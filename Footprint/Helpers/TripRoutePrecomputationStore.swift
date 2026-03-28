//
//  TripRoutePrecomputationStore.swift
//  Footprint
//
//  与 MapView `tripRoutes` 同步，供「旅程卡片」总里程与地图抽屉 `RouteCard` 使用相同的预计算路线。
//

import Foundation
import MapKit
import Combine

@MainActor
final class TripRoutePrecomputationStore: ObservableObject {
    static let shared = TripRoutePrecomputationStore()
    
    /// 各旅程 `MKRoute` 段（与 `JourneyDrawer` 传入 `RouteCard` 的 `precomputedRoutes` 同源）
    @Published private(set) var routesByTripId: [UUID: [MKRoute]] = [:]
    
    func sync(from tripRoutes: [UUID: [MKRoute?]]) {
        let newMap: [UUID: [MKRoute]] = tripRoutes.mapValues { $0.compactMap { $0 } }
        guard !approximatelyEqual(newMap, routesByTripId) else { return }
        routesByTripId = newMap
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
