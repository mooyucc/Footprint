//
//  MapView.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
//

import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @Query private var destinations: [TravelDestination]
    @Query private var trips: [TravelTrip]
    @Environment(\.colorScheme) private var colorScheme // 检测颜色模式
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedDestination: TravelDestination?
    @State private var showingAddDestination = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showTripConnections = true // 是否显示旅程连线
    @State private var updateTimer: Timer? // 用于防抖
    @State private var pendingRegion: MKCoordinateRegion? // 待处理的区域更新
    @State private var mapSelection: TravelDestination? // 地图的选择状态
    
    // 长按添加目的地相关状态
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var isGeocodingLocation = false
    @State private var prefilledLocationData: (location: MKMapItem, name: String, country: String, category: String)?
    
    // 简化版中国国界多边形（近似，覆盖中国大陆与海南一带；仅作兜底使用）
    private static let chinaMainlandPolygon: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 53.55, longitude: 73.50),
        CLLocationCoordinate2D(latitude: 49.00, longitude: 87.80),
        CLLocationCoordinate2D(latitude: 47.50, longitude: 90.00),
        CLLocationCoordinate2D(latitude: 45.00, longitude: 96.00),
        CLLocationCoordinate2D(latitude: 42.00, longitude: 100.00),
        CLLocationCoordinate2D(latitude: 40.00, longitude: 104.00),
        CLLocationCoordinate2D(latitude: 37.00, longitude: 97.00),
        CLLocationCoordinate2D(latitude: 35.00, longitude: 91.00),
        CLLocationCoordinate2D(latitude: 31.00, longitude: 81.00),
        CLLocationCoordinate2D(latitude: 28.00, longitude: 85.00),
        CLLocationCoordinate2D(latitude: 27.00, longitude: 88.00),
        CLLocationCoordinate2D(latitude: 23.50, longitude: 98.00),
        CLLocationCoordinate2D(latitude: 22.00, longitude: 100.50),
        CLLocationCoordinate2D(latitude: 20.50, longitude: 109.00),
        CLLocationCoordinate2D(latitude: 18.00, longitude: 110.50),
        CLLocationCoordinate2D(latitude: 18.00, longitude: 109.00),
        CLLocationCoordinate2D(latitude: 21.50, longitude: 108.00),
        CLLocationCoordinate2D(latitude: 21.50, longitude: 107.50),
        CLLocationCoordinate2D(latitude: 20.50, longitude: 106.00),
        CLLocationCoordinate2D(latitude: 22.00, longitude: 105.50),
        CLLocationCoordinate2D(latitude: 24.00, longitude: 102.00),
        CLLocationCoordinate2D(latitude: 25.00, longitude: 103.50),
        CLLocationCoordinate2D(latitude: 27.00, longitude: 104.00),
        CLLocationCoordinate2D(latitude: 29.00, longitude: 106.00),
        CLLocationCoordinate2D(latitude: 31.00, longitude: 108.00),
        CLLocationCoordinate2D(latitude: 33.00, longitude: 104.00),
        CLLocationCoordinate2D(latitude: 35.00, longitude: 106.00),
        CLLocationCoordinate2D(latitude: 37.00, longitude: 110.00),
        CLLocationCoordinate2D(latitude: 39.00, longitude: 112.00),
        CLLocationCoordinate2D(latitude: 41.00, longitude: 114.00),
        CLLocationCoordinate2D(latitude: 43.00, longitude: 118.00),
        CLLocationCoordinate2D(latitude: 45.00, longitude: 123.00),
        CLLocationCoordinate2D(latitude: 47.00, longitude: 126.00),
        CLLocationCoordinate2D(latitude: 48.00, longitude: 128.00),
        CLLocationCoordinate2D(latitude: 45.00, longitude: 131.00),
        CLLocationCoordinate2D(latitude: 41.00, longitude: 132.00),
        CLLocationCoordinate2D(latitude: 37.00, longitude: 124.00),
        CLLocationCoordinate2D(latitude: 35.00, longitude: 121.00),
        CLLocationCoordinate2D(latitude: 32.00, longitude: 122.00),
        CLLocationCoordinate2D(latitude: 29.00, longitude: 121.00),
        CLLocationCoordinate2D(latitude: 26.00, longitude: 120.00),
        CLLocationCoordinate2D(latitude: 24.00, longitude: 118.00),
        CLLocationCoordinate2D(latitude: 22.00, longitude: 114.00),
        CLLocationCoordinate2D(latitude: 21.50, longitude: 112.00),
        CLLocationCoordinate2D(latitude: 22.00, longitude: 110.00),
        CLLocationCoordinate2D(latitude: 24.00, longitude: 106.00),
        CLLocationCoordinate2D(latitude: 26.00, longitude: 101.00),
        CLLocationCoordinate2D(latitude: 27.50, longitude: 98.00),
        CLLocationCoordinate2D(latitude: 30.00, longitude: 96.00),
        CLLocationCoordinate2D(latitude: 33.00, longitude: 94.00),
        CLLocationCoordinate2D(latitude: 36.00, longitude: 92.00),
        CLLocationCoordinate2D(latitude: 39.00, longitude: 90.00),
        CLLocationCoordinate2D(latitude: 43.00, longitude: 86.00),
        CLLocationCoordinate2D(latitude: 46.00, longitude: 82.00),
        CLLocationCoordinate2D(latitude: 49.00, longitude: 80.00),
        CLLocationCoordinate2D(latitude: 52.00, longitude: 78.00),
        CLLocationCoordinate2D(latitude: 53.55, longitude: 73.50)
    ]
    
    // 根据颜色模式返回不同的连线颜色
    private var tripConnectionColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5)
    }
    
    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $mapCameraPosition, selection: $mapSelection) {
                // 绘制旅程连线
                if showTripConnections {
                    ForEach(trips) { trip in
                        if let destinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                           destinations.count > 1 {
                            MapPolyline(coordinates: destinations.map { $0.coordinate })
                                .stroke(tripConnectionColor, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [1, 2]))
                        }
                    }
                }
                
                // 绘制地点标注
                ForEach(clusterAnnotations, id: \.id) { cluster in
                    Annotation(cluster.title, coordinate: cluster.coordinate) {
                        ClusterAnnotationView(
                            cluster: cluster,
                            zoomLevel: currentZoomLevel,
                            tripColorMap: tripColorMapping
                        )
                        .equatable()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if cluster.destinations.count == 1 {
                                    selectedDestination = cluster.destinations.first
                                    mapSelection = cluster.destinations.first
                                } else {
                                    // 放大到聚合区域
                                    zoomToCluster(cluster)
                                }
                            }
                        }
                    }
                }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onMapCameraChange { context in
                    // 使用防抖机制，避免频繁更新
                    pendingRegion = context.region
                    updateTimer?.invalidate()
                    updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        visibleRegion = pendingRegion
                    }
                }
                .onChange(of: mapSelection) { oldValue, newValue in
                    // 只在用户选择新的地点时更新，不自动清除
                    if let newValue = newValue {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedDestination = newValue
                        }
                    }
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onEnded { value in
                            switch value {
                            case .second(true, let drag):
                                if let location = drag?.location,
                                   let coordinate = proxy.convert(location, from: .local) {
                                    handleLongPress(at: coordinate)
                                }
                            default:
                                break
                            }
                        }
                )
            }
            
            // 当弹窗显示时，添加透明覆盖层来捕获点击事件
            if selectedDestination != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        // 点击空白区域关闭弹窗
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            selectedDestination = nil
                            mapSelection = nil
                        }
                    }
                    .zIndex(1) // 在地图之上
            }
            
            // 弹窗卡片
            VStack {
                Spacer()
                if let selected = selectedDestination {
                    DestinationPreviewCard(destination: selected)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .zIndex(2) // 在覆盖层之上
            
            // 已移除地理编码加载指示器
            
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // 添加按钮
                        Button {
                            showingAddDestination = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // 切换连线显示
                        Button {
                            withAnimation {
                                showTripConnections.toggle()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                                
                                Image(systemName: showTripConnections ? "point.3.connected.trianglepath.dotted" : "circle.grid.3x3.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(showTripConnections ? .blue : .gray)
                            }
                        }
                        
                        // 重置地图视图
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                mapCameraPosition = .automatic
                                selectedDestination = nil
                                mapSelection = nil
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                                
                                Image(systemName: "scope")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                }
                Spacer()
            }
            .zIndex(3) // 在所有层之上，确保按钮可点击
        }
        .sheet(isPresented: $showingAddDestination, onDismiss: {
            // 清除预填充数据
            prefilledLocationData = nil
        }) {
            if let locationData = prefilledLocationData {
                AddDestinationView(
                    prefilledLocation: locationData.location,
                    prefilledName: locationData.name,
                    prefilledCountry: locationData.country,
                    prefilledCategory: locationData.category
                )
            } else {
                AddDestinationView()
            }
        }
        .onDisappear {
            // 清理 timer
            updateTimer?.invalidate()
            updateTimer = nil
        }
    }
    
    // 计算当前缩放级别
    private var currentZoomLevel: Double {
        guard let region = visibleRegion else { return 10 }
        let span = region.span.longitudeDelta
        // 根据经度跨度计算缩放级别 (0-20)
        let zoomLevel = log2(360.0 / span)
        return max(0, min(20, zoomLevel))
    }
    
    // 旅程统一颜色映射
    private var tripColorMapping: [UUID: Color] {
        var mapping: [UUID: Color] = [:]
        for trip in trips {
            mapping[trip.id] = .blue // 所有旅程使用统一的蓝色
        }
        return mapping
    }
    
    // 获取旅程颜色
    private func tripColor(for trip: TravelTrip) -> Color {
        .blue // 所有旅程使用统一的蓝色
    }
    
    // 根据缩放级别计算聚合距离
    private var clusterDistance: Double {
        let zoom = currentZoomLevel
        // 缩放级别越小（视野越大），聚合距离越大
        if zoom < 4 { return 250000 }      // 250km - 世界/大洲级别
        else if zoom < 6 { return 100000 } // 100km - 国家级别
        else if zoom < 8 { return 50000 }  // 50km - 省级别
        else if zoom < 10 { return 25000 } // 25km - 市级别
        else if zoom < 12 { return 5000 }  // 5km - 城市级别
        else { return 0 }                  // 不聚合 - 街道级别
    }
    
    // 计算聚合后的标注点
    private var clusterAnnotations: [ClusterAnnotation] {
        let distance = clusterDistance
        
        // 如果聚合距离为0，返回所有单独的点
        if distance == 0 {
            return destinations.map { ClusterAnnotation(destinations: [$0]) }
        }
        
        var clusters: [ClusterAnnotation] = []
        var processed: Set<UUID> = []
        
        for destination in destinations {
            if processed.contains(destination.id) { continue }
            
            var clusterDestinations = [destination]
            processed.insert(destination.id)
            
            // 查找附近的地点
            for other in destinations {
                if processed.contains(other.id) { continue }
                
                let dist = destination.coordinate.distance(to: other.coordinate)
                if dist < distance {
                    clusterDestinations.append(other)
                    processed.insert(other.id)
                }
            }
            
            clusters.append(ClusterAnnotation(destinations: clusterDestinations))
        }
        
        return clusters
    }
    
    // 处理长按手势
    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        print("🗺️ 长按地图位置: (\(coordinate.latitude), \(coordinate.longitude))")
        longPressLocation = coordinate
        
        // 执行反向地理编码
        reverseGeocodeLocation(coordinate: coordinate)
    }
    
    // 反向地理编码：获取城市和国家信息（带多重回退）
    private func reverseGeocodeLocation(coordinate: CLLocationCoordinate2D) {
        isGeocodingLocation = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        func succeed(with placemark: CLPlacemark) {
            isGeocodingLocation = false
            let cityName = placemark.locality ?? placemark.administrativeArea ?? "未知城市"
            let countryName = placemark.country ?? "未知国家"
            let isoCountryCode = placemark.isoCountryCode ?? ""
            let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "国内" : "国外"
            print("✅ 反向地理编码成功:\n   城市: \(cityName)\n   国家: \(countryName)\n   ISO代码: \(isoCountryCode)\n   分类: \(category)")
            let mkPlacemark = MKPlacemark(placemark: placemark)
            let mapItem = MKMapItem(placemark: mkPlacemark)
            mapItem.name = cityName
            prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
            showingAddDestination = true
        }

        func failoverToAlternateLocales() {
            // 优先尝试英文，再尝试中文，提升国外/国内识别成功率
            geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "en_US")) { placemarks, _ in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async { succeed(with: placemark) }
                    return
                }
                geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN")) { placemarks, _ in
                    if let placemark = placemarks?.first {
                        DispatchQueue.main.async { succeed(with: placemark) }
                        return
                    }
                    // 继续回退到附近搜索
                    DispatchQueue.main.async { fallbackSearchAround(coordinate: coordinate) }
                }
            }
        }

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async { succeed(with: placemark) }
                return
            }
            print("❌ 反向地理编码失败: \(error?.localizedDescription ?? "未知错误")，尝试备用方案…")
            failoverToAlternateLocales()
        }
    }

    // 备用方案1：在坐标附近做一次本地搜索，尽量拿到国家/城市
    private func fallbackSearchAround(coordinate: CLLocationCoordinate2D) {
        let request = MKLocalSearch.Request()
        // 不设置关键词，利用区域搜索附近的已知地标/城市
        request.naturalLanguageQuery = nil
        let span = MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
        request.region = MKCoordinateRegion(center: coordinate, span: span)
        if #available(iOS 13.0, *) {
            request.resultTypes = [.address, .pointOfInterest]
        }
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let item = response?.mapItems.first {
                let cityName = item.name ?? item.placemark.locality ?? "所选位置"
                let countryName = item.placemark.country ?? "未知国家"
                let isoCountryCode = item.placemark.isoCountryCode ?? ""
                let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "国内" : "国外"
                print("✅ 附近搜索成功，使用邻近地点推断: \(cityName) - \(countryName)")
                let mapItem = item
                mapItem.name = cityName
                DispatchQueue.main.async {
                    self.isGeocodingLocation = false
                    self.prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
                    self.showingAddDestination = true
                }
            } else {
                print("⚠️ 附近搜索失败: \(error?.localizedDescription ?? "无结果")，继续使用坐标兜底…")
                DispatchQueue.main.async { self.fallbackWithCoordinateOnly(coordinate: coordinate) }
            }
        }
    }

    // 备用方案2：仅根据坐标进行国内/国外判断并提供占位名称
    private func fallbackWithCoordinateOnly(coordinate: CLLocationCoordinate2D) {
        isGeocodingLocation = false
        let category = isInChinaBoundingBox(coordinate) ? "国内" : "国外"
        let countryName = category == "国内" ? "中国" : "Unknown"
        let cityName = category == "国内" ? "所选位置" : "Selected Location"
        print("🛟 使用坐标兜底: \(cityName) - \(countryName) [分类: \(category)]")
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = cityName
        prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
        showingAddDestination = true
    }

    // 使用简化中国多边形进行判断（点在多边形内）
    private func isInChinaBoundingBox(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return isPoint(coordinate, inPolygon: Self.chinaMainlandPolygon)
    }

    // 射线法判断点是否在多边形内（支持闭合/未闭合输入）
    private func isPoint(_ point: CLLocationCoordinate2D, inPolygon polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].latitude
            let yi = polygon[i].longitude
            let xj = polygon[j].latitude
            let yj = polygon[j].longitude
            let intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
                (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi + 1e-12) + xi)
            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }
    
    // 放大到聚合区域
    private func zoomToCluster(_ cluster: ClusterAnnotation) {
        let coordinates = cluster.destinations.map { $0.coordinate }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.5)
        )
        
        withAnimation {
            mapCameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

// 聚合标注数据模型
struct ClusterAnnotation: Identifiable, Equatable {
    let destinations: [TravelDestination]
    
    // 使用稳定的 ID：基于聚合中所有地点的 ID 生成
    var id: String {
        destinations
            .map { $0.id.uuidString }
            .sorted()
            .joined(separator: "-")
    }
    
    var coordinate: CLLocationCoordinate2D {
        let avgLat = destinations.map { $0.coordinate.latitude }.reduce(0, +) / Double(destinations.count)
        let avgLon = destinations.map { $0.coordinate.longitude }.reduce(0, +) / Double(destinations.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
    
    var title: String {
        destinations.count == 1 ? destinations[0].name : "\(destinations.count) 个地点"
    }
    
    // 实现 Equatable 协议
    static func == (lhs: ClusterAnnotation, rhs: ClusterAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

// 聚合标注视图
struct ClusterAnnotationView: View, Equatable {
    let cluster: ClusterAnnotation
    let zoomLevel: Double
    let tripColorMap: [UUID: Color]
    
    // 实现 Equatable 协议以减少不必要的视图更新
    static func == (lhs: ClusterAnnotationView, rhs: ClusterAnnotationView) -> Bool {
        lhs.cluster.id == rhs.cluster.id &&
        abs(lhs.zoomLevel - rhs.zoomLevel) < 0.5 // 缩放级别变化小于0.5时不更新
    }
    
    private var markerSize: CGFloat {
        // 所有标记统一使用相同大小，不根据缩放级别或数量调整
        return 32
    }
    
    private var strokeWidth: CGFloat {
        cluster.destinations.count == 1 ? 2 : 2.5
    }
    
    // 主颜色：优先使用旅程颜色，没有旅程则使用国内/国外区分
    private var mainColor: Color {
        if cluster.destinations.count == 1 {
            let destination = cluster.destinations[0]
            if destination.trip != nil {
                return .blue // 旅程地点使用蓝色
            }
            return destination.category == "国内" ? .red : .blue
        } else {
            // 聚合标记：检查是否有共同旅程
            let tripIds = cluster.destinations.compactMap { $0.trip?.id }
            if mostFrequent(in: tripIds) != nil {
                return .blue // 有旅程的聚合使用蓝色
            }
            
            // 没有共同旅程，使用国内/国外混合颜色
            let domesticCount = cluster.destinations.filter { $0.category == "国内" }.count
            let ratio = Double(domesticCount) / Double(cluster.destinations.count)
            if ratio > 0.7 { return .red }
            else if ratio < 0.3 { return .blue }
            else { return .purple }
        }
    }
    
    // 边框颜色：如果有旅程，显示与主色不同的亮色边框
    private var borderColor: Color {
        if cluster.destinations.count == 1 {
            if cluster.destinations[0].trip != nil {
                return .white
            }
        }
        return .white
    }
    
    // 找出最常出现的元素
    private func mostFrequent(in array: [UUID]) -> UUID? {
        guard !array.isEmpty else { return nil }
        let counts = array.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    private var hasFavorite: Bool {
        cluster.destinations.contains { $0.isFavorite }
    }
    
    // 是否属于旅程
    private var belongsToTrip: Bool {
        cluster.destinations.count == 1 && cluster.destinations[0].trip != nil
    }
    
    // 聚合中是否包含旅程地点
    private var hasTripDestinations: Bool {
        cluster.destinations.contains { $0.trip != nil }
    }
    
    var body: some View {
        ZStack {
            // 外圈：旅程标识（当包含旅程地点时显示）
            if belongsToTrip || hasTripDestinations {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: markerSize + 8, height: markerSize + 8)
                    .opacity(0.8)
            }
            
            // 单个地点
            if cluster.destinations.count == 1 {
                let destination = cluster.destinations[0]
                
                // 如果有照片，显示照片
                if let photoData = destination.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: markerSize, height: markerSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: strokeWidth)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    // 没有照片，根据是否属于旅程显示不同效果
                    if belongsToTrip {
                        // 旅程地点使用蓝紫渐变
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: markerSize, height: markerSize)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: strokeWidth)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        // 普通地点显示颜色填充的圆点（红色=国内，蓝色=国外）
                        Circle()
                            .fill(mainColor)
                            .frame(width: markerSize, height: markerSize)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: strokeWidth)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                
                // 内容图标（收藏心形）
                if hasFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .font(.system(size: markerSize * 0.5))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            } else {
                // 聚合地点：根据是否包含旅程地点显示不同效果
                if hasTripDestinations {
                    // 包含旅程的聚合使用蓝紫渐变
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: markerSize, height: markerSize)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: strokeWidth)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    // 普通聚合显示颜色填充的圆点
                    Circle()
                        .fill(mainColor)
                        .frame(width: markerSize, height: markerSize)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: strokeWidth)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // 聚合地点数量
                Text("\(cluster.destinations.count)")
                    .font(.system(size: markerSize * 0.45, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
    }
}

// CLLocationCoordinate2D 扩展：计算两点距离
extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

struct DestinationPreviewCard: View {
    let destination: TravelDestination
    @State private var showDetail = false
    @State private var showEditSheet = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(destination.name)
                        .font(.headline)
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // 显示旅程信息
                if let trip = destination.trip {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.caption2)
                        Text(trip.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
                
                Text(destination.country)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.visitDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(destination.visitDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 圆形照片元素
            if let photoData = destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                // 如果没有照片，显示默认图标
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
            
            // 编辑按钮
            Button {
                showEditSheet = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            // 详情按钮
            Button {
                showDetail = true
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
        .sheet(isPresented: $showDetail) {
            DestinationDetailView(destination: destination)
        }
        .sheet(isPresented: $showEditSheet) {
            EditDestinationView(destination: destination)
        }
    }
}

#Preview {
    MapView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
}

