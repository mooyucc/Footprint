//
//  TripDataExporter.swift
//  Footprint
//
//  Created on 2025/10/20.
//

import Foundation
import SwiftData
import MapKit

// MARK: - 旅程数据导出结构
struct TripExportData: Codable {
    let trip: TripInfo
    let destinations: [DestinationInfo]
    let exportDate: Date
    let appVersion: String
    /// 路线段信息（按目的地 visitDate 顺序，每段为 dest[i] -> dest[i+1]）；无或空表示不包含路线数据
    let routeSegments: [RouteSegmentInfo]?
    
    struct TripInfo: Codable {
        let name: String
        let desc: String
        let startDate: Date
        let endDate: Date
        let coverPhotoData: Data?
    }
    
    struct DestinationInfo: Codable {
        let name: String
        let country: String
        let province: String?
        let latitude: Double
        let longitude: Double
        let visitDate: Date
        let notes: String
        let photoData: Data?
        let photoThumbnailData: Data?
        let photoDatas: [Data]?
        let photoThumbnailDatas: [Data]?
        let videoData: Data?
        let category: String
        let isFavorite: Bool
        
        init(
            name: String,
            country: String,
            province: String?,
            latitude: Double,
            longitude: Double,
            visitDate: Date,
            notes: String,
            photoData: Data?,
            photoThumbnailData: Data?,
            photoDatas: [Data]?,
            photoThumbnailDatas: [Data]?,
            videoData: Data?,
            category: String,
            isFavorite: Bool
        ) {
            self.name = name
            self.country = country
            self.province = province
            self.latitude = latitude
            self.longitude = longitude
            self.visitDate = visitDate
            self.notes = notes
            self.photoData = photoData
            self.photoThumbnailData = photoThumbnailData
            self.photoDatas = photoDatas
            self.photoThumbnailDatas = photoThumbnailDatas
            self.videoData = videoData
            self.category = category
            self.isFavorite = isFavorite
        }
    }
    
    /// 路线段：两点之间的交通方式与可选路线几何，用于导入后免重新计算
    struct RouteSegmentInfo: Codable {
        let startLatitude: Double
        let startLongitude: Double
        let endLatitude: Double
        let endLongitude: Double
        /// 交通方式 rawValue；0 表示导入时使用自动选择
        let transportTypeRawValue: UInt
        let distance: Double?
        let expectedTravelTime: Double?
        let coordinates: [RouteSegmentCoordinate]?
        
        struct RouteSegmentCoordinate: Codable {
            let latitude: Double
            let longitude: Double
        }
    }
}

struct TripDataExporter {
    
    /// 构建旅程导出数据
    static func exportPayload(for trip: TravelTrip) -> TripExportData {
        let tripInfo = TripExportData.TripInfo(
            name: trip.name,
            desc: trip.desc,
            startDate: trip.startDate,
            endDate: trip.endDate,
            coverPhotoData: trip.coverPhotoData
        )
        
        let destinations = trip.destinations?.map { destination in
            TripExportData.DestinationInfo(
                name: destination.name,
                country: destination.country,
                province: destination.province.isEmpty ? nil : destination.province,
                latitude: destination.latitude,
                longitude: destination.longitude,
                visitDate: destination.visitDate,
                notes: destination.notes,
                photoData: destination.photoData,
                photoThumbnailData: destination.photoThumbnailData,
                photoDatas: destination.photoDatas.isEmpty ? nil : destination.photoDatas,
                photoThumbnailDatas: destination.photoThumbnailDatas.isEmpty ? nil : destination.photoThumbnailDatas,
                videoData: destination.videoData,
                category: destination.category,
                isFavorite: destination.isFavorite
            )
        } ?? []
        
        let routeSegments = buildRouteSegments(for: trip)
        
        return TripExportData(
            trip: tripInfo,
            destinations: destinations,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            routeSegments: routeSegments
        )
    }
    
    /// 按 visitDate 顺序构建路线段（交通方式 + 可选路线几何），供导入后免重新计算
    private static func buildRouteSegments(for trip: TravelTrip) -> [TripExportData.RouteSegmentInfo]? {
        guard let list = trip.destinations, list.count >= 2 else { return nil }
        let sortedDest = list.sorted { $0.visitDate < $1.visitDate }
        let routeManager = RouteManager.shared
        var segments: [TripExportData.RouteSegmentInfo] = []
        for i in 0..<(sortedDest.count - 1) {
            let from = sortedDest[i].coordinate
            let to = sortedDest[i + 1].coordinate
            let transportType = routeManager.getUserTransportType(from: from, to: to)
            let transportRaw = transportType?.rawValue ?? 0
            var distance: Double?
            var expectedTravelTime: Double?
            var coordinates: [TripExportData.RouteSegmentInfo.RouteSegmentCoordinate]?
            if let route = routeManager.getCachedRoute(from: from, to: to, transportType: transportType) {
                distance = route.footprintDistance
                expectedTravelTime = route.footprintExpectedTravelTime
                let count = route.polyline.pointCount
                if count >= 2 {
                    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
                    route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
                    coordinates = coords.map { TripExportData.RouteSegmentInfo.RouteSegmentCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
                }
            }
            segments.append(TripExportData.RouteSegmentInfo(
                startLatitude: from.latitude,
                startLongitude: from.longitude,
                endLatitude: to.latitude,
                endLongitude: to.longitude,
                transportTypeRawValue: transportRaw,
                distance: distance,
                expectedTravelTime: expectedTravelTime,
                coordinates: coordinates
            ))
        }
        return segments.isEmpty ? nil : segments
    }
    
    /// 导出独立地点（没有关联到任何旅程的地点）
    static func exportStandaloneDestination(_ destination: TravelDestination) -> TripExportData.DestinationInfo {
        TripExportData.DestinationInfo(
            name: destination.name,
            country: destination.country,
            province: destination.province.isEmpty ? nil : destination.province,
            latitude: destination.latitude,
            longitude: destination.longitude,
            visitDate: destination.visitDate,
            notes: destination.notes,
            photoData: destination.photoData,
            photoThumbnailData: destination.photoThumbnailData,
            photoDatas: destination.photoDatas.isEmpty ? nil : destination.photoDatas,
            photoThumbnailDatas: destination.photoThumbnailDatas.isEmpty ? nil : destination.photoThumbnailDatas,
            videoData: destination.videoData,
            category: destination.category,
            isFavorite: destination.isFavorite
        )
    }
    
    /// 导出旅程数据为JSON格式
    static func exportTrip(_ trip: TravelTrip) -> URL? {
        let exportData = exportPayload(for: trip)
        
        // 序列化为JSON
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            
            // 创建临时文件
            let fileName = "\(trip.name)_MooFootprint.json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: tempURL)
            
            return tempURL
        } catch {
            print("导出旅程数据失败: \(error)")
            return nil
        }
    }
    
    /// 生成分享文本描述
    static func generateShareText(for trip: TravelTrip) -> String {
        let destinationCount = trip.destinations?.count ?? 0
        return """
        🗺️ 旅程分享：\(trip.name)
        
        📅 行程时间：\(trip.startDate.localizedFormatted(dateStyle: .short)) - \(trip.endDate.localizedFormatted(dateStyle: .short))
        📍 目的地数量：\(destinationCount) 个地点
        
        使用墨鱼足迹应用导入此旅程，即可获得完整的行程安排！
        """
    }
}
