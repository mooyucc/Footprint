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
    
    @Query private var destinations: [TravelDestination]
    @Query private var trips: [TravelTrip]
    
    @StateObject private var aiManager = AIModelManager.shared
    @State private var selectedDestination: TravelDestination?
    @State private var selectedTrip: TravelTrip?
    @State private var showingDestinationPicker = false
    @State private var showingTripPicker = false
    @State private var pendingAction: AIAction?
    @State private var showPaywall = false
    
    // 检查是否为Beta版本
    private var isBetaBuild: Bool {
        BetaInfo.isBetaBuild
    }
    
    // 检查是否有权限使用AI功能
    private var canUseAI: Bool {
        !isBetaBuild && entitlementManager.canUseAIFeatures
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 头部介绍
                    headerSection
                    
                    // 权限检查
                    if isBetaBuild {
                        // Beta版本：显示引导下载正式版
                        betaRestrictionView
                    } else if !canUseAI {
                        // 正式版但未订阅：显示订阅提示
                        subscriptionRequiredView
                    } else {
                        // 已订阅：显示AI功能列表
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
                            
                            // 标签生成
                            aiFunctionCard(
                                icon: "tag.fill",
                                title: "ai_function_tags_title".localized,
                                description: "ai_function_tags_desc".localized,
                                color: .orange,
                                isAvailable: !destinations.isEmpty
                            ) {
                                showDestinationSelector(for: .generateTags)
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
        }
    }
    
    @State private var currentAction: AIAction = .generateNotes
    
    enum AIAction {
        case generateNotes
        case generateDescription
        case generateTags
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
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }
}

/// AI操作结果展示Sheet
struct AIActionSheet: View {
    let destination: TravelDestination?
    let trip: TravelTrip?
    let action: AIAssistantView.AIAction
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var aiManager = AIModelManager.shared
    @State private var result: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
    
    private var actionTitle: String {
        switch action {
        case .generateNotes:
            return "ai_generating_notes".localized
        case .generateDescription:
            return "ai_generating_description".localized
        case .generateTags:
            return "ai_generating_tags".localized
        }
    }
    
    private var resultView: some View {
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
                    // TODO: 复制或使用结果
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
                        } else {
                            errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                        }
                    }
                }
                
            case .generateTags:
                if let destination = destination {
                    let tags = await aiManager.generateTagsFor(destination: destination)
                    await MainActor.run {
                        isLoading = false
                        if !tags.isEmpty {
                            let prefix = "ai_tags_result_prefix".localized
                            result = "\(prefix)\n\(tags.joined(separator: "、"))"
                        } else {
                            result = "ai_tags_empty".localized
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
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
    
    @EnvironmentObject private var brandColorManager: BrandColorManager
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
        .modelContainer(for: [TravelDestination.self, TravelTrip.self], inMemory: true)
}

/// AI笔记预览和编辑Sheet - 用于快速添加页面（不保存到数据库，通过回调返回）
struct AINotePreviewSheetForQuickAdd: View {
    let tempDestination: TravelDestination
    let onSave: (String) -> Void  // 回调函数，返回生成的笔记
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    
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

