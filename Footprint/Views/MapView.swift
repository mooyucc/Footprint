//
//  MapView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import Combine
import AudioToolbox

// 地图样式枚举
enum MapStyle: String, CaseIterable {
    case muted = "muted"
    case standard = "standard"
    case hybrid = "hybrid"
    case imagery = "imagery"
    
    var displayName: String {
        switch self {
        case .standard:
            return "map_style_standard"
        case .muted:
            return "map_style_muted"
        case .hybrid:
            return "map_style_hybrid"
        case .imagery:
            return "map_style_imagery"
        }
    }
    
    var iconName: String {
        switch self {
        case .standard:
            return "map"
        case .muted:
            return "map.fill"
        case .hybrid:
            return "globe.americas"
        case .imagery:
            return "camera"
        }
    }
    
    func toMapKitStyle() -> MapKit.MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .muted:
            return .standard(elevation: .flat, emphasis: .muted)  // 静音模式：道路不明显
        case .hybrid:
            return .hybrid(elevation: .realistic)  // 混合地图：卫星图像+标注，支持地球视图
        case .imagery:
            return .imagery(elevation: .realistic) // 卫星图像：纯卫星图像，无标注
        }
    }
}

struct MapView: View {
    @Query private var destinations: [TravelDestination]
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Environment(\.colorScheme) private var colorScheme // 检测颜色模式
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var countryManager = CountryManager.shared
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedDestination: TravelDestination?
    @State private var showingAddDestination = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showTripConnections = false // 是否显示旅程连线
    @State private var updateTimer: Timer? // 用于防抖
    @State private var pendingRegion: MKCoordinateRegion? // 待处理的区域更新
    @State private var periodicCheckTimer: Timer? // 用于定期检查地点变化
    @State private var mapSelection: TravelDestination? // 地图的选择状态
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeManager = RouteManager.shared
    // 详情弹窗（由父级统一展示，避免子视图被移除导致弹窗不出现）
    @State private var showingDestinationDetail = false
    @State private var detailDestinationForSheet: TravelDestination?
    
    // 存储每个旅程的路线数据 [tripId: [routeIndex: route]]
    // 使用 [MKRoute?] 而不是 [MKRoute] 以保持索引对应关系（nil 表示该段路线计算失败）
    @State private var tripRoutes: [UUID: [MKRoute?]] = [:]
    
    // 性能优化：缓存聚合结果
    @State private var cachedClusterAnnotations: [ClusterAnnotation] = []
    @State private var cachedZoomLevelEnum: ZoomLevel = .world
    @State private var cachedDestinationsCount: Int = 0
    @State private var cachedVisibleRegionKey: String = "" // 缓存可见区域的标识
    @State private var lastCalculationTime: Date = Date()
    
    // 地图样式相关状态
    @State private var currentMapStyle: MapStyle = .muted
    @State private var showingMapStylePicker = false
    
    // 长按添加目的地相关状态
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var isGeocodingLocation = false
    @State private var prefilledLocationData: (location: MKMapItem, name: String, country: String, category: String)?
    @State private var isWaitingForLocation = false // 等待定位状态（用于打卡功能）
    
    @State private var refreshID = UUID()
    
    // 用于检测地点变化的状态（坐标、删除等）
    @State private var lastDestinationsSignature: String = ""
    
    // 回忆泡泡相关状态
    @State private var showMemoryBubble = false
    @State private var selectedBubbleDestination: TravelDestination?
    @State private var bubbleAnimationOffset: CGFloat = 0
    @State private var bubbleScale: CGFloat = 0
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var showSearchResults = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // 线路卡片相关状态
    @State private var showRouteCards = false
    @State private var selectedTripId: UUID? // 当前选中的旅程ID（用于显示连线和地图跟随）
    @State private var cardSwitchTask: DispatchWorkItem? // 用于取消之前的切换任务
    @State private var isScrolling = false // 是否正在滚动
    @State private var snapTask: DispatchWorkItem? // 磁吸任务
    @State private var shouldHideRouteCards = false // 是否应该隐藏路线卡片（用于弹窗交互）
    @State private var showingTripDetail = false // 是否显示路线详情sheet
    @State private var detailTripForSheet: TravelTrip? // 用于sheet的路线详情
    var autoShowRouteCards: Bool = false // 是否自动显示线路卡片
    
    // 滑动优化相关状态
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollVelocity: CGFloat = 0
    @State private var lastScrollTime: Date = Date()
    @State private var isUserScrolling: Bool = false
    
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
    
    // 搜索框占位符文本
    private var searchPlaceholderText: String {
        "search_places".localized
    }
    
    // 根据地图样式返回图标颜色
    private var iconColor: Color {
        switch currentMapStyle {
        case .standard, .muted:
            return .blue
        case .hybrid, .imagery:
            return .white
        }
    }
    
    // 判断是否是深色地图样式
    private var isDarkMapStyle: Bool {
        switch currentMapStyle {
        case .standard, .muted:
            return false
        case .hybrid, .imagery:
            return true
        }
    }
    
