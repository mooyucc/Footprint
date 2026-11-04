//
//  DataSettingsView.swift
//  Footprint
//
//  从 SettingsView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit
import UniformTypeIdentifiers
import UIKit

enum BetaLocalDataIOAction {
    case importData
    case exportData
}


struct DataSettingsView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
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
    /// 批量优化图片时的进度：(已处理数, 总数)
    @State private var optimizeImagesProgress: (current: Int, total: Int)? = nil
    @State private var showingDeleteAccountSuccess = false
    @State private var deleteAccountErrorMessage: String?
    @State private var showingDeleteAccountError = false
    @State private var showPaywall = false
    @State private var showingBetaLocalDataIOAlert = false
    @State private var betaLocalDataIOAction: BetaLocalDataIOAction? = nil
    
    var body: some View {
        NavigationStack {
            FootprintFormScaffold(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
            List {
                // iCloud 同步状态（依赖系统 Apple ID / iCloud，与 App 登录无关）
                Section {
                    HStack {
                        SettingsRowLabel(title: "icloud_sync".localized, systemImage: "icloud", iconColor: brandColorManager.currentBrandColor)
                        Spacer()
                        Text(userProfileManager.isICloudAvailable ? "icloud_sync_on".localized : "local".localized)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("data_sync".localized)
                } footer: {
                    Text(userProfileManager.isICloudAvailable ? "sync_description_icloud".localized : "sync_description_local".localized)
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
            .overlay {
                if let progress = optimizeImagesProgress, progress.total > 0 {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView(value: Double(progress.current) / Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(width: 220)
                        Text("optimize_images".localized + " \(progress.current)/\(progress.total)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            } // FootprintFormScaffold
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
            if summary.standaloneDestinationsImported > 0 {
                message += "\n" + "local_import_summary_standalone_destinations".localized(with: summary.standaloneDestinationsImported)
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
            
            // 在主线程上获取当前的目的地列表快照和需要处理的总图片数量，避免在后台线程直接访问 @Query
            let (destinations, totalToOptimize) = await MainActor.run { () -> ([TravelDestination], Int) in
                let destinations = allDestinations
                let total = destinations.reduce(0) { partial, dest in
                    let single = dest.photoData != nil ? 1 : 0
                    return partial + single + dest.photoDatas.count
                }
                return (destinations, total)
            }
            
            await MainActor.run {
                if totalToOptimize > 0 {
                    optimizeImagesProgress = (0, totalToOptimize)
                } else {
                    optimizeImagesProgress = nil
                }
            }
            
            if totalToOptimize == 0 {
                await MainActor.run {
                    isOptimizingImages = false
                    let message = "optimize_images_success".localized(with: 0)
                    optimizeResultMessage = message
                    showingOptimizeResult = true
                }
                return
            }
            
            for destination in destinations {
                // 先在主线程读取需要处理的原始数据副本
                let singlePhotoData: Data? = await MainActor.run {
                    destination.photoData
                }
                let multiplePhotoDatas: [Data] = await MainActor.run {
                    Array(destination.photoDatas)
                }
                
                // 在后台线程执行耗时的图像处理
                if let originalData = singlePhotoData {
                    let processed = ImageProcessor.process(data: originalData)
                    optimizedCount += 1
                    
                    await MainActor.run {
                        optimizeImagesProgress = (optimizedCount, totalToOptimize)
                    }
                    
                    // 处理完成后回到主线程更新 SwiftData 模型
                    await MainActor.run {
                        destination.photoData = processed.0
                        destination.photoThumbnailData = processed.1
                    }
                }
                
                if !multiplePhotoDatas.isEmpty {
                    var optimizedPhotoDatas: [Data] = []
                    var optimizedThumbnailDatas: [Data] = []
                    
                    for photoData in multiplePhotoDatas {
                        let processed = ImageProcessor.process(data: photoData)
                        optimizedPhotoDatas.append(processed.0)
                        optimizedThumbnailDatas.append(processed.1)
                        optimizedCount += 1
                        
                         await MainActor.run {
                             optimizeImagesProgress = (optimizedCount, totalToOptimize)
                         }
                    }
                    
                    await MainActor.run {
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
            }
            
            await MainActor.run {
                do {
                    try modelContext.save()
                } catch {
                    print("保存优化后的图片失败: \(error.localizedDescription)")
                }
                
                isOptimizingImages = false
                optimizeImagesProgress = nil
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
                userProfileManager.resetProfile()
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
