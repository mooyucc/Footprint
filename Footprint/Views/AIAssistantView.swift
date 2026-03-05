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
    
    // 检查是否有权限使用AI功能（测试版开放以便测试，正式版需订阅或拥有次数）
    private var canUseAI: Bool {
        if isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 20)
            }
            .appPageBackgroundGradient(for: colorScheme)
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
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
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
                showPaywall = true
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
                showPaywall = true
            }
            return
        }
        
        pendingAction = action
        showingTripPicker = true
    }
    
    private func showRecommendDestination() {
        guard canUseAI else {
            if !isBetaBuild {
                showPaywall = true
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
                    showPaywall = true
                } label: {
                    Label("ai_upgrade_to_pro".localized, systemImage: "star.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(brandColorManager.currentBrandColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    showCreditPaywall = true
                } label: {
                    Label("ai_buy_per_use_button".localized, systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }
}

/// 旅行目的地推荐结果 Sheet（根据已记录地点推荐下一站）
struct AIRecommendDestinationSheet: View {
    let destinations: [TravelDestination]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @StateObject private var aiManager = AIModelManager.shared
    @State private var result: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var saveSuccessMessage: String?
    @State private var showingHistory = false
    @State private var selectedSavedItem: TravelRecommendationItem?
    @State private var showCreditPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorScheme.pageBackgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
                
                if isLoading {
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
                    Color.clear
                        .onAppear { performRecommend() }
                }
            }
            .navigationTitle("ai_function_recommend_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body)
                            .foregroundColor(.secondary)
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
        }
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
                
                HStack(spacing: 12) {
                    Button {
                        saveRecommendation()
                    } label: {
                        Label("ai_save_recommend".localized, systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        copyToClipboard(result)
                    } label: {
                        Label("ai_copy_result".localized, systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(brandColorManager.currentBrandColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
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
        isLoading = true
        errorMessage = nil
        result = ""
        
        let isProUser = entitlementManager.canUseAIFeatures
        if !isProUser {
            if !aiCreditManager.consumeOne() {
                isLoading = false
                errorMessage = nil
                showCreditPaywall = true
                return
            }
        }
        
        Task {
            let text = await aiManager.recommendNextDestinations(from: destinations)
            await MainActor.run {
                isLoading = false
                if let text = text {
                    result = text
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RecommendationContentCardView(content: recommendation.content)
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = recommendation.content
                        #endif
                        dismiss()
                    } label: {
                        Label("ai_copy_result".localized, systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(brandColorManager.currentBrandColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
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
struct AIActionSheet: View {
    let destination: TravelDestination?
    let trip: TravelTrip?
    let action: AIAssistantView.AIAction
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @StateObject private var aiManager = AIModelManager.shared
    @State private var result: String = ""
    @State private var editedResult: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    init(destination: TravelDestination? = nil, trip: TravelTrip? = nil, action: AIAssistantView.AIAction) {
        self.destination = destination
        self.trip = trip
        self.action = action
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorScheme.pageBackgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
                    errorView(error)
                } else if !result.isEmpty {
                    resultView
                } else {
                    // 执行AI操作
                    Color.clear
                        .onAppear {
                            performAction()
                        }
                }
            }
            .navigationTitle(actionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 旅程描述生成时显示取消和完成按钮
                if action == .generateDescription && trip != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            if isEditing {
                                // 编辑模式下，取消编辑回到预览状态
                                isEditing = false
                                isFocused = false
                                editedResult = result // 恢复原始内容
                            } else {
                                // 预览模式下，取消并关闭
                                dismiss()
                            }
                        } label: {
                            Text("cancel".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            saveDescription()
                        } label: {
                            Text("done".localized)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .fontWeight(.semibold)
                        }
                        .disabled(editedResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    // 其他操作显示关闭按钮
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
            }
        }
    }
    
    private var actionTitle: String {
        switch action {
        case .generateNotes:
            return "ai_generating_notes".localized
        case .generateDescription:
            return "ai_generating_description".localized
        }
    }
    
    private var resultView: some View {
        // 旅程描述生成时显示预览和编辑界面
        if action == .generateDescription && trip != nil {
            return AnyView(descriptionPreviewView)
        } else {
            // 其他操作显示简单的结果视图
            return AnyView(simpleResultView)
        }
    }
    
    private var descriptionPreviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 编辑提示
                if !isEditing {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                        Text("ai_note_edit_hint".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // 描述编辑器
                ZStack(alignment: .topLeading) {
                    // 占位符
                    if editedResult.isEmpty && !isFocused {
                        Text("ai_note_placeholder".localized)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $editedResult)
                        .frame(minHeight: 200)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .onTapGesture {
                    isEditing = true
                    isFocused = true
                }
                
                // 操作按钮
                if !isEditing {
                    Button {
                        isEditing = true
                        isFocused = true
                    } label: {
                        Label("ai_note_edit_button".localized, systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(brandColorManager.currentBrandColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            editedResult = result
        }
    }
    
    private var simpleResultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(result)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                
                // 操作按钮
                Button {
                    copyToClipboard(result)
                } label: {
                    Label("ai_copy_result".localized, systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(brandColorManager.currentBrandColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    private func errorView(_ error: String) -> some View {
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
                performAction()
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
    
    private func performAction() {
        isLoading = true
        errorMessage = nil
        result = ""
        
        let isProUser = entitlementManager.canUseAIFeatures
        if !isProUser {
            if !aiCreditManager.consumeOne() {
                isLoading = false
                errorMessage = nil
                // 这里不直接显示购买界面，由上层决定入口；目前仅提示不足
                return
            }
        }
        
        Task {
            switch action {
            case .generateNotes:
                if let destination = destination {
                    let notes = await aiManager.generateNotesFor(destination: destination)
                    await MainActor.run {
                        isLoading = false
                        if let notes = notes {
                            result = notes
                        } else {
                            errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                        }
                    }
                }
                
            case .generateDescription:
                if let trip = trip {
                    let description = await aiManager.generateDescriptionFor(trip: trip)
                    await MainActor.run {
                        isLoading = false
                        if let description = description {
                            result = description
                            editedResult = description
                        } else {
                            errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                        }
                    }
                }
            }
        }
    }
    
    private func formatAnalysisResult(_ analysis: ImageAnalysisResult) -> String {
        var text = ""
        
        if let sceneType = analysis.sceneType {
            text += "场景类型：\(sceneType)\n\n"
        }
        
        text += "描述：\(analysis.description)\n\n"
        
        if !analysis.mainSubjects.isEmpty {
            text += "主要物体：\(analysis.mainSubjects.joined(separator: "、"))\n\n"
        }
        
        if !analysis.suggestedTags.isEmpty {
            text += "建议标签：\(analysis.suggestedTags.joined(separator: "、"))"
        }
        
        return text
    }
    
    private func saveDescription() {
        guard let trip = trip else { return }
        
        // 更新旅程的描述
        trip.desc = editedResult.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 保存到数据库
        try? modelContext.save()
        
        // 发送更新通知
        NotificationCenter.default.post(name: .tripUpdated, object: nil)
        
        // 关闭视图
        dismiss()
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Destination Picker View

struct DestinationPickerView: View {
    let destinations: [TravelDestination]
    let onSelect: (TravelDestination) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(destinations.sorted(by: { $0.visitDate > $1.visitDate })) { destination in
                    Button {
                        onSelect(destination)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(destination.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(destination.country) · \(formatDate(destination.visitDate))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if !destination.photoDatas.isEmpty {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("选择目的地")
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
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - Trip Picker View

struct TripPickerView: View {
    let trips: [TravelTrip]
    let onSelect: (TravelTrip) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(trips.sorted(by: { $0.startDate > $1.startDate })) { trip in
                    Button {
                        onSelect(trip)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(formatDateRange(trip.startDate, trip.endDate)) · \(trip.destinationCount)个目的地")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("选择旅程")
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
        }
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - AI Note Preview Sheet

/// AI笔记预览和编辑Sheet - 用于地点预览卡片
struct AINotePreviewSheet: View {
    let destination: TravelDestination
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    
    @StateObject private var aiManager = AIModelManager.shared
    @State private var generatedNotes: String = ""
    @State private var editedNotes: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorScheme.pageBackgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("ai_generating_notes".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    errorView(error)
                } else if !generatedNotes.isEmpty {
                    notePreviewView
                } else {
                    // 自动开始生成
                    Color.clear
                        .onAppear {
                            generateNotes()
                        }
                }
            }
            .navigationTitle("ai_note_preview_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("cancel".localized)
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveNotes()
                    } label: {
                        Text("done".localized)
                            .foregroundColor(brandColorManager.currentBrandColor)
                            .fontWeight(.semibold)
                    }
                    .disabled(editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var notePreviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 编辑提示
                if !isEditing {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                        Text("ai_note_edit_hint".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // 笔记编辑器
                ZStack(alignment: .topLeading) {
                    // 占位符
                    if editedNotes.isEmpty && !isFocused {
                        Text("ai_note_placeholder".localized)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 200)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .onTapGesture {
                    isEditing = true
                    isFocused = true
                }
                
                // 操作按钮
                if !isEditing {
                    Button {
                        isEditing = true
                        isFocused = true
                    } label: {
                        Label("ai_note_edit_button".localized, systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(brandColorManager.currentBrandColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            editedNotes = generatedNotes
        }
    }
    
    private func errorView(_ error: String) -> some View {
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
                generateNotes()
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
    
    private func generateNotes() {
        isLoading = true
        errorMessage = nil
        generatedNotes = ""
        
        let isProUser = entitlementManager.canUseAIFeatures
        if !isProUser {
            if !aiCreditManager.consumeOne() {
                isLoading = false
                errorMessage = nil
                return
            }
        }
        
        Task {
            let notes = await aiManager.generateNotesFor(destination: destination)
            await MainActor.run {
                isLoading = false
                if let notes = notes {
                    generatedNotes = notes
                    editedNotes = notes
                } else {
                    errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                }
            }
        }
    }
    
    private func saveNotes() {
        // 更新地点的笔记
        destination.notes = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 保存到数据库
        try? modelContext.save()
        
        // 发送更新通知
        NotificationCenter.default.post(name: .destinationUpdated, object: nil)
        
        // 关闭视图
        dismiss()
    }
}

#Preview {
    AIAssistantView()
        .modelContainer(for: [TravelDestination.self, TravelTrip.self, TravelRecommendation.self], inMemory: true)
}

/// AI笔记预览和编辑Sheet - 用于快速添加页面（不保存到数据库，通过回调返回）
struct AINotePreviewSheetForQuickAdd: View {
    let tempDestination: TravelDestination
    let onSave: (String) -> Void  // 回调函数，返回生成的笔记
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    
    @StateObject private var aiManager = AIModelManager.shared
    @State private var generatedNotes: String = ""
    @State private var editedNotes: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorScheme.pageBackgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("ai_generating_notes".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    errorView(error)
                } else if !generatedNotes.isEmpty {
                    notePreviewView
                } else {
                    // 自动开始生成
                    Color.clear
                        .onAppear {
                            generateNotes()
                        }
                }
            }
            .navigationTitle("ai_note_preview_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("cancel".localized)
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveNotes()
                    } label: {
                        Text("done".localized)
                            .foregroundColor(brandColorManager.currentBrandColor)
                            .fontWeight(.semibold)
                    }
                    .disabled(editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var notePreviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 编辑提示
                if !isEditing {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                        Text("ai_note_edit_hint".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // 笔记编辑器
                ZStack(alignment: .topLeading) {
                    // 占位符
                    if editedNotes.isEmpty && !isFocused {
                        Text("ai_note_placeholder".localized)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 200)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .onTapGesture {
                    isEditing = true
                    isFocused = true
                }
                
                // 操作按钮
                if !isEditing {
                    Button {
                        isEditing = true
                        isFocused = true
                    } label: {
                        Label("ai_note_edit_button".localized, systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(brandColorManager.currentBrandColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            editedNotes = generatedNotes
        }
    }
    
    private func errorView(_ error: String) -> some View {
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
                generateNotes()
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
    
    private func generateNotes() {
        isLoading = true
        errorMessage = nil
        generatedNotes = ""
        
        let isProUser = entitlementManager.canUseAIFeatures
        if !isProUser {
            if !aiCreditManager.consumeOne() {
                isLoading = false
                errorMessage = nil
                return
            }
        }
        
        Task {
            let notes = await aiManager.generateNotesFor(destination: tempDestination)
            await MainActor.run {
                isLoading = false
                if let notes = notes {
                    generatedNotes = notes
                    editedNotes = notes
                } else {
                    errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                }
            }
        }
    }
    
    private func saveNotes() {
        // 通过回调返回生成的笔记，不保存到数据库
        onSave(editedNotes.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // 关闭视图
        dismiss()
    }
}

