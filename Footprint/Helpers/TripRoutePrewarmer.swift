//
//  TripRoutePrewarmer.swift
//  Footprint
//
//  打开旅程地图 Sheet 时从 RouteManager 磁盘/内存缓存预填；实际 MKDirections 仅由 MapView 在缺段时增量计算。
//

import Foundation
import MapKit

@MainActor
enum TripRoutePrewarmer {
    private static var warmTasks: [UUID: Task<Void, Never>] = [:]
    
    /// 将已持久化的段缓存同步到本会话 `TripRoutePrecomputationStore`（无网络）
    static func syncSessionStoreFromCache(for trip: TravelTrip) {
        guard let routes = cachedRoutesIfComplete(for: trip) else { return }
        TripRoutePrecomputationStore.shared.storeRoutes(for: trip.id, routes: routes)
    }
    
    /// 卡片聚焦时后台预热缺段（限并发；已全缓存则跳过）
    static func warmMissingSegments(for trip: TravelTrip, maxConcurrentMisses: Int = 3) {
        guard let destinations = sortedDestinations(for: trip), destinations.count >= 2 else { return }
        guard !isFullyCached(for: trip) else { return }
        
        warmTasks[trip.id]?.cancel()
        warmTasks[trip.id] = Task {
            let coordinates = destinations.map { $0.coordinate }
            let routes = await RouteManager.shared.incrementalRoutes(
                for: coordinates,
                maxConcurrentMisses: maxConcurrentMisses
            )
            guard !Task.isCancelled else { return }
            if routes.allSatisfy({ $0 != nil }) {
                TripRoutePrecomputationStore.shared.storeRoutes(for: trip.id, routes: routes)
                print("🔥 旅程 \(trip.id.uuidString.prefix(8)) 路线预热完成，共 \(routes.count) 段")
            }
            warmTasks.removeValue(forKey: trip.id)
        }
    }
    
    static func cancelWarm(for tripId: UUID) {
        warmTasks[tripId]?.cancel()
        warmTasks.removeValue(forKey: tripId)
    }

    /// 打开线路 Sheet 前同步预填（会话 store → RouteManager 段缓存）；不全则为部分段或 nil
    static func prefillRoutes(for trip: TravelTrip) -> [MKRoute?]? {
        guard let destinations = sortedDestinations(for: trip), destinations.count >= 2 else { return nil }
        let segmentCount = destinations.count - 1
        let coordinates = destinations.map { $0.coordinate }

        if let precomputed = TripRoutePrecomputationStore.shared.precomputedRoutes(
            for: trip.id,
            segmentCount: segmentCount
        ) {
            return precomputed.map { $0 as MKRoute? }
        }

        let routes = RouteManager.shared.cachedRoutes(for: coordinates)
        if routes.allSatisfy({ $0 != nil }) {
            TripRoutePrecomputationStore.shared.storeRoutes(for: trip.id, routes: routes)
            return routes
        }

        guard routes.contains(where: { $0 != nil }) else { return nil }
        return routes
    }

    /// 整趟路线是否已在缓存中（无需再请求 MKDirections）
    static func isFullyCached(for trip: TravelTrip) -> Bool {
        cachedRoutesIfComplete(for: trip) != nil
    }

    private static func cachedRoutesIfComplete(for trip: TravelTrip) -> [MKRoute?]? {
        guard let destinations = sortedDestinations(for: trip), destinations.count >= 2 else { return nil }
        let segmentCount = destinations.count - 1
        let coordinates = destinations.map { $0.coordinate }

        if let precomputed = TripRoutePrecomputationStore.shared.precomputedRoutes(
            for: trip.id,
            segmentCount: segmentCount
        ) {
            return precomputed.map { $0 as MKRoute? }
        }

        let routes = RouteManager.shared.cachedRoutes(for: coordinates)
        guard routes.allSatisfy({ $0 != nil }) else { return nil }
        return routes
    }

    private static func sortedDestinations(for trip: TravelTrip) -> [TravelDestination]? {
        trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate })
    }
}
