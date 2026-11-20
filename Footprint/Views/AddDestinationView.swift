//
//  AddDestinationView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI
import MapKit

struct AddDestinationPrefill {
    var location: MKMapItem?
    var name: String?
    var country: String?
    var province: String?
    var category: String?
    var visitDate: Date?
    var photoDatas: [Data]
    var photoThumbnailDatas: [Data]

    init(
        location: MKMapItem? = nil,
        name: String? = nil,
        country: String? = nil,
        province: String? = nil,
        category: String? = nil,
        visitDate: Date? = nil,
        photoDatas: [Data] = [],
        photoThumbnailDatas: [Data] = []
    ) {
        self.location = location
        self.name = name
        self.country = country
        self.province = province
        self.category = category
        self.visitDate = visitDate
        self.photoDatas = photoDatas
        self.photoThumbnailDatas = photoThumbnailDatas
    }
}

struct AddDestinationView: View {
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query private var allDestinations: [TravelDestination]
    @StateObject private var languageManager = LanguageManager.shared
    
    // 支持从外部传入预填充数据
    private let prefill: AddDestinationPrefill?
    // 保存成功后的回调，用于关闭父窗口
    private let onSaveSuccess: (() -> Void)?
    
    @State private var name: String
    @State private var country: String
    @State private var province: String
    @State private var visitDate: Date
    @State private var notes = ""
    @State private var category: String
    @State private var type: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDatas: [Data]
    @State private var photoThumbnailDatas: [Data]
    @State private var videoData: Data?
    @State private var selectedLocation: MKMapItem?
    @State private var selectedTrip: TravelTrip?
    @State private var showDuplicateAlert = false
    @State private var duplicateDestinationName = ""
    @State private var existingDestination: TravelDestination?
    @State private var showPaywall = false
    @State private var tempDestinationForAI: TravelDestination?
    @State private var showCreditPaywall = false
    
    let categories = ["domestic", "international"]
    
    init(prefill: AddDestinationPrefill? = nil, onSaveSuccess: (() -> Void)? = nil) {
        self.prefill = prefill
        self.onSaveSuccess = onSaveSuccess
        let initialName = prefill?.name ?? ""
        let initialCountry = prefill?.country ?? ""
        let initialProvince = prefill?.province ?? ""
        let initialCategory = prefill?.category ?? "domestic"
        let initialType = ""
        let initialVisitDate = prefill?.visitDate ?? Date()
        let initialLocation = prefill?.location
        let initialPhotoDatas = prefill?.photoDatas ?? []
        let initialThumbnailDatas: [Data]
        if let prefill = prefill,
           prefill.photoThumbnailDatas.count == prefill.photoDatas.count {
            initialThumbnailDatas = prefill.photoThumbnailDatas
        } else {
            initialThumbnailDatas = initialPhotoDatas
        }
        
        _name = State(initialValue: initialName)
        _country = State(initialValue: initialCountry)
        _province = State(initialValue: initialProvince)
        _visitDate = State(initialValue: initialVisitDate)
        _category = State(initialValue: initialCategory)
        _type = State(initialValue: initialType)
        _photoDatas = State(initialValue: initialPhotoDatas)
        _photoThumbnailDatas = State(initialValue: initialThumbnailDatas)
        _selectedLocation = State(initialValue: initialLocation)
    }
    
