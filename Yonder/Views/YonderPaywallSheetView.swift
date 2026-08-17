//
//  YonderPaywallSheetView.swift
//  Yonder
//

import StoreKit
import SwiftUI

/// Yonder PRO paywall — unlocks daily/weekly/monthly goal tracking.
struct YonderPaywallSheetView: View {

    @AppStorage("app_language") private var appLanguage: String = "en"
    @Environment(\.dismiss) private var dismiss
    @StateObject private var proStore = ProStore.shared

    #if DEBUG
    /// Extra local-only gate so the debug unlock button stays hidden even in Debug
    /// builds unless explicitly enabled (e.g. via an Xcode launch argument:
    /// `-debug_show_pro_unlock_button YES`). Never compiled into Release/TestFlight builds.
    @AppStorage("debug_show_pro_unlock_button") private var showDebugProControls: Bool = false
    #endif

    private let onUnlockPremium: () -> Void

    init(onUnlockPremium: @escaping () -> Void = {}) {
        self.onUnlockPremium = onUnlockPremium
    }

    private var isTurkish: Bool { appLanguage == "tr" }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.055, green: 0.060, blue: 0.078),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    topBar
                    hero
                    benefitsCard
                    productsSection
                    restoreSection
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await proStore.start()
        }
        .alert(
            isTurkish ? "Satın alma tamamlanamadı" : "Purchase unavailable",
            isPresented: Binding(
                get: { proStore.alertMessage != nil },
                set: { if !$0 { proStore.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(proStore.alertMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Text("YONDER PRO")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.55))
                .tracking(3)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(white: 0.62))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTurkish ? "Kapat" : "Close")
        }
        .padding(.top, 14)
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.96, green: 0.79, blue: 0.36).opacity(0.24),
                                Color(red: 0.96, green: 0.79, blue: 0.36).opacity(0.04),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 74
                        )
                    )
                    .frame(width: 150, height: 150)

                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color(red: 0.96, green: 0.79, blue: 0.36))
                    .frame(width: 86, height: 86)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }

            VStack(spacing: 8) {
                Text(isTurkish ? "Hedeflerini planla." : "Plan your goals.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.96))
                    .multilineTextAlignment(.center)

                Text(isTurkish
                     ? "Yonder PRO ile günlük, haftalık ve aylık hedeflerini takip et."
                     : "Track daily, weekly, and monthly goals with Yonder PRO.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.58))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 360)
            }
        }
        .padding(.top, 8)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefitRow(
                icon: "target",
                title: isTurkish ? "Günlük, haftalık, aylık hedefler" : "Daily, weekly, monthly goals",
                subtitle: isTurkish ? "Genel ve çalışma bazlı hedeflerini ayrıntılı takip et." : "Track general and work-based goals in detail."
            )

            benefitRow(
                icon: "chart.line.uptrend.xyaxis",
                title: isTurkish ? "Gelişmiş hedef takibi" : "Advanced goal tracking",
                subtitle: isTurkish ? "Hedef ilerlemeni raporlarında daha net gör." : "See your goal progress more clearly in reports."
            )

        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.065))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private var productsSection: some View {
        VStack(spacing: 12) {
            if proStore.isLoadingProducts && proStore.products.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(height: 64)
            } else if proStore.products.isEmpty {
                unavailableProductsView
            } else {
                ForEach(proStore.products, id: \.id) { product in
                    productButton(product)
                }
            }
        }
    }

    private var unavailableProductsView: some View {
        VStack(spacing: 10) {
            Text(isTurkish ? "Ürünler yüklenemedi." : "Could not load products.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.88))

            Text(isTurkish
                 ? "Lütfen internet bağlantını kontrol et ve tekrar dene."
                 : "Please check your internet connection and try again.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.48))
                .multilineTextAlignment(.center)

            Button {
                Task { await proStore.loadProducts() }
            } label: {
                Text(isTurkish ? "Tekrar Dene" : "Try Again")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private func productButton(_ product: Product) -> some View {
        Button {
            Task {
                let didUnlock = await proStore.purchase(product)
                if didUnlock {
                    onUnlockPremium()
                    dismiss()
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(productTitle(product))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(white: 0.96))

                        if product.id == ProStore.ProductID.yearly {
                            Text(isTurkish ? "ÖNERİLEN" : "RECOMMENDED")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(red: 0.96, green: 0.79, blue: 0.36)))
                        }
                    }

                    Text(productRenewalCaption(product))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.96))

                    Text(productPeriodSuffix(product))
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(white: 0.42))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(minHeight: 76)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(product.id == ProStore.ProductID.yearly ? Color(red: 0.96, green: 0.79, blue: 0.36).opacity(0.13) : Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(product.id == ProStore.ProductID.yearly ? Color(red: 0.96, green: 0.79, blue: 0.36).opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(proStore.isPurchasing)
    }

    private var restoreSection: some View {
        VStack(spacing: 12) {
            if proStore.isPurchasing {
                ProgressView()
                    .tint(.white)
            }

            Button {
                Task {
                    let didRestore = await proStore.restorePurchases()
                    if didRestore {
                        onUnlockPremium()
                        dismiss()
                    }
                }
            } label: {
                Text(isTurkish ? "Satın Alımı Geri Yükle" : "Restore Purchase")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.70))
            }
            .buttonStyle(.plain)
            .disabled(proStore.isPurchasing)

            Text(isTurkish
                 ? "Satın alma Apple hesabınla yönetilir. İstediğin zaman App Store aboneliklerinden iptal edebilirsin."
                 : "Purchases are managed by your Apple account. You can cancel any time from App Store subscriptions.")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.38))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Terms of Use & Privacy Policy — required for App Store Review
            HStack(spacing: 16) {
                Link(
                    isTurkish ? "Kullanım Koşulları" : "Terms of Use",
                    destination: LegalLinks.termsOfUseURL
                )
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.30))

                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.25))

                Link(
                    isTurkish ? "Gizlilik Politikası" : "Privacy Policy",
                    destination: LegalLinks.privacyPolicyURL
                )
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.30))
            }

            #if DEBUG
            if showDebugProControls {
                debugControls
            }
            #endif
        }
        .padding(.top, 2)
    }

    #if DEBUG
    private var debugControls: some View {
        Button {
            proStore.enableDebugPro()
            onUnlockPremium()
            dismiss()
        } label: {
            Text(isTurkish ? "Debug: PRO Aç" : "Debug: Unlock PRO")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.96, green: 0.79, blue: 0.36))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }
    #endif

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.96, green: 0.79, blue: 0.36))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(red: 0.96, green: 0.79, blue: 0.36).opacity(0.10)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.90))

                Text(subtitle)
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.48))
                    .lineSpacing(2)
            }
        }
    }

    private func productTitle(_ product: Product) -> String {
        if product.id == ProStore.ProductID.yearly {
            return isTurkish ? "Yıllık PRO" : "Yearly PRO"
        }

        if product.id == ProStore.ProductID.monthly {
            return isTurkish ? "Aylık PRO" : "Monthly PRO"
        }

        return product.displayName
    }

    /// Explicit disclosure of subscription length and auto-renewal, required for App Store Review.
    private func productRenewalCaption(_ product: Product) -> String {
        if product.id == ProStore.ProductID.yearly {
            return isTurkish ? "1 yıllık abonelik · Otomatik yenilenir" : "1 year subscription · Auto-renews"
        }

        if product.id == ProStore.ProductID.monthly {
            return isTurkish ? "1 aylık abonelik · Otomatik yenilenir" : "1 month subscription · Auto-renews"
        }

        return ""
    }

    private func productPeriodSuffix(_ product: Product) -> String {
        if product.id == ProStore.ProductID.yearly {
            return isTurkish ? "/ yıl" : "/ year"
        }

        if product.id == ProStore.ProductID.monthly {
            return isTurkish ? "/ ay" : "/ month"
        }

        return ""
    }
}
