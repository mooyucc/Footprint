//
//  AINotePreviewSheets.swift
//  Footprint
//
//  从 AIAssistantView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit

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
    @State private var showCreditPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
                
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
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
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
                showCreditPaywall = true
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
    @State private var showCreditPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
                
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
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
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
                showCreditPaywall = true
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