    var body: some View {
        NavigationStack {
            FootprintFormScaffold(accent: Color.footprintRed) {
            Form {
                Section("basic_info".localized) {
                    TextField("place_name".localized, text: $name)
                    
                    Picker("category".localized, selection: $category) {
                        ForEach(categories, id: \.self) { categoryKey in
                            Text(categoryKey.localized).tag(categoryKey)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("province_state".localized, text: $province)
                    
                    TextField("country_region".localized, text: $country)
                    
                    DatePicker("visit_date".localized, selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, get24HourLocale())
                }
                
                // 使用可复用的旅程选择组件
                TripSelectionSection(selectedTrip: $selectedTrip)
                
                // 使用可复用的照片选择组件
                PhotoSelectionSection(
                    selectedPhotos: $selectedPhotos,
                    photoDatas: $photoDatas,
                    photoThumbnailDatas: $photoThumbnailDatas,
                    maxPhotos: entitlementManager.maxPhotosPerDestination
                )
                
                // 使用可复用的视频选择组件
                VideoSelectionSection(videoData: $videoData)
                
                NotesSection(
                    notes: $notes,
                    onAITap: {
                        handleAITap()
                    },
                    canUseAI: canUseAI
                )
            }
            .navigationTitle("add_destination".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveDestination()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("duplicate_destination_title".localized, isPresented: $showDuplicateAlert) {
                Button("duplicate_destination_overwrite".localized, role: .destructive) {
                    overwriteExistingDestination()
                }
                Button("duplicate_destination_cancel".localized, role: .cancel) {
                    // 取消操作，不做任何处理
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(contextMessage: "limit_destination_reached_message".localized)
                    .environmentObject(purchaseManager)
                    .environmentObject(entitlementManager)
            }
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
            }
            .sheet(item: $tempDestinationForAI) { tempDestination in
                AINotePreviewSheetForQuickAdd(
                    tempDestination: tempDestination,
                    onSave: { generatedNotes in
                        notes = generatedNotes
                    }
                )
            }
            } // FootprintFormScaffold
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !country.isEmpty && selectedLocation != nil
    }
    
    private var alertMessage: String {
        guard let existing = existingDestination else {
            return "duplicate_destination_message".localized(with: duplicateDestinationName, "", "", "")
        }
        
        let notesText = existing.notes.isEmpty ? "" : "\n备注：\(existing.notes)"
        return "duplicate_destination_message".localized(
            with: duplicateDestinationName,
            existing.country,
            existing.visitDate.localizedFormatted(dateStyle: .medium),
            notesText
        )
    }
    
    private func saveDestination() {
        guard let location = selectedLocation else { return }
        
        // 检查是否存在同名目的地
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingDestination = allDestinations.first { destination in
            destination.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedName.lowercased()
        }
        
        if let existing = existingDestination {
            // 发现重复名称，显示确认对话框
            self.existingDestination = existing
            duplicateDestinationName = trimmedName
            showDuplicateAlert = true
            return
        }
        
        // 没有重复，直接保存
        createAndSaveDestination()
    }
    
    private func createAndSaveDestination() {
        guard let location = selectedLocation else { return }

        guard entitlementManager.canAddDestination(currentCount: allDestinations.count) else {
            showPaywall = true
            return
        }
        
        let destination = TravelDestination(
            name: name,
            country: country,
            province: province,
            latitude: location.placemark.coordinate.latitude,
            longitude: location.placemark.coordinate.longitude,
            visitDate: visitDate,
            notes: notes,
            photoData: photoDatas.first,
            photoDatas: photoDatas,
            photoThumbnailData: photoThumbnailDatas.first,
            photoThumbnailDatas: photoThumbnailDatas,
            videoData: videoData,
            category: category,
            type: type
        )
        
        // 关联到旅程
        if let trip = selectedTrip {
            destination.trip = trip
        }
        
        modelContext.insert(destination)
        // 立即保存，确保 @Query 与统计更新
        try? modelContext.save()
        // 发送更新通知，通知徽章视图更新（新增目的地）
        NotificationCenter.default.post(name: .destinationUpdated, object: nil)
        
        // 如果提供了保存成功回调，先调用回调关闭父窗口
        if let onSaveSuccess = onSaveSuccess {
            onSaveSuccess()
        }
        dismiss()
    }
    
    private func overwriteExistingDestination() {
        guard let existing = existingDestination else { return }
        
        // 更新现有目的地的信息
        existing.name = name
        existing.country = country
        existing.province = province
        existing.latitude = selectedLocation?.placemark.coordinate.latitude ?? existing.latitude
        existing.longitude = selectedLocation?.placemark.coordinate.longitude ?? existing.longitude
        existing.visitDate = visitDate
        existing.notes = notes
        existing.photoData = photoDatas.first
        existing.photoDatas = photoDatas
        existing.photoThumbnailData = photoThumbnailDatas.first
        existing.photoThumbnailDatas = photoThumbnailDatas
        existing.videoData = videoData
        existing.updateHasPhotosFlag()
        existing.category = category
        existing.type = type
        
        // 更新旅程关联
        existing.trip = selectedTrip
        
        // 保存更新
        try? modelContext.save()
        // 发送更新通知，通知徽章视图更新（覆盖现有目的地）
        NotificationCenter.default.post(name: .destinationUpdated, object: nil)
        
        // 如果提供了保存成功回调，先调用回调关闭父窗口
        if let onSaveSuccess = onSaveSuccess {
            onSaveSuccess()
        }
        dismiss()
    }
    
    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }

    /// 用当前表单内容生成笔记，写回输入框，等用户点保存再入库。
    private func handleAITap() {
        guard canUseAI else {
            showCreditPaywall = true
            return
        }

        let location = selectedLocation
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = location?.name ?? location?.placemark.locality ?? ""
        guard !resolvedName.isEmpty || !fallbackName.isEmpty else { return }

        let resolvedCountry = country.isEmpty ? (location?.placemark.country ?? "") : country
        let resolvedProvince: String
        if !province.isEmpty {
            resolvedProvince = province
        } else if let location {
            resolvedProvince = CountryManager.extractProvince(
                administrativeArea: location.placemark.administrativeArea,
                locality: location.placemark.locality,
                country: location.placemark.country ?? "",
                isoCountryCode: location.placemark.isoCountryCode
            )
        } else {
            resolvedProvince = ""
        }

        tempDestinationForAI = TravelDestination(
            name: resolvedName.isEmpty ? fallbackName : resolvedName,
            country: resolvedCountry,
            province: resolvedProvince,
            latitude: location?.placemark.coordinate.latitude ?? 0,
            longitude: location?.placemark.coordinate.longitude ?? 0,
            visitDate: visitDate,
            notes: notes,
            photoData: photoDatas.first,
            photoDatas: photoDatas,
            photoThumbnailData: photoThumbnailDatas.first,
            photoThumbnailDatas: photoThumbnailDatas,
            videoData: videoData,
            category: category,
            type: type
        )
    }

    // 获取24小时制的locale（用于DatePicker显示24小时制时间）
    private func get24HourLocale() -> Locale {
        // 根据当前语言返回对应的locale，但强制使用24小时制
        let baseLocale = Locale(identifier: languageManager.currentLanguage.rawValue)
        
        // 对于中文环境，使用zh_CN但确保24小时制
        // 可以通过创建自定义locale或使用特定标识符
        switch languageManager.currentLanguage {
        case .chinese, .chineseTraditional:
            // 使用zh_CN但确保24小时制显示
            return Locale(identifier: "zh_CN")
        case .english:
            return Locale(identifier: "en_US")
        case .japanese:
            return Locale(identifier: "ja_JP")
        case .french:
            return Locale(identifier: "fr_FR")
        case .spanish:
            return Locale(identifier: "es_ES")
        case .korean:
            return Locale(identifier: "ko_KR")
        case .german:
            return Locale(identifier: "de_DE")
        }
    }
}

#Preview {
    AddDestinationView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(EntitlementManager.shared)
        .environmentObject(PurchaseManager.shared)
        .environmentObject(AICreditManager.shared)
        .environmentObject(BrandColorManager.shared)
}