    var body: some View {
        ZStack {
            mapLayer
            dismissOverlay
            previewCard
            routeCardsOverlay
            memoryBubbleOverlay
            floatingButtons
        }
        .sheet(isPresented: $showingDestinationDetail) {
            if let dest = detailDestinationForSheet {
                DestinationDetailView(destination: dest)
            }
        }
        .sheet(isPresented: $showingTripDetail) {
            if let trip = detailTripForSheet {
                TripDetailView(trip: trip)
            }
        }
        .sheet(isPresented: $showingAddDestination, onDismiss: {
            prefilledLocationData = nil
            isWaitingForLocation = false
        }) {
            destinationSheet
        }
        .sheet(isPresented: $showingMapStylePicker) {
            mapStylePicker
        }
        .onAppear {
            // 地图视图加载完成
            // 如果设置了自动显示线路卡片，则自动显示
            if autoShowRouteCards {
                // 找到所有有效的旅程（至少2个地点）
                let validTrips = trips.filter { trip in
                    if let destinations = trip.destinations,
                       !destinations.isEmpty,
                       destinations.count >= 2 {
                        return true
                    }
                    return false
                }
                
                // 确定要使用的旅程：优先使用已选中的旅程（如果仍然有效），否则使用第一个
                var targetTrip: TravelTrip?
                var tripDestinations: [TravelDestination]?
                
                // 如果已经有选中的旅程，检查它是否仍然有效
                if let currentSelectedId = selectedTripId,
                   let currentTrip = validTrips.first(where: { $0.id == currentSelectedId }),
                   let destinations = currentTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                   destinations.count >= 2 {
                    // 使用已选中的旅程，保持地图和卡片一致
                    targetTrip = currentTrip
                    tripDestinations = destinations
                } else if let firstValidTrip = validTrips.first,
                          let destinations = firstValidTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                          destinations.count >= 2 {
                    // 没有有效的选中旅程，使用第一个
                    targetTrip = firstValidTrip
                    tripDestinations = destinations
                    selectedTripId = firstValidTrip.id
                }
                
                // 如果有有效的旅程，设置地图和显示
                if let trip = targetTrip, let destinations = tripDestinations {
                    // 1. 缩放地图到该旅程的范围
                    zoomToTripDestinations(destinations)
                    
                    // 2. 开启地点连线显示
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showTripConnections = true
                    }
                    
                    // 3. 计算该旅程的路线（如果还没有计算）
                    let coordinates = destinations.map { $0.coordinate }
                    Task {
                        await calculateRoutesForTrip(tripId: trip.id, coordinates: coordinates, incremental: true)
                    }
                    
                    // 4. 延迟一小段时间后显示路线卡片，确保地图缩放完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showRouteCards = true
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // 语言变化时刷新界面
            refreshID = UUID()
        }
        .onChange(of: destinations.count) { oldValue, newValue in
            // 地点数量变化时立即更新路线
            print("🔄 地点数量变化: \(oldValue) -> \(newValue)")
            handleDestinationsChange()
        }
        .onChange(of: destinations) { oldValue, newValue in
            // 监听地点数组变化（包括坐标、所属旅程等属性变化）
            // 比较数组内容是否真的变化了
            let oldIds = Set(oldValue.map { $0.id })
            let newIds = Set(newValue.map { $0.id })
            if oldIds != newIds {
                print("🔄 地点ID集合变化")
                handleDestinationsChange()
            } else {
                // 即使ID相同，也可能坐标或旅程变化了
                checkDestinationsChange()
            }
        }
        .onChange(of: trips) { oldValue, newValue in
            // 监听旅程变化，检查每个旅程的destinations是否变化
            for trip in newValue {
                if let tripDestinations = trip.destinations {
                    let tripDestCount = tripDestinations.count
                    // 检查是否有对应的旧旅程
                    if let oldTrip = oldValue.first(where: { $0.id == trip.id }),
                       let oldDestinations = oldTrip.destinations {
                        let oldDestCount = oldDestinations.count
                        if oldDestCount != tripDestCount {
                            print("🔄 旅程 \(trip.name) 的地点数量变化: \(oldDestCount) -> \(tripDestCount)")
                            handleDestinationsChange()
                            return
                        }
                    }
                }
            }
        }
        .onAppear {
            // 初始化签名
            lastDestinationsSignature = destinationsSignature
            // 启动定时检查（作为备用，每2秒检查一次）
            startPeriodicCheck()
        }
        .onDisappear {
            updateTimer?.invalidate()
            updateTimer = nil
            stopPeriodicCheck()
        }
        .onChange(of: currentZoomLevelEnum) { oldValue, newValue in
            // 缩放级别变化时清除缓存，触发重新计算
            if oldValue != newValue {
                print("📏 缩放级别变化: \(oldValue.description) → \(newValue.description)")
                clearClusterCache()
            }
        }
        .onChange(of: showTripConnections) { _, newValue in
            if newValue {
                // 显示连线时计算路线
                calculateRoutesForAllTrips()
            }
        }
        .onChange(of: trips.count) { _, _ in
            // 旅程变化时重新计算路线
            if showTripConnections {
                calculateRoutesForAllTrips()
            }
        }
        .onChange(of: locationManager.lastKnownLocation) { oldValue, newValue in
            // 监听位置更新：如果正在等待位置（打卡功能），则开始反向地理编码
            if isWaitingForLocation, let newLocation = newValue {
                print("✅ 位置更新，开始打卡反向地理编码: (\(newLocation.latitude), \(newLocation.longitude))")
                isWaitingForLocation = false
                reverseGeocodeLocation(coordinate: newLocation)
            }
        }
        .onChange(of: selectedTripId) { oldValue, newValue in
            // 如果在线路tab且选中线路发生变化，清除聚合缓存以重新计算
            if autoShowRouteCards && oldValue != newValue {
                clearClusterCache()
            }
        }
        .onChange(of: selectedDestination) { oldValue, newValue in
            // 当显示地点小卡片弹窗时，隐藏路线卡片（不改变showRouteCards状态）
            if newValue != nil && showRouteCards {
                // 显示地点小卡片时，隐藏路线卡片
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    shouldHideRouteCards = true
                }
            } else if newValue == nil && oldValue != nil && autoShowRouteCards {
                // 关闭地点小卡片时，如果在线路tab，重新显示路线卡片
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    shouldHideRouteCards = false
                }
            }
        }
        .onChange(of: showingTripDetail) { oldValue, newValue in
            // 当显示路线详情弹窗时，隐藏路线卡片（不改变showRouteCards状态）
            if newValue && showRouteCards {
                // 显示路线详情时，隐藏路线卡片
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    shouldHideRouteCards = true
                }
            } else if !newValue && oldValue && autoShowRouteCards {
                // 关闭路线详情时，如果在线路tab，重新显示路线卡片
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    shouldHideRouteCards = false
                }
            }
        }
        .id(refreshID)
    }
    
    // 地图层
    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $mapCameraPosition, selection: $mapSelection) {
                tripConnections
                clusterMarkers
                userLocationMarker
            }
            .mapStyle(currentMapStyle.toMapKitStyle())
            .onMapCameraChange(frequency: .continuous) { context in
                pendingRegion = context.region
                updateTimer?.invalidate()
                // 增加防抖延迟，减少频繁计算
                updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    visibleRegion = pendingRegion
                }
            }
            .onChange(of: mapSelection) { oldValue, newValue in
                if let newValue = newValue {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDestination = newValue
                    }
                }
            }
            .gesture(longPressGesture(proxy: proxy))
        }
    }
    
    // 旅程连线
    @MapContentBuilder
    private var tripConnections: some MapContent {
        if !showTripConnections {
            // 不显示连线时返回空内容
        } else {
            // 如果设置了选中的旅程ID，只显示该旅程的连线；否则显示所有旅程的连线
            let tripsToShow = selectedTripId != nil 
                ? trips.filter { $0.id == selectedTripId }
                : trips
            
            ForEach(tripsToShow) { trip in
                if let tripDestinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                   tripDestinations.count > 1 {
                    let visibleDestinations: [TravelDestination] = tripDestinations
                    
                    if visibleDestinations.count > 1 {
                        // 检查是否有计算好的路线（至少有一个非nil的路线）
                        let routes = tripRoutes[trip.id]
                        let hasValidRoutes = routes != nil && !routes!.isEmpty && routes!.contains { $0 != nil }
                        
                        if hasValidRoutes, let routes = routes {
                            // 遍历所有路线段（基于目的地数量），保持索引对应关系
                            ForEach(Array(visibleDestinations.enumerated()), id: \.offset) { index, _ in
                                if index < visibleDestinations.count - 1 {
                                    // 检查起点和终点是否在同一个聚合中
                                    let sourceDestination = visibleDestinations[index]
                                    let destinationDestination = visibleDestinations[index + 1]
                                    
                                    // 如果不在同一个聚合中，才显示路线
                                    if !areDestinationsInSameCluster(sourceDestination, destinationDestination) {
                                        // 获取对应索引的路线（可能为 nil）
                                        if index < routes.count, let route = routes[index] {
                                            // 路线 - 使用 Apple 设计标准的样式（白色描边 + 蓝色主体）
                                            // 先绘制白色背景（更粗），创建描边效果
                                            MapPolyline(route.polyline)
                                                .stroke(
                                                    Color.white,
                                                    style: StrokeStyle(
                                                        lineWidth: 7,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                            // 再绘制蓝色主体（较细），叠加在白色背景上
                                            MapPolyline(route.polyline)
                                                .stroke(
                                                    Color.blue,
                                                    style: StrokeStyle(
                                                        lineWidth: 5,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                            
                                            // 距离标注
                                            if let midpoint = midpointOfPolyline(route.polyline) {
                                                Annotation("", coordinate: midpoint) {
                                                    RouteDistanceLabel(distance: route.distance)
                                                }
                                            }
                                        } else {
                                            // 如果该段路线为nil，显示占位线
                                            let source = visibleDestinations[index]
                                            let destination = visibleDestinations[index + 1]
                                            MapPolyline(coordinates: [source.coordinate, destination.coordinate])
                                                .stroke(tripConnectionColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [1, 2]))
                                            
                                            // 显示直线距离标注
                                            let distance = source.coordinate.distance(to: destination.coordinate)
                                            if let midpoint = midpointOfLine(from: source.coordinate, to: destination.coordinate) {
                                                Annotation("", coordinate: midpoint) {
                                                    RouteDistanceLabel(distance: distance)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // 如果没有路线或所有路线都是nil，显示直线作为占位，但也要检查聚合
                            ForEach(Array(visibleDestinations.enumerated()), id: \.offset) { index, _ in
                                if index < visibleDestinations.count - 1 {
                                    let source = visibleDestinations[index]
                                    let destination = visibleDestinations[index + 1]
                                    
                                    // 如果不在同一个聚合中，才显示占位线
                                    if !areDestinationsInSameCluster(source, destination) {
                                        MapPolyline(coordinates: [source.coordinate, destination.coordinate])
                                            .stroke(tripConnectionColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [1, 2]))
                                        
                                        // 显示直线距离标注
                                        let distance = source.coordinate.distance(to: destination.coordinate)
                                        if let midpoint = midpointOfLine(from: source.coordinate, to: destination.coordinate) {
                                            Annotation("", coordinate: midpoint) {
                                                RouteDistanceLabel(distance: distance)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 聚合标记
    @MapContentBuilder
    private var clusterMarkers: some MapContent {
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
                            zoomToCluster(cluster)
                        }
                    }
                }
            }
        }
    }
    
    // 用户位置标记
    @MapContentBuilder
    private var userLocationMarker: some MapContent {
        if let userLocation = locationManager.lastKnownLocation {
            Annotation("", coordinate: userLocation) {
                UserLocationAnnotationView()
            }
        }
    }
    
    // 长按手势
    private func longPressGesture(proxy: MapProxy) -> some Gesture {
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
    }
    
    // 消失覆盖层
    @ViewBuilder
    private var dismissOverlay: some View {
        if selectedDestination != nil {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedDestination = nil
                        mapSelection = nil
                    }
                }
                .zIndex(1)
        }
    }
    
    // 预览卡片
    private var previewCard: some View {
        VStack {
            Spacer()
            if let selected = selectedDestination {
                DestinationPreviewCard(destination: selected, onDelete: {
                    // 删除回调：关闭弹窗
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedDestination = nil
                        mapSelection = nil
                    }
                }, onOpenDetail: {
                    // 父级弹出详情页，并隐藏小弹窗
                    detailDestinationForSheet = selected
                    showingDestinationDetail = true
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedDestination = nil
                        mapSelection = nil
                    }
                })
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            selectedDestination = nil
                            mapSelection = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(2)
    }
    
    // 线路卡片覆盖层
    private var routeCardsOverlay: some View {
        VStack {
            Spacer()
            if showRouteCards {
                // 获取有效的旅程列表（用于显示卡片）
                let validTrips = trips.filter { trip in
                    if let destinations = trip.destinations,
                       !destinations.isEmpty,
                       destinations.count >= 2 {
                        return true
                    }
                    return false
                }
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(validTrips.enumerated()), id: \.element.id) { index, trip in
                                if let tripDestinations = trip.destinations,
                                   !tripDestinations.isEmpty,
                                   tripDestinations.count >= 2 {
                                    // 使用容器包装卡片，确保阴影有足够空间不被裁剪
                                    ZStack {
                                        RouteCard(
                                            trip: trip,
                                            destinations: tripDestinations.sorted(by: { $0.visitDate < $1.visitDate }),
                                            onTap: {
                                                // 点击路线卡片，直接打开详情页并隐藏路线卡片列表
                                                detailTripForSheet = trip
                                                showingTripDetail = true
                                            }
                                        )
                                    }
                                    .frame(width: 336) // 卡片宽度 320 + 左右阴影空间 16
                                    .padding(.vertical, 4) // 为上下阴影留出空间
                                    .id(trip.id)
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .preference(
                                                    key: ScrollOffsetPreferenceKey.self,
                                                    value: [ScrollOffsetInfo(
                                                        tripId: trip.id,
                                                        offset: geometry.frame(in: .named("scroll")).minX
                                                    )]
                                                )
                                        }
                                    )
                                    .onAppear {
                                        // 当卡片出现时，如果这是第一个卡片且没有选中，则选中它
                                        if index == 0 && selectedTripId == nil {
                                            handleCardAppear(trip: trip, destinations: tripDestinations.sorted(by: { $0.visitDate < $1.visitDate }))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offsets in
                        // 计算当前滚动位置和速度（使用最接近中心的卡片）
                        let screenWidth = UIScreen.main.bounds.width
                        let centerX = screenWidth / 2
                        let cardWidth: CGFloat = 336 // 更新为外层容器宽度
                        let cardCenterOffset = cardWidth / 2
                        
                        // 找到最接近中心的卡片来计算速度
                        var closestOffset: CGFloat?
                        var minDistance: CGFloat = .infinity
                        
                        for offsetInfo in offsets {
                            let cardCenterX = offsetInfo.offset + cardCenterOffset
                            let distance = abs(cardCenterX - centerX)
                            if distance < minDistance {
                                minDistance = distance
                                closestOffset = offsetInfo.offset
                            }
                        }
                        
                        if let currentOffset = closestOffset {
                            let now = Date()
                            let timeDelta = now.timeIntervalSince(lastScrollTime)
                            
                            // 计算滚动速度
                            if timeDelta > 0 && timeDelta < 0.5 { // 只在合理的时间范围内计算
                                let offsetDelta = currentOffset - lastScrollOffset
                                scrollVelocity = offsetDelta / CGFloat(timeDelta)
                            }
                            
                            lastScrollOffset = currentOffset
                            lastScrollTime = now
                            isUserScrolling = true
                        }
                        
                        // 取消之前的任务
                        cardSwitchTask?.cancel()
                        snapTask?.cancel()
                        
                        // 创建新的切换任务（防抖）
                        let switchTask = DispatchWorkItem {
                            let (closestId, _) = findClosestCardToCenter(offsets: offsets)
                            
                            // 如果找到最接近中心的卡片，且不是当前选中的，则切换
                            if let closestId = closestId,
                               closestId != selectedTripId,
                               let trip = validTrips.first(where: { $0.id == closestId }),
                               let destinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                               destinations.count >= 2 {
                                handleCardAppear(trip: trip, destinations: destinations)
                            }
                        }
                        
                        // 创建磁吸任务（滚动停止后自动居中并分页）
                        let snapTaskWorkItem = DispatchWorkItem {
                            // 标记用户滚动结束
                            isUserScrolling = false
                            
                            let (closestId, minDistance) = findClosestCardToCenter(offsets: offsets)
                            
                            // 计算应该跳转到哪张卡片
                            let cardWidth: CGFloat = 320
                            let cardSpacing: CGFloat = 12
                            let cardStep = cardWidth + cardSpacing
                            
                            // 根据滚动速度决定跳转策略
                            // 目标：轻滑只跳一张，快速滑动可以跳多张
                            let slowSpeedThreshold: CGFloat = 150 // 慢速阈值（点/秒），低于此速度使用最近卡片
                            let fastSpeedThreshold: CGFloat = 500 // 快速阈值（点/秒），超过此速度可以跳2张
                            
                            var targetTripId: UUID? = closestId
                            
                            // 如果滚动速度较快，根据速度决定跳转几张卡片
                            if let currentIndex = validTrips.firstIndex(where: { $0.id == selectedTripId }) {
                                let absVelocity = abs(scrollVelocity)
                                
                                if absVelocity > fastSpeedThreshold {
                                    // 快速滑动：根据速度跳转1-2张卡片
                                    let direction = scrollVelocity < 0 ? -1 : 1
                                    // 速度越快，跳转越多（但最多2张）
                                    let speedFactor = min(2.0, (absVelocity - fastSpeedThreshold) / 300 + 1.0)
                                    let jumpCount = max(1, Int(round(speedFactor)))
                                    let targetIndex = max(0, min(validTrips.count - 1, currentIndex + (jumpCount * direction)))
                                    if targetIndex < validTrips.count && targetIndex != currentIndex {
                                        targetTripId = validTrips[targetIndex].id
                                    }
                                } else if absVelocity > slowSpeedThreshold {
                                    // 中等速度：跳转1张卡片（确保轻滑只跳一张）
                                    let direction = scrollVelocity < 0 ? -1 : 1
                                    let targetIndex = max(0, min(validTrips.count - 1, currentIndex + direction))
                                    if targetIndex < validTrips.count && targetIndex != currentIndex {
                                        targetTripId = validTrips[targetIndex].id
                                    }
                                }
                                // 慢速滑动（absVelocity <= slowSpeedThreshold）：使用最近的卡片（closestId），自动吸附
                            }
                            
                            // 如果找到目标卡片，且距离中心超过阈值，则自动吸附到中心
                            if let targetId = targetTripId,
                               let targetTrip = validTrips.first(where: { $0.id == targetId }),
                               let destinations = targetTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                               destinations.count >= 2 {
                                
                                // 检查是否需要吸附（距离中心超过阈值）
                                let (_, targetDistance) = findClosestCardToCenter(offsets: offsets.filter { $0.tripId == targetId })
                                
                                if targetDistance > 10 || targetId != selectedTripId {
                                    // 使用Q弹的弹簧动画
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.2)) {
                                        proxy.scrollTo(targetId, anchor: .center)
                                    }
                                    
                                    // 更新选中状态
                                    if targetId != selectedTripId {
                                        handleCardAppear(trip: targetTrip, destinations: destinations)
                                    }
                                }
                            }
                            
                            // 重置速度
                            scrollVelocity = 0
                            isScrolling = false
                        }
                        
                        // 保存任务引用
                        cardSwitchTask = switchTask
                        self.snapTask = snapTaskWorkItem
                        
                        // 延迟执行切换任务（防抖：避免快速滚动时频繁切换）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: switchTask)
                        
                        // 延迟执行磁吸任务（滑动停止后自动吸附，延迟稍长以确保滚动完全停止）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: snapTaskWorkItem)
                    }
                    .padding(.bottom, 20)
                    .onAppear {
                        // 在线路tab视图，确保卡片滚动位置与选中的旅程一致
                        if let currentSelectedId = selectedTripId,
                           let selectedTrip = validTrips.first(where: { $0.id == currentSelectedId }),
                           let destinations = selectedTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                           destinations.count >= 2 {
                            // 如果已经有选中的卡片，滚动到该卡片并居中（保持地图和卡片一致）
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    proxy.scrollTo(currentSelectedId, anchor: .center)
                                }
                            }
                        } else if selectedTripId == nil, let firstTrip = validTrips.first {
                            // 如果没有选中的卡片，选中第一个
                            let destinations = firstTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }) ?? []
                            if destinations.count >= 2 {
                                handleCardAppear(trip: firstTrip, destinations: destinations)
                                
                                // 确保第一个旅程的路线已计算（使用incremental模式检查缓存）
                                if tripRoutes[firstTrip.id] == nil || tripRoutes[firstTrip.id]?.isEmpty == true {
                                    let coordinates = destinations.map { $0.coordinate }
                                    Task {
                                        // 使用incremental模式，会先检查缓存，避免重复计算
                                        await calculateRoutesForTrip(tripId: firstTrip.id, coordinates: coordinates, incremental: true)
                                    }
                                }
                                
                                // 滚动到第一个卡片并居中（首次显示）
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        proxy.scrollTo(firstTrip.id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .opacity(shouldHideRouteCards ? 0 : 1) // 使用透明度隐藏，保持滚动位置
                .allowsHitTesting(!shouldHideRouteCards) // 隐藏时禁用交互
            }
        }
        .zIndex(3)
    }
    
    // 处理卡片出现（切换地图视图和连线）
    private func handleCardAppear(trip: TravelTrip, destinations: [TravelDestination]) {
        // 如果已经是当前选中的旅程，直接返回
        if selectedTripId == trip.id {
            return
        }
        
        print("🔄 切换到旅程: \(trip.name)，包含 \(destinations.count) 个地点")
        
        // 更新选中的旅程ID
        selectedTripId = trip.id
        
        // 如果在线路tab，清除聚合缓存，以便重新计算只显示当前线路的地点
        if autoShowRouteCards {
            clearClusterCache()
            // 确保显示旅程连线
            if !showTripConnections {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showTripConnections = true
                }
            }
        }
        
        // 缩放地图到该旅程的范围
        zoomToTripDestinations(destinations)
        
        // 确保该旅程的路线已计算（如果还没有计算，使用incremental模式检查缓存）
        if tripRoutes[trip.id] == nil || tripRoutes[trip.id]?.isEmpty == true {
            let coordinates = destinations.map { $0.coordinate }
            Task {
                // 使用incremental模式，会先检查缓存，避免重复计算
                await calculateRoutesForTrip(tripId: trip.id, coordinates: coordinates, incremental: true)
            }
        }
    }
    
    // 查找最接近屏幕中心的卡片
    private func findClosestCardToCenter(offsets: [ScrollOffsetInfo]) -> (UUID?, CGFloat) {
        let screenWidth = UIScreen.main.bounds.width
        let centerX = screenWidth / 2
        let cardWidth: CGFloat = 320 // 卡片宽度
        let cardCenterOffset = cardWidth / 2 // 卡片中心偏移量
        
        var closestTripId: UUID?
        var minDistance: CGFloat = .infinity
        
        for offsetInfo in offsets {
            // 计算卡片中心距离屏幕中心的距离
            // 卡片中心 = offset + cardCenterOffset
            let cardCenterX = offsetInfo.offset + cardCenterOffset
            let distance = abs(cardCenterX - centerX)
            
            // 只考虑在屏幕可见范围内的卡片（offset 在 -200 到 screenWidth+200 之间）
            if offsetInfo.offset > -200 && offsetInfo.offset < screenWidth + 200 {
                if distance < minDistance {
                    minDistance = distance
                    closestTripId = offsetInfo.tripId
                }
            }
        }
        
        return (closestTripId, minDistance)
    }
    
    // 浮动按钮
    private var floatingButtons: some View {
        ZStack {
            // 搜索框（点击搜索按钮时显示）
            if showSearchResults {
                VStack {
                    searchBox
                        .padding(.horizontal, 60)
                        .padding(.top, 15)
                    Spacer()
                }
            }
            
            // 右下角：TabView 按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // 当地点预览卡片出现时，或线路卡片显示时，隐藏按钮容器
                    if selectedDestination == nil && !showRouteCards {
                    bottomRightTabView
                        .padding(.trailing)
                            .padding(.bottom, 20)
                            .transition(.opacity)
                    }
                }
            }
        }
        .zIndex(4) // 确保浮动按钮在折叠覆盖层之上
    }
    
    // 右下角按钮组：参考iPhone地图应用的紧凑样式，支持滑动
    private var bottomRightTabView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                // 定位按钮
                buttonGroupItem(
                    icon: "location.fill",
                    title: "定位",
                    isActive: false,
                    action: {
                        centerMapOnCurrentLocation()
                    }
                )
                
                // 打卡按钮
                buttonGroupItem(
                    icon: "DakaIcon",
                    title: "打卡",
                    isActive: false,
                    action: {
                        handleCheckIn()
                    }
                )
                
                // 回忆泡泡按钮
                buttonGroupItem(
                    icon: "PaopaoIcon",
                    title: "回忆",
                    isActive: false,
                    action: {
                        triggerMemoryBubble()
                    }
                )
                
                // 搜索按钮
                buttonGroupItem(
                    icon: "magnifyingglass",
                    title: "搜索",
                    isActive: showSearchResults,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if showSearchResults {
                                // 如果搜索已显示，则关闭
                                searchText = ""
                                searchResults = []
                                showSearchResults = false
                                isSearchFieldFocused = false
                            } else {
                                // 如果搜索未显示，则显示搜索框
                                showSearchResults = true
                                // 延迟一小段时间后激活焦点，确保搜索框已显示
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFieldFocused = true
                                }
                            }
                        }
                    }
                )
                
                // 地图样式切换按钮
                buttonGroupItem(
                    icon: currentMapStyle.iconName,
                    title: "样式",
                    isActive: false,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingMapStylePicker.toggle()
                        }
                    }
                )
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
        .frame(height: 200) // 调整容器高度为200
        .background(
            containerBackgroundMaterial
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 2)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    // 按钮组中的单个按钮项（参考iPhone地图应用样式）
    private func buttonGroupItem(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Group {
                        // 判断是系统图标还是自定义图片资源
                        if icon == "PaopaoIcon" {
                            // PaopaoIcon：在深色地图模式下显示为白色
                            Image(icon)
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .foregroundColor(buttonIconColor(isActive: isActive))
                                .frame(width: 22, height: 22)
                        } else if icon == "DakaIcon" {
                            // DakaIcon：打卡按钮自定义图标
                            // 浅色模式显示实际颜色，系统深色模式显示DakaIcon(D)
                            Image((colorScheme == .dark) ? "DakaIcon(D)" : icon)
                                .resizable()
                                .renderingMode(.original)
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        } else {
                            // 系统图标
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: isActive ? .semibold : .regular))
                                .foregroundColor(buttonIconColor(isActive: isActive))
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .background(
                    Group {
                        if isActive {
                            Circle()
                                .fill(activeButtonBackground)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(isDarkMapStyle ? 0.3 : 0.2), lineWidth: 1.5)
                                )
                        }
                    }
                )
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(isDarkMapStyle ? .white.opacity(0.9) : .primary.opacity(0.9))
                    .frame(height: 14)
                    .padding(.top, -4)
            }
        }
        .buttonStyle(.plain)
    }
    
    // 激活状态的按钮背景（深色地图模式使用更明显的背景）
    private var activeButtonBackground: Color {
        if isDarkMapStyle {
            // 深色地图模式：使用灰色背景，提高辨识度
            return Color.white.opacity(0.25)
        } else {
            // 浅色地图模式：使用浅灰色背景
            return Color.gray.opacity(0.15)
        }
    }
    
    // 根据地图样式和激活状态返回按钮图标颜色
    private func buttonIconColor(isActive: Bool) -> Color {
        if isActive {
            // 激活状态：深色地图模式使用白色，浅色地图模式使用黑色
            return isDarkMapStyle ? .white : .black
        } else {
            // 非激活状态：深色地图模式下使用白色/浅灰色，浅色地图模式下使用深色
            return isDarkMapStyle ? .white.opacity(0.9) : .primary
        }
    }
    
    // 根据地图样式返回容器背景材质（深色地图模式透明度为0.1）
    @ViewBuilder
    private var containerBackgroundMaterial: some View {
        if isDarkMapStyle {
            // 深色地图模式：使用黑色半透明背景（透明度0.1），叠加超薄材质
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.1))
            }
        } else {
            // 浅色地图模式：使用标准材质
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
    
    // 搜索框（仅在showSearchResults为true时显示）
    private var searchBox: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15, weight: .medium))
                
                TextField(searchPlaceholderText, text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { _, newValue in
                        if newValue.isEmpty {
                            searchResults = []
                        } else {
                            performSearch()
                        }
                    }
                
                Button {
                    searchText = ""
                    searchResults = []
                    showSearchResults = false
                    isSearchFieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial) // iOS 16 标准材质
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            // 搜索结果列表
            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.prefix(5).enumerated()), id: \.offset) { index, result in
                        SearchResultRow(mapItem: result) {
                            selectSearchResult(result)
                        }
                        
                        if index < min(4, searchResults.count - 1) {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 21)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                .padding(.top, 2)
            }
        }
    }
    
    // 地图样式选择器
    private var mapStylePicker: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("map_style_title".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    ForEach(MapStyle.allCases, id: \.self) { style in
                        MapStyleCard(
                            style: style,
                            isSelected: currentMapStyle == style
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentMapStyle = style
                                showingMapStylePicker = false
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        showingMapStylePicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
    }
    
    // 目的地添加表单
    @ViewBuilder
    private var destinationSheet: some View {
        if let locationData = prefilledLocationData {
            AddDestinationView(
                prefilledLocation: locationData.location,
                prefilledName: locationData.name,
                prefilledCountry: locationData.country,
                prefilledCategory: locationData.category
            )
        } else if isGeocodingLocation {
            // 显示加载状态，等待地理编码完成
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("getting_location_info".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("identifying_location".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else {
            AddDestinationView()
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
    
    // 6个明确的缩放级别定义
    enum ZoomLevel: Int, CaseIterable {
        case world = 1      // 世界/大洲级别
        case country = 2   // 国家级别  
        case province = 3  // 省级别
        case city = 4      // 市级别
        case district = 5  // 区级别
        case street = 6    // 街道级别
        
        var distance: Double {
            switch self {
            case .world: return 250000    // 250km
            case .country: return 100000  // 100km
            case .province: return 50000   // 50km
            case .city: return 25000      // 25km
            case .district: return 5000   // 5km
            case .street: return 0        // 不聚合
            }
        }
        
        var description: String {
            switch self {
            case .world: return "世界/大洲"
            case .country: return "国家"
            case .province: return "省份"
            case .city: return "城市"
            case .district: return "区域"
            case .street: return "街道"
            }
        }
    }
    
    // 根据缩放级别计算聚合距离
    private var clusterDistance: Double {
        return currentZoomLevelEnum.distance
    }
    
    // 获取当前缩放级别枚举
    private var currentZoomLevelEnum: ZoomLevel {
        let zoom = currentZoomLevel
        if zoom < 4 { return .world }
        else if zoom < 6 { return .country }
        else if zoom < 8 { return .province }
        else if zoom < 10 { return .city }
        else if zoom < 12 { return .district }
        else { return .street }
    }
    
    // 生成地点签名（用于检测地点变化：删除、坐标变化、所属旅程变化）
    private var destinationsSignature: String {
        // 为每个地点生成签名：ID + 坐标 + 所属旅程ID + 访问日期（用于排序）
        let signatures = destinations.map { dest in
            let tripId = dest.trip?.id.uuidString ?? "nil"
            // 坐标精度到小数点后6位（约0.1米精度）
            let lat = String(format: "%.6f", dest.latitude)
            let lon = String(format: "%.6f", dest.longitude)
            let visitDate = String(format: "%.0f", dest.visitDate.timeIntervalSince1970)
            return "\(dest.id.uuidString):\(lat),\(lon):\(tripId):\(visitDate)"
        }
        // 按ID排序以确保一致性
        return signatures.sorted().joined(separator: "|")
    }
    
    // 获取屏幕可见区域内的地点（优化：只计算可见区域）
    private var visibleDestinationsInRegion: [TravelDestination] {
        // 如果在线路tab且选中了线路卡片，只显示该线路的地点
        var filteredDestinations = destinations
        if autoShowRouteCards, let selectedTripId = selectedTripId {
            // 只显示当前选中线路的地点
            if let selectedTrip = trips.first(where: { $0.id == selectedTripId }),
               let tripDestinations = selectedTrip.destinations {
                filteredDestinations = Array(tripDestinations)
            } else {
                // 如果找不到选中的旅程，返回空数组
                return []
            }
        }
        
        guard let region = visibleRegion else {
            // 如果没有可见区域信息，返回过滤后的地点（兼容性处理）
            return filteredDestinations
        }
        
        // 计算可见区域的边界
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        
        // 添加一些边距，确保边缘地点也被包含（避免聚合时遗漏）
        let margin = max(region.span.latitudeDelta, region.span.longitudeDelta) * 0.1 // 10% 边距
        let expandedMinLat = minLat - margin
        let expandedMaxLat = maxLat + margin
        let expandedMinLon = minLon - margin
        let expandedMaxLon = maxLon + margin
        
        // 过滤出在可见区域内的地点
        return filteredDestinations.filter { destination in
            let lat = destination.latitude
            let lon = destination.longitude
            return lat >= expandedMinLat && lat <= expandedMaxLat &&
                   lon >= expandedMinLon && lon <= expandedMaxLon
        }
    }
    
    // 生成可见区域的缓存键（用于判断区域是否变化）
    private var visibleRegionKey: String {
        guard let region = visibleRegion else { return "" }
        // 使用中心点和跨度生成唯一标识（精度到小数点后3位，避免微小变化导致频繁重算）
        let centerLat = String(format: "%.3f", region.center.latitude)
        let centerLon = String(format: "%.3f", region.center.longitude)
        let spanLat = String(format: "%.3f", region.span.latitudeDelta)
        let spanLon = String(format: "%.3f", region.span.longitudeDelta)
        // 如果在线路tab，包含选中的旅程ID，以便在切换线路时重新计算
        let tripIdSuffix = autoShowRouteCards ? (selectedTripId?.uuidString ?? "nil") : "all"
        return "\(centerLat),\(centerLon),\(spanLat),\(spanLon),\(tripIdSuffix)"
    }
    
    // 计算聚合后的标注点（按级别触发计算，仅计算可见区域）
    private var clusterAnnotations: [ClusterAnnotation] {
        let currentZoomEnum = currentZoomLevelEnum
        
        // 只计算可见区域内的地点
        let visibleDestinations = visibleDestinationsInRegion
        let currentCount = visibleDestinations.count
        let currentRegionKey = visibleRegionKey
        
        // 检查缓存是否有效：缩放级别、地点数量、可见区域都未变化时才使用缓存
        if !cachedClusterAnnotations.isEmpty &&
           cachedZoomLevelEnum == currentZoomEnum &&
           cachedDestinationsCount == currentCount &&
           cachedVisibleRegionKey == currentRegionKey {
            return cachedClusterAnnotations
        }
        
        // 性能监控：记录计算开始时间
        let startTime = Date()
        
        let distance = clusterDistance
        var clusters: [ClusterAnnotation] = []
        
        // 如果聚合距离为0，返回所有单独的点
        if distance == 0 {
            clusters = visibleDestinations.map { ClusterAnnotation(destinations: [$0]) }
        } else {
            // 优化的聚合算法：减少重复计算
            clusters = calculateClustersOptimized(distance: distance, from: visibleDestinations)
        }
        
        // 更新缓存
        cachedClusterAnnotations = clusters
        cachedZoomLevelEnum = currentZoomEnum
        cachedDestinationsCount = currentCount
        cachedVisibleRegionKey = currentRegionKey
        lastCalculationTime = Date()
        
        // 性能监控：记录计算耗时和级别变化
        let calculationTime = Date().timeIntervalSince(startTime)
        let totalDestinations = destinations.count
        print("🔄 聚合计算完成: \(currentZoomEnum.description)级别, 耗时: \(String(format: "%.3f", calculationTime))秒, 可见地点: \(currentCount)/\(totalDestinations)个")
        
        return clusters
    }
    
    // 优化的聚合计算算法
    private func calculateClustersOptimized(distance: Double, from destinations: [TravelDestination]) -> [ClusterAnnotation] {
        var clusters: [ClusterAnnotation] = []
        var processed: Set<UUID> = []
        
        // 按纬度排序，减少不必要的距离计算
        let sortedDestinations = destinations.sorted { $0.latitude < $1.latitude }
        
        for destination in sortedDestinations {
            if processed.contains(destination.id) { continue }
            
            var clusterDestinations = [destination]
            processed.insert(destination.id)
            
            // 只检查纬度相近的地点（优化：减少计算量）
            let latitudeThreshold = distance / 111000.0 // 1度纬度约111km
            
            for other in sortedDestinations {
                if processed.contains(other.id) { continue }
                
                // 快速纬度过滤
                if abs(destination.latitude - other.latitude) > latitudeThreshold {
                    continue
                }
                
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
    
    // 清除聚合缓存
    private func clearClusterCache() {
        cachedClusterAnnotations = []
        cachedZoomLevelEnum = .world
        cachedDestinationsCount = 0
        cachedVisibleRegionKey = ""
        lastCalculationTime = Date()
        print("🧹 已清除聚合缓存")
    }
    
    // 处理地点变化（立即更新路线）
    private func handleDestinationsChange() {
        print("🔄 处理地点变化，重新计算路线...")
        // 清除聚合缓存
        clearClusterCache()
        // 清除路线缓存，强制重新计算
        tripRoutes.removeAll()
        // 如果显示连线，重新计算所有路线
        if showTripConnections {
            calculateRoutesForAllTrips()
        }
        // 如果在线路tab且选中了线路，重新计算该线路的路线
        if autoShowRouteCards, let selectedTripId = selectedTripId,
           let selectedTrip = trips.first(where: { $0.id == selectedTripId }),
           let tripDestinations = selectedTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
           tripDestinations.count >= 2 {
            let coordinates = tripDestinations.map { $0.coordinate }
            Task {
                // 强制重新计算（不使用缓存）
                await calculateRoutesForTrip(tripId: selectedTripId, coordinates: coordinates, incremental: false)
            }
        } else if autoShowRouteCards, let selectedTripId = selectedTripId {
            // 如果选中线路的地点数量不足2个，清除该线路的路线
            tripRoutes.removeValue(forKey: selectedTripId)
        }
        // 更新签名
        lastDestinationsSignature = destinationsSignature
    }
    
    // 检查地点变化并更新路线（通过签名比较）
    private func checkDestinationsChange() {
        let currentSignature = destinationsSignature
        // 如果签名发生变化，说明有地点被删除、坐标变化或所属旅程变化
        if lastDestinationsSignature != "" && lastDestinationsSignature != currentSignature {
            print("🔄 通过签名检测到地点变化")
            handleDestinationsChange()
        } else {
            // 即使签名相同，也更新签名（防止下次误判）
            lastDestinationsSignature = currentSignature
        }
    }
    
    // 启动定期检查（作为备用方案）
    private func startPeriodicCheck() {
        // 每2秒检查一次地点变化
        periodicCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [self] _ in
            checkDestinationsChange()
        }
    }
    
    // 停止定期检查
    private func stopPeriodicCheck() {
        periodicCheckTimer?.invalidate()
        periodicCheckTimer = nil
    }
    
    // 为所有旅程计算路线（优化版：增量更新 + 分批处理）
    private func calculateRoutesForAllTrips() {
        print("🗺️ 开始计算所有旅程的路线...")
        
        // 收集需要计算路线的旅程
        var tripsToCalculate: [(UUID, [CLLocationCoordinate2D])] = []
        
        for trip in trips {
            guard let tripDestinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                  tripDestinations.count >= 2 else {
                continue
            }
            
            let coordinates = tripDestinations.map { $0.coordinate }
            
            // 检查是否需要重新计算（增量更新）
            // 如果路线数量匹配，检查所有路线是否都在缓存中
            if let existingRoutes = tripRoutes[trip.id],
               existingRoutes.count == coordinates.count - 1 {
                // 检查所有路线段是否都在缓存中
                var allCached = true
                for i in 0..<coordinates.count - 1 {
                    if routeManager.getCachedRoute(
                        from: coordinates[i],
                        to: coordinates[i + 1]
                    ) == nil {
                        allCached = false
                        break
                    }
                }
                
                if allCached {
                    print("✅ 旅程 \(trip.id.uuidString.prefix(8)) 的路线无需重新计算（使用缓存）")
                    continue
                }
            }
            
            tripsToCalculate.append((trip.id, coordinates))
        }
        
        // 分批处理：每次只计算一个旅程，避免请求过多导致限流
        // 这样可以避免在国家级别时同时发起太多请求
        Task {
            for (tripId, coordinates) in tripsToCalculate {
                await calculateRoutesForTrip(tripId: tripId, coordinates: coordinates, incremental: true)
                // 在旅程之间添加小延迟，避免请求过于密集
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms 延迟
            }
            print("✅ 所有旅程的路线计算完成")
        }
    }
    
    // 为单个旅程计算路线（优化版：并发计算 + 渐进式更新 + 增量更新）
    /// - Parameters:
    ///   - tripId: 旅程ID
    ///   - coordinates: 地点坐标数组
    ///   - incremental: 是否使用增量更新（检查缓存）
    private func calculateRoutesForTrip(tripId: UUID, coordinates: [CLLocationCoordinate2D], incremental: Bool = false) async {
        guard coordinates.count >= 2 else { return }
        
        // 如果路线已经完整计算过，直接返回（避免重复计算）
        if let existingRoutes = tripRoutes[tripId],
           existingRoutes.count == coordinates.count - 1,
           existingRoutes.allSatisfy({ $0 != nil }) {
            // 路线已完整，无需重新计算
            return
        }
        
        // 初始化路线数组（保持顺序）
        var calculatedRoutes: [MKRoute?] = Array(repeating: nil, count: coordinates.count - 1)
        
        // 如果使用增量更新，先检查缓存
        if incremental {
            for i in 0..<coordinates.count - 1 {
                if let cachedRoute = routeManager.getCachedRoute(
                    from: coordinates[i],
                    to: coordinates[i + 1]
                ) {
                    calculatedRoutes[i] = cachedRoute
                }
            }
            
            // 如果所有路线都已缓存，直接更新 UI
            let allCached = calculatedRoutes.allSatisfy { $0 != nil }
            if allCached {
                await MainActor.run {
                    // 保持 [MKRoute?] 格式，不进行 compactMap，以保持索引对应关系
                    tripRoutes[tripId] = calculatedRoutes
                    print("✅ 旅程 \(tripId.uuidString.prefix(8)) 的路线全部来自缓存，共 \(calculatedRoutes.count) 段路线")
                }
                return
            }
        }
        
        // 使用 TaskGroup 并发计算所有路线段（只计算未缓存的）
        await withTaskGroup(of: (Int, MKRoute?).self) { group in
            // 为每段路线创建任务（跳过已缓存的）
            for i in 0..<coordinates.count - 1 {
                // 如果已缓存，跳过
                if incremental && calculatedRoutes[i] != nil {
                    continue
                }
                
                let source = coordinates[i]
                let destination = coordinates[i + 1]
                let index = i
                
                group.addTask {
                    // 使用 async/await 版本，性能更好
                    let route = await self.routeManager.calculateRoute(from: source, to: destination)
                    return (index, route)
                }
            }
            
            // 收集结果并渐进式更新 UI
            for await (index, route) in group {
                calculatedRoutes[index] = route
                
                // 每计算完一个路线就立即更新 UI（渐进式显示）
                await MainActor.run {
                    // 保持 [MKRoute?] 格式，不进行 compactMap，以保持索引对应关系
                    // 只更新到当前完成的索引，保留 nil 值
                    let routesToShow = Array(calculatedRoutes.prefix(index + 1))
                    // 只有当新路线数量增加时才更新（避免重复更新）
                    let currentCount = tripRoutes[tripId]?.count ?? 0
                    if routesToShow.count > currentCount {
                        tripRoutes[tripId] = routesToShow
                    }
                }
            }
        }
        
        // 最终更新：确保所有路线都已显示
        await MainActor.run {
            // 保持 [MKRoute?] 格式，不进行 compactMap，以保持索引对应关系
            tripRoutes[tripId] = calculatedRoutes
            let successCount = calculatedRoutes.compactMap { $0 }.count
            print("✅ 旅程 \(tripId.uuidString.prefix(8)) 的路线计算完成，共 \(successCount)/\(coordinates.count - 1) 段路线")
        }
    }
    
    // 处理长按手势
    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        print("🗺️ 长按地图位置: (\(coordinate.latitude), \(coordinate.longitude))")
        longPressLocation = coordinate
        
        // 立即显示添加目的地界面，显示加载状态
        showingAddDestination = true
        
        // 执行反向地理编码
        reverseGeocodeLocation(coordinate: coordinate)
    }
    
    // 处理打卡功能：使用用户当前位置添加目的地
    private func handleCheckIn() {
        print("📍 点击打卡按钮")
        
        // 检查是否有已知位置
        if let userLocation = locationManager.lastKnownLocation {
            print("✅ 使用已知位置进行打卡: (\(userLocation.latitude), \(userLocation.longitude))")
            
            // 立即显示添加目的地界面，显示加载状态
            showingAddDestination = true
            
            // 执行反向地理编码
            reverseGeocodeLocation(coordinate: userLocation)
        } else {
            // 如果没有位置信息，先请求定位
            print("⏳ 没有已知位置，请求定位中...")
            
            // 立即显示添加目的地界面，显示加载状态
            showingAddDestination = true
            isGeocodingLocation = true
            isWaitingForLocation = true
            
            // 请求位置更新
            locationManager.requestLocation()
            
            // 使用定时器等待定位更新（等待最多2秒）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // 如果还在等待状态，说明定位超时
                if self.isWaitingForLocation {
                    print("⏰ 定位超时，使用备用方案")
                    self.fallbackCheckInWithoutLocation()
                }
            }
        }
    }
    
    // 打卡备用方案：无法获取位置时的处理
    private func fallbackCheckInWithoutLocation() {
        isGeocodingLocation = false
        isWaitingForLocation = false
        print("❌ 无法获取当前位置，打卡功能需要定位权限")
        
        // 关闭弹窗，用户可以重新尝试或使用长按功能
        showingAddDestination = false
        
        // 注意：如果需要，可以在这里添加一个 Alert 提示用户需要定位权限
    }
    
    // 反向地理编码：获取城市和国家信息（带多重回退）
    private func reverseGeocodeLocation(coordinate: CLLocationCoordinate2D) {
        isGeocodingLocation = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        func succeed(with placemark: CLPlacemark) {
            isGeocodingLocation = false
            let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
            let countryName = placemark.country ?? "unknown_country".localized
            let isoCountryCode = placemark.isoCountryCode ?? ""
            let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
            print("✅ 反向地理编码成功:\n   城市: \(cityName)\n   国家: \(countryName)\n   ISO代码: \(isoCountryCode)\n   分类: \(category)")
            let mkPlacemark = MKPlacemark(placemark: placemark)
            let mapItem = MKMapItem(placemark: mkPlacemark)
            mapItem.name = cityName
            prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
            // 不需要再次设置 showingAddDestination，界面已经显示
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
            print("❌ " + "reverse_geocoding_failed".localized(with: error?.localizedDescription ?? "未知错误"))
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
                let cityName = item.name ?? item.placemark.locality ?? "selected_location".localized
                let countryName = item.placemark.country ?? "unknown_country".localized
                let isoCountryCode = item.placemark.isoCountryCode ?? ""
                let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
                print("✅ " + "nearby_search_success".localized(with: cityName, countryName))
                let mapItem = item
                mapItem.name = cityName
                DispatchQueue.main.async {
                    self.isGeocodingLocation = false
                    self.prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
                    // 不需要再次设置 showingAddDestination，界面已经显示
                }
            } else {
                print("⚠️ " + "nearby_search_failed".localized(with: error?.localizedDescription ?? "无结果"))
                DispatchQueue.main.async { self.fallbackWithCoordinateOnly(coordinate: coordinate) }
            }
        }
    }

    // 备用方案2：仅根据坐标进行国内/国外判断并提供占位名称
    private func fallbackWithCoordinateOnly(coordinate: CLLocationCoordinate2D) {
        isGeocodingLocation = false
        let category = isInChinaBoundingBox(coordinate) ? "domestic" : "international"
        let countryName = category == "domestic" ? "中国" : "unknown_country".localized
        let cityName = "selected_location".localized
        print("🛟 " + "coordinate_fallback".localized(with: cityName, countryName, category))
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = cityName
        prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
        // 不需要再次设置 showingAddDestination，界面已经显示
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
    
    // 缩放到旅程的所有地点范围
    private func zoomToTripDestinations(_ destinations: [TravelDestination]) {
        guard !destinations.isEmpty else { return }
        
        let coordinates = destinations.map { $0.coordinate }
        
        // 计算边界
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        // 计算中心点
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // 计算跨度，添加一些边距（1.5倍）以确保所有地点都在视野内
        let latSpan = max((maxLat - minLat) * 1.5, 0.01) // 至少0.01度
        let lonSpan = max((maxLon - minLon) * 1.5, 0.01)
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            mapCameraPosition = .region(region)
        }
        
        print("🗺️ 地图已缩放到旅程范围，包含 \(destinations.count) 个地点")
    }
    
    
    // 根据国家代码获取地图区域
    private func getRegionForCountry(countryCode: String, userLocation: CLLocationCoordinate2D) -> MKCoordinateRegion {
        switch countryCode {
        case "CN":
            // 中国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 40.0)
            )
        case "US":
            // 美国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 60.0)
            )
        case "JP":
            // 日本
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            )
        case "KR":
            // 韩国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5),
                span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            )
        case "SG":
            // 新加坡
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        case "TH":
            // 泰国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 15.8700, longitude: 100.9925),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            )
        case "MY":
            // 马来西亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 4.2105, longitude: 101.9758),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "ID":
            // 印度尼西亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -0.7893, longitude: 113.9213),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        case "PH":
            // 菲律宾
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "VN":
            // 越南
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 14.0583, longitude: 108.2772),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 10.0)
            )
        case "IN":
            // 印度
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 30.0)
            )
        case "AU":
            // 澳大利亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751),
                span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 50.0)
            )
        case "NZ":
            // 新西兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -41.2865, longitude: 174.7762),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 15.0)
            )
        case "CA":
            // 加拿大
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 56.1304, longitude: -106.3468),
                span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 80.0)
            )
        case "MX":
            // 墨西哥
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.6345, longitude: -102.5528),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        case "GB":
            // 英国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 54.0, longitude: -2.0),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "FR":
            // 法国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.2276, longitude: 2.2137),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "DE":
            // 德国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 10.0)
            )
        case "IT":
            // 意大利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.8719, longitude: 12.5674),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "ES":
            // 西班牙
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.4637, longitude: -3.7492),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "NL":
            // 荷兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 52.1326, longitude: 5.2913),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
            )
        case "CH":
            // 瑞士
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275),
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        case "AT":
            // 奥地利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 47.5162, longitude: 14.5501),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 5.0)
            )
        case "BE":
            // 比利时
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 50.5039, longitude: 4.4699),
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        case "DK":
            // 丹麦
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 56.2639, longitude: 9.5018),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            )
        case "FI":
            // 芬兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 61.9241, longitude: 25.7482),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 10.0)
            )
        case "NO":
            // 挪威
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 60.4720, longitude: 8.4689),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 8.0)
            )
        case "SE":
            // 瑞典
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 60.1282, longitude: 18.6435),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0)
            )
        case "PL":
            // 波兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.9194, longitude: 19.1451),
                span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 8.0)
            )
        case "CZ":
            // 捷克
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 49.8175, longitude: 15.4730),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 4.0)
            )
        case "HU":
            // 匈牙利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 47.1625, longitude: 19.5033),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            )
        case "GR":
            // 希腊
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.0742, longitude: 21.8243),
                span: MKCoordinateSpan(latitudeDelta: 7.0, longitudeDelta: 8.0)
            )
        case "PT":
            // 葡萄牙
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.3999, longitude: -8.2245),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            )
        case "IE":
            // 爱尔兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 53.4129, longitude: -8.2439),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 4.0)
            )
        case "LU":
            // 卢森堡
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 49.8153, longitude: 6.1296),
                span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
            )
        case "RU":
            // 俄罗斯
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 61.5240, longitude: 105.3188),
                span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 80.0)
            )
        case "UA":
            // 乌克兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 12.0)
            )
        case "TR":
            // 土耳其
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 38.9637, longitude: 35.2433),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 12.0)
            )
        case "IL":
            // 以色列
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 31.0461, longitude: 34.8516),
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        case "AE":
            // 阿联酋
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.4241, longitude: 53.8478),
                span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            )
        case "SA":
            // 沙特阿拉伯
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.8859, longitude: 45.0792),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 20.0)
            )
        case "QA":
            // 卡塔尔
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 25.3548, longitude: 51.1839),
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        case "KW":
            // 科威特
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 29.3759, longitude: 47.9774),
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        case "BH":
            // 巴林
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 26.0667, longitude: 50.5577),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        case "OM":
            // 阿曼
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 21.4735, longitude: 55.9754),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "JO":
            // 约旦
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 30.5852, longitude: 36.2384),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 4.0)
            )
        case "LB":
            // 黎巴嫩
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 33.8547, longitude: 35.8623),
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
            )
        case "EG":
            // 埃及
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 26.0975, longitude: 31.2357),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 12.0)
            )
        case "ZA":
            // 南非
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -30.5595, longitude: 22.9375),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        case "BR":
            // 巴西
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -14.2350, longitude: -51.9253),
                span: MKCoordinateSpan(latitudeDelta: 35.0, longitudeDelta: 45.0)
            )
        case "AR":
            // 阿根廷
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -38.4161, longitude: -63.6167),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 20.0)
            )
        case "CL":
            // 智利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -35.6751, longitude: -71.5430),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 5.0)
            )
        case "CO":
            // 哥伦比亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 4.5709, longitude: -74.2973),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 12.0)
            )
        case "PE":
            // 秘鲁
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -9.1900, longitude: -75.0152),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 15.0)
            )
        case "IS":
            // 冰岛
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 64.9631, longitude: -19.0208),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 6.0)
            )
        default:
            // 其他国家 - 使用一个合理的世界地图视野作为默认值
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 30.0, longitude: 0.0),
                span: MKCoordinateSpan(latitudeDelta: 60.0, longitudeDelta: 120.0)
            )
        }
    }
    
    // 将地图定位到用户选择的国家
    private func centerMapOnSelectedCountry() {
        let countryCode = countryManager.currentCountry.rawValue
        let region = getRegionForCountry(countryCode: countryCode, userLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(region)
        }
        print("📍 地图定位到用户选择的国家: \(countryManager.currentCountry.displayName) (\(countryCode))")
    }
    
    // 移动地图到指定地点，以国家视野范围定位到目的地为中心
    private func moveMapToDestination(_ destination: TravelDestination) {
        // 获取地点的国家名称
        let countryName = destination.country
        
        // 根据国家名称获取国家代码
        let countryCode = getCountryCodeFromName(countryName)
        
        // 获取预设的国家视野范围
        let countryRegion = getRegionForCountry(countryCode: countryCode, userLocation: destination.coordinate)
        
        // 创建以目的地为中心，使用国家视野范围的新区域
        let region = MKCoordinateRegion(
            center: destination.coordinate, // 以目的地为中心
            span: countryRegion.span // 使用国家的视野范围
        )
        
        // 直接跳到目标位置，不使用动画
        mapCameraPosition = .region(region)
        
        print("🫧 地图移动到地点: \(destination.name) (\(countryName) - \(countryCode))")
    }
    
    // 根据国家名称获取国家代码
    private func getCountryCodeFromName(_ countryName: String) -> String {
        switch countryName.lowercased() {
        case "中国", "china", "cn":
            return "CN"
        case "美国", "united states", "usa", "us":
            return "US"
        case "日本", "japan", "jp":
            return "JP"
        case "韩国", "south korea", "korea", "kr":
            return "KR"
        case "新加坡", "singapore", "sg":
            return "SG"
        case "泰国", "thailand", "th":
            return "TH"
        case "马来西亚", "malaysia", "my":
            return "MY"
        case "印度尼西亚", "indonesia", "id":
            return "ID"
        case "菲律宾", "philippines", "ph":
            return "PH"
        case "越南", "vietnam", "vn":
            return "VN"
        case "印度", "india", "in":
            return "IN"
        case "澳大利亚", "australia", "au":
            return "AU"
        case "新西兰", "new zealand", "nz":
            return "NZ"
        case "加拿大", "canada", "ca":
            return "CA"
        case "墨西哥", "mexico", "mx":
            return "MX"
        case "英国", "united kingdom", "uk", "gb":
            return "GB"
        case "法国", "france", "fr":
            return "FR"
        case "德国", "germany", "de":
            return "DE"
        case "意大利", "italy", "it":
            return "IT"
        case "西班牙", "spain", "es":
            return "ES"
        case "荷兰", "netherlands", "nl":
            return "NL"
        case "瑞士", "switzerland", "ch":
            return "CH"
        case "奥地利", "austria", "at":
            return "AT"
        case "比利时", "belgium", "be":
            return "BE"
        case "丹麦", "denmark", "dk":
            return "DK"
        case "瑞典", "sweden", "se":
            return "SE"
        case "挪威", "norway", "no":
            return "NO"
        case "芬兰", "finland", "fi":
            return "FI"
        case "俄罗斯", "russia", "ru":
            return "RU"
        case "巴西", "brazil", "br":
            return "BR"
        case "阿根廷", "argentina", "ar":
            return "AR"
        case "智利", "chile", "cl":
            return "CL"
        case "哥伦比亚", "colombia", "co":
            return "CO"
        case "秘鲁", "peru", "pe":
            return "PE"
        case "冰岛", "iceland", "is":
            return "IS"
        default:
            // 如果找不到匹配的国家，使用默认的世界视野
            return "DEFAULT"
        }
    }
    
    // 将地图定位到当前位置
    private func centerMapOnCurrentLocation() {
        if let userLocation = locationManager.lastKnownLocation {
            // 如果有已知位置，定位到该位置
            let region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            
            withAnimation(.easeInOut(duration: 0.5)) {
                mapCameraPosition = .region(region)
            }
            print("📍 定位到当前位置")
        } else {
            // 如果没有位置信息，请求位置
            locationManager.requestLocation()
            
            // 使用自动定位
            withAnimation(.easeInOut(duration: 0.4)) {
                mapCameraPosition = .automatic
            }
            print("⚠️ 正在获取当前位置...")
        }
    }
    
    // 回忆泡泡覆盖层
    @ViewBuilder
    private var memoryBubbleOverlay: some View {
        if showMemoryBubble, let destination = selectedBubbleDestination {
            GeometryReader { geometry in
                // 计算地点在地图上的屏幕坐标
                let screenPoint = convertCoordinateToScreenPoint(destination.coordinate, in: geometry.size)
                
                // 回忆泡泡
                MemoryBubbleView(
                    destination: destination,
                    screenPosition: screenPoint,
                    animationOffset: bubbleAnimationOffset,
                    scale: bubbleScale
                ) {
                    // 点击泡泡的回调
                    handleBubbleTap(destination: destination)
                }
            }
            .allowsHitTesting(true)
        }
    }
    
    // 触发回忆泡泡
    private func triggerMemoryBubble() {
        // 检查是否有地点可以显示
        guard !destinations.isEmpty else {
            print("🫧 没有地点可以显示回忆泡泡")
            return
        }
        
        // 随机选择一个地点
        let randomDestination = destinations.randomElement()!
        selectedBubbleDestination = randomDestination
        
        // 播放音效
        playBubbleSound()
        
        // 移动地图到选中的地点，以国家视野范围定位到目的地为中心
        moveMapToDestination(randomDestination)
        
        // 地图直接跳到位置，预留0.3秒后显示泡泡
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // 开始动画
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showMemoryBubble = true
                bubbleScale = 1.0
            }
            
            // 泡泡上升动画
            withAnimation(.easeOut(duration: 2.0)) {
                bubbleAnimationOffset = -100
            }
        }
        
        // 3秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
            dismissMemoryBubble()
        }
        
        print("🫧 触发回忆泡泡: \(randomDestination.name)")
    }
    
    // 处理泡泡点击
    private func handleBubbleTap(destination: TravelDestination) {
        // 播放点击音效
        playTapSound()
        
        // 关闭泡泡
        dismissMemoryBubble()
        
        // 选中该地点并显示详情
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDestination = destination
            mapSelection = destination
        }
        
        // 将地图移动到该地点
        let region = MKCoordinateRegion(
            center: destination.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            mapCameraPosition = .region(region)
        }
        
        print("🫧 点击回忆泡泡: \(destination.name)")
    }
    
    // 关闭回忆泡泡
    private func dismissMemoryBubble() {
        withAnimation(.easeIn(duration: 0.3)) {
            showMemoryBubble = false
            bubbleScale = 0
            bubbleAnimationOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedBubbleDestination = nil
        }
    }
    
    // 将坐标转换为屏幕坐标
    private func convertCoordinateToScreenPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        // 这里需要根据当前地图的可见区域来计算屏幕坐标
        // 由于MapKit的复杂性，我们使用一个简化的方法
        // 在实际应用中，可能需要使用MapProxy来获取准确的屏幕坐标
        
        guard let region = visibleRegion else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        let span = region.span
        let center = region.center
        
        // 计算相对位置
        let latRatio = (coordinate.latitude - center.latitude + span.latitudeDelta / 2) / span.latitudeDelta
        let lonRatio = (coordinate.longitude - center.longitude + span.longitudeDelta / 2) / span.longitudeDelta
        
        // 转换为屏幕坐标
        let x = lonRatio * size.width
        let y = (1 - latRatio) * size.height // 翻转Y轴，因为屏幕坐标系Y轴向下
        
        return CGPoint(x: x, y: y)
    }
    
    // 播放泡泡音效
    private func playBubbleSound() {
        // 使用系统音效
        AudioServicesPlaySystemSound(1104) // 气泡音效
    }
    
    // 播放点击音效
    private func playTapSound() {
        // 使用系统音效
        AudioServicesPlaySystemSound(1105) // 点击音效
    }
    
    // MARK: - 搜索功能
    
    // 执行搜索
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            showSearchResults = false
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // 设置搜索区域为当前可见区域
        if let region = visibleRegion {
            request.region = region
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("❌ 搜索失败: \(error.localizedDescription)")
                    self.searchResults = []
                    self.showSearchResults = false
                    return
                }
                
                self.searchResults = response?.mapItems ?? []
                self.showSearchResults = !self.searchResults.isEmpty
                
                print("✅ 搜索完成，找到 \(self.searchResults.count) 个结果")
            }
        }
    }
    
    // 选择搜索结果
    private func selectSearchResult(_ mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        
        // 移动地图到搜索结果位置
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            mapCameraPosition = .region(region)
        }
        
        // 清除搜索
        searchText = ""
        searchResults = []
        showSearchResults = false
        isSearchFieldFocused = false
        
        print("📍 移动到搜索结果: \(mapItem.name ?? "未知地点")")
    }
}

