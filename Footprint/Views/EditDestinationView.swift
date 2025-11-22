//
//  EditDestinationView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import CoreLocation
import Contacts
// import removed: UniformTypeIdentifiers (不再需要拖拽)

struct EditDestinationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @StateObject private var languageManager = LanguageManager.shared
    
    let destination: TravelDestination
    
    @State private var name = ""
    @State private var country = ""
    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var category = "international"
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
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var selectedTrip: TravelTrip?
    @State private var showDeleteConfirmation = false
    
    let categories = ["domestic", "international"]
    private let maxPhotos = 9
    
    // 城市数据管理器实例
    private let cityDataManager = CityDataManager.shared
    
    init(destination: TravelDestination) {
        self.destination = destination
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("basic_info".localized) {
                    TextField("place_name".localized, text: $name)
                    
                    Picker("category".localized, selection: $category) {
                        ForEach(categories, id: \.self) { categoryKey in
                            Text(categoryKey.localized).tag(categoryKey)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("country_region".localized, text: $country)
                    
                    DatePicker("visit_date".localized, selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
                    
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
                
                Section("location_info".localized) {
                    HStack {
                        TextField("search_place".localized, text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("search".localized) {
                            searchLocation()
                        }
                        .disabled(searchText.isEmpty)
                    }
                    
                    NavigationLink {
                        MapCoordinatePickerView(
                            initialCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        ) { item in
                            // 从地图选点回填
                            self.selectedLocation = item
                            self.latitude = item.placemark.coordinate.latitude
                            self.longitude = item.placemark.coordinate.longitude
                            if let countryName = item.placemark.country, !countryName.isEmpty {
                                self.country = countryName
                            }
                            // 名称不强制覆盖，保留用户原名称
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                            Text("在地图上选点")
                        }
                    }
                    
                    if isSearching {
                        ProgressView()
                    }
                    
                    ForEach(searchResults, id: \.self) { item in
                        Button {
                            selectLocation(item)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "unknown_place".localized)
                                    .foregroundColor(.primary)
                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if let location = selectedLocation {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("selected".localized + (location.name ?? ""))
                                    .font(.caption)
                                Text("latitude_longitude".localized(with: location.placemark.coordinate.latitude, location.placemark.coordinate.longitude))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("current_location".localized)
                                    .font(.caption)
                                Text("latitude_longitude".localized(with: latitude, longitude))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
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
                        Label("add_photo".localized, systemImage: "photo")
                    }
                    .disabled(remaining == 0)
                }
                
                Section("notes".localized) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
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
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !country.isEmpty
    }
    
    private func loadDestinationData() {
        name = destination.name
        country = destination.country
        visitDate = destination.visitDate
        notes = destination.notes
        category = destination.category
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
        latitude = destination.latitude
        longitude = destination.longitude
        selectedTrip = destination.trip
    }
    
    private func searchLocation() {
        isSearching = true
        searchResults = []
        
        // 🎯 优化策略：根据分类选择不同的搜索方式
        if category == "domestic" {
            // 国内搜索：优先使用高德地图数据（通过 MKLocalSearch）
            searchDomesticWithLocalData()
        } else {
            // 国外搜索：优先使用 Apple 国际数据（通过网络 API）
            searchInternationalWithAppleData()
        }
    }
    
    // 🇨🇳 国内搜索：使用高德地图数据（通过 MKLocalSearch）
    private func searchDomesticWithLocalData() {
        print("🇨🇳 [编辑] 使用高德地图数据搜索国内地点: \(searchText)")
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        
        // 设置搜索区域为中国（提高搜索准确性）
        let chinaRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954), // 中国中心点
            span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 60.0) // 覆盖中国全境
        )
        searchRequest.region = chinaRegion
        
        // 设置结果类型
        if #available(iOS 13.0, *) {
            searchRequest.resultTypes = [.address, .pointOfInterest]
        }
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("❌ [编辑] 高德地图搜索错误: \(error.localizedDescription)")
                    // 如果高德搜索失败，尝试 CLGeocoder
                    self.fallbackToCLGeocoderForChina()
                    return
                }
                
                if let response = response {
                    self.searchResults = response.mapItems
                    print("✅ [编辑] 高德地图找到 \(response.mapItems.count) 个国内地点")
                } else {
                    print("⚠️ [编辑] 高德地图未找到结果，尝试备用搜索")
                    self.fallbackToCLGeocoderForChina()
                }
            }
        }
    }
    
    // 备用国内搜索：使用 CLGeocoder
    private func fallbackToCLGeocoderForChina() {
        print("🔄 [编辑] 备用搜索：使用 CLGeocoder 搜索国内地点")
        
        let domesticQuery = searchText.contains("中国") ? searchText : "\(searchText), 中国"
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(domesticQuery) { placemarks, error in
            DispatchQueue.main.async {
                if let placemarks = placemarks, !placemarks.isEmpty {
                    // 过滤出中国的地点
                    let chinesePlaces = placemarks.filter { placemark in
                        placemark.isoCountryCode == "CN" || 
                        placemark.country == "中国" || 
                        placemark.country == "China"
                    }
                    
                    if !chinesePlaces.isEmpty {
                        let mapItems = chinesePlaces.compactMap { placemark -> MKMapItem? in
                            guard let location = placemark.location else { return nil }
                            return MKMapItem(placemark: MKPlacemark(placemark: placemark))
                        }
                        
                        self.searchResults = mapItems
                        print("✅ [编辑] CLGeocoder 找到 \(mapItems.count) 个国内地点")
                    } else {
                        self.searchResults = []
                        print("❌ [编辑] 未找到国内地点")
                    }
                } else {
                    self.searchResults = []
                    print("❌ [编辑] CLGeocoder 搜索失败")
                }
            }
        }
    }
    
    // 🌍 国外搜索：优先使用 Apple 国际数据（通过网络 API）
    private func searchInternationalWithAppleData() {
        print("🌍 [编辑] 使用 Apple 国际数据搜索国外地点: \(searchText)")
        
        // 🔑 策略1：先检查预设城市库（快速响应）
        if let cityInfo = cityDataManager.findCity(by: searchText) {
            print("✅ [编辑] 从预设城市库找到: \(cityInfo.localizedName), \(cityInfo.localizedCountry)")
            
            // 创建 MKPlacemark 和 MKMapItem
            let coordinate = CLLocationCoordinate2D(latitude: cityInfo.latitude, longitude: cityInfo.longitude)
            let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: [
                CNPostalAddressCountryKey: cityInfo.localizedCountry,
                CNPostalAddressCityKey: cityInfo.localizedName
            ])
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = cityInfo.localizedName
            
            DispatchQueue.main.async {
                self.searchResults = [mapItem]
                self.isSearching = false
                print("✅ [编辑] 使用预设坐标: (\(cityInfo.latitude), \(cityInfo.longitude))")
            }
            return
        }
        
        // 🔑 策略2：使用 Apple 国际数据 API
        print("🔍 [编辑] 预设库中未找到，尝试使用 Apple 国际数据...")
        searchWithAppleInternationalAPI()
    }
    
    // 使用 Apple 国际数据 API 搜索
    private func searchWithAppleInternationalAPI() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("❌ [编辑] Apple 国际数据 API 错误: \(error.localizedDescription)")
                    // 如果 Apple API 失败，尝试 MKLocalSearch
                    self.fallbackToMKLocalSearch()
                    return
                }
                
                if let placemarks = placemarks, !placemarks.isEmpty {
                    print("📍 [编辑] Apple 国际数据 API 返回 \(placemarks.count) 个原始结果")
                    
                    // 将所有地点转换为 MKMapItem
                    let allMapItems = placemarks.compactMap { placemark -> MKMapItem? in
                        guard let location = placemark.location else { return nil }
                        return MKMapItem(placemark: MKPlacemark(placemark: placemark))
                    }
                    
                    // 优先显示非中国的地点
                    let internationalItems = allMapItems.filter { item in
                        item.placemark.isoCountryCode != "CN" &&
                        item.placemark.country != "中国" &&
                        item.placemark.country != "China"
                    }
                    
                    print("🔍 [编辑] 过滤后的国外地点数量: \(internationalItems.count)")
                    
                    let finalResults = internationalItems.isEmpty ? allMapItems : internationalItems
                    
                    self.searchResults = finalResults
                    print("✅ [编辑] Apple 国际数据最终显示 \(finalResults.count) 个地点")
                } else {
                    print("⚠️ [编辑] Apple 国际数据 API 未找到结果")
                    self.fallbackToMKLocalSearch()
                }
            }
        }
    }
    
    // 备用搜索方法：使用 MKLocalSearch
    private func fallbackToMKLocalSearch() {
        print("🔄 [编辑] 备用搜索：使用 MKLocalSearch")
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        
        // 不设置 region，让系统根据查询内容自动匹配
        // 设置结果类型（仅包括 address 和 pointOfInterest）
        if #available(iOS 13.0, *) {
            searchRequest.resultTypes = [.address, .pointOfInterest]
        }
        
        searchRequest.pointOfInterestFilter = nil
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("❌ [编辑] MKLocalSearch 搜索错误: \(error.localizedDescription)")
                    return
                }
                
                if let response = response {
                    self.searchResults = response.mapItems
                    print("✅ [编辑] MKLocalSearch 搜索到 \(response.mapItems.count) 个结果")
                }
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedLocation = item
        latitude = item.placemark.coordinate.latitude
        longitude = item.placemark.coordinate.longitude
        searchResults = []
        searchText = ""
    }
    
    private func saveChanges() {
        // 更新目的地信息
        destination.name = name
        destination.country = country
        destination.visitDate = visitDate
        destination.notes = notes
        destination.category = category
        destination.isFavorite = isFavorite
        let datasToSave = photoItems.map { $0.data }
        let thumbnailsToSave = photoItems.map { $0.thumbnailData }
        destination.photoDatas = datasToSave
        destination.photoData = datasToSave.first
        destination.photoThumbnailDatas = thumbnailsToSave
        destination.photoThumbnailData = thumbnailsToSave.first
        destination.trip = selectedTrip
        
        // 如果选择了新位置，更新坐标
        if let location = selectedLocation {
            destination.latitude = location.placemark.coordinate.latitude
            destination.longitude = location.placemark.coordinate.longitude
        }
        
        // SwiftData会自动保存更改
        dismiss()
    }
    
    private func deleteDestination() {
        let destinationId = destination.id
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.delete(destination)
            try? modelContext.save()
            // 发送删除通知，通知详情页关闭
            NotificationCenter.default.post(name: .destinationDeleted, object: nil, userInfo: ["destinationId": destinationId])
            dismiss()
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
}

