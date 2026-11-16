//
//  PaywallView.swift
//  Footprint
//
//  订阅付费墙：展示价值点、价格、购买与恢复入口。
//

import SwiftUI
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var isRestoring: Bool = false
    @State private var isPurchasing: Bool = false
    @State private var selectedProductID: String = SubscriptionProductID.proYearly
    @State private var showCreditPaywall: Bool = false
    @State private var introEligibleProductIDs: Set<String> = []

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

                    VStack(spacing: 12) {
                        purchaseCTASection
                        if isOnboarding, let onSkip = onSkip {
                            continueFreeSection(onSkip: onSkip)
                        }
                    }

                    if isSelectedSubscriptionPlan {
                        subscriptionTermsSection
                    }

                    if isOnboarding {
                        onboardingFooter
                    } else {
                        buyCreditsSecondaryLink
                        restoreSection
                        legalLinksSection
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
            .background {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
            }
            .task {
                await purchaseManager.loadProducts()
                syncSelectedProductIfNeeded()
                await refreshIntroOfferEligibility()
            }
            .onChange(of: purchaseManager.products.count) { _, _ in
                syncSelectedProductIfNeeded()
                Task { await refreshIntroOfferEligibility() }
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
        .footprintGlassCard(cornerRadius: 18, glow: brandColorManager.currentBrandColor)
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
        .footprintGlassCard(cornerRadius: 14)
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
        .footprintGlassCard(cornerRadius: 14, glow: brandColorManager.currentBrandColor)
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            Text(isOnboarding ? "onboarding_pricing_section_title".localized : "paywall_select_plan".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasLifetime {
                lifetimeUnlockedCard
            }

            if purchaseManager.isLoading {
                ProgressView("loading".localized)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if purchasableProducts.isEmpty && !hasLifetime {
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

                ForEach(purchasableProducts, id: \.id) { product in
                    planCard(for: product)
                }
            }
        }
    }

    private var purchaseCTASection: some View {
        VStack(spacing: 8) {
            Button {
                purchaseSelectedPlan()
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(primaryCTATitle)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(brandColorManager.currentBrandColor)
            .controlSize(.large)
            .disabled(isPurchasing || selectedProduct == nil || isCurrentSelectedPlan || purchasableProducts.isEmpty)

            if let caption = selectedPlanCaption {
                Text(caption)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
        .frame(minHeight: 44)
    }

    private func continueFreeSection(onSkip: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button {
                onSkip()
            } label: {
                Text("onboarding_continue_free".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("onboarding_continue_free_hint".localized)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var onboardingFooter: some View {
        VStack(spacing: 10) {
            onboardingRestoreLink
            legalLinksSection
        }
        .padding(.top, 4)
    }

    private var buyCreditsSecondaryLink: some View {
        Button {
            showCreditPaywall = true
        } label: {
            Text("paywall_buy_credits_secondary".localized)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var subscriptionTermsSection: some View {
        Text("subscription_auto_renew_note".localized)
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
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

    private func planCard(for product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isCurrent = isCurrentPlan(product)
        let isRecommended = product.id == SubscriptionProductID.proYearly

        return Button {
            guard !isCurrent else { return }
            selectedProductID = product.id
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
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
                    if isCurrent {
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
                    if isCurrent, let expiryDate = entitlementManager.subscriptionExpiryDate {
                        Text("paywall_expires_on".localized + formatDate(expiryDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if let extra = planExtraLine(for: product) {
                    Text(extra)
                        .font(.caption)
                        .foregroundColor(brandColorManager.currentBrandColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrent ?
                          Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1) :
                            brandColorManager.currentBrandColor.opacity(isSelected ? (colorScheme == .dark ? 0.28 : 0.18) : (colorScheme == .dark ? 0.16 : 0.1)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? brandColorManager.currentBrandColor.opacity(0.7) :
                            (isCurrent ? Color.green.opacity(0.5) : Color.clear),
                        lineWidth: isSelected ? 2 : 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func purchaseSelectedPlan() {
        guard let product = selectedProduct, !isPurchasing, !isCurrentSelectedPlan else { return }
        isPurchasing = true

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
                isPurchasing = false
            } else {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                isPurchasing = false
            }
        }
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

    private var purchasableProducts: [Product] {
        purchaseManager.products
            .filter { SubscriptionProductID.all.contains($0.id) }
            .filter { product in
                if product.id == SubscriptionProductID.proLifetime && hasLifetime {
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                planSortOrder(for: lhs.id) < planSortOrder(for: rhs.id)
            }
    }

    private var selectedProduct: Product? {
        purchasableProducts.first { $0.id == selectedProductID } ?? purchasableProducts.first
    }

    private var isCurrentSelectedPlan: Bool {
        guard let product = selectedProduct else { return false }
        return isCurrentPlan(product)
    }

    private func isCurrentPlan(_ product: Product) -> Bool {
        entitlementManager.currentSubscriptionProductID == product.id && entitlementManager.isSubscriptionActive
    }

    private var primaryCTATitle: String {
        guard let product = selectedProduct else {
            return "paywall_cta_unlock".localized
        }
        if isCurrentPlan(product) {
            return "paywall_cta_current".localized
        }
        switch product.id {
        case SubscriptionProductID.proYearly:
            if isEligibleForIntroTrial(product) {
                return "paywall_cta_start_trial".localized
            }
            return "paywall_cta_yearly".localized(with: product.displayPrice)
        case SubscriptionProductID.proMonthly:
            return "paywall_cta_monthly".localized(with: product.displayPrice)
        case SubscriptionProductID.proLifetime:
            return "paywall_cta_lifetime".localized(with: product.displayPrice)
        default:
            return "paywall_cta_unlock_price".localized(with: product.displayPrice)
        }
    }

    private var selectedPlanCaption: String? {
        guard let product = selectedProduct else { return nil }
        if product.id == SubscriptionProductID.proLifetime {
            return nil
        }
        if product.id == SubscriptionProductID.proYearly, isEligibleForIntroTrial(product) {
            return "paywall_cta_trial_then_yearly".localized(with: product.displayPrice)
        }
        return nil
    }

    private var isSelectedSubscriptionPlan: Bool {
        guard let id = selectedProduct?.id else { return false }
        return id == SubscriptionProductID.proYearly || id == SubscriptionProductID.proMonthly
    }

    private func planExtraLine(for product: Product) -> String? {
        if product.id == SubscriptionProductID.proLifetime {
            return "paywall_ai_uses_credits".localized
        }
        if product.id == SubscriptionProductID.proYearly {
            var parts: [String] = ["paywall_ai_uses_credits".localized]
            if let monthly = monthlyEquivalentText(for: product) {
                parts.append(monthly)
            }
            if let save = yearlySavingsPercent() {
                parts.append("paywall_yearly_save".localized(with: save))
            }
            if let trial = trialText(for: product) {
                parts.append(trial)
            }
            return parts.joined(separator: " · ")
        }
        var parts: [String] = ["paywall_ai_uses_credits".localized]
        if let trial = trialText(for: product) {
            parts.append(trial)
        }
        return parts.joined(separator: " · ")
    }

    private func monthlyEquivalentText(for product: Product) -> String? {
        guard product.id == SubscriptionProductID.proYearly else { return nil }
        let perMonth = product.price / 12
        let formatted = product.priceFormatStyle.format(perMonth)
        return "paywall_yearly_monthly_equivalent".localized(with: formatted)
    }

    private func yearlySavingsPercent() -> Int? {
        guard
            let yearly = purchaseManager.products.first(where: { $0.id == SubscriptionProductID.proYearly }),
            let monthly = purchaseManager.products.first(where: { $0.id == SubscriptionProductID.proMonthly })
        else { return nil }

        let yearIfMonthly = monthly.price * 12
        guard yearIfMonthly > 0, yearly.price < yearIfMonthly else { return nil }
        let ratio = NSDecimalNumber(decimal: yearly.price / yearIfMonthly).doubleValue
        let percent = Int((1.0 - ratio) * 100.0)
        return percent > 0 ? percent : nil
    }

    private func trialText(for product: Product) -> String? {
        guard isEligibleForIntroTrial(product) else { return nil }
        guard let intro = product.subscription?.introductoryOffer else { return nil }

        let value = intro.period.value
        switch intro.period.unit {
        case .day:
            return "paywall_trial_days".localized(with: value)
        case .week:
            return "paywall_trial_weeks".localized(with: value)
        case .month:
            return "paywall_trial_months".localized(with: value)
        case .year:
            return "paywall_trial_years".localized(with: value)
        @unknown default:
            return nil
        }
    }

    private func isEligibleForIntroTrial(_ product: Product) -> Bool {
        guard
            let intro = product.subscription?.introductoryOffer,
            intro.paymentMode == .freeTrial
        else { return false }
        return introEligibleProductIDs.contains(product.id)
    }

    private func refreshIntroOfferEligibility() async {
        var eligible: Set<String> = []
        for product in purchasableProducts {
            guard
                let subscription = product.subscription,
                let intro = subscription.introductoryOffer,
                intro.paymentMode == .freeTrial
            else { continue }
            if await subscription.isEligibleForIntroOffer {
                eligible.insert(product.id)
            }
        }
        introEligibleProductIDs = eligible
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
        entitlementManager.hasLifetimePurchase || entitlementManager.currentEntitlement == .proLifetime
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
            Text("paywall_ai_uses_credits".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("paywall_lifetime_sync_hint".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .footprintGlassCard(cornerRadius: 14, glow: .green)
    }

    private func syncSelectedProductIfNeeded() {
        let available = purchasableProducts
        guard !available.isEmpty else { return }

        if let selected = available.first(where: { $0.id == selectedProductID }), !isCurrentPlan(selected) {
            return
        }
        if let yearly = available.first(where: { $0.id == SubscriptionProductID.proYearly && !isCurrentPlan($0) }) {
            selectedProductID = yearly.id
            return
        }
        selectedProductID = available.first(where: { !isCurrentPlan($0) })?.id ?? available[0].id
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