// 搜索结果行组件
struct SearchResultRow: View {
    let mapItem: MKMapItem
    let onTap: () -> Void
    
    private var unknownLocationText: String {
        "unknown_location".localized
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mapItem.name ?? unknownLocationText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = mapItem.placemark.title {
                        Text(address)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "location.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 地图样式卡片组件
struct MapStyleCard: View {
    let style: MapStyle
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: style.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(style.displayName.localized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
        destinations.count == 1 ? destinations[0].name : "\(destinations.count) " + "locations_count".localized
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
        let zoom = zoomLevel
        // 国家和世界/大洲级别使用较小标记，其他级别保持32
        if zoom < 6 { return 20 }  // 世界/大洲级别和国家级别
        else { return 40 }          // 其他级别
    }
    
    private var strokeWidth: CGFloat {
        cluster.destinations.count == 1 ? 2 : 2.5
    }
    
    // 主颜色：统一使用国内/国外区分（不再因旅程使用渐变或统一蓝色）
    private var mainColor: Color {
        if cluster.destinations.count == 1 {
            let destination = cluster.destinations[0]
            return destination.normalizedCategory == "domestic" ? .red : .blue
        } else {
            // 聚合：使用国内/国外比例决定颜色
            let domesticCount = cluster.destinations.filter { $0.category == "domestic" }.count
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
                        lineWidth: 0
                    )
                    .frame(width: markerSize + 8, height: markerSize + 8)
                    .opacity(0.8)
            }
            
            // 单个地点
            if cluster.destinations.count == 1 {
                let destination = cluster.destinations[0]
                
                // 照片显示规则：仅当尺寸较大（>20）且有照片时展示图片；
                // 尺寸为20时，与无照片一致使用液态玻璃渐变
                let isDomestic = (destination.normalizedCategory == "domestic")
                if markerSize > 20,
                   let photoData = destination.photoData,
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
                    // 液态玻璃渐变标注（国内：粉→橙；国外：青→蓝）
                    LiquidGlassMarkerView(
                        size: markerSize,
                        startColor: isDomestic ? Color(.systemPink) : Color(.systemTeal),
                        endColor: isDomestic ? Color(.systemOrange) : Color(.systemBlue),
                        borderWidth: strokeWidth
                    )
                }
                
                // 内容图标（收藏心形）
                if hasFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .font(.system(size: markerSize * 0.5))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            } else {
                // 聚合地点：使用液态玻璃渐变（国内占比高=粉→橙；国外占比高=青→蓝；混合=紫→蓝紫）
                let domesticCount = cluster.destinations.filter { $0.category == "domestic" }.count
                let ratio = Double(domesticCount) / Double(cluster.destinations.count)
                let (startColor, endColor): (Color, Color) = {
                    if ratio > 0.7 {
                        return (Color(.systemPink), Color(.systemOrange))
                    } else if ratio < 0.3 {
                        return (Color(.systemTeal), Color(.systemBlue))
                    } else {
                        return (.purple, .indigo)
                    }
                }()
                ZStack {
                    LiquidGlassMarkerView(
                        size: markerSize,
                        startColor: startColor,
                        endColor: endColor,
                        borderWidth: strokeWidth
                    )
                    // 聚合数量文本
                    Text("\(cluster.destinations.count)")
                        .font(.system(size: markerSize * 0.45, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
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

// 计算多边形中点的辅助函数
extension MapView {
    // 计算路线多边形的中点坐标
    func midpointOfPolyline(_ polyline: MKPolyline) -> CLLocationCoordinate2D? {
        let pointCount = polyline.pointCount
        guard pointCount > 0 else { return nil }
        
        let midIndex = pointCount / 2
        let points = polyline.points()
        guard midIndex < pointCount else { return nil }
        let mapPoint = points[midIndex]
        return mapPoint.coordinate
    }
    
    // 计算两点连线的中点
    func midpointOfLine(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        return CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
    }
    
    // 检查两个地点是否在同一个聚合中
    func areDestinationsInSameCluster(_ destination1: TravelDestination, _ destination2: TravelDestination) -> Bool {
        // 遍历所有聚合，检查两个地点是否在同一个聚合中
        for cluster in clusterAnnotations {
            let destinationIds = Set(cluster.destinations.map { $0.id })
            if destinationIds.contains(destination1.id) && destinationIds.contains(destination2.id) {
                return true
            }
        }
        return false
    }
}

// 路线距离标签视图
struct RouteDistanceLabel: View {
    let distance: CLLocationDistance
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Text(formatDistance(distance))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
}

// CLLocationCoordinate2D 扩展：Equatable 支持
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct DestinationPreviewCard: View {
    let destination: TravelDestination
    let onDelete: () -> Void
    let onOpenDetail: () -> Void
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @Environment(\.modelContext) private var modelContext
    
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
                    Text(destination.visitDate.localizedFormatted(dateStyle: .medium))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(destination.visitDate.localizedFormatted(dateStyle: .none, timeStyle: .short))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 显示笔记
                if !destination.notes.isEmpty {
                    Text(destination.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
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
            
            // 按钮组
            HStack(spacing: 8) {
                // 编辑按钮
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(10)
                        .background(
                            Circle().fill(Color.white.opacity(0.5))
                        )
                }
                
                // 删除按钮
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(10)
                        .background(
                            Circle().fill(Color.white.opacity(0.5))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(radius: 10)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            onOpenDetail()
        }
        .sheet(isPresented: $showEditSheet) {
            EditDestinationView(destination: destination)
        }
        .confirmationDialog("delete_destination".localized, isPresented: $showDeleteConfirmation) {
            Button("delete".localized, role: .destructive) {
                deleteDestination()
            }
            Button("cancel".localized, role: .cancel) { }
        } message: {
            Text("confirm_delete_destination".localized(with: destination.name))
        }
    }
    
    // 删除地点的方法
    private func deleteDestination() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.delete(destination)
            try? modelContext.save()
            onDelete() // 调用回调函数关闭弹窗
        }
    }
}

#Preview {
    MapView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(CountryManager.shared)
}

// 位置管理器
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // 检查当前授权状态
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocation() {
        // 如果尚未请求权限，先请求权限
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // 请求一次性位置更新
        locationManager.requestLocation()
    }
    
    // CLLocationManagerDelegate 方法
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let wgsCoord = location.coordinate
            // 将WGS84坐标转换为GCJ02（火星坐标）以适应中国地图显示
            let gcjCoord = CoordinateConverter.wgs84ToGCJ02(wgsCoord)
            lastKnownLocation = gcjCoord
            
            print("📍 获取到用户位置: WGS84(\(wgsCoord.latitude), \(wgsCoord.longitude)) -> GCJ02(\(gcjCoord.latitude), \(gcjCoord.longitude))")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 获取位置失败: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 位置授权状态变更: \(authorizationStatus.rawValue)")
        
        // 如果已授权，立即请求位置
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}


// 回忆泡泡视图
struct MemoryBubbleView: View {
    let destination: TravelDestination
    let screenPosition: CGPoint
    let animationOffset: CGFloat
    let scale: CGFloat
    let onTap: () -> Void
    
    @State private var bubbleOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -100
    
    var body: some View {
        ZStack {
            // 泡泡主体
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.pink.opacity(0.6),
                            Color.blue.opacity(0.4)
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 50
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    // 泡泡高光效果
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .offset(x: -15, y: -15)
                )
                .overlay(
                    // 泡泡边框
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.8),
                                    .purple.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // 地点名称
            Text(destination.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            
            // 闪烁效果
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 100, height: 100)
                .offset(x: shimmerOffset)
                .opacity(bubbleOpacity)
        }
        .position(x: screenPosition.x, y: screenPosition.y + animationOffset)
        .scaleEffect(scale)
        .opacity(bubbleOpacity)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            // 出现动画
            withAnimation(.easeOut(duration: 0.5)) {
                bubbleOpacity = 1.0
            }
            
            // 闪烁动画
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 100
            }
        }
        .onDisappear {
            bubbleOpacity = 0
            shimmerOffset = -100
        }
    }
}

// MARK: - Custom Bubble Icon
struct CustomBubbleIcon: View {
    let iconColor: Color
    
