//
//  TripDataExporter.swift
//  Footprint
//
//  Created on 2025/10/20.
//

import Foundation
import SwiftData

// MARK: - 旅程数据导出结构
struct TripExportData: Codable {
    let trip: TripInfo
    let destinations: [DestinationInfo]
    let exportDate: Date
    let appVersion: String
    
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
        
        return TripExportData(
            trip: tripInfo,
            destinations: destinations,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        )
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
