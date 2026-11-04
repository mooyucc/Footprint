//
//  TripRoutePrecomputationStore.swift
//  Footprint
//
//  与 MapView `tripRoutes` 同步，供「旅程卡片」总里程使用相同的预计算路线。
//

import Foundation
import MapKit
import Combine

@MainActor
final class TripRoutePrecomputationStore: ObservableObject {
    static let shared = TripRoutePrecomputationStore()
    
    /// 各旅程 `MKRoute` 段（与 MapView `tripRoutes` 同源）
    @Published private(set) var routesByTripId: [UUID: [MKRoute]] = [:]
    
    func sync(from tripRoutes: [UUID: [MKRoute?]]) {
        let newMap: [UUID: [MKRoute]] = tripRoutes.mapValues { $0.compactMap { $0 } }
        guard !approximatelyEqual(newMap, routesByTripId) else { return }
        routesByTripId = newMap
    }
    
    /// 写入预热或主地图同步的整趟路线（段数须完整才存储）
    func storeRoutes(for tripId: UUID, routes: [MKRoute?]) {
        guard routes.allSatisfy({ $0 != nil }) else { return }
        let compact = routes.compactMap { $0 }
        guard compact.count == routes.count else { return }
        routesByTripId[tripId] = compact
    }
    
    /// 主地图已算好的整趟路线（段数须与 `segmentCount` 一致才可信）
    func precomputedRoutes(for tripId: UUID, segmentCount: Int) -> [MKRoute]? {
        guard segmentCount > 0,
              let routes = routesByTripId[tripId],
              routes.count == segmentCount else {
            return nil
        }
        return routes
    }
    
    private func approximatelyEqual(_ a: [UUID: [MKRoute]], _ b: [UUID: [MKRoute]]) -> Bool {
        guard a.count == b.count else { return false }
        for (id, routesA) in a {
            guard let routesB = b[id] else { return false }
            guard routesA.count == routesB.count else { return false }
            let sumA = routesA.reduce(0.0) { $0 + $1.footprintDistance }
            let sumB = routesB.reduce(0.0) { $0 + $1.footprintDistance }
            if abs(sumA - sumB) > 1.0 { return false }
        }
        return true
    }
}