    var body: some View {
        ZStack {
            // 最大的圆形（上方）
            Circle()
                .fill(.white.opacity(0.3))
                .stroke(iconColor.opacity(0.8), lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .offset(x: -4, y: -3)
            
            // 中等圆形（中间）
            Circle()
                .fill(.white.opacity(0.5))
                .stroke(iconColor.opacity(0.8), lineWidth: 1.2)
                .frame(width: 12, height: 12)
                .offset(x: 6, y: 1) // 向右平移更多
            
            // 最小的圆形（下方）
            Circle()
                .fill(.white.opacity(0.7))
                .stroke(iconColor.opacity(0.8), lineWidth: 1.0)
                .frame(width: 8, height: 8)
                .offset(x: 2, y: 9) // 往下移动更多
        }
        .frame(width: 28, height: 28)
    }
}

// 用户位置标记视图
struct UserLocationAnnotationView: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // 外圈脉冲动画
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
            
            // 中间圈
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
            
            // 内圈
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onAppear {
            // 脉冲动画
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                pulseScale = 1.5
                pulseOpacity = 0.0
            }
        }
    }
}

// 滚动偏移信息
struct ScrollOffsetInfo: Equatable {
    let tripId: UUID
    let offset: CGFloat
}

// PreferenceKey 用于传递滚动偏移信息
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [ScrollOffsetInfo] = []
    
    static func reduce(value: inout [ScrollOffsetInfo], nextValue: () -> [ScrollOffsetInfo]) {
        value.append(contentsOf: nextValue())
    }
}

