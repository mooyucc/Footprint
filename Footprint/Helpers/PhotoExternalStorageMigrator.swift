//
//  PhotoExternalStorageMigrator.swift
//  Footprint
//
//  一次性：把已内联的多图 / 视频 / 旅程封面按 externalStorage 规则重写出去。
//  仅加 @Attribute(.externalStorage) 不会自动搬迁旧数据。
//

import Foundation
import SwiftData

@MainActor
enum PhotoExternalStorageMigrator {
    /// v2：在 v1（多图+封面）基础上纳入地点 videoData
    private static let completionKey = "photoExternalStorageMigration.v2.completed"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completionKey)
    }

    /// Splash / 预热完成后调用；不阻塞启动画面。失败不打标，下次冷启动可续跑。
    static func migrateIfNeeded(in context: ModelContext) async {
        guard !isCompleted else { return }

        print("📦 开始媒体外部存储迁移…")
        let destinationBatch = 12
        let tripBatch = 20
        var rewrittenDestinations = 0
        var rewrittenTrips = 0

        do {
            let destinationCount = try context.fetchCount(FetchDescriptor<TravelDestination>())
            var offset = 0
            while offset < destinationCount {
                var descriptor = FetchDescriptor<TravelDestination>(
                    sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
                )
                descriptor.fetchOffset = offset
                descriptor.fetchLimit = min(destinationBatch, destinationCount - offset)
                let batch = try context.fetch(descriptor)
                for destination in batch {
                    if rewriteDestinationMedia(destination) {
                        rewrittenDestinations += 1
                    }
                }
                if context.hasChanges {
                    try context.save()
                }
                offset += batch.count
                await Task.yield()
            }

            let tripCount = try context.fetchCount(FetchDescriptor<TravelTrip>())
            offset = 0
            while offset < tripCount {
                var descriptor = FetchDescriptor<TravelTrip>(
                    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                )
                descriptor.fetchOffset = offset
                descriptor.fetchLimit = min(tripBatch, tripCount - offset)
                let batch = try context.fetch(descriptor)
                for trip in batch {
                    if rewriteTripCover(trip) {
                        rewrittenTrips += 1
                    }
                }
                if context.hasChanges {
                    try context.save()
                }
                offset += batch.count
                await Task.yield()
            }

            UserDefaults.standard.set(true, forKey: completionKey)
            print("📦 媒体外部存储迁移完成：地点 \(rewrittenDestinations) 条，旅程封面 \(rewrittenTrips) 条")
        } catch {
            print("⚠️ 媒体外部存储迁移失败，将在下次启动重试: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private static func rewriteDestinationMedia(_ destination: TravelDestination) -> Bool {
        var didRewrite = false

        let photos = destination.photoDatas
        let thumbs = destination.photoThumbnailDatas
        if !photos.isEmpty || !thumbs.isEmpty {
            destination.photoDatas = []
            destination.photoThumbnailDatas = []
            destination.photoDatas = photos.map { Data($0) }
            destination.photoThumbnailDatas = thumbs.map { Data($0) }
            didRewrite = true
        }

        if let video = destination.videoData, !video.isEmpty {
            destination.videoData = nil
            destination.videoData = Data(video)
            didRewrite = true
        }

        return didRewrite
    }

    @discardableResult
    private static func rewriteTripCover(_ trip: TravelTrip) -> Bool {
        guard let cover = trip.coverPhotoData, !cover.isEmpty else { return false }
        trip.coverPhotoData = nil
        trip.coverPhotoData = Data(cover)
        return true
    }
}
