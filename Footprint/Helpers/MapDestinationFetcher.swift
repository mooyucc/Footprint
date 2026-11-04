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

    static func fetchMapChangeSignature(in context: ModelContext) -> String {
        let descriptor = FetchDescriptor<TravelDestination>(
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        let list = (try? context.fetch(descriptor)) ?? []
        return DestinationCollectionSignature.makeForMap(from: list)
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

    /// 在 Splash 期间把地点和旅程装进视图上下文（须为主上下文）。
    /// 临时 `ModelContext` 的缓存不会留给 `@Query`，首次切 Tab 仍会在主线程冷读全表。
    @MainActor
    static func prewarmTabQueries(in context: ModelContext) async {
        await Task.yield()

        let destinationCount = fetchCount(in: context)
        await materialize(count: destinationCount, batchSize: 40) { offset, limit in
            var descriptor = FetchDescriptor<TravelDestination>(
                sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            _ = try? context.fetch(descriptor)
        }

        let tripCount = (try? context.fetchCount(FetchDescriptor<TravelTrip>())) ?? 0
        await materialize(count: tripCount, batchSize: 20) { offset, limit in
            var descriptor = FetchDescriptor<TravelTrip>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            descriptor.relationshipKeyPathsForPrefetching = [\.destinations]
            _ = try? context.fetch(descriptor)
        }

        print("📦 SwiftData 预热: \(destinationCount) 地点, \(tripCount) 旅程")
    }

    @MainActor
    private static func materialize(
        count: Int,
        batchSize: Int,
        fetch: (Int, Int) -> Void
    ) async {
        guard count > 0, batchSize > 0 else { return }
        var offset = 0
        while offset < count {
            let limit = min(batchSize, count - offset)
            fetch(offset, limit)
            offset += limit
            await Task.yield()
        }
    }
}
