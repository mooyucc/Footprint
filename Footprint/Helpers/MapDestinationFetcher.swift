//
//  MapDestinationFetcher.swift
//  Footprint
//
//  On-demand SwiftData fetches for MapView (replaces full @Query subscription).
//

import Foundation
import MapKit
import SwiftData

enum MapDestinationFetcher {
    /// 可见区域内拉取上限（聚类输入缓冲，略高于最终渲染上限）
    static let regionFetchLimit = 100
    /// 地图上最多渲染的标注数（与 MapClusterEngine.maxVisibleClusters 对齐）
    static let maxVisibleMarkers = 50

    static func fetchCount(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<TravelDestination>())) ?? 0
    }

    /// 轻量变更签名：count + 最新 visitDate，避免全量 O(n) hash
    static func fetchLightSignature(in context: ModelContext) -> String {
        let count = fetchCount(in: context)
        var descriptor = FetchDescriptor<TravelDestination>(
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let latest = (try? context.fetch(descriptor).first?.visitDate.timeIntervalSince1970) ?? 0
        return "\(count)-\(Int(latest))"
    }

    static func fetchAllSortedByVisitDate(in context: ModelContext, reverse: Bool = true) -> [TravelDestination] {
        let descriptor = FetchDescriptor<TravelDestination>(
            sortBy: [SortDescriptor(\.visitDate, order: reverse ? .reverse : .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchRandom(in context: ModelContext) -> TravelDestination? {
        let count = fetchCount(in: context)
        guard count > 0 else { return nil }

        var descriptor = FetchDescriptor<TravelDestination>()
        descriptor.fetchOffset = Int.random(in: 0..<count)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func fetchInRegion(
        _ region: MKCoordinateRegion,
        in context: ModelContext,
        marginRatio: Double = 0.05,
        limit: Int = regionFetchLimit
    ) -> [TravelDestination] {
        let margin = max(region.span.latitudeDelta, region.span.longitudeDelta) * marginRatio
        let minLat = region.center.latitude - region.span.latitudeDelta / 2 - margin
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2 + margin
        let minLon = region.center.longitude - region.span.longitudeDelta / 2 - margin
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2 + margin

        var descriptor = FetchDescriptor<TravelDestination>(
            predicate: #Predicate<TravelDestination> { destination in
                destination.latitude >= minLat && destination.latitude <= maxLat &&
                destination.longitude >= minLon && destination.longitude <= maxLon
            },
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
