//
//  PaywallView.swift
//  Footprint
//
//  订阅付费墙：展示价值点、价格、购买与恢复入口。
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var isRestoring: Bool = false
    @State private var isPurchasing: Set<String> = []

    // 引导流程相关
    var isOnboarding: Bool = false
    var onSkip: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection

                    if isOnboarding {
                        freeTierSection
                    }

                    featureList
                    pricingSection

                    if isOnboarding {
                        subscriptionTermsSection
                    }

                    if !isOnboarding {
                        restoreSection
                    }

                    if isOnboarding, let onSkip = onSkip {
                        continueFreeSection(onSkip: onSkip)
                        onboardingRestoreLink
                        legalLinksSection
                    } else {
                        termsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .padding(.top, 12)
            }
            .navigationTitle(navigationTitleKey.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("close".localized) { dismiss() }
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.12),
                        Color.pink.opacity(0.08),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .task {
                await purchaseManager.loadProducts()
            }
        }
    }

    // MARK: - Sections

    private var navigationTitleKey: String {
        isOnboarding ? "onboarding_paywall_nav_title" : "paywall_title"
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: isOnboarding ? "map.fill" : "sparkles.rectangle.stack")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(brandColorManager.currentBrandColor)

            Text(isOnboarding ? "onboarding_paywall_title".localized : "paywall_title".localized)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(isOnboarding ? "onboarding_paywall_subtitle".localized : "paywall_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var freeTierSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("onboarding_free_tier_title".localized)
                .font(.headline)

            freeTierRow(title: "onboarding_free_destinations".localized(with: FreeTierLimits.maxDestinations))
            freeTierRow(title: "onboarding_free_trips".localized(with: FreeTierLimits.maxTrips))
            freeTierRow(title: "onboarding_free_photos".localized(with: FreeTierLimits.maxPhotosPerDestination))
            freeTierRow(title: "onboarding_free_share".localized)
            freeTierRow(title: "onboarding_free_ai_trial".localized(with: FreeTierLimits.aiFreeTrialCredits))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isOnboarding ? "onboarding_pro_feature_title".localized : "paywall_feature_title".localized)
                .font(.headline)

            featureRow(icon: "sparkles", title: "paywall_feature_ai".localized)
            featureRow(icon: "infinity", title: "paywall_feature_unlimited".localized)
            featureRow(icon: "square.grid.3x3.square.badge.ellipsis", title: "paywall_feature_share_layouts".localized)
            featureRow(icon: "tray.and.arrow.down.fill", title: "paywall_feature_import_export".localized)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if isOnboarding {
                Text("onboarding_pricing_section_title".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasLifetime {
                lifetimeUnlockedCard
            } else {
                if purchaseManager.isLoading {
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if purchaseManager.products.isEmpty {
                    if let message = purchaseManager.errorMessage {
                        VStack(spacing: 12) {
                            Text(message)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                Task {
                                    await purchaseManager.loadProducts()
                                }
                            } label: {
                                Text("retry".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    } else {
                        ProgressView("loading".localized)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                } else {
                    if let errorMessage = purchaseManager.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }

                    ForEach(sortedProducts(), id: \.id) { product in
                        purchaseButton(for: product)
                    }
                }
            }
        }
    }

    private var restoreSection: some View {
        Button {
            Task {
                isRestoring = true
                await purchaseManager.restorePurchases()
                isRestoring = false
                entitlementManager.updateEntitlement()
                if entitlementManager.isSubscriptionActive {
                    completeActiveSubscriptionFlow()
                }
            }
        } label: {
            HStack {
                if isRestoring { ProgressView().scaleEffect(0.8) }
                Text("paywall_button_restore".localized)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var onboardingRestoreLink: some View {
        Button {
            Task {
                isRestoring = true
                await purchaseManager.restorePurchases()
                isRestoring = false
                entitlementManager.updateEntitlement()
                if entitlementManager.isSubscriptionActive {
                    completeActiveSubscriptionFlow()
                }
            }
        } label: {
            HStack(spacing: 6) {
                if isRestoring { ProgressView().scaleEffect(0.7) }
                Text("paywall_button_restore".localized)
            }
            .font(.footnote.weight(.medium))
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func continueFreeSection(onSkip: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Button {
                onSkip()
            } label: {
                Text("onboarding_continue_free".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("onboarding_continue_free_hint".localized)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var subscriptionTermsSection: some View {
        Text("subscription_auto_renew_note".localized)
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var termsSection: some View {
        VStack(spacing: 6) {
            Text("subscription_auto_renew_note".localized)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            legalLinksSection
        }
        .padding(.top, 4)
    }

    private var legalLinksSection: some View {
        HStack(spacing: 4) {
            Link("terms_of_use".localized, destination: URL(string: "terms_url".localized)!)
            Text("|")
                .foregroundColor(.secondary)
            Link("privacy_policy".localized, destination: URL(string: "privacy_url".localized)!)
        }
        .font(.footnote.weight(.semibold))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func freeTierRow(title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.secondary)
                .frame(width: 26)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(brandColorManager.currentBrandColor)
                .frame(width: 26)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private func purchaseButton(for product: Product) -> some View {
        let isPurchasingThis = isPurchasing.contains(product.id)
        let isCurrentSubscription = entitlementManager.currentSubscriptionProductID == product.id && entitlementManager.isSubscriptionActive
        let isRecommended = isOnboarding && product.id == SubscriptionProductID.proYearly

        return Button {
            guard !isPurchasingThis else { return }
            guard !isCurrentSubscription else { return }

            isPurchasing.insert(product.id)

            Task { @MainActor in
                purchaseManager.errorMessage = nil
                let transaction = await purchaseManager.purchase(product)

                if let transaction = transaction {
                    entitlementManager.updateEntitlement(from: transaction)
                    try? await Task.sleep(nanoseconds: 300_000_000)

                    if entitlementManager.isSubscriptionActive {
                        completeActiveSubscriptionFlow()
                    } else {
                        entitlementManager.updateEntitlement()
                    }
                }

                if transaction == nil && purchaseManager.errorMessage == nil {
                    isPurchasing.remove(product.id)
                } else {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    isPurchasing.remove(product.id)
                }
            }
        } label: {
            HStack {
                VStack(spacing: 6) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        if isRecommended {
                            Text("onboarding_recommended_plan".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(brandColorManager.currentBrandColor)
                                )
                        }
                        Spacer()
                        if isCurrentSubscription {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                Text("paywall_current_subscription".localized)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text(product.displayPrice)
                                .font(.headline)
                        }
                    }
                    HStack {
                        Text(subtitle(for: product))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if isCurrentSubscription {
                            if let expiryDate = entitlementManager.subscriptionExpiryDate {
                                Text("paywall_expires_on".localized + formatDate(expiryDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("membership_status_lifetime_active".localized)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                if isPurchasingThis {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrentSubscription ?
                          Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1) :
                            brandColorManager.currentBrandColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isRecommended ? brandColorManager.currentBrandColor.opacity(0.55) :
                                (isCurrentSubscription ? Color.green.opacity(0.5) : Color.clear), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasingThis || isCurrentSubscription)
    }

    private func completeActiveSubscriptionFlow() {
        if isOnboarding, let onSkip = onSkip {
            onSkip()
        } else {
            dismiss()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private func sortedProducts() -> [Product] {
        let subscriptions = purchaseManager.products
            .filter { SubscriptionProductID.all.contains($0.id) }

        if isOnboarding {
            return subscriptions.sorted { lhs, rhs in
                planSortOrder(for: lhs.id) < planSortOrder(for: rhs.id)
            }
        }

        return subscriptions.sorted { $0.price < $1.price }
    }

    private func planSortOrder(for productID: String) -> Int {
        switch productID {
        case SubscriptionProductID.proYearly: return 0
        case SubscriptionProductID.proMonthly: return 1
        case SubscriptionProductID.proLifetime: return 2
        default: return 3
        }
    }

    private func subtitle(for product: Product) -> String {
        if product.id == SubscriptionProductID.proLifetime {
            return "one_time_purchase".localized
        }
        if let unit = product.subscription?.subscriptionPeriod.unit {
            return unit.title
        }
        return ""
    }

    private var hasLifetime: Bool {
        entitlementManager.currentEntitlement == .pro && entitlementManager.subscriptionExpiryDate == nil
    }

    private var lifetimeUnlockedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("paywall_lifetime_unlocked".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Text("paywall_lifetime_sync_hint".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var title: String {
        switch self {
        case .month: return "subscription_monthly".localized
        case .year: return "subscription_yearly".localized
        case .week: return "subscription_weekly".localized
        case .day: return "subscription_daily".localized
        @unknown default: return "subscription_default".localized
        }
    }
}
