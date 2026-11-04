//
//  AISavedRecommendationsViews.swift
//  Footprint
//
//  从 AIAssistantView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit

struct SavedRecommendationsListView: View {
    @Binding var selectedItem: TravelRecommendationItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \TravelRecommendation.generatedAt, order: .reverse) private var list: [TravelRecommendation]
    
    var body: some View {
        NavigationStack {
            Group {
                if list.isEmpty {
                    ContentUnavailableView("ai_saved_recommend_empty_title".localized, systemImage: "doc.text.magnifyingglass", description: Text("ai_saved_recommend_empty_desc".localized))
                } else {
                    List {
                        ForEach(list, id: \.id) { item in
                            Button {
                                selectedItem = TravelRecommendationItem(item)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(formatGeneratedDate(item.generatedAt))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(item.previewText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("ai_saved_recommend_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            guard index < list.count else { continue }
            modelContext.delete(list[index])
        }
        try? modelContext.save()
    }
    
    /// 使用当前应用语言环境格式化生成日期，避免始终跟随系统语言
    private func formatGeneratedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if let languageCode = Locale.preferredLanguages.first {
            formatter.locale = Locale(identifier: languageCode)
        } else {
            formatter.locale = Locale.current
        }
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}


struct SavedRecommendationDetailSheet: View {
    let recommendation: TravelRecommendation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @State private var shareItem: TripShareItem?
    @State private var isGeneratingShareImage = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RecommendationContentCardView(content: recommendation.content)
                    
                    Button {
                        shareRecommendationImage()
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
                    
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = recommendation.content
                        #endif
                    } label: {
                        Label("ai_copy_result".localized, systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .footprintGlassCard(cornerRadius: 14)
                    }
                }
                .padding()
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle(formatGeneratedDate(recommendation.generatedAt))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                if let image = item.image {
                    SystemShareSheet(items: [image])
                }
            }
        }
    }
    
    private func shareRecommendationImage() {
        guard !isGeneratingShareImage else { return }
        isGeneratingShareImage = true
        let applyWatermark = entitlementManager.shouldApplyShareWatermark
        let content = recommendation.content
        let generatedAt = recommendation.generatedAt
        
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

    /// 使用当前应用语言环境格式化生成日期，避免始终跟随系统语言
    private func formatGeneratedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if let languageCode = Locale.preferredLanguages.first {
            formatter.locale = Locale(identifier: languageCode)
        } else {
            formatter.locale = Locale.current
        }
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// AI操作结果展示Sheet
