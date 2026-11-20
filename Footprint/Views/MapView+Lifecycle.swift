//
//  MapView+Lifecycle.swift
//  Footprint
//
//  从 MapView.swift 拆分（编译加速）
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

extension MapView {
    @ViewBuilder
    func applySheets<Content: View>(to content: Content) -> some View {
        content
            .sheet(item: $detailDestinationForSheet, onDismiss: {
                mediaViewerSession = nil
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    selectedDestination = nil
                    mapSelection = nil
                }
            }) { destination in
                NavigationStack {
                    DestinationDetailView(destination: destination)
                }
                .environment(\.presentMediaViewer, PresentMediaViewerAction { items, index in
                    mediaViewerSession = MediaViewerSession(items: items, index: index)
                })
                // 看图在 sheet 外层 cover：detent 保持用户原样，只禁止拖关闭
                .presentationDetents([.fraction(0.25), .medium, .large], selection: $destinationDetailDetent)
                .presentationDragIndicator(.visible)
                // 下拉先收起/关闭 sheet；只有拉到最大档后，内容才滚动
                .presentationContentInteraction(.resizes)
                .interactiveDismissDisabled(mediaViewerSession != nil)
            }
            .fullScreenCover(item: $mediaViewerSession) { session in
                MediaFullscreenViewer(
                    items: session.items,
                    currentIndex: Binding(
                        get: { mediaViewerSession?.index ?? session.index },
                        set: { newIndex in
                            guard var current = mediaViewerSession else { return }
                            current.index = newIndex
                            mediaViewerSession = current
                        }
                    ),
                    onClose: { mediaViewerSession = nil }
                )
                .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingFootprintsDrawer) {
                FootprintsDrawerView(
                    destinations: footprintsDrawerDestinations,
                    onSelect: handleFootprintsSelect,
                    onAdd: handleFootprintsAdd
                )
            }
            .onChange(of: showingFootprintsDrawer) { _, isShowing in
                if isShowing {
                    loadFootprintsDrawerDestinations()
                }
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
            .sheet(isPresented: $showingMapStylePicker) {
                mapStylePicker
            }
            .sheet(isPresented: $showingAIAssistant) {
                AIAssistantView()
            }
            .photosPicker(
                isPresented: $showingPhotoImportPicker,
                selection: $photoImportItems,
                maxSelectionCount: photoImportMaxSelectionCount,
                matching: .images
            )
            .onChange(of: photoImportItems) { _, newValue in
                guard !newValue.isEmpty else { return }
                handlePhotoImportSelection(newValue)
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
    func applyLifecycleModifiers<Content: View>(to content: Content) -> some View {
        let withBasicModifiers = applyBasicLifecycleModifiers(to: content)
        let withDestinationModifiers = applyDestinationLifecycleModifiers(to: withBasicModifiers)
        let withLocationModifiers = applyLocationLifecycleModifiers(to: withDestinationModifiers)
        withLocationModifiers
            .id(refreshID)
    }
    
    // 基础生命周期修饰符
    @ViewBuilder
    func applyBasicLifecycleModifiers<Content: View>(to content: Content) -> some View {
        content
            .onAppear {
                handleViewAppear()
            }
            .onDisappear {
                handleViewDisappear()
            }
            .onChange(of: isAppReady) { oldValue, newValue in
                // 当应用就绪状态从 false 变为 true 时（启动画面/引导结束），再落初始相机
                if !oldValue && newValue {
                    if locationInitializationPending || !Self.hasSettledInitialCameraThisLaunch {
                        locationInitializationPending = false
                        if !autoShowRouteCards {
                            beginInitialCameraSettlement()
                        }
                    }
                    if !autoShowRouteCards {
                        scheduleStartupContentReveal()
                    }
                }
                if !oldValue && newValue, !autoShowRouteCards {
                    // 骨架期内先轻量备元数据；标注等内容可见后再刷区域
                    refreshDestinationMetadata(triggerChangeHandler: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { notification in
                handleDestinationDeleted(notification: notification)
                destinationsInVisibleRegion = nil
                refreshDestinationMetadata(debounceSeconds: 2.0)
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationUpdated)) { _ in
                destinationsInVisibleRegion = nil
                refreshDestinationMetadata(debounceSeconds: 2.0)
            }
            .onChange(of: scenePhase) { _, _ in
                syncWeatherManagerPauseState()
            }
            .onChange(of: mapWeatherEnabled) { _, _ in
                syncWeatherManagerPauseState()
            }
            .onChange(of: isMapTabActive) { _, isActive in
                syncWeatherManagerPauseState()
                if isActive {
                    refetchVisibleDestinationsIfNeeded()
                    scheduleClusterRecalculationIfNeeded()
                } else {
                    regionFetchTask?.cancel()
                    regionHolder.cancelDebounce()
                }
            }
            .onChange(of: locationManager.authorizationStatus) { _, status in
                guard !autoShowRouteCards, !Self.hasSettledInitialCameraThisLaunch else { return }
                if status == .denied || status == .restricted {
                    revealShanghaiFallback()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
                applyThermalMitigation(ProcessInfo.processInfo.thermalState)
            }
    }
    
    // 地点相关生命周期修饰符
    @ViewBuilder
    func applyDestinationLifecycleModifiers<Content: View>(to content: Content) -> some View {
        content
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
                    scheduleClusterRecalculationIfNeeded()
                }
            }
            .onChange(of: destinationsInVisibleRegion?.count) { _, _ in
                scheduleClusterRecalculationIfNeeded()
            }
            .onChange(of: effectiveTrips.count) { _, _ in
                if autoShowRouteCards {
                    recalcSelectedTripRoutes()
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
                    let dests = visibleDestinationsForSelectedTrip
                    let routesReady = selectedTripId.flatMap { tripRoutes[$0]?.allSatisfy { $0 != nil } } ?? false
                    zoomToTripDestinations(dests, animationDuration: routesReady ? 0.25 : 0.8)
                    if let tripId = selectedTripId {
                        let sorted = sortedDestinations(for: tripId)
                        if sorted.count >= 2,
                           tripRoutes[tripId]?.count != sorted.count - 1 {
                            let coordinates = sorted.map { $0.coordinate }
                            Task {
                                await calculateRoutesForTrip(tripId: tripId, coordinates: coordinates, incremental: true)
                            }
                        }
                    }
                }
            }
    }
    
    // 位置相关生命周期修饰符
    @ViewBuilder
    func applyLocationLifecycleModifiers<Content: View>(to content: Content) -> some View {
        content
            .onChange(of: locationManager.lastKnownLocation) { _, newValue in
                handleLocationChange(newValue: newValue)
            }
            // 坐标不变、仅精度变好时也要能落到初始相机
            .onChange(of: locationManager.lastLocationAccuracy) { _, _ in
                guard !initialCameraPositionSet || isWaitingForUserLocate else { return }
                handleLocationChange(newValue: locationManager.lastKnownLocation)
            }
    }
    
    // 处理地点删除通知
    func handleDestinationDeleted(notification: Notification) {
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
    func handleLocationChange(newValue: CLLocationCoordinate2D?) {
        guard let newLocation = newValue else { return }
        
        let accuracy = locationManager.lastLocationAccuracy ?? Double.greatestFiniteMagnitude
        
        // 用户点击定位按钮后，收到位置即移动地图
        if isWaitingForUserLocate {
            if accuracy > 0 && accuracy < 200.0 {
                setCameraToUserLocation(newLocation)
                isWaitingForUserLocate = false
                restoreMapBrowsingLocationModeIfNeeded()
                print("📍 定位按钮：已定位到用户位置（精度: \(String(format: "%.1f", accuracy))米）")
            }
            return
        }
        
        // 旅程线路 Sheet：只看 trip 路线，不对当前 GPS 做自动反向地理编码
        if autoShowRouteCards {
            return
        }
        
        // 尚未落下初始相机：有可用定位就飞，不依赖 waiting 标志（避免 isAppReady 竞态漏设）
        if !initialCameraPositionSet {
            trySettleInitialCamera()
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
            restoreMapBrowsingLocationModeIfNeeded()
        }
        
        if isStartupPhase {
            // 启动阶段：只执行一次自动反向地理编码
            hasDoneInitialGeocode = true
        }
        
        reverseGeocodeLocation(coordinate: newLocation, force: shouldForce, forAddDestinationPrefill: forAddDestinationPrefill)
    }
    
    // 处理视图出现
    func handleViewAppear() {
        selectionFeedbackGenerator.prepare()
        checkInFeedbackGenerator.prepare()
        
        // 记录视图出现时间，用于启动阶段的节流控制
        viewAppearTime = Date()
        isThrottled = false
        throttleResetTime = nil
        
        lastDestinationsSignature = trackedDestinationsSignature
        applyThermalMitigation(ProcessInfo.processInfo.thermalState)
        if autoShowRouteCards {
            showSearchBar = false
            assistiveMenuExpanded = false
        }
        // 线路 Sheet 使用 trip.destinations，无需全量地点 metadata 扫描
        // 足迹 Tab：骨架期内不拉标注/聚类，等内容揭晓后再刷
        if !autoShowRouteCards {
            refreshDestinationMetadata(triggerChangeHandler: false)
            if isStartupContentVisible {
                if locationManager.lastKnownLocation != nil {
                    refetchVisibleDestinationsIfNeeded()
                }
                scheduleClusterRecalculationIfNeeded()
            }
        }
        
        syncWeatherManagerPauseState()
        
        // 主 Tab 由 ContentView 管持续定位；此处再催一包，避免 Splash 一次性定位失败后首帧无点
        if !autoShowRouteCards {
            locationManager.startUpdatingLocation(mode: .mapBrowsing)
            locationManager.requestLocation()
        } else if mapViewInNavigationStack {
            // 旅程线路 Sheet 复用已有 lastKnownLocation 显示蓝点即可
        }
        
        // 如果应用还未就绪（启动画面/引导还在），先记 pending，就绪后再落相机
        if !isAppReady {
            print("⏳ 应用未就绪，延迟设置初始地图相机...")
            locationInitializationPending = true
            waitingForLocationToSetCamera = true
            if autoShowRouteCards {
                handleAutoShowRouteCards()
            }
            return
        }
        
        if autoShowRouteCards {
            isStartupContentVisible = true
            handleAutoShowRouteCards()
        } else {
            beginInitialCameraSettlement()
            scheduleStartupContentReveal()
        }
    }
    
    /// 本次进程是否已揭过启动内容（Tab 回来不再走骨架）
    private static var hasRevealedStartupContentThisLaunch = false
    /// 骨架最短展示，避免 Map 已就绪时一闪而过
    private static let startupContentRevealMinDelayNs: UInt64 = 400_000_000
    /// 极端情况下仍未出 Map，超时后也揭晓，避免永久卡骨架
    private static let startupContentRevealMaxWaitNs: UInt64 = 8_000_000_000
    
    /// 等真 Map 出现后再揭骨架（避免骨架结束露出空白底）
    func scheduleStartupContentReveal() {
        guard !autoShowRouteCards else {
            isStartupContentVisible = true
            return
        }
        if Self.hasRevealedStartupContentThisLaunch {
            isStartupContentVisible = true
            refetchVisibleDestinationsIfNeeded()
            return
        }
        guard isAppReady else { return }
        guard !isStartupContentVisible else { return }
        
        startupContentRevealTask?.cancel()
        startupContentRevealTask = Task { @MainActor in
            let started = Date()
            
            // 等定位落地或上海兜底创建 Map；超时则继续揭晓
            while !isInitialMapVisible {
                let elapsed = Date().timeIntervalSince(started)
                if elapsed * 1_000_000_000 >= Double(Self.startupContentRevealMaxWaitNs) {
                    break
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard !Task.isCancelled else { return }
            }
            
            let elapsedNs = UInt64(max(0, Date().timeIntervalSince(started)) * 1_000_000_000)
            if elapsedNs < Self.startupContentRevealMinDelayNs {
                try? await Task.sleep(nanoseconds: Self.startupContentRevealMinDelayNs - elapsedNs)
                guard !Task.isCancelled else { return }
            }
            
            Self.hasRevealedStartupContentThisLaunch = true
            withAnimation(.easeInOut(duration: 0.35)) {
                isStartupContentVisible = true
            }
            refreshDestinationMetadata(triggerChangeHandler: false)
            refetchVisibleDestinationsIfNeeded()
            scheduleClusterRecalculationIfNeeded()
            print("✨ 启动骨架结束，显示地图内容")
        }
    }
    
    /// LocationManager 已过滤后的 fix 即可用于首帧相机
    private static let initialCameraAccuracyLimit: CLLocationAccuracy = 1000
    /// 相机中心距目标小于此距离即视为落地成功（米）
    private static let initialCameraConfirmDistance: CLLocationDistance = 2500
    /// 落地后短时内若中心飘离超过此距离，视为被拉回 fallback，再锁一次
    private static let initialCameraDriftDistance: CLLocationDistance = 50_000
    /// 漂移守卫窗口
    private static let initialCameraDriftGuardDuration: TimeInterval = 8
    /// 本次进程是否已完成「启动飞到定位」；Tab 切换重建 MapView 不再重复飞
    private static var hasSettledInitialCameraThisLaunch = false
    /// 供定位按钮等判断是否仍走初始 settle
    static var hasCompletedInitialCameraSettlement: Bool { hasSettledInitialCameraThisLaunch }
    /// 已写入 mapCameraPosition、等待 Map 实际报到附近的目标坐标
    private static var pendingInitialCameraCoordinate: CLLocationCoordinate2D?
    /// 为 true 时 pending 是上海默认视野，确认时保持城市跨度，不要收成街道级
    private static var pendingCameraUsesFallbackRegion = false
    /// 已确认落地的锚点（用于漂移守卫）
    private static var settledInitialCameraCoordinate: CLLocationCoordinate2D?
    private static var initialCameraDriftGuardUntil: Date?
    /// 离开足迹 Tab 时记住视野，回来时静默恢复（无飞行动画）
    private static var lastFootprintCameraRegion: MKCoordinateRegion?
    
    /// 找不到手机定位时的视野：上海（人民广场一带）
    static let startupFallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        span: MKCoordinateSpan(latitudeDelta: 0.28, longitudeDelta: 0.28)
    )
    /// 授权已确定但仍没有定位时，改落到上海（模拟器/无定位时不宜过长）
    private static let shanghaiFallbackDelayNs: UInt64 = 2_000_000_000
    /// 权限框还在时继续等，避免用户还没点允许就落到上海
    private static let shanghaiFallbackAuthorizationCap: TimeInterval = 20
    
    private static func initialUserRegion(for location: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
    
    static func isAcceptableInitialAccuracy(_ accuracy: CLLocationAccuracy?) -> Bool {
        guard let accuracy else {
            return LocationManager.shared.lastKnownLocation != nil
        }
        guard accuracy > 0 else { return false }
        return accuracy < initialCameraAccuracyLimit
    }
    
    /// 足迹 Tab 第一帧：已锁定过则恢复上次视野，否则有定位就用手机位置
    static func makeInitialCameraPosition(forFootprintTab: Bool) -> MapCameraPosition {
        if forFootprintTab,
           hasSettledInitialCameraThisLaunch,
           let region = lastFootprintCameraRegion {
            return .region(region)
        }
        if forFootprintTab,
           let location = LocationManager.shared.lastKnownLocation,
           isAcceptableInitialAccuracy(LocationManager.shared.lastLocationAccuracy) {
            return .region(initialUserRegion(for: location))
        }
        return .region(startupFallbackRegion)
    }
    
    /// 足迹 Tab 也首帧挂 Map（默认上海，定位到后再跳）
    static func shouldShowMapOnFirstFrame(forFootprintTab: Bool) -> Bool {
        _ = forFootprintTab
        return true
    }
    
    /// 启动初始相机：仅冷启动飞一次；Tab 回来只恢复上次视野
    func beginInitialCameraSettlement() {
        guard !autoShowRouteCards else { return }
        
        if Self.hasSettledInitialCameraThisLaunch {
            restoreFootprintCameraAfterTabReturn()
            return
        }
        
        if initialCameraWaitStartedAt == nil {
            initialCameraWaitStartedAt = Date()
        }
        waitingForLocationToSetCamera = true
        if geocoder == nil {
            geocoder = CLGeocoder()
        }
        
        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            revealShanghaiFallback()
            return
        }
        
        locationManager.startUpdatingLocation(mode: .mapBrowsing)
        locationManager.requestLocation()
        
        // Splash 期间可能已经写入定位。onChange 不会补发旧值，这里主动走一次，
        // 相机和反向地理编码都能在 Map 出现时发生。
        if locationManager.lastKnownLocation != nil {
            handleLocationChange(newValue: locationManager.lastKnownLocation)
        }
        
        DispatchQueue.main.async {
            self.trySettleInitialCamera()
        }
        
        scheduleInitialCameraSettleRetries()
        if Self.pendingInitialCameraCoordinate == nil {
            scheduleShanghaiFallbackIfNeeded()
        }
    }
    
    /// 在 Map 尚未就绪时反复重试；已写入目标但未确认落地时也会重放相机
    private func scheduleInitialCameraSettleRetries() {
        initialCameraSettleTask?.cancel()
        initialCameraSettleTask = Task { @MainActor in
            let delays: [UInt64] = [
                50_000_000,
                200_000_000,
                500_000_000,
                1_000_000_000,
                2_000_000_000,
                3_500_000_000,
                5_000_000_000,
                8_000_000_000
            ]
            for delayNs in delays {
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled else { return }
                guard !Self.hasSettledInitialCameraThisLaunch else { return }
                if Self.pendingInitialCameraCoordinate != nil {
                    self.reapplyPendingInitialCamera()
                } else {
                    self.locationManager.requestLocation()
                    self.trySettleInitialCamera()
                }
            }
            guard !Task.isCancelled, !Self.hasSettledInitialCameraThisLaunch else { return }
            guard let location = Self.pendingInitialCameraCoordinate, self.isInitialMapVisible else { return }
            // 地图已按手机坐标创建，确认回调若被吞掉也解开锁定，避免一直不能拖动
            self.markInitialCameraSettled(at: location)
        }
    }
    
    /// 授权已定、仍没有可用定位时落到上海。权限框未关闭则继续等。
    private func scheduleShanghaiFallbackIfNeeded() {
        guard !autoShowRouteCards, !Self.hasSettledInitialCameraThisLaunch else { return }
        shanghaiFallbackTask?.cancel()
        shanghaiFallbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.shanghaiFallbackDelayNs)
            guard !Task.isCancelled else { return }
            self.revealShanghaiFallbackIfStillNeeded()
        }
    }
    
    private func revealShanghaiFallbackIfStillNeeded() {
        guard !autoShowRouteCards, !Self.hasSettledInitialCameraThisLaunch else { return }
        if Self.pendingInitialCameraCoordinate != nil { return }
        if let userLocation = locationManager.lastKnownLocation,
           shouldAcceptLocationForInitialCamera(accuracy: locationManager.lastLocationAccuracy) {
            applyInitialCamera(to: userLocation, animated: false)
            handleLocationChange(newValue: userLocation)
            return
        }
        if locationManager.authorizationStatus == .notDetermined {
            let waited = Date().timeIntervalSince(initialCameraWaitStartedAt ?? .distantPast)
            if waited < Self.shanghaiFallbackAuthorizationCap {
                scheduleShanghaiFallbackIfNeeded()
                return
            }
        }
        revealShanghaiFallback()
    }
    
    /// 找不到手机定位：用上海区域创建 Map。先锁定写回，等相机回调确认后再允许拖动。
    private func revealShanghaiFallback() {
        guard !autoShowRouteCards, !Self.hasSettledInitialCameraThisLaunch else { return }
        if let pending = Self.pendingInitialCameraCoordinate,
           !Self.pendingCameraUsesFallbackRegion {
            return
        }
        mapCameraPosition = .region(Self.startupFallbackRegion)
        isInitialMapVisible = true
        waitingForLocationToSetCamera = false
        Self.pendingInitialCameraCoordinate = Self.startupFallbackRegion.center
        Self.pendingCameraUsesFallbackRegion = true
        shanghaiFallbackTask?.cancel()
        shanghaiFallbackTask = nil
        print("📍 未取得手机定位，地图默认到上海")
    }
    
    /// Tab 切回足迹：静默恢复上次区域，不再飞向 GPS
    private func restoreFootprintCameraAfterTabReturn() {
        initialCameraPositionSet = true
        waitingForLocationToSetCamera = false
        isInitialMapVisible = true
        Self.pendingInitialCameraCoordinate = nil
        if let region = Self.lastFootprintCameraRegion {
            mapCameraPosition = .region(region)
        } else if let location = locationManager.lastKnownLocation {
            mapCameraPosition = .region(Self.initialUserRegion(for: location))
        }
        refetchVisibleDestinationsIfNeeded()
    }
    
    /// 有可用定位则落到用户附近；否则保持当前 fallback，不在重试里反复重置相机
    @discardableResult
    func trySettleInitialCamera() -> Bool {
        guard !Self.hasSettledInitialCameraThisLaunch, !autoShowRouteCards else {
            return Self.hasSettledInitialCameraThisLaunch
        }
        
        if let userLocation = locationManager.lastKnownLocation,
           shouldAcceptLocationForInitialCamera(accuracy: locationManager.lastLocationAccuracy) {
            if let pending = Self.pendingInitialCameraCoordinate,
               !Self.pendingCameraUsesFallbackRegion,
               Self.coordinatesMatch(pending, userLocation) {
                reapplyPendingInitialCamera()
            } else {
                applyInitialCamera(to: userLocation, animated: false)
            }
            return false
        }
        
        if Self.pendingInitialCameraCoordinate != nil {
            reapplyPendingInitialCamera()
            return false
        }
        
        waitingForLocationToSetCamera = true
        return false
    }
    
    private static func coordinatesMatch(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D,
        within meters: CLLocationDistance = 30
    ) -> Bool {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)) <= meters
    }
    
