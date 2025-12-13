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
import UIKit
import PhotosUI
import Photos
import ImageIO

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

// 任务持有者类：用于在SwiftUI View中存储DispatchWorkItem
private class POILoadingTaskHolder {
    var task: DispatchWorkItem?
}

struct MapView: View {
    @Query private var destinations: [TravelDestination]
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Environment(\.colorScheme) private var colorScheme // 检测颜色模式
    @Environment(\.isAppReady) private var isAppReady // 应用是否已就绪（启动画面是否结束）
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var countryManager = CountryManager.shared
    
    // MARK: - Route Color Helper
    /// 根据交通方式返回路线颜色
    /// - Parameter transportType: 交通方式
    /// - Returns: 路线颜色（徒步：绿色，机动车：蓝色，飞机：橙色，其他：灰色）
    private func routeColor(for transportType: MKDirectionsTransportType) -> Color {
        if transportType == RouteManager.airplane {
            // 飞机模式：使用橙色
            return .orange
        } else if transportType.contains(.walking) && transportType == .walking {
            // 徒步模式：使用绿色，更符合自然、步行的感觉
            return .green
        } else if transportType.contains(.automobile) && transportType == .automobile {
            // 机动车模式：使用蓝色（保持原有颜色）
            return .blue
        } else if transportType.contains(.transit) && transportType == .transit {
            // 公共交通：使用紫色
            return .purple
        } else {
            // 其他或混合模式：使用灰色
            return .gray
        }
    }
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedDestination: TravelDestination?
    @State private var showingAddDestination = false        // 普通“添加目的地”弹窗
    @State private var showingQuickCheckIn = false          // “快速打卡”弹窗
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showTripConnections = false // 是否显示旅程连线
    @State private var updateTimer: Timer? // 用于防抖
    @State private var pendingRegion: MKCoordinateRegion? // 待处理的区域更新
    @State private var periodicCheckTimer: Timer? // 用于定期检查地点变化
    @State private var mapSelection: TravelDestination? // 地图的选择状态
    @ObservedObject private var locationManager = LocationManager.shared
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var destinationWeatherManager = DestinationWeatherManager()
    // 详情弹窗（由父级统一展示，避免子视图被移除导致弹窗不出现）
    @State private var detailDestinationForSheet: TravelDestination?
    
    // 反向地理编码优化：使用共享的 geocoder 实例，避免重复创建
    @State private var geocoder: CLGeocoder?
    @State private var pendingGeocodeCoordinate: CLLocationCoordinate2D?
    @State private var geocodeTimeoutTimer: Timer?
    @State private var lastGeocodeTime: Date?
    @State private var isThrottled = false // 是否处于节流状态
    @State private var throttleResetTime: Date? // 节流重置时间
    @State private var viewAppearTime: Date? // 视图出现时间，用于启动阶段的节流控制
    @State private var hasDoneInitialGeocode = false // 启动阶段是否已完成一次反向地理编码
    @State private var startupGeocodeScheduled = false // 启动阶段是否已安排一次延迟地理编码
    @State private var locationInitializationPending = false // 定位初始化是否待执行（等待启动画面结束）
    @State private var initialCameraPositionSet = false // 初始相机位置是否已设置
    @State private var waitingForLocationToSetCamera = false // 是否正在等待位置来设置相机
    
    // 底部浮动按钮参数
    private let tabBarHeight: CGFloat = 49
    private let bottomButtonSpacing: CGFloat = 6
    private let cachedPlacemarkReuseDistance: CLLocationDistance = 120
    private let cachedPlacemarkTTL: TimeInterval = 300
    private let accuracyImprovementTrigger: Double = 15
    
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
    @State private var addDestinationPrefill: AddDestinationPrefill?
    @State private var isWaitingForLocation = false // 等待定位状态（用于打卡功能）
    @State private var pendingPhotoPrefill: PendingPhotoPrefill?
    @State private var lastReverseGeocodePlacemark: CLPlacemark?
    @State private var lastReverseGeocodeCoordinate: CLLocationCoordinate2D?
    @State private var lastReverseGeocodeTimestamp: Date?
    @State private var lastGeocodedAccuracy: Double = .greatestFiniteMagnitude
    @State private var showingPhotoImportPicker = false
    @State private var photoImportItem: PhotosPickerItem?
    @State private var photoImportError: PhotoImportError?
    
    // POI点击相关状态
    @State private var selectedPOI: MKMapItem?
    @State private var showingPOIPreview = false
    @State private var isSearchingPOI = false
    @State private var poiSearchStartTime: Date?
    private let loadingTaskHolder = POILoadingTaskHolder() // 使用类来存储任务引用，避免结构体的不可变问题
    private let showLoadingThreshold: TimeInterval = 0.3 // 超过300ms才显示加载卡片
    
    @State private var refreshID = UUID()
    
    // 用于检测地点变化的状态（坐标、删除等）
    @State private var lastDestinationsSignature: String = ""
    
    // 回忆泡泡相关状态
    @State private var selectedBubbleDestination: TravelDestination? // 用于获取地点位置
    @State private var showSoapBubbles = false
    @State private var soapBubblesID = UUID() // 用于强制创建新的肥皂泡泡视图实例
    @State private var waitingForMapToReachDestination = false // 是否正在等待地图到达地点
    @State private var targetBubbleDestination: TravelDestination? // 目标地点（用于检查是否到达）
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var showSearchBar = false // 控制搜索栏显示
    @FocusState private var isSearchFocused: Bool
    
    // 线路卡片相关状态
    @State private var showRouteCards = false
    @State private var selectedTripId: UUID? // 当前选中的旅程ID（用于显示连线和地图跟随）
    @State private var cardSwitchTask: DispatchWorkItem? // 用于取消之前的切换任务
    @State private var isScrolling = false // 是否正在滚动
    @State private var snapTask: DispatchWorkItem? // 磁吸任务
    @State private var shouldHideRouteCards = false // 是否应该隐藏路线卡片（用于弹窗交互）
    @State private var showingTripDetail = false // 是否显示路线详情sheet
    @State private var detailTripForSheet: TravelTrip? // 用于sheet的路线详情
    @State private var showingFootprintsDrawer = false // 是否显示“我的足迹”抽屉
    @State private var assistiveMenuExpanded = false
    @State private var assistiveMenuPosition: CGPoint = .zero
    var autoShowRouteCards: Bool = false // 是否自动显示线路卡片
    var showBottomCheckInButton: Bool = true // 是否展示底部打卡按钮
    
    // 滑动优化相关状态
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollVelocity: CGFloat = 0
    @State private var lastScrollTime: Date = Date()
    @State private var isUserScrolling: Bool = false
    @State private var selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    private let checkInFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    @State private var checkInPulseScale: CGFloat = 1.0
    @State private var checkInPulseOpacity: Double = 0.45
    
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
    
    private struct PendingPhotoPrefill {
        var visitDate: Date?
        var photoData: Data
        var thumbnailData: Data
    }
    
    private struct PhotoMetadata {
        var coordinate: CLLocationCoordinate2D?
        var captureDate: Date?
    }
    
    private enum GeocodeResultSource {
        case live
        case cached
    }
    
    private enum PhotoImportError: Identifiable {
        case failedToLoad
        case missingLocation
        
        var id: String {
            switch self {
            case .failedToLoad:
                return "failedToLoad"
            case .missingLocation:
                return "missingLocation"
            }
        }
        
        var messageKey: String {
            switch self {
            case .failedToLoad:
                return "photo_import_failed_message"
            case .missingLocation:
                return "photo_import_missing_location_message"
            }
        }
    }
    
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
    
    private var shouldShowAssistiveMenu: Bool {
        selectedDestination == nil && !showRouteCards && !showSearchBar
    }
    
    private var brandAccentColor: Color {
        brandColorManager.currentBrandColor
    }
    
