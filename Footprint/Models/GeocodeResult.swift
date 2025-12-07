//
//  GeocodeResult.swift
//  Footprint
//
//  Created on 2025/12/05.
//  统一的地理编码结果模型，用于封装高德和Apple的返回结果
//

import Foundation
import CoreLocation
import MapKit

/// 统一的地理编码结果模型
struct GeocodeResult {
    let coordinate: CLLocationCoordinate2D
    let address: AddressInfo
    let poi: POIInfo?
    let source: GeocodeSource
    
    enum GeocodeSource {
        case amap      // 高德地图
        case apple     // Apple MapKit
        
        var displayName: String {
            switch self {
            case .amap:
                return "高德地图"
            case .apple:
                return "Apple Maps"
            }
        }
    }
    
    /// 地址信息
    struct AddressInfo {
        let country: String?
        let province: String?
        let city: String?
        let district: String?
        let street: String?
        let streetNumber: String?
        let formattedAddress: String
        
        /// 构建完整地址字符串
        func buildFullAddress() -> String {
            var components: [String] = []
            
            if let street = street, !street.isEmpty {
                components.append(street)
            }
            if let streetNumber = streetNumber, !streetNumber.isEmpty {
                components.append(streetNumber)
            }
            if let district = district, !district.isEmpty {
                components.append(district)
            }
            if let city = city, !city.isEmpty {
                components.append(city)
            }
            if let province = province, !province.isEmpty {
                components.append(province)
            }
            if let country = country, !country.isEmpty {
                components.append(country)
            }
            
            if components.isEmpty {
                return formattedAddress.isEmpty ? "未知位置" : formattedAddress
            }
            
            return components.joined(separator: " ")
        }
    }
    
    /// POI信息
    struct POIInfo {
        let name: String
        let category: String?
        let distance: Double?  // 距离搜索点的距离（米）
        let address: String?
        let coordinate: CLLocationCoordinate2D?
        
        init(name: String, category: String? = nil, distance: Double? = nil, address: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
            self.name = name
            self.category = category
            self.distance = distance
            self.address = address
            self.coordinate = coordinate
        }
        
        /// 格式化距离显示
        var formattedDistance: String {
            guard let distance = distance else { return "" }
            
            if distance < 1000 {
                return String(format: "%.0f米", distance)
            } else {
                return String(format: "%.1f公里", distance / 1000.0)
            }
        }
    }
    
    /// 转换为MKMapItem（用于显示和后续处理）
    func toMapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        // 设置名称：优先使用POI名称，否则使用地址
        if let poi = poi {
            mapItem.name = poi.name
        } else {
            mapItem.name = address.buildFullAddress()
        }
        
        return mapItem
    }
    
    /// 构建地点名称（用于显示）
    func buildLocationName() -> String {
        if let poi = poi {
            return poi.name
        }
        return address.buildFullAddress()
    }
}

/// 周边POI搜索结果
struct NearbyPOIResult {
    let pois: [GeocodeResult.POIInfo]
    let center: CLLocationCoordinate2D
    let radius: Int  // 搜索半径（米）
    
    /// 按距离排序的POI列表
    var sortedByDistance: [GeocodeResult.POIInfo] {
        pois.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
    }
    
    /// 最近的POI
    var nearestPOI: GeocodeResult.POIInfo? {
        sortedByDistance.first
    }
}

