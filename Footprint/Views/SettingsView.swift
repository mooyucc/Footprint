//
//  SettingsView.swift
//  Footprint
//
//  Created on 2025/10/19.
//

import SwiftUI
import SwiftData
import AuthenticationServices
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var countryManager: CountryManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query private var allDestinations: [TravelDestination]
    @State private var showingEditName = false
    @State private var editingName = ""
    @State private var showingEditAvatar = false
    @State private var showingLanguagePicker = false
    @State private var showingCountryPicker = false
    @State private var showingLocalImportPicker = false
    @State private var localImportURL: URL?
    @State private var isImportingLocalData = false
    @State private var isExportingLocalData = false
    @State private var backupShareItem: TripShareItem?
    @State private var importSummaryMessage: String?
    @State private var showingImportSummaryAlert = false
    @State private var backupErrorMessage: String?
    @State private var showingBackupError = false
    @State private var isOptimizingImages = false
    @State private var showingOptimizeConfirm = false
    @State private var optimizeResultMessage: String?
    @State private var showingOptimizeResult = false
    @State private var showingAboutView = false
    
    var body: some View {
        NavigationStack {
            List {
                // 账户信息
                Section {
                    if appleSignInManager.isSignedIn {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // 用户头像（可点击编辑）
                                Button(action: {
                                    showingEditAvatar = true
                                }) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Group {
                                            if let avatarImage = appleSignInManager.userAvatarImage {
                                                Image(uiImage: avatarImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "person.circle.fill")
                                                    .font(.system(size: 50))
                                                    .foregroundStyle(.blue.gradient)
                                            }
                                        }
                                        
                                        // 编辑图标（右下角）
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.blue)
                                            .background(Color(.systemBackground))
                                            .clipShape(Circle())
                                            .offset(x: 4, y: 4)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(appleSignInManager.displayName)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        
                                        Button(action: {
                                            editingName = appleSignInManager.customUserName
                                            showingEditName = true
                                        }) {
                                            Image(systemName: "pencil.circle")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    if !appleSignInManager.userEmail.isEmpty {
                                        Text(appleSignInManager.userEmail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("not_logged_in".localized)
                                        .font(.headline)
                                    
                                    Text("login_sync_description".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            
                            AppleSignInButton(signInManager: appleSignInManager)
                                .frame(height: 50)
                        }
                    }
                } header: {
                    Text("account".localized)
                }
                
                // 语言设置
                Section {
                    Button(action: {
                        showingLanguagePicker = true
                    }) {
                        HStack {
                            Label("language".localized, systemImage: "globe")
                            Spacer()
                            HStack {
                                Text(languageManager.currentLanguage.flag)
                                Text(languageManager.currentLanguage.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("language".localized)
                }
                
                // 国家设置
                Section {
                    Button(action: {
                        showingCountryPicker = true
                    }) {
                        HStack {
                            Label("country".localized, systemImage: "flag")
                            Spacer()
                            HStack {
                                Text(countryManager.currentCountry.flag)
                                Text(countryManager.currentCountryLocalizedName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("country".localized)
                } footer: {
                    Text("country_description".localized)
                }
                
                // 品牌颜色设置（外观）
                Section {
                    VStack(spacing: 16) {
                        // 颜色预览和选择器（同一行）
                        HStack(spacing: 12) {
                            // 当前颜色预览
                            RoundedRectangle(cornerRadius: 12)
                                .fill(brandColorManager.currentBrandColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("brand_color".localized)
                                    .font(.headline)
                                
                                if brandColorManager.isUsingCustomColor {
                                    Text("custom_color_active".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("default_color_active".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // 颜色选择器（放在右侧）
                            ColorPicker("select_brand_color".localized, selection: Binding(
                                get: {
                                    brandColorManager.currentBrandColor
                                },
                                set: { newColor in
                                    brandColorManager.setCustomBrandColor(newColor)
                                }
                            ), supportsOpacity: false)
                            .labelsHidden()
                        }
                        .padding(.vertical, 8)
                        
                        // 恢复默认按钮（始终显示，但使用自定义颜色时才可点击）
                        Button(action: {
                            brandColorManager.resetBrandColorToDefault()
                        }) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("reset_to_default_color".localized)
                            }
                            .font(.subheadline)
                            .foregroundColor(brandColorManager.isUsingCustomColor ? .blue : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(brandColorManager.isUsingCustomColor ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .disabled(!brandColorManager.isUsingCustomColor)
                    }
                } header: {
                    Text("appearance".localized)
                } footer: {
                    Text("brand_color_description".localized)
                }
                
                // iCloud 同步状态（数据同步）
                Section {
                    HStack {
                        Label("icloud_sync".localized, systemImage: "icloud")
                        Spacer()
                        Text("in_development".localized)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("data_storage".localized, systemImage: "externaldrive.fill.badge.icloud")
                        Spacer()
                        Text(appleSignInManager.isSignedIn ? "icloud".localized : "local".localized)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("data_sync".localized)
                } footer: {
                    if appleSignInManager.isSignedIn {
                        Text("sync_description_logged_in".localized)
                    } else {
                        Text("sync_description_not_logged_in".localized)
                    }
                }
                
                // 本地数据
                Section {
                    Button(action: {
                        presentLocalImportPicker()
                    }) {
                        HStack {
                            Label("import_local_data".localized, systemImage: "square.and.arrow.down")
                            Spacer()
                            if isImportingLocalData {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isImportingLocalData || isExportingLocalData)
                    
                    Button(action: {
                        exportLocalData()
                    }) {
                        HStack {
                            Label("export_local_data".localized, systemImage: "square.and.arrow.up")
                            Spacer()
                            if isExportingLocalData {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isImportingLocalData || isExportingLocalData || isOptimizingImages)
                    
                    Button(action: {
                        showingOptimizeConfirm = true
                    }) {
                        HStack {
                            Label("optimize_images".localized, systemImage: "photo.badge.arrow.down")
                            Spacer()
                            if isOptimizingImages {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isImportingLocalData || isExportingLocalData || isOptimizingImages)
                } header: {
                    Text("local_data".localized)
                } footer: {
                    Text("local_data_description".localized)
                }
                
                // 关于应用
                Section {
                    Button(action: {
                        showingAboutView = true
                    }) {
                        HStack {
                            Label("about_app".localized, systemImage: "info.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("about".localized)
                }
                
                // 退出登录
                if appleSignInManager.isSignedIn {
                    Section {
                        Button(role: .destructive) {
                            appleSignInManager.signOut()
                        } label: {
                            HStack {
                                Spacer()
                                Label("sign_out".localized, systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditName) {
                EditUserNameView(
                    currentName: $editingName,
                    onSave: { newName in
                        appleSignInManager.setCustomUserName(newName)
                        showingEditName = false
                    },
                    onCancel: {
                        showingEditName = false
                    }
                )
            }
            .sheet(isPresented: $showingEditAvatar) {
                EditUserAvatarView(
                    currentAvatarData: appleSignInManager.userAvatarData,
                    onSave: { imageData in
                        appleSignInManager.setUserAvatar(imageData)
                        showingEditAvatar = false
                    },
                    onCancel: {
                        showingEditAvatar = false
                    }
                )
            }
            .sheet(isPresented: $showingLanguagePicker) {
                LanguageSelectionView()
            }
            .sheet(isPresented: $showingCountryPicker) {
                CountrySelectionView()
            }
            .sheet(isPresented: $showingAboutView) {
                AboutView()
                    .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingLocalImportPicker) {
                DocumentPicker(selectedURL: $localImportURL)
            }
            .sheet(item: $backupShareItem) { item in
                if let url = item.url {
                    SystemShareSheet(items: [url])
                } else {
                    SystemShareSheet(items: [item.text])
                }
            }
            .alert("local_import_summary_title".localized, isPresented: $showingImportSummaryAlert) {
                Button("ok".localized) { }
            } message: {
                if let message = importSummaryMessage {
                    Text(message)
                }
            }
            .alert("local_backup_error_title".localized, isPresented: $showingBackupError) {
                Button("ok".localized) { }
            } message: {
                if let message = backupErrorMessage {
                    Text(message)
                }
            }
            .alert("optimize_images_confirm_title".localized, isPresented: $showingOptimizeConfirm) {
                Button("cancel".localized) { }
                Button("optimize".localized) {
                    optimizeAllImages()
                }
            } message: {
                Text("optimize_images_confirm_message".localized)
            }
            .alert("optimize_images_result_title".localized, isPresented: $showingOptimizeResult) {
                Button("ok".localized) { }
            } message: {
                if let message = optimizeResultMessage {
                    Text(message)
                }
            }
            .onChange(of: localImportURL) { _, newValue in
                if let url = newValue {
                    importLocalData(from: url)
                }
            }
        }
    }
    
    // MARK: - 本地数据操作
    private func presentLocalImportPicker() {
        guard !isImportingLocalData else { return }
        showingLocalImportPicker = true
    }
    
    private func importLocalData(from url: URL) {
        guard !isImportingLocalData else { return }
        isImportingLocalData = true
        defer {
            localImportURL = nil
            isImportingLocalData = false
        }
        
        let result = LocalDataBackupManager.importAllTrips(from: url, modelContext: modelContext)
        switch result {
        case .success(let summary):
            var message = "local_import_summary_success".localized(with: summary.importedCount)
            if summary.duplicateCount > 0 {
                message += "\n" + "local_import_summary_duplicates".localized(with: summary.duplicateCount)
            }
            if summary.hasFailures {
                message += "\n" + "local_import_summary_failures".localized(with: summary.failedMessages.count)
                let details = summary.failedMessages.map { "• \($0)" }.joined(separator: "\n")
                message += "\n" + details
            }
            importSummaryMessage = message
            showingImportSummaryAlert = true
        case .failure(let error):
            backupErrorMessage = error.localizedDescription
            showingBackupError = true
        }
    }
    
    private func exportLocalData() {
        guard !isExportingLocalData else { return }
        isExportingLocalData = true
        defer {
            isExportingLocalData = false
        }
        
        let result = LocalDataBackupManager.exportAllTrips(modelContext: modelContext)
        switch result {
        case .success(let url):
            backupShareItem = TripShareItem(
                text: "local_backup_share_text".localized,
                image: nil,
                url: url
            )
        case .failure(let error):
            backupErrorMessage = error.localizedDescription
            showingBackupError = true
        }
    }
    
    // MARK: - 图片优化
    private func optimizeAllImages() {
        guard !isOptimizingImages else { return }
        isOptimizingImages = true
        
        Task {
            var optimizedCount = 0
            
            // 优化所有图片
            for destination in allDestinations {
                // 处理单张图片（旧版）
                if let originalData = destination.photoData {
                    let processed = ImageProcessor.process(data: originalData)
                    destination.photoData = processed.0
                    destination.photoThumbnailData = processed.1
                    optimizedCount += 1
                }
                
                // 处理多张图片（新版）
                if !destination.photoDatas.isEmpty {
                    var optimizedPhotoDatas: [Data] = []
                    var optimizedThumbnailDatas: [Data] = []
                    
                    for photoData in destination.photoDatas {
                        let processed = ImageProcessor.process(data: photoData)
                        optimizedPhotoDatas.append(processed.0)
                        optimizedThumbnailDatas.append(processed.1)
                        optimizedCount += 1
                    }
                    
                    destination.photoDatas = optimizedPhotoDatas
                    destination.photoThumbnailDatas = optimizedThumbnailDatas
                    
                    // 更新单张图片字段（保持兼容性）
                    if let firstPhoto = optimizedPhotoDatas.first {
                        destination.photoData = firstPhoto
                    }
                    if let firstThumbnail = optimizedThumbnailDatas.first {
                        destination.photoThumbnailData = firstThumbnail
                    }
                }
            }
            
            // 保存更改
            do {
                try modelContext.save()
            } catch {
                print("保存优化后的图片失败: \(error.localizedDescription)")
            }
            
            // 显示结果
            await MainActor.run {
                isOptimizingImages = false
                let message = "optimize_images_success".localized(with: optimizedCount)
                optimizeResultMessage = message
                showingOptimizeResult = true
            }
        }
    }
}

// 编辑用户头像视图
struct EditUserAvatarView: View {
    let currentAvatarData: Data?
    let onSave: (Data?) -> Void
    let onCancel: () -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var shouldRemoveAvatar = false
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("edit_avatar".localized)
                        .font(.headline)
                    
                    Text("avatar_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 头像预览
                VStack(spacing: 16) {
                    Group {
                        if shouldRemoveAvatar {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 120))
                                .foregroundStyle(.blue.gradient)
                        } else if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if let currentData = currentAvatarData, let uiImage = UIImage(data: currentData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 120))
                                .foregroundStyle(.blue.gradient)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    )
                    
                    // 选择照片按钮
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("select_photo".localized, systemImage: "photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    // 删除头像按钮（仅在有头像时显示）
                    if currentAvatarData != nil || selectedImageData != nil {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label(shouldRemoveAvatar ? "restore_avatar".localized : "remove_avatar".localized, systemImage: shouldRemoveAvatar ? "arrow.uturn.backward" : "trash")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.vertical)
                
                Spacer()
            }
            .padding()
            .navigationTitle("edit_avatar".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        if shouldRemoveAvatar {
                            onSave(nil)
                        } else {
                            onSave(selectedImageData ?? currentAvatarData)
                        }
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let newItem = newItem {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                selectedImageData = data
                                shouldRemoveAvatar = false // 选择新图片时取消删除标记
                            }
                        }
                    }
                }
            }
            .alert("remove_avatar_confirm_title".localized, isPresented: $showingDeleteConfirm) {
                Button("cancel".localized, role: .cancel) { }
                Button("remove".localized, role: .destructive) {
                    shouldRemoveAvatar = true
                    selectedImageData = nil
                }
            } message: {
                Text("remove_avatar_confirm_message".localized)
            }
        }
    }
}

// 编辑用户名视图
struct EditUserNameView: View {
    @Binding var currentName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("custom_username".localized)
                        .font(.headline)
                    
                    Text("username_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("enter_username".localized, text: $editedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onAppear {
                        editedName = currentName
                        isTextFieldFocused = true
                    }
                
                Spacer()
            }
            .padding()
            .navigationTitle("edit_username".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        onSave(editedName)
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


#Preview {
    SettingsView()
        .modelContainer(for: TravelTrip.self, inMemory: true)
        .environmentObject(AppleSignInManager.shared)
        .environmentObject(LanguageManager.shared)
        .environmentObject(CountryManager.shared)
        .environmentObject(BrandColorManager.shared)
}