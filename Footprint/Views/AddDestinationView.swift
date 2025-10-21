//
//  AddDestinationView.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
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
    
    // 支持从外部传入预填充数据
    var prefilledLocation: MKMapItem?
    var prefilledName: String?
    var prefilledCountry: String?
    var prefilledCategory: String?
    
    @State private var name = ""
    @State private var country = ""
    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var category = "国内"
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    @State private var selectedTrip: TravelTrip?
    
    let categories = ["国内", "国外"]
    
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
                Section("基本信息") {
                    TextField("地点名称", text: $name)
                    
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("国家/地区", text: $country)
                    
                    DatePicker("访问日期", selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Toggle("标记为喜爱", isOn: $isFavorite)
                }
                
                if !trips.isEmpty {
                    Section("所属旅程（可选）") {
                        Picker("选择旅程", selection: $selectedTrip) {
                            Text("无").tag(nil as TravelTrip?)
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
                                    Text("\(trip.startDate, style: .date) - \(trip.endDate, style: .date)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("位置搜索") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("搜索地点...", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("搜索") {
                                searchLocation()
                            }
                            .disabled(searchText.isEmpty)
                        }
                        
                        // 搜索提示（根据分类显示不同的提示）
                        if searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                if category == "国内" {
                                    Text("🇨🇳 搜索国内地点:")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("• 使用高德地图数据，搜索中国境内地点")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("• 直接输入城市名，如\"北京\"、\"上海\"、\"杭州\"")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("• 输入景点名，如\"故宫\"、\"西湖\"、\"外滩\"")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("🌍 搜索国外地点:")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("• 使用 Apple 国际数据，搜索全球地点")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("• ⭐ 热门城市快速搜索：London/伦敦、Paris/巴黎、Tokyo/东京等")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("• 支持英文和中文输入，通过网络获取最新数据")
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
                            Text("搜索\(category)地点中...")
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
                                        Text(item.name ?? item.placemark.locality ?? "未知地点")
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
                                Text("未找到结果")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            
                            Text("建议：")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("1. 尝试使用英文地名搜索")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("2. 输入更具体的地址，如\"London, UK\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("3. 检查拼写是否正确")
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
                                Text("已选择位置")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name ?? location.placemark.locality ?? "未知地点")
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
                                
                                Text("纬度: \(location.placemark.coordinate.latitude, specifier: "%.4f"), 经度: \(location.placemark.coordinate.longitude, specifier: "%.4f")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Section("照片") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("选择照片", systemImage: "photo")
                    }
                    
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                    }
                }
                
                Section("笔记") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("添加目的地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
        if category == "国内" {
            // 国内搜索：优先使用高德地图数据（通过 MKLocalSearch）
            searchDomesticWithLocalData()
        } else {
            // 国外搜索：优先使用 Apple 国际数据（通过网络 API）
            searchInternationalWithAppleData()
        }
    }
    
    // 🇨🇳 国内搜索：使用高德地图数据（通过 MKLocalSearch）
    private func searchDomesticWithLocalData() {
        print("🇨🇳 使用高德地图数据搜索国内地点: \(searchText)")
        
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
                    print("❌ 高德地图搜索错误: \(error.localizedDescription)")
                    // 如果高德搜索失败，尝试 CLGeocoder
                    self.fallbackToCLGeocoderForChina()
                    return
                }
                
                if let response = response {
                    self.searchResults = response.mapItems
                    print("✅ 高德地图找到 \(response.mapItems.count) 个国内地点")
                    
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

