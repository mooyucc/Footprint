//
//  DestinationThumbnailCache.swift
//  Footprint
//
//  Decode and cache destination thumbnails off the main thread for map markers.
//

import UIKit

/// Shared thumbnail cache so map annotations and list cards do not decode full-size `photoData` on the main thread.
final class DestinationThumbnailCache {
    static let shared = DestinationThumbnailCache()
    
    private enum Variant: String {
        case marker
        case listCard
        /// 旅程卡片 Tab 景深背景（屏宽级 downsample）
        case journeyDepthCover
        /// 时光 Tab 大卡封面（优先原图，约 1080）
        case timeCapsuleCover
    }
    
    private let cache = NSCache<NSString, UIImage>()
    private let decodeQueue = DispatchQueue(
        label: "com.footprint.thumbnailDecode",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    private init() {
        cache.countLimit = 384
        cache.totalCostLimit = 32 * 1024 * 1024
    }
    
    func cachedImage(for id: UUID) -> UIImage? {
        cache.object(forKey: cacheKey(for: id, variant: .marker))
    }
    
    func cachedListCardImage(for id: UUID) -> UIImage? {
        cache.object(forKey: cacheKey(for: id, variant: .listCard))
    }

    func cachedTimeCapsuleCoverImage(for id: UUID) -> UIImage? {
        cache.object(forKey: cacheKey(for: id, variant: .timeCapsuleCover))
    }
    
    func image(for id: UUID, thumbnailData: Data?, fallbackData: Data?) async -> UIImage? {
        await decodeImage(
            for: id,
            variant: .marker,
            thumbnailData: thumbnailData,
            fallbackData: fallbackData,
            maxDimension: 96
        )
    }
    
    func imageForListCard(for id: UUID, thumbnailData: Data?, fallbackData: Data?) async -> UIImage? {
        await decodeImage(
            for: id.uuidString,
            variant: .listCard,
            thumbnailData: thumbnailData,
            fallbackData: fallbackData,
            maxDimension: 400
        )
    }

    /// 旅程卡片景深背景：行程封面，约屏宽 ×2 以内。
    func imageForJourneyDepthCover(for tripId: UUID, coverData: Data?) async -> UIImage? {
        await decodeImage(
            for: tripId,
            variant: .journeyDepthCover,
            thumbnailData: coverData,
            fallbackData: nil,
            maxDimension: 1080,
            compressionQuality: 0.82
        )
    }

    /// 时光轮播大卡：优先主图，缩略图兜底；最长边约 1080。
    func imageForTimeCapsuleCover(
        for id: UUID,
        fullData: Data?,
        thumbnailData: Data?
    ) async -> UIImage? {
        await decodeImage(
            for: id.uuidString,
            variant: .timeCapsuleCover,
            thumbnailData: fullData,
            fallbackData: thumbnailData,
            maxDimension: 1080,
            compressionQuality: 0.85
        )
    }
    
    private func cacheKey(for id: UUID, variant: Variant) -> NSString {
        cacheKey(for: id.uuidString, variant: variant)
    }

    private func cacheKey(for id: String, variant: Variant) -> NSString {
        "\(id)-\(variant.rawValue)" as NSString
    }
    
    private func decodeImage(
        for id: UUID,
        variant: Variant,
        thumbnailData: Data?,
        fallbackData: Data?,
        maxDimension: CGFloat,
        compressionQuality: CGFloat = 0.72
    ) async -> UIImage? {
        await decodeImage(
            for: id.uuidString,
            variant: variant,
            thumbnailData: thumbnailData,
            fallbackData: fallbackData,
            maxDimension: maxDimension,
            compressionQuality: compressionQuality
        )
    }

    private func decodeImage(
        for id: String,
        variant: Variant,
        thumbnailData: Data?,
        fallbackData: Data?,
        maxDimension: CGFloat,
        compressionQuality: CGFloat = 0.72
    ) async -> UIImage? {
        let key = cacheKey(for: id, variant: variant)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        let data = thumbnailData ?? fallbackData
        guard let data, !data.isEmpty else { return nil }
        
        return await withCheckedContinuation { continuation in
            decodeQueue.async {
                let image = Self.decode(
                    data: data,
                    maxDimension: maxDimension,
                    compressionQuality: compressionQuality
                )
                if let image {
                    let cost = Int(image.size.width * image.size.height * 4)
                    self.cache.setObject(image, forKey: key, cost: max(cost, data.count))
                }
                continuation.resume(returning: image)
            }
        }
    }
    
    private static func decode(
        data: Data,
        maxDimension: CGFloat,
        compressionQuality: CGFloat
    ) -> UIImage? {
        if data.count > 64_000,
           let downsampled = ImageProcessor.downsample(
            data: data,
            maxDimension: maxDimension,
            compressionQuality: compressionQuality
           ) {
            return UIImage(data: downsampled)
        }
        return UIImage(data: data)
    }
}
