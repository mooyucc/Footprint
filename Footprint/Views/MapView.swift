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
import Contacts

/// 用于在闭包中安全更新选中旅程/按天筛选（避免 struct 的 self 不可变）
private final class RouteSelectionHolder: ObservableObject {
    @Published var selectedTripId: UUID?
    @Published var selectedDayFilter: Int?
}

struct MapView: View {
    @Query private var destinations: [TravelDestination]
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme // 检测颜色模式
    @Environment(\.isAppReady) private var isAppReady // 应用是否已就绪（启动画面是否结束）
    @Environment(\.mapViewInNavigationStack) private var mapViewInNavigationStack // 是否嵌入在 NavigationStack 中（如旅程卡片全屏地图 sheet），用于统一顶部工具栏位置
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var countryManager = CountryManager.shared
    
    // MapView 专注于"我的足迹"模式
    /// 嵌入 NavigationStack 时可传入绑定，用于在导航栏标题位显示「第几天」筛选
    /// tripsOverride: 父视图传入时用于限制展示的行程列表（如分页）；nil 时使用 @Query 全量
    init(
        autoShowRouteCards: Bool = false,
        showBottomCheckInButton: Bool = true,
        showJourneyDrawer: Bool = true,
        selectedTripIdBinding: Binding<UUID?>? = nil,
        selectedDayFilterBinding: Binding<Int?>? = nil,
        tripsOverride: [TravelTrip]? = nil,
        hasMoreTrips: Bool = false,
        onLoadMoreTrips: (() -> Void)? = nil
    ) {
        self.autoShowRouteCards = autoShowRouteCards
        self.showBottomCheckInButton = showBottomCheckInButton
        self.showJourneyDrawer = showJourneyDrawer
        self.selectedTripIdBinding = selectedTripIdBinding
        self.selectedDayFilterBinding = selectedDayFilterBinding
        self.tripsOverride = tripsOverride
        self.hasMoreTrips = hasMoreTrips
        self.onLoadMoreTrips = onLoadMoreTrips
    }
    
    /// 父视图传入的行程列表；nil 时使用 @Query 的 trips
    private var tripsOverride: [TravelTrip]?
    /// 是否还有更多行程可加载（用于分页「加载更多」）
    var hasMoreTrips: Bool = false
    /// 加载更多行程的回调（与 `tripsOverride` 配合分页时使用）
    var onLoadMoreTrips: (() -> Void)? = nil
    
    /// 实际使用的行程列表：有 override 时用 override（分页），否则用 @Query 全量
    private var effectiveTrips: [TravelTrip] {
        tripsOverride ?? trips
    }
    
    /// 由父视图传入时用于导航栏标题位筛选；未传入时使用内部 state
    private var selectedTripIdBinding: Binding<UUID?>?
    private var selectedDayFilterBinding: Binding<Int?>?
    
