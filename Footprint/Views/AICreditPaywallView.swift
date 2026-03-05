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
    
    // 目标商品
    private var aiCreditProduct: Product? {
        purchaseManager.products.first { $0.id == AICreditProductID.tenCalls }
    }
    
    // 商品展示名称
    private var productTitle: String {
        if let override = productTitleOverride {
            return override
        }
        if let product = aiCreditProduct {
            return product.displayName
        }
        // StoreKit 信息未加载时的兜底标题
        return "ai_credits_default_product_title".localized
    }
    
    // 商品价格展示文本
    private var productPriceText: String {
        if let override = productPriceTextOverride {
            return override
        }
        if let product = aiCreditProduct {
            return product.displayPrice
        }
        return "¥3.00"
    }
    
    // 使用说明
    private var usageDescription: String {
        usageDescriptionOverride ?? "ai_credits_usage_desc".localized
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        counterSection
                        productSection
                        usageInfoSection
                        restoreSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
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
                // 确保产品信息已加载（如果尚未加载或失败）
                if purchaseManager.products.isEmpty && !purchaseManager.isLoading {
                    await purchaseManager.loadProducts()
                }
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
    
    private var counterSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ai_credits_remaining_label".localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Text("\(remainingCalls)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ai_credits_used_label".localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Text("\(usedCalls)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.25, blue: 0.45),
                    Color(red: 1.0, green: 0.45, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 14, x: 0, y: 8)
    }
    
    private var productSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ai_credits_buy_section_title".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Button {
                Task {
                    guard let product = aiCreditProduct else {
                        await MainActor.run {
                            purchaseManager.errorMessage = "ai_credits_product_unavailable".localized
                        }
                        return
                    }
                    _ = await purchaseManager.purchase(product)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text("ai_credits_product_subtitle".localized(with: productTitle))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(productPriceText)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

