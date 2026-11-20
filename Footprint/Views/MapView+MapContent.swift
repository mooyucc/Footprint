//
//  MapView+MapContent.swift
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
    var mapLayer: some View {
        // 始终挂真 Map：无定位时首帧为上海，定位到后再跳到用户位置
        interactiveMap
    }

    /// 初始锁定完成前忽略 Map 写回，避免首帧把手机位置盖掉
    var lockedMapCameraPosition: Binding<MapCameraPosition> {
        Binding(
            get: { mapCameraPosition },
            set: { newValue in
                let keepProgrammaticCamera = !autoShowRouteCards
                    && !Self.hasCompletedInitialCameraSettlement
                    && isInitialMapVisible
                if keepProgrammaticCamera { return }
                mapCameraPosition = newValue
            }
        )
    }

    var interactiveMap: some View {
        MapReader { proxy in
            Map(position: lockedMapCameraPosition, selection: $mapSelection) {
                tripConnections
                if autoShowRouteCards {
                    routeTripDestinationMarkers
                } else if isStartupContentVisible {
                    // 揭晓前不画标注，先让 Map / 瓦片格子露出
                    clusterMarkers
                }
                if isStartupContentVisible || autoShowRouteCards {
                    memoryBubbleDestinationMarker
                }
                userLocationMarker
            }
            .id(mapCameraBootstrapID)
            .mapStyle(currentMapStyle.toMapKitStyle())
            .onMapCameraChange(frequency: .continuous) { context in
                guard isMapTabActive || autoShowRouteCards else { return }
                // 只写非 Observable 持有者，避免每帧触发 MapView body 重绘
                regionHolder.pending = context.region
                // 初始定位确认不等 debounce，避免首飞成功被拖到 0.3s 后才停重试
                confirmInitialCameraIfNeeded(region: context.region)
                guardInitialCameraAgainstDrift(region: context.region)
                regionHolder.scheduleDebouncedCommit {
                    commitVisibleRegionUpdate()
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
    
    /// 路线 polyline 渲染分级（LOD），降低低 zoom 时 GPU 负载
    enum RoutePolylineDetail {
        case hidden
        case simplified
        case full
    }
    
    var routePolylineDetail: RoutePolylineDetail {
        if isThermallyCritical { return .hidden }
        // 仅旅程线路图显示路线；足迹 Tab 不画连线
        guard autoShowRouteCards else { return .hidden }
        let zoom = currentZoomLevel
        // 低 zoom 仍显示 simplified 实线，避免误回退占位虚线
        if zoom < 12 { return .simplified }
        return .full
    }
    
    func applyThermalMitigation(_ state: ProcessInfo.ThermalState) {
        thermalState = state
        destinationWeatherManager.setThermallyLimited(state != .nominal)
        locationManager.applyThermalMitigation(state)
        
        if state == .serious || state == .critical {
            showSoapBubbles = false
            selectedBubbleDestination = nil
            assistiveMenuExpanded = false
        }

        if state == .nominal || state == .fair {
            scheduleClusterRecalculationIfNeeded()
        }
    }
    
    // 旅程连线（仅旅程线路图）
    @MapContentBuilder
    var tripConnections: some MapContent {
        if !autoShowRouteCards {
            // 足迹 Tab 不显示连线
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
                        
                        if hasValidRoutes, routePolylineDetail != .hidden {
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
                                            } else if routePolylineDetail == .simplified {
                                                MapPolyline(route.polyline)
                                                    .stroke(
                                                        routeColor,
                                                        style: StrokeStyle(
                                                            lineWidth: 4,
                                                            lineCap: .round,
                                                            lineJoin: .round
                                                        )
                                                    )
                                            } else {
                                                // 街道级：白色描边 + 主体颜色
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
                                            
                                            // 距离标注：路线可见时始终显示（含看全旅程的远景）
                                            if routePolylineDetail != .hidden,
                                               let midpoint = midpointOfPolyline(route.polyline) {
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
                        } else if !hasValidRoutes {
                            // 仅无缓存路线时显示占位虚线；有路线但 LOD 隐藏时不画占位线，避免误导
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
    
    // 线路模式：直接标注旅程地点，跳过聚类计算
    @MapContentBuilder
    var routeTripDestinationMarkers: some MapContent {
        ForEach(visibleDestinationsForSelectedTrip) { destination in
            Annotation(destination.name, coordinate: destination.coordinate) {
                ClusterAnnotationView(
                    cluster: ClusterAnnotation(destinations: [destination], displayType: .simplifiedAvatar),
                    zoomLevel: currentZoomLevel,
                    tripColorMap: tripColorMapping,
                    accentColor: brandAccentColor,
                    weatherSummary: nil,
                    mapMode: .myFootprints
                )
                .equatable()
                .onTapGesture {
                    annotationTapInProgress = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        annotationTapInProgress = false
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDestination = destination
                        mapSelection = destination
                    }
                }
            }
        }
    }
    
    /// 回忆泡泡流程中需要钉住的目标地点（飞行中或吹泡泡时）
    var memoryBubblePinnedDestination: TravelDestination? {
        guard !autoShowRouteCards else { return nil }
        guard let destination = selectedBubbleDestination ?? targetBubbleDestination else { return nil }
        let alreadyInClusters = clusterAnnotations.contains {
            $0.destinations.count == 1 && $0.destinations[0].id == destination.id
        }
        return alreadyInClusters ? nil : destination
    }
    
    // 回忆泡泡：目标地点临时圆圈标记（不依赖异步 fetch/聚类）
    @MapContentBuilder
    var memoryBubbleDestinationMarker: some MapContent {
        if let destination = memoryBubblePinnedDestination {
            Annotation(destination.name, coordinate: destination.coordinate) {
                ClusterAnnotationView(
                    cluster: ClusterAnnotation(destinations: [destination]),
                    zoomLevel: currentZoomLevel,
                    tripColorMap: tripColorMapping,
                    accentColor: brandAccentColor,
                    weatherSummary: nil,
                    mapMode: .myFootprints
                )
                .equatable()
            }
        }
    }
    
    // 聚合标记
    @MapContentBuilder
    var clusterMarkers: some MapContent {
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
    
    func syncWeatherManagerPauseState() {
        destinationWeatherManager.setPaused(scenePhase != .active || !mapWeatherEnabled || !isMapTabActive)
    }
    
    func weatherSummary(for cluster: ClusterAnnotation) -> WeatherSummary? {
        guard mapWeatherEnabled else { return nil }
        // 性能优化：在线路卡片模式下不显示天气 tag，减少数据更新计算
        guard !autoShowRouteCards else { return nil }
        
        guard cluster.destinations.count == 1,
              let destination = cluster.destinations.first
        else { return nil }
        return destinationWeatherManager.summary(for: destination.id)
    }
    
    func shouldDisplayWeather(for cluster: ClusterAnnotation) -> Bool {
        guard mapWeatherEnabled else { return false }
        // 性能优化：在线路卡片模式下不显示天气
        guard !autoShowRouteCards else { return false }
        return currentZoomLevel >= 12 && cluster.destinations.count == 1
    }
    
    func weatherTaskIdentifier(for cluster: ClusterAnnotation) -> String {
        "\(cluster.id)-\(currentZoomLevelEnum.rawValue)-\(mapWeatherEnabled)"
    }
    
    func requestWeatherIfNeeded(for cluster: ClusterAnnotation) async {
        // 性能优化：在线路卡片模式下不请求天气数据
        guard !autoShowRouteCards else { return }
        guard isMapTabActive else { return }
        guard !isThermallyLimited && !isThermallyCritical else { return }
        
        guard shouldDisplayWeather(for: cluster),
              let destination = cluster.destinations.first
        else { return }
        await destinationWeatherManager.refreshWeatherIfNeeded(for: destination)
    }
    
    // 用户位置标记
    @MapContentBuilder
    var userLocationMarker: some MapContent {
        if let userLocation = locationManager.lastKnownLocation {
            Annotation("", coordinate: userLocation) {
                UserLocationAnnotationView()
            }
        }
    }
    
    // 长按手势
    func longPressGesture(proxy: MapProxy) -> some Gesture {
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
    func tapGesture(proxy: MapProxy) -> some Gesture {
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
    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
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
    func isNearAnnotationOrCluster(_ coordinate: CLLocationCoordinate2D) -> Bool {
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
}
