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

struct AddDestinationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @StateObject private var languageManager = LanguageManager.shared
    
    // 支持从外部传入预填充数据
    var prefilledLocation: MKMapItem?
    var prefilledName: String?
    var prefilledCountry: String?
    var prefilledCategory: String?
    
    @State private var name = ""
    @State private var country = ""
    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var category = "domestic"
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    @State private var selectedTrip: TravelTrip?
    
    let categories = ["domestic", "international"]
    
    // 常用国际城市坐标库（解决在中国无法搜索国外地点的问题）
    // 参考 iPhone 地图应用的国际城市数据，手动维护热门目的地
    let internationalCities: [String: (name: String, country: String, lat: Double, lon: Double)] = [
        "london": ("London", "United Kingdom", 51.5074, -0.1278),
        "伦敦": ("London", "United Kingdom", 51.5074, -0.1278),
        "paris": ("Paris", "France", 48.8566, 2.3522),
        "巴黎": ("Paris", "France", 48.8566, 2.3522),
        "tokyo": ("Tokyo", "Japan", 35.6762, 139.6503),
        "东京": ("Tokyo", "Japan", 35.6762, 139.6503),
        "newyork": ("New York", "United States", 40.7128, -74.0060),
        "纽约": ("New York", "United States", 40.7128, -74.0060),
        "sydney": ("Sydney", "Australia", -33.8688, 151.2093),
        "悉尼": ("Sydney", "Australia", -33.8688, 151.2093),
        "rome": ("Rome", "Italy", 41.9028, 12.4964),
        "罗马": ("Rome", "Italy", 41.9028, 12.4964),
        "dubai": ("Dubai", "United Arab Emirates", 25.2048, 55.2708),
        "迪拜": ("Dubai", "United Arab Emirates", 25.2048, 55.2708),
        "singapore": ("Singapore", "Singapore", 1.3521, 103.8198),
        "新加坡": ("Singapore", "Singapore", 1.3521, 103.8198),
        "losangeles": ("Los Angeles", "United States", 34.0522, -118.2437),
        "洛杉矶": ("Los Angeles", "United States", 34.0522, -118.2437),
        "barcelona": ("Barcelona", "Spain", 41.3851, 2.1734),
        "巴塞罗那": ("Barcelona", "Spain", 41.3851, 2.1734),
        "amsterdam": ("Amsterdam", "Netherlands", 52.3676, 4.9041),
        "阿姆斯特丹": ("Amsterdam", "Netherlands", 52.3676, 4.9041),
        "bangkok": ("Bangkok", "Thailand", 13.7563, 100.5018),
        "曼谷": ("Bangkok", "Thailand", 13.7563, 100.5018),
        "seoul": ("Seoul", "South Korea", 37.5665, 126.9780),
        "首尔": ("Seoul", "South Korea", 37.5665, 126.9780),
        "moscow": ("Moscow", "Russia", 55.7558, 37.6173),
        "莫斯科": ("Moscow", "Russia", 55.7558, 37.6173)
    ]
    
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
                
                Section("location_search".localized) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("search_place".localized, text: $searchText)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("search".localized) {
                                searchLocation()
                            }
                            .disabled(searchText.isEmpty)
                        }
                        
                        // 搜索提示（根据分类显示不同的提示）
                        if searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                if category == "domestic".localized {
                                    Text("search_domestic_places".localized)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("use_amap_data".localized)
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("input_city_names".localized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("input_attractions".localized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("search_international_places".localized)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("use_apple_international".localized)
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("hot_cities_quick_search".localized)
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("support_multilingual".localized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
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
                
                Section("photo".localized) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("select_photo".localized, systemImage: "photo")
                    }
                    
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                    }
                }
                
                Section("notes".localized) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
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
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear {
                // 应用预填充数据
                if let prefilledLocation = prefilledLocation {
                    selectedLocation = prefilledLocation
                }
                if let prefilledName = prefilledName {
                    name = prefilledName
                }
                if let prefilledCountry = prefilledCountry {
                    country = prefilledCountry
                }
                if let prefilledCategory = prefilledCategory {
                    category = prefilledCategory
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !country.isEmpty && selectedLocation != nil
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
                    print("amap_search_error".localized(with: error.localizedDescription))
                    // 如果高德搜索失败，尝试 CLGeocoder
                    self.fallbackToCLGeocoderForChina()
                    return
                }
                
                if let response = response {
                    self.searchResults = response.mapItems
                    print("amap_found_results".localized(with: response.mapItems.count))
                    
                    for (index, item) in response.mapItems.prefix(3).enumerated() {
                        let locality = item.placemark.locality ?? ""
                        let province = item.placemark.administrativeArea ?? ""
                        let country = item.placemark.country ?? ""
                        print("结果 \(index + 1): \(locality) - \(province), \(country)")
                    }
                } else {
                    print("⚠️ 高德地图未找到结果，尝试备用搜索")
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
                        
                        self.searchResults = mapItems
                        print("✅ CLGeocoder 找到 \(mapItems.count) 个国内地点")
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
        let searchKey = searchText.lowercased().replacingOccurrences(of: " ", with: "")
        if let cityInfo = internationalCities[searchKey] {
            print("✅ 从预设城市库找到: \(cityInfo.name), \(cityInfo.country)")
            
            // 创建 MKPlacemark 和 MKMapItem
            let coordinate = CLLocationCoordinate2D(latitude: cityInfo.lat, longitude: cityInfo.lon)
            let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: [
                CNPostalAddressCountryKey: cityInfo.country,
                CNPostalAddressCityKey: cityInfo.name
            ])
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = cityInfo.name
            
            DispatchQueue.main.async {
                self.searchResults = [mapItem]
                self.isSearching = false
                print("✅ 使用预设坐标: (\(cityInfo.lat), \(cityInfo.lon))")
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
                    
                    self.searchResults = finalResults
                    print("✅ Apple 国际数据最终显示 \(finalResults.count) 个地点")
                    
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
                    print("❌ MKLocalSearch 搜索错误: \(error.localizedDescription)")
                    return
                }
                
                if let response = response {
                    self.searchResults = response.mapItems
                    print("✅ MKLocalSearch 搜索到 \(response.mapItems.count) 个结果")
                }
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedLocation = item
        
        // 自动填充地点名称
        if name.isEmpty {
            // 优先使用 name，否则使用 locality（城市名）
            name = item.name ?? item.placemark.locality ?? ""
        }
        
        // 自动填充国家/地区
        if country.isEmpty {
            country = item.placemark.country ?? ""
        }
        
        // 清空搜索结果和搜索文本
        searchResults = []
        searchText = ""
        
        // 打印选中的位置信息，方便调试
        print("✅ 已选择位置:")
        print("   名称: \(name)")
        print("   国家: \(country)")
        print("   坐标: (\(item.placemark.coordinate.latitude), \(item.placemark.coordinate.longitude))")
    }
    
    private func saveDestination() {
        guard let location = selectedLocation else { return }
        
        let destination = TravelDestination(
            name: name,
            country: country,
            latitude: location.placemark.coordinate.latitude,
            longitude: location.placemark.coordinate.longitude,
            visitDate: visitDate,
            notes: notes,
            photoData: photoData,
            category: category,
            isFavorite: isFavorite
        )
        
        // 关联到旅程
        if let trip = selectedTrip {
            destination.trip = trip
        }
        
        modelContext.insert(destination)
        dismiss()
    }
}

#Preview {
    AddDestinationView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
}