    // MARK: - Route Color Helper
    /// 根据交通方式返回路线颜色
    /// - Parameter transportType: 交通方式
    /// - Returns: 路线颜色（徒步：绿色，机动车：蓝色，飞机：橙色，其他：灰色）
    private func routeColor(for transportType: MKDirectionsTransportType) -> Color {
        if transportType == RouteManager.none {
            // 无：浅灰色（跨天连接线）
            return Color(.tertiaryLabel)
        } else if transportType == RouteManager.airplane {
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
    // 标记当前点按是否来自自定义地点标记，避免“击穿”到地图触发POI弹窗
    @State private var annotationTapInProgress = false

    @ObservedObject private var locationManager = LocationManager.shared
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var destinationWeatherManager = DestinationWeatherManager()
    // 详情弹窗（由父级统一展示，避免子视图被移除导致弹窗不出现）
    @State private var detailDestinationForSheet: TravelDestination?
    @State private var destinationDetailDetent: PresentationDetent = .fraction(0.25)
    
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
    @State private var isCalculatingClusters = false // 标记是否正在计算，避免重复触发
    
    // 性能优化：缓存排序后的地点列表，避免重复排序
    @State private var sortedDestinationsCache: [UUID: [TravelDestination]] = [:]
    
    // 按可见区域从 DB 拉取的地点（减少首屏/缩放时对全量 destinations 的遍历与聚类计算量）
    @State private var destinationsInVisibleRegion: [TravelDestination]? = nil
    @State private var visibleRegionKeyForFetch: String = ""
    
    
    // 地图样式相关状态
    @AppStorage("mapStyle") private var mapStyleRawValue: String = MapStyle.muted.rawValue
    @State private var showingMapStylePicker = false
    
    // 长按添加目的地相关状态
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var isGeocodingLocation = false
    @State private var addDestinationPrefill: AddDestinationPrefill?
    @State private var isWaitingForLocation = false // 等待定位状态（用于打卡功能）
    @State private var pendingPhotoPrefill: PendingPhotoPrefill?
    @State private var shouldUsePrefillForAddDestination = false // 标记是否应该在"添加目的地"中使用预填充数据（用于照片导入等场景）
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
    @State private var tapStartTime: Date? // 用于区分轻点和长按
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
    
    // AI功能相关状态
    @State private var showingAIAssistant = false // 控制AI助手界面显示
    
    // 线路卡片相关状态
    @State private var showRouteCards = false
    @StateObject private var routeSelectionHolder = RouteSelectionHolder()
    @State private var scrollPosition: UUID? // 滚动位置（iOS 17+ 原生 API）
    @State private var shouldHideRouteCards = false // 是否应该隐藏路线卡片（用于弹窗交互）
    @State private var showingTripDetail = false // 是否显示路线详情sheet
    @State private var detailTripForSheet: TravelTrip? // 用于sheet的路线详情
    @State private var showingFootprintsDrawer = false // 是否显示"我的足迹"抽屉
    @State private var assistiveMenuExpanded = false
    @State private var assistiveMenuPosition: CGPoint = .zero
    var autoShowRouteCards: Bool = false // 是否自动显示线路卡片
    var showBottomCheckInButton: Bool = true // 是否展示底部打卡按钮
    /// 是否显示底部旅程抽屉（`JourneyDrawer`）；为 `false` 时仍保留线路 tab 的缩放/连线/按天筛选逻辑，仅隐藏底部卡片
    var showJourneyDrawer: Bool = true
    
    /// 当前选中的旅程ID（来自 Binding 或内部 holder）
    private var selectedTripId: UUID? {
        get { selectedTripIdBinding?.wrappedValue ?? routeSelectionHolder.selectedTripId }
        set {
            if let b = selectedTripIdBinding { b.wrappedValue = newValue }
            else { routeSelectionHolder.selectedTripId = newValue }
        }
    }
    
    /// 按天筛选（来自 Binding 或内部 holder）
    private var selectedDayFilter: Int? {
        get { selectedDayFilterBinding?.wrappedValue ?? routeSelectionHolder.selectedDayFilter }
        set {
            if let b = selectedDayFilterBinding { b.wrappedValue = newValue }
            else { routeSelectionHolder.selectedDayFilter = newValue }
        }
    }
    
    /// 供子视图使用的 selectedTripId Binding（因 selectedTripId 为计算属性）
    private var selectedTripIdBindingForSubviews: Binding<UUID?> {
        Binding(
            get: { selectedTripId },
            set: { newValue in
                if let b = selectedTripIdBinding { b.wrappedValue = newValue }
                else { routeSelectionHolder.selectedTripId = newValue }
            }
        )
    }
    
    /// 在闭包/非 mutating 上下文中安全写入选中旅程（避免 self 不可变）
    private func setSelectedTripId(_ value: UUID?) {
        if let b = selectedTripIdBinding { b.wrappedValue = value }
        else { routeSelectionHolder.selectedTripId = value }
    }
    
    /// 在闭包/非 mutating 上下文中安全写入按天筛选
    private func setSelectedDayFilter(_ value: Int?) {
        if let b = selectedDayFilterBinding { b.wrappedValue = value }
        else { routeSelectionHolder.selectedDayFilter = value }
    }
    
    // 触觉反馈
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
        var suggestedPlaceType: String?
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
    
    // 当前地图样式（持久化）
    private var currentMapStyle: MapStyle {
        MapStyle(rawValue: mapStyleRawValue) ?? .muted
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
        !autoShowRouteCards && selectedDestination == nil && !showRouteCards && !showSearchBar
    }
    
    private var brandAccentColor: Color {
        brandColorManager.currentBrandColor
    }
    
    /// 在地图上展示的地点集合（我的足迹：展示用户所有打卡点）
    private var destinationsForCurrentMapMode: [TravelDestination] {
        return destinations
    }
    
    /// 根据可见区域生成缓存键（与 visibleRegionKey 一致，用于按区域拉取）
    private static func makeRegionKey(_ region: MKCoordinateRegion, tripId: UUID? = nil, dayFilter: Int? = nil) -> String {
        let centerLat = String(format: "%.3f", region.center.latitude)
        let centerLon = String(format: "%.3f", region.center.longitude)
        let spanLat = String(format: "%.3f", region.span.latitudeDelta)
        let spanLon = String(format: "%.3f", region.span.longitudeDelta)
        let tripIdSuffix = tripId?.uuidString ?? "nil"
        let daySuffix = dayFilter.map { "\($0)" } ?? "all"
        return "\(centerLat),\(centerLon),\(spanLat),\(spanLon),\(tripIdSuffix),\(daySuffix)"
    }
    
    /// 按可见区域从 DB 拉取地点（带约 10% 边距），用于聚类等，减轻对全量 @Query 的依赖
    private func fetchDestinationsInRegion(_ region: MKCoordinateRegion) async {
        let margin = max(region.span.latitudeDelta, region.span.longitudeDelta) * 0.15
        let minLat = region.center.latitude - region.span.latitudeDelta / 2 - margin
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2 + margin
        let minLon = region.center.longitude - region.span.longitudeDelta / 2 - margin
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2 + margin
        let descriptor = FetchDescriptor<TravelDestination>(
            predicate: #Predicate<TravelDestination> { d in
                d.latitude >= minLat && d.latitude <= maxLat &&
                d.longitude >= minLon && d.longitude <= maxLon
            },
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        let list = (try? modelContext.fetch(descriptor)) ?? []
        let key = Self.makeRegionKey(region, tripId: selectedTripId, dayFilter: selectedDayFilter)
        await MainActor.run {
            destinationsInVisibleRegion = list
            visibleRegionKeyForFetch = key
        }
    }
    
    // 打卡按钮的无障碍提示
    private var checkInAccessibilityHint: String {
        "quick_check_in".localized
    }
    
    // 仅为当前选中的旅程重新计算路线（进入"旅程"时避免全量计算）
    private func recalcSelectedTripRoutes(forceFullRecalc: Bool = false) {
        guard let selectedId = selectedTripId,
              let trip = effectiveTrips.first(where: { $0.id == selectedId }),
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
            // destinationCalloutOverlay // 已移除：点击地点时只显示底部抽屉弹窗，不显示地点位置的标签卡片
            floatingButtons
            keyboardOverlay
        }
        // 搜索功能已移至 searchBarOverlay，使用自定义覆盖层实现
    }
    
    // 应用 Sheet 修饰符
    @ViewBuilder
    private func applySheets<Content: View>(to content: Content) -> some View {
        content
            .sheet(item: $detailDestinationForSheet, onDismiss: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    selectedDestination = nil
                    mapSelection = nil
                }
            }) { destination in
                NavigationStack {
                    DestinationDetailView(destination: destination)
                }
                .presentationDetents([.fraction(0.25), .medium, .large], selection: $destinationDetailDetent)
                .presentationDragIndicator(.visible)
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
                    onAdd: handleFootprintsAdd
                )
            }
            // 普通"添加目的地"弹窗
            .sheet(isPresented: $showingAddDestination, onDismiss: {
                addDestinationPrefill = nil
                pendingPhotoPrefill = nil
                isWaitingForLocation = false
                isGeocodingLocation = false
                shouldUsePrefillForAddDestination = false  // 重置标志
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
            .sheet(isPresented: $showingAIAssistant) {
                AIAssistantView()
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
            .onReceive(NotificationCenter.default.publisher(for: .destinationUpdated)) { _ in
                destinationsInVisibleRegion = nil
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
            .onChange(of: effectiveTrips) { oldValue, newValue in
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
            .onChange(of: effectiveTrips.count) { _, _ in
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
                    
                    // 卡片切换时，对原来计算不成功的占位线再次尝试计算
                    if let newTripId = newValue,
                       let trip = effectiveTrips.first(where: { $0.id == newTripId }),
                       let tripDestinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                       tripDestinations.count >= 2 {
                        let coordinates = tripDestinations.map { $0.coordinate }
                        Task {
                            // 重新计算失败的路线（占位线）
                            await retryFailedRoutesForTrip(tripId: newTripId, coordinates: coordinates)
                        }
                    }
                }
            }
            .onChange(of: selectedDayFilter) { _, _ in
                if autoShowRouteCards, !visibleDestinationsForSelectedTrip.isEmpty {
                    zoomToTripDestinations(visibleDestinationsForSelectedTrip)
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
                            self.reverseGeocodeLocation(coordinate: currentLocation, force: false, forAddDestinationPrefill: false)
                        }
                    }
                }
            }
            return
        }
        
        let accuracyImproved = accuracy + accuracyImprovementTrigger < lastGeocodedAccuracy
        // 启动阶段：即使精度改善，也不强制触发，避免频繁请求
        let shouldForce = isWaitingForLocation || (!isStartupPhase && (distanceToLast > 80 || accuracyImproved)) || lastReverseGeocodeCoordinate == nil
        
        // 是否为「打卡等待定位」触发的编码（需在清空 isWaitingForLocation 前保存，用于决定是否更新添加目的地预填）
        let forAddDestinationPrefill = isWaitingForLocation
        if isWaitingForLocation {
            print("✅ 位置更新，开始打卡反向地理编码: (\(newLocation.latitude), \(newLocation.longitude)) 精度=\(String(format: "%.1f", accuracy))米")
            isWaitingForLocation = false
        }
        
        if isStartupPhase {
            // 启动阶段：只执行一次自动反向地理编码
            hasDoneInitialGeocode = true
        }
        
        reverseGeocodeLocation(coordinate: newLocation, force: shouldForce, forAddDestinationPrefill: forAddDestinationPrefill)
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
        
        // 主 Tab 地图的定位启停由 ContentView（scenePhase + 选中 tab）统一管理，避免与 onDisappear 重复 stop/start。
        // 仅嵌入全屏旅程地图（sheet）时需在此自行启动（此时通常不在「足迹地图」tab）。
        if mapViewInNavigationStack {
            locationManager.startUpdatingLocation()
        }
        
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
        if mapViewInNavigationStack {
            locationManager.stopUpdatingLocation()
        }
        geocodeTimeoutTimer?.invalidate()
        geocodeTimeoutTimer = nil
        pendingGeocodeCoordinate = nil
    }
    
    // 处理自动显示路线卡片
    private func handleAutoShowRouteCards() {
        let allTrips = effectiveTrips
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
           let currentTrip = validTrips.first(where: { $0.id == currentSelectedId }) {
            // 使用缓存的排序结果
            let destinations = sortedDestinations(for: currentSelectedId)
            if destinations.count >= 2 {
                targetTrip = currentTrip
                tripDestinations = destinations
            }
        } else if let firstValidTrip = validTrips.first {
            // 使用缓存的排序结果
            let destinations = sortedDestinations(for: firstValidTrip.id)
            if destinations.count >= 2 {
                targetTrip = firstValidTrip
                tripDestinations = destinations
                setSelectedTripId(firstValidTrip.id)
            }
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
                    setSelectedTripId(fallbackTrip.id)
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
                setSelectedTripId(nil)
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
            // 清空所有预填充数据，确保普通"添加目的地"页面不会使用打卡功能的预填充数据
            addDestinationPrefill = nil
            pendingPhotoPrefill = nil
            isWaitingForLocation = false
            isGeocodingLocation = false  // 确保清空地理编码状态
            shouldUsePrefillForAddDestination = false  // 确保不使用预填充数据
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
                    if let region = pendingRegion, !autoShowRouteCards || selectedTripId == nil {
                        Task { await fetchDestinationsInRegion(region) }
                    }
                    // 如果正在等待地图到达地点，检查是否已到达
                    if waitingForMapToReachDestination {
                        checkAndTriggerBubbles()
                    }
                }
            }
            .onChange(of: mapSelection) { oldValue, newValue in
                if let newValue = newValue {
                    // 选中标记：直接打开详情页
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDestination = newValue
                        // 同时关闭可能打开的POI预览卡片
                        showingPOIPreview = false
                        selectedPOI = nil
                    }
                    // 直接弹出详情页
                    detailDestinationForSheet = newValue
                } else if oldValue != nil && newValue == nil {
                    // 从标记变为空：用户点击了空白区域取消选择
                    // 同时关闭任何打开的预览卡片
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showingPOIPreview = false
                        selectedPOI = nil
                    }
                }
                // oldValue == nil && newValue == nil 的情况不需要处理
                // （点击空白处但没有之前的选择 = 无操作，符合iPhone地图行为）
            }
            .gesture(longPressGesture(proxy: proxy))
            .simultaneousGesture(tapGesture(proxy: proxy))
            // 当搜索栏显示时，禁用地图交互
            // 在线路卡片模式下，即使卡片显示，地图也应该可以交互（缩放、平移等），只是点击地图不触发 POI 搜索
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
                ? effectiveTrips.filter { $0.id == selectedTripId }
                : effectiveTrips
            
            ForEach(tripsToShow) { trip in
                if let tripDestinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                   tripDestinations.count > 1 {
                    // 当前旅程若为选中且启用了「第几天」筛选，则使用筛选后的目的地与路线
                    let visibleDestinations: [TravelDestination] = (trip.id == selectedTripId)
                        ? visibleDestinationsForSelectedTrip
                        : tripDestinations
                    let routes: [MKRoute?] = (trip.id == selectedTripId)
                        ? visibleRoutesForSelectedTrip.routes
                        : (tripRoutes[trip.id] ?? [])
                    
                    if visibleDestinations.count > 1 {
                        // 检查是否有计算好的路线（至少有一个非nil的路线）
                        let hasValidRoutes = !routes.isEmpty && routes.contains { $0 != nil }
                        
                        if hasValidRoutes {
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
                                            let isNoneTransport = route.footprintTransportType == RouteManager.none
                                            
                                            if isNoneTransport {
                                                // "无"模式：浅灰虚线，用于跨天两地
                                                MapPolyline(route.polyline)
                                                    .stroke(
                                                        routeColor,
                                                        style: StrokeStyle(
                                                            lineWidth: 4,
                                                            lineCap: .round,
                                                            lineJoin: .round,
                                                            dash: [6, 4]
                                                        )
                                                    )
                                            } else {
                                                // 其他交通方式：白色描边 + 主体颜色
                                                MapPolyline(route.polyline)
                                                    .stroke(
                                                        Color.white,
                                                        style: StrokeStyle(
                                                            lineWidth: 7,
                                                            lineCap: .round,
                                                            lineJoin: .round
                                                        )
                                                    )
                                                MapPolyline(route.polyline)
                                                    .stroke(
                                                        routeColor,
                                                        style: StrokeStyle(
                                                            lineWidth: 5,
                                                            lineCap: .round,
                                                            lineJoin: .round
                                                        )
                                                    )
                                            }
                                            
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
                                                            syncTripRoutesToSharedStore()
                                                            // 重新计算该旅程的路线
                                                            // 重新计算时使用整趟行程的坐标，避免覆盖其他天的路线
                                                            let coordinates = sortedDestinations(for: trip.id).map { $0.coordinate }
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
                    weatherSummary: weatherSummary(for: cluster),
                    mapMode: .myFootprints
                )
                .equatable()
                // 性能优化：在线路卡片模式下不请求天气数据，减少计算和网络请求
                .task(id: weatherTaskIdentifier(for: cluster)) {
                    // 主地图模式才请求天气
                    guard !autoShowRouteCards else { return }
                    await requestWeatherIfNeeded(for: cluster)
                }
                .onTapGesture {
                    // 标注本身被点按，短时间内屏蔽地图层的POI轻点逻辑，避免“击穿”
                    annotationTapInProgress = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        annotationTapInProgress = false
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if cluster.destinations.count == 1 {
                            let destination = cluster.destinations.first!
                            // 点击圆圈标注显示弹窗
                            selectedDestination = destination
                            mapSelection = destination
                        } else {
                            zoomToCluster(cluster)
                        }
                    }
                }
            }
        }
    }
    
    private func weatherSummary(for cluster: ClusterAnnotation) -> WeatherSummary? {
        // 性能优化：在线路卡片模式下不显示天气 tag，减少数据更新计算
        guard !autoShowRouteCards else { return nil }
        
        guard cluster.destinations.count == 1,
              let destination = cluster.destinations.first
        else { return nil }
        return destinationWeatherManager.summary(for: destination.id)
    }
    
    private func shouldDisplayWeather(for cluster: ClusterAnnotation) -> Bool {
        // 性能优化：在线路卡片模式下不显示天气
        guard !autoShowRouteCards else { return false }
        return currentZoomLevel >= 10 && cluster.destinations.count == 1
    }
    
    private func weatherTaskIdentifier(for cluster: ClusterAnnotation) -> String {
        "\(cluster.id)-\(currentZoomLevelEnum.rawValue)"
    }
    
    private func requestWeatherIfNeeded(for cluster: ClusterAnnotation) async {
        // 性能优化：在线路卡片模式下不请求天气数据
        guard !autoShowRouteCards else { return }
        
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
                // 在线路卡片模式下禁用长按手势
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
    
    // 轻点手势 - 用于查询系统POI标记信息
    private func tapGesture(proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                // 记录按下时间
                if tapStartTime == nil {
                    tapStartTime = Date()
                }
            }
            .onEnded { value in
                // 在线路卡片模式下禁用轻点 POI 搜索
                if autoShowRouteCards {
                    tapStartTime = nil
                    return
                }
                
                // 如果卡片正在显示，不处理轻点（避免点击穿透）
                if selectedDestination != nil || showingPOIPreview {
                    tapStartTime = nil
                    return
                }
                
                if showSearchBar {
                    tapStartTime = nil
                    return
                }
                
                // 检查按下时长，如果超过0.4秒，认为是长按意图，不处理
                if let startTime = tapStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    tapStartTime = nil
                    if duration >= 0.4 {
                        // 可能是长按，不处理轻点
                        return
                    }
                }
                
                // 检查拖拽距离，如果过大，认为是拖拽操作
                let translation = value.translation
                let dragDistance = hypot(translation.width, translation.height)
                if dragDistance >= 8 {
                    return
                }
                
                // 计算点击对应的地图坐标
                guard let coordinate = proxy.convert(value.location, from: .local) else {
                    return
                }
                let tappedCoordinate = coordinate
                
                // 关键：延迟一点执行POI搜索，给子视图（自定义地点圆圈）的 onTapGesture 一个优先处理的时间窗口，
                // 如果在这段时间内检测到来自标记的点击，就不再触发地图层的POI逻辑，避免“击穿”效果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // 如果刚刚点击了自定义地点标记，跳过本次地图点击，避免“击穿”触发POI弹窗
                    if annotationTapInProgress {
                        return
                    }
                    
                    // 如果此时已经有地点详情或POI卡片在展示，也不再触发新的POI搜索
                    if selectedDestination != nil || showingPOIPreview {
                        return
                    }
                    
                    // 检查点击位置是否接近用户添加的标注或聚合点
                    if isNearAnnotationOrCluster(tappedCoordinate) {
                        // 点击的是用户添加的标记，由 mapSelection / 标记本身处理，不查询POI
                        return
                    }
                    
                    // 轻点地图空白处或系统POI标记，查询POI信息
                    handleMapTap(at: tappedCoordinate)
                }
            }
    }
    
    // 处理地图点击 - 检测POI或地址信息
    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        // 在线路卡片模式下禁用反向地理编码和 POI 搜索
        if autoShowRouteCards {
            print("⏭️ 线路卡片模式：已禁用点击地图的 POI 搜索")
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
    
    // 显示错误回退信息（使用坐标兜底，显示POI预览卡片）
    private func showErrorFallback(coordinate: CLLocationCoordinate2D) {
        // 使用坐标兜底方案，显示POI预览卡片
        fallbackToCoordinatePOI(coordinate: coordinate)
    }
    
    // 地图点击失败时降级为坐标显示（显示POI预览卡片）
    private func fallbackToCoordinatePOI(coordinate: CLLocationCoordinate2D) {
        let mkPlacemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: mkPlacemark)
        
        // 尝试根据坐标判断国家
        let countryName = getCountryNameByCoordinate(coordinate)
        
        // 使用本地化字符串，提供更友好的显示
        mapItem.name = "selected_location".localized
        
        print("🛟 地图点击查询失败，使用坐标降级显示，判断国家: \(countryName)")
        
        // 使用统一函数显示结果（智能处理加载状态）
        showPOIResult(mapItem, message: "✅ 使用坐标信息")
    }
    
    // 根据坐标判断国家名称（使用边界框方法，覆盖主要国家）
    private func getCountryNameByCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // 首先检查是否在中国（使用现有的精确判断）
        if isInChinaBoundingBox(coordinate) {
            return "中国"
        }
        
        // 美国（包含阿拉斯加和夏威夷的粗略范围）
        if lat >= 18.9 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 {
            // 排除加拿大和墨西哥的部分重叠区域
            if !(lat >= 41.7 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 && lat > 49.0) {
                // 美国本土：25°N-49°N, 66°W-125°W
                if lat >= 25.0 && lat <= 49.0 && lon >= -125.0 && lon <= -66.9 {
                    return "美国"
                }
                // 阿拉斯加：51°N-71°N, 130°W-172°W
                if lat >= 51.0 && lat <= 71.5 && lon >= -179.8 && lon <= -130.0 {
                    return "美国"
                }
                // 夏威夷：18.9°N-22.3°N, 154.8°W-160.3°W
                if lat >= 18.9 && lat <= 22.3 && lon >= -160.3 && lon <= -154.8 {
                    return "美国"
                }
            }
        }
        
        // 加拿大
        if lat >= 41.7 && lat <= 83.1 && lon >= -141.0 && lon <= -52.6 {
            return "加拿大"
        }
        
        // 日本
        if lat >= 24.2 && lat <= 45.5 && lon >= 122.9 && lon <= 153.9 {
            return "日本"
        }
        
        // 韩国
        if lat >= 33.1 && lat <= 38.6 && lon >= 124.6 && lon <= 132.0 {
            return "韩国"
        }
        
        // 英国
        if lat >= 49.9 && lat <= 60.8 && lon >= -8.6 && lon <= 1.8 {
            return "英国"
        }
        
        // 法国
        if lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6 {
            return "法国"
        }
        
        // 德国
        if lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0 {
            return "德国"
        }
        
        // 意大利
        if lat >= 36.6 && lat <= 47.1 && lon >= 6.6 && lon <= 18.5 {
            return "意大利"
        }
        
        // 西班牙
        if lat >= 35.2 && lat <= 43.8 && lon >= -9.3 && lon <= 4.3 {
            return "西班牙"
        }
        
        // 澳大利亚
        if lat >= -43.6 && lat <= -10.7 && lon >= 113.3 && lon <= 153.6 {
            return "澳大利亚"
        }
        
        // 新西兰
        if lat >= -47.3 && lat <= -34.4 && lon >= 166.5 && lon <= 178.6 {
            return "新西兰"
        }
        
        // 巴西
        if lat >= -33.7 && lat <= 5.3 && lon >= -73.0 && lon <= -32.0 {
            return "巴西"
        }
        
        // 印度
        if lat >= 6.8 && lat <= 35.7 && lon >= 68.1 && lon <= 97.4 {
            return "印度"
        }
        
        // 俄罗斯（主要部分）
        if lat >= 41.2 && lat <= 81.2 && lon >= 19.6 && lon <= 180.0 {
            // 排除欧洲其他国家
            if !(lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0) { // 德国
                if !(lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6) { // 法国
                    if lon >= 19.6 {
                        return "俄罗斯"
                    }
                }
            }
        }
        
        // 如果无法判断，返回未知国家
        return "unknown_country".localized
    }
    
    // 根据坐标判断国家枚举（用于获取本地化名称）
    private func getCountryByCoordinate(_ coordinate: CLLocationCoordinate2D) -> CountryManager.Country? {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // 首先检查是否在中国（使用现有的精确判断）
        if isInChinaBoundingBox(coordinate) {
            return .china
        }
        
        // 美国（包含阿拉斯加和夏威夷的粗略范围）
        if lat >= 18.9 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 {
            // 排除加拿大和墨西哥的部分重叠区域
            if !(lat >= 41.7 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 && lat > 49.0) {
                // 美国本土：25°N-49°N, 66°W-125°W
                if lat >= 25.0 && lat <= 49.0 && lon >= -125.0 && lon <= -66.9 {
                    return .unitedStates
                }
                // 阿拉斯加：51°N-71°N, 130°W-172°W
                if lat >= 51.0 && lat <= 71.5 && lon >= -179.8 && lon <= -130.0 {
                    return .unitedStates
                }
                // 夏威夷：18.9°N-22.3°N, 154.8°W-160.3°W
                if lat >= 18.9 && lat <= 22.3 && lon >= -160.3 && lon <= -154.8 {
                    return .unitedStates
                }
            }
        }
        
        // 加拿大
        if lat >= 41.7 && lat <= 83.1 && lon >= -141.0 && lon <= -52.6 {
            return .canada
        }
        
        // 日本
        if lat >= 24.2 && lat <= 45.5 && lon >= 122.9 && lon <= 153.9 {
            return .japan
        }
        
        // 韩国
        if lat >= 33.1 && lat <= 38.6 && lon >= 124.6 && lon <= 132.0 {
            return .southKorea
        }
        
        // 英国
        if lat >= 49.9 && lat <= 60.8 && lon >= -8.6 && lon <= 1.8 {
            return .unitedKingdom
        }
        
        // 法国
        if lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6 {
            return .france
        }
        
        // 德国
        if lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0 {
            return .germany
        }
        
        // 意大利
        if lat >= 36.6 && lat <= 47.1 && lon >= 6.6 && lon <= 18.5 {
            return .italy
        }
        
        // 西班牙
        if lat >= 35.2 && lat <= 43.8 && lon >= -9.3 && lon <= 4.3 {
            return .spain
        }
        
        // 澳大利亚
        if lat >= -43.6 && lat <= -10.7 && lon >= 113.3 && lon <= 153.6 {
            return .australia
        }
        
        // 新西兰
        if lat >= -47.3 && lat <= -34.4 && lon >= 166.5 && lon <= 178.6 {
            return .newZealand
        }
        
        // 巴西
        if lat >= -33.7 && lat <= 5.3 && lon >= -73.0 && lon <= -32.0 {
            return .brazil
        }
        
        // 印度
        if lat >= 6.8 && lat <= 35.7 && lon >= 68.1 && lon <= 97.4 {
            return .india
        }
        
        // 俄罗斯（主要部分）
        if lat >= 41.2 && lat <= 81.2 && lon >= 19.6 && lon <= 180.0 {
            // 排除欧洲其他国家
            if !(lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0) { // 德国
                if !(lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6) { // 法国
                    if lon >= 19.6 {
                        return .russia
                    }
                }
            }
        }
        
        // 如果无法判断，返回 nil
        return nil
    }
    
    // 根据坐标获取本地化的国家名称（根据app语言环境调整）
    private func getLocalizedCountryNameByCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        if let country = getCountryByCoordinate(coordinate) {
            return CountryManager.shared.getLocalizedCountryName(for: country)
        }
        return "unknown_country".localized
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
                    // 再次失败时降级为坐标显示（POI预览卡片）
                    self.fallbackToCoordinatePOI(coordinate: coordinate)
                }
            }
        }
    }
    
    // 消失覆盖层
    @ViewBuilder
    private var dismissOverlay: some View {
        if showingPOIPreview || selectedDestination != nil {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        if showingPOIPreview {
                            showingPOIPreview = false
                            selectedPOI = nil
                        }
                        if selectedDestination != nil {
                            selectedDestination = nil
                            mapSelection = nil
                        }
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
            if showingPOIPreview, let poi = selectedPOI {
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
    
    // 线路卡片覆盖层（使用可拖拽抽屉）
    private var routeCardsOverlay: some View {
        Group {
            if showRouteCards {
                let showDayBar = selectedTripId != nil && selectedTripDayGroups.count > 1 && !mapViewInNavigationStack
                if showDayBar || showJourneyDrawer {
                    VStack(spacing: 0) {
                        Spacer()
                        // 「第几天」筛选：多日行程时显示；在导航栈内时改由导航栏标题位显示，此处不重复
                        if showDayBar {
                            journeyDayFilterBar
                        }
                        if showJourneyDrawer {
                            JourneyDrawer(
                                trips: effectiveTrips,
                                tripRoutes: tripRoutes,
                                sortedDestinations: { tripId in
                                    sortedDestinations(for: tripId)
                                },
                                selectedTripId: selectedTripIdBindingForSubviews,
                                scrollPosition: $scrollPosition,
                                onTripSelected: { trip, destinations in
                                    handleCardAppear(trip: trip, destinations: destinations)
                                },
                                onCardTap: { trip in
                                    // 点击路线卡片，直接打开详情页
                                    detailTripForSheet = trip
                                    showingTripDetail = true
                                },
                                hasMoreTrips: hasMoreTrips,
                                onLoadMoreTrips: onLoadMoreTrips
                            )
                        }
                    }
                    .opacity(shouldHideRouteCards ? 0 : 1)
                    .allowsHitTesting(!shouldHideRouteCards)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .zIndex(3)
    }
    
    /// 「第几天」筛选条：放在旅程卡片上方，多日时显示下拉
    @ViewBuilder
    private var journeyDayFilterBar: some View {
        let allTitle = "all".localized
        Menu {
            Button {
                setSelectedDayFilter(nil)
                if let tripId = selectedTripId {
                    let dests = sortedDestinations(for: tripId)
                    zoomToTripDestinations(dests)
                }
            } label: {
                Label(allTitle, systemImage: selectedDayFilter == nil ? "checkmark.circle.fill" : "circle")
            }
            ForEach(selectedTripDayGroups, id: \.dayStart) { group in
                Button {
                    setSelectedDayFilter(group.dayIndex)
                    zoomToTripDestinations(group.destinations)
                } label: {
                    let title = String(format: "trip_route_day_title".localized, group.dayIndex, group.dayStart.localizedFormatted(dateStyle: .medium))
                    Label(title, systemImage: selectedDayFilter == group.dayIndex ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                if let dayIndex = selectedDayFilter,
                   let group = selectedTripDayGroups.first(where: { $0.dayIndex == dayIndex }) {
                    Text(String(format: "trip_route_day_title".localized, group.dayIndex, group.dayStart.localizedFormatted(dateStyle: .medium)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(allTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // 处理卡片出现（切换地图视图和连线）
    private func handleCardAppear(trip: TravelTrip, destinations: [TravelDestination]) {
        // 如果已经是当前选中的旅程，直接返回
        if selectedTripId == trip.id {
            return
        }
        
        print("🔄 切换到旅程: \(trip.name)，包含 \(destinations.count) 个地点")
        
        // 使用 DispatchQueue.main.async 确保不在视图更新期间修改状态
        // 这样可以避免 "Modifying state during view update" 警告和循环更新
        DispatchQueue.main.async {
            // 更新选中状态；切换旅程时清除「第几天」筛选
            setSelectedTripId(trip.id)
            setSelectedDayFilter(nil)
            selectionFeedbackGenerator.selectionChanged()
            selectionFeedbackGenerator.prepare()
            
            // 如果在线路tab，清除聚合缓存，以便重新计算只显示当前线路的地点
            // 注意：在缩放地图之前清除缓存，确保后续的聚合计算基于新的旅程地点
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
            // 注意：地图缩放会触发 onMapCameraChange，进而更新 visibleRegion
            // visibleRegion 的更新是防抖的（0.3秒），所以聚合计算会在区域更新后自动触发
            zoomToTripDestinations(destinations)
            
            // 延迟计算路线，避免与地图缩放冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 确保该旅程的路线已计算（如果还没有计算，使用incremental模式检查缓存）
                if tripRoutes[trip.id] == nil || tripRoutes[trip.id]?.isEmpty == true {
                    let coordinates = destinations.map { $0.coordinate }
                    Task {
                        await calculateRoutesForTrip(tripId: trip.id, coordinates: coordinates, incremental: true)
                    }
                }
            }
        }
    }
    
    // 获取排序后的地点列表（带缓存，避免重复排序）
    private func sortedDestinations(for tripId: UUID) -> [TravelDestination] {
        // 检查缓存
        if let cached = sortedDestinationsCache[tripId] {
            return cached
        }
        
        // 查找旅程并排序
        if let trip = effectiveTrips.first(where: { $0.id == tripId }),
           let destinations = trip.destinations {
            let sorted = destinations.sorted(by: { $0.visitDate < $1.visitDate })
            // 延迟写入缓存，避免在视图更新期间修改 @State（消除 "Modifying state during view update" 并防止多余重绘）
            let tid = tripId
            DispatchQueue.main.async {
                sortedDestinationsCache[tid] = sorted
            }
            return sorted
        }
        
        return []
    }
    
    // 清除排序缓存（当地点发生变化时调用）
    private func clearSortedDestinationsCache(for tripId: UUID? = nil) {
        if let tripId = tripId {
            sortedDestinationsCache.removeValue(forKey: tripId)
        } else {
            sortedDestinationsCache.removeAll()
        }
    }
    
    /// 当前选中旅程按天分组（用于「第几天」筛选）
    private var selectedTripDayGroups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] {
        guard let tripId = selectedTripId,
              let trip = effectiveTrips.first(where: { $0.id == tripId }),
              let dests = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }), !dests.isEmpty else {
            return []
        }
        let calendar = Calendar.current
        var groups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] = []
        var currentDayStart: Date?
        var currentList: [TravelDestination] = []
        for d in dests {
            let dayStart = calendar.startOfDay(for: d.visitDate)
            if dayStart != currentDayStart {
                if let prev = currentDayStart { groups.append((groups.count + 1, prev, currentList)) }
                currentDayStart = dayStart
                currentList = [d]
            } else {
                currentList.append(d)
            }
        }
        if let last = currentDayStart { groups.append((groups.count + 1, last, currentList)) }
        return groups
    }
    
    /// 当前选中旅程、考虑「第几天」筛选后的目的地列表（用于连线和标注）
    private var visibleDestinationsForSelectedTrip: [TravelDestination] {
        guard let tripId = selectedTripId else { return [] }
        let sorted = sortedDestinations(for: tripId)
        guard !sorted.isEmpty else { return [] }
        guard let dayIndex = selectedDayFilter,
              let group = selectedTripDayGroups.first(where: { $0.dayIndex == dayIndex }) else {
            return sorted
        }
        return group.destinations
    }
    
    /// 当前选中旅程、考虑「第几天」筛选后的路线段（与 visibleDestinationsForSelectedTrip 对应）
    private var visibleRoutesForSelectedTrip: (destinations: [TravelDestination], routes: [MKRoute?]) {
        let allSorted = sortedDestinations(for: selectedTripId ?? UUID())
        guard let tripId = selectedTripId, !allSorted.isEmpty else { return ([], []) }
        guard let dayIndex = selectedDayFilter,
              let group = selectedTripDayGroups.first(where: { $0.dayIndex == dayIndex }) else {
            let routes = tripRoutes[tripId] ?? []
            return (allSorted, routes)
        }
        let dayDests = group.destinations
        guard dayDests.count >= 2 else { return (dayDests, []) }
        let startIndex = allSorted.firstIndex(where: { $0.id == dayDests.first!.id }) ?? 0
        let fullRoutes = tripRoutes[tripId] ?? []
        let segmentCount = dayDests.count - 1
        let routeSlice = (0..<segmentCount).map { i in
            let idx = startIndex + i
            return idx < fullRoutes.count ? fullRoutes[idx] : nil as MKRoute?
        }
        return (dayDests, routeSlice)
    }
    
    // 清除聚合缓存（用于旅程切换等）
    private var floatingButtons: some View {
        ZStack {
            // 顶部地图样式切换按钮（与“发现”tab保持一致）；嵌入 NavigationStack 时由父视图导航栏 leading 放置，此处不显示
            if !showSearchBar, !mapViewInNavigationStack {
                VStack {
                    topToolbar
                    Spacer()
                }
            }
            
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
    
    // 顶部工具栏：地图样式切换按钮（与嵌入导航栏中的按钮一致：LinearGradient 图标 + 与导航栏相同的 .bar 背景）
    private var topToolbar: some View {
        HStack {
            Button {
                // 循环切换地图样式
                let styles = MapStyle.allCases
                if let currentIndex = styles.firstIndex(of: currentMapStyle),
                   currentIndex < styles.count - 1 {
                    mapStyleRawValue = styles[currentIndex + 1].rawValue
                } else {
                    mapStyleRawValue = styles[0].rawValue
                }
            } label: {
                if #available(iOS 26, *) {
                    Image(systemName: currentMapStyle.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .contentShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                } else {
                    Image(systemName: currentMapStyle.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .fill((isDarkMapStyle ? Color.white.opacity(0.12) : Color.white.opacity(0.85)))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(isDarkMapStyle ? 0.25 : 0.35), lineWidth: 1)
                                )
                        )
                        .contentShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
            }
            .accessibilityLabel("map_button_style".localized)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        // 无额外 top padding，紧贴安全区顶部（此前上方废弃的旅程按钮已移除）
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
                            .glassEffect(GlassEffectStyle.regular, in: Circle())
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
        .modifier(AccessibilityHintModifier(hint: checkInAccessibilityHint))
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
                        .glassEffect(GlassEffectStyle.regular, in: Circle())
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
                id: "ai",
                icon: "sparkles",
                title: "map_button_ai".localized,
                isActive: showingAIAssistant,
                action: {
                    handleAIAssistant()
                }
            ),
            AssistiveMenuAction(
                id: "import_photo",
                icon: "photo.badge.plus",
                title: "map_button_import_photo".localized,
                isActive: false,
                action: {
                    handleFootprintsImport()
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
                id: "locate",
                icon: "location.fill",
                title: "map_button_locate".localized,
                isActive: false,
                action: {
                    centerMapOnCurrentLocation()
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
            ),
            AssistiveMenuAction(
                id: "check_in",
                icon: "DakaIcon",
                title: "map_button_check_in".localized,
                isActive: false,
                action: {
                    handleCheckIn()
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
            return AnyView(
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundColor(buttonIconColor(isActive: isActive))
                    .frame(width: 22, height: 22)
            )
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
                HStack(spacing: 5) {
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
                        .font(.system(size: 18)) // 进一步缩小图标：从24改为18
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
                                mapStyleRawValue = style.rawValue
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
            // 使用 .id 确保 prefill 从 nil 变为有值时 SwiftUI 会重建视图，从而正确应用预填数据
            let idKey: String = {
                let name = prefill.name ?? ""
                guard let loc = prefill.location else { return name.isEmpty ? UUID().uuidString : name }
                let c = loc.placemark.coordinate
                return "\(name)-\(c.latitude)-\(c.longitude)"
            }()
            QuickCheckInView(prefill: prefill)
                .id(idKey)
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
    
    // 普通"添加目的地"弹窗内容
    @ViewBuilder
    private var addDestinationSheet: some View {
        // 只有在明确标记应该使用预填充数据时才使用（例如照片导入）
        // 普通"添加目的地"功能不使用自动地理编码的残留数据
        if shouldUsePrefillForAddDestination, let prefill = addDestinationPrefill {
            AddDestinationView(prefill: prefill, mapRegion: visibleRegion)
        } else if isGeocodingLocation && shouldUsePrefillForAddDestination {
            // 只有在明确需要预填充时才显示加载状态（例如照片导入正在地理编码）
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
            // 普通"添加目的地"：显示空页面，不使用预填充数据
            AddDestinationView(mapRegion: visibleRegion)
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
        for trip in effectiveTrips {
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
    
    // 获取屏幕可见区域内的地点（优化：有按区域拉取结果时直接用，否则再在内存中过滤全量）
    private var visibleDestinationsInRegion: [TravelDestination] {
        // 如果在线路tab且选中了线路卡片，只显示该线路的地点（并考虑「第几天」筛选）
        if autoShowRouteCards, selectedTripId != nil {
            return visibleDestinationsForSelectedTrip
        }
        
        // 有按可见区域拉取的结果且区域键一致时，直接使用，避免对全量 destinations 做 filter
        if let inRegion = destinationsInVisibleRegion, visibleRegionKeyForFetch == visibleRegionKey {
            return inRegion
        }
        
        guard let region = visibleRegion else {
            return destinationsForCurrentMapMode
        }
        
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        let margin = max(region.span.latitudeDelta, region.span.longitudeDelta) * 0.1
        let expandedMinLat = minLat - margin
        let expandedMaxLat = maxLat + margin
        let expandedMinLon = minLon - margin
        let expandedMaxLon = maxLon + margin
        
        return destinationsForCurrentMapMode.filter { destination in
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
        // 如果在线路tab，包含选中的旅程ID和按天筛选，以便在切换线路/天时重新计算
        let tripIdSuffix = autoShowRouteCards ? (selectedTripId?.uuidString ?? "nil") : "all"
        let daySuffix = (autoShowRouteCards && selectedDayFilter != nil) ? "\(selectedDayFilter!)" : "all"
        return "\(centerLat),\(centerLon),\(spanLat),\(spanLon),\(tripIdSuffix),\(daySuffix)"
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
        
        // 如果缓存失效，触发异步更新
        // 如果正在计算，直接返回旧缓存，避免重复触发
        if isCalculatingClusters {
            return cachedClusterAnnotations
        }
        
        // 如果旧缓存为空且可见地点也为空，直接返回空数组（避免不必要的计算）
        if cachedClusterAnnotations.isEmpty && visibleDestinations.isEmpty {
            return []
        }
        
        // 如果旧缓存不为空，先返回旧缓存，然后异步更新
        let oldCache = cachedClusterAnnotations
        
        // 标记正在计算
        isCalculatingClusters = true
        
        // 创建新的异步计算任务
        // 捕获当前值，避免在异步任务中访问计算属性导致循环
        let capturedZoomEnum = currentZoomEnum
        let capturedDestinations = visibleDestinations
        let capturedCount = currentCount
        let capturedRegionKey = currentRegionKey
        let capturedDistance = clusterDistance
        
        // 使用 DispatchQueue 异步执行计算
        // 注意：捕获 destinations 用于日志输出
        let capturedTotalDestinations = destinations.count
        DispatchQueue.main.async {
            // 再次检查缓存是否仍然失效（可能在异步等待期间已经更新）
            // 注意：这里使用捕获的值进行比较，避免在异步块中访问计算属性导致循环依赖
            // 如果缓存已经更新（由其他计算任务完成），则取消本次计算
            if !cachedClusterAnnotations.isEmpty &&
               cachedZoomLevelEnum == capturedZoomEnum &&
               cachedDestinationsCount == capturedCount &&
               cachedVisibleRegionKey == capturedRegionKey {
                // 缓存已经更新，不需要重新计算
                isCalculatingClusters = false
                return
            }
            
            // 性能监控：记录计算开始时间
            let startTime = Date()
            
            // 使用捕获的值进行计算（避免访问计算属性）
            var clusters: [ClusterAnnotation] = []
            
            // 如果聚合距离为0，返回所有单独的点
            if capturedDistance == 0 {
                clusters = capturedDestinations.map { ClusterAnnotation(destinations: [$0]) }
            } else {
                // 优化的聚合算法：减少重复计算
                clusters = calculateClustersOptimized(distance: capturedDistance, from: capturedDestinations)
            }
            
            // 更新缓存（使用捕获的值）
            cachedClusterAnnotations = clusters
            cachedZoomLevelEnum = capturedZoomEnum
            cachedDestinationsCount = capturedCount
            cachedVisibleRegionKey = capturedRegionKey
            lastCalculationTime = Date()
            isCalculatingClusters = false
            
            // 性能监控：记录计算耗时和级别变化
            let calculationTime = Date().timeIntervalSince(startTime)
            print("🔄 聚合计算完成: \(capturedZoomEnum.description)级别, 耗时: \(String(format: "%.3f", calculationTime))秒, 可见地点: \(capturedCount)/\(capturedTotalDestinations)个")
        }
        
        // 如果旧缓存不为空，返回旧缓存；否则返回空数组，等待异步任务完成
        return oldCache
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
        // 重置计算标志
        isCalculatingClusters = false
        
        // 同步清除缓存，确保立即生效，避免异步导致的竞态条件
        // 注意：这个函数通常在 DispatchQueue.main.async 中调用，所以直接修改状态是安全的
        cachedClusterAnnotations = []
        cachedZoomLevelEnum = .world
        cachedDestinationsCount = 0
        cachedVisibleRegionKey = ""
        lastCalculationTime = Date()
        print("🧹 已清除聚合缓存")
    }
    
    /// 与 `JourneyDrawer` / `TripRoutePrecomputationStore` 同步，使「旅程卡片」总里程与地图 `tripRoutes` 一致
    private func syncTripRoutesToSharedStore() {
        TripRoutePrecomputationStore.shared.sync(from: tripRoutes)
    }
    
    // 处理地点变化（立即更新路线）
    private func handleDestinationsChange() {
        print("🔄 处理地点变化，重新计算路线...")
        // 清除聚合缓存
        clearClusterCache()
        // 清除排序缓存（地点变化后需要重新排序）
        clearSortedDestinationsCache()
        // 清除路线缓存，强制重新计算
        tripRoutes.removeAll()
        syncTripRoutesToSharedStore()
        
        // 如果在线路tab，只计算当前选中旅程的路线
        if autoShowRouteCards {
            if let selectedTripId = selectedTripId,
               let selectedTrip = effectiveTrips.first(where: { $0.id == selectedTripId }),
               let tripDestinations = selectedTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
               tripDestinations.count >= 2 {
                let coordinates = tripDestinations.map { $0.coordinate }
                Task {
                    // 强制重新计算（不使用缓存）
                    await calculateRoutesForTrip(tripId: selectedTripId, coordinates: coordinates, incremental: false)
                }
            } else if let selectedTripId = selectedTripId {
                // 如果选中线路的地点数量不足2个，清除该线路的路线
                tripRoutes.removeValue(forKey: selectedTripId)
                syncTripRoutesToSharedStore()
            }
        } else {
            // 如果显示连线，重新计算所有路线（地图 tab）
            if showTripConnections {
                calculateRoutesForAllTrips()
            }
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
        
        for trip in effectiveTrips {
            guard let tripDestinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
                  tripDestinations.count >= 2 else {
                continue
            }
            
            let coordinates = tripDestinations.map { $0.coordinate }
            
            // 检查是否需要重新计算（增量更新）
            // 如果路线数量匹配，检查所有路线是否都在缓存中
            if let existingRoutes = tripRoutes[trip.id],
               existingRoutes.count == coordinates.count - 1 {
                // 检查所有路线段是否都在缓存中（考虑交通方式）
                var allCached = true
                for i in 0..<coordinates.count - 1 {
                    let source = coordinates[i]
                    let destination = coordinates[i + 1]
                    
                    // 获取用户选择的交通方式（如果有），否则使用默认机动车
                    let userTransportType = routeManager.getUserTransportType(from: source, to: destination)
                    let transportType = userTransportType ?? .automobile
                    
                    if routeManager.getCachedRoute(
                        from: source,
                        to: destination,
                        transportType: transportType
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
                
                // 获取用户选择的交通方式（如果有），否则使用默认机动车
                let userTransportType = routeManager.getUserTransportType(from: source, to: destination)
                let transportType = userTransportType ?? .automobile
                
                // 检查缓存（RouteManager 会根据交通方式自动匹配）
                if let cachedRoute = routeManager.getCachedRoute(
                    from: source,
                    to: destination,
                    transportType: transportType
                ) {
                    // 缓存命中，直接使用
                    calculatedRoutes[i] = cachedRoute
                }
            }
            
            // 如果所有路线都已缓存且都合适，直接更新 UI
            let allCached = calculatedRoutes.allSatisfy { $0 != nil }
            if allCached {
                await MainActor.run {
                    // 保持 [MKRoute?] 格式，不进行 compactMap，以保持索引对应关系
                    tripRoutes[tripId] = calculatedRoutes
                    syncTripRoutesToSharedStore()
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
                    // 获取用户选择的交通方式（如果有），否则使用默认机动车
                    let userTransportType = self.routeManager.getUserTransportType(from: source, to: destination)
                    let transportType = userTransportType ?? .automobile
                    
                    // 使用 async/await 版本，性能更好
                    let route = await self.routeManager.calculateRoute(from: source, to: destination, transportType: transportType)
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
                        syncTripRoutesToSharedStore()
                    }
                }
            }
        }
        
        // 最终更新：确保所有路线都已显示
        await MainActor.run {
            // 保持 [MKRoute?] 格式，不进行 compactMap，以保持索引对应关系
            tripRoutes[tripId] = calculatedRoutes
            syncTripRoutesToSharedStore()
            let successCount = calculatedRoutes.compactMap { $0 }.count
            print("✅ 旅程 \(tripId.uuidString.prefix(8)) 的路线计算完成，共 \(successCount)/\(coordinates.count - 1) 段路线")
        }
    }
    
    /// 重试失败的路线计算（占位线重试机制）
    /// - Parameters:
    ///   - tripId: 旅程ID
    ///   - coordinates: 旅程地点坐标数组
    private func retryFailedRoutesForTrip(tripId: UUID, coordinates: [CLLocationCoordinate2D]) async {
        guard coordinates.count >= 2 else { return }
        
        // 获取当前路线状态
        guard let currentRoutes = tripRoutes[tripId],
              currentRoutes.count == coordinates.count - 1 else {
            // 如果路线还未计算，直接调用正常计算流程
            await calculateRoutesForTrip(tripId: tripId, coordinates: coordinates, incremental: true)
            return
        }
        
        // 找出失败的路线（nil 值）
        var routesToRetry: [(Int, CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        for i in 0..<coordinates.count - 1 {
            if currentRoutes[i] == nil {
                routesToRetry.append((i, coordinates[i], coordinates[i + 1]))
            }
        }
        
        guard !routesToRetry.isEmpty else {
            // 没有失败的路线，无需重试
            return
        }
        
        print("🔄 重试 \(routesToRetry.count) 段失败的路线...")
        
        // 并发重试失败的路线
        await withTaskGroup(of: (Int, MKRoute?).self) { group in
            for (index, source, destination) in routesToRetry {
                group.addTask {
                    // 获取用户选择的交通方式（如果有），否则使用默认机动车
                    let userTransportType = self.routeManager.getUserTransportType(from: source, to: destination)
                    let transportType = userTransportType ?? .automobile
                    
                    // 重试计算路线
                    let route = await self.routeManager.calculateRoute(from: source, to: destination, transportType: transportType)
                    return (index, route)
                }
            }
            
            // 收集结果并更新 UI
            for await (index, route) in group {
                await MainActor.run {
                    // 更新对应索引的路线
                    if tripRoutes[tripId] != nil && index < tripRoutes[tripId]!.count {
                        tripRoutes[tripId]![index] = route
                        syncTripRoutesToSharedStore()
                    }
                }
            }
        }
        
        await MainActor.run {
            let successCount = tripRoutes[tripId]?.compactMap { $0 }.count ?? 0
            syncTripRoutesToSharedStore()
            print("✅ 重试完成，共 \(successCount)/\(coordinates.count - 1) 段路线")
        }
    }
    
    // 处理长按手势 - 显示地址信息（路名和门牌号）
    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        // 在线路卡片模式下禁用反向地理编码
        if autoShowRouteCards {
            print("⏭️ 线路卡片模式：已禁用长按反向地理编码")
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
                    // 失败时降级为坐标显示
                    self.fallbackToCoordinateForLongPress(coordinate: coordinate, error: error)
                }
            }
        }
    }
    
    // 长按失败时降级为坐标显示
    private func fallbackToCoordinateForLongPress(coordinate: CLLocationCoordinate2D, error: Error?) {
        let mkPlacemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: mkPlacemark)
        
        // 使用本地化字符串，提供更友好的显示
        mapItem.name = "selected_location".localized
        
        // 记录错误信息（但不影响降级显示）
        if let error = error {
            let errorDescription = error.localizedDescription
            print("❌ 长按反向地理编码失败，使用坐标降级: \(errorDescription)")
            
            // 检查是否是节流错误
            if let nsError = error as NSError?,
               nsError.domain == "GEOErrorDomain" && nsError.code == -3 {
                print("⚠️ 地理编码服务被节流，已降级为坐标显示")
            }
        } else {
            print("⚠️ 长按反向地理编码返回空结果，使用坐标降级")
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.selectedPOI = mapItem
            self.showingPOIPreview = true
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
        
        // 如果placemark没有国家信息，尝试根据坐标判断国家（使用本地化名称）
        var countryName = placemark.country ?? ""
        if countryName.isEmpty || countryName == "unknown_country".localized {
            countryName = getLocalizedCountryNameByCoordinate(placemark.coordinate)
            print("📍 使用坐标判断国家（本地化）: \(countryName)")
        }
        if countryName.isEmpty {
            countryName = "unknown_country".localized
        }
        
        // 根据国家名称判断分类（支持本地化名称）
        let isoCountryCode = placemark.isoCountryCode ?? ""
        let category: String
        if isoCountryCode == "CN" {
            category = "domestic"
        } else if CountryManager.shared.isDomestic(country: countryName) {
            category = "domestic"
        } else {
            category = "international"
        }
        
        // 设置预填充数据并显示快速打卡界面
        isWaitingForLocation = false
        pendingPhotoPrefill = nil
        updateAddDestinationPrefill(
            mapItem: poi,
            name: locationName,
            country: countryName,
            category: category
        )
        // 延迟到下一 run loop 再呈现 sheet，确保 addDestinationPrefill 已提交，避免弹窗内容为空（首次添加时）
        DispatchQueue.main.async {
            self.showingQuickCheckIn = true
        }
    }
    
    // 处理打卡功能：使用用户当前位置添加目的地
    private func handleCheckIn() {
        print("📍 点击打卡按钮")
        checkInFeedbackGenerator.impactOccurred()
        
        // 检查是否有已知位置
        if let userLocation = locationManager.lastKnownLocation {
            print("✅ 使用已知位置进行打卡: (\(userLocation.latitude), \(userLocation.longitude))")
            
            isGeocodingLocation = true  // 先显示加载状态，避免首帧出现空表单
            // 在下一帧显示添加目的地界面，避免第一次呈现时使用旧的模式状态
            DispatchQueue.main.async {
                self.showingQuickCheckIn = true
            }
            
            // 执行反向地理编码
            reverseGeocodeLocation(coordinate: userLocation, forAddDestinationPrefill: true)
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
            prefill.suggestedPlaceType = pending.suggestedPlaceType
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
    
    private func tryUseCachedPlacemark(for coordinate: CLLocationCoordinate2D, updatePrefill: Bool = true) -> Bool {
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
            applyGeocodeResult(cachedPlacemark, coordinate: coordinate, source: .cached, updatePrefill: updatePrefill)
            print("♻️ 直接复用缓存的地理编码结果，距离 \(Int(distance))m，缓存时间 \(Int(Date().timeIntervalSince(cachedTime)))s")
            return true
        }
        return false
    }
    
    private func applyGeocodeResult(_ placemark: CLPlacemark, coordinate: CLLocationCoordinate2D, source: GeocodeResultSource = .live, updatePrefill: Bool = true) {
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
        
        let countryName = resolvedCountryName(from: placemark)
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
        
        // 仅当本次地理编码是为「添加目的地/打卡」发起的才更新预填充，避免启动时的自动定位覆盖用户即将添加的地点
        guard updatePrefill else { return }
        
        // 使用本次查询坐标作为锚点；CLPlacemark.location 常偏向路网/区块中心，与照片 EXIF 或选点不一致
        let mapItem = mkMapItemForPrefill(
            displayCoordinate: coordinate,
            placemark: placemark,
            locationName: locationName
        )
        updateAddDestinationPrefill(
            mapItem: mapItem,
            name: locationName,
            country: countryName,
            category: category
        )
    }
    
    /// 境外反向地理编码常见：`country` 为空但 `isoCountryCode` 有值（如 MY），需本地化展示。
    private func resolvedCountryName(from placemark: CLPlacemark) -> String {
        if let c = placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        if let iso = placemark.isoCountryCode, !iso.isEmpty {
            return Locale.current.localizedString(forRegionCode: iso) ?? iso
        }
        return "unknown_country".localized
    }
    
    /// 预填/保存用的 `MKMapItem`：锚点用查询坐标；国家/州/市从 `CLPlacemark` 写入 `CNPostalAddress`。
    /// 境外常无 `postalAddress`，若仅用 `MKPlacemark(coordinate:)` 会导致国家、行政区空白（未知国家、省份为空）。
    private func mkMapItemForPrefill(
        displayCoordinate: CLLocationCoordinate2D,
        placemark: CLPlacemark,
        locationName: String
    ) -> MKMapItem {
        let postal: CNPostalAddress = {
            let m: CNMutablePostalAddress
            if let existing = placemark.postalAddress {
                m = existing.mutableCopy() as! CNMutablePostalAddress
            } else {
                m = CNMutablePostalAddress()
            }
            if m.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let s = placemark.administrativeArea, !s.isEmpty {
                m.state = s
            }
            if m.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let s = placemark.locality, !s.isEmpty {
                m.city = s
            }
            if m.subLocality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let s = placemark.subLocality, !s.isEmpty {
                m.subLocality = s
            }
            if m.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let parts = [placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.filter { !$0.isEmpty }
                if !parts.isEmpty {
                    m.street = parts.joined(separator: " ")
                }
            }
            if m.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let iso = placemark.isoCountryCode, !iso.isEmpty {
                    m.isoCountryCode = iso
                    m.country = Locale.current.localizedString(forRegionCode: iso) ?? iso
                } else if let c = placemark.country, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    m.country = c
                }
            }
            if m.isoCountryCode.isEmpty, let iso = placemark.isoCountryCode, !iso.isEmpty {
                m.isoCountryCode = iso
            }
            return m
        }()
        let mk = MKPlacemark(coordinate: displayCoordinate, postalAddress: postal)
        let item = MKMapItem(placemark: mk)
        item.name = locationName
        return item
    }
    
    // 反向地理编码：获取城市和国家信息（带多重回退和优化）
    // forAddDestinationPrefill：为 true 时才更新 addDestinationPrefill（打卡/照片导入等）；启动或定位更新触发的编码不更新预填，避免覆盖用户即将添加的地点
    private func reverseGeocodeLocation(coordinate: CLLocationCoordinate2D, force: Bool = false, forAddDestinationPrefill: Bool = false) {
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
        
        if !force, tryUseCachedPlacemark(for: coordinate, updatePrefill: forAddDestinationPrefill) {
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
                self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
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
                self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
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
                self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
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
            self.isGeocodingLocation = false
            self.pendingGeocodeCoordinate = nil
            self.geocodeTimeoutTimer = nil
            // 使用备用搜索
            self.fallbackSearchAround(coordinate: coordinate, forAddDestinationPrefill: forAddDestinationPrefill)
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
                        self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
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
                        self.applyGeocodeResult(placemark, coordinate: coordinate, updatePrefill: forAddDestinationPrefill)
                    }
                    return
                }
                geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN")) { placemarks, _ in
                    if let placemark = placemarks?.first {
                        DispatchQueue.main.async {
                            self.applyGeocodeResult(placemark, coordinate: coordinate, updatePrefill: forAddDestinationPrefill)
                        }
                        return
                    }
                    // 继续回退到附近搜索
                    DispatchQueue.main.async {
                        self.pendingGeocodeCoordinate = nil
                        self.isGeocodingLocation = false
                        self.fallbackSearchAround(coordinate: coordinate, forAddDestinationPrefill: forAddDestinationPrefill)
                    }
                }
            }
        }

        // 7. 执行地理编码请求
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.applyGeocodeResult(placemark, coordinate: coordinate, updatePrefill: forAddDestinationPrefill)
                }
                return
            }
            DispatchQueue.main.async { handleError(error) }
        }
    }

    // 备用方案1：在坐标附近做一次本地搜索，尽量拿到国家/城市
    private func fallbackSearchAround(coordinate: CLLocationCoordinate2D, forAddDestinationPrefill: Bool = false) {
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
                
                let countryName = self.resolvedCountryName(from: item.placemark)
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
                
                let mapItem = self.mkMapItemForPrefill(
                    displayCoordinate: coordinate,
                    placemark: item.placemark,
                    locationName: locationName
                )
                DispatchQueue.main.async {
                    self.isGeocodingLocation = false
                    if forAddDestinationPrefill {
                        self.updateAddDestinationPrefill(
                            mapItem: mapItem,
                            name: locationName,
                            country: countryName,
                            category: category
                        )
                    }
                    // 不需要再次设置 showingAddDestination，界面已经显示
                }
            } else {
                print("⚠️ " + "nearby_search_failed".localized(with: error?.localizedDescription ?? "无结果"))
                DispatchQueue.main.async { self.fallbackWithCoordinateOnly(coordinate: coordinate, forAddDestinationPrefill: forAddDestinationPrefill) }
            }
        }
    }

    // 备用方案2：仅根据坐标进行国内/国外判断并提供占位名称
    private func fallbackWithCoordinateOnly(coordinate: CLLocationCoordinate2D, forAddDestinationPrefill: Bool = false) {
        isGeocodingLocation = false
        let category = isInChinaBoundingBox(coordinate) ? "domestic" : "international"
        // 使用本地化的国家名称
        let countryName = category == "domestic"
            ? CountryManager.shared.getLocalizedCountryName(for: .china)
            : getLocalizedCountryNameByCoordinate(coordinate)
        let cityName = "selected_location".localized
        print("🛟 " + "coordinate_fallback".localized(with: cityName, countryName, category))
        guard forAddDestinationPrefill else { return }
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
                    showingQuickCheckIn = false
                    pendingPhotoPrefill = nil
                    photoImportItem = nil
                    showingPhotoImportPicker = false
                }
                return
            }
            
            print("✅ 图片数据加载成功，大小: \(data.count / 1024) KB")
            
            let processed = ImageProcessor.process(data: data)
            let metadata = extractMetadata(for: item, imageData: data)
            let suggestedType = PlaceTypeImageClassifier.suggestPlaceType(from: processed.0)

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
                        thumbnailData: processed.1,
                        suggestedPlaceType: suggestedType
                    )
                    photoImportError = nil
                    isGeocodingLocation = true  // 先显示加载状态，避免首帧出现空表单
                    showingQuickCheckIn = true
                    addDestinationPrefill = nil
                    
                    print("🔄 开始逆地理编码...")
                    reverseGeocodeLocation(coordinate: finalCoordinate, forAddDestinationPrefill: true)
                } else {
                    print("⚠️ 图片中未找到 GPS 坐标信息")
                    if let captureDate = metadata.captureDate {
                        print("📅 拍摄日期: \(captureDate)")
                    }
                    
                    pendingPhotoPrefill = nil
                    addDestinationPrefill = AddDestinationPrefill(
                        visitDate: metadata.captureDate,
                        photoDatas: [processed.0],
                        photoThumbnailDatas: [processed.1],
                        suggestedPlaceType: suggestedType
                    )
                    isGeocodingLocation = false
                    showingQuickCheckIn = true
                    photoImportError = .missingLocation
                }
            }
        }
    }
    
    /// 从 EXIF GPS 字典解析 WGS84（与 CoreLocation / PHAsset 一致）；支持标量、NSNumber、度分秒数组及有理数分量。
    private func coordinateFromEXIFGPSDictionary(_ gps: [CFString: Any]) -> CLLocationCoordinate2D? {
        guard let latRefRaw = gps[kCGImagePropertyGPSLatitudeRef],
              let lonRefRaw = gps[kCGImagePropertyGPSLongitudeRef] else { return nil }
        let latRef = String(describing: latRefRaw).uppercased()
        let lonRef = String(describing: lonRefRaw).uppercased()
        guard let latDeg = exifGPSDegrees(from: gps[kCGImagePropertyGPSLatitude]),
              let lonDeg = exifGPSDegrees(from: gps[kCGImagePropertyGPSLongitude]) else { return nil }
        let lat = (latRef == "S") ? -latDeg : latDeg
        let lon = (lonRef == "W") ? -lonDeg : lonDeg
        guard lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    private func exifGPSDegrees(from value: Any?) -> Double? {
        guard let value = value else { return nil }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let arr = value as? [Any], arr.count >= 3 {
            return exifRationalComponent(arr[0]) + exifRationalComponent(arr[1]) / 60.0 + exifRationalComponent(arr[2]) / 3600.0
        }
        if let arr = value as? NSArray, arr.count >= 3 {
            return exifRationalComponent(arr[0]) + exifRationalComponent(arr[1]) / 60.0 + exifRationalComponent(arr[2]) / 3600.0
        }
        return nil
    }
    
    private func exifRationalComponent(_ value: Any?) -> Double {
        guard let value = value else { return 0 }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let dict = value as? NSDictionary,
           let num = dict["Numerator"] as? NSNumber,
           let den = dict["Denominator"] as? NSNumber,
           den.doubleValue != 0 {
            return num.doubleValue / den.doubleValue
        }
        return 0
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
                
                // 提取 GPS（兼容 Double、NSNumber、度分秒数组；PHAsset 已为 WGS84）
                if coordinate == nil,
                   let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
                    if let coord = coordinateFromEXIFGPSDictionary(gps) {
                        coordinate = coord
                        print("✅ 从 EXIF GPS 获取坐标: (\(String(format: "%.6f", coord.latitude)), \(String(format: "%.6f", coord.longitude)))")
                    } else {
                        print("⚠️ EXIF 中未找到 GPS 信息")
                    }
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
        
        // 步骤1：计算路线纬度的跨度和中心点
        let routeCenterLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let routeLatSpan = max(maxLat - minLat, 0.01) // 路线的实际纬度跨度（至少0.01度）
        
        // 计算经度跨度（用于正常情况）
        let lonSpan = max((maxLon - minLon) * 1.5, 0.01)
        
        if showRouteCards {
            // 步骤2：将路线纬度中心放到屏幕上半部分的中心
            // 屏幕上半部分的中心 = 屏幕顶部往下 25% 的位置（因为上半部分占50%，中心就是25%）
            // 如果地图中心点在屏幕中心（50%），要移动到25%的位置，需要将中心点向下偏移 25%
            // 由于地图坐标系中，中心点向南移动（纬度减少）会使内容相对向上移动
            // 所以我们需要将中心点向下偏移，使路线中心对齐到屏幕25%的位置
            
            // 步骤3：根据路线纬度跨度计算跨度调整比例，确保路线在上半部分完整显示
            // 屏幕上半部分的高度 = 50% 屏幕高度
            // 要使路线完整显示在上半部分，地图显示的跨度应该刚好覆盖上半部分
            // 由于路线跨度需要完整显示在上半部分（50%屏幕），地图跨度应该是路线跨度的 2倍
            // 加上一些边距，使用 2.2倍 以确保路线完整可见且有适当边距
            let adjustedLatSpan = routeLatSpan * 2.2
            
            // 现在计算偏移量：要将路线中心（routeCenterLat）对齐到屏幕25%的位置
            // 如果使用 adjustedLatSpan 作为地图跨度，那么：
            // - 地图中心点向上偏移 25% 的 adjustedLatSpan，路线中心就会向下移动到75%位置（不对）
            // - 地图中心点向下偏移 25% 的 adjustedLatSpan，路线中心就会向上移动到25%位置（正确）
            // 所以我们需要将地图中心点设置在：routeCenterLat - 0.25 * adjustedLatSpan
            let screenTopHalfCenterOffset = adjustedLatSpan * 0.3
            let adjustedCenterLat = routeCenterLat - screenTopHalfCenterOffset
            
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: adjustedCenterLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: adjustedLatSpan, longitudeDelta: lonSpan)
            )
            
            withAnimation(.easeInOut(duration: 0.8)) {
                mapCameraPosition = .region(region)
            }
        } else {
            // 正常情况：使用路线中心点和标准跨度（添加1.5倍边距）
            let normalLatSpan = max(routeLatSpan * 1.5, 0.01)
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: routeCenterLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: normalLatSpan, longitudeDelta: lonSpan)
            )
            
            withAnimation(.easeInOut(duration: 0.8)) {
                mapCameraPosition = .region(region)
            }
        }
        
        print("🗺️ 地图已缩放到旅程范围，包含 \(destinations.count) 个地点\(showRouteCards ? "（已向上偏移以避免卡片遮挡）" : "")")
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
    
    // 地图地点标注弹窗覆盖层
    @ViewBuilder
    private var destinationCalloutOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                if let destination = selectedDestination {
                    // 计算地点在地图上的屏幕坐标
                    let screenPoint = convertCoordinateToScreenPoint(destination.coordinate, in: geometry.size)
                    
                    // 弹窗显示在标注上方，向上偏移约100点
                    let calloutPosition = CGPoint(
                        x: screenPoint.x,
                        y: screenPoint.y - 100
                    )
                    
                    MapDestinationCalloutView(
                        destination: destination,
                        onTap: {
                            // 点击弹窗时打开详情页
                            detailDestinationForSheet = destination
                        },
                        appleSignInManager: AppleSignInManager.shared
                    )
                    .position(x: calloutPosition.x, y: calloutPosition.y)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedDestination?.id)
                    .zIndex(999) // 确保在标注上方
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
    
    // 处理AI助手功能
    private func handleAIAssistant() {
        print("🤖 点击AI助手按钮")
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 切换AI助手界面显示状态
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingAIAssistant.toggle()
        }
        
        // TODO: 后续实现AI功能入口
        // 可以打开AI助手界面、显示AI功能列表等
        // 参考：可以创建一个AIAssistantView来展示AI功能
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
        
        // 获取当前屏幕中心点坐标（用于距离排序）
        let centerCoordinate = visibleRegion?.center
        
        // 使用可复用的搜索辅助类
        LocationSearchHelper.search(
            query: searchText,
            region: visibleRegion,
            centerCoordinate: centerCoordinate
        ) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let items):
                    self.searchResults = items
                    print("✅ 搜索完成，找到 \(items.count) 个结果（已按距离排序）")
                case .failure(let error):
                    print("❌ 搜索失败: \(error.localizedDescription)")
                    self.searchResults = []
                }
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
        
        // 显示POI预览卡片（与点击地图POI的行为一致）
        // 延迟一点显示，等待地图移动动画开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.selectedPOI = mapItem
                self.showingPOIPreview = true
            }
        }
        
        // 关闭搜索栏，但保留搜索结果和搜索文本（用户关闭POI卡片后可以重新打开搜索栏查看其他结果）
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSearchBar = false
            isSearchFocused = false
            // 注意：不清空 searchText 和 searchResults，这样用户重新打开搜索栏时还能看到结果
        }
        
        print("📍 移动到搜索结果并显示POI预览: \(mapItem.name ?? "未知地点")")
    }
}

