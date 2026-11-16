//
//  AIRecommendDestinationSheet.swift
//  Footprint
//
//  从 AIAssistantView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit

struct AIRecommendDestinationSheet: View {
    let destinations: [TravelDestination]
    
    private enum RecommendPhase {
        case hub
        case active
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @StateObject private var aiManager = AIModelManager.shared
    @State private var phase: RecommendPhase = .hub
    @State private var result: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var saveSuccessMessage: String?
    @State private var showingHistory = false
    @State private var selectedSavedItem: TravelRecommendationItem?
    @State private var showCreditPaywall = false
    @State private var shareItem: TripShareItem?
    @State private var isGeneratingShareImage = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
                
                if phase == .hub {
                    recommendHubView
                } else if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("ai_generating_recommend".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    recommendErrorView(error)
                } else if !result.isEmpty {
                    recommendResultView
                } else {
                    recommendHubView
                        .onAppear { phase = .hub }
                }
            }
            .navigationTitle("ai_function_recommend_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if phase == .active {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
            .sheet(isPresented: $showingHistory) {
                SavedRecommendationsListView(selectedItem: $selectedSavedItem)
            }
            .sheet(item: $selectedSavedItem, onDismiss: { selectedSavedItem = nil }) { item in
                SavedRecommendationDetailSheet(recommendation: item.recommendation)
            }
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
            }
            .sheet(item: $shareItem) { item in
                if let image = item.image {
                    SystemShareSheet(items: [image])
                }
            }
        }
    }
    
    private var recommendHubView: some View {
        VStack(spacing: 16) {
            Text("ai_recommend_hub_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            recommendHubCard(
                icon: "clock.arrow.circlepath",
                title: "ai_recommend_view_saved".localized,
                description: "ai_recommend_view_saved_desc".localized,
                color: .orange
            ) {
                showingHistory = true
            }
            
            recommendHubCard(
                icon: "sparkles",
                title: "ai_recommend_generate_new".localized,
                description: "ai_recommend_generate_new_desc".localized,
                color: .green
            ) {
                startNewRecommendation()
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    private func recommendHubCard(
        icon: String,
        title: String,
        description: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .footprintGlassCard(cornerRadius: 16, glow: color)
        }
        .buttonStyle(.plain)
    }
    
    private func startNewRecommendation() {
        phase = .active
        performRecommend()
    }
    
    private var recommendResultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 分段展示，增强层次与可读性
                RecommendationContentCardView(content: result)
                
                if let msg = saveSuccessMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
                
                Button {
                    shareRecommendationImage(content: result, generatedAt: Date())
                } label: {
                    HStack {
                        if isGeneratingShareImage {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isGeneratingShareImage ? "share_generating".localized : "share".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isGeneratingShareImage ? Color.gray : brandColorManager.currentBrandColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isGeneratingShareImage)
                
                HStack(spacing: 12) {
                    Button {
                        saveRecommendation()
                    } label: {
                        Label("ai_save_recommend".localized, systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .footprintGlassCard(cornerRadius: 14)
                    }
                    
                    Button {
                        copyToClipboard(result)
                    } label: {
                        Label("ai_copy_result".localized, systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .footprintGlassCard(cornerRadius: 14)
                    }
                }
            }
            .padding()
        }
    }
    
    private func shareRecommendationImage(content: String, generatedAt: Date?) {
        guard !isGeneratingShareImage else { return }
        isGeneratingShareImage = true
        let applyWatermark = entitlementManager.shouldApplyShareWatermark
        
        Task { @MainActor in
            let image = ShareImageUtilities.applyingWatermarkIfNeeded(
                RecommendationShareImageGenerator.generate(content: content, generatedAt: generatedAt),
                shouldApply: applyWatermark
            )
            isGeneratingShareImage = false
            if let image {
                shareItem = TripShareItem(text: "", image: image)
            }
        }
    }
    
    private func saveRecommendation() {
        let record = TravelRecommendation(generatedAt: Date(), content: result)
        modelContext.insert(record)
        do {
            try modelContext.save()
            saveSuccessMessage = "ai_save_recommend_success".localized
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveSuccessMessage = nil
            }
        } catch {
            saveSuccessMessage = "ai_save_recommend_failed".localized
        }
    }
    
    private func recommendErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("ai_error_occurred".localized)
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                performRecommend()
            } label: {
                Text("ai_retry".localized)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(brandColorManager.currentBrandColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    private func performRecommend() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        result = ""
        
        switch aiCreditManager.gateAICall(isUnlimitedUser: entitlementManager.canUseAIFeatures) {
        case .allowed:
            break
        case .insufficientCredits:
            isLoading = false
            errorMessage = nil
            phase = .hub
            showCreditPaywall = true
            return
        case .dailyLimitReached:
            isLoading = false
            errorMessage = "ai_daily_limit_reached_message".localized
            return
        }
        
        Task {
            let text = await aiManager.recommendNextDestinations(from: destinations)
            await MainActor.run {
                isLoading = false
                let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !trimmed.isEmpty {
                    result = trimmed
                } else {
                    errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

