//
//  ProStore.swift
//  Yonder
//

import Combine
import Foundation
import StoreKit
import UIKit

/// Central StoreKit 2 entitlement manager for Yonder PRO.
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    enum ProductID {
        static let monthly = "com.emir.Yonder.pro.monthly"
        static let yearly = "com.emir.Yonder.pro.yearly"
        static let all: [String] = [monthly, yearly]
    }

    enum ProStoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                // Note: This string is intentionally minimal — App Review guideline 4.0
                return NSLocalizedString(
                    "Purchase could not be verified with the App Store. Please try again or restore your purchase.",
                    comment: "StoreKit verification failure"
                )
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var alertMessage: String?

    private let entitlementDefaultsKey = "is_premium_user"
    private let debugOverrideDefaultsKey = "debug_pro_override"
    private var transactionUpdatesTask: Task<Void, Never>?
    private var foregroundRefreshTask: Task<Void, Never>?
    private var hasStarted = false

    private init() {}

    deinit {
        transactionUpdatesTask?.cancel()
        foregroundRefreshTask?.cancel()
    }

    var hasPro: Bool {
        hasVerifiedEntitlement || hasDebugOverride
    }

    var hasVerifiedEntitlement: Bool {
        !purchasedProductIDs.isEmpty
    }

    private var hasDebugOverride: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: debugOverrideDefaultsKey)
        #else
        false
        #endif
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }

        // Re-checks entitlements whenever the app returns to the foreground so an
        // expiration that happened while backgrounded is reflected without a relaunch.
        foregroundRefreshTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                guard let self else { return }
                await self.refreshEntitlements()
            }
        }

        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let storeProducts = try await Product.products(for: ProductID.all)
            products = storeProducts.sorted { lhs, rhs in
                productSortRank(lhs.id) < productSortRank(rhs.id)
            }
        } catch {
            // Products failing to load (e.g. no network) is shown as a calm empty-state
            // panel by the paywall UI rather than a jarring system-error alert.
            products = []
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                updateSharedPremiumFlag()
                await transaction.finish()
                return true
            case .pending:
                // Ask to Buy or payment pending — no error shown, user will be notified by the OS
                return false
            case .userCancelled:
                // User dismissed the payment sheet — silent, no alert needed
                return false
            @unknown default:
                return false
            }
        } catch {
            // Only show an alert for real errors (not cancellations)
            let nsError = error as NSError
            let isCancelledBySystem = nsError.domain == SKErrorDomain && nsError.code == SKError.Code.paymentCancelled.rawValue
            if !isCancelledBySystem {
                alertMessage = error.localizedDescription
            }
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return hasPro
        } catch {
            // AppStore.sync() can fail if the user cancels Sign In with Apple — don't show an alert for cancellations
            let nsError = error as NSError
            let isCancelledBySystem = nsError.domain == SKErrorDomain && nsError.code == SKError.Code.paymentCancelled.rawValue
            if !isCancelledBySystem {
                alertMessage = error.localizedDescription
            }
            return false
        }
    }

    func refreshEntitlements() async {
        var verifiedIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard ProductID.all.contains(transaction.productID) else { continue }
                verifiedIDs.insert(transaction.productID)
            } catch {
                continue
            }
        }

        purchasedProductIDs = verifiedIDs
        updateSharedPremiumFlag()
    }

    func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            openSubscriptionsURL()
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            openSubscriptionsURL()
        }
    }

    #if DEBUG
    func enableDebugPro() {
        UserDefaults.standard.set(true, forKey: debugOverrideDefaultsKey)
        updateSharedPremiumFlag()
    }

    func disableDebugPro() {
        UserDefaults.standard.set(false, forKey: debugOverrideDefaultsKey)
        updateSharedPremiumFlag()
    }
    #endif

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            guard ProductID.all.contains(transaction.productID) else {
                await transaction.finish()
                return
            }

            if transaction.revocationDate == nil && isCurrentlyActive(transaction) {
                purchasedProductIDs.insert(transaction.productID)
            } else {
                purchasedProductIDs.remove(transaction.productID)
            }

            updateSharedPremiumFlag()
            await transaction.finish()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func updateSharedPremiumFlag() {
        UserDefaults.standard.set(hasPro, forKey: entitlementDefaultsKey)
    }

    private func openSubscriptionsURL() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    /// A transaction pushed via `Transaction.updates` may represent an already-expired
    /// subscription (e.g. a failed renewal attempt) — guard against granting Pro from it.
    private func isCurrentlyActive(_ transaction: Transaction) -> Bool {
        guard let expirationDate = transaction.expirationDate else { return true }
        return expirationDate > Date()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw ProStoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    private func productSortRank(_ productID: String) -> Int {
        if productID == ProductID.yearly { return 0 }
        if productID == ProductID.monthly { return 1 }
        return 2
    }
}
