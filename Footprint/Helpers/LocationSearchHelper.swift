//
//  LocationSearchHelper.swift
//  Footprint
//
//  Created by AI Assistant on 2025/01/XX.
//

import Foundation
import MapKit
import CoreLocation

/// 位置搜索辅助类：提供可复用的位置搜索功能，支持基于中心点的距离排序
class LocationSearchHelper {
    
    /// 搜索结果回调
    typealias SearchCompletion = (Result<[MKMapItem], Error>) -> Void
    
    /// 执行位置搜索，支持基于中心点的距离排序
    /// - Parameters:
    ///   - query: 搜索查询文本
    ///   - region: 可选的搜索区域限制（如果为nil，将使用系统默认区域）
    ///   - centerCoordinate: 可选的中心点坐标，用于距离排序（如果提供，结果将按距离中心点的远近排序）
    ///   - resultTypes: 搜索结果类型（iOS 13+）
    ///   - completion: 搜索完成回调，返回排序后的结果
    static func search(
        query: String,
        region: MKCoordinateRegion? = nil,
        centerCoordinate: CLLocationCoordinate2D? = nil,
        resultTypes: MKLocalSearch.ResultType = [.address, .pointOfInterest],
        completion: @escaping SearchCompletion
    ) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.success([]))
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // 设置搜索区域
        if let region = region {
            request.region = region
        }
        
        // 设置结果类型（iOS 13+）
        if #available(iOS 13.0, *) {
            request.resultTypes = resultTypes
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let mapItems = response?.mapItems else {
                completion(.success([]))
                return
            }
            
            // 如果提供了中心点坐标，按距离排序；否则保持原顺序
            let sortedItems: [MKMapItem]
            if let center = centerCoordinate {
                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                
                // 计算所有距离并排序
                sortedItems = mapItems.sorted { item1, item2 in
                    let coord1 = item1.placemark.coordinate
                    let coord2 = item2.placemark.coordinate
                    
                    let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
                    let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
                    
                    let distance1 = location1.distance(from: centerLocation)
                    let distance2 = location2.distance(from: centerLocation)
                    
                    return distance1 < distance2
                }
                
                // 调试：打印前5个结果的排序信息
                print("📍 排序完成，前5个结果的距离信息（从中心点 \(center.latitude), \(center.longitude)）：")
                for (index, item) in sortedItems.prefix(5).enumerated() {
                    let coord = item.placemark.coordinate
                    let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let distance = location.distance(from: centerLocation) / 1000.0 // 转换为公里
                    let name = item.name ?? item.placemark.locality ?? "未知"
                    print("   \(index + 1). \(name) - 距离: \(String(format: "%.1f", distance))公里 - 坐标: (\(coord.latitude), \(coord.longitude))")
                }
            } else {
                sortedItems = mapItems
            }
            
            completion(.success(sortedItems))
        }
    }
    
    /// 计算两个坐标之间的距离（单位：米）
    /// - Parameters:
    ///   - coordinate1: 第一个坐标
    ///   - coordinate2: 第二个坐标
    /// - Returns: 距离（米）
    static func distance(
        from coordinate1: CLLocationCoordinate2D,
        to coordinate2: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        return location1.distance(from: location2)
    }
    
    /// 对搜索结果按距离中心点排序
    /// - Parameters:
    ///   - items: 搜索结果数组
    ///   - centerCoordinate: 中心点坐标
    /// - Returns: 排序后的结果数组（距离越近越靠前）
    static func sortByDistance(
        items: [MKMapItem],
        from centerCoordinate: CLLocationCoordinate2D
    ) -> [MKMapItem] {
        return items.sorted { item1, item2 in
            let coord1 = item1.placemark.coordinate
            let coord2 = item2.placemark.coordinate
            
            let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
            let centerLocation = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
            
            let distance1 = location1.distance(from: centerLocation)
            let distance2 = location2.distance(from: centerLocation)
            
            return distance1 < distance2
        }
    }
}