// 线路卡片组件
struct RouteCard: View {
    let trip: TravelTrip
    let destinations: [TravelDestination]
    let onTap: (() -> Void)?
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var routes: [MKRoute] = []
    @State private var isLoadingRoutes = false
    @State private var totalDistance: CLLocationDistance = 0
    @State private var lastDestinationsHash: Int = 0 // 用于检测 destinations 变化
    
    init(trip: TravelTrip, destinations: [TravelDestination], onTap: (() -> Void)? = nil) {
        self.trip = trip
        self.destinations = destinations
        self.onTap = onTap
    }
    
    // 生成 destinations 的哈希值，用于检测变化
    // 包括地点ID、坐标和访问日期，确保能检测到所有相关变化
    private var destinationsHash: Int {
        let hashString = destinations
            .sorted(by: { $0.visitDate < $1.visitDate })
            .map { "\($0.id.uuidString)|\($0.coordinate.latitude)|\($0.coordinate.longitude)|\($0.visitDate.timeIntervalSince1970)" }
            .joined(separator: ",")
        return hashString.hashValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 旅程名称和日期
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDateRange(trip.startDate, trip.endDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 线路信息
            HStack(spacing: 16) {
                // 地点数量
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(destinations.count)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("地点")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 总距离
                if totalDistance > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "road.lanes")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(formatDistance(totalDistance))
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Text("总距离")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if isLoadingRoutes {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("计算中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 起点和终点
            if let start = destinations.first, let end = destinations.last {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text(start.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        Text("起点")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text(end.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        Text("终点")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            // 首次出现时计算路线
            calculateRoutes()
        }
        .onChange(of: destinations.count) { oldValue, newValue in
            // 当地点数量变化时，重新计算
            calculateRoutes()
        }
        .onChange(of: destinationsHash) { oldValue, newValue in
            // 当地点列表发生变化时（新增、删除、顺序变化），重新计算
            if oldValue != 0 && oldValue != newValue {
                calculateRoutes()
            }
        }
    }
    
    // 计算路线（优化版：并发计算 + 缓存检查 + 实时更新）
    private func calculateRoutes() {
        guard destinations.count >= 2 else {
            routes = []
            totalDistance = 0
            lastDestinationsHash = destinationsHash
            return
        }
        
        // 检查是否所有路线都已缓存（用于快速更新）
        // 注意：destinations 在传入时已经按 visitDate 排序（见 MapView 第577行）
        let coordinates = destinations.map { $0.coordinate }
        var allCached = true
        var cachedRoutes: [MKRoute] = []
        
        for i in 0..<coordinates.count - 1 {
            if let cachedRoute = routeManager.getCachedRoute(
                from: coordinates[i],
                to: coordinates[i + 1]
            ) {
                cachedRoutes.append(cachedRoute)
            } else {
                allCached = false
                break
            }
        }
        
        // 如果所有路线都已缓存，直接使用缓存（快速更新）
        if allCached && cachedRoutes.count == coordinates.count - 1 {
            routes = cachedRoutes
            totalDistance = cachedRoutes.reduce(0) { $0 + $1.distance }
            lastDestinationsHash = destinationsHash
            return
        }
        
        // 如果有未缓存的路线，需要重新计算
        isLoadingRoutes = true
        
        Task {
            // 使用 RouteManager 的并发批量计算（与 TripRouteMapView 使用相同的方法）
            let calculatedRoutes = await routeManager.calculateRoutes(for: coordinates)
            
            await MainActor.run {
                routes = calculatedRoutes
                
                // 计算总距离：如果路线计算成功，使用路线距离；否则使用直线距离
                if calculatedRoutes.count == coordinates.count - 1 {
                    // 所有路线都计算成功，使用路线距离
                    totalDistance = calculatedRoutes.reduce(0) { $0 + $1.distance }
                } else {
                    // 部分或全部路线计算失败，使用直线距离作为备用
                    var straightLineDistance: CLLocationDistance = 0
                    for i in 0..<coordinates.count - 1 {
                        straightLineDistance += coordinates[i].distance(to: coordinates[i + 1])
                    }
                    totalDistance = straightLineDistance
                }
                
                isLoadingRoutes = false
                lastDestinationsHash = destinationsHash
            }
        }
    }
    
    // 格式化日期范围
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) - \(endString)"
    }
    
    // 格式化距离
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
}

// 路线预览卡片组件
struct RoutePreviewCard: View {
    let trip: TravelTrip
    let destinations: [TravelDestination]
    let onOpenDetail: () -> Void
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var routes: [MKRoute] = []
    @State private var isLoadingRoutes = false
    @State private var totalDistance: CLLocationDistance = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 旅程名称和日期
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDateRange(trip.startDate, trip.endDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 描述
            if !trip.desc.isEmpty {
                Text(trip.desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 线路信息
            HStack(spacing: 16) {
                // 地点数量
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(destinations.count)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Text("地点")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 总距离
                if totalDistance > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "road.lanes")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(formatDistance(totalDistance))
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Text("总距离")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if isLoadingRoutes {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("计算中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 起点和终点
            if let start = destinations.first, let end = destinations.last {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text(start.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        Text("起点")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text(end.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        Text("终点")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // 查看详情按钮
            Button {
                onOpenDetail()
            } label: {
                HStack {
                    Text("view_details".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            onOpenDetail()
        }
        .onAppear {
            calculateRoutes()
        }
    }
    
    // 计算路线
    private func calculateRoutes() {
        guard destinations.count >= 2 else {
            routes = []
            totalDistance = 0
            return
        }
        
        isLoadingRoutes = true
        let coordinates = destinations.map { $0.coordinate }
        
        Task {
            let calculatedRoutes = await routeManager.calculateRoutes(for: coordinates)
            
            await MainActor.run {
                routes = calculatedRoutes
                
                // 计算总距离：如果路线计算成功，使用路线距离；否则使用直线距离
                if calculatedRoutes.count == coordinates.count - 1 {
                    // 所有路线都计算成功，使用路线距离
                    totalDistance = calculatedRoutes.reduce(0) { $0 + $1.distance }
                } else {
                    // 部分或全部路线计算失败，使用直线距离作为备用
                    var straightLineDistance: CLLocationDistance = 0
                    for i in 0..<coordinates.count - 1 {
                        straightLineDistance += coordinates[i].distance(to: coordinates[i + 1])
                    }
                    totalDistance = straightLineDistance
                }
                
                isLoadingRoutes = false
            }
        }
    }
    
    // 格式化日期范围
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) - \(endString)"
    }
    
    // 格式化距离
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
}
