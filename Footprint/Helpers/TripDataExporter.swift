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
        let latitude: Double
        let longitude: Double
        let visitDate: Date
        let notes: String
        let photoData: Data?
        let photoThumbnailData: Data?
        let photoThumbnailDatas: [Data]?
        let category: String
        let isFavorite: Bool
    }
}

struct TripDataExporter {
    
    /// 导出旅程数据为JSON格式
    static func exportTrip(_ trip: TravelTrip) -> URL? {
        // 准备导出数据
        let tripInfo = TripExportData.TripInfo(
            name: trip.name,
            desc: trip.desc,
            startDate: trip.startDate,
            endDate: trip.endDate,
            coverPhotoData: trip.coverPhotoData
        )
        
        // 转换目的地数据
        let destinations = trip.destinations?.map { destination in
            TripExportData.DestinationInfo(
                name: destination.name,
                country: destination.country,
                latitude: destination.latitude,
                longitude: destination.longitude,
                visitDate: destination.visitDate,
                notes: destination.notes,
                photoData: destination.photoData,
                photoThumbnailData: destination.photoThumbnailData,
                photoThumbnailDatas: destination.photoThumbnailDatas.isEmpty ? nil : destination.photoThumbnailDatas,
                category: destination.category,
                isFavorite: destination.isFavorite
            )
        } ?? []
        
        // 创建导出数据
        let exportData = TripExportData(
            trip: tripInfo,
            destinations: destinations,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        )
        
        // 序列化为JSON
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            
            // 创建临时文件
            let fileName = "\(trip.name)_MooyuFootprint.json"
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
