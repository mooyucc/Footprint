//
//  EditDestinationView.swift
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

struct EditDestinationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    
    let destination: TravelDestination
    
    @State private var name = ""
    @State private var country = ""
    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var category = "国外"
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var selectedTrip: TravelTrip?
    
    let categories = ["国内", "国外"]
    
    // 常用国际城市坐标库（与 AddDestinationView 保持一致）
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
    
    init(destination: TravelDestination) {
        self.destination = destination
    }
    
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
                
                Section("位置信息") {
                    HStack {
                        TextField("搜索地点...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("搜索") {
                            searchLocation()
                        }
                        .disabled(searchText.isEmpty)
                    }
                    
                    if isSearching {
                        ProgressView()
                    }
                    
                    ForEach(searchResults, id: \.self) { item in
                        Button {
                            selectLocation(item)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "未知地点")
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
                                Text("已选择：\(location.name ?? "")")
                                    .font(.caption)
                                Text("纬度: \(location.placemark.coordinate.latitude, specifier: "%.4f"), 经度: \(location.placemark.coordinate.longitude, specifier: "%.4f")")
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
                                Text("当前位置")
                                    .font(.caption)
                                Text("纬度: \(latitude, specifier: "%.4f"), 经度: \(longitude, specifier: "%.4f")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("照片") {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Button {
                                self.photoData = nil
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(8)
                        }
                    }
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(photoData == nil ? "添加照片" : "更换照片", systemImage: "photo")
                    }
                }
                
                Section("笔记") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("编辑目的地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadDestinationData()
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
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
        photoData = destination.photoData
        latitude = destination.latitude
        longitude = destination.longitude
        selectedTrip = destination.trip
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
        let searchKey = searchText.lowercased().replacingOccurrences(of: " ", with: "")
        if let cityInfo = internationalCities[searchKey] {
            print("✅ [编辑] 从预设城市库找到: \(cityInfo.name), \(cityInfo.country)")
            
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
                print("✅ [编辑] 使用预设坐标: (\(cityInfo.lat), \(cityInfo.lon))")
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
        destination.photoData = photoData
        destination.trip = selectedTrip
        
        // 如果选择了新位置，更新坐标
        if let location = selectedLocation {
            destination.latitude = location.placemark.coordinate.latitude
            destination.longitude = location.placemark.coordinate.longitude
        }
        
        // SwiftData会自动保存更改
        dismiss()
    }
}

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
        category: "国内",
        isFavorite: true
    )
    container.mainContext.insert(destination)
    
    return EditDestinationView(destination: destination)
        .modelContainer(container)
}

