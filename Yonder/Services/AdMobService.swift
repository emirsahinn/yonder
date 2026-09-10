//
//  AdMobService.swift
//  Yonder
//

import AppTrackingTransparency
import Combine
import Foundation
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Owns the interstitial ad lifecycle for free users.
@MainActor
final class AdMobService: NSObject, ObservableObject {
    static let shared = AdMobService()

    private enum Config {
        static let sampleInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    }

    @Published private(set) var isPrivacyOptionsRequired = false

    private var interstitialAd: InterstitialAd?
    private var isConsentFlowStarted = false
    private var isMobileAdsStarted = false
    private var isLoadingInterstitial = false
    private var presentationContinuation: CheckedContinuation<Bool, Never>?

    private override init() {
        super.init()
    }

    func configureOnLaunch() {
        guard !isConsentFlowStarted else { return }
        isConsentFlowStarted = true

        Task {
            await prepareForAdsIfPossible()
        }
    }

    @discardableResult
    func showCompletionInterstitialIfNeeded() async -> Bool {
        guard !ProStore.shared.hasPro else { return false }
        guard await ensureInterstitialReady() else { return false }
        return await presentLoadedInterstitial()
    }

    func presentPrivacyOptionsIfNeeded() async {
        guard isPrivacyOptionsRequired else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            updatePrivacyOptionsRequirement()
        } catch {
            #if DEBUG
            print("[AdMobService] Privacy options failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func ensureInterstitialReady() async -> Bool {
        if !isConsentFlowStarted {
            configureOnLaunch()
        }

        guard ConsentInformation.shared.canRequestAds else { return false }
        guard isMobileAdsStarted else { return false }

        if interstitialAd == nil {
            await loadInterstitialWithTimeout()
        }

        return interstitialAd != nil
    }

    private func prepareForAdsIfPossible() async {
        let parameters = RequestParameters()

        do {
            try await requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            #if DEBUG
            print("[AdMobService] Consent flow error: \(error.localizedDescription)")
            #endif
        }

        updatePrivacyOptionsRequirement()

        guard ConsentInformation.shared.canRequestAds else { return }

        await requestTrackingAuthorizationIfNeeded()

        if !isMobileAdsStarted {
            await MobileAds.shared.start()
            isMobileAdsStarted = true
        }

        if interstitialAd == nil {
            await loadInterstitial()
        }
    }

    private func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func updatePrivacyOptionsRequirement() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Bounds the on-demand ad load so a completion action (save/discard/leave)
    /// never stalls indefinitely waiting on the ad network. If the load hasn't
    /// finished in time, `loadInterstitial()` keeps running in the background
    /// and the ad becomes available for the next opportunity.
    private func loadInterstitialWithTimeout(seconds: UInt64 = 4) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.loadInterstitial()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func loadInterstitial() async {
        guard !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        defer { isLoadingInterstitial = false }

        do {
            interstitialAd = try await InterstitialAd.load(
                with: interstitialAdUnitID,
                request: Request()
            )
            interstitialAd?.fullScreenContentDelegate = self
        } catch {
            interstitialAd = nil
            #if DEBUG
            print("[AdMobService] Interstitial load failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func presentLoadedInterstitial() async -> Bool {
        guard let interstitialAd, presentationContinuation == nil else { return false }

        return await withCheckedContinuation { continuation in
            presentationContinuation = continuation
            interstitialAd.present(from: nil)

            // Safety net: if `present(from:)` never triggers a delegate
            // callback (e.g. no key window / backgrounded), don't hang the
            // caller forever.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self?.finishPresentationIfStillPending()
            }
        }
    }

    private func finishPresentationIfStillPending() {
        guard presentationContinuation != nil else { return }
        finishPresentation(didShow: false)
    }

    private var interstitialAdUnitID: String {
        #if DEBUG
        return Config.sampleInterstitialAdUnitID
        #else
        let configured = Bundle.main.object(forInfoDictionaryKey: "YonderInterstitialAdUnitID") as? String
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? Config.sampleInterstitialAdUnitID : trimmed
        #endif
    }

    private func finishPresentation(didShow: Bool) {
        interstitialAd = nil
        presentationContinuation?.resume(returning: didShow)
        presentationContinuation = nil

        Task {
            await loadInterstitial()
        }
    }
}

extension AdMobService: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[AdMobService] Interstitial present failed: \(error.localizedDescription)")
        #endif
        finishPresentation(didShow: false)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation(didShow: true)
    }
}
