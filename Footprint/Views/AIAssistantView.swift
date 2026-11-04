//
//  AIAssistantView.swift
//  Footprint
//
//  Created on 2025/01/27.
//  AI助手主界面
//

import SwiftUI
import SwiftData
import StoreKit

/// AI助手主界面
/// 展示可用的AI功能列表
struct AIAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    
    @Query private var destinations: [TravelDestination]
    @Query private var trips: [TravelTrip]
    
    @StateObject private var aiManager = AIModelManager.shared
    @State private var selectedDestination: TravelDestination?
    @State private var selectedTrip: TravelTrip?
    @State private var showingDestinationPicker = false
    @State private var showingTripPicker = false
    @State private var pendingAction: AIAction?
    @State private var showPaywall = false
    @State private var showCreditPaywall = false
    
    // 检查是否为Beta版本
    private var isBetaBuild: Bool {
        BetaInfo.isBetaBuild
    }
    
    // 检查是否有权限使用AI功能（测试版开放以便测试；正式版需兼容无限 AI 或剩余次数）
    private var canUseAI: Bool {
        if isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    var body: some View {
        NavigationStack {
            FootprintHubScaffold(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
                // 头部介绍
                headerSection
                
                // 权限检查
                if !canUseAI {
                    // 正式版但未订阅：显示订阅提示
                    subscriptionRequiredView
                } else {
                    // 已订阅或测试版：显示AI功能列表
                    VStack(spacing: 16) {
                        // 智能笔记生成
                        aiFunctionCard(
                            icon: "sparkles",
                            title: "ai_function_notes_title".localized,
                            description: "ai_function_notes_desc".localized,
                            color: .blue,
                            isAvailable: !destinations.isEmpty
                        ) {
                            showDestinationSelector(for: .generateNotes)
                        }
                        
                        // 旅程描述生成
                        aiFunctionCard(
                            icon: "map",
                            title: "ai_function_trip_desc_title".localized,
                            description: "ai_function_trip_desc_desc".localized,
                            color: .purple,
                            isAvailable: !trips.isEmpty
                        ) {
                            showTripSelector(for: .generateDescription)
                        }
                        
                        // 旅行目的地推荐
                        aiFunctionCard(
                            icon: "airplane.departure",
                            title: "ai_function_recommend_title".localized,
                            description: "ai_function_recommend_desc".localized,
                            color: .green,
                            isAvailable: !destinations.isEmpty
                        ) {
                            showRecommendDestination()
                        }
                    }
                }
            }
            .navigationTitle("ai_assistant_title".localized)
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(isPresented: $showingDestinationPicker) {
                DestinationPickerView(destinations: destinations) { destination in
                    selectedDestination = destination
                    currentAction = pendingAction ?? .generateNotes
                    showingDestinationPicker = false
                }
            }
            .sheet(isPresented: $showingTripPicker) {
                TripPickerView(trips: trips) { trip in
                    selectedTrip = trip
                    currentAction = pendingAction ?? .generateDescription
                    showingTripPicker = false
                }
            }
            .sheet(item: $selectedDestination) { destination in
                AIActionSheet(destination: destination, action: currentAction)
            }
            .sheet(item: $selectedTrip) { trip in
                AIActionSheet(trip: trip, action: currentAction)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
            }
            .sheet(isPresented: $showingRecommendSheet) {
                AIRecommendDestinationSheet(destinations: destinations)
            }
        }
    }
    
    @State private var currentAction: AIAction = .generateNotes
    @State private var showingRecommendSheet = false
    
    enum AIAction {
        case generateNotes
        case generateDescription
    }
    
    // MARK: - Views
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [brandColorManager.currentBrandColor, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
            
            Text("ai_assistant_welcome".localized)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("ai_assistant_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 20)
    }
    
    private func aiFunctionCard(
        icon: String,
        title: String,
        description: String,
        color: Color,
        isAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                // 文字内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .footprintGlassCard(cornerRadius: 16, glow: isAvailable ? color : nil)
            .opacity(isAvailable ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
    
    // MARK: - Actions
    
    private func showDestinationSelector(for action: AIAction) {
        // 检查权限
        guard canUseAI else {
            if !isBetaBuild {
                showCreditPaywall = true
            }
            return
        }
        
        pendingAction = action
        showingDestinationPicker = true
    }
    
    private func showTripSelector(for action: AIAction) {
        // 检查权限
        guard canUseAI else {
            if !isBetaBuild {
                showCreditPaywall = true
            }
            return
        }
        
        pendingAction = action
        showingTripPicker = true
    }
    
    private func showRecommendDestination() {
        guard canUseAI else {
            if !isBetaBuild {
                showCreditPaywall = true
            }
            return
        }
        showingRecommendSheet = true
    }
    
    // MARK: - Beta限制视图
    
    private var betaRestrictionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("ai_beta_not_available_title".localized)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("ai_beta_not_available_message".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                // 打开App Store下载正式版
                if let url = URL(string: "https://apps.apple.com/app/id6739095075") {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #endif
                }
            } label: {
                Label("ai_download_full_version".localized, systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(brandColorManager.currentBrandColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 订阅要求视图
    
    private var subscriptionRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [brandColorManager.currentBrandColor, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("ai_subscription_required_title".localized)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("ai_subscription_required_message".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(spacing: 12) {
                Button {
                    showCreditPaywall = true
                } label: {
                    Label("ai_buy_per_use_button".localized, systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(brandColorManager.currentBrandColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    showPaywall = true
                } label: {
                    Label("ai_upgrade_to_pro".localized, systemImage: "star.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .tint(brandColorManager.currentBrandColor)
                .controlSize(.large)
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .footprintGlassCard(glow: brandColorManager.currentBrandColor)
    }
}

/// 旅行目的地推荐结果 Sheet（根据已记录地点推荐下一站）
