//
//  TripRoutePrewarmer.swift
//  Footprint
//
//  旅程卡片页后台预热路线缓存，供线路 Sheet 秒开。
//

import Foundation
import MapKit

@MainActor
enum TripRoutePrewarmer {
    private static var activeTask: Task<Void, Never>?
    
    /// 对焦点卡片及相邻 1～2 张卡片增量预热（single-flight，避免 MKDirections 限流）
    static func schedulePrewarm(for trips: [TravelTrip], focusIndex: Int) {
        activeTask?.cancel()
        guard !trips.isEmpty else { return }
        
        let indices = Set([focusIndex, focusIndex - 1, focusIndex + 1, focusIndex + 2])
            .filter { $0 >= 0 && $0 < trips.count }
            .sorted()
        
        activeTask = Task {
            for index in indices {
                guard !Task.isCancelled else { return }
                await prewarm(trips[index])
            }
        }
    }
    
    /// 打开线路 Sheet 前同步预填（RouteManager 段缓存 + TripRoutePrecomputationStore）
    static func prefillRoutes(for trip: TravelTrip) -> [MKRoute?]? {
        guard let destinations = sortedDestinations(for: trip), destinations.count >= 2 else { return nil }
        let coordinates = destinations.map { $0.coordinate }
        var routes = RouteManager.shared.cachedRoutes(for: coordinates)
        
        if !routes.allSatisfy({ $0 != nil }),
           let precomputed = TripRoutePrecomputationStore.shared.precomputedRoutes(
               for: trip.id,
               segmentCount: coordinates.count - 1
           ) {
            for index in routes.indices where routes[index] == nil {
                routes[index] = precomputed[index]
            }
        }
        
        guard routes.contains(where: { $0 != nil }) else { return nil }
        return routes
    }
    
    private static func prewarm(_ trip: TravelTrip) async {
        guard let destinations = sortedDestinations(for: trip), destinations.count >= 2 else { return }
        let coordinates = destinations.map { $0.coordinate }
        
        let cached = RouteManager.shared.cachedRoutes(for: coordinates)
        if cached.allSatisfy({ $0 != nil }) {
            TripRoutePrecomputationStore.shared.storeRoutes(for: trip.id, routes: cached)
            return
        }
        
        let routes = await RouteManager.shared.incrementalRoutes(for: coordinates, maxConcurrentMisses: 2)
        if routes.allSatisfy({ $0 != nil }) {
            TripRoutePrecomputationStore.shared.storeRoutes(for: trip.id, routes: routes)
        }
    }
    
    private static func sortedDestinations(for trip: TravelTrip) -> [TravelDestination]? {
        trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate })
    }
}
