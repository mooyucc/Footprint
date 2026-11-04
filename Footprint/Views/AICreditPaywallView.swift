//
//  AICreditPaywallView.swift
//  Footprint
//
//  AI 调用次数购买页：展示剩余/已用次数，并提供购买入口。
//

import SwiftUI
import StoreKit

struct AICreditPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    
    /// 以下属性用于预览或测试时的覆盖值；正常运行时使用环境对象中的真实数据。
    var remainingCallsOverride: Int? = nil
    var usedCallsOverride: Int? = nil
    var productTitleOverride: String? = nil
    var productPriceTextOverride: String? = nil
    var usageDescriptionOverride: String? = nil
    
    // 计算属性：当前剩余/已用次数
    private var remainingCalls: Int {
        remainingCallsOverride ?? aiCreditManager.remaining
    }
    
    private var usedCalls: Int {
        usedCallsOverride ?? aiCreditManager.used
    }
    
    // 目标商品：50 次优先展示，其次 10 次
    private var creditProducts: [Product] {
        let order = [AICreditProductID.fiftyCalls, AICreditProductID.tenCalls]
        return order.compactMap { id in
            purchaseManager.products.first { $0.id == id }
        }
    }
    
    // 使用说明
    private var usageDescription: String {
        usageDescriptionOverride ?? "ai_credits_usage_desc".localized
    }
    
    @State private var showPaywall = false
    @State private var purchasingProductID: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: Color.pink,
                    secondaryAccent: Color.orange
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        counterSection
                        productSection
                        viewProPlansSecondaryLink
                        usageInfoSection
                        restoreSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("ai_credits_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task {
                await purchaseManager.loadProducts()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pink, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 4)
            
            Text("ai_credits_title".localized)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            Text("ai_credits_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var viewProPlansSecondaryLink: some View {
        Button {
            showPaywall = true
        } label: {
            Text("paywall_button_upgrade".localized)
                .font(.footnote.weight(.medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
    
    private var counterSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ai_credits_remaining_label".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(remainingCalls)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ai_credits_used_label".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(usedCalls)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .footprintGlassCard(cornerRadius: FootprintTheme.Radius.card, glow: .pink)
    }
    
    private var productSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ai_credits_buy_section_title".localized)
                .font(.headline)
                .foregroundColor(.primary)

            if purchaseManager.isLoading && creditProducts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if creditProducts.isEmpty {
                Text("ai_credits_product_unavailable".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(creditProducts, id: \.id) { product in
                    creditProductRow(for: product)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditProductRow(for product: Product) -> some View {
        let isBestValue = product.id == AICreditProductID.fiftyCalls
        let isPurchasing = purchasingProductID == product.id

        return Button {
            guard purchasingProductID == nil else { return }
            purchasingProductID = product.id
            Task {
                _ = await purchaseManager.purchase(product)
                purchasingProductID = nil
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title(for: product))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        if isBestValue {
                            Text("ai_credits_best_value".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor))
                        }
                    }

                    Text("ai_credits_product_grant".localized(with: creditGrantCount(for: product)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .footprintGlassCard(cornerRadius: 16, glow: isBestValue ? Color.accentColor : nil)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isBestValue ? Color.accentColor.opacity(0.55) : Color.accentColor.opacity(0.25),
                        lineWidth: isBestValue ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(purchasingProductID != nil)
    }

    private func title(for product: Product) -> String {
        if !product.displayName.isEmpty {
            return product.displayName
        }
        switch product.id {
        case AICreditProductID.fiftyCalls:
            return "ai_credits_default_product_title_50".localized
        default:
            return "ai_credits_default_product_title".localized
        }
    }

    private func creditGrantCount(for product: Product) -> Int {
        AICreditProductID.creditAmount(for: product.id) ?? 0
    }
    
    private var usageInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("ai_credits_usage_title".localized)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            Text(usageDescription)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var restoreSection: some View {
        VStack(spacing: 4) {
            Button {
                // 对于消耗型商品，系统不支持恢复次数，这里仅保留文案提示。
            } label: {
                Text("ai_credits_restore_button".localized)
                    .font(.footnote.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            
            Text("ai_credits_restore_tip".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

#if DEBUG
struct AICreditPaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AICreditPaywallView(
                remainingCallsOverride: 235,
                usedCallsOverride: 85,
                productTitleOverride: "10 次 AI 调用",
                productPriceTextOverride: "¥3.00",
                usageDescriptionOverride: """
每次生成 AI 旅行笔记会消耗 1 次调用；
每次生成或更新 AI 旅程描述会消耗 1 次调用；
每次使用 AI 旅行推荐功能会消耗 1 次调用；调用次数长期有效，不会自动过期。
"""
            )
            .environmentObject(PurchaseManager.shared)
            .environmentObject(AICreditManager.shared)
            .preferredColorScheme(.light)
            
            AICreditPaywallView(
                remainingCallsOverride: 235,
                usedCallsOverride: 85,
                productTitleOverride: "10 次 AI 调用",
                productPriceTextOverride: "¥3.00",
                usageDescriptionOverride: """
每次生成 AI 旅行笔记会消耗 1 次调用；
每次生成或更新 AI 旅程描述会消耗 1 次调用；
每次使用 AI 旅行推荐功能会消耗 1 次调用；调用次数长期有效，不会自动过期。
"""
            )
            .environmentObject(PurchaseManager.shared)
            .environmentObject(AICreditManager.shared)
            .preferredColorScheme(.dark)
        }
    }
}
#endif