// 搜索结果行组件

// CLLocationCoordinate2D 扩展：计算两点距离
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
        // 获取用户选择的交通方式，如果没有则使用默认机动车
        let userTransportType = routeManager.getUserTransportType(
            from: source.coordinate,
            to: destination.coordinate
        )
        
        // 优先使用用户选择，否则使用默认机动车
        return userTransportType ?? .automobile
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
                        // 清除该旅程的路线缓存，强制重新计算（使用整趟行程坐标，避免按天筛选时只更新部分路线）
                        tripRoutes.removeValue(forKey: tripId)
                        syncTripRoutesToSharedStore()
                        let coordinates = sortedDestinations(for: tripId).map { $0.coordinate }
                        Task {
                            await calculateRoutesForTrip(tripId: tripId, coordinates: coordinates, incremental: false)
                        }
                    }
                )
            }
        }
    }
}

#Preview {
    MapView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(BrandColorManager.shared)
        .environmentObject(CountryManager.shared)
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
            mainButtonContent
        }
        .buttonStyle(.plain)
        .accessibilityHint(menuTitle)
    }
    
    @ViewBuilder
    private var mainButtonContent: some View {
        if #available(iOS 26, *) {
            Image(systemName: isExpanded ? "xmark" : "circle.hexagongrid.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isDarkStyle ? Color.white : Color.primary)
                .frame(width: Self.collapsedDiameter, height: Self.collapsedDiameter)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        } else {
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
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    private func radialButton(for action: AssistiveMenuAction, at index: Int) -> some View {
        let offsets = radialOffsets(for: index)
        
        return Button {
            select(action)
        } label: {
            radialButtonContent(for: action)
        }
        .buttonStyle(.plain)
        .offset(x: isExpanded ? offsets.x : 0, y: isExpanded ? offsets.y : 0)
    }
    
    @ViewBuilder
    private func radialButtonContent(for action: AssistiveMenuAction) -> some View {
        VStack(spacing: 0) {
            if #available(iOS 26, *) {
                iconProvider(action.icon, action.isActive)
                    .frame(width: 24, height: 24)
                    .padding(14)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
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
                    .contentShape(Circle())
            }
        }
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1 : 0.5, anchor: .center)
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

// MARK: - MapView 嵌入 NavigationStack 环境键（由嵌入父视图设置，用于隐藏浮动地图样式按钮）
private struct MapViewInNavigationStackKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var mapViewInNavigationStack: Bool {
        get { self[MapViewInNavigationStackKey.self] }
        set { self[MapViewInNavigationStackKey.self] = newValue }
    }
}

// "我的足迹"抽屉视图