    private static func regionForPendingCamera(_ location: CLLocationCoordinate2D) -> MKCoordinateRegion {
        if pendingCameraUsesFallbackRegion {
            return startupFallbackRegion
        }
        return initialUserRegion(for: location)
    }
    
    private func shouldAcceptLocationForInitialCamera(accuracy: CLLocationAccuracy?) -> Bool {
        Self.isAcceptableInitialAccuracy(accuracy)
    }
    
    /// 先写入手机坐标再显示 Map，让第一帧就是该区域
    func applyInitialCamera(to location: CLLocationCoordinate2D, animated: Bool) {
        guard !Self.hasSettledInitialCameraThisLaunch else { return }
        isWaitingForUserLocate = false
        Self.pendingInitialCameraCoordinate = location
        Self.pendingCameraUsesFallbackRegion = false
        waitingForLocationToSetCamera = false
        shanghaiFallbackTask?.cancel()
        shanghaiFallbackTask = nil
        
        let region = Self.initialUserRegion(for: location)
        mapCameraPosition = .region(region)
        isInitialMapVisible = true
        
        let accuracy = locationManager.lastLocationAccuracy ?? -1
        print("📍 初始相机已请求飞向用户: (\(location.latitude), \(location.longitude)), 精度=\(String(format: "%.1f", accuracy))米（待 Map 确认）")
        
        if let visible = visibleRegion ?? regionHolder.pending {
            confirmInitialCameraIfNeeded(region: visible)
        }
        
        _ = animated
    }
    
