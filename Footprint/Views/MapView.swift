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
    case standard = "standard"
    case hybrid = "hybrid"
    case imagery = "imagery"
    
    var displayName: String {
        switch self {
        case .standard:
            return "map_style_standard"
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
        case .hybrid:
            return .hybrid(elevation: .realistic)  // 混合地图：卫星图像+标注
        case .imagery:
            return .imagery(elevation: .realistic) // 卫星图像：纯卫星图像，无标注
        }
    }
}

struct MapView: View {
    @Query private var destinations: [TravelDestination]
    @Query private var trips: [TravelTrip]
    @Environment(\.colorScheme) private var colorScheme // 检测颜色模式
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var countryManager = CountryManager.shared
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedDestination: TravelDestination?
    @State private var showingAddDestination = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showTripConnections = true // 是否显示旅程连线
    @State private var updateTimer: Timer? // 用于防抖
    @State private var pendingRegion: MKCoordinateRegion? // 待处理的区域更新
    @State private var mapSelection: TravelDestination? // 地图的选择状态
    @StateObject private var locationManager = LocationManager()
    
    // 性能优化：缓存聚合结果
    @State private var cachedClusterAnnotations: [ClusterAnnotation] = []
    @State private var cachedZoomLevelEnum: ZoomLevel = .world
    @State private var cachedDestinationsCount: Int = 0
    @State private var lastCalculationTime: Date = Date()
    
    // 地图样式相关状态
    @State private var currentMapStyle: MapStyle = .standard
    @State private var showingMapStylePicker = false
    
    // 长按添加目的地相关状态
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var isGeocodingLocation = false
    @State private var prefilledLocationData: (location: MKMapItem, name: String, country: String, category: String)?
    
    // 打卡功能相关状态
    @State private var isCheckingIn = false
    @State private var checkInLocation: CLLocationCoordinate2D?
    
    // 缓存用户国家信息
    @State private var userCountryRegion: MKCoordinateRegion?
    @State private var refreshID = UUID()
    
    // 回忆泡泡相关状态
    @State private var showMemoryBubble = false
    @State private var selectedBubbleDestination: TravelDestination?
    @State private var bubbleAnimationOffset: CGFloat = 0
    @State private var bubbleScale: CGFloat = 0
    
