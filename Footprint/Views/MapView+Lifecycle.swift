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
                // 当应用就绪状态从 false 变为 true 时（启动画面结束），执行延迟的初始化
                if !oldValue && newValue && locationInitializationPending {
                    print("✅ 启动画面已结束，定位服务已在启动画面期间启动，直接设置地图相机位置")
                    locationInitializationPending = false
                    // 定位服务已在启动画面期间启动，这里只需要设置地图相机位置
                    setInitialMapCameraPosition()
                }
                if !oldValue && newValue, !autoShowRouteCards {
                    refreshDestinationMetadata(triggerChangeHandler: false)
                    refetchVisibleDestinationsIfNeeded()
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
        if !autoShowRouteCards {
            refreshDestinationMetadata(triggerChangeHandler: false)
            refetchVisibleDestinationsIfNeeded()
            scheduleClusterRecalculationIfNeeded()
        }
        
        syncWeatherManagerPauseState()
        
        // 主 Tab 地图的定位启停由 ContentView（scenePhase + 选中 tab）统一管理，避免与 onDisappear 重复 stop/start。
        // 旅程线路 Sheet 复用已有 lastKnownLocation 显示蓝点即可，不持续定位，避免无关 geocode 与耗电。
        if mapViewInNavigationStack && !autoShowRouteCards {
            locationManager.startUpdatingLocation(mode: .mapBrowsing)
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
    func setInitialMapCameraPosition() {
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
    func setCameraToUserLocation(_ location: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // 约5公里范围
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(region)
        }
    }
    
    // 处理视图消失
    func handleViewDisappear() {
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
