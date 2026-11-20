//
//  TripDataImporter.swift
//  Footprint
//
//  Created on 2025/10/20.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct TripDataImporter {
    
    /// 从URL导入旅程数据
    static func importTrip(from url: URL, modelContext: ModelContext) -> ImportResult {
        // 获取文件访问权限
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let jsonData = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(TripExportData.self, from: jsonData)
            return importTrip(from: exportData, modelContext: modelContext)
        } catch {
            print("导入旅程数据失败: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// 从Data导入旅程数据
    static func importTrip(from data: Data, modelContext: ModelContext) -> ImportResult {
        do {
            let exportData = try JSONDecoder().decode(TripExportData.self, from: data)
            return importTrip(from: exportData, modelContext: modelContext)
        } catch {
            print("导入旅程数据失败: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// 通过导出数据导入旅程
    static func importTrip(from exportData: TripExportData, modelContext: ModelContext) -> ImportResult {
        do {
            // 检查是否已存在相同名称的旅程
            let existingTrip = try modelContext.fetch(
                FetchDescriptor<TravelTrip>(
                    predicate: #Predicate { $0.name == exportData.trip.name }
                )
            ).first
            
            if let existingTrip = existingTrip {
                return .duplicate(existingTrip)
            }
            
            // 创建新旅程
            let newTrip = TravelTrip(
                name: exportData.trip.name,
                desc: exportData.trip.desc,
                startDate: exportData.trip.startDate,
                endDate: exportData.trip.endDate,
                coverPhotoData: exportData.trip.coverPhotoData
            )
            
            // 创建目的地，检查重复
            var destinations: [TravelDestination] = []
            for destInfo in exportData.destinations {
                // 检查是否已存在相同的目的地（名称、国家、坐标相同）
                let existingDestination = try modelContext.fetch(
                    FetchDescriptor<TravelDestination>(
                        predicate: #Predicate { destination in
                            destination.name == destInfo.name &&
                            destination.country == destInfo.country &&
                            destination.latitude >= destInfo.latitude - 0.001 &&
                            destination.latitude <= destInfo.latitude + 0.001 &&
                            destination.longitude >= destInfo.longitude - 0.001 &&
                            destination.longitude <= destInfo.longitude + 0.001
                        }
                    )
                ).first
                
                if let existingDestination = existingDestination {
                    // 如果目的地已存在，将其添加到新旅程中
                    existingDestination.trip = newTrip
                    destinations.append(existingDestination)
                } else {
                    // 创建新目的地
                    let destination = TravelDestination(
                        name: destInfo.name,
                        country: destInfo.country,
                        province: destInfo.province ?? "",
                        latitude: destInfo.latitude,
                        longitude: destInfo.longitude,
                        visitDate: destInfo.visitDate,
                        notes: destInfo.notes,
                        photoData: destInfo.photoData,
                        photoDatas: destInfo.photoDatas ?? [],
                        photoThumbnailData: destInfo.photoThumbnailData,
                        photoThumbnailDatas: destInfo.photoThumbnailDatas ?? [],
                        videoData: destInfo.videoData,
                        category: destInfo.category,
                        isFavorite: destInfo.isFavorite
                    )
                    destination.trip = newTrip
                    destinations.append(destination)
                }
            }
            
            // 设置关联关系
            newTrip.destinations = destinations
            
            // 应用路线段（交通方式 + 路线几何），避免导入后重新计算
            if let segments = exportData.routeSegments, !segments.isEmpty {
                let sortedDest = destinations.sorted { $0.visitDate < $1.visitDate }
                let routeManager = RouteManager.shared
                for i in 0..<(sortedDest.count - 1) {
                    guard i < segments.count else { break }
                    let seg = segments[i]
                    let from = sortedDest[i].coordinate
                    let to = sortedDest[i + 1].coordinate
                    let coords: [CLLocationCoordinate2D]? = seg.coordinates?.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    routeManager.importRoute(
                        from: from,
                        to: to,
                        transportTypeRawValue: seg.transportTypeRawValue,
                        distance: seg.distance ?? 0,
                        expectedTravelTime: seg.expectedTravelTime ?? 0,
                        coordinates: coords
                    )
                }
            }
            
            // 保存到数据库
            modelContext.insert(newTrip)
            for destination in destinations {
                // 只插入新创建的目的地，已存在的目的地不需要重复插入
                if destination.modelContext == nil {
                    modelContext.insert(destination)
                }
            }
            
            try modelContext.save()
            DestinationChangeNotifier.postUpdated()
            
            return .success(newTrip)
        } catch {
            print("导入旅程数据失败: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// 导入独立地点（没有关联到任何旅程的地点）
    static func importStandaloneDestination(from destInfo: TripExportData.DestinationInfo, modelContext: ModelContext) -> ImportDestinationResult {
        do {
            // 检查是否已存在相同的目的地（名称、国家、坐标相同）
            let existingDestination = try modelContext.fetch(
                FetchDescriptor<TravelDestination>(
                    predicate: #Predicate { destination in
                        destination.name == destInfo.name &&
                        destination.country == destInfo.country &&
                        destination.latitude >= destInfo.latitude - 0.001 &&
                        destination.latitude <= destInfo.latitude + 0.001 &&
                        destination.longitude >= destInfo.longitude - 0.001 &&
                        destination.longitude <= destInfo.longitude + 0.001
                    }
                )
            ).first
            
            if let existingDestination = existingDestination {
                // 如果目的地已存在，更新其数据（但保持其 trip 关联不变）
                existingDestination.province = destInfo.province ?? ""
                existingDestination.visitDate = destInfo.visitDate
                existingDestination.notes = destInfo.notes
                existingDestination.photoData = destInfo.photoData
                existingDestination.photoThumbnailData = destInfo.photoThumbnailData
                existingDestination.photoDatas = destInfo.photoDatas ?? []
                existingDestination.photoThumbnailDatas = destInfo.photoThumbnailDatas ?? []
                existingDestination.videoData = destInfo.videoData
                existingDestination.updateHasPhotosFlag()
                existingDestination.category = destInfo.category
                existingDestination.isFavorite = destInfo.isFavorite
                
                try modelContext.save()
                DestinationChangeNotifier.postUpdated()
                return .duplicate(existingDestination)
            } else {
                // 创建新独立地点
                let destination = TravelDestination(
                    name: destInfo.name,
                    country: destInfo.country,
                    province: destInfo.province ?? "",
                    latitude: destInfo.latitude,
                    longitude: destInfo.longitude,
                    visitDate: destInfo.visitDate,
                    notes: destInfo.notes,
                    photoData: destInfo.photoData,
                    photoDatas: destInfo.photoDatas ?? [],
                    photoThumbnailData: destInfo.photoThumbnailData,
                    photoThumbnailDatas: destInfo.photoThumbnailDatas ?? [],
                    videoData: destInfo.videoData,
                    category: destInfo.category,
                    isFavorite: destInfo.isFavorite
                )
                // 独立地点不关联任何旅程
                destination.trip = nil
                
                modelContext.insert(destination)
                try modelContext.save()
                DestinationChangeNotifier.postUpdated()
                
                return .success(destination)
            }
        } catch {
            print("导入独立地点失败: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
}

// MARK: - 导入目的地结果枚举
enum ImportDestinationResult {
    case success(TravelDestination)
    case duplicate(TravelDestination)
    case error(String)
}

// MARK: - 导入结果枚举
enum ImportResult {
    case success(TravelTrip)
    case duplicate(TravelTrip)
    case error(String)
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var isDuplicate: Bool {
        if case .duplicate = self {
            return true
        }
        return false
    }
    
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
    
    var trip: TravelTrip? {
        switch self {
        case .success(let trip), .duplicate(let trip):
            return trip
        case .error:
            return nil
        }
    }
    
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}
