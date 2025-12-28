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
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showingEditProfile = false
    @State private var showingAboutView = false
    @State private var showingGeneralSettings = false
    @State private var showingDataSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                // 账户信息
                Section {
                    if appleSignInManager.isSignedIn {
                        Button {
                            showingEditProfile = true
                        } label: {
                            HStack(spacing: 12) {
                                Group {
                                    if let avatarImage = appleSignInManager.userAvatarImage {
                                        Image(uiImage: avatarImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(.blue.gradient)
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(appleSignInManager.displayName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    if !appleSignInManager.userEmail.isEmpty {
                                        Text(appleSignInManager.userEmail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        // 第一行：身份标签和MBTI标签
                                        HStack(spacing: 6) {
                                            if !appleSignInManager.personaTag.isEmpty {
                                                Label(
                                                    UserProfileOptions.personaLocalizedValue(for: appleSignInManager.personaTag),
                                                    systemImage: "person.crop.circle.badge.questionmark"
                                                )
                                                    .font(.caption2)
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color(.secondarySystemBackground))
                                                    .clipShape(Capsule())
                                            }
                                            
                                            if !appleSignInManager.mbtiType.isEmpty {
                                                Label(appleSignInManager.mbtiType, systemImage: "brain.head.profile")
                                                    .font(.caption2)
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color(.secondarySystemBackground))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        // 第二行：星座标签
                                        if !appleSignInManager.constellation.isEmpty {
                                            HStack(spacing: 6) {
                                                Label(
                                                    UserProfileOptions.constellationLocalizedValue(for: appleSignInManager.constellation),
                                                    systemImage: "sparkles"
                                                )
                                                    .font(.caption2)
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color(.secondarySystemBackground))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
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
                            
                            // 未登录时也可以设置用户属性
                            Button {
                                showingEditProfile = true
                            } label: {
                                HStack {
                                    Text("user_profile_settings".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("account".localized)
                }
                
                // 通用设置入口
                Section {
                    Button {
                        showingGeneralSettings = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "general_settings".localized, systemImage: "gearshape", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("general_settings".localized)
                }

                // 数据设置入口
                Section {
                    Button {
                        showingDataSettings = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "data_settings".localized, systemImage: "internaldrive", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("data_settings".localized)
                }

                // 关于应用
                Section {
                    Button(action: {
                        showingAboutView = true
                    }) {
                        HStack {
                            SettingsRowLabel(title: "about_app".localized, systemImage: "info.circle", iconColor: brandColorManager.currentBrandColor)
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
            .sheet(isPresented: $showingEditProfile) {
                EditUserProfileView(
                    isLoggedIn: appleSignInManager.isSignedIn,
                    currentName: appleSignInManager.customUserName,
                    currentAvatarData: appleSignInManager.userAvatarData,
                    currentPersona: appleSignInManager.personaTag,
                    currentMbti: appleSignInManager.mbtiType,
                    currentGender: appleSignInManager.gender,
                    currentAgeGroup: appleSignInManager.ageGroup,
                    currentConstellation: appleSignInManager.constellation,
                    onSave: { newName, imageData, persona, mbti, gender, ageGroup, constellation in
                        if appleSignInManager.isSignedIn {
                            appleSignInManager.setCustomUserName(newName)
                            appleSignInManager.setUserAvatar(imageData)
                        }
                        appleSignInManager.setPersonaTag(persona)
                        appleSignInManager.setMbtiType(mbti)
                        appleSignInManager.setGender(gender)
                        appleSignInManager.setAgeGroup(ageGroup)
                        appleSignInManager.setConstellation(constellation)
                        showingEditProfile = false
                    },
                    onCancel: {
                        showingEditProfile = false
                    }
                )
            }
            .sheet(isPresented: $showingAboutView) {
                AboutView()
                    .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingGeneralSettings) {
                GeneralSettingsView(appearanceManager: AppearanceManager.shared)
                    .environmentObject(languageManager)
                    .environmentObject(countryManager)
                    .environmentObject(brandColorManager)
            }
            .sheet(isPresented: $showingDataSettings) {
                DataSettingsView()
                    .environmentObject(appleSignInManager)
                    .environmentObject(brandColorManager)
            }
        }
        .preferredColorScheme(actualColorScheme)
    }
    
    // MARK: - Helper Methods
    
    /// 获取实际使用的颜色模式（考虑系统模式）
    private var actualColorScheme: ColorScheme? {
        switch appearanceManager.currentMode {
        case .system:
            // 当跟随系统时，主动读取系统当前的颜色模式
            return appearanceManager.systemColorScheme
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
    
}

// 数据设置视图
enum BetaLocalDataIOAction {
    case importData
    case exportData
}

struct DataSettingsView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query private var allDestinations: [TravelDestination]
    
    @State private var isImportingLocalData = false
    @State private var isExportingLocalData = false
    @State private var isOptimizingImages = false
    @State private var isDeletingAccount = false
    
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteAccountSheet = false
    @State private var deleteConfirmationText = ""
    
    @State private var showingLocalImportPicker = false
    @State private var localImportURL: URL?
    @State private var backupShareItem: TripShareItem?
    @State private var importSummaryMessage: String?
    @State private var showingImportSummaryAlert = false
    @State private var backupErrorMessage: String?
    @State private var showingBackupError = false
    @State private var showingOptimizeConfirm = false
    @State private var optimizeResultMessage: String?
    @State private var showingOptimizeResult = false
    @State private var showingDeleteAccountSuccess = false
    @State private var deleteAccountErrorMessage: String?
    @State private var showingDeleteAccountError = false
    @State private var showPaywall = false
    @State private var showingBetaLocalDataIOAlert = false
    @State private var betaLocalDataIOAction: BetaLocalDataIOAction? = nil
    
    var body: some View {
        NavigationStack {
            List {
                // iCloud 同步状态（数据同步）
                Section {
                    HStack {
                        SettingsRowLabel(title: "icloud_sync".localized, systemImage: "icloud", iconColor: brandColorManager.currentBrandColor)
                        Spacer()
                        Text("in_development".localized)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        SettingsRowLabel(title: "data_storage".localized, systemImage: "externaldrive.fill.badge.icloud", iconColor: brandColorManager.currentBrandColor)
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
                    Button(action: presentLocalImportPicker) {
                        HStack {
                            SettingsRowLabel(title: "import_local_data".localized, systemImage: "square.and.arrow.down", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            if isImportingLocalData {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isImportingLocalData || isExportingLocalData || isDeletingAccount)
                    
                    Button(action: exportLocalData) {
                        HStack {
                            SettingsRowLabel(title: "export_local_data".localized, systemImage: "square.and.arrow.up", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            if isExportingLocalData {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isImportingLocalData || isExportingLocalData || isOptimizingImages || isDeletingAccount)
                    
                    Button(action: { showingOptimizeConfirm = true }) {
                        HStack {
                            SettingsRowLabel(title: "optimize_images".localized, systemImage: "photo.badge.arrow.down", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            if isOptimizingImages {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isImportingLocalData || isExportingLocalData || isOptimizingImages || isDeletingAccount)
                } header: {
                    Text("local_data".localized)
                } footer: {
                    Text("local_data_description".localized)
                }
                
                // 删除账户
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("delete_account_description".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(role: .destructive) {
                            showingDeleteAccountAlert = true
                        } label: {
                            HStack {
                                Label("delete_account".localized, systemImage: "person.crop.circle.badge.minus")
                                    .font(.headline)
                                Spacer()
                                if isDeletingAccount {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .disabled(isDeletingAccount)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("delete_account".localized)
                } footer: {
                    Text("delete_account_detail".localized)
                }
            }
            .navigationTitle("data_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseManager)
                .environmentObject(entitlementManager)
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
        .alert("delete_account_success_title".localized, isPresented: $showingDeleteAccountSuccess) {
            Button("ok".localized) {
                dismiss()
            }
        } message: {
            Text("delete_account_success_message".localized)
        }
        .alert("delete_account_error_title".localized, isPresented: $showingDeleteAccountError) {
            Button("ok".localized) { }
        } message: {
            if let message = deleteAccountErrorMessage {
                Text(message)
            }
        }
        .alert("delete_account_warning_title".localized, isPresented: $showingDeleteAccountAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete_account_confirm_button".localized, role: .destructive) {
                showingDeleteAccountSheet = true
            }
        } message: {
            Text("delete_account_warning_message".localized)
        }
        .alert("beta_local_data_io_title".localized, isPresented: $showingBetaLocalDataIOAlert) {
            Button("cancel".localized, role: .cancel) {
                betaLocalDataIOAction = nil
            }
            Button("beta_local_data_io_continue".localized) {
                if let action = betaLocalDataIOAction {
                    switch action {
                    case .importData:
                        proceedWithImport()
                    case .exportData:
                        proceedWithExport()
                    }
                }
                betaLocalDataIOAction = nil
            }
            Button("beta_local_data_io_button".localized) {
                openAppStoreForRelease()
                betaLocalDataIOAction = nil
            }
        } message: {
            Text("beta_local_data_io_message".localized)
        }
        .sheet(isPresented: $showingDeleteAccountSheet, onDismiss: {
            deleteConfirmationText = ""
        }) {
            DeleteAccountConfirmationView(
                confirmationKeyword: "delete_account_keyword".localized,
                confirmationText: $deleteConfirmationText,
                isDeletingAccount: isDeletingAccount,
                onConfirm: {
                    showingDeleteAccountSheet = false
                    deleteAccountAndData()
                },
                onCancel: {
                    showingDeleteAccountSheet = false
                }
            )
        }
        .onChange(of: localImportURL) { _, newValue in
            if let url = newValue {
                importLocalData(from: url)
            }
        }
    }
    
    // MARK: - 本地数据操作
    private func presentLocalImportPicker() {
        guard entitlementManager.canUseLocalDataIO else {
            // Beta版本显示提示但允许继续，非Beta版本显示Paywall
            if BetaInfo.isBetaBuild {
                betaLocalDataIOAction = .importData
                showingBetaLocalDataIOAlert = true
            } else {
                showPaywall = true
            }
            return
        }
        guard !isImportingLocalData else { return }
        showingLocalImportPicker = true
    }
    
    private func proceedWithImport() {
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
        guard entitlementManager.canUseLocalDataIO else {
            // Beta版本显示提示但允许继续，非Beta版本显示Paywall
            if BetaInfo.isBetaBuild {
                betaLocalDataIOAction = .exportData
                showingBetaLocalDataIOAlert = true
            } else {
                showPaywall = true
            }
            return
        }
        proceedWithExport()
    }
    
    private func proceedWithExport() {
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
    
    // MARK: - App Store
    private func openAppStoreForRelease() {
        if let url = URL(string: "https://apps.apple.com/cn/app/墨鱼足迹/id6754274652") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - 图片优化
    private func optimizeAllImages() {
        guard !isOptimizingImages else { return }
        isOptimizingImages = true
        
        Task {
            var optimizedCount = 0
            
            for destination in allDestinations {
                if let originalData = destination.photoData {
                    let processed = ImageProcessor.process(data: originalData)
                    destination.photoData = processed.0
                    destination.photoThumbnailData = processed.1
                    optimizedCount += 1
                }
                
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
                    
                    if let firstPhoto = optimizedPhotoDatas.first {
                        destination.photoData = firstPhoto
                    }
                    if let firstThumbnail = optimizedThumbnailDatas.first {
                        destination.photoThumbnailData = firstThumbnail
                    }
                }
            }
            
            do {
                try modelContext.save()
            } catch {
                print("保存优化后的图片失败: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isOptimizingImages = false
                let message = "optimize_images_success".localized(with: optimizedCount)
                optimizeResultMessage = message
                showingOptimizeResult = true
            }
        }
    }
    
    // MARK: - 删除账户
    private func deleteAccountAndData() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        
        Task { @MainActor in
            let tripsToDelete = trips
            let destinationsToDelete = allDestinations
            
            tripsToDelete.forEach { trip in
                modelContext.delete(trip)
            }
            
            destinationsToDelete.forEach { destination in
                modelContext.delete(destination)
            }
            
            do {
                try modelContext.save()
                // 发送批量删除通知，通知徽章视图更新
                NotificationCenter.default.post(name: .destinationDeleted, object: nil)
                appleSignInManager.signOut()
                showingDeleteAccountSuccess = true
            } catch {
                deleteAccountErrorMessage = error.localizedDescription
                showingDeleteAccountError = true
            }
            
            isDeletingAccount = false
        }
    }
}


// 删除账户确认视图
struct DeleteAccountConfirmationView: View {
    let confirmationKeyword: String
    @Binding var confirmationText: String
    let isDeletingAccount: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("delete_account_warning_message".localized)
                        .font(.headline)
                    Text("delete_account_detail".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("delete_account_instruction".localized(with: confirmationKeyword))
                        .font(.subheadline)
                    TextField(String(format: "delete_account_placeholder".localized, confirmationKeyword), text: $confirmationText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                }
                
                Spacer()
                
                Button(role: .destructive) {
                    onConfirm()
                    dismiss()
                } label: {
                    if isDeletingAccount {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("delete_account_confirm_button".localized)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(confirmationText != confirmationKeyword || isDeletingAccount)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("delete_account".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}


// 通用设置视图
struct GeneralSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var countryManager: CountryManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @ObservedObject var appearanceManager: AppearanceManager
    @AppStorage("mapStyle") private var mapStyleRawValue: String = MapStyle.muted.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showingLanguagePicker = false
    @State private var showingCountryPicker = false
    
    var body: some View {
        NavigationStack {
            List {
                // 语言设置
                Section {
                    Button {
                        showingLanguagePicker = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "language".localized, systemImage: "globe", iconColor: brandColorManager.currentBrandColor)
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
                    Button {
                        showingCountryPicker = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "country".localized, systemImage: "flag", iconColor: brandColorManager.currentBrandColor)
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
                
                // 外观模式设置
                Section {
                    Picker("appearance_mode".localized, selection: Binding(
                        get: { appearanceManager.currentMode },
                        set: { newMode in
                            appearanceManager.setAppearanceMode(newMode)
                        }
                    )) {
                        ForEach(AppearanceManager.AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("appearance_mode".localized)
                } footer: {
                    Text("appearance_mode_description".localized)
                }
                
                // 品牌颜色设置（外观）
                Section {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
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
                        
                        Button {
                            brandColorManager.resetBrandColorToDefault()
                        } label: {
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
                
                // 地图样式
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(MapStyle.allCases, id: \.self) { style in
                            MapStyleCard(
                                style: style,
                                isSelected: currentMapStyle == style
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    mapStyleRawValue = style.rawValue
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("map_style_title".localized)
                }
            }
            .navigationTitle("general_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(actualColorScheme)
        .sheet(isPresented: $showingLanguagePicker) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingCountryPicker) {
            CountrySelectionView()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取实际使用的颜色模式（考虑系统模式）
    private var actualColorScheme: ColorScheme? {
        switch appearanceManager.currentMode {
        case .system:
            // 当跟随系统时，主动读取系统当前的颜色模式
            return appearanceManager.systemColorScheme
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
    
    private var currentMapStyle: MapStyle {
        MapStyle(rawValue: mapStyleRawValue) ?? .muted
    }
    
    /// 获取外观模式的图标
    private func modeIcon(for mode: AppearanceManager.AppearanceMode) -> String {
        switch mode {
        case .system:
            return "circle.lefthalf.filled"
        case .dark:
            return "moon.fill"
        case .light:
            return "sun.max.fill"
        }
    }
}

// 通用设置行标签，确保文本使用系统主色而图标保留品牌色
struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let iconColor: Color
    
    var body: some View {
        Label {
            Text(title)
                .foregroundColor(.primary)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .foregroundColor(iconColor)
        }
    }
}


// 编辑用户档案视图（头像 + 用户名）
struct EditUserProfileView: View {
    let isLoggedIn: Bool  // 是否已登录
    let currentName: String
    let currentAvatarData: Data?
    let currentPersona: String
    let currentMbti: String
    let currentGender: String
    let currentAgeGroup: String
    let currentConstellation: String
    let onSave: (String, Data?, String, String, String, String, String) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var shouldRemoveAvatar = false
    @State private var showingDeleteConfirm = false
    @State private var selectedPersonaOption: String
    @State private var customPersona: String
    @State private var selectedMbti: String
    @State private var selectedGender: String
    @State private var selectedAgeGroup: String
    @State private var selectedConstellation: String
    @FocusState private var isTextFieldFocused: Bool
    
    // 使用本地化选项
    private var personaOptions: [String] {
        UserProfileOptions.localizedPersonaOptions()
    }
    
    private let mbtiOptions: [String] = [
        "INTJ","INTP","ENTJ","ENTP",
        "INFJ","INFP","ENFJ","ENFP",
        "ISTJ","ISFJ","ESTJ","ESFJ",
        "ISTP","ISFP","ESTP","ESFP"
    ]
    
    private var genderOptions: [String] {
        UserProfileOptions.localizedGenderOptions()
    }
    
    private var ageGroupOptions: [String] {
        UserProfileOptions.localizedAgeGroupOptions()
    }
    
    private var constellationOptions: [String] {
        UserProfileOptions.localizedConstellationOptions()
    }
    
    // 存储实际键值的状态变量
    @State private var storedPersonaKey: String = ""
    @State private var storedGenderKey: String = ""
    @State private var storedAgeGroupKey: String = ""
    @State private var storedConstellationKey: String = ""
    
    init(
        isLoggedIn: Bool,
        currentName: String,
        currentAvatarData: Data?,
        currentPersona: String,
        currentMbti: String,
        currentGender: String,
        currentAgeGroup: String,
        currentConstellation: String,
        onSave: @escaping (String, Data?, String, String, String, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isLoggedIn = isLoggedIn
        self.currentName = currentName
        self.currentAvatarData = currentAvatarData
        self.currentPersona = currentPersona
        self.currentMbti = currentMbti
        self.currentGender = currentGender
        self.currentAgeGroup = currentAgeGroup
        self.currentConstellation = currentConstellation
        self.onSave = onSave
        self.onCancel = onCancel
        _editedName = State(initialValue: currentName)
        
        // 转换存储值为本地化显示值
        // 处理身份标签
        let personaLocalized = UserProfileOptions.personaLocalizedValue(for: currentPersona)
        var personaKeyToStore = currentPersona
        // 检查是否是预定义选项（键值）
        if UserProfileOptions.personaKeys.contains(currentPersona) {
            personaKeyToStore = currentPersona
        } else if !currentPersona.isEmpty {
            // 可能是旧的中文值或自定义值，尝试转换
            let oldToNewMap: [String: String] = [
                "旅行家": "traveler",
                "徒步爱好者": "hiker",
                "摄影师": "photographer",
                "设计师": "designer",
                "美食家": "foodie",
                "数码玩家": "techie",
                "不愿透露": "prefer_not_to_say"
            ]
            personaKeyToStore = oldToNewMap[currentPersona] ?? currentPersona // 如果是自定义值，保持不变
        }
        let personaInOptions = UserProfileOptions.personaKeys.contains(personaKeyToStore)
        let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
        _selectedPersonaOption = State(initialValue: personaInOptions && !currentPersona.isEmpty ? personaLocalized : customOptionLocalized)
        _customPersona = State(initialValue: personaInOptions || currentPersona.isEmpty ? "" : currentPersona)
        _storedPersonaKey = State(initialValue: currentPersona.isEmpty ? "traveler" : personaKeyToStore)
        
        _selectedMbti = State(initialValue: currentMbti.isEmpty ? "INTJ" : currentMbti)
        
        // 处理性别
        let genderLocalized = UserProfileOptions.genderLocalizedValue(for: currentGender)
        let genderKeyToStore: String = {
            if UserProfileOptions.genderKeys.contains(currentGender) {
                return currentGender
            } else if !currentGender.isEmpty {
                let oldToNewMap: [String: String] = ["男": "male", "女": "female", "其他": "other", "不愿透露": "prefer_not_to_say"]
                return oldToNewMap[currentGender] ?? "prefer_not_to_say"
            }
            return "prefer_not_to_say"
        }()
        _selectedGender = State(initialValue: currentGender.isEmpty ? UserProfileOptions.localizedGender(for: "prefer_not_to_say") : genderLocalized)
        _storedGenderKey = State(initialValue: genderKeyToStore)
        
        // 处理年龄段
        let ageGroupLocalized = UserProfileOptions.ageGroupLocalizedValue(for: currentAgeGroup)
        let ageGroupKeyToStore: String = {
            if UserProfileOptions.ageGroupKeys.contains(currentAgeGroup) {
                return currentAgeGroup
            } else if !currentAgeGroup.isEmpty {
                let oldToNewMap: [String: String] = [
                    "18岁以下": "under_18", "18-25岁": "18_25", "26-35岁": "26_35",
                    "36-45岁": "36_45", "46-55岁": "46_55", "56岁以上": "over_56",
                    "不愿透露": "prefer_not_to_say"
                ]
                return oldToNewMap[currentAgeGroup] ?? "prefer_not_to_say"
            }
            return "prefer_not_to_say"
        }()
        _selectedAgeGroup = State(initialValue: currentAgeGroup.isEmpty ? UserProfileOptions.localizedAgeGroup(for: "prefer_not_to_say") : ageGroupLocalized)
        _storedAgeGroupKey = State(initialValue: ageGroupKeyToStore)
        
        // 处理星座
        let constellationLocalized = UserProfileOptions.constellationLocalizedValue(for: currentConstellation)
        let constellationKeyToStore: String = {
            if UserProfileOptions.constellationKeys.contains(currentConstellation) {
                return currentConstellation
            } else if !currentConstellation.isEmpty {
                let oldToNewMap: [String: String] = [
                    "白羊座": "aries", "金牛座": "taurus", "双子座": "gemini", "巨蟹座": "cancer",
                    "狮子座": "leo", "处女座": "virgo", "天秤座": "libra", "天蝎座": "scorpio",
                    "射手座": "sagittarius", "摩羯座": "capricorn", "水瓶座": "aquarius", "双鱼座": "pisces",
                    "不愿透露": "prefer_not_to_say"
                ]
                return oldToNewMap[currentConstellation] ?? "prefer_not_to_say"
            }
            return "prefer_not_to_say"
        }()
        _selectedConstellation = State(initialValue: currentConstellation.isEmpty ? UserProfileOptions.localizedConstellation(for: "prefer_not_to_say") : constellationLocalized)
        _storedConstellationKey = State(initialValue: constellationKeyToStore)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头像区（仅登录时显示）
                    if isLoggedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("edit_avatar".localized)
                                .font(.headline)
                            
                            Text("avatar_description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
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
                                
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    Label("select_photo".localized, systemImage: "photo")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                                
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 用户名（仅登录时显示）
                        VStack(alignment: .leading, spacing: 12) {
                            Text("custom_username".localized)
                                .font(.headline)
                            
                            Text("username_description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("enter_username".localized, text: $editedName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isTextFieldFocused)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 身份标签
                    VStack(alignment: .leading, spacing: 12) {
                        Text("identity_tag".localized)
                            .font(.headline)
                        
                        Text("identity_tag_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("identity_tag".localized, selection: $selectedPersonaOption) {
                            ForEach(personaOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedPersonaOption) { newValue in
                            storedPersonaKey = UserProfileOptions.personaKey(for: newValue)
                        }
                        
                        let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
                        if selectedPersonaOption == customOptionLocalized {
                            TextField("identity_tag_placeholder".localized, text: $customPersona)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // MBTI
                    VStack(alignment: .leading, spacing: 12) {
                        Text("mbti_title".localized)
                            .font(.headline)
                        
                        Text("mbti_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("mbti_title".localized, selection: $selectedMbti) {
                            ForEach(mbtiOptions, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 性别
                    VStack(alignment: .leading, spacing: 12) {
                        Text("gender_title".localized)
                            .font(.headline)
                        
                        Text("gender_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("gender_title".localized, selection: $selectedGender) {
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedGender) { newValue in
                            storedGenderKey = UserProfileOptions.genderKey(for: newValue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 年龄段
                    VStack(alignment: .leading, spacing: 12) {
                        Text("age_group_title".localized)
                            .font(.headline)
                        
                        Text("age_group_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("age_group_title".localized, selection: $selectedAgeGroup) {
                            ForEach(ageGroupOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedAgeGroup) { newValue in
                            storedAgeGroupKey = UserProfileOptions.ageGroupKey(for: newValue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 星座
                    VStack(alignment: .leading, spacing: 12) {
                        Text("constellation_title".localized)
                            .font(.headline)
                        
                        Text("constellation_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("constellation_title".localized, selection: $selectedConstellation) {
                            ForEach(constellationOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedConstellation) { newValue in
                            storedConstellationKey = UserProfileOptions.constellationKey(for: newValue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("account".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        let trimmedName = isLoggedIn ? editedName.trimmingCharacters(in: .whitespacesAndNewlines) : currentName
                        let finalAvatar = isLoggedIn ? (shouldRemoveAvatar ? nil : (selectedImageData ?? currentAvatarData)) : nil
                        let personaValue: String = {
                            let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
                            if selectedPersonaOption == customOptionLocalized {
                                return customPersona.trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                return storedPersonaKey
                            }
                        }()
                        let preferNotToSayGender = UserProfileOptions.localizedGender(for: "prefer_not_to_say")
                        let preferNotToSayAge = UserProfileOptions.localizedAgeGroup(for: "prefer_not_to_say")
                        let preferNotToSayConstellation = UserProfileOptions.localizedConstellation(for: "prefer_not_to_say")
                        let genderValue = selectedGender == preferNotToSayGender ? "" : storedGenderKey
                        let ageGroupValue = selectedAgeGroup == preferNotToSayAge ? "" : storedAgeGroupKey
                        let constellationValue = selectedConstellation == preferNotToSayConstellation ? "" : storedConstellationKey
                        onSave(trimmedName, finalAvatar, personaValue, selectedMbti, genderValue, ageGroupValue, constellationValue)
                    }
                    .disabled(isLoggedIn && editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let newItem = newItem {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                selectedImageData = data
                                shouldRemoveAvatar = false
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


#Preview {
    SettingsView()
        .modelContainer(for: TravelTrip.self, inMemory: true)
        .environmentObject(AppleSignInManager.shared)
        .environmentObject(LanguageManager.shared)
        .environmentObject(CountryManager.shared)
        .environmentObject(BrandColorManager.shared)
}
