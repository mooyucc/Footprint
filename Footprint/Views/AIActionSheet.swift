//
//  AIActionSheet.swift
//  Footprint
//
//  从 AIAssistantView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit

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
    @State private var showCreditPaywall = false
    /// 防止 SwiftUI onAppear 重复触发导致连环 API 调用
    @State private var didAutoStart = false
    
    init(destination: TravelDestination? = nil, trip: TravelTrip? = nil, action: AIAssistantView.AIAction) {
        self.destination = destination
        self.trip = trip
        self.action = action
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
                    errorView(error)
                } else if !result.isEmpty {
                    resultView
                } else {
                    // 执行AI操作（仅自动启动一次）
                    Color.clear
                        .onAppear {
                            guard !didAutoStart else { return }
                            didAutoStart = true
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
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
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
                .footprintGlassCard(cornerRadius: 14)
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
                    .footprintGlassCard(cornerRadius: 14)
                
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
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        result = ""
        
        switch aiCreditManager.gateAICall(isUnlimitedUser: entitlementManager.canUseAIFeatures) {
        case .allowed:
            break
        case .insufficientCredits:
            isLoading = false
            errorMessage = "ai_subscription_required_message".localized
            showCreditPaywall = true
            return
        case .dailyLimitReached:
            isLoading = false
            errorMessage = "ai_daily_limit_reached_message".localized
            return
        }
        
        Task {
            switch action {
            case .generateNotes:
                guard let destination = destination else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "ai_error_unknown".localized
                    }
                    return
                }
                let notes = await aiManager.generateNotesFor(destination: destination)
                await MainActor.run {
                    isLoading = false
                    let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !trimmed.isEmpty {
                        result = trimmed
                    } else {
                        // 空结果视为失败，进入错误页，避免回到 onAppear 空态死循环
                        errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                    }
                }
                
            case .generateDescription:
                guard let trip = trip else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "ai_error_unknown".localized
                    }
                    return
                }
                let description = await aiManager.generateDescriptionFor(trip: trip)
                await MainActor.run {
                    isLoading = false
                    let trimmed = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !trimmed.isEmpty {
                        result = trimmed
                        editedResult = trimmed
                    } else {
                        errorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                    }
                }
            }
        }
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

