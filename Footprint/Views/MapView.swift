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
final class RouteSelectionHolder: ObservableObject {
    @Published var selectedTripId: UUID?
    @Published var selectedDayFilter: Int?
}

struct MapView: View {
    @Query(sort: \TravelTrip.startDate, order: .reverse) var trips: [TravelTrip]
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme // 检测颜色模式
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.isAppReady) var isAppReady // 应用是否已就绪（启动画面是否结束）
    @Environment(\.isMapTabActive) var isMapTabActive // 足迹地图 Tab 是否在前台（离屏保活时暂停拉取/天气）
    @Environment(\.mapViewInNavigationStack) var mapViewInNavigationStack // 是否嵌入在 NavigationStack 中（如旅程卡片全屏地图 sheet），用于统一顶部工具栏位置
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject var languageManager = LanguageManager.shared
    @StateObject var countryManager = CountryManager.shared
    
    // MapView 专注于"我的足迹"模式
    /// 嵌入 NavigationStack 时可传入绑定，用于在导航栏标题位显示「第几天」筛选
    /// tripsOverride: 父视图传入时用于限制展示的行程列表（如分页）；nil 时使用 @Query 全量
    init(
        autoShowRouteCards: Bool = false,
        selectedTripIdBinding: Binding<UUID?>? = nil,
        selectedDayFilterBinding: Binding<Int?>? = nil,
        tripsOverride: [TravelTrip]? = nil,
        prefilledTripRoutes: [UUID: [MKRoute?]]? = nil
    ) {
        self.autoShowRouteCards = autoShowRouteCards
        self.selectedTripIdBinding = selectedTripIdBinding
        self.selectedDayFilterBinding = selectedDayFilterBinding
        self.tripsOverride = tripsOverride
        _tripRoutes = State(initialValue: prefilledTripRoutes ?? [:])
    }
    
    /// 父视图传入的行程列表；nil 时使用 @Query 的 trips
    var tripsOverride: [TravelTrip]?
    
    /// 实际使用的行程列表：有 override 时用 override（分页），否则用 @Query 全量
    var effectiveTrips: [TravelTrip] {
        tripsOverride ?? trips
    }
    
    /// 由父视图传入时用于导航栏标题位筛选；未传入时使用内部 state
    var selectedTripIdBinding: Binding<UUID?>?
    var selectedDayFilterBinding: Binding<Int?>?
    
    // MARK: - Route Color Helper
    /// 根据交通方式返回路线颜色
    /// - Parameter transportType: 交通方式
    /// - Returns: 路线颜色（徒步：绿色，机动车：蓝色，飞机：橙色，其他：灰色）
    func routeColor(for transportType: MKDirectionsTransportType) -> Color {
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

    @State var position: MapCameraPosition = .automatic
    @State var selectedDestination: TravelDestination?
    @State var showingAddDestination = false        // 普通“添加目的地”弹窗
    @State var showingQuickCheckIn = false          // “快速打卡”弹窗
    @State var mapCameraPosition: MapCameraPosition = .automatic
    @State var visibleRegion: MKCoordinateRegion?
    let regionHolder = MapRegionHolder() // 相机 continuous 回调写入，避免每帧 @State 刷新
    @State var mapSelection: TravelDestination? // 地图的选择状态
    // 标记当前点按是否来自自定义地点标记，避免“击穿”到地图触发POI弹窗
    @State var annotationTapInProgress = false

    @ObservedObject var locationManager = LocationManager.shared
    @StateObject var routeManager = RouteManager.shared
    @StateObject var destinationWeatherManager = DestinationWeatherManager()
    // 详情弹窗（由父级统一展示，避免子视图被移除导致弹窗不出现）
    @State var detailDestinationForSheet: TravelDestination?
    @State var destinationDetailDetent: PresentationDetent = .fraction(0.25)
    
    // 反向地理编码优化：使用共享的 geocoder 实例，避免重复创建
    @State var geocoder: CLGeocoder?
    @State var pendingGeocodeCoordinate: CLLocationCoordinate2D?
    @State var geocodeTimeoutTimer: Timer?
    @State var lastGeocodeTime: Date?
    @State var isThrottled = false // 是否处于节流状态
    @State var throttleResetTime: Date? // 节流重置时间
    @State var viewAppearTime: Date? // 视图出现时间，用于启动阶段的节流控制
    @State var hasDoneInitialGeocode = false // 启动阶段是否已完成一次反向地理编码
    @State var startupGeocodeScheduled = false // 启动阶段是否已安排一次延迟地理编码
    @State var locationInitializationPending = false // 定位初始化是否待执行（等待启动画面结束）
    @State var initialCameraPositionSet = false // 初始相机位置是否已设置
    @State var waitingForLocationToSetCamera = false // 是否正在等待位置来设置相机
    @State var isWaitingForUserLocate = false // 用户点击定位按钮后等待位置
    
    // 底部浮动按钮参数
    let tabBarHeight: CGFloat = 49
    let bottomButtonSpacing: CGFloat = 6
    let cachedPlacemarkReuseDistance: CLLocationDistance = 120
    let cachedPlacemarkTTL: TimeInterval = 300
    let accuracyImprovementTrigger: Double = 15
    
    // 存储每个旅程的路线数据 [tripId: [routeIndex: route]]
    // 使用 [MKRoute?] 而不是 [MKRoute] 以保持索引对应关系（nil 表示该段路线计算失败）
    @State var tripRoutes: [UUID: [MKRoute?]] = [:]
    
    // 性能优化：缓存聚合结果
    @State var cachedClusterAnnotations: [ClusterAnnotation] = []
    @State var cachedZoomLevelEnum: ZoomLevel = .world
    @State var cachedDestinationsCount: Int = 0
    @State var cachedVisibleRegionKey: String = "" // 缓存可见区域的标识
    @State var lastCalculationTime: Date = Date()
    @State var isCalculatingClusters = false // 标记是否正在计算，避免重复触发
    @State var clusterCalculationGeneration = 0 // 忽略过期的后台聚类结果
    @State var scheduledClusterRegionKey: String = "" // 避免相同区域重复调度聚类
    
    // 性能优化：缓存排序后的地点列表，避免重复排序
    @State var sortedDestinationsCache: [UUID: [TravelDestination]] = [:]
    
    // 按可见区域从 DB 拉取的地点（地图标注/聚类数据源，替代全量 @Query）
    @State var destinationsInVisibleRegion: [TravelDestination]? = nil
    @State var visibleRegionKeyForFetch: String = ""
    @State var totalDestinationCount: Int = 0
    @State var trackedDestinationsSignature: String = ""
    @State var footprintsDrawerDestinations: [TravelDestination] = []
    @State var destinationMetadataTask: Task<Void, Never>?
    @State var regionFetchTask: Task<Void, Never>?
    @State var regionFetchInFlightKey: String?
    @State var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    
    // 地图样式相关状态
    @AppStorage("mapStyle") var mapStyleRawValue: String = MapStyle.muted.rawValue
    @AppStorage("mapWeatherEnabled") var mapWeatherEnabled = false
    @State var showingMapStylePicker = false
    
    // 长按添加目的地相关状态
    @State var longPressLocation: CLLocationCoordinate2D?
    @State var isGeocodingLocation = false
    @State var addDestinationPrefill: AddDestinationPrefill?
    @State var isWaitingForLocation = false // 等待定位状态（用于打卡功能）
    @State var pendingPhotoPrefill: PendingPhotoPrefill?
    @State var shouldUsePrefillForAddDestination = false // 标记是否应该在"添加目的地"中使用预填充数据（用于照片导入等场景）
    @State var lastReverseGeocodePlacemark: CLPlacemark?
    @State var lastReverseGeocodeCoordinate: CLLocationCoordinate2D?
    @State var lastReverseGeocodeTimestamp: Date?
    @State var lastGeocodedAccuracy: Double = .greatestFiniteMagnitude
    @State var showingPhotoImportPicker = false
    @State var photoImportItems: [PhotosPickerItem] = []
    @State var photoImportError: PhotoImportError?
    let photoImportMaxSelectionCount = 9
    
    // POI点击相关状态
    @State var selectedPOI: MKMapItem?
    @State var showingPOIPreview = false
    @State var isSearchingPOI = false
    @State var poiSearchStartTime: Date?
    @State var tapStartTime: Date? // 用于区分轻点和长按
    let loadingTaskHolder = POILoadingTaskHolder() // 使用类来存储任务引用，避免结构体的不可变问题
    let showLoadingThreshold: TimeInterval = 0.3 // 超过300ms才显示加载卡片
    
    @State var refreshID = UUID()
    
    // 用于检测地点变化的状态（坐标、删除等）
    @State var lastDestinationsSignature: String = ""
    
    // 回忆泡泡相关状态
    @State var selectedBubbleDestination: TravelDestination? // 用于获取地点位置
    @State var showSoapBubbles = false
    @State var soapBubblesID = UUID() // 用于强制创建新的肥皂泡泡视图实例
    @State var waitingForMapToReachDestination = false // 是否正在等待地图到达地点
    @State var targetBubbleDestination: TravelDestination? // 目标地点（用于检查是否到达）
    
    // 搜索相关状态
    @State var searchText = ""
    @State var searchResults: [MKMapItem] = []
    @State var isSearching = false
    @State var showSearchBar = false // 控制搜索栏显示
    @FocusState var isSearchFocused: Bool
    
    // AI功能相关状态
    @State var showingAIAssistant = false // 控制AI助手界面显示
    @AppStorage("hasUsedMapAIAssistant") var hasUsedMapAIAssistant = false
    
    // 旅程线路图选中状态（仅 autoShowRouteCards）
    @StateObject var routeSelectionHolder = RouteSelectionHolder()
    @State var showingFootprintsDrawer = false // 是否显示"我的足迹"抽屉
    @State var assistiveMenuExpanded = false
    @State var assistiveMenuPosition: CGPoint = .zero
    /// 是否为旅程线路图模式（从旅程卡片进入）；足迹 Tab 为 false，不画路线
    var autoShowRouteCards: Bool = false
    
    /// 当前选中的旅程ID（来自 Binding 或内部 holder）
    var selectedTripId: UUID? {
        get { selectedTripIdBinding?.wrappedValue ?? routeSelectionHolder.selectedTripId }
        set {
            if let b = selectedTripIdBinding { b.wrappedValue = newValue }
            else { routeSelectionHolder.selectedTripId = newValue }
        }
    }
    
    /// 按天筛选（来自 Binding 或内部 holder）
    var selectedDayFilter: Int? {
        get { selectedDayFilterBinding?.wrappedValue ?? routeSelectionHolder.selectedDayFilter }
        set {
            if let b = selectedDayFilterBinding { b.wrappedValue = newValue }
            else { routeSelectionHolder.selectedDayFilter = newValue }
        }
    }
    
    /// 在闭包/非 mutating 上下文中安全写入选中旅程（避免 self 不可变）
    func setSelectedTripId(_ value: UUID?) {
        if let b = selectedTripIdBinding { b.wrappedValue = value }
        else { routeSelectionHolder.selectedTripId = value }
    }
    
    /// 在闭包/非 mutating 上下文中安全写入按天筛选
    func setSelectedDayFilter(_ value: Int?) {
        if let b = selectedDayFilterBinding { b.wrappedValue = value }
        else { routeSelectionHolder.selectedDayFilter = value }
    }
    
    // 触觉反馈
    @State var selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    let checkInFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    @State var checkInPulseScale: CGFloat = 1.0
    @State var checkInPulseOpacity: Double = 0.45
    
    // 简化版中国国界多边形（近似，覆盖中国大陆与海南一带；仅作兜底使用）
    static let chinaMainlandPolygon: [CLLocationCoordinate2D] = [
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
    
    struct PendingPhotoPrefill {
        var visitDate: Date?
        var photoDatas: [Data]
        var photoThumbnailDatas: [Data]
    }
    
    struct PhotoMetadata {
        var coordinate: CLLocationCoordinate2D?
        var captureDate: Date?
    }
    
    struct ResolvedPhotoImportMetadata {
        var coordinate: CLLocationCoordinate2D?
        var visitDate: Date?
        var gpsSourceIndex: Int?
    }
    
    enum GeocodeResultSource {
        case live
        case cached
    }
    
    enum PhotoImportError: Identifiable {
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
    var tripConnectionColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5)
    }
    
    // 搜索框占位符文本
    var searchPlaceholderText: String {
        "search_places".localized
    }
    
    // 当前地图样式（持久化）
    var currentMapStyle: MapStyle {
        MapStyle(rawValue: mapStyleRawValue) ?? .muted
    }
    
    // 根据地图样式返回图标颜色
    var iconColor: Color {
        switch currentMapStyle {
        case .standard, .muted:
            return .blue
        case .hybrid, .imagery:
            return .white
        }
    }
    
    // 判断是否是深色地图样式
    var isDarkMapStyle: Bool {
        switch currentMapStyle {
        case .standard, .muted:
            return false
        case .hybrid, .imagery:
            return true
        }
    }
    
    var shouldShowAssistiveMenu: Bool {
        !autoShowRouteCards && selectedDestination == nil && !showSearchBar
    }
    
    var isThermallyLimited: Bool {
        thermalState == .fair
    }
    
    var isThermallyCritical: Bool {
        thermalState == .serious || thermalState == .critical
    }
    
    var brandAccentColor: Color {
        brandColorManager.currentBrandColor
    }
    
    /// 在地图上展示的地点集合（足迹模式：仅使用可见区域 fetch 结果）
    var destinationsForCurrentMapMode: [TravelDestination] {
        destinationsInVisibleRegion ?? []
    }
    
    /// 根据可见区域生成缓存键（小数 2 位，减少重复 fetch）
    static func makeRegionKey(_ region: MKCoordinateRegion, tripId: UUID? = nil, dayFilter: Int? = nil) -> String {
        let centerLat = String(format: "%.2f", region.center.latitude)
        let centerLon = String(format: "%.2f", region.center.longitude)
        let spanLat = String(format: "%.2f", region.span.latitudeDelta)
        let spanLon = String(format: "%.2f", region.span.longitudeDelta)
        let tripIdSuffix = tripId?.uuidString ?? "nil"
        let daySuffix = dayFilter.map { "\($0)" } ?? "all"
        return "\(centerLat),\(centerLon),\(spanLat),\(spanLon),\(tripIdSuffix),\(daySuffix)"
    }
    
    /// 按可见区域从 DB 拉取地点（single-flight + 5% 边距 + 设备相关上限）
    func fetchDestinationsInRegion(_ region: MKCoordinateRegion) async {
        guard isMapTabActive || autoShowRouteCards else { return }
        
        let limit = MapDestinationFetcher.regionFetchLimit
        let key = Self.makeRegionKey(region, tripId: selectedTripId, dayFilter: selectedDayFilter)
        
        let alreadyCached = await MainActor.run { visibleRegionKeyForFetch == key }
        if alreadyCached { return }
        
        let alreadyInFlight = await MainActor.run { regionFetchInFlightKey == key }
        if alreadyInFlight { return }
        
        await MainActor.run {
            regionFetchTask?.cancel()
            regionFetchInFlightKey = key
        }
        
        let list = await MainActor.run {
            MapDestinationFetcher.fetchInRegion(region, in: modelContext, limit: limit)
        }
        
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            regionFetchInFlightKey = nil
            destinationsInVisibleRegion = list
            visibleRegionKeyForFetch = key
            scheduleClusterRecalculationIfNeeded()
        }
    }

    /// 刷新地点总数与变更签名（debounce 合并，禁止与 camera 联动）
    func refreshDestinationMetadata(triggerChangeHandler: Bool = true, debounceSeconds: TimeInterval = 0) {
        destinationMetadataTask?.cancel()
        destinationMetadataTask = Task {
            if debounceSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(debounceSeconds * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            
            let count = await MainActor.run { MapDestinationFetcher.fetchCount(in: modelContext) }
            let newSignature = await MainActor.run {
                MapDestinationFetcher.fetchLightSignature(in: modelContext)
            }

            guard !Task.isCancelled else { return }

            let shouldRefetchRegion = await MainActor.run { () -> Bool in
                let oldCount = totalDestinationCount
                let oldSignature = trackedDestinationsSignature

                totalDestinationCount = count
                trackedDestinationsSignature = newSignature

                guard triggerChangeHandler else {
                    lastDestinationsSignature = newSignature
                    return true
                }

                if oldSignature.isEmpty {
                    lastDestinationsSignature = newSignature
                } else if oldCount != count {
                    print("🔄 地点数量变化: \(oldCount) -> \(count)")
                    handleDestinationsChange()
                } else if oldSignature != newSignature {
                    checkDestinationsChange()
                }

                return !(autoShowRouteCards && selectedTripId != nil)
            }

            guard shouldRefetchRegion, !Task.isCancelled else { return }

            let region = await MainActor.run { visibleRegion ?? regionHolder.pending }
            if let region {
                await fetchDestinationsInRegion(region)
            }
        }
    }

    func loadFootprintsDrawerDestinations() {
        Task {
            let list = await MainActor.run {
                MapDestinationFetcher.fetchAllSortedByVisitDate(in: modelContext, reverse: true)
            }
            await MainActor.run {
                footprintsDrawerDestinations = list
            }
        }
    }

    func refetchVisibleDestinationsIfNeeded() {
        guard !(autoShowRouteCards && selectedTripId != nil) else { return }
        if let region = visibleRegion ?? regionHolder.pending {
            Task { await fetchDestinationsInRegion(region) }
        }
    }
    
    /// 相机 debounce 后统一提交可见区域并触发下游计算
    func commitVisibleRegionUpdate() {
        let region = regionHolder.pending
        visibleRegion = region
        if let region, !autoShowRouteCards || selectedTripId == nil {
            Task { await fetchDestinationsInRegion(region) }
        }
        scheduleClusterRecalculationIfNeeded()
        if waitingForMapToReachDestination {
            checkAndTriggerBubbles()
        }
    }
    
    // 打卡按钮的无障碍提示
    var checkInAccessibilityHint: String {
        "quick_check_in".localized
    }
    
    // 仅为当前选中的旅程重新计算路线（进入"旅程"时避免全量计算）
    func recalcSelectedTripRoutes(forceFullRecalc: Bool = false) {
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
        let content = mainContentView()
        let withSheets = applySheets(to: content)
        let withLifecycle = applyLifecycleModifiers(to: withSheets)
        withLifecycle
    }
    
    // 主视图内容
    @ViewBuilder
    func mainContentView() -> some View {
        ZStack {
            mapLayer
            dismissOverlay
            previewCard
            memoryBubbleOverlay
            // destinationCalloutOverlay // 已移除：点击地点时只显示底部抽屉弹窗，不显示地点位置的标签卡片
            if !autoShowRouteCards {
                floatingButtons
            }
            keyboardOverlay
        }
        // 搜索功能已移至 searchBarOverlay，使用自定义覆盖层实现
    }
    
}

#Preview {
    MapView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(BrandColorManager.shared)
        .environmentObject(CountryManager.shared)
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
