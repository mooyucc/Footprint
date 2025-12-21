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
import CoreLocation
import Contacts

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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query private var allDestinations: [TravelDestination]
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    
    // 支持从外部传入预填充数据
    private let prefill: AddDestinationPrefill?
    // 地图显示区域（用于搜索排序，优先使用地图显示区域中心）
    private let mapRegion: MKCoordinateRegion?
    // 保存成功后的回调，用于关闭父窗口（如从快速打卡页进入时）
    private let onSaveSuccess: (() -> Void)?
    
    @State private var name: String
    @State private var country: String
    @State private var province: String
    @State private var visitDate: Date
    @State private var notes = ""
    @State private var category: String
    @State private var isFavorite = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDatas: [Data]
    @State private var photoThumbnailDatas: [Data]
    @State private var videoData: Data?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    @State private var selectedTrip: TravelTrip?
    @State private var searchTask: DispatchWorkItem? // 用于防抖搜索任务
    @State private var showDuplicateAlert = false
    @State private var duplicateDestinationName = ""
    @State private var existingDestination: TravelDestination?
    @State private var showPaywall = false
    
    let categories = ["domestic", "international"]
    
    // 城市数据管理器实例
    private let cityDataManager = CityDataManager.shared
    
    init(prefill: AddDestinationPrefill? = nil, mapRegion: MKCoordinateRegion? = nil, onSaveSuccess: (() -> Void)? = nil) {
        self.prefill = prefill
        self.mapRegion = mapRegion
        self.onSaveSuccess = onSaveSuccess
        let initialName = prefill?.name ?? ""
        let initialCountry = prefill?.country ?? ""
        let initialProvince = prefill?.province ?? ""
        let initialCategory = prefill?.category ?? "domestic"
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
        _photoDatas = State(initialValue: initialPhotoDatas)
        _photoThumbnailDatas = State(initialValue: initialThumbnailDatas)
        _selectedLocation = State(initialValue: initialLocation)
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
                    
                    TextField("province_state".localized, text: $province)
                    
                    TextField("country_region".localized, text: $country)
                    
                    DatePicker("visit_date".localized, selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, get24HourLocale())
                    
                    Toggle("mark_as_favorite".localized, isOn: $isFavorite)
                }
                
                // 使用可复用的旅程选择组件
                TripSelectionSection(selectedTrip: $selectedTrip)
                
                Section("location_search".localized) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("search_place".localized, text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    // 提交时立即搜索（取消防抖）
                                    searchTask?.cancel()
                                    searchLocation()
                                }
                                .onChange(of: searchText) { _, newValue in
                                    // 实时搜索（带防抖，与悬浮按钮搜索体验一致）
                                    searchTask?.cancel()
                                    
                                    if newValue.isEmpty {
                                        searchResults = []
                                        isSearching = false
                                    } else {
                                        // 防抖：延迟0.3秒执行搜索，避免频繁请求
                                        let task = DispatchWorkItem {
                                            searchLocation()
                                        }
                                        searchTask = task
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                                    }
                                }
                            
                            // 保留搜索按钮作为手动触发选项
                            Button("search".localized) {
                                searchTask?.cancel()
                                searchLocation()
                            }
                            .disabled(searchText.isEmpty)
                        }
                        // 已移除：搜索框下方提示文字
                    }
                    
                    if isSearching {
                        HStack {
                            ProgressView()
                            Text("searching_places".localized(with: category))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 搜索结果
                    if !isSearching && !searchResults.isEmpty {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectLocation(item)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name ?? item.placemark.locality ?? "unknown_place".localized)
                                            .foregroundColor(.primary)
                                            .font(.body)
                                        
                                        // 显示更详细的地址信息
                                        if let country = item.placemark.country {
                                            HStack(spacing: 4) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                                Text([
                                                    item.placemark.locality,
                                                    item.placemark.administrativeArea,
                                                    country
                                                ].compactMap { $0 }.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // 无结果提示
                    if !isSearching && searchResults.isEmpty && !searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("no_results_found".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            
                            Text("suggestions".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("try_english_names".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("input_specific_address".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("check_spelling".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // 已选择的位置
                    if let location = selectedLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("selected_location".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name ?? location.placemark.locality ?? "unknown_place".localized)
                                    .font(.body)
                                
                                if let country = location.placemark.country {
                                    Text([
                                        location.placemark.locality,
                                        location.placemark.administrativeArea,
                                        country
                                    ].compactMap { $0 }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                
                                Text("latitude_longitude".localized(with: location.placemark.coordinate.latitude, location.placemark.coordinate.longitude))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 使用可复用的照片选择组件
                PhotoSelectionSection(
                    selectedPhotos: $selectedPhotos,
                    photoDatas: $photoDatas,
                    photoThumbnailDatas: $photoThumbnailDatas
                )
                
                // 使用可复用的视频选择组件
                VideoSelectionSection(videoData: $videoData)
                
                // 使用可复用的笔记组件
                NotesSection(notes: $notes)
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
                PaywallView()
                    .environmentObject(purchaseManager)
                    .environmentObject(entitlementManager)
            }
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
        print("search_domestic_with_amap".localized(with: searchText))
        
        // 优先使用地图显示区域作为搜索区域（与悬浮按钮搜索保持一致）
        // 如果没有地图区域，则使用整个中国区域作为备选
        let searchRegion: MKCoordinateRegion
        let chinaRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954), // 中国中心点
            span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 60.0) // 覆盖中国全境
        )
        
        if let mapRegion = mapRegion {
            searchRegion = mapRegion
            print("📍 使用地图显示区域作为搜索区域: (\(mapRegion.center.latitude), \(mapRegion.center.longitude))")
        } else {
            searchRegion = chinaRegion
            print("📍 地图区域不可用，使用整个中国区域作为搜索范围")
        }
        
        // 优先使用地图显示区域中心，其次是用户位置，最后使用搜索区域中心（与悬浮按钮搜索保持一致）
        let centerCoordinate: CLLocationCoordinate2D
        if let mapCenter = mapRegion?.center {
            centerCoordinate = mapCenter
            print("📍 使用地图显示区域中心作为排序参考点: (\(mapCenter.latitude), \(mapCenter.longitude))")
        } else if let userLoc = locationManager.lastKnownLocation {
            centerCoordinate = userLoc
            print("📍 使用用户位置作为排序参考点: (\(userLoc.latitude), \(userLoc.longitude))")
        } else {
            centerCoordinate = searchRegion.center
            print("📍 使用搜索区域中心作为排序参考点")
        }
        
        // 使用可复用的搜索辅助类（与悬浮按钮搜索功能保持一致）
        LocationSearchHelper.search(
            query: searchText,
            region: searchRegion,
            centerCoordinate: centerCoordinate
        ) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let items):
                    if items.isEmpty {
                        print("⚠️ 高德地图未找到结果，尝试备用搜索")
                        self.fallbackToCLGeocoderForChina()
                    } else {
                        self.searchResults = items
                        print("amap_found_results".localized(with: items.count))
                        
                        for (index, item) in items.prefix(3).enumerated() {
                            let locality = item.placemark.locality ?? ""
                            let province = item.placemark.administrativeArea ?? ""
                            let country = item.placemark.country ?? ""
                            print("结果 \(index + 1): \(locality) - \(province), \(country)")
                        }
                    }
                case .failure(let error):
                    print("amap_search_error".localized(with: error.localizedDescription))
                    // 如果高德搜索失败，尝试 CLGeocoder
                    self.fallbackToCLGeocoderForChina()
                }
            }
        }
    }
    
    // 备用国内搜索：使用 CLGeocoder
    private func fallbackToCLGeocoderForChina() {
        print("🔄 备用搜索：使用 CLGeocoder 搜索国内地点")
        
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
                        
                        // 优先使用地图显示区域中心，其次是用户位置，最后使用中国中心点（与悬浮按钮搜索保持一致）
                        let centerCoordinate: CLLocationCoordinate2D
                        if let mapCenter = self.mapRegion?.center {
                            centerCoordinate = mapCenter
                        } else if let userLoc = self.locationManager.lastKnownLocation {
                            centerCoordinate = userLoc
                        } else {
                            centerCoordinate = CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954)
                        }
                        self.searchResults = LocationSearchHelper.sortByDistance(items: mapItems, from: centerCoordinate)
                        print("✅ CLGeocoder 找到 \(mapItems.count) 个国内地点（已按距离排序）")
                    } else {
                        self.searchResults = []
                        print("❌ 未找到国内地点")
                    }
                } else {
                    self.searchResults = []
                    print("❌ CLGeocoder 搜索失败")
                }
            }
        }
    }
    
    // 🌍 国外搜索：优先使用 Apple 国际数据（通过网络 API）
    private func searchInternationalWithAppleData() {
        print("🌍 使用 Apple 国际数据搜索国外地点: \(searchText)")
        print("📱 设备区域设置: \(Locale.current.identifier)")
        print("📱 设备语言: \(Locale.current.languageCode ?? "未知")")
        print("📱 设备国家: \(Locale.current.regionCode ?? "未知")")
        
        // 🔑 策略1：先检查预设城市库（快速响应）
        if let cityInfo = cityDataManager.findCity(by: searchText) {
            print("✅ 从预设城市库找到: \(cityInfo.localizedName), \(cityInfo.localizedCountry)")
            
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
                print("✅ 使用预设坐标: (\(cityInfo.latitude), \(cityInfo.longitude))")
            }
            return
        }
        
        // 🔑 策略2：使用 Apple 国际数据 API
        print("🔍 预设库中未找到，尝试使用 Apple 国际数据...")
        searchWithAppleInternationalAPI()
    }
    
    // 使用 Apple 国际数据 API 搜索
    private func searchWithAppleInternationalAPI() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("❌ Apple 国际数据 API 错误: \(error.localizedDescription)")
                    // 如果 Apple API 失败，尝试 MKLocalSearch
                    self.fallbackToMKLocalSearch()
                    return
                }
                
                if let placemarks = placemarks, !placemarks.isEmpty {
                    print("📍 Apple 国际数据 API 返回 \(placemarks.count) 个原始结果:")
                    for (index, placemark) in placemarks.enumerated() {
                        print("  原始结果 \(index + 1):")
                        print("    - 名称: \(placemark.name ?? "无")")
                        print("    - 国家: \(placemark.country ?? "无")")
                        print("    - ISO代码: \(placemark.isoCountryCode ?? "无")")
                        print("    - 城市: \(placemark.locality ?? "无")")
                    }
                    
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
                    
                    print("🔍 过滤后的国外地点数量: \(internationalItems.count)")
                    
                    let finalResults = internationalItems.isEmpty ? allMapItems : internationalItems
                    
                    // 优先使用地图显示区域中心，其次是用户位置，最后保持原顺序（与悬浮按钮搜索功能保持一致）
                    if let mapCenter = self.mapRegion?.center {
                        self.searchResults = LocationSearchHelper.sortByDistance(items: finalResults, from: mapCenter)
                        print("✅ Apple 国际数据最终显示 \(finalResults.count) 个地点（已按地图区域中心距离排序）")
                    } else if let userLocation = self.locationManager.lastKnownLocation {
                        self.searchResults = LocationSearchHelper.sortByDistance(items: finalResults, from: userLocation)
                        print("✅ Apple 国际数据最终显示 \(finalResults.count) 个地点（已按用户位置距离排序）")
                    } else {
                        self.searchResults = finalResults
                        print("✅ Apple 国际数据最终显示 \(finalResults.count) 个地点")
                    }
                    
                    for (index, item) in finalResults.prefix(3).enumerated() {
                        let country = item.placemark.country ?? "未知国家"
                        let locality = item.placemark.locality ?? ""
                        print("显示结果 \(index + 1): \(item.name ?? locality) - \(country)")
                    }
                } else {
                    print("⚠️ Apple 国际数据 API 未找到结果")
                    self.fallbackToMKLocalSearch()
                }
            }
        }
    }
    
    // 备用搜索方法：使用 MKLocalSearch
    private func fallbackToMKLocalSearch() {
        // 优先使用地图显示区域中心，其次是用户位置（与悬浮按钮搜索功能保持一致）
        let centerCoordinate = mapRegion?.center ?? locationManager.lastKnownLocation
        // 使用可复用的搜索辅助类（不设置region，但使用地图区域中心或用户位置进行排序）
        LocationSearchHelper.search(
            query: searchText,
            region: nil,
            centerCoordinate: centerCoordinate
        ) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let items):
                    self.searchResults = items
                    print("✅ MKLocalSearch 搜索到 \(items.count) 个结果\(centerCoordinate != nil ? "（已按距离排序）" : "")")
                case .failure(let error):
                    print("❌ MKLocalSearch 搜索错误: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedLocation = item
        
        // 🎯 新功能：点击新搜索地点时覆盖现有页面中的相关信息
        // 优先使用 name，否则使用 locality（城市名）
        name = item.name ?? item.placemark.locality ?? ""
        
        // 自动填充国家/地区
        country = item.placemark.country ?? ""
        
        // 自动填充省份/州（对于中国直辖市，会将其名称作为省份）
        province = CountryManager.extractProvince(
            administrativeArea: item.placemark.administrativeArea,
            locality: item.placemark.locality,
            country: country,
            isoCountryCode: item.placemark.isoCountryCode
        )
        
        // 根据国家信息自动判断分类
        if let countryCode = item.placemark.isoCountryCode {
            if countryCode == "CN" || country == "中国" || country == "China" {
                category = "domestic"
            } else {
                category = "international"
            }
        }
        
        // 清空搜索结果和搜索文本
        searchResults = []
        searchText = ""
        
        // 打印选中的位置信息，方便调试
        print("✅ 已选择位置:")
        print("   名称: \(name)")
        print("   国家: \(country)")
        print("   分类: \(category)")
        print("   坐标: (\(item.placemark.coordinate.latitude), \(item.placemark.coordinate.longitude))")
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
            isFavorite: isFavorite
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
        
        // 如果提供了保存成功回调（如从快速打卡页进入），先调用回调关闭父窗口
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
        existing.category = category
        existing.isFavorite = isFavorite
        
        // 更新旅程关联
        existing.trip = selectedTrip
        
        // 保存更新
        try? modelContext.save()
        // 发送更新通知，通知徽章视图更新（覆盖现有目的地）
        NotificationCenter.default.post(name: .destinationUpdated, object: nil)
        
        // 如果提供了保存成功回调（如从快速打卡页进入），先调用回调关闭父窗口
        if let onSaveSuccess = onSaveSuccess {
            onSaveSuccess()
        }
        dismiss()
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
        }
    }
}

#Preview {
    AddDestinationView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
}