    // 右上角图标折叠/展开状态
    @State private var isTopRightIconsCollapsed = true
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var showSearchResults = false
    
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
        case .standard:
            return .blue
        case .hybrid, .imagery:
            return .white
        }
    }
    
    var body: some View {
        ZStack {
            mapLayer
            dismissOverlay
            previewCard
            memoryBubbleOverlay
            floatingButtons
            collapseOverlay
        }
        .sheet(isPresented: $showingAddDestination, onDismiss: {
            prefilledLocationData = nil
        }) {
            destinationSheet
        }
        .sheet(isPresented: $showingMapStylePicker) {
            mapStylePicker
        }
        .onAppear {
            preloadUserLocation()
        }
        .onDisappear {
            updateTimer?.invalidate()
            updateTimer = nil
        }
        .onChange(of: locationManager.lastKnownLocation?.latitude) { _, _ in
            if let location = locationManager.lastKnownLocation, userCountryRegion == nil {
                precalculateUserCountryRegion(location: location)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // 语言变化时刷新界面
            refreshID = UUID()
        }
        .onChange(of: destinations.count) { _, _ in
            // 地点数量变化时清除缓存
            clearClusterCache()
        }
        .onChange(of: currentZoomLevelEnum) { oldValue, newValue in
            // 缩放级别变化时清除缓存，触发重新计算
            if oldValue != newValue {
                print("📏 缩放级别变化: \(oldValue.description) → \(newValue.description)")
                clearClusterCache()
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
        if showTripConnections {
            ForEach(trips) { trip in
                if let destinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                   destinations.count > 1 {
                    MapPolyline(coordinates: destinations.map { $0.coordinate })
                        .stroke(tripConnectionColor, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [1, 2]))
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
    
    // 折叠覆盖层 - 点击外部区域自动折叠图标
    @ViewBuilder
    private var collapseOverlay: some View {
        if !isTopRightIconsCollapsed {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isTopRightIconsCollapsed = true
                    }
                }
                .zIndex(2) // 确保在其他内容之上，但在浮动按钮之下
        }
    }
    
    // 预览卡片
    private var previewCard: some View {
        VStack {
            Spacer()
            if let selected = selectedDestination {
                DestinationPreviewCard(destination: selected) {
                    // 删除回调：关闭弹窗
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedDestination = nil
                        mapSelection = nil
                    }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(2)
    }
    
    // 浮动按钮
    private var floatingButtons: some View {
        ZStack {
            // 左上角：折叠/展开按钮和功能按钮组
            VStack {
                HStack {
                    VStack(spacing: 12) {
                        // 折叠/展开按钮
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isTopRightIconsCollapsed.toggle()
                            }
                        } label: {
                            Image(systemName: isTopRightIconsCollapsed ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(iconColor)
                        }
                        .buttonStyle(MapFloatingButtonStyle(mapStyle: currentMapStyle))
                        
                        // 功能按钮组（可折叠）
                        if !isTopRightIconsCollapsed {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showTripConnections.toggle()
                                }
                            } label: {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.system(size: 24))
                                    .foregroundColor(showTripConnections ? iconColor : .gray)
                            }
                            .buttonStyle(MapFloatingButtonStyle(mapStyle: currentMapStyle))
                            .transition(.scale.combined(with: .opacity))
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showingMapStylePicker.toggle()
                                }
                            } label: {
                                Image(systemName: currentMapStyle.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(iconColor)
                            }
                            .buttonStyle(MapFloatingButtonStyle(mapStyle: currentMapStyle))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.leading)
                    .padding(.top)
                    
                    Spacer()
                }
                Spacer()
            }
            
            // 顶部中央：搜索框
            VStack {
                HStack {
                    Spacer()
                    
                    searchBox
                        .padding(.horizontal, 60) // 增加左右边距，避免与按钮重叠
                    
                    Spacer()
                }
                .padding(.top, 15) // 调整顶部边距，使搜索框中心线与按钮中心线对齐
                
                Spacer()
            }
            
            // 右上角：拖动打卡按钮
            VStack {
                HStack {
                    Spacer()
                    
                    DragCheckInButton(
                        isCheckingIn: $isCheckingIn,
                        onCheckIn: {
                            handleCheckIn()
                        },
                        normalImageName: "ImageDaka",
                        successImageName: "ImageDaka",
                        mapStyle: currentMapStyle
                    )
                    .padding(.trailing)
                    .padding(.top)
                }
                Spacer()
            }
            
            // 右下角：回忆泡泡按钮和定位到国家按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // 回忆泡泡按钮
                        Button {
                            triggerMemoryBubble()
                        } label: {
                            CustomBubbleIcon(iconColor: iconColor)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(MapFloatingButtonStyle(mapStyle: currentMapStyle))
                        
                        // 定位到国家按钮
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                centerMapOnSelectedCountry()
                                selectedDestination = nil
                                mapSelection = nil
                            }
                        } label: {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 24))
                                .foregroundColor(iconColor)
                        }
                        .buttonStyle(MapFloatingButtonStyle(mapStyle: currentMapStyle))
                    }
                    .padding(.trailing)
                    .padding(.bottom, selectedDestination != nil ? 140 : 20) // 当预览卡片出现时，增加底部边距
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedDestination != nil)
                }
            }
        }
        .zIndex(4) // 确保浮动按钮在折叠覆盖层之上
    }
    
    // 搜索框
    private var searchBox: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15, weight: .medium))
                
                TextField(searchPlaceholderText, text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { _, newValue in
                        if newValue.isEmpty {
                            searchResults = []
                            showSearchResults = false
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        showSearchResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                    }
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
            if showSearchResults && !searchResults.isEmpty {
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
            VStack(spacing: 20) {
                Text("map_style_title".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
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
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        showingMapStylePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
    
    // 计算聚合后的标注点（按级别触发计算）
    private var clusterAnnotations: [ClusterAnnotation] {
        let currentZoomEnum = currentZoomLevelEnum
        let currentCount = destinations.count
        
        // 检查缓存是否有效：只在缩放级别真正改变时才重新计算
        if !cachedClusterAnnotations.isEmpty &&
           cachedZoomLevelEnum == currentZoomEnum &&
           cachedDestinationsCount == currentCount {
            return cachedClusterAnnotations
        }
        
        // 性能监控：记录计算开始时间
        let startTime = Date()
        
        let distance = clusterDistance
        var clusters: [ClusterAnnotation] = []
        
        // 如果聚合距离为0，返回所有单独的点
        if distance == 0 {
            clusters = destinations.map { ClusterAnnotation(destinations: [$0]) }
        } else {
            // 优化的聚合算法：减少重复计算
            clusters = calculateClustersOptimized(distance: distance)
        }
        
        // 更新缓存
        cachedClusterAnnotations = clusters
        cachedZoomLevelEnum = currentZoomEnum
        cachedDestinationsCount = currentCount
        lastCalculationTime = Date()
        
        // 性能监控：记录计算耗时和级别变化
        let calculationTime = Date().timeIntervalSince(startTime)
        print("🔄 聚合计算完成: \(currentZoomEnum.description)级别, 耗时: \(String(format: "%.3f", calculationTime))秒, 地点: \(currentCount)个")
        
        return clusters
    }
    
    // 优化的聚合计算算法
    private func calculateClustersOptimized(distance: Double) -> [ClusterAnnotation] {
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
        lastCalculationTime = Date()
        print("🧹 已清除聚合缓存")
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
    
    // 预加载用户位置
    private func preloadUserLocation() {
        locationManager.requestLocation()
    }
    
    // 预先计算用户国家区域（异步，不阻塞UI）
    private func precalculateUserCountryRegion(location: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            if let placemark = placemarks?.first {
                let countryCode = placemark.isoCountryCode ?? ""
                
                DispatchQueue.main.async {
                    self.userCountryRegion = self.getRegionForCountry(countryCode: countryCode, userLocation: location)
                    print("📍 " + "preloaded_country_region".localized(with: placemark.country ?? "unknown_country".localized, countryCode))
                }
            }
        }
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
    
    // 将地图定位到用户所在国家（即时响应，使用缓存）
    private func centerMapOnUserCountry() {
        // 如果已有缓存的区域，立即使用
        if let region = userCountryRegion {
            // 使用更快的 easeInOut 动画，持续时间0.5秒
            withAnimation(.easeInOut(duration: 0.5)) {
                mapCameraPosition = .region(region)
            }
            print("📍 " + "using_cached_country_region".localized)
            return
        }
        
        // 如果有位置但没有缓存区域，立即计算并显示
        if let userLocation = locationManager.lastKnownLocation {
            // 先立即显示用户位置周边
            let tempRegion = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            )
            
            withAnimation(.easeInOut(duration: 0.4)) {
                mapCameraPosition = .region(tempRegion)
            }
            
            // 然后异步获取国家信息并调整
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            
            geocoder.reverseGeocodeLocation(location) { [self] placemarks, error in
                if let placemark = placemarks?.first {
                    let countryCode = placemark.isoCountryCode ?? ""
                    let region = self.getRegionForCountry(countryCode: countryCode, userLocation: userLocation)
                    
                    DispatchQueue.main.async {
                        self.userCountryRegion = region
                        withAnimation(.easeInOut(duration: 0.6)) {
                            self.mapCameraPosition = .region(region)
                        }
                        print("📍 " + "map_positioned_to".localized(with: placemark.country ?? "unknown_country".localized, countryCode))
                    }
                }
            }
        } else {
            // 没有位置信息，请求位置
            locationManager.requestLocation()
            
            // 使用自动定位作为临时方案
            withAnimation(.easeInOut(duration: 0.4)) {
                mapCameraPosition = .automatic
            }
            print("⚠️ " + "getting_user_location".localized)
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
    
    // MARK: - 打卡功能
    
    // 处理打卡功能
    private func handleCheckIn() {
        print("📍 开始打卡流程...")
        isCheckingIn = true
        
        // 检查位置权限
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            print("❌ 位置权限未授权")
            requestLocationPermission()
            isCheckingIn = false
            return
        }
        
        // 获取当前位置
        if let currentLocation = locationManager.lastKnownLocation {
            print("✅ 使用缓存位置: (\(currentLocation.latitude), \(currentLocation.longitude))")
            performCheckIn(at: currentLocation)
        } else {
            print("🔄 请求当前位置...")
            locationManager.requestLocation()
            
            // 监听位置更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let location = self.locationManager.lastKnownLocation {
                    self.performCheckIn(at: location)
                } else {
                    print("❌ 无法获取当前位置")
                    self.isCheckingIn = false
                    // 可以显示错误提示
                }
            }
        }
    }
    
    // 请求位置权限
    private func requestLocationPermission() {
        locationManager.requestLocation()
    }
    
    // 执行打卡
    private func performCheckIn(at coordinate: CLLocationCoordinate2D) {
        print("📍 执行打卡: (\(coordinate.latitude), \(coordinate.longitude))")
        checkInLocation = coordinate
        
        // 立即显示添加目的地界面，显示加载状态
        showingAddDestination = true
        
        // 执行反向地理编码获取城市信息
        reverseGeocodeForCheckIn(coordinate: coordinate)
    }
    
    // 为打卡进行反向地理编码
    private func reverseGeocodeForCheckIn(coordinate: CLLocationCoordinate2D) {
        isGeocodingLocation = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        func succeed(with placemark: CLPlacemark) {
            isGeocodingLocation = false
            isCheckingIn = false
            
            let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
            let countryName = placemark.country ?? "unknown_country".localized
            let isoCountryCode = placemark.isoCountryCode ?? ""
            let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
            
            print("✅ 打卡反向地理编码成功:")
            print("   城市: \(cityName)")
            print("   国家: \(countryName)")
            print("   ISO代码: \(isoCountryCode)")
            print("   分类: \(category)")
            
            let mkPlacemark = MKPlacemark(placemark: placemark)
            let mapItem = MKMapItem(placemark: mkPlacemark)
            mapItem.name = cityName
            
            prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
            
            // 播放打卡成功音效
            AudioServicesPlaySystemSound(1104) // 气泡音效
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
                    DispatchQueue.main.async { fallbackSearchForCheckIn(coordinate: coordinate) }
                }
            }
        }

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async { succeed(with: placemark) }
                return
            }
            print("❌ 打卡反向地理编码失败: \(error?.localizedDescription ?? "未知错误")")
            failoverToAlternateLocales()
        }
    }
    
    // 打卡备用方案1：在坐标附近做一次本地搜索
    private func fallbackSearchForCheckIn(coordinate: CLLocationCoordinate2D) {
        let request = MKLocalSearch.Request()
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
                print("✅ 打卡附近搜索成功: \(cityName), \(countryName)")
                let mapItem = item
                mapItem.name = cityName
                DispatchQueue.main.async {
                    self.isGeocodingLocation = false
                    self.isCheckingIn = false
                    self.prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
                    AudioServicesPlaySystemSound(1104) // 气泡音效
                }
            } else {
                print("⚠️ 打卡附近搜索失败: \(error?.localizedDescription ?? "无结果")")
                DispatchQueue.main.async { self.fallbackCheckInWithCoordinateOnly(coordinate: coordinate) }
            }
        }
    }
    
    // 打卡备用方案2：仅根据坐标进行国内/国外判断并提供占位名称
    private func fallbackCheckInWithCoordinateOnly(coordinate: CLLocationCoordinate2D) {
        isGeocodingLocation = false
        isCheckingIn = false
        let category = isInChinaBoundingBox(coordinate) ? "domestic" : "international"
        let countryName = category == "domestic" ? "中国" : "unknown_country".localized
        let cityName = "selected_location".localized
        print("🛟 打卡坐标回退: \(cityName), \(countryName), \(category)")
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = cityName
        prefilledLocationData = (location: mapItem, name: cityName, country: countryName, category: category)
        AudioServicesPlaySystemSound(1104) // 气泡音效
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
            VStack(spacing: 12) {
                Image(systemName: style.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(style.displayName.localized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
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
        else { return 32 }          // 其他级别
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
            return destination.normalizedCategory == "domestic" ? .red : .blue
        } else {
            // 聚合标记：检查是否有共同旅程
            let tripIds = cluster.destinations.compactMap { $0.trip?.id }
            if mostFrequent(in: tripIds) != nil {
                return .blue // 有旅程的聚合使用蓝色
            }
            
            // 没有共同旅程，使用国内/国外混合颜色
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

// CLLocationCoordinate2D 扩展：Equatable 支持
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct DestinationPreviewCard: View {
    let destination: TravelDestination
    let onDelete: () -> Void
    @State private var showDetail = false
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
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                
                // 删除按钮
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            DestinationDetailView(destination: destination)
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
            lastKnownLocation = location.coordinate
            print("📍 " + "user_location_obtained".localized(with: location.coordinate.latitude, location.coordinate.longitude))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ " + "location_permission_denied".localized(with: error.localizedDescription))
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 " + "location_authorization_changed".localized(with: authorizationStatus.rawValue))
        
        // 如果已授权，立即请求位置
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}

// 地图浮动按钮样式 - 玻璃质感效果
struct MapFloatingButtonStyle: ButtonStyle {
    let mapStyle: MapStyle
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .background(
                GlassButtonBackground(mapStyle: mapStyle)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct GlassButtonBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let mapStyle: MapStyle
    
    // 判断是否是深色地图样式
    private var isDarkMapStyle: Bool {
        switch mapStyle {
        case .standard:
            return false
        case .hybrid, .imagery:
            return true
        }
    }
    
    var body: some View {
        ZStack {
            // 主背景 - 根据地图样式调整不透明度和模糊效果
            if isDarkMapStyle {
                // 混合/卫星地图：半透明深色背景（平板磨砂玻璃效果）
                ZStack {
                    // 底层深色背景
                    Circle()
                        .fill(Color.black.opacity(0.65))
                    
                    // 顶层磨砂材质（平板玻璃质感）
                    Circle()
                        .fill(.thinMaterial.opacity(0.8))
                }
            } else {
                // 标准地图：使用白色背景
                Circle()
                    .fill(Color.white.opacity(0.9))
            }
            
            // 顶部的光泽效果
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(isDarkMapStyle ? 0.15 : 0.5),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
            
            // 底部的阴影效果
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(isDarkMapStyle ? 0.25 : 0.05)
                        ],
                        startPoint: .center,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 边框 - 根据地图样式调整
            Circle()
                .stroke(
                    isDarkMapStyle 
                    ? Color.white.opacity(0.25)
                    : Color.black.opacity(0.1),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
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

