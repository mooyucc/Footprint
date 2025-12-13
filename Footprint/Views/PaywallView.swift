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
    
    // 引导流程相关
    var isOnboarding: Bool = false
    var onSkip: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    featureList
                    pricingSection
                    restoreSection
                    
                    // 引导流程中显示"开始使用"按钮
                    if isOnboarding, let onSkip = onSkip {
                        skipButton(onSkip: onSkip)
                    }
                    
                    termsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .padding(.top, 12)
            }
            .navigationTitle("paywall_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 仅在非引导流程中显示关闭按钮
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
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("paywall_title".localized)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("paywall_subtitle".localized)
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

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("paywall_feature_title".localized)
                .font(.headline)

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
            if hasLifetime {
                lifetimeUnlockedCard
            } else {
                if purchaseManager.products.isEmpty && purchaseManager.errorMessage == nil {
                    ProgressView("loading".localized)
                } else if let message = purchaseManager.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
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
    
    private func skipButton(onSkip: @escaping () -> Void) -> some View {
        Button {
            onSkip()
        } label: {
            Text("onboarding_complete".localized)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(brandColorManager.currentBrandColor)
                )
        }
    }

    private var termsSection: some View {
        VStack(spacing: 6) {
            Text("subscription_auto_renew_note".localized)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Link("terms_of_use".localized, destination: URL(string: "terms_url".localized)!)
                Text("|")
                    .foregroundColor(.secondary)
                Link("privacy_policy".localized, destination: URL(string: "privacy_url".localized)!)
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 26)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private func purchaseButton(for product: Product) -> some View {
        Button {
            Task {
                _ = await purchaseManager.purchase(product)
                entitlementManager.updateEntitlement()
            }
        } label: {
            VStack(spacing: 6) {
                HStack {
                    Text(product.displayName)
                        .font(.headline)
                    Spacer()
                    Text(product.displayPrice)
                        .font(.headline)
                }
                Text(subtitle(for: product))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
            )
        }
        .buttonStyle(.plain)
    }

    private func sortedProducts() -> [Product] {
        purchaseManager.products.sorted { lhs, rhs in
            lhs.price < rhs.price
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

