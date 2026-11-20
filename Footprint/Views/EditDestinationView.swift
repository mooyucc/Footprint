//
//  EditDestinationView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI
// import removed: UniformTypeIdentifiers (不再需要拖拽)

struct EditDestinationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @StateObject private var languageManager = LanguageManager.shared
    
    let destination: TravelDestination
    
    @State private var name = ""
    @State private var country = ""
    @State private var province = ""
    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var category = "international"
    @State private var type = ""
    @State private var isFavorite = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    // 为每张图片分配唯一 ID，避免 ForEach 标识冲突
    struct PhotoItem: Identifiable, Equatable {
        let id: UUID
        var data: Data
        var thumbnailData: Data
        static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool { lhs.id == rhs.id }
    }
    @State private var photoItems: [PhotoItem] = []
    @State private var videoData: Data?
    @State private var selectedTrip: TravelTrip?
    @State private var showDeleteConfirmation = false
    @State private var tempDestinationForAI: TravelDestination?
    @State private var showCreditPaywall = false
    
    let categories = ["domestic", "international"]
    private var maxPhotos: Int {
        entitlementManager.maxPhotosPerDestination
    }
    
    init(destination: TravelDestination) {
        self.destination = destination
    }
    
    var body: some View {
        NavigationStack {
            FootprintFormScaffold(accent: Color.footprintRed) {
            Form {
                Section("basic_info".localized) {
                    TextField("location_tag".localized, text: $name)
                    
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
                    
                    Toggle("mark_as_favorite".localized, isOn: $isFavorite)
                }
                
                if !trips.isEmpty {
                    Section("belongs_to_trip_optional".localized) {
                        Picker("select_trip".localized, selection: $selectedTrip) {
                            Text("none".localized).tag(nil as TravelTrip?)
                            ForEach(trips) { trip in
                                Text(trip.name).tag(trip as TravelTrip?)
                            }
                        }
                        
                        if let trip = selectedTrip {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.name)
                                        .font(.caption)
                                    Text("\(trip.startDate.localizedFormatted(dateStyle: .medium)) - \(trip.endDate.localizedFormatted(dateStyle: .medium))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("photo".localized) {
                    if !photoItems.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                            ForEach(photoItems) { item in
                                if let uiImage = UIImage(data: item.thumbnailData) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                            .contentShape(Rectangle())

                                        // ❌ 删除单张照片
                                        Button {
                                            if let index = photoItems.firstIndex(where: { $0.id == item.id }) {
                                                photoItems.remove(at: index)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .contentShape(Circle())
                                        .buttonStyle(.plain)
                                        .padding(4)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    let remaining = max(0, maxPhotos - photoItems.count)
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: remaining == 0 ? 1 : remaining, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(Color.footprintRed)
                            Text("add_photo".localized)
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(remaining == 0)
                }
                
                // 使用可复用的视频选择组件
                VideoSelectionSection(videoData: $videoData)
                
                NotesSection(
                    notes: $notes,
                    onAITap: {
                        handleAITap()
                    },
                    canUseAI: canUseAI
                )
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("delete".localized)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("edit_destination".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadDestinationData()
            }
            .alert("delete_destination".localized, isPresented: $showDeleteConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("delete".localized, role: .destructive) {
                    deleteDestination()
                }
            } message: {
                Text("confirm_delete_destination".localized(with: destination.name))
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
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    // 载入当前选择的所有图片数据
                    var processed: [(Data, Data)] = []
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            let result = ImageProcessor.process(data: data)
                            processed.append(result)
                        }
                    }
                    // 去重并截断到上限：避免同一张图片重复加入，且不超过 9 张
                    if !processed.isEmpty {
                        let capacity = max(0, maxPhotos - photoItems.count)
                        if capacity > 0 {
                            let limited = Array(processed.prefix(capacity))
                            let newItems = limited.compactMap { pair -> PhotoItem? in
                                let (data, thumbnail) = pair
                                if photoItems.contains(where: { $0.data == data }) {
                                    return nil
                                }
                                return PhotoItem(id: UUID(), data: data, thumbnailData: thumbnail)
                            }
                            if !newItems.isEmpty {
                                await MainActor.run { photoItems.append(contentsOf: newItems) }
                            }
                        }
                    }
                    // 清空选择，避免 PhotosPicker 维持累积选择导致再次触发重复添加
                    await MainActor.run { selectedPhotos = [] }
                }
            }
            } // FootprintFormScaffold
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !country.isEmpty
    }

    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }

    /// 用当前编辑内容生成笔记，写回输入框，随表单一并保存。
    private func handleAITap() {
        guard canUseAI else {
            showCreditPaywall = true
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty || !destination.name.isEmpty else { return }

        let datas = photoItems.map(\.data)
        let thumbnails = photoItems.map(\.thumbnailData)
        tempDestinationForAI = TravelDestination(
            name: trimmedName.isEmpty ? destination.name : trimmedName,
            country: country.isEmpty ? destination.country : country,
            province: province,
            latitude: destination.latitude,
            longitude: destination.longitude,
            visitDate: visitDate,
            notes: notes,
            photoData: datas.first,
            photoDatas: datas,
            photoThumbnailData: thumbnails.first,
            photoThumbnailDatas: thumbnails,
            videoData: videoData,
            category: category,
            type: type,
            isFavorite: isFavorite
        )
    }
    
    private func loadDestinationData() {
        name = destination.name
        country = destination.country
        province = destination.province
        visitDate = destination.visitDate
        notes = destination.notes
        category = destination.category
        type = destination.type
        isFavorite = destination.isFavorite
        // 兼容旧数据：若数组为空但有单张照片，则填充为数组
        var datas = destination.photoDatas
        if datas.isEmpty, let single = destination.photoData { datas = [single] }
        var thumbnails = destination.photoThumbnailDatas
        if thumbnails.isEmpty, let singleThumb = destination.photoThumbnailData { thumbnails = [singleThumb] }
        
        photoItems = datas.enumerated().map { index, data in
            if index < thumbnails.count {
                return PhotoItem(id: UUID(), data: data, thumbnailData: thumbnails[index])
            } else {
                let processed = ImageProcessor.process(data: data)
                return PhotoItem(id: UUID(), data: processed.0, thumbnailData: processed.1)
            }
        }
        videoData = destination.videoData
        selectedTrip = destination.trip
    }
    
    private func saveChanges() {
        // 更新目的地信息（坐标保持创建时的值，编辑页不再修改）
        destination.name = name
        destination.country = country
        destination.province = province
        destination.visitDate = visitDate
        destination.notes = notes
        destination.category = category
        destination.type = type
        destination.isFavorite = isFavorite
        let datasToSave = photoItems.map { $0.data }
        let thumbnailsToSave = photoItems.map { $0.thumbnailData }
        destination.photoDatas = datasToSave
        destination.photoData = datasToSave.first
        destination.photoThumbnailDatas = thumbnailsToSave
        destination.photoThumbnailData = thumbnailsToSave.first
        destination.videoData = videoData
        destination.updateHasPhotosFlag()
        destination.trip = selectedTrip
        
        // 显式保存更改，确保数据已同步
        try? modelContext.save()
        
        // 发送更新通知，通知徽章视图更新
        // 延迟一小段时间，确保 SwiftData 的保存操作已完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .destinationUpdated, object: nil)
        }
        
        dismiss()
    }
    
    private func deleteDestination() {
        let destinationId = destination.id
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.delete(destination)
            try? modelContext.save()
            // 发送删除通知，由上层视图根据需要关闭详情页 / 编辑页
            NotificationCenter.default.post(name: .destinationDeleted, object: nil, userInfo: ["destinationId": destinationId])
        }
    }
    
    // 获取24小时制的locale（用于DatePicker显示24小时制时间）
    private func get24HourLocale() -> Locale {
        // 根据当前语言返回对应的locale，但强制使用24小时制
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

// 拖拽排序功能已取消

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TravelDestination.self, configurations: config)
    let destination = TravelDestination(
        name: "测试地点",
        country: "测试国家",
        latitude: 39.9042,
        longitude: 116.4074,
        visitDate: Date(),
        notes: "测试笔记",
        category: "domestic",
        isFavorite: true
    )
    container.mainContext.insert(destination)
    
    return EditDestinationView(destination: destination)
        .modelContainer(container)
        .environmentObject(EntitlementManager.shared)
        .environmentObject(AICreditManager.shared)
        .environmentObject(BrandColorManager.shared)
}