    private func reapplyPendingInitialCamera() {
        guard !Self.hasSettledInitialCameraThisLaunch,
              let location = Self.pendingInitialCameraCoordinate else { return }
        mapCameraPosition = .region(Self.regionForPendingCamera(location))
        isInitialMapVisible = true
        if let visible = visibleRegion ?? regionHolder.pending {
            confirmInitialCameraIfNeeded(region: visible)
        }
    }
    
    /// Map 相机回调确认已落到用户附近后再标记成功并停重试
    func confirmInitialCameraIfNeeded(region: MKCoordinateRegion) {
        guard !Self.hasSettledInitialCameraThisLaunch,
              let target = Self.pendingInitialCameraCoordinate else { return }
        
        let center = region.center
        let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        guard distance <= Self.initialCameraConfirmDistance else { return }
        
        markInitialCameraSettled(at: target)
    }
    
    /// 确认后又被拉回远处（常见于 fallback 重入 / 零尺寸 Map 复位）时再锁一次
    func guardInitialCameraAgainstDrift(region: MKCoordinateRegion) {
        guard Self.hasSettledInitialCameraThisLaunch,
              let anchor = Self.settledInitialCameraCoordinate,
              let guardUntil = Self.initialCameraDriftGuardUntil,
              Date() < guardUntil else { return }
        
        let center = region.center
        let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: anchor.latitude, longitude: anchor.longitude))
        guard distance > Self.initialCameraDriftDistance else { return }
        
        print("⚠️ 初始相机漂移 \(Int(distance))m，重新锁定用户位置")
        mapCameraPosition = .region(Self.initialUserRegion(for: anchor))
        mapCameraBootstrapID = UUID()
        Self.initialCameraDriftGuardUntil = Date().addingTimeInterval(Self.initialCameraDriftGuardDuration)
    }
    
    private func markInitialCameraSettled(at location: CLLocationCoordinate2D) {
        guard !Self.hasSettledInitialCameraThisLaunch else { return }
        let usesFallback = Self.pendingCameraUsesFallbackRegion
        Self.hasSettledInitialCameraThisLaunch = true
        Self.pendingInitialCameraCoordinate = nil
        Self.pendingCameraUsesFallbackRegion = false
        Self.settledInitialCameraCoordinate = location
        Self.initialCameraDriftGuardUntil = usesFallback
            ? nil
            : Date().addingTimeInterval(Self.initialCameraDriftGuardDuration)
        waitingForLocationToSetCamera = false
        initialCameraPositionSet = true
        initialCameraSettleTask?.cancel()
        initialCameraSettleTask = nil
        shanghaiFallbackTask?.cancel()
        shanghaiFallbackTask = nil
        
        mapCameraPosition = .region(
            usesFallback ? Self.startupFallbackRegion : Self.initialUserRegion(for: location)
        )
        isInitialMapVisible = true
        
        if usesFallback {
            print("📍 未取得手机定位，地图已落到上海")
        } else {
            print("📍 地图已定位到用户位置: (\(location.latitude), \(location.longitude))")
        }
        refetchVisibleDestinationsIfNeeded()
    }
    
    // 设置地图相机到用户位置
    func setCameraToUserLocation(_ location: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(Self.initialUserRegion(for: location))
        }
    }
    
    // 处理视图消失
    func handleViewDisappear() {
        if !autoShowRouteCards, let region = visibleRegion ?? regionHolder.pending {
            Self.lastFootprintCameraRegion = region
        }
        // 未确认的初始飞跃下次 appear 用 lastKnownLocation 重来，避免残留 pending
        if !Self.hasSettledInitialCameraThisLaunch {
            Self.pendingInitialCameraCoordinate = nil
            Self.pendingCameraUsesFallbackRegion = false
        }
        startupContentRevealTask?.cancel()
        startupContentRevealTask = nil
        initialCameraSettleTask?.cancel()
        initialCameraSettleTask = nil
        shanghaiFallbackTask?.cancel()
        shanghaiFallbackTask = nil
        regionHolder.cancelDebounce()
        regionFetchTask?.cancel()
        regionFetchTask = nil
        destinationMetadataTask?.cancel()
        destinationWeatherManager.setPaused(true)
        if mapViewInNavigationStack {
            locationManager.stopUpdatingLocation()
        }
        if locationManager.currentMode == .checkIn {
            locationManager.applyMode(.mapBrowsing)
        }
        geocodeTimeoutTimer?.invalidate()
        geocodeTimeoutTimer = nil
        pendingGeocodeCoordinate = nil
    }
    
    /// 打开线路地图前从 RouteManager / TripRoutePrecomputationStore 预填 `tripRoutes`
    /// - Returns: 是否全部段均已缓存（可跳过占位虚线）
    @discardableResult
    func prefillTripRoutesFromCache(tripId: UUID, coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count >= 2 else { return false }
        
        let segmentCount = coordinates.count - 1
        var routes = routeManager.cachedRoutes(for: coordinates)
        if routes.count < segmentCount {
            routes.append(contentsOf: Array(repeating: nil, count: segmentCount - routes.count))
        }
        
        if !routes.allSatisfy({ $0 != nil }),
           let precomputed = TripRoutePrecomputationStore.shared.precomputedRoutes(
               for: tripId,
               segmentCount: segmentCount
           ) {
            for index in routes.indices where routes[index] == nil {
                routes[index] = precomputed[index]
            }
        }
        
        let allCached = routes.allSatisfy { $0 != nil }
        tripRoutes[tripId] = routes
        syncTripRoutesToSharedStore()
        if allCached {
            print("✅ 旅程 \(tripId.uuidString.prefix(8)) 的路线已从缓存预填，共 \(routes.count) 段")
        } else {
            let hitCount = routes.compactMap { $0 }.count
            print("📋 旅程 \(tripId.uuidString.prefix(8)) 路线缓存 \(hitCount)/\(segmentCount) 段，缺段显示占位线并异步补算")
        }
        
        return allCached
    }

    /// 预填缓存、缩放地图；缺失段则异步补算（仅旅程线路图）
    @discardableResult
    func presentTripRoute(tripId: UUID, destinations: [TravelDestination]) -> Bool {
        guard destinations.count >= 2 else { return false }

        let coordinates = destinations.map { $0.coordinate }
        let allCached = prefillTripRoutesFromCache(tripId: tripId, coordinates: coordinates)
        let zoomDuration: TimeInterval = allCached ? 0.25 : 0.8

        zoomToTripDestinations(destinations, animationDuration: zoomDuration)

        if !allCached {
            Task {
                await calculateRoutesForTrip(tripId: tripId, coordinates: coordinates, incremental: true)
            }
        }

        return allCached
    }
    
    // 旅程线路图：选中旅程并缩放、预填/补算路线
    func handleAutoShowRouteCards() {
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
            let destinations = sortedDestinations(for: currentSelectedId)
            if destinations.count >= 2 {
                targetTrip = currentTrip
                tripDestinations = destinations
            }
        } else if let firstValidTrip = validTrips.first {
            let destinations = sortedDestinations(for: firstValidTrip.id)
            if destinations.count >= 2 {
                targetTrip = firstValidTrip
                tripDestinations = destinations
                setSelectedTripId(firstValidTrip.id)
            }
        }
        
        if let trip = targetTrip, let destinations = tripDestinations {
            presentTripRoute(tripId: trip.id, destinations: destinations)
        } else if let fallbackTrip = allTrips.first(where: { trip in
            if let selectedId = selectedTripId {
                return trip.id == selectedId
            }
            return true
        }) {
            if selectedTripId != fallbackTrip.id {
                setSelectedTripId(fallbackTrip.id)
            }
        } else {
            setSelectedTripId(nil)
        }
    }
    
    // 处理足迹抽屉选择
    func handleFootprintsSelect(_ destination: TravelDestination) {
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
    func handleFootprintsAdd() {
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
    func handleFootprintsImport() {
        showingFootprintsDrawer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            addDestinationPrefill = nil
            pendingPhotoPrefill = nil
            photoImportItems = []
            isGeocodingLocation = false
            isWaitingForLocation = false
            showingPhotoImportPicker = true
        }
    }
    
    // 地图层
}
