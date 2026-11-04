//
//  MapView+Routes.swift
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
    func scheduleClusterRecalculationIfNeeded() {
        guard !autoShowRouteCards else { return }
        guard isMapTabActive else { return }
        if isThermallyCritical { return }
        
        let currentZoomEnum = currentZoomLevelEnum
        let visibleDestinations = visibleDestinationsInRegion
        let currentCount = visibleDestinations.count
        let currentRegionKey = visibleRegionKey
        
        if !cachedClusterAnnotations.isEmpty &&
            cachedZoomLevelEnum == currentZoomEnum &&
            cachedDestinationsCount == currentCount &&
            cachedVisibleRegionKey == currentRegionKey {
            return
        }
        
        if isCalculatingClusters { return }
        if scheduledClusterRegionKey == currentRegionKey && !currentRegionKey.isEmpty { return }
        if cachedClusterAnnotations.isEmpty && visibleDestinations.isEmpty { return }
        
        scheduledClusterRegionKey = currentRegionKey
        isCalculatingClusters = true
        
        let capturedZoomEnum = currentZoomEnum
        let capturedDestinations = visibleDestinations
        let capturedCount = currentCount
        let capturedRegionKey = currentRegionKey
        let capturedDistance = clusterDistance
        let capturedMaxMarkers = MapDestinationFetcher.maxVisibleMarkers
        let capturedPoints = capturedDestinations.map {
            MapClusterPoint(id: $0.id, latitude: $0.latitude, longitude: $0.longitude)
        }
        let destinationByID = Dictionary(uniqueKeysWithValues: capturedDestinations.map { ($0.id, $0) })
        let capturedTotalDestinations = totalDestinationCount
        clusterCalculationGeneration += 1
        let generation = clusterCalculationGeneration
        
        Task.detached(priority: .utility) {
            let startTime = Date()
            let groups = MapClusterEngine.clusterGroups(
                points: capturedPoints,
                distance: capturedDistance,
                maxClusters: capturedMaxMarkers
            )
            let calculationTime = Date().timeIntervalSince(startTime)
            let renderedClusterCount = groups.count
            
            await MainActor.run {
                guard generation == clusterCalculationGeneration else {
                    isCalculatingClusters = false
                    scheduledClusterRegionKey = ""
                    return
                }
                
                let clusters = groups.map { ids in
                    ClusterAnnotation(destinations: ids.compactMap { destinationByID[$0] })
                }
                
                cachedClusterAnnotations = clusters
                cachedZoomLevelEnum = capturedZoomEnum
                cachedDestinationsCount = capturedCount
                cachedVisibleRegionKey = capturedRegionKey
                lastCalculationTime = Date()
                isCalculatingClusters = false
                scheduledClusterRegionKey = ""
                
                #if DEBUG
                print("🔄 聚合计算完成: \(capturedZoomEnum.description)级别, 耗时: \(String(format: "%.3f", calculationTime))秒, 标注: \(renderedClusterCount)/\(capturedMaxMarkers), 输入地点: \(capturedCount)/\(capturedTotalDestinations)")
                #endif
            }
        }
    }
    
    // 清除聚合缓存
    func clearClusterCache() {
        isCalculatingClusters = false
        scheduledClusterRegionKey = ""
        
        cachedClusterAnnotations = []
        cachedZoomLevelEnum = .world
        cachedDestinationsCount = 0
        cachedVisibleRegionKey = ""
        lastCalculationTime = Date()
        print("🧹 已清除聚合缓存")
    }
    
    /// 与 `TripRoutePrecomputationStore` 同步，使「旅程卡片」总里程与地图 `tripRoutes` 一致
    func syncTripRoutesToSharedStore() {
        TripRoutePrecomputationStore.shared.sync(from: tripRoutes)
    }
    
    // 处理地点变化（立即更新路线）
    func handleDestinationsChange() {
        print("🔄 处理地点变化，重新计算路线...")
        // 清除聚合缓存
        clearClusterCache()
        // 清除排序缓存（地点变化后需要重新排序）
        clearSortedDestinationsCache()
        // 清除路线缓存，强制重新计算
        tripRoutes.removeAll()
        syncTripRoutesToSharedStore()
        
        // 仅旅程线路图计算当前选中旅程的路线
        if autoShowRouteCards {
            if let selectedTripId = selectedTripId,
               let selectedTrip = effectiveTrips.first(where: { $0.id == selectedTripId }),
               let tripDestinations = selectedTrip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }),
               tripDestinations.count >= 2 {
                let coordinates = tripDestinations.map { $0.coordinate }
                Task {
                    await calculateRoutesForTrip(tripId: selectedTripId, coordinates: coordinates, incremental: false)
                }
            } else if let selectedTripId = selectedTripId {
                tripRoutes.removeValue(forKey: selectedTripId)
                syncTripRoutesToSharedStore()
            }
        }
        // 更新签名
        lastDestinationsSignature = trackedDestinationsSignature
        destinationsInVisibleRegion = nil
        refetchVisibleDestinationsIfNeeded()
    }
    
    // 检查地点变化并更新路线（通过签名比较）
    func checkDestinationsChange() {
        let currentSignature = trackedDestinationsSignature
        // 如果签名发生变化，说明有地点被删除、坐标变化或所属旅程变化
        if lastDestinationsSignature != "" && lastDestinationsSignature != currentSignature {
            print("🔄 通过签名检测到地点变化")
            handleDestinationsChange()
        } else {
            // 即使签名相同，也更新签名（防止下次误判）
            lastDestinationsSignature = currentSignature
        }
    }
    
    // 为单个旅程计算路线（优化版：并发计算 + 渐进式更新 + 增量更新）
    /// - Parameters:
    ///   - tripId: 旅程ID
    ///   - coordinates: 地点坐标数组
    ///   - incremental: 是否使用增量更新（检查缓存）
    func calculateRoutesForTrip(tripId: UUID, coordinates: [CLLocationCoordinate2D], incremental: Bool = false) async {
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
            
            // 收集结果并渐进式更新 UI（按段替换占位虚线）
            for await (index, route) in group {
                calculatedRoutes[index] = route
                
                await MainActor.run {
                    var updated = self.tripRoutes[tripId] ?? Array(repeating: nil, count: coordinates.count - 1)
                    if updated.count != coordinates.count - 1 {
                        updated = Array(repeating: nil, count: coordinates.count - 1)
                    }
                    updated[index] = route
                    withAnimation(.easeInOut(duration: 0.28)) {
                        self.tripRoutes[tripId] = updated
                    }
                    self.syncTripRoutesToSharedStore()
                }
            }
        }
        
        // 最终更新：确保所有路线都已显示
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.28)) {
                tripRoutes[tripId] = calculatedRoutes
            }
            syncTripRoutesToSharedStore()
            let successCount = calculatedRoutes.compactMap { $0 }.count
            print("✅ 旅程 \(tripId.uuidString.prefix(8)) 的路线计算完成，共 \(successCount)/\(coordinates.count - 1) 段路线")
        }
    }
    
    /// 重试失败的路线计算（占位线重试机制）
    /// - Parameters:
    ///   - tripId: 旅程ID
    ///   - coordinates: 旅程地点坐标数组
    func retryFailedRoutesForTrip(tripId: UUID, coordinates: [CLLocationCoordinate2D]) async {
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
}