    // 仅为当前选中的旅程重新计算路线（进入“旅程”时避免全量计算）
    private func recalcSelectedTripRoutes(forceFullRecalc: Bool = false) {
        guard let selectedId = selectedTripId,
              let trip = trips.first(where: { $0.id == selectedId }),
              let tripDestinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
              tripDestinations.count >= 2 else { return }
        
        let coordinates = tripDestinations.map { $0.coordinate }
        Task {
            await calculateRoutesForTrip(
                tripId: selectedId,
                coordinates: coordinates,
                incremental: !forceFullRecalc
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let content = mainContentView(geometry: geometry)
            let withSheets = applySheets(to: content)
            let withLifecycle = applyLifecycleModifiers(to: withSheets, geometry: geometry)
            withLifecycle
        }
    }
    
    // 主视图内容
    @ViewBuilder
    private func mainContentView(geometry: GeometryProxy) -> some View {
        ZStack {
            mapLayer
            dismissOverlay
            previewCard
            routeCardsOverlay
            memoryBubbleOverlay
            floatingButtons
            keyboardOverlay
        }
        // 搜索功能已移至 searchBarOverlay，使用自定义覆盖层实现
    }
    
    // 应用 Sheet 修饰符
    @ViewBuilder
    private func applySheets<Content: View>(to content: Content) -> some View {
        content
            .sheet(item: $detailDestinationForSheet) { destination in
                NavigationStack {
                    DestinationDetailView(destination: destination)
                }
            }
            .sheet(isPresented: $showingTripDetail) {
                if let trip = detailTripForSheet {
                    NavigationStack {
                        TripDetailView(trip: trip)
                    }
                }
            }
            .sheet(isPresented: $showingFootprintsDrawer) {
                FootprintsDrawerView(
                    destinations: destinations.sorted(by: { $0.visitDate > $1.visitDate }),
                    onSelect: handleFootprintsSelect,
                    onAdd: handleFootprintsAdd,
                    onImportPhoto: handleFootprintsImport
                )
            }
            // 普通“添加目的地”弹窗
            .sheet(isPresented: $showingAddDestination, onDismiss: {
                addDestinationPrefill = nil
                pendingPhotoPrefill = nil
                isWaitingForLocation = false
                isGeocodingLocation = false
            }) {
                addDestinationSheet
            }
            // “快速打卡”弹窗
            .sheet(isPresented: $showingQuickCheckIn, onDismiss: {
                addDestinationPrefill = nil
                pendingPhotoPrefill = nil
                isWaitingForLocation = false
                isGeocodingLocation = false
            }) {
                quickCheckInSheet
            }
            .sheet(isPresented: $showingMapStylePicker) {
                mapStylePicker
            }
            .photosPicker(isPresented: $showingPhotoImportPicker, selection: $photoImportItem, matching: .images)
            .onChange(of: photoImportItem) { _, newValue in
                if let item = newValue {
                    handlePhotoImportSelection(item)
                }
            }
            .alert(item: $photoImportError) { error in
                Alert(
                    title: Text("photo_import_error_title".localized),
                    message: Text(error.messageKey.localized),
                    dismissButton: .default(Text("ok".localized))
                )
            }
    }
    
    // 应用生命周期修饰符
    @ViewBuilder
    private func applyLifecycleModifiers<Content: View>(to content: Content, geometry: GeometryProxy) -> some View {
        let withBasicModifiers = applyBasicLifecycleModifiers(to: content)
        let withDestinationModifiers = applyDestinationLifecycleModifiers(to: withBasicModifiers)
        let withLocationModifiers = applyLocationLifecycleModifiers(to: withDestinationModifiers)
        let withRouteCardModifiers = applyRouteCardLifecycleModifiers(to: withLocationModifiers)
        withRouteCardModifiers
            .id(refreshID)
    }
    
    // 基础生命周期修饰符
    @ViewBuilder
    private func applyBasicLifecycleModifiers<Content: View>(to content: Content) -> some View {
        content
            .onAppear {
                handleViewAppear()
            }
            .onDisappear {
                handleViewDisappear()
            }
            .onChange(of: isAppReady) { oldValue, newValue in
                // 当应用就绪状态从 false 变为 true 时（启动画面结束），执行延迟的初始化
                if !oldValue && newValue && locationInitializationPending {
                    print("✅ 启动画面已结束，定位服务已在启动画面期间启动，直接设置地图相机位置")
                    locationInitializationPending = false
                    // 定位服务已在启动画面期间启动，这里只需要设置地图相机位置
                    setInitialMapCameraPosition()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .shouldPrepareGeocoder)) { _ in
                // 在启动画面期间提前创建 Geocoder
                if geocoder == nil {
                    geocoder = CLGeocoder()
                    print("📍 Geocoder 已在启动画面期间提前创建")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { notification in
                handleDestinationDeleted(notification: notification)
            }
    }
    
    // 地点相关生命周期修饰符
    @ViewBuilder
    private func applyDestinationLifecycleModifiers<Content: View>(to content: Content) -> some View {
        content
            .onChange(of: destinations.count) { oldValue, newValue in
                print("🔄 地点数量变化: \(oldValue) -> \(newValue)")
                handleDestinationsChange()
            }
            .onChange(of: destinations) { oldValue, newValue in
                let oldIds = Set(oldValue.map { $0.id })
                let newIds = Set(newValue.map { $0.id })
                if oldIds != newIds {
                    print("🔄 地点ID集合变化")
                    handleDestinationsChange()
                } else {
                    checkDestinationsChange()
                }
            }
            .onChange(of: trips) { oldValue, newValue in
                for trip in newValue {
                    if let tripDestinations = trip.destinations {
                        let tripDestCount = tripDestinations.count
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
            .onChange(of: currentZoomLevelEnum) { oldValue, newValue in
                if oldValue != newValue {
                    print("📏 缩放级别变化: \(oldValue.description) → \(newValue.description)")
                    clearClusterCache()
                }
            }
            .onChange(of: showTripConnections) { _, newValue in
                if newValue {
                    if autoShowRouteCards {
                        recalcSelectedTripRoutes()
                    } else {
                        calculateRoutesForAllTrips()
                    }
                }
            }
            .onChange(of: trips.count) { _, _ in
                if showTripConnections {
                    if autoShowRouteCards {
                        recalcSelectedTripRoutes()
                    } else {
                        calculateRoutesForAllTrips()
                    }
                }
            }
            .onChange(of: selectedTripId) { oldValue, newValue in
                if autoShowRouteCards && oldValue != newValue {
                    clearClusterCache()
                }
            }
    }
    
    // 位置相关生命周期修饰符
    @ViewBuilder
    private func applyLocationLifecycleModifiers<Content: View>(to content: Content) -> some View {
        content
            .onChange(of: locationManager.lastKnownLocation) { _, newValue in
                handleLocationChange(newValue: newValue)
            }
    }
    
    // 路线卡片相关生命周期修饰符
    @ViewBuilder
    private func applyRouteCardLifecycleModifiers<Content: View>(to content: Content) -> some View {
        content
            .onChange(of: selectedDestination) { oldValue, newValue in
                if newValue != nil && showRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = true
                    }
                } else if newValue == nil && oldValue != nil && autoShowRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = false
                    }
                }
            }
            .onChange(of: showingTripDetail) { oldValue, newValue in
                if newValue && showRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = true
                    }
                } else if !newValue && oldValue && autoShowRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = false
                    }
                }
            }
            .onChange(of: showingPOIPreview) { oldValue, newValue in
                if newValue && showRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = true
                    }
                } else if !newValue && oldValue && autoShowRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = false
                    }
                }
            }
            .onChange(of: isSearchingPOI) { oldValue, newValue in
                if newValue && showRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = true
                    }
                } else if !newValue && oldValue && autoShowRouteCards {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        shouldHideRouteCards = false
                    }
                }
            }
    }
    
    // 处理地点删除通知
    private func handleDestinationDeleted(notification: Notification) {
        // 当地点被删除时，关闭所有相关弹窗
        if let userInfo = notification.userInfo,
           let deletedDestinationId = userInfo["destinationId"] as? UUID {
            // 检查是否是当前选中的地点
            if let selected = selectedDestination, selected.id == deletedDestinationId {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDestination = nil
                    mapSelection = nil
                }
            }
            // 检查是否是详情页中打开的地点
            if let detail = detailDestinationForSheet, detail.id == deletedDestinationId {
                detailDestinationForSheet = nil
            }
        } else {
            // 如果没有 destinationId，可能是批量删除，关闭所有弹窗
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDestination = nil
                mapSelection = nil
                detailDestinationForSheet = nil
            }
        }
    }
    
    // 处理位置变化
    private func handleLocationChange(newValue: CLLocationCoordinate2D?) {
        guard let newLocation = newValue else { return }
        
        let accuracy = locationManager.lastLocationAccuracy ?? Double.greatestFiniteMagnitude
        
        // 如果正在等待位置来设置初始相机位置，现在设置它
        if waitingForLocationToSetCamera && !initialCameraPositionSet {
            // 等待精度稳定（<200米）再设置相机位置
            if accuracy > 0 && accuracy < 200.0 {
                setCameraToUserLocation(newLocation)
                waitingForLocationToSetCamera = false
                initialCameraPositionSet = true
                print("📍 首次获取到位置，地图已定位到用户位置（精度: \(String(format: "%.1f", accuracy))米）")
            }
            // 注意：即使精度不够，也继续执行后续的反向地理编码逻辑
        }
        let distanceToLast: CLLocationDistance
        if let lastCoord = lastReverseGeocodeCoordinate {
            let newLoc = CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
            let oldLoc = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            distanceToLast = newLoc.distance(from: oldLoc)
        } else {
            distanceToLast = .greatestFiniteMagnitude
        }
        
        // 启动阶段节流控制：在启动后30秒内，只在位置精度稳定（<50米）且距离变化较大时才触发
        let isStartupPhase = viewAppearTime.map { Date().timeIntervalSince($0) < 30.0 } ?? false
        let isLocationStable = accuracy > 0 && accuracy < 50.0 // 位置精度稳定
        
        // 启动阶段：如果已经完成过一次自动反向地理编码，则后续位置更新不再自动触发请求
        if isStartupPhase && hasDoneInitialGeocode {
            lastReverseGeocodeCoordinate = newLocation
            lastGeocodedAccuracy = accuracy
            return
        }
        
        // 启动阶段：如果位置精度不稳定，延迟触发反向地理编码
        if isStartupPhase && !isLocationStable {
            print("⏳ 启动阶段，等待位置稳定（当前精度: \(String(format: "%.1f", accuracy))米）")
            // 启动阶段只安排一次延迟反向地理编码，给GPS更多时间稳定
            if !startupGeocodeScheduled {
                startupGeocodeScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    startupGeocodeScheduled = false
                    if let currentLocation = self.locationManager.lastKnownLocation {
                        let currentAccuracy = self.locationManager.lastLocationAccuracy ?? Double.greatestFiniteMagnitude
                        if currentAccuracy > 0 && currentAccuracy < 50.0 {
                            hasDoneInitialGeocode = true
                            self.reverseGeocodeLocation(coordinate: currentLocation, force: false)
                        }
                    }
                }
            }
            return
        }
        
        let accuracyImproved = accuracy + accuracyImprovementTrigger < lastGeocodedAccuracy
        // 启动阶段：即使精度改善，也不强制触发，避免频繁请求
        let shouldForce = isWaitingForLocation || (!isStartupPhase && (distanceToLast > 80 || accuracyImproved)) || lastReverseGeocodeCoordinate == nil
        
        if isWaitingForLocation {
            print("✅ 位置更新，开始打卡反向地理编码: (\(newLocation.latitude), \(newLocation.longitude)) 精度=\(String(format: "%.1f", accuracy))米")
            isWaitingForLocation = false
        }
        
        if isStartupPhase {
            // 启动阶段：只执行一次自动反向地理编码
            hasDoneInitialGeocode = true
        }
        
        reverseGeocodeLocation(coordinate: newLocation, force: shouldForce)
    }
    
    // 处理视图出现
    private func handleViewAppear() {
        selectionFeedbackGenerator.prepare()
        checkInFeedbackGenerator.prepare()
        
        // 记录视图出现时间，用于启动阶段的节流控制
        viewAppearTime = Date()
        isThrottled = false
        throttleResetTime = nil
        
        lastDestinationsSignature = destinationsSignature
        startPeriodicCheck()
        
        // 如果应用还未就绪（启动画面还在显示），延迟设置地图相机位置
        if !isAppReady {
            print("⏳ 启动画面显示中，定位服务已在后台启动，等待启动画面结束...")
            locationInitializationPending = true
            // 即使启动画面还在显示，也要处理路线卡片（如果在线路tab）
            if autoShowRouteCards {
                handleAutoShowRouteCards()
            }
            return
        }
        
        // 应用已就绪，处理路线卡片和地图相机位置
        if autoShowRouteCards {
            // 在线路tab，优先处理路线卡片，让地图缩放到旅程范围
            handleAutoShowRouteCards()
        } else {
            // 不在线路tab，设置初始地图相机位置（定位服务已在启动画面期间启动）
        setInitialMapCameraPosition()
        }
    }
    
    // 设置初始地图相机位置（优化：优先定位到用户位置）
    private func setInitialMapCameraPosition() {
        // 如果已经设置过，不再重复设置
        guard !initialCameraPositionSet else { return }
        
        // 检查定位服务是否已获取到位置
        if let userLocation = locationManager.lastKnownLocation {
            let accuracy = locationManager.lastLocationAccuracy ?? Double.greatestFiniteMagnitude
            // 如果位置精度较好（<200米），直接定位到用户位置
            if accuracy > 0 && accuracy < 200.0 {
                setCameraToUserLocation(userLocation)
                initialCameraPositionSet = true
                print("📍 地图已定位到用户位置: (\(userLocation.latitude), \(userLocation.longitude))")
            } else {
                // 位置精度不够，等待更好的位置
                waitingForLocationToSetCamera = true
                mapCameraPosition = .automatic
                print("⏳ 等待更精确的位置（当前精度: \(String(format: "%.1f", accuracy))米）")
            }
        } else {
            // 如果还没有位置，使用自动定位，并监听位置更新
            waitingForLocationToSetCamera = true
            mapCameraPosition = .automatic
            print("⏳ 等待定位获取，使用自动定位模式")
            
            // 确保 Geocoder 已创建
            if geocoder == nil {
                geocoder = CLGeocoder()
            }
        }
    }
    
    // 设置地图相机到用户位置
    private func setCameraToUserLocation(_ location: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // 约5公里范围
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(region)
        }
    }
    
    // 处理视图消失
    private func handleViewDisappear() {
        updateTimer?.invalidate()
        updateTimer = nil
        stopPeriodicCheck()
        locationManager.stopUpdatingLocation()
        geocodeTimeoutTimer?.invalidate()
        geocodeTimeoutTimer = nil
        pendingGeocodeCoordinate = nil
    }
    
    // 处理自动显示路线卡片
    private func handleAutoShowRouteCards() {
        let allTrips = trips
        let validTrips = allTrips.filter { trip in
            if let destinations = trip.destinations,
               !destinations.isEmpty,
               destinations.count >= 2 {
                return true
            }
            return false
        }
        
        var targetTrip: TravelTrip?
        var tripDestinations: [TravelDestination]?
        
        if let currentSelectedId = selectedTripId,
           let currentTrip = validTrips.first(where: { $0.id == currentSelectedId }),
           let destinations = currentTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
           destinations.count >= 2 {
            targetTrip = currentTrip
            tripDestinations = destinations
        } else if let firstValidTrip = validTrips.first,
                  let destinations = firstValidTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                  destinations.count >= 2 {
            targetTrip = firstValidTrip
            tripDestinations = destinations
            selectedTripId = firstValidTrip.id
        }
        
        if let trip = targetTrip, let destinations = tripDestinations {
            // 先缩放地图到旅程范围（确保地点可见）
            zoomToTripDestinations(destinations)
            
            // 显示旅程连线
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showTripConnections = true
            }
            
            // 计算路线
            let coordinates = destinations.map { $0.coordinate }
            Task {
                await calculateRoutesForTrip(tripId: trip.id, coordinates: coordinates, incremental: true)
            }
            
            // 延迟显示卡片，确保地图已经缩放完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showRouteCards = true
                }
            }
        } else {
            let fallbackTrip = allTrips.first { trip in
                if let selectedId = selectedTripId {
                    return trip.id == selectedId
                }
                return true
            }
            
            if let fallbackTrip {
                if selectedTripId != fallbackTrip.id {
                    selectedTripId = fallbackTrip.id
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showTripConnections = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showRouteCards = true
                    }
                }
            } else {
                showRouteCards = false
                selectedTripId = nil
            }
        }
    }
    
    // 处理足迹抽屉选择
    private func handleFootprintsSelect(_ destination: TravelDestination) {
        showingFootprintsDrawer = false
        let targetDestination = destination
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // 聚焦地图到指定地点
            let region = MKCoordinateRegion(
                center: targetDestination.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            withAnimation(.easeInOut(duration: 0.8)) {
                mapCameraPosition = .region(region)
            }
            detailDestinationForSheet = targetDestination
        }
    }
    
    // 处理足迹抽屉添加
    private func handleFootprintsAdd() {
        showingFootprintsDrawer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            addDestinationPrefill = nil
            pendingPhotoPrefill = nil
            isWaitingForLocation = false
            showingAddDestination = true
        }
    }
    
    // 处理足迹抽屉导入照片
    private func handleFootprintsImport() {
        showingFootprintsDrawer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            addDestinationPrefill = nil
            pendingPhotoPrefill = nil
            photoImportItem = nil
            isGeocodingLocation = false
            isWaitingForLocation = false
            showingPhotoImportPicker = true
        }
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
                    // 如果正在等待地图到达地点，检查是否已到达
                    if waitingForMapToReachDestination {
                        checkAndTriggerBubbles()
                    }
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // 在旅程页面禁用点击地图的POI搜索
                        if autoShowRouteCards {
                            return
                        }
                        
                        guard selectedDestination == nil,
                              !showingPOIPreview,
                              !showSearchBar else { return }
                        
                        let translation = value.translation
                        let dragDistance = hypot(translation.width, translation.height)
                        guard dragDistance < 8 else { return }
                        
                        if let coordinate = proxy.convert(value.location, from: .local) {
                            handleMapTap(at: coordinate)
                        }
                    }
            )
            // 当搜索栏显示时，禁用地图交互
            .allowsHitTesting(!showSearchBar)
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
                                            // 根据交通方式选择颜色
                                            let routeColor = routeColor(for: route.footprintTransportType)
                                            
                                            // 路线 - 使用 Apple 设计标准的样式（白色描边 + 主体颜色）
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
                                            // 再绘制主体颜色（较细），叠加在白色背景上
                                            MapPolyline(route.polyline)
                                                .stroke(
                                                    routeColor,
                                                    style: StrokeStyle(
                                                        lineWidth: 5,
                                                        lineCap: .round,
                                                        lineJoin: .round
                                                    )
                                                )
                                            
                                            // 距离标注（带交通方式选择）
                                            if let midpoint = midpointOfPolyline(route.polyline) {
                                                Annotation("", coordinate: midpoint) {
                                                    RouteDistanceLabel(
                                                        distance: route.footprintDistance,
                                                        transportType: route.footprintTransportType,
                                                        source: sourceDestination.coordinate,
                                                        destination: destinationDestination.coordinate,
                                                        onTransportTypeChange: { newType in
                                                            // 保存用户选择并重新计算路线
                                                            routeManager.setUserTransportType(
                                                                from: sourceDestination.coordinate,
                                                                to: destinationDestination.coordinate,
                                                                transportType: newType
                                                            )
                                                            // 清除该旅程的路线缓存，强制重新计算
                                                            tripRoutes.removeValue(forKey: trip.id)
                                                            // 重新计算该旅程的路线
                                                            let coordinates = visibleDestinations.map { $0.coordinate }
                                                            Task {
                                                                await calculateRoutesForTrip(tripId: trip.id, coordinates: coordinates, incremental: false)
                                                            }
                                                        }
                                                    )
                                                }
                                            }
                                        } else {
                                            // 如果该段路线为nil，显示占位线（虚线）
                                            let source = visibleDestinations[index]
                                            let destination = visibleDestinations[index + 1]
                                            let transportType = calculatePlaceholderTransportType(from: source, to: destination)
                                            placeholderRouteContent(
                                                for: source,
                                                destination: destination,
                                                transportType: transportType,
                                                tripId: trip.id,
                                                visibleDestinations: visibleDestinations
                                            )
                                        }
                                    }
                                }
                            }
                        } else {
                            // 如果没有路线或所有路线都是nil，显示彩色占位线，但也要检查聚合
                            ForEach(Array(visibleDestinations.enumerated()), id: \.offset) { index, _ in
                                if index < visibleDestinations.count - 1 {
                                    let source = visibleDestinations[index]
                                    let destination = visibleDestinations[index + 1]
                                    
                                    // 如果不在同一个聚合中，才显示占位线
                                    if !areDestinationsInSameCluster(source, destination) {
                                        let transportType = calculatePlaceholderTransportType(from: source, to: destination)
                                        placeholderRouteContent(
                                            for: source,
                                            destination: destination,
                                            transportType: transportType,
                                            tripId: trip.id,
                                            visibleDestinations: visibleDestinations
                                        )
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
                    tripColorMap: tripColorMapping,
                    accentColor: brandAccentColor,
                    weatherSummary: weatherSummary(for: cluster)
                )
                .equatable()
                .task(id: weatherTaskIdentifier(for: cluster)) {
                    await requestWeatherIfNeeded(for: cluster)
                }
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
    
    private func weatherSummary(for cluster: ClusterAnnotation) -> WeatherSummary? {
        guard cluster.destinations.count == 1,
              let destination = cluster.destinations.first
        else { return nil }
        return destinationWeatherManager.summary(for: destination.id)
    }
    
    private func shouldDisplayWeather(for cluster: ClusterAnnotation) -> Bool {
        currentZoomLevel >= 10 && cluster.destinations.count == 1
    }
    
    private func weatherTaskIdentifier(for cluster: ClusterAnnotation) -> String {
        "\(cluster.id)-\(currentZoomLevelEnum.rawValue)"
    }
    
    private func requestWeatherIfNeeded(for cluster: ClusterAnnotation) async {
        guard shouldDisplayWeather(for: cluster),
              let destination = cluster.destinations.first
        else { return }
        await destinationWeatherManager.refreshWeatherIfNeeded(for: destination)
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
                // 在旅程页面禁用长按手势
                if autoShowRouteCards {
                    return
                }
                
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
    
    // 处理地图点击 - 检测POI或地址信息
    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        // 在旅程页面禁用反向地理编码和POI搜索
        if autoShowRouteCards {
            print("⏭️ 旅程页面：已禁用点击地图的POI搜索")
            return
        }
        
        print("📍 点击地图位置: (\(coordinate.latitude), \(coordinate.longitude))")
        
        // 检查点击位置是否接近任何标注或聚合点
        // 如果接近，则不触发POI搜索（因为标注/聚合点有自己的点击处理）
        if isNearAnnotationOrCluster(coordinate) {
            print("📍 点击位置接近标注或聚合点，跳过POI搜索")
            return
        }
        
        // 先关闭之前可能显示的POI预览
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showingPOIPreview = false
            selectedPOI = nil
        }
        
        // 搜索该位置的POI信息（用户主动点击，不受启动阶段节流影响）
        searchPOIAtCoordinate(coordinate, isUserInitiated: true)
    }
    
    // 检查点击坐标是否接近任何标注或聚合点
    private func isNearAnnotationOrCluster(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 阈值：50米（考虑标注视图的视觉大小和点击容差）
        let thresholdDistance: CLLocationDistance = 50.0
        
        // 检查是否接近任何聚合点
        for cluster in clusterAnnotations {
            let distance = coordinate.distance(to: cluster.coordinate)
            if distance < thresholdDistance {
                return true
            }
        }
        
        // 检查是否接近任何单独的地点（不在聚合中的）
        // 注意：如果地点在聚合中，已经在上面检查过了
        let allClusteredDestinationIds = Set(clusterAnnotations.flatMap { $0.destinations.map { $0.id } })
        for destination in visibleDestinationsInRegion {
            // 只检查不在聚合中的地点（单独显示的标注）
            if !allClusteredDestinationIds.contains(destination.id) {
                let distance = coordinate.distance(to: destination.coordinate)
                if distance < thresholdDistance {
                    return true
                }
            }
        }
        
        return false
    }
    
    // 在指定坐标搜索POI（用于点击地图）
    private func searchPOIAtCoordinate(_ coordinate: CLLocationCoordinate2D, isUserInitiated: Bool = false) {
        // 优化：先尝试小范围精确搜索，找不到再扩大范围
        searchPOIAtCoordinate(coordinate, searchSpan: nil, isRetry: false, isUserInitiated: isUserInitiated)
    }
    
    // 统一显示POI结果：智能处理加载状态
    private func showPOIResult(_ mapItem: MKMapItem, message: String? = nil) {
        // 取消延迟显示加载卡片的任务（如果结果返回得很快，就不显示加载状态）
        loadingTaskHolder.task?.cancel()
        loadingTaskHolder.task = nil
        
        if let message = message {
            print(message)
        }
        
        // 检查是否已经显示了加载状态
        if isSearchingPOI {
            // 如果已显示加载状态，先隐藏它，然后显示结果（平滑过渡）
            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                self.isSearchingPOI = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.selectedPOI = mapItem
                    self.showingPOIPreview = true
                }
            }
        } else {
            // 如果没显示加载状态（快速返回），直接显示结果
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.selectedPOI = mapItem
                self.showingPOIPreview = true
            }
        }
    }
    
    // 优化的POI搜索方法：支持渐进式搜索策略和多种搜索方式
    private func searchPOIAtCoordinate(_ coordinate: CLLocationCoordinate2D, searchSpan: MKCoordinateSpan?, isRetry: Bool, isUserInitiated: Bool = false) {
        // 只在首次搜索时设置延迟显示加载状态（重试时不重新设置）
        if !isRetry {
            // 记录搜索开始时间
            poiSearchStartTime = Date()
            
            // 取消之前的延迟显示任务
            loadingTaskHolder.task?.cancel()
            
            // 用户主动点击时，立即显示加载状态（不等待300ms），提供即时反馈
            if isUserInitiated {
                withAnimation(.easeIn(duration: 0.1)) {
                    isSearchingPOI = true
                }
            } else {
                // 延迟显示加载卡片：如果搜索很快完成（300ms内），就不显示加载状态
                let task = DispatchWorkItem {
                    // 检查是否已经显示了结果，如果没有才显示加载状态
                    if !showingPOIPreview && selectedPOI == nil {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isSearchingPOI = true
                        }
                    }
                }
                loadingTaskHolder.task = task
                DispatchQueue.main.asyncAfter(deadline: .now() + showLoadingThreshold, execute: task)
            }
        }
        
        // 判断是否在中国境内
        let isInChina = CoordinateConverter.isInChina(coordinate)
        
        // 优化：在中国使用高德API，其他地区使用Apple MapKit
        if isInChina && !isRetry {
            // 在中国：使用高德API进行POI搜索（更可靠，识别率更高）
            searchPOIWithGeocodeService(coordinate: coordinate, isUserInitiated: isUserInitiated)
            return
        }
        
        let request = MKLocalSearch.Request()
        
        // 搜索范围策略：先小范围精确搜索，失败后再扩大范围
        let span: MKCoordinateSpan
        if let providedSpan = searchSpan {
            span = providedSpan
        } else {
            // 首次搜索：使用较小范围提高精度
            if isInChina {
                span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // 中国使用稍大范围
            } else {
                span = MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003) // 约300米范围
            }
        }
        
        // 优化：设置region而不是只设置naturalLanguageQuery
        request.region = MKCoordinateRegion(center: coordinate, span: span)
        
        // 优化：在中国，不设置naturalLanguageQuery可能导致错误，尝试不设置region但设置查询词
        // 但这里我们通过反向地理编码先获取POI名称，然后再搜索
        if #available(iOS 13.0, *) {
            // 优先搜索POI
            request.resultTypes = [.pointOfInterest, .address]
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                // 取消延迟显示加载卡片的任务
                self.loadingTaskHolder.task?.cancel()
                self.loadingTaskHolder.task = nil
                
                if let error = error {
                    // 如果已经显示了加载状态，先隐藏它
                    if self.isSearchingPOI {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                            self.isSearchingPOI = false
                        }
                    }
                    
                    // 详细错误信息
                    let nsError = error as NSError
                    print("❌ POI搜索失败:")
                    print("   错误描述: \(error.localizedDescription)")
                    print("   错误代码: \(nsError.code)")
                    print("   错误域: \(nsError.domain)")
                    
                    // 如果不是重试且搜索范围较小，尝试扩大范围重试
                    if !isRetry {
                        let largerSpan = MKCoordinateSpan(
                            latitudeDelta: span.latitudeDelta * 4,
                            longitudeDelta: span.longitudeDelta * 4
                        )
                        print("   🔄 扩大搜索范围重试...")
                        self.searchPOIAtCoordinate(coordinate, searchSpan: largerSpan, isRetry: true, isUserInitiated: isUserInitiated)
                        return
                    }
                    
                    if isInChina {
                        print("   ⚠️ 在中国境内，MKLocalSearch可能不稳定，降级到反向地理编码")
                    }
                    // 搜索失败时，尝试反向地理编码获取地址信息
                    self.fallbackToAddressInfo(coordinate: coordinate)
                    return
                }
                
                // 检查响应是否为空
                guard let response = response, !response.mapItems.isEmpty else {
                    // 如果首次搜索无结果且范围较小，尝试扩大范围
                    if !isRetry {
                        let largerSpan = MKCoordinateSpan(
                            latitudeDelta: span.latitudeDelta * 4,
                            longitudeDelta: span.longitudeDelta * 4
                        )
                        print("⚠️ 小范围搜索无结果，扩大搜索范围重试...")
                        self.searchPOIAtCoordinate(coordinate, searchSpan: largerSpan, isRetry: true, isUserInitiated: isUserInitiated)
                        return
                    }
                    
                    print("⚠️ POI搜索返回空结果，尝试反向地理编码")
                    self.fallbackToAddressInfo(coordinate: coordinate)
                    return
                }
                
                // 处理搜索结果
                self.processPOISearchResults(response: response, clickCoordinate: coordinate)
            }
        }
    }
    
    // 使用统一的地理编码服务进行POI搜索（混合策略：中国使用高德，其他地区使用Apple）
    private func searchPOIWithGeocodeService(coordinate: CLLocationCoordinate2D, isUserInitiated: Bool = false) {
        // 获取适合的服务（根据坐标自动选择高德或Apple）
        let service = GeocodeServiceFactory.createService(for: coordinate)
        
        print("📍 [统一服务] 开始POI搜索，服务: \(service is AMapGeocodeService ? "高德API" : "Apple MapKit")")
        
        // 1. 先进行反向地理编码获取地址和POI信息
        service.reverseGeocode(coordinate: coordinate) { result in
            switch result {
            case .success(let geocodeResult):
                // 处理成功结果
                self.handleGeocodeResult(geocodeResult, coordinate: coordinate)
                
                // 2. 如果在中国且没有找到POI，同时搜索周边POI（增强功能）
                if geocodeResult.source == .amap && geocodeResult.poi == nil {
                    // 搜索500米范围内的周边POI
                    service.searchNearbyPOIs(coordinate: coordinate, radius: 500) { nearbyResult in
                        switch nearbyResult {
                        case .success(let nearbyPOIResult):
                            if let nearestPOI = nearbyPOIResult.nearestPOI {
                                print("📍 [统一服务] 找到最近的周边POI: \(nearestPOI.name) (\(nearestPOI.formattedDistance))")
                                // 使用最近的POI创建结果
                                let poiResult = GeocodeResult(
                                    coordinate: coordinate,
                                    address: geocodeResult.address,
                                    poi: nearestPOI,
                                    source: .amap
                                )
                                self.handleGeocodeResult(poiResult, coordinate: coordinate)
                            }
                        case .failure(let error):
                            print("⚠️ [统一服务] 周边POI搜索失败: \(error.localizedDescription)")
                            // 忽略错误，使用反向地理编码的结果
                        }
                    }
                }
                
            case .failure(let error):
                // 处理错误：降级到Apple MapKit或显示错误
                print("❌ [统一服务] 反向地理编码失败: \(error.localizedDescription)")
                self.handleGeocodeError(error, coordinate: coordinate, isUserInitiated: isUserInitiated)
            }
        }
    }
    
    // 处理统一的地理编码结果
    private func handleGeocodeResult(_ result: GeocodeResult, coordinate: CLLocationCoordinate2D) {
        // 转换为MKMapItem用于显示
        let mapItem = result.toMapItem()
        
        // 构建消息
        var message = "✅ 找到位置信息（来源：\(result.source.displayName)）"
        if let poi = result.poi {
            message += "\n   POI: \(poi.name)"
            if let distance = poi.distance {
                message += " (\(String(format: "%.0f", distance))米)"
            }
        } else {
            message += "\n   地址: \(result.address.buildFullAddress())"
        }
        
        // 显示结果
        showPOIResult(mapItem, message: message)
    }
    
    // 处理地理编码错误
    private func handleGeocodeError(_ error: Error, coordinate: CLLocationCoordinate2D, isUserInitiated: Bool) {
        // 检查是否是节流错误 - 如果是，不继续尝试，避免触发更多节流
        if let nsError = error as NSError?,
           nsError.domain == "GEOErrorDomain" && nsError.code == -3 {
            print("⚠️ Apple地理编码已被节流，停止尝试降级，避免进一步触发节流")
            // 显示错误信息给用户
            showErrorFallback(coordinate: coordinate)
            return
        }
        
        // 检查当前是否处于节流状态
        if isThrottled {
            print("⚠️ 当前处于节流状态，不继续尝试降级服务")
            showErrorFallback(coordinate: coordinate)
            return
        }
        
        // 如果是高德API失败（网络错误或超时），且是用户主动点击，可以尝试降级
        if (error is AMapError || error.localizedDescription.contains("高德") || error.localizedDescription.contains("超时") || error.localizedDescription.contains("网络错误")) && isUserInitiated {
            print("⚠️ 高德API失败（用户主动点击），尝试降级到Apple MapKit")
            // 使用Apple服务重试（但只在用户主动点击时）
            let appleService = AppleGeocodeService.shared
            appleService.reverseGeocode(coordinate: coordinate) { result in
                switch result {
                case .success(let geocodeResult):
                    self.handleGeocodeResult(geocodeResult, coordinate: coordinate)
                case .failure:
                    // Apple也失败，显示错误信息
                    print("⚠️ Apple MapKit也失败，显示错误信息")
                    self.showErrorFallback(coordinate: coordinate)
                }
            }
        } else {
            // 其他错误或自动请求，直接显示错误信息，不再尝试降级
            print("⚠️ 地理编码服务失败，显示错误信息")
            showErrorFallback(coordinate: coordinate)
        }
    }
    
    // 显示错误回退信息（使用坐标兜底）
    private func showErrorFallback(coordinate: CLLocationCoordinate2D) {
        // 使用坐标兜底方案
        fallbackWithCoordinateOnly(coordinate: coordinate)
    }
    
    // 优化的反向地理编码方法：在中国优先使用，可以获取areasOfInterest（POI名称）
    // 注意：此方法保留用于兼容性，但优先使用searchPOIWithGeocodeService
    private func tryReverseGeocodeWithPOI(coordinate: CLLocationCoordinate2D, isUserInitiated: Bool = false) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 使用独立的 geocoder（不受主 geocoder 节流影响）
        let poiGeocoder = CLGeocoder()
        
        // 用户主动点击时，记录日志以便调试
        if isUserInitiated {
            print("👆 用户主动点击POI，立即执行反向地理编码（不受启动阶段节流影响）")
        }
        
        poiGeocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    // 反向地理编码失败，尝试MKLocalSearch
                    print("⚠️ 反向地理编码失败，尝试MKLocalSearch: \(error.localizedDescription)")
                    self.searchPOIAtCoordinate(coordinate, searchSpan: nil, isRetry: true, isUserInitiated: isUserInitiated)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("⚠️ 反向地理编码返回空结果，尝试MKLocalSearch")
                    self.searchPOIAtCoordinate(coordinate, searchSpan: nil, isRetry: true, isUserInitiated: isUserInitiated)
                    return
                }
                
                // 从placemark中提取POI信息
                let poiName = placemark.areasOfInterest?.first ?? placemark.name
                let hasPOIInfo = placemark.areasOfInterest != nil && !placemark.areasOfInterest!.isEmpty
                
                // 如果有POI名称，使用MKLocalSearch搜索该POI获取详细信息
                if let poiName = poiName, hasPOIInfo {
                    print("✅ 反向地理编码找到POI: \(poiName)，使用MKLocalSearch获取详细信息...")
                    self.searchPOIByName(poiName: poiName, nearCoordinate: coordinate)
                } else {
                    // 没有POI信息，直接使用反向地理编码结果
                    print("✅ 反向地理编码成功，但没有POI信息，直接使用地址信息")
                    self.createMapItemFromPlacemark(placemark, coordinate: coordinate)
                }
            }
        }
    }
    
    // 通过POI名称搜索获取详细信息（在中国更可靠）
    private func searchPOIByName(poiName: String, nearCoordinate: CLLocationCoordinate2D) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = poiName
        
        // 设置搜索区域为点击位置附近
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        request.region = MKCoordinateRegion(center: nearCoordinate, span: span)
        
        if #available(iOS 13.0, *) {
            request.resultTypes = [.pointOfInterest, .address]
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                // 取消延迟显示加载卡片的任务（如果需要显示错误结果，会由后续处理）
                
                if let error = error {
                    print("⚠️ 通过POI名称搜索失败: \(error.localizedDescription)，使用反向地理编码结果")
                    let location = CLLocation(latitude: nearCoordinate.latitude, longitude: nearCoordinate.longitude)
                    let geocoder = CLGeocoder()
                    geocoder.reverseGeocodeLocation(location) { placemarks, error in
                        DispatchQueue.main.async {
                            if let placemark = placemarks?.first {
                                self.createMapItemFromPlacemark(placemark, coordinate: nearCoordinate)
                            } else {
                                self.fallbackToAddressInfo(coordinate: nearCoordinate)
                            }
                        }
                    }
                    return
                }
                
                // 找到匹配的POI，选择最接近点击位置的
                if let response = response, !response.mapItems.isEmpty {
                    let clickLocation = CLLocation(latitude: nearCoordinate.latitude, longitude: nearCoordinate.longitude)
                    
                    // 找到最近的POI
                    let nearestPOI = response.mapItems.min { item1, item2 in
                        let loc1 = CLLocation(latitude: item1.placemark.coordinate.latitude,
                                             longitude: item1.placemark.coordinate.longitude)
                        let loc2 = CLLocation(latitude: item2.placemark.coordinate.latitude,
                                             longitude: item2.placemark.coordinate.longitude)
                        return clickLocation.distance(from: loc1) < clickLocation.distance(from: loc2)
                    }
                    
                    if let poi = nearestPOI {
                        // 使用统一函数显示结果（智能处理加载状态）
                        showPOIResult(poi, message: "✅ 通过POI名称找到匹配: \(poi.name ?? "未知")")
                        return
                    }
                }
                
                // 如果通过名称搜索失败，使用反向地理编码
                print("⚠️ POI名称搜索无结果，使用反向地理编码")
                self.fallbackToAddressInfo(coordinate: nearCoordinate)
            }
        }
    }
    
    // 从CLPlacemark创建MKMapItem
    private func createMapItemFromPlacemark(_ placemark: CLPlacemark, coordinate: CLLocationCoordinate2D) {
        let mkPlacemark = MKPlacemark(placemark: placemark)
        let mapItem = MKMapItem(placemark: mkPlacemark)
        
        // 构建地点名称
        let poiName = placemark.areasOfInterest?.first
        let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
        let streetName = placemark.thoroughfare ?? ""
        let streetNumber = placemark.subThoroughfare ?? ""
        
        let locationName = self.buildLocationName(
            poi: poiName ?? "",
            city: cityName,
            street: streetName,
            streetNumber: streetNumber
        )
        
        mapItem.name = locationName
        
        var message = "✅ 使用反向地理编码结果: \(locationName)"
        if let poi = poiName {
            message += "\n   POI: \(poi)"
        }
        
        // 使用统一函数显示结果（智能处理加载状态）
        showPOIResult(mapItem, message: message)
    }
    
    // 处理POI搜索结果：优化匹配逻辑，优先选择最近的POI
    private func processPOISearchResults(response: MKLocalSearch.Response, clickCoordinate: CLLocationCoordinate2D) {
        let clickLocation = CLLocation(latitude: clickCoordinate.latitude, longitude: clickCoordinate.longitude)
        
        // 优先选择POI结果，如果没有POI则选择地址结果
        let poiItems = response.mapItems.filter { item in
            item.pointOfInterestCategory != nil || item.name != nil
        }
        
        // 优化：计算所有POI的距离，并按距离排序，优先选择最近的
        let poiWithDistances = poiItems.map { item -> (item: MKMapItem, distance: CLLocationDistance) in
            let poiLocation = CLLocation(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            let distance = clickLocation.distance(from: poiLocation)
            return (item, distance)
        }.sorted { $0.distance < $1.distance } // 按距离从近到远排序
        
        // 优化的检测范围：从50米缩小到20米，提高点击精度
        let preciseClickThreshold: CLLocationDistance = 20 // 20米内认为是精确点击了POI图标
        let nearbyClickThreshold: CLLocationDistance = 50  // 50米内认为是点击了附近POI
        
        // 优先查找精确点击的POI（20米内）
        if let precisePOI = poiWithDistances.first(where: { $0.distance <= preciseClickThreshold }) {
            showPOIResult(precisePOI.item, message: "✅ 精确点击了POI图标 (\(String(format: "%.1f", precisePOI.distance))米): \(precisePOI.item.name ?? "未知")")
            return
        }
        
        // 如果没有精确点击，检查是否有附近POI（20-50米）
        if let nearbyPOI = poiWithDistances.first(where: { $0.distance <= nearbyClickThreshold }) {
            showPOIResult(nearbyPOI.item, message: "✅ 点击了附近POI (\(String(format: "%.1f", nearbyPOI.distance))米): \(nearbyPOI.item.name ?? "未知")")
            return
        }
        
        // 如果有POI但距离较远，选择最近的POI
        if let nearestPOI = poiWithDistances.first {
            let distance = nearestPOI.distance
            if distance <= 100 { // 100米内仍然显示最近的POI
                showPOIResult(nearestPOI.item, message: "✅ 找到最近POI (\(String(format: "%.1f", distance))米): \(nearestPOI.item.name ?? "未知")")
                return
            }
        }
        
        // 没有找到合适的POI，尝试显示地址信息
        if let firstAddress = response.mapItems.first(where: { $0.pointOfInterestCategory == nil }) {
            showPOIResult(firstAddress, message: "✅ 找到地址信息: \(firstAddress.name ?? "未知")")
            return
        }
        
        // 完全没有找到任何信息，尝试反向地理编码
        print("⚠️ 未找到POI或地址，尝试反向地理编码")
        self.fallbackToAddressInfo(coordinate: clickCoordinate)
    }
    
    // 备用方案：使用反向地理编码获取地址信息
    private func fallbackToAddressInfo(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 使用独立的 geocoder，避免主 geocoder 忙碌时冲突
        let fallbackGeocoder = CLGeocoder()
        fallbackGeocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let mkPlacemark = MKPlacemark(placemark: placemark)
                    let mapItem = MKMapItem(placemark: mkPlacemark)
                    
                    // 构建地点名称
                    let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
                    let streetName = placemark.thoroughfare ?? ""
                    let streetNumber = placemark.subThoroughfare ?? ""
                    let poi = placemark.areasOfInterest?.first ?? ""
                    
                    let locationName = self.buildLocationName(
                        poi: poi,
                        city: cityName,
                        street: streetName,
                        streetNumber: streetNumber
                    )
                    
                    mapItem.name = locationName
                    
                    // 使用统一函数显示结果（智能处理加载状态）
                    showPOIResult(mapItem, message: "✅ 反向地理编码成功: \(locationName)")
                } else {
                    let errorDescription = error?.localizedDescription ?? "未知错误"
                    print("❌ 反向地理编码失败: \(errorDescription)")
                    // 再次失败时兜底展示已选择地点
                    self.fallbackWithCoordinateOnly(coordinate: coordinate)
                }
            }
        }
    }
    
    // 消失覆盖层
    @ViewBuilder
    private var dismissOverlay: some View {
        if selectedDestination != nil || showingPOIPreview {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedDestination = nil
                        mapSelection = nil
                        showingPOIPreview = false
                        selectedPOI = nil
                    }
                }
                .zIndex(1)
        }
    }
    
    // 键盘覆盖层：当搜索栏显示且有焦点时，阻止地图交互
    @ViewBuilder
    private var keyboardOverlay: some View {
        if showSearchBar && isSearchFocused {
            // 使用 GeometryReader 来覆盖键盘区域
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    // 覆盖键盘区域，阻止地图交互
                    // 使用 clear 颜色但拦截事件，阻止传递到地图
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: max(geometry.size.height * 0.45, 350)) // 覆盖键盘区域（约屏幕高度的45%，至少350点）
                        .allowsHitTesting(true) // 允许接收事件，阻止事件传递到地图
                        .onTapGesture {
                            // 空手势处理，拦截点击事件，阻止传递到地图层
                            // 这样点击键盘区域时不会关闭搜索框
                        }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .allowsHitTesting(true) // 确保覆盖层可以接收事件
            .zIndex(1.5) // 在地图之上（zIndex 0），但在搜索框和按钮容器之下（zIndex 4）
        }
    }
    
    // 预览卡片
    private var previewCard: some View {
        VStack {
            Spacer()
            if let selected = selectedDestination {
                DestinationPreviewCard(destination: selected, onOpenDetail: {
                    // 父级弹出详情页，并隐藏小弹窗
                    detailDestinationForSheet = selected
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedDestination = nil
                        mapSelection = nil
                    }
                })
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showingPOIPreview, let poi = selectedPOI {
                POIPreviewCard(mapItem: poi, onAddDestination: {
                    // 点击"添加目的地"按钮，打开添加目的地界面
                    handlePOIAddDestination(poi: poi)
                }, onDismiss: {
                    // 关闭POI预览
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showingPOIPreview = false
                        selectedPOI = nil
                    }
                })
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isSearchingPOI {
                // 显示加载状态的POI搜索卡片
                POISearchingCard()
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
                let displayTrips = trips
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(displayTrips.enumerated()), id: \.element.id) { index, trip in
                                let sortedDestinations = (trip.destinations ?? []).sorted(by: { $0.visitDate < $1.visitDate })
                                
                                // 使用容器包装卡片，确保阴影有足够空间不被裁剪
                                ZStack {
                                    RouteCard(
                                        trip: trip,
                                        destinations: sortedDestinations,
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
                                        handleCardAppear(trip: trip, destinations: sortedDestinations)
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
                                scrollVelocity = (offsetDelta / CGFloat(timeDelta)) * 0.6
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
                               let trip = displayTrips.first(where: { $0.id == closestId }) {
                                let destinations = (trip.destinations ?? []).sorted(by: { $0.visitDate < $1.visitDate })
                                handleCardAppear(trip: trip, destinations: destinations)
                            }
                        }
                        
                        // 创建磁吸任务（滚动停止后自动居中并分页）
                        let snapTaskWorkItem = DispatchWorkItem {
                            // 标记用户滚动结束
                            isUserScrolling = false
                            
                            let (closestId, _) = findClosestCardToCenter(offsets: offsets)
                            
                            // 计算应该跳转到哪张卡片
                            let cardWidth: CGFloat = 320
                            let cardSpacing: CGFloat = 12
                            
                            // 根据滚动速度决定跳转策略
                            // 目标：轻滑只跳一张，快速滑动可以跳多张
                            let slowSpeedThreshold: CGFloat = 220 // 慢速阈值（点/秒），低于此速度使用最近卡片
                            let fastSpeedThreshold: CGFloat = 700 // 快速阈值（点/秒），超过此速度可以跳2张
                            
                            var targetTripId: UUID? = closestId
                            
                            // 如果滚动速度较快，根据速度决定跳转几张卡片
                            if let currentIndex = displayTrips.firstIndex(where: { $0.id == selectedTripId }) {
                                let absVelocity = abs(scrollVelocity)
                                
                                if absVelocity > fastSpeedThreshold {
                                    // 快速滑动：根据速度跳转1-2张卡片
                                    let direction = scrollVelocity < 0 ? -1 : 1
                                    // 速度越快，跳转越多（但最多2张）
                                    let speedFactor = min(2.0, (absVelocity - fastSpeedThreshold) / 300 + 1.0)
                                    let jumpCount = max(1, Int(round(speedFactor)))
                                    let targetIndex = max(0, min(displayTrips.count - 1, currentIndex + (jumpCount * direction)))
                                    if targetIndex < displayTrips.count && targetIndex != currentIndex {
                                        targetTripId = displayTrips[targetIndex].id
                                    }
                                } else if absVelocity > slowSpeedThreshold {
                                    // 中等速度：跳转1张卡片（确保轻滑只跳一张）
                                    let direction = scrollVelocity < 0 ? -1 : 1
                                    let targetIndex = max(0, min(displayTrips.count - 1, currentIndex + direction))
                                    if targetIndex < displayTrips.count && targetIndex != currentIndex {
                                        targetTripId = displayTrips[targetIndex].id
                                    }
                                }
                                // 慢速滑动（absVelocity <= slowSpeedThreshold）：使用最近的卡片（closestId），自动吸附
                            }
                            
                            // 如果找到目标卡片，且距离中心超过阈值，则自动吸附到中心
                            if let targetId = targetTripId,
                               let targetTrip = displayTrips.first(where: { $0.id == targetId }) {
                                let destinations = (targetTrip.destinations ?? []).sorted(by: { $0.visitDate < $1.visitDate })
                                
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
                           let currentTrip = displayTrips.first(where: { $0.id == currentSelectedId }),
                           let tripDestinations = currentTrip.destinations {
                            let destinations = tripDestinations.sorted(by: { $0.visitDate < $1.visitDate })
                            guard destinations.count >= 2 else { return }
                            
                            // 如果已经有选中的卡片，确保地图已缩放到该旅程范围
                            // 检查地图是否已经正确缩放（通过检查当前地图位置）
                            // 如果地图还没有缩放，再次调用缩放函数
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                // 延迟一点确保地图已经渲染，然后再次确保缩放正确
                                zoomToTripDestinations(destinations)
                            }
                            
                            // 滚动到该卡片并居中（保持地图和卡片一致）
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    proxy.scrollTo(currentSelectedId, anchor: .center)
                                }
                            }
                        } else if selectedTripId == nil, let firstTrip = displayTrips.first,
                                  let tripDestinations = firstTrip.destinations {
                            let destinations = tripDestinations.sorted(by: { $0.visitDate < $1.visitDate })
                            guard destinations.count >= 2 else { return }
                            // 如果没有选中的卡片，选中第一个并缩放地图
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
        selectionFeedbackGenerator.selectionChanged()
        selectionFeedbackGenerator.prepare()
        
        // 如果在线路tab，清除聚合缓存，以便重新计算只显示当前线路的地点
        if autoShowRouteCards {
            clearClusterCache()
            if destinations.count >= 2 {
                // 确保显示旅程连线
                if !showTripConnections {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showTripConnections = true
                    }
                }
            } else if showTripConnections {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showTripConnections = false
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
            // iOS 26标准搜索栏覆盖层
            if showSearchBar {
                VStack {
                    searchBarOverlay
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if shouldShowAssistiveMenu {
                GeometryReader { proxy in
                    FloatingAssistiveMenu(
                        actions: assistiveMenuActions,
                        isExpanded: $assistiveMenuExpanded,
                        position: $assistiveMenuPosition,
                        canvasSize: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        menuTitle: "map_button_menu".localized,
                        isDarkStyle: colorScheme == .dark || isDarkMapStyle,
                        iconProvider: { icon, isActive in
                            menuIcon(for: icon, isActive: isActive)
                        },
                        activeBackground: activeButtonBackground
                    )
                    .onAppear {
                        if assistiveMenuPosition == .zero {
                            assistiveMenuPosition = FloatingAssistiveMenu.defaultPosition(
                                in: proxy.size,
                                safeArea: proxy.safeAreaInsets
                            )
                        } else {
                            assistiveMenuPosition = FloatingAssistiveMenu.clamp(
                                assistiveMenuPosition,
                                in: proxy.size,
                                safeArea: proxy.safeAreaInsets,
                                requiresMenuSpace: false
                            )
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .zIndex(4) // 确保浮动按钮在折叠覆盖层之上
        .onChange(of: shouldShowAssistiveMenu) { newValue in
            if !newValue {
                assistiveMenuExpanded = false
            }
        }
    }
    
    private var bottomCheckInButton: some View {
        Button {
            handleCheckIn()
        } label: {
            ZStack {
                // 外圈脉冲光晕（品牌色，呼吸感）
                Circle()
                    .fill(brandColorManager.currentBrandColor.opacity(0.25))
                    .frame(width: 92, height: 92)
                    .scaleEffect(checkInPulseScale)
                    .opacity(checkInPulseOpacity)
                
                // 中心 Liquid Glass 按钮（iOS 26+ 使用 .glassEffect，旧版退回 Material）
                Group {
                    if #available(iOS 26, *) {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 72, height: 72)
                            // iOS 26 Liquid Glass
                            .glassEffect(.regular, in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.7),
                                                brandColorManager.currentBrandColor.opacity(0.5),
                                                .white.opacity(0.25)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            // 整体透明度与底部导航相近（约 85% 不透明）
                            .opacity(0.95)
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.3),
                                radius: 10,
                                x: 0,
                                y: 6
                            )
                            .overlay(checkInIcon)
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.6),
                                                brandColorManager.currentBrandColor.opacity(0.4),
                                                .white.opacity(0.25)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .opacity(0.85)
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.25),
                                radius: 10,
                                x: 0,
                                y: 6
                            )
                            .overlay(checkInIcon)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("map_button_check_in".localized)
        .accessibilityHint("quick_check_in".localized)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(searchText.isEmpty)
        .opacity(searchText.isEmpty ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                checkInPulseScale = 1.3
                checkInPulseOpacity = 0.0
            }
        }
        .onDisappear {
            checkInPulseScale = 1.0
            checkInPulseOpacity = 0.45
        }
    }
    
    // 打卡按钮图标视图，便于在不同外观分支中复用
    private var checkInIcon: some View {
        Image("DakaIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            // 图标颜色使用品牌色，固定透明度
            .foregroundStyle(brandColorManager.currentBrandColor)
            // 图标缩放随脉冲在 1.0 → 1.1 之间变化，与外圈脉冲同步
            .scaleEffect(1.0 + (checkInPulseScale - 1.0) * (0.1 / 0.3))
    }
    
    /// 浮动菜单中使用的打卡图标（小号版本），复用与底部按钮一致的颜色与脉冲动画
    private var assistiveCheckInMenuIcon: some View {
        ZStack {
            // 外圈脉冲光晕（缩小版）
            Circle()
                .fill(brandColorManager.currentBrandColor.opacity(0.25))
                .frame(width: 60, height: 60)
                .scaleEffect(checkInPulseScale)
                .opacity(checkInPulseOpacity)
            
            // 中心玻璃按钮（缩小版）
            Group {
                if #available(iOS 26, *) {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 46, height: 46)
                        .glassEffect(.regular, in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.7),
                                            brandColorManager.currentBrandColor.opacity(0.5),
                                            .white.opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.6
                                )
                        )
                        .opacity(0.95)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                        .overlay(checkInIcon)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.6),
                                            brandColorManager.currentBrandColor.opacity(0.4),
                                            .white.opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.6
                                )
                        )
                        .opacity(0.88)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.25),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                        .overlay(checkInIcon)
                }
            }
        }
        // 当仅保留浮动菜单时，在这里启动/重置打卡脉冲动画
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                checkInPulseScale = 1.3
                checkInPulseOpacity = 0.0
            }
        }
        .onDisappear {
            checkInPulseScale = 1.0
            checkInPulseOpacity = 0.45
        }
    }
    
    private var assistiveMenuActions: [AssistiveMenuAction] {
        [
            AssistiveMenuAction(
                id: "footprints",
                icon: "mappin.and.ellipse",
                title: "map_button_footprints".localized,
                isActive: showingFootprintsDrawer,
                action: {
                    showingFootprintsDrawer = true
                }
            ),
            AssistiveMenuAction(
                id: "search",
                icon: "magnifyingglass",
                title: "map_button_search".localized,
                isActive: showSearchBar || !searchText.isEmpty,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSearchBar.toggle()
                        if showSearchBar {
                            // 延迟一点让动画完成后再聚焦
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isSearchFocused = true
                            }
                        } else {
                            searchText = ""
                            searchResults = []
                            isSearchFocused = false
                        }
                    }
                }
            ),
            AssistiveMenuAction(
                id: "style",
                icon: currentMapStyle.iconName,
                title: "map_button_style".localized,
                isActive: showingMapStylePicker,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingMapStylePicker.toggle()
                    }
                }
            ),
            AssistiveMenuAction(
                id: "locate",
                icon: "location.fill",
                title: "map_button_locate".localized,
                isActive: false,
                action: {
                    centerMapOnCurrentLocation()
                }
            ),
            AssistiveMenuAction(
                id: "check_in",
                icon: "DakaIcon",
                title: "map_button_check_in".localized,
                isActive: false,
                action: {
                    handleCheckIn()
                }
            ),
            AssistiveMenuAction(
                id: "memory",
                icon: "PaopaoIcon",
                title: "map_button_memory".localized,
                isActive: false,
                action: {
                    triggerMemoryBubble()
                }
            )
        ]
    }
    
    
    private func menuIcon(for icon: String, isActive: Bool) -> AnyView {
        switch icon {
        case "PaopaoIcon":
            return AnyView(
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundColor(buttonIconColor(isActive: isActive))
                    .frame(width: 22, height: 22)
            )
        case "DakaIcon":
            // 浮动菜单中的打卡按钮使用与底部大按钮一致的玻璃+脉冲视觉
            return AnyView(assistiveCheckInMenuIcon)
        default:
            return AnyView(
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(buttonIconColor(isActive: isActive))
            )
        }
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
    
    // iOS 26标准搜索栏覆盖层
    private var searchBarOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 搜索输入框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15, weight: .medium))
                    
                    TextField(searchPlaceholderText, text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                        .focused($isSearchFocused)
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // 关闭按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSearchBar = false
                        searchText = ""
                        searchResults = []
                        isSearchFocused = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.regularMaterial)
            
            // 搜索结果列表
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(searchResults.prefix(10).enumerated()), id: \.offset) { index, result in
                            SearchResultRow(mapItem: result) {
                                selectSearchResult(result)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showSearchBar = false
                                }
                            }
                            
                            if index < min(9, searchResults.count - 1) {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
                .background(.regularMaterial)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
    
    // “快速打卡”弹窗内容
    @ViewBuilder
    private var quickCheckInSheet: some View {
        if let prefill = addDestinationPrefill {
            QuickCheckInView(prefill: prefill)
        } else if isGeocodingLocation {
            // 快速打卡模式的加载状态
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
            // 快速打卡模式但还没有位置信息，显示简化界面（会显示加载状态）
            QuickCheckInView(prefill: nil)
        }
    }
    
    // 普通“添加目的地”弹窗内容
    @ViewBuilder
    private var addDestinationSheet: some View {
        if let prefill = addDestinationPrefill {
            AddDestinationView(prefill: prefill)
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
            case .world: return 180000     // 180km
            case .country: return 90000    // 90km
            case .province: return 45000   // 45km
            case .city: return 12000       // 12km
            case .district: return 3000    // 3km
            case .street: return 0         // 不聚合
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
        
        // 如果使用增量更新，且路线已经完整计算过，直接返回（避免重复计算）
        // 如果 incremental = false（强制重新计算），则跳过此检查
        if incremental {
        if let existingRoutes = tripRoutes[tripId],
           existingRoutes.count == coordinates.count - 1,
           existingRoutes.allSatisfy({ $0 != nil }) {
            // 路线已完整，无需重新计算
            return
            }
        }
        
        // 初始化路线数组（保持顺序）
        var calculatedRoutes: [MKRoute?] = Array(repeating: nil, count: coordinates.count - 1)
        
        // 如果使用增量更新，先检查缓存
        if incremental {
            for i in 0..<coordinates.count - 1 {
                let source = coordinates[i]
                let destination = coordinates[i + 1]
                
                // 计算两点间的直线距离
                let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
                let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
                let distance = sourceLocation.distance(from: destinationLocation)
                
                if let cachedRoute = routeManager.getCachedRoute(
                    from: source,
                    to: destination
                ) {
                    // 检查缓存的路线是否使用了合适的交通方式
                    // 如果距离≤5公里但使用了机动车模式，说明是旧缓存，需要重新计算
                    let cachedTransportType = cachedRoute.footprintTransportType
                    let shouldUseWalking = distance <= 5_000
                    let isUsingAutomobile = cachedTransportType.contains(.automobile) && cachedTransportType == .automobile
                    
                    if shouldUseWalking && isUsingAutomobile {
                        // 缓存的路线使用了不合适的交通方式，清除缓存并重新计算
                        print("🔄 检测到缓存路线使用了不合适的交通方式（距离\(String(format: "%.1f", distance/1000))km应使用徒步但使用了机动车），清除缓存并重新计算")
                        routeManager.clearRouteCache(from: source, to: destination)
                        // 不添加到 calculatedRoutes，让后续重新计算
                    } else {
                    calculatedRoutes[i] = cachedRoute
                    }
                }
            }
            
            // 如果所有路线都已缓存且都合适，直接更新 UI
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
    
    // 处理长按手势 - 显示地址信息（路名和门牌号）
    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        // 在旅程页面禁用反向地理编码
        if autoShowRouteCards {
            print("⏭️ 旅程页面：已禁用长按反向地理编码")
            return
        }
        
        print("🗺️ 长按地图位置: (\(coordinate.latitude), \(coordinate.longitude))")
        
        // 先关闭之前可能显示的POI预览
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showingPOIPreview = false
            selectedPOI = nil
        }
        
        // 长按时只做反向地理编码，显示地址信息（路名和门牌号），不搜索POI
        showAddressInfoForLongPress(coordinate: coordinate)
    }
    
    // 长按时显示地址信息（路名和门牌号）
    private func showAddressInfoForLongPress(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 使用独立的 geocoder，避免主 geocoder 忙碌时冲突
        let addressGeocoder = CLGeocoder()
        addressGeocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let mkPlacemark = MKPlacemark(placemark: placemark)
                    let mapItem = MKMapItem(placemark: mkPlacemark)
                    
                    // 构建地址名称：优先使用路名+门牌号，不包含POI信息
                    let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
                    let streetName = placemark.thoroughfare ?? ""
                    let streetNumber = placemark.subThoroughfare ?? ""
                    
                    // 长按时只显示地址信息，不显示POI
                    var locationName = ""
                    if !streetName.isEmpty && !streetNumber.isEmpty {
                        locationName = "\(streetName)\(streetNumber)"
                    } else if !streetName.isEmpty {
                        locationName = streetName
                    } else if !streetNumber.isEmpty {
                        locationName = streetNumber
                    } else {
                        // 如果没有路名和门牌号，使用城市名
                        locationName = cityName
                    }
                    
                    mapItem.name = locationName
                    
                    print("✅ 长按反向地理编码成功: \(locationName)")
                    if !streetName.isEmpty {
                        print("   路名: \(streetName)")
                    }
                    if !streetNumber.isEmpty {
                        print("   门牌号: \(streetNumber)")
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        self.selectedPOI = mapItem
                        self.showingPOIPreview = true
                    }
                } else {
                    let errorDescription = error?.localizedDescription ?? "未知错误"
                    print("❌ 长按反向地理编码失败: \(errorDescription)")
                    // 失败时显示坐标信息
                    let mkPlacemark = MKPlacemark(coordinate: coordinate)
                    let mapItem = MKMapItem(placemark: mkPlacemark)
                    mapItem.name = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        self.selectedPOI = mapItem
                        self.showingPOIPreview = true
                    }
                }
            }
        }
    }
    
    // 处理POI添加目的地 - 打开快速打卡弹窗
    private func handlePOIAddDestination(poi: MKMapItem) {
        // 关闭POI预览
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showingPOIPreview = false
            selectedPOI = nil
        }
        
        // 提取POI信息
        let placemark = poi.placemark
        let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
        let streetName = placemark.thoroughfare ?? ""
        let streetNumber = placemark.subThoroughfare ?? ""
        let poiName = poi.name ?? placemark.areasOfInterest?.first ?? ""
        
        // 构建地点名称：优先使用POI名称
        let locationName = buildLocationName(
            poi: poiName,
            city: cityName,
            street: streetName,
            streetNumber: streetNumber
        )
        
        let countryName = placemark.country ?? "unknown_country".localized
        let isoCountryCode = placemark.isoCountryCode ?? ""
        let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
        
        // 设置预填充数据并显示快速打卡界面
        isWaitingForLocation = false
        pendingPhotoPrefill = nil
        updateAddDestinationPrefill(
            mapItem: poi,
            name: locationName,
            country: countryName,
            category: category
        )
        showingQuickCheckIn = true
    }
    
    // 处理打卡功能：使用用户当前位置添加目的地
    private func handleCheckIn() {
        print("📍 点击打卡按钮")
        checkInFeedbackGenerator.impactOccurred()
        
        // 检查是否有已知位置
        if let userLocation = locationManager.lastKnownLocation {
            print("✅ 使用已知位置进行打卡: (\(userLocation.latitude), \(userLocation.longitude))")
            
            // 在下一帧显示添加目的地界面，避免第一次呈现时使用旧的模式状态
            DispatchQueue.main.async {
                self.showingQuickCheckIn = true
            }
            
            // 执行反向地理编码
            reverseGeocodeLocation(coordinate: userLocation)
        } else {
            // 如果没有位置信息，先请求定位
            print("⏳ 没有已知位置，请求定位中...")
            
            // 在下一帧显示添加目的地界面，显示加载状态，确保使用快速打卡模式
            DispatchQueue.main.async {
                self.showingQuickCheckIn = true
            }
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
        print("❌ 无法获取当前位置，显示快速打卡界面（用户可手动输入位置）")
        
        // 即使无法获取位置，也显示快速打卡界面，用户可以手动搜索位置
        // 不关闭弹窗，让用户可以在快速打卡界面中手动搜索位置
        // showingAddDestination 保持为 true，会显示 QuickCheckInView(prefill: nil)
    }
    
    private func updateAddDestinationPrefill(
        mapItem: MKMapItem,
        name: String,
        country: String,
        category: String
    ) {
        // 提取省份信息（对于中国直辖市，会将其名称作为省份）
        let province = CountryManager.extractProvince(
            administrativeArea: mapItem.placemark.administrativeArea,
            locality: mapItem.placemark.locality,
            country: country,
            isoCountryCode: mapItem.placemark.isoCountryCode
        )
        
        var prefill = AddDestinationPrefill(
            location: mapItem,
            name: name,
            country: country,
            province: province,
            category: category
        )
        if let pending = pendingPhotoPrefill {
            prefill.visitDate = pending.visitDate
            prefill.photoDatas = [pending.photoData]
            prefill.photoThumbnailDatas = [pending.thumbnailData]
            pendingPhotoPrefill = nil
        }
        addDestinationPrefill = prefill
    }
    
    // 构建地点名称：优先使用 POI，否则使用"城市+街道+门牌号"
    private func buildLocationName(poi: String, city: String, street: String, streetNumber: String) -> String {
        // 优先级1：使用 POI（如果存在）
        if !poi.isEmpty {
            return poi
        }
        
        // 优先级2：组合"城市+街道+门牌号"
        // 判断是否为中文环境（通过检查城市名是否包含中文字符）
        let isChinese = city.contains(where: { "\u{4E00}" <= $0 && $0 <= "\u{9FFF}" }) ||
                       street.contains(where: { "\u{4E00}" <= $0 && $0 <= "\u{9FFF}" })
        
        var addressParts: [String] = []
        
        if isChinese {
            // 中文格式：城市 + 街道 + 门牌号（如"北京市建国路88号"）
            addressParts.append(city)
            if !street.isEmpty {
                addressParts.append(street)
            }
            if !streetNumber.isEmpty {
                addressParts.append(streetNumber)
            }
            
            // 如果有多个部分，组合它们；否则只返回城市
            if addressParts.count > 1 {
                return addressParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            }
            return city
        } else {
            // 英文格式：门牌号 + 街道, 城市（如"123 Main Street, New York"）
            if !streetNumber.isEmpty {
                addressParts.append(streetNumber)
            }
            if !street.isEmpty {
                addressParts.append(street)
            }
            
            // 如果有街道信息，组合成"门牌号 街道, 城市"格式
            if !addressParts.isEmpty {
                let streetPart = addressParts.joined(separator: " ")
                return "\(streetPart), \(city)"
            }
            
            // 如果没有街道信息，只返回城市
            return city
        }
    }
    
    private func tryUseCachedPlacemark(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard let cachedPlacemark = lastReverseGeocodePlacemark,
              let cachedCoordinate = lastReverseGeocodeCoordinate,
              let cachedTime = lastReverseGeocodeTimestamp else {
            return false
        }
        
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let cachedLocation = CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude)
        let distance = currentLocation.distance(from: cachedLocation)
        let isFresh = Date().timeIntervalSince(cachedTime) < cachedPlacemarkTTL
        
        if distance < cachedPlacemarkReuseDistance && isFresh {
            applyGeocodeResult(cachedPlacemark, coordinate: coordinate, source: .cached)
            print("♻️ 直接复用缓存的地理编码结果，距离 \(Int(distance))m，缓存时间 \(Int(Date().timeIntervalSince(cachedTime)))s")
            return true
        }
        return false
    }
    
    private func applyGeocodeResult(_ placemark: CLPlacemark, coordinate: CLLocationCoordinate2D, source: GeocodeResultSource = .live) {
        geocodeTimeoutTimer?.invalidate()
        geocodeTimeoutTimer = nil
        pendingGeocodeCoordinate = nil
        isGeocodingLocation = false
        lastReverseGeocodePlacemark = placemark
        lastReverseGeocodeCoordinate = coordinate
        lastReverseGeocodeTimestamp = Date()
        if let accuracy = locationManager.lastLocationAccuracy {
            lastGeocodedAccuracy = accuracy
        }
        
        let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
        let streetName = placemark.thoroughfare ?? ""
        let streetNumber = placemark.subThoroughfare ?? ""
        let poi = placemark.areasOfInterest?.first ?? ""
        let locationName = buildLocationName(
            poi: poi,
            city: cityName,
            street: streetName,
            streetNumber: streetNumber
        )
        
        let countryName = placemark.country ?? "unknown_country".localized
        let isoCountryCode = placemark.isoCountryCode ?? ""
        let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
        
        print("✅ 反向地理编码成功(\(source == .cached ? "缓存" : "实时")):")
        print("   地点名称: \(locationName)")
        if !poi.isEmpty {
            print("   POI: \(poi)")
        }
        print("   城市: \(cityName)")
        if !streetName.isEmpty {
            print("   街道: \(streetName)")
        }
        if !streetNumber.isEmpty {
            print("   门牌号: \(streetNumber)")
        }
        print("   国家: \(countryName)")
        print("   ISO代码: \(isoCountryCode)")
        print("   分类: \(category)")
        
        let mkPlacemark = MKPlacemark(placemark: placemark)
        let mapItem = MKMapItem(placemark: mkPlacemark)
        mapItem.name = locationName
        updateAddDestinationPrefill(
            mapItem: mapItem,
            name: locationName,
            country: countryName,
            category: category
        )
    }
    
    // 反向地理编码：获取城市和国家信息（带多重回退和优化）
    private func reverseGeocodeLocation(coordinate: CLLocationCoordinate2D, force: Bool = false) {
        // 0. 检查节流状态
        if isThrottled, let resetTime = throttleResetTime {
            let timeUntilReset = resetTime.timeIntervalSinceNow
            if timeUntilReset > 0 {
                print("⏸️ 反向地理编码被节流，\(Int(timeUntilReset)) 秒内不再发起新请求")
                return
            } else {
                // 节流时间已过，重置状态
                isThrottled = false
                throttleResetTime = nil
            }
        }
        
        if !force, tryUseCachedPlacemark(for: coordinate) {
            return
        }
        
        // 1. 请求去重：如果正在处理相同或非常接近的坐标，忽略新请求
        if !force, let pendingCoord = pendingGeocodeCoordinate {
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: CLLocation(latitude: pendingCoord.latitude, longitude: pendingCoord.longitude))
            if distance < 10.0 { // 10米内的重复请求
                print("⚠️ 忽略重复的地理编码请求（距离: \(String(format: "%.1f", distance))米）")
                return
            }
        }
        
        // 2. 防抖：如果距离上次请求太近（启动阶段2秒，正常1秒），延迟执行
        let debounceInterval: TimeInterval = (viewAppearTime.map { Date().timeIntervalSince($0) < 30.0 } ?? false) ? 2.0 : 1.0
        if !force,
           let lastTime = lastGeocodeTime,
           Date().timeIntervalSince(lastTime) < debounceInterval {
            print("⏳ 地理编码请求过于频繁，延迟执行")
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval) {
                self.reverseGeocodeLocation(coordinate: coordinate, force: force)
            }
            return
        }
        
        // 3. 确保 geocoder 已初始化
        guard let geocoder = geocoder else {
            print("⏳ Geocoder 尚未初始化，延迟执行")
            // 如果 geocoder 还没初始化，先初始化它
            self.geocoder = CLGeocoder()
            // 延迟一小段时间后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.reverseGeocodeLocation(coordinate: coordinate, force: force)
            }
            return
        }
        
        // 4. 检查 geocoder 是否正在处理请求
        if geocoder.isGeocoding {
            print("⚠️ Geocoder 正在处理其他请求，稍后重试")
            // 取消当前请求，使用新坐标
            geocoder.cancelGeocode()
            // 等待一小段时间后重试
            let delay: TimeInterval = force ? 0.1 : 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.reverseGeocodeLocation(coordinate: coordinate, force: force)
            }
            return
        }
        
        // 5. 记录待处理的坐标
        pendingGeocodeCoordinate = coordinate
        lastGeocodeTime = Date()
        isGeocodingLocation = true
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 6. 设置超时处理（10秒）
        geocodeTimeoutTimer?.invalidate()
        geocodeTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("⏰ 地理编码超时，尝试备用方案")
            isGeocodingLocation = false
            pendingGeocodeCoordinate = nil
            geocodeTimeoutTimer = nil
            // 使用备用搜索
            fallbackSearchAround(coordinate: coordinate)
        }

        func handleError(_ error: Error?) {
            // 取消超时定时器
            geocodeTimeoutTimer?.invalidate()
            geocodeTimeoutTimer = nil
            
            let errorDescription = error?.localizedDescription ?? "未知错误"
            print("❌ 反向地理编码失败: \(errorDescription)")
            
            // 检查是否是网络错误、服务不可用或节流错误
            if let nsError = error as NSError? {
                let errorCode = nsError.code
                let errorDomain = nsError.domain
                
                // 检查是否是节流错误（GEOErrorDomain Code=-3）
                if errorDomain == "GEOErrorDomain" && errorCode == -3 {
                    print("⚠️ 反向地理编码被节流（请求过于频繁）")
                    
                    // 从错误信息中提取重置时间
                    var resetTime: TimeInterval = 20.0 // 默认20秒
                    if let userInfo = nsError.userInfo as? [String: Any],
                       let timeUntilReset = userInfo["timeUntilReset"] as? TimeInterval {
                        resetTime = timeUntilReset
                    }
                    
                    // 设置节流状态
                    isThrottled = true
                    throttleResetTime = Date().addingTimeInterval(resetTime)
                    
                    print("⏸️ 节流将在 \(Int(resetTime)) 秒后重置，本次及冷静期内不再自动重试")
                    return
                }
                
                // CLError 错误码
                if errorCode == 2 { // kCLErrorNetwork
                    print("⚠️ 网络错误，稍后重试")
                    // 网络错误时，延迟重试
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.reverseGeocodeLocation(coordinate: coordinate, force: force)
                    }
                    return
                }
            }
            
            // 其他错误，尝试备用方案
            failoverToAlternateLocales()
        }

        func failoverToAlternateLocales() {
            // 优先尝试英文，再尝试中文，提升国外/国内识别成功率
            geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "en_US")) { placemarks, _ in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        self.applyGeocodeResult(placemark, coordinate: coordinate)
                    }
                    return
                }
                geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN")) { placemarks, _ in
                    if let placemark = placemarks?.first {
                        DispatchQueue.main.async {
                            self.applyGeocodeResult(placemark, coordinate: coordinate)
                        }
                        return
                    }
                    // 继续回退到附近搜索
                    DispatchQueue.main.async {
                        pendingGeocodeCoordinate = nil
                        isGeocodingLocation = false
                        fallbackSearchAround(coordinate: coordinate)
                    }
                }
            }
        }

        // 7. 执行地理编码请求
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.applyGeocodeResult(placemark, coordinate: coordinate)
                }
                return
            }
            DispatchQueue.main.async { handleError(error) }
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
                // 提取详细地址信息
                let cityName = item.placemark.locality ?? item.placemark.administrativeArea ?? "unknown_city".localized
                let streetName = item.placemark.thoroughfare ?? ""
                let streetNumber = item.placemark.subThoroughfare ?? ""
                // 优先使用 mapItem.name（可能是 POI），否则使用 areasOfInterest
                let poi = item.name ?? item.placemark.areasOfInterest?.first ?? ""
                
                // 构建地点名称：优先使用 POI，否则使用"城市+街道+门牌号"
                let locationName = self.buildLocationName(
                    poi: poi,
                    city: cityName,
                    street: streetName,
                    streetNumber: streetNumber
                )
                
                let countryName = item.placemark.country ?? "unknown_country".localized
                let isoCountryCode = item.placemark.isoCountryCode ?? ""
                let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
                
                print("✅ 附近搜索成功:")
                print("   地点名称: \(locationName)")
                if !poi.isEmpty {
                    print("   POI: \(poi)")
                }
                print("   城市: \(cityName)")
                if !streetName.isEmpty {
                    print("   街道: \(streetName)")
                }
                if !streetNumber.isEmpty {
                    print("   门牌号: \(streetNumber)")
                }
                print("   国家: \(countryName)")
                
                let mapItem = item
                mapItem.name = locationName
                DispatchQueue.main.async {
                    self.isGeocodingLocation = false
                    self.updateAddDestinationPrefill(
                        mapItem: mapItem,
                        name: locationName,
                        country: countryName,
                        category: category
                    )
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
        updateAddDestinationPrefill(
            mapItem: mapItem,
            name: cityName,
            country: countryName,
            category: category
        )
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
    
    private func handlePhotoImportSelection(_ item: PhotosPickerItem) {
        Task {
            print("📸 开始处理图片导入...")
            
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                print("❌ 图片加载失败：无法从 PhotosPickerItem 获取数据")
                await MainActor.run {
                    photoImportError = .failedToLoad
                    showingAddDestination = false
                    pendingPhotoPrefill = nil
                    photoImportItem = nil
                    showingPhotoImportPicker = false
                }
                return
            }
            
            print("✅ 图片数据加载成功，大小: \(data.count / 1024) KB")
            
            let processed = ImageProcessor.process(data: data)
            let metadata = extractMetadata(for: item, imageData: data)
            
            await MainActor.run {
                photoImportItem = nil
                showingPhotoImportPicker = false
                
                if let wgsCoordinate = metadata.coordinate {
                    // 📍 关键修复：iPhone 拍摄的照片 GPS 信息是 WGS84 坐标系
                    // 在中国境内需要转换为 GCJ02（火星坐标）才能准确定位
                    let isInChina = !CoordinateConverter.isOutOfChina(wgsCoordinate)
                    let finalCoordinate: CLLocationCoordinate2D
                    
                    if isInChina {
                        finalCoordinate = CoordinateConverter.wgs84ToGCJ02(wgsCoordinate)
                        print("📍 坐标转换（中国境内）:")
                        print("   WGS84: (\(String(format: "%.6f", wgsCoordinate.latitude)), \(String(format: "%.6f", wgsCoordinate.longitude)))")
                        print("   GCJ02: (\(String(format: "%.6f", finalCoordinate.latitude)), \(String(format: "%.6f", finalCoordinate.longitude)))")
                    } else {
                        finalCoordinate = wgsCoordinate
                        print("📍 坐标（境外，无需转换）: (\(String(format: "%.6f", finalCoordinate.latitude)), \(String(format: "%.6f", finalCoordinate.longitude)))")
                    }
                    
                    if let captureDate = metadata.captureDate {
                        print("📅 拍摄日期: \(captureDate)")
                    } else {
                        print("⚠️ 未找到拍摄日期")
                    }
                    
                    pendingPhotoPrefill = PendingPhotoPrefill(
                        visitDate: metadata.captureDate,
                        photoData: processed.0,
                        thumbnailData: processed.1
                    )
                    photoImportError = nil
                    showingAddDestination = true
                    addDestinationPrefill = nil
                    
                    print("🔄 开始逆地理编码...")
                    reverseGeocodeLocation(coordinate: finalCoordinate)
                } else {
                    print("⚠️ 图片中未找到 GPS 坐标信息")
                    if let captureDate = metadata.captureDate {
                        print("📅 拍摄日期: \(captureDate)")
                    }
                    
                    pendingPhotoPrefill = nil
                    addDestinationPrefill = AddDestinationPrefill(
                        visitDate: metadata.captureDate,
                        photoDatas: [processed.0],
                        photoThumbnailDatas: [processed.1]
                    )
                    isGeocodingLocation = false
                    showingAddDestination = true
                    photoImportError = .missingLocation
                }
            }
        }
    }
    
    private func extractMetadata(for item: PhotosPickerItem, imageData: Data) -> PhotoMetadata {
        var coordinate: CLLocationCoordinate2D?
        var captureDate: Date?
        
        // 方法1：从 PHAsset 获取元数据（优先）
        if let identifier = item.itemIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = assets.firstObject {
                captureDate = asset.creationDate ?? asset.modificationDate
                if let location = asset.location {
                    coordinate = location.coordinate
                    print("✅ 从 PHAsset 获取坐标: (\(String(format: "%.6f", coordinate!.latitude)), \(String(format: "%.6f", coordinate!.longitude)))")
                } else {
                    print("⚠️ PHAsset 中未找到位置信息")
                }
                if captureDate != nil {
                    print("✅ 从 PHAsset 获取拍摄日期: \(captureDate!)")
                } else {
                    print("⚠️ PHAsset 中未找到拍摄日期")
                }
            } else {
                print("⚠️ 无法找到对应的 PHAsset")
            }
        }
        
        // 方法2：从图片 EXIF 数据获取元数据（备用）
        if coordinate == nil || captureDate == nil {
            if let source = CGImageSourceCreateWithData(imageData as CFData, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                
                // 提取 GPS 坐标
                if coordinate == nil,
                   let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
                   let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
                   let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
                   let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
                   let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                    let latRef = latitudeRef.uppercased()
                    let lonRef = longitudeRef.uppercased()
                    let lat = latRef == "S" ? -latitude : latitude
                    let lon = lonRef == "W" ? -longitude : longitude
                    coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    print("✅ 从 EXIF GPS 获取坐标: (\(String(format: "%.6f", lat)), \(String(format: "%.6f", lon)))")
                } else if coordinate == nil {
                    print("⚠️ EXIF 中未找到 GPS 信息")
                }
                
                // 提取拍摄日期
                if captureDate == nil {
                    if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
                       let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                        captureDate = parseExifDateString(dateString)
                        if captureDate != nil {
                            print("✅ 从 EXIF DateTimeOriginal 获取拍摄日期: \(captureDate!)")
                        }
                    }
                    if captureDate == nil,
                       let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                       let dateString = tiff[kCGImagePropertyTIFFDateTime] as? String {
                        captureDate = parseExifDateString(dateString)
                        if captureDate != nil {
                            print("✅ 从 TIFF DateTime 获取拍摄日期: \(captureDate!)")
                        }
                    }
                    if captureDate == nil {
                        print("⚠️ EXIF/TIFF 中未找到拍摄日期")
                    }
                }
            } else {
                print("⚠️ 无法读取图片 EXIF 数据")
            }
        }
        
        return PhotoMetadata(coordinate: coordinate, captureDate: captureDate)
    }
    
    private func parseExifDateString(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let patterns = ["yyyy:MM:dd HH:mm:ss", "yyyy:MM:dd HH:mm:ssZ"]
        for pattern in patterns {
            formatter.dateFormat = pattern
            if pattern.hasSuffix("Z") {
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
            } else {
                formatter.timeZone = TimeZone.current
            }
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
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
        GeometryReader { geometry in
            ZStack {
                // 吹出肥皂泡泡动画 - 从地点上方吹出
                if showSoapBubbles, let destination = selectedBubbleDestination {
                    // 计算地点在地图上的屏幕坐标
                    let screenPoint = convertCoordinateToScreenPoint(destination.coordinate, in: geometry.size)
                    
                    // 从地点上方（向上偏移约80点）吹出肥皂泡泡
                    let bubbleStartPosition = CGPoint(
                        x: screenPoint.x,
                        y: screenPoint.y - 80 // 地点上方
                    )
                    
                    SoapBubblesView(
                        position: bubbleStartPosition,
                        direction: .pi / 2, // 主要向上吹
                        spreadAngle: .pi / 3, // 约60度扩散角度，向上飘散，带有轻微摆动
                        isDarkMapStyle: isDarkMapStyle, // 传递地图样式信息，用于调整泡泡对比度
                        onPlaySound: { soundType in
                            // 在泡泡动画过程中播放音效，根据类型播放不同音效
                            // 使用3种不同的音效变体，营造Q弹感和层次感
                            switch soundType {
                            case 0:
                                playBubblePopSound1() // 气泡音效
                            case 1:
                                playBubblePopSound2() // 轻微点击音效
                            case 2:
                                playBubblePopSound3() // 消息接收音效
                            default:
                                playBubblePopSound1()
                            }
                        },
                        onComplete: {
                            showSoapBubbles = false
                            selectedBubbleDestination = nil
                        }
                    )
                    .id(soapBubblesID) // 使用 ID 确保每次创建新实例
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false) // 不阻挡其他交互
                    .zIndex(1000) // 确保在最上层
                }
            }
        }
        .allowsHitTesting(true)
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
        
        // 播放音效
        playBubbleSound()
        
        // 设置目标地点，开始等待地图到达
        targetBubbleDestination = randomDestination
        waitingForMapToReachDestination = true
        
        // 直接 Zoom in 到地点（使用较小的视野范围，约10km）
        let zoomRegion = MKCoordinateRegion(
            center: randomDestination.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09) // 约10km视野
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            mapCameraPosition = .region(zoomRegion)
        }
        
        print("🫧 地图 Zoom in 到地点: \(randomDestination.name)")
        print("🫧 等待地图到达地点后吹出肥皂泡泡...")
        
        // 设置超时保护：如果5秒后还没到达，强制触发（防止卡死）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if waitingForMapToReachDestination {
                print("🫧 超时保护：强制触发肥皂泡泡动画")
                self.checkAndTriggerBubbles()
            }
        }
    }
    
    // 检查地图是否已到达目标地点，如果到达则触发肥皂泡泡
    private func checkAndTriggerBubbles() {
        guard waitingForMapToReachDestination,
              let target = targetBubbleDestination,
              let currentRegion = visibleRegion else {
            return
        }
        
        // 计算目标地点与当前视野中心的距离
        let targetCoord = target.coordinate
        let centerCoord = currentRegion.center
        
        // 计算距离（使用简单的经纬度差值，约111km/度）
        let latDiff = abs(targetCoord.latitude - centerCoord.latitude)
        let lonDiff = abs(targetCoord.longitude - centerCoord.longitude)
        
        // 检查是否在视野范围内（允许一些误差，约1km）
        let latSpan = currentRegion.span.latitudeDelta
        let lonSpan = currentRegion.span.longitudeDelta
        
        // 如果地点在视野中心附近（距离中心小于视野范围的20%），认为已到达
        let isNearCenter = latDiff < latSpan * 0.2 && lonDiff < lonSpan * 0.2
        
        if isNearCenter {
            print("🫧 地图已到达地点，触发肥皂泡泡动画")
            waitingForMapToReachDestination = false
            targetBubbleDestination = nil
            
            // 触发肥皂泡泡动画
            selectedBubbleDestination = target
            showSoapBubbles = true
            soapBubblesID = UUID()
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
    
    // 播放轻泡泡音效（用于动画过程中）
    private func playLightBubbleSound() {
        // 使用较轻的系统音效（音量较低，用于连续播放）
        // 使用音效 1103 (轻微点击) 或 1104 (气泡)，但音量较低
        AudioServicesPlaySystemSound(1103) // 轻微点击音效，较轻
    }
    
    // 播放Q弹泡泡音效（变体1）
    private func playBubblePopSound1() {
        AudioServicesPlaySystemSound(1104) // 气泡音效
    }
    
    // 播放Q弹泡泡音效（变体2）
    private func playBubblePopSound2() {
        AudioServicesPlaySystemSound(1103) // 轻微点击音效
    }
    
    // 播放Q弹泡泡音效（变体3）
    private func playBubblePopSound3() {
        AudioServicesPlaySystemSound(1057) // 消息接收音效（较轻的提示音）
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
                    return
                }
                
                self.searchResults = response?.mapItems ?? []
                
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // 确保整个矩形区域都可以点击
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
    let accentColor: Color
    let weatherSummary: WeatherSummary?
    
    // 实现 Equatable 协议以减少不必要的视图更新
    static func == (lhs: ClusterAnnotationView, rhs: ClusterAnnotationView) -> Bool {
        lhs.cluster.id == rhs.cluster.id &&
        abs(lhs.zoomLevel - rhs.zoomLevel) < 0.5 &&
        lhs.accentColorSignature == rhs.accentColorSignature &&
        lhs.weatherSummary == rhs.weatherSummary // 品牌色或天气变化时需要刷新
    }
    
    private var markerSize: CGFloat {
        let zoom = zoomLevel
        // 世界 / 国家使用最小标记，省 / 市保持中等大小，区 / 街道使用较大标记
        if zoom < 6 {
            return 10   // world、country
        } else if zoom < 10 {
            return 20   // province、city
        } else {
            return 40   // district、street
        }
    }
    
    private var strokeWidth: CGFloat {
        cluster.destinations.count == 1 ? 2 : 2.5
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
    
    private var accentColorSignature: String {
        UIColor(accentColor).description
    }
    
    var body: some View {
        VStack(spacing: 6) {
            if shouldDisplayWeatherBadge, let summary = weatherSummary {
                WeatherBadgeView(summary: summary)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
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
                    if markerSize > 20 {
                        if let photoData = destination.photoData,
                           let uiImage = UIImage(data: photoData) {
                            // 有照片：使用用户照片作为标记
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
                            // 无照片：使用内置形象图 ImageMooyu 作为标记
                            Image("ImageMooyu")
                                .resizable()
                                .interpolation(.high)  // 高质量插值，确保边缘光滑
                                .antialiased(true)     // 启用抗锯齿
                                .scaledToFill()
                                .frame(width: markerSize, height: markerSize)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: strokeWidth)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    } else {
                        // 液态玻璃标注（统一使用品牌红色）
                        LiquidGlassMarkerView(
                            size: markerSize,
                            startColor: accentColor,
                            endColor: accentColor,
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
                    // 聚合地点：使用液态玻璃标注（统一使用品牌红色）
                    ZStack {
                        LiquidGlassMarkerView(
                            size: markerSize,
                            startColor: accentColor,
                            endColor: accentColor,
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

    private var shouldDisplayWeatherBadge: Bool {
        markerSize >= 40 && cluster.destinations.count == 1 && weatherSummary != nil
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
    // 计算路线多边形的中点坐标（按距离计算，而不是简单的点索引）
    func midpointOfPolyline(_ polyline: MKPolyline) -> CLLocationCoordinate2D? {
        let pointCount = polyline.pointCount
        guard pointCount > 0 else { return nil }
        
        // 如果只有两个点（如飞机模式的直线），直接计算两点中点
        if pointCount == 2 {
            let points = polyline.points()
            let start = points[0].coordinate
            let end = points[1].coordinate
            return midpointOfLine(from: start, to: end)
        }
        
        // 对于多点路线，计算总距离，然后找到中点位置
        let points = polyline.points()
        var totalDistance: CLLocationDistance = 0
        var segmentDistances: [CLLocationDistance] = []
        
        // 计算每段的距离和总距离
        for i in 0..<pointCount - 1 {
            let start = CLLocation(latitude: points[i].coordinate.latitude, longitude: points[i].coordinate.longitude)
            let end = CLLocation(latitude: points[i + 1].coordinate.latitude, longitude: points[i + 1].coordinate.longitude)
            let segmentDistance = start.distance(from: end)
            segmentDistances.append(segmentDistance)
            totalDistance += segmentDistance
        }
        
        // 找到中点位置（总距离的一半）
        let halfDistance = totalDistance / 2
        var accumulatedDistance: CLLocationDistance = 0
        
        for i in 0..<segmentDistances.count {
            let segmentDistance = segmentDistances[i]
            if accumulatedDistance + segmentDistance >= halfDistance {
                // 中点在这个段内
                let remainingDistance = halfDistance - accumulatedDistance
                let ratio = remainingDistance / segmentDistance
                
                let start = points[i].coordinate
                let end = points[i + 1].coordinate
                
                // 在起点和终点之间按比例插值
                return CLLocationCoordinate2D(
                    latitude: start.latitude + (end.latitude - start.latitude) * ratio,
                    longitude: start.longitude + (end.longitude - start.longitude) * ratio
                )
            }
            accumulatedDistance += segmentDistance
        }
        
        // 如果没找到（理论上不应该发生），返回中间点
        let midIndex = pointCount / 2
        guard midIndex < pointCount else { return nil }
        return points[midIndex].coordinate
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
    
    // 计算占位线应该显示的交通方式
    private func calculatePlaceholderTransportType(
        from source: TravelDestination,
        to destination: TravelDestination
    ) -> MKDirectionsTransportType {
        // 获取用户选择的交通方式，如果没有则使用自动选择的逻辑
        let userTransportType = routeManager.getUserTransportType(
            from: source.coordinate,
            to: destination.coordinate
        )
        
        // 确定显示的交通方式：优先使用用户选择，否则根据距离智能选择
        if let userType = userTransportType {
            return userType
        } else {
            // 自动选择逻辑：近距离步行，远距离机动车
            let distance = source.coordinate.distance(to: destination.coordinate)
            if distance <= 5_000 {
                return .walking
            } else {
                return .automobile
            }
        }
    }
    
    // 占位线绘制视图（提取复杂逻辑，避免类型检查超时）
    @MapContentBuilder
    private func placeholderRouteContent(
        for source: TravelDestination,
        destination: TravelDestination,
        transportType: MKDirectionsTransportType,
        tripId: UUID,
        visibleDestinations: [TravelDestination]
    ) -> some MapContent {
        // 根据交通方式选择虚线颜色
        let placeholderColor = routeColor(for: transportType)
        
        // 计算直线距离
        let distance = source.coordinate.distance(to: destination.coordinate)
        
        // 绘制虚线（更细的线条，更短的虚线间隔）
        MapPolyline(coordinates: [source.coordinate, destination.coordinate])
            .stroke(placeholderColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [3, 2]))
        
        // 显示直线距离标注（带交通方式选择，显示用户选择的交通方式图标）
        if let midpoint = midpointOfLine(from: source.coordinate, to: destination.coordinate) {
            Annotation("", coordinate: midpoint) {
                RouteDistanceLabel(
                    distance: distance,
                    transportType: transportType, // 显示用户选择的交通方式图标
                    source: source.coordinate,
                    destination: destination.coordinate,
                    onTransportTypeChange: { newType in
                        // 保存用户选择并重新计算路线
                        routeManager.setUserTransportType(
                            from: source.coordinate,
                            to: destination.coordinate,
                            transportType: newType
                        )
                        // 清除该旅程的路线缓存，强制重新计算
                        tripRoutes.removeValue(forKey: tripId)
                        // 重新计算该旅程的路线
                        let coordinates = visibleDestinations.map { $0.coordinate }
                        Task {
                            await calculateRoutesForTrip(tripId: tripId, coordinates: coordinates, incremental: false)
                        }
                    }
                )
            }
        }
    }
}

// 路线距离标签视图（带交通方式选择）
struct RouteDistanceLabel: View {
    let distance: CLLocationDistance
    let transportType: MKDirectionsTransportType
    let source: CLLocationCoordinate2D?
    let destination: CLLocationCoordinate2D?
    let onTransportTypeChange: ((MKDirectionsTransportType?) -> Void)?
    
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var routeManager = RouteManager.shared
    
    // 兼容旧版本：不传递交通方式信息时使用
    init(distance: CLLocationDistance) {
        self.distance = distance
        self.transportType = .automobile
        self.source = nil
        self.destination = nil
        self.onTransportTypeChange = nil
    }
    
    // 新版本：包含交通方式信息
    init(
        distance: CLLocationDistance,
        transportType: MKDirectionsTransportType,
        source: CLLocationCoordinate2D? = nil,
        destination: CLLocationCoordinate2D? = nil,
        onTransportTypeChange: ((MKDirectionsTransportType?) -> Void)? = nil
    ) {
        self.distance = distance
        self.transportType = transportType
        self.source = source
        self.destination = destination
        self.onTransportTypeChange = onTransportTypeChange
    }
    
    var body: some View {
        // 如果有回调，将整个标签包装在 Menu 中，使整个标签都可以点击
        if let source = source, let destination = destination, let onChange = onTransportTypeChange {
            Menu {
                Button {
                    onChange(nil) // 恢复自动选择
                } label: {
                    Label {
                        Text("auto_select".localized)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
                
                Divider()
                
                Button {
                    onChange(.walking)
                } label: {
                    Label {
                        Text("walking".localized)
                    } icon: {
                        Image(systemName: "figure.walk")
                    }
                }
                
                Button {
                    onChange(.automobile)
                } label: {
                    Label {
                        Text("automobile".localized)
                    } icon: {
                        Image(systemName: "car.fill")
                    }
                }
                
                Button {
                    onChange(.transit)
                } label: {
                    Label {
                        Text("transit".localized)
                    } icon: {
                        Image(systemName: "tram.fill")
                    }
                }
                
                Button {
                    onChange(RouteManager.airplane)
                } label: {
                    Label {
                        Text("airplane".localized)
                    } icon: {
                        Image(systemName: "airplane")
                    }
                }
            } label: {
                // 整个标签作为 Menu 的 label，使整个标签都可以点击
                HStack(spacing: 4) {
                    // 交通方式图标
                    Image(systemName: transportType.iconName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(transportColor(for: transportType))
                        .frame(width: 14, height: 14)
                    
                    // 距离文本
                    Text(formatDistance(distance))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
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
            .menuStyle(.borderlessButton) // 使用无边框按钮样式，确保点击响应
        } else {
            // 只显示标签，不可点击
            HStack(spacing: 4) {
                // 交通方式图标
                Image(systemName: transportType.iconName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(transportColor(for: transportType))
                    .frame(width: 14, height: 14)
                
                // 距离文本
                Text(formatDistance(distance))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
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
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
    
    private func transportColor(for type: MKDirectionsTransportType) -> Color {
        if type == RouteManager.airplane {
            return .orange // 飞机使用橙色
        } else if type.contains(.walking) && type == .walking {
            return .green
        } else if type.contains(.automobile) && type == .automobile {
            return .blue
        } else if type.contains(.transit) && type == .transit {
            return .purple
        } else {
            return .gray
        }
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
    let onOpenDetail: () -> Void
    @State private var shareItem: TripShareItem?
    @State private var showingSelectTrip = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            photoThumbnail
            
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
                
                HStack(spacing: 4) {
                    if !destination.province.isEmpty {
                        Text(destination.province)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(destination.country)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
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
            
            Spacer(minLength: 12)
            
            // 按钮组 - 2x2布局
            VStack(spacing: 8) {
                // 第一行：分享和喜欢按钮
                HStack(spacing: 8) {
                    // 分享按钮
                    Button {
                        shareDestination()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(
                                Circle().fill(Color.white.opacity(0.5))
                            )
                    }
                    
                    // 喜爱按钮
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: destination.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(destination.isFavorite ? .red : .black)
                            .padding(10)
                            .background(
                                Circle().fill(Color.white.opacity(0.5))
                            )
                    }
                }
                
                // 第二行：创建/添加旅程按钮
                HStack(spacing: 8) {
                    // 创建/添加旅程按钮
                    Button {
                        showingSelectTrip = true
                    } label: {
                        Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.filled.scurvepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(
                                Circle().fill(Color.white.opacity(0.5))
                            )
                    }
                    
                    // 占位，保持布局对称
                    Spacer()
                        .frame(width: 36, height: 36)
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
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                SystemShareSheet(items: [image])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .sheet(isPresented: $showingSelectTrip) {
            SelectOrCreateTripView(destination: destination)
        }
    }
    
    private var photoThumbnail: some View {
        Group {
            if let photoData = destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("ImageMooyu")
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)  // 高质量插值，确保边缘光滑
                    .antialiased(true)     // 启用抗锯齿
                    .scaledToFill()
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
    
    // 切换喜爱状态的方法
    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            destination.isFavorite.toggle()
            try? modelContext.save()
        }
    }
    
    // 分享地点图片
    private func shareDestination() {
        // 生成地点分享图片
        let destinationImage = TripImageGenerator.generateDestinationImage(from: destination)
        // 只分享图片，不分享文字（因为所有信息都已经包含在图片中）
        shareItem = TripShareItem(text: "", image: destinationImage)
    }
}

// POI预览卡片 - 显示地图上点击的POI或地址信息
struct POIPreviewCard: View {
    let mapItem: MKMapItem
    let onAddDestination: () -> Void
    let onDismiss: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // POI名称或地址
                    Text(mapItem.name ?? "unknown_location".localized)
                        .font(.headline)
                        .lineLimit(2)
                    
                    // 地址信息
                    if let address = formatAddress(from: mapItem.placemark) {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // POI类别（如果有）
                    if let category = mapItem.pointOfInterestCategory {
                        HStack(spacing: 4) {
                            Image(systemName: categoryIcon(for: category))
                                .font(.caption2)
                            Text(category.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 关闭按钮
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 操作按钮
            HStack(spacing: 12) {
                // 在Apple Maps中打开
                Button {
                    mapItem.openInMaps()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                        Text("open_in_maps".localized)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                // 添加目的地
                Button {
                    onAddDestination()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("add_destination".localized)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // 格式化地址
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        // 街道地址
        if let streetNumber = placemark.subThoroughfare,
           let street = placemark.thoroughfare {
            components.append("\(streetNumber) \(street)")
        } else if let street = placemark.thoroughfare {
            components.append(street)
        }
        
        // 城市
        if let city = placemark.locality {
            components.append(city)
        } else if let area = placemark.administrativeArea {
            components.append(area)
        }
        
        // 国家
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // 获取POI类别图标
    private func categoryIcon(for category: MKPointOfInterestCategory) -> String {
        switch category {
        case .restaurant:
            return "fork.knife"
        case .cafe:
            return "cup.and.saucer.fill"
        case .hotel:
            return "bed.double.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .airport:
            return "airplane"
        case .park:
            return "leaf.fill"
        case .museum:
            return "building.columns.fill"
        case .theater:
            return "theatermasks.fill"
        case .store:
            return "bag.fill"
        case .school:
            return "graduationcap.fill"
        case .hospital:
            return "cross.case.fill"
        case .bank:
            return "building.columns.fill"
        default:
            return "mappin.circle.fill"
        }
    }
}

// POI搜索加载卡片 - 显示搜索状态
struct POISearchingCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 加载动画图标
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("searching_location".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("please_wait".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MKPointOfInterestCategory扩展 - 添加显示名称
extension MKPointOfInterestCategory {
    var displayName: String {
        switch self {
        case .restaurant:
            return "restaurant".localized
        case .cafe:
            return "cafe".localized
        case .hotel:
            return "hotel".localized
        case .gasStation:
            return "gas_station".localized
        case .airport:
            return "airport".localized
        case .park:
            return "park".localized
        case .museum:
            return "museum".localized
        case .theater:
            return "theater".localized
        case .store:
            return "store".localized
        case .school:
            return "school".localized
        case .hospital:
            return "hospital".localized
        case .bank:
            return "bank".localized
        default:
            return "point_of_interest".localized
        }
    }
}

#Preview {
    MapView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(BrandColorManager.shared)
        .environmentObject(CountryManager.shared)
}

// 位置管理器 - 单例模式，支持在启动画面期间提前初始化
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocationAccuracy: Double?
    private var isUpdatingLocation = false
    
    // 位置去重和优化
    private var lastProcessedLocation: CLLocation?
    private var lastUpdateTime: Date?
    private var consecutiveLowAccuracyCount = 0
    private var lastSpeed: Double = 0.0
    private var hasDeliveredInitialFix = false
    private var lastDeliveredAccuracy: Double = .greatestFiniteMagnitude
    
    // 配置常量
    private let minUpdateInterval: TimeInterval = 1.0 // 最小更新间隔（秒）
    private let maxAccuracyThreshold: Double = 50.0 // 最大精度阈值（米）
    private let initialAccuracyTolerance: Double = 200.0 // 初始定位阶段允许的精度
    private let accuracyImprovementThreshold: Double = 15.0 // 精度改善阈值
    private let minDistanceForUpdate: Double = 3.0 // 最小距离变化（米）
    private let staleLocationThreshold: TimeInterval = 30.0 // 位置数据过期时间（秒）
    
    private override init() {
        super.init()
        locationManager.delegate = self
        
        // ===== 综合定位技术配置 =====
        // iOS 系统会自动使用所有可用的定位技术，包括：
        // 1. GPS（全球定位系统）- 室外高精度定位
        // 2. WiFi 定位 - 通过 WiFi 热点数据库快速定位（室内/城市）
        // 3. 蜂窝网络定位 - 通过基站三角测量（快速但精度较低）
        // 4. 蓝牙定位 - 通过 iBeacon 等（室内定位）
        // 5. 气压计 - 用于高度测量
        // 6. 磁力计 - 用于方向判断
        // 系统会智能地将所有信号源结合起来，提供最快、最准确的位置信息
        // 我们只需要设置精度要求，系统会自动选择最佳组合
        
        // 使用导航级精度：精度更高（±5米或更好），系统会智能优化功耗
        // 适合长时间追踪路线，类似健身app的策略
        // 系统会自动使用 GPS + WiFi + 蜂窝网络等所有可用技术
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        // 设置距离过滤器：当位置变化超过5米时更新（平衡精度和功耗）
        locationManager.distanceFilter = 5.0
        
        // 设置活动类型为健身/导航，系统会根据活动类型优化定位技术使用和功耗
        // 例如：静止时更多使用 WiFi/蜂窝网络，运动时更多使用 GPS
        locationManager.activityType = .fitness
        
        // 允许后台位置更新（如果已授权后台权限）
        locationManager.allowsBackgroundLocationUpdates = false // 默认关闭，需要时再开启
        
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
    
    /// 开始持续定位更新（用于实时跟踪用户位置）
    func startUpdatingLocation() {
        // 如果尚未请求权限，先请求权限
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        // 检查授权状态
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("⚠️ 位置权限未授权，无法启动持续定位")
            return
        }
        
        // 如果已经在更新，则不需要重复启动
        guard !isUpdatingLocation else {
            return
        }
        
        locationManager.startUpdatingLocation()
        isUpdatingLocation = true
        print("📍 开始持续定位更新")
    }
    
    /// 停止持续定位更新（节省电量）
    func stopUpdatingLocation() {
        guard isUpdatingLocation else {
            return
        }
        
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
        
        // 清理状态
        lastProcessedLocation = nil
        lastUpdateTime = nil
        consecutiveLowAccuracyCount = 0
        lastSpeed = 0.0
        lastLocationAccuracy = nil
        hasDeliveredInitialFix = false
        lastDeliveredAccuracy = .greatestFiniteMagnitude
        
        print("📍 停止持续定位更新")
    }
    
    /// 重置位置缓存（用于重新开始追踪）
    func resetLocationCache() {
        lastProcessedLocation = nil
        lastUpdateTime = nil
        consecutiveLowAccuracyCount = 0
        lastSpeed = 0.0
        lastLocationAccuracy = nil
        hasDeliveredInitialFix = false
        lastDeliveredAccuracy = .greatestFiniteMagnitude
        print("🔄 位置缓存已重置")
    }
    
    // CLLocationManagerDelegate 方法
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 获取最新位置
        guard let location = locations.last else { return }
        let now = Date()
        
        // 1. 时间戳验证：只接受新鲜的位置数据（30秒内）
        let locationAge = abs(location.timestamp.timeIntervalSinceNow)
        if locationAge > staleLocationThreshold {
            print("⚠️ 位置数据过期，忽略: 年龄=\(Int(locationAge))秒")
            return
        }
        
        if let lastTime = lastUpdateTime,
           now.timeIntervalSince(lastTime) > staleLocationThreshold {
            hasDeliveredInitialFix = false
        }
        
        let accuracy = location.horizontalAccuracy
        let effectiveThreshold = hasDeliveredInitialFix ? maxAccuracyThreshold : initialAccuracyTolerance
        
        // 2. 位置质量过滤：只接受水平精度在阈值以内的位置更新
        if accuracy < 0 || accuracy > effectiveThreshold {
            consecutiveLowAccuracyCount += 1
            // 如果连续多次低精度，可以考虑降低精度要求（但这里先严格过滤）
            if consecutiveLowAccuracyCount < 3 {
                print("⚠️ 位置精度较差，忽略此次更新: 精度=\(accuracy)米 (连续\(consecutiveLowAccuracyCount)次)")
            }
            return
        }
        
        // 重置低精度计数
        consecutiveLowAccuracyCount = 0
        
        // 3. 位置去重：避免处理相同或非常接近的位置
        if let lastLocation = lastProcessedLocation {
            let distance = location.distance(from: lastLocation)
            
            // 如果距离变化小于阈值，且时间间隔太短，则忽略（除非精度明显改善）
            if distance < minDistanceForUpdate {
                let accuracyImproved = accuracy + accuracyImprovementThreshold < lastDeliveredAccuracy
                if let lastTime = lastUpdateTime,
                   now.timeIntervalSince(lastTime) < minUpdateInterval,
                   !accuracyImproved {
                    return // 位置变化太小且没有显著精度改善，忽略
                }
            }
        }
        
        // 4. 速度检测和智能调整
        if location.speed >= 0 {
            lastSpeed = location.speed
            
            // 根据速度智能调整距离过滤器（可选优化）
            // 静止时增大距离过滤器，运动时减小
            if location.speed < 0.5 { // 静止（< 0.5 m/s）
                // 静止时可以增大距离过滤器，但这里保持5米不变
            } else if location.speed > 5.0 { // 快速移动（> 5 m/s，约18 km/h）
                // 快速移动时可以减小距离过滤器以获得更平滑的轨迹
                // 但为了省电，这里保持5米不变
            }
        }
        
        // 5. 更新位置
        // 注意：location 对象已经包含了系统综合所有定位技术（GPS + WiFi + 蜂窝网络等）的结果
        // 我们不需要关心具体使用了哪种技术，系统已经为我们选择了最佳组合
        // CoreLocation 返回 WGS84 坐标，国内地图需要 GCJ02（火星坐标）
        // 仅在坐标位于中国境内时会进行修正
        let wgsCoord = location.coordinate
        let gcjCoord = CoordinateConverter.wgs84ToGCJ02(wgsCoord)
        lastKnownLocation = gcjCoord
        lastLocationAccuracy = accuracy
        lastDeliveredAccuracy = accuracy
        if !hasDeliveredInitialFix {
            hasDeliveredInitialFix = true
            print("✅ 初始定位可用，精度=\(String(format: "%.1f", accuracy))米")
        }
        
        // 6. 记录已处理的位置
        lastProcessedLocation = location
        lastUpdateTime = Date()
        
        // 输出位置信息（精度反映了综合定位技术的效果）
        // horizontalAccuracy 越小表示精度越高，通常：
        // - < 5米：主要使用 GPS（室外）
        // - 5-20米：GPS + WiFi/蜂窝网络混合（城市环境）
        // - 20-50米：主要使用 WiFi/蜂窝网络（室内或信号弱时）
        print("📍 获取到用户位置（综合定位）: WGS84(\(wgsCoord.latitude), \(wgsCoord.longitude)) -> GCJ02(\(gcjCoord.latitude), \(gcjCoord.longitude)), 精度=\(String(format: "%.1f", location.horizontalAccuracy))米, 速度=\(String(format: "%.1f", location.speed * 3.6))km/h")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        
        // 详细的错误处理和恢复策略
        switch nsError.code {
        case CLError.locationUnknown.rawValue:
            // 位置未知，但可以继续尝试
            print("⚠️ 位置未知，继续尝试获取位置")
            
        case CLError.denied.rawValue:
            // 用户拒绝授权
            print("❌ 位置权限被拒绝")
            stopUpdatingLocation()
            
        case CLError.network.rawValue:
            // 网络错误
            print("⚠️ 网络错误，无法获取位置: \(error.localizedDescription)")
            // 网络错误时可以继续尝试，系统会自动重试
            
        case CLError.headingFailure.rawValue:
            // 方向获取失败（不影响位置）
            print("⚠️ 方向获取失败")
            
        default:
            print("❌ 获取位置失败: \(error.localizedDescription) (错误码: \(nsError.code))")
        }
        
        // 如果是临时错误，系统会自动重试
        // 如果是权限错误，需要用户重新授权
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 位置授权状态变更: \(authorizationStatus.rawValue)")
        
        // 如果已授权且正在更新，重新启动定位
        if (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) && isUpdatingLocation {
            locationManager.startUpdatingLocation()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            // 如果已授权但未在更新，请求一次位置（用于一次性定位场景）
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
                    // 使用品牌红与米色渐变增强质感，符合配色规范
                    RadialGradient(
                        colors: [
                            Color.footprintRed.opacity(0.9),
                            Color.footprintRed.opacity(0.6),
                            Color.footprintBeige.opacity(0.5)
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
                                    Color.white.opacity(0.7),
                                    Color.footprintBeige.opacity(0.1)
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
                                    Color.white.opacity(0.9),
                                    Color.footprintRed.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.footprintRed.opacity(0.35), radius: 10, x: 0, y: 5)
                .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
            
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
                            Color.white.opacity(0.4),
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

private struct AssistiveMenuAction: Identifiable {
    let id: String
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void
}

private struct FloatingAssistiveMenu: View {
    static let collapsedDiameter: CGFloat = 60
    static let menuRadius: CGFloat = 120
    static let margin: CGFloat = 12
    
    let actions: [AssistiveMenuAction]
    @Binding var isExpanded: Bool
    @Binding var position: CGPoint
    let canvasSize: CGSize
    let safeAreaInsets: EdgeInsets
    let menuTitle: String
    let isDarkStyle: Bool
    let iconProvider: (String, Bool) -> AnyView
    let activeBackground: Color
    
    @State private var dragStartPosition: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var lastCanvasSize: CGSize = .zero
    @State private var lastSafeAreaInsets: EdgeInsets = EdgeInsets()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if isExpanded {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        collapseMenu()
                    }
            }
            
            menuLayer
                .position(position)
                .highPriorityGesture(dragGesture)
                .accessibilityLabel(menuTitle)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .onChange(of: canvasSize) { newSize in
            handleGeometryChange(newSize: newSize, newInsets: safeAreaInsets)
        }
        .onChange(of: safeAreaInsets) { newInsets in
            handleGeometryChange(newSize: canvasSize, newInsets: newInsets)
        }
    }
    
    private var menuLayer: some View {
        ZStack {
            if isExpanded {
                menuBackdrop
                    .transition(.scale.combined(with: .opacity))
            }
            
            ForEach(Array(actions.enumerated()), id: \.1.id) { index, action in
                radialButton(for: action, at: index)
            }
            mainButton
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
 
    private var menuBackdrop: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .fill(
                        (isDarkStyle ? Color.black : Color.white)
                            .opacity(0.15)
                    )
            )
            .frame(width: Self.menuRadius * 2.3, height: Self.menuRadius * 2.3)
            .blur(radius: 6, opaque: false)
            .shadow(color: .black.opacity(isDarkStyle ? 0.45 : 0.18), radius: 20, x: 0, y: 8)
            .accessibilityHidden(true)
    }
   
    private var mainButton: some View {
        Button {
            toggleMenu()
        } label: {
            Image(systemName: isExpanded ? "xmark" : "circle.hexagongrid.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isDarkStyle ? Color.white : Color.primary)
                .frame(width: Self.collapsedDiameter, height: Self.collapsedDiameter)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(isDarkStyle ? Color.white.opacity(0.12) : Color.white.opacity(0.85))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isDarkStyle ? 0.25 : 0.35), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint(menuTitle)
    }
    
    private func radialButton(for action: AssistiveMenuAction, at index: Int) -> some View {
        let offsets = radialOffsets(for: index)
        let isCheckInAction = action.id == "check_in"
        
        return Button {
            select(action)
        } label: {
            VStack(spacing: 0) {
                if isCheckInAction {
                    // 打卡按钮：直接使用外部提供的完整玻璃+脉冲视图，不再额外包一层圆形背景
                    iconProvider(action.icon, action.isActive)
                } else {
                    iconProvider(action.icon, action.isActive)
                        .frame(width: 24, height: 24)
                        .padding(14)
                        .background(
                            Circle()
                                .fill(buttonBackground(isActive: action.isActive))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(isDarkStyle ? 0.25 : 0.2), lineWidth: action.isActive ? 1.6 : 1)
                                )
                        )
                }
            }
            .opacity(isExpanded ? 1 : 0)
            .scaleEffect(isExpanded ? 1 : 0.5, anchor: .center)
        }
        .buttonStyle(.plain)
        .offset(x: isExpanded ? offsets.x : 0, y: isExpanded ? offsets.y : 0)
    }
    
    private func radialOffsets(for index: Int) -> (x: CGFloat, y: CGFloat) {
        guard actions.count > 1 else { return (0, 0) }
        let spread = Double.pi * 0.9
        let start = -spread / 2
        let step = spread / Double(actions.count - 1)
        let angle = start + step * Double(index)
        let baseX = CGFloat(cos(angle)) * Self.menuRadius
        let baseY = CGFloat(sin(angle)) * Self.menuRadius
        let horizontalDirection: CGFloat = position.x > canvasSize.width / 2 ? -1 : 1
        return (abs(baseX) * horizontalDirection, baseY)
    }
    
    private func buttonBackground(isActive: Bool) -> Color {
        if isActive {
            return activeBackground
        }
        return isDarkStyle ? Color.black.opacity(0.55) : Color.white.opacity(0.95)
    }
    
    private func toggleMenu() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if isExpanded {
            collapseMenu()
        } else {
            clampPosition(requiresMenuSpace: true)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isExpanded = true
            }
        }
    }
    
    private func select(_ action: AssistiveMenuAction) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        collapseMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action.action()
        }
    }
    
    private func collapseMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isExpanded = false
        }
        clampPosition(requiresMenuSpace: false)
        snapToNearestEdge()
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // 如果是第一次拖拽，记录初始位置
                if !isDragging {
                    isDragging = true
                    dragStartPosition = position
                }
                
                if isExpanded {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
                
                // 实时更新位置：基于初始位置 + 拖拽偏移量
                // 不使用动画，确保实时跟随手指
                position = CGPoint(
                    x: dragStartPosition.x + value.translation.width,
                    y: dragStartPosition.y + value.translation.height
                )
            }
            .onEnded { value in
                // 应用最终位置
                position = CGPoint(
                    x: dragStartPosition.x + value.translation.width,
                    y: dragStartPosition.y + value.translation.height
                )
                
                // 重置拖拽状态
                isDragging = false
                dragStartPosition = .zero
                
                // 限制在安全区域内
                clampPosition(requiresMenuSpace: false)
                
                // 吸附到最近的边缘
                snapToNearestEdge()
            }
    }
    
    private func snapToNearestEdge(size: CGSize? = nil, insets: EdgeInsets? = nil) {
        let canvas = size ?? canvasSize
        let safeArea = insets ?? safeAreaInsets
        let collapsedRadius = Self.collapsedDiameter / 2
        let left = safeArea.leading + Self.margin + collapsedRadius
        let right = canvas.width - safeArea.trailing - Self.margin - collapsedRadius
        let targetX = position.x < canvas.width / 2 ? left : right
        let clampedY = min(
            max(position.y, safeArea.top + Self.margin + collapsedRadius),
            canvas.height - safeArea.bottom - Self.margin - collapsedRadius
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            position = CGPoint(x: targetX, y: clampedY)
        }
    }
    
    private func clampPosition(requiresMenuSpace: Bool) {
        clampPosition(
            to: canvasSize,
            insets: safeAreaInsets,
            requiresMenuSpace: requiresMenuSpace
        )
    }
    
    private func clampPosition(to size: CGSize, insets: EdgeInsets, requiresMenuSpace: Bool) {
        position = FloatingAssistiveMenu.clamp(
            position,
            in: size,
            safeArea: insets,
            requiresMenuSpace: requiresMenuSpace
        )
    }
    
    private func handleGeometryChange(newSize: CGSize, newInsets: EdgeInsets) {
        guard newSize.width.isFinite, newSize.height.isFinite else { return }
        
        let sizeDelta = abs(lastCanvasSize.width - newSize.width) + abs(lastCanvasSize.height - newSize.height)
        let insetDelta =
            abs(lastSafeAreaInsets.top - newInsets.top) +
            abs(lastSafeAreaInsets.leading - newInsets.leading) +
            abs(lastSafeAreaInsets.bottom - newInsets.bottom) +
            abs(lastSafeAreaInsets.trailing - newInsets.trailing)
        
        let isInitialMeasurement = lastCanvasSize == .zero
        lastCanvasSize = newSize
        lastSafeAreaInsets = newInsets
        
        if isInitialMeasurement {
            clampPosition(to: newSize, insets: newInsets, requiresMenuSpace: isExpanded)
            return
        }
        
        if sizeDelta > 10 || insetDelta > 2 {
            if isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isExpanded = false
                }
            }
            clampPosition(to: newSize, insets: newInsets, requiresMenuSpace: false)
            snapToNearestEdge(size: newSize, insets: newInsets)
        } else {
            clampPosition(to: newSize, insets: newInsets, requiresMenuSpace: isExpanded)
        }
    }
    
    static func defaultPosition(in size: CGSize, safeArea: EdgeInsets) -> CGPoint {
        CGPoint(
            x: size.width - safeArea.trailing - margin - (collapsedDiameter / 2),
            y: size.height - safeArea.bottom - margin - (collapsedDiameter / 2) - 120
        )
    }
    
    static func clamp(
        _ position: CGPoint,
        in size: CGSize,
        safeArea: EdgeInsets,
        requiresMenuSpace: Bool
    ) -> CGPoint {
        guard size.width.isFinite, size.height.isFinite else { return position }
        let collapsedRadius = collapsedDiameter / 2
        let minX = safeArea.leading + margin + collapsedRadius
        let maxX = size.width - safeArea.trailing - margin - collapsedRadius
        let minY = safeArea.top + margin + collapsedRadius
        let maxY = size.height - safeArea.bottom - margin - collapsedRadius
        
        var clampedX = min(max(position.x, minX), maxX)
        var clampedY = min(max(position.y, minY), maxY)
        
        guard requiresMenuSpace else {
            return CGPoint(x: clampedX, y: clampedY)
        }
        
        // 根据浮球所在区域，仅为展开方向预留空间，避免整体被挤到屏幕中间
        let horizontalMid = (minX + maxX) / 2
        if clampedX >= horizontalMid {
            let minAllowedX = minX + menuRadius
            if clampedX < minAllowedX {
                clampedX = minAllowedX
            }
        } else {
            let maxAllowedX = maxX - menuRadius
            if clampedX > maxAllowedX {
                clampedX = maxAllowedX
            }
        }
        
        // 垂直方向仅在需要时进行最小幅度的校正
        let availableTop = clampedY - minY
        if availableTop < menuRadius {
            clampedY = minY + menuRadius
        }
        
        let availableBottom = maxY - clampedY
        if availableBottom < menuRadius {
            clampedY = maxY - menuRadius
        }
        
        return CGPoint(x: clampedX, y: clampedY)
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
    @State private var showingLayoutSelection = false // 控制版面选择视图显示
    @State private var selectedLayout: TripShareLayout = .list // 默认选择清单版面
    
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
    
    // 检查是否有封面图片
    private var hasCoverPhoto: Bool {
        trip.coverPhotoData != nil
    }
    
    // 封面图片
    @ViewBuilder
    private var coverImage: some View {
        if let photoData = trip.coverPhotoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Color.clear
        }
    }
    
    // 文字颜色：有封面图片时使用白色，否则使用系统颜色
    private var primaryTextColor: Color {
        hasCoverPhoto ? .white : .primary
    }
    
    private var secondaryTextColor: Color {
        hasCoverPhoto ? .white.opacity(0.9) : .secondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 旅程名称和日期
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                        .foregroundColor(primaryTextColor)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                        Text(formatDateRange(trip.startDate, trip.endDate))
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
                
                // 操作按钮组
                HStack(spacing: 8) {
                    // 在地图中打开按钮
                    Button {
                        openTripInMaps()
                    } label: {
                        ZStack {
                            if hasCoverPhoto {
                                // 有封面时使用更不透明的 Material，叠加白色半透明层
                                Circle()
                                    .fill(.ultraThinMaterial)
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                            } else {
                                Circle()
                                    .fill(.ultraThinMaterial)
                            }
                            
                        Image(systemName: "map")
                            .font(.system(size: 16, weight: .medium))
                                .foregroundColor(hasCoverPhoto ? .white : .primary)
                        }
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    
                    // 分享按钮
                    Button {
                        showingLayoutSelection = true
                    } label: {
                        ZStack {
                            if hasCoverPhoto {
                                // 有封面时使用更不透明的 Material，叠加白色半透明层
                                Circle()
                                    .fill(.ultraThinMaterial)
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                            } else {
                                Circle()
                                    .fill(.ultraThinMaterial)
                            }
                            
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                                .foregroundColor(hasCoverPhoto ? .white : .primary)
                        }
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 线路信息
            HStack(spacing: 16) {
                // 地点数量
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(hasCoverPhoto ? .white : .blue)
                        Text("\(destinations.count)")
                            .font(.headline)
                            .foregroundColor(primaryTextColor)
                    }
                    Text("地点")
                        .font(.caption2)
                        .foregroundColor(secondaryTextColor)
                }
                
                // 总距离
                if totalDistance > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "road.lanes")
                                .font(.caption)
                                .foregroundColor(hasCoverPhoto ? .white : .green)
                            Text(formatDistance(totalDistance))
                                .font(.headline)
                                .foregroundColor(primaryTextColor)
                        }
                        Text("总距离")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }
                } else if isLoadingRoutes {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(hasCoverPhoto ? .white : nil)
                        Text("计算中...")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            
            // 起点和终点
            if let start = destinations.first, let end = destinations.last {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(hasCoverPhoto ? Color.white : Color.red)
                                .frame(width: 6, height: 6)
                            Text(start.name)
                                .font(.caption)
                                .foregroundColor(primaryTextColor)
                                .lineLimit(1)
                        }
                        Text("起点")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(secondaryTextColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(hasCoverPhoto ? Color.white : Color.blue)
                                .frame(width: 6, height: 6)
                            Text(end.name)
                                .font(.caption)
                                .foregroundColor(primaryTextColor)
                                .lineLimit(1)
                        }
                        Text("终点")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("trip_share_no_destinations".localized)
                        .font(.subheadline)
                        .foregroundColor(secondaryTextColor)
                    
                    Label("add_destination".localized, systemImage: "plus.circle")
                        .font(.caption)
                        .foregroundColor(hasCoverPhoto ? .white : .accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 320)
        .background(
            Group {
                if hasCoverPhoto {
                    // 有封面图片：使用封面图片 + 深色遮罩层
                    GeometryReader { geometry in
                        ZStack {
                            // 封面图片作为背景，填充整个区域
                            coverImage
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                            
                            // 深色半透明遮罩层，确保文字可读性
                            // 使用渐变遮罩，底部更暗以增强文字对比度
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                } else {
                    // 无封面图片：使用毛玻璃效果
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
                }
            }
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
        .sheet(isPresented: $showingLayoutSelection) {
            TripShareLayoutSelectionView(trip: trip, selectedLayout: $selectedLayout)
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
            totalDistance = cachedRoutes.reduce(0) { $0 + $1.footprintDistance }
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
                    totalDistance = calculatedRoutes.reduce(0) { $0 + $1.footprintDistance }
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
    
    // 在Apple Maps中打开旅程（路线规划模式）
    private func openTripInMaps() {
        guard !destinations.isEmpty else { return }
        
        let sortedDestinations = destinations.sorted { $0.visitDate < $1.visitDate }
        
        // 创建所有目的地的MapItem（按访问顺序）
        var mapItems: [MKMapItem] = []
        for destination in sortedDestinations {
            let placemark = MKPlacemark(coordinate: destination.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = destination.name
            mapItems.append(mapItem)
        }
        
        guard !mapItems.isEmpty else { return }
        
        // 配置路线规划启动选项（使用驾车模式，这样会直接打开路线规划界面）
        // "d" = 驾车, "w" = 步行, "t" = 公共交通
        let options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: "d",  // 驾车模式
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ]
        
        if mapItems.count == 1 {
            // 只有一个目的地：打开从当前位置到该地点的路线规划
            mapItems[0].openInMaps(launchOptions: options)
        } else {
            // 多个目的地：创建包含所有停靠点的路线
            // 第一个作为起点，其余作为停靠点和终点
            // Apple Maps会自动处理多停靠点的路线规划，并显示路线界面
            MKMapItem.openMaps(with: mapItems, launchOptions: options)
        }
    }
}

// "我的足迹"抽屉视图
struct FootprintsDrawerView: View {
    let destinations: [TravelDestination]
    let onSelect: (TravelDestination) -> Void
    let onAdd: () -> Void
    let onImportPhoto: () -> Void
    
    private var orderedDestinations: [TravelDestination] {
        destinations.sorted { $0.visitDate > $1.visitDate }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if orderedDestinations.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "map")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.accentColor)
                            
                            Text("start_recording_footprints".localized)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(orderedDestinations) { destination in
                            Button {
                                onSelect(destination)
                            } label: {
                                DestinationRow(destination: destination, showsDisclosureIndicator: true)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    } header: {
                        Text("\(orderedDestinations.count) " + "destinations".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("my_footprints".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        // 添加目的地按钮
                        Button {
                            onAdd()
                        } label: {
                            FootprintsToolbarIcon(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        
                        // 导入照片按钮
                        Button {
                            onImportPhoto()
                        } label: {
                            FootprintsToolbarIcon(systemName: "photo.badge.plus")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// 顶部工具栏图标按钮样式（与全局风格一致，去掉额外灰色环）
private struct FootprintsToolbarIcon: View {
    let systemName: String
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            // 图标使用系统背景色，搭配深色圆形背景，形成黑/白对比
            .foregroundColor(Color(.systemBackground))
            .frame(width: 32, height: 32)
            .background {
                if #available(iOS 26, *) {
                    Circle()
                        // 使用系统语义前景色（浅色模式下接近黑色，深色模式下接近白色）
                        .fill(Color(.label))
                        .glassEffect(.regular, in: Circle())
                } else {
                    Circle()
                        .fill(Color(.label))
                }
            }
            .contentShape(Rectangle())
            .frame(width: 44, height: 44) // 扩大触控区域，符合HIG
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
                    totalDistance = calculatedRoutes.reduce(0) { $0 + $1.footprintDistance }
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

