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
import Contacts

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
        // 构建地址字典，用于创建包含完整地址信息的MKPlacemark
        var addressDictionary: [String: Any] = [:]
        
        // 填充地址信息
        // 先检查省份，判断是否是中国的特别行政区
        var finalCountry = address.country
        var finalCountryCode: String?
        
        if let province = address.province, !province.isEmpty {
            // 检查是否是中国的特别行政区或省份
            let normalizedProvince = province.lowercased()
            if normalizedProvince.contains("香港") || normalizedProvince.contains("hong kong") {
                finalCountry = "中国"
                finalCountryCode = "CN"
            } else if normalizedProvince.contains("澳门") || normalizedProvince.contains("macau") || normalizedProvince.contains("macao") {
                finalCountry = "中国"
                finalCountryCode = "CN"
            } else if normalizedProvince.contains("台湾") || normalizedProvince.contains("taiwan") {
                finalCountry = "中国"
                finalCountryCode = "CN"
            }
            
            // 使用CNPostalAddress键名
            addressDictionary[CNPostalAddressStateKey] = province
        }
        
        // 设置国家信息
        if let country = finalCountry, !country.isEmpty {
            var countryToUse = country
            var countryCodeToUse: String?
            
            if let code = finalCountryCode {
                countryCodeToUse = code
            } else if country == "中国" || country == "China" {
                countryCodeToUse = "CN"
            } else if country.contains("香港") || country == "Hong Kong" {
                countryCodeToUse = "CN"
                countryToUse = "中国"
            } else if country.contains("澳门") || country == "Macau" || country == "Macao" {
                countryCodeToUse = "CN"
                countryToUse = "中国"
            } else if country.contains("台湾") || country == "Taiwan" {
                countryCodeToUse = "CN"
                countryToUse = "中国"
            }
            
            addressDictionary[CNPostalAddressCountryKey] = countryToUse
            if let code = countryCodeToUse {
                addressDictionary["CountryCode"] = code
            }
        }
        
        if let city = address.city, !city.isEmpty {
            addressDictionary[CNPostalAddressCityKey] = city
        }
        
        if let district = address.district, !district.isEmpty {
            addressDictionary[CNPostalAddressSubAdministrativeAreaKey] = district
        }
        
        if let street = address.street, !street.isEmpty {
            addressDictionary[CNPostalAddressStreetKey] = street
        }
        
        if let streetNumber = address.streetNumber, !streetNumber.isEmpty {
            addressDictionary[CNPostalAddressSubLocalityKey] = streetNumber
        }
        
        // 创建包含地址信息的MKPlacemark
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDictionary.isEmpty ? nil : addressDictionary)
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

