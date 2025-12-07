//
//  AppleGeocodeService.swift
//  Footprint
//
//  Created on 2025/12/05.
//  Apple MapKit地理编码服务实现（封装现有逻辑）
//

import Foundation
import CoreLocation
import MapKit

/// Apple MapKit地理编码服务实现
class AppleGeocodeService: GeocodeServiceProtocol {
    static let shared = AppleGeocodeService()
    
    private let geocoder = CLGeocoder()
    private var activeSearch: MKLocalSearch?
    private let requestQueue = DispatchQueue(label: "com.footprint.apple.geocode")
    
    private init() {
        print("📍 [Apple Maps] 地理编码服务已初始化")
    }
    
    // MARK: - GeocodeServiceProtocol Implementation
    
    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<GeocodeResult, Error>) -> Void
    ) {
        print("📍 [Apple Maps] 反向地理编码请求: (\(coordinate.latitude), \(coordinate.longitude))")
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        requestQueue.async {
            self.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    print("❌ [Apple Maps] 反向地理编码失败: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("⚠️ [Apple Maps] 反向地理编码返回空结果")
                    DispatchQueue.main.async {
                        completion(.failure(GeocodeError.noData))
                    }
                    return
                }
                
                let result = self.convertPlacemarkToResult(placemark: placemark, coordinate: coordinate)
                print("✅ [Apple Maps] 反向地理编码成功: \(result.buildLocationName())")
                if let poi = result.poi {
                    print("   POI: \(poi.name)")
                }
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            }
        }
    }
    
    func searchNearbyPOIs(
        coordinate: CLLocationCoordinate2D,
        radius: Int,
        completion: @escaping (Result<NearbyPOIResult, Error>) -> Void
    ) {
        print("📍 [Apple Maps] 周边POI搜索请求: (\(coordinate.latitude), \(coordinate.longitude)), 半径: \(radius)米")
        
        let request = MKLocalSearch.Request()
        
        // 计算搜索区域的跨度
        // 1度约等于111公里
        let spanDegree = Double(radius) / 111000.0 * 2
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: spanDegree,
                longitudeDelta: spanDegree
            )
        )
        request.region = region
        
        // 设置结果类型
        if #available(iOS 13.0, *) {
            request.resultTypes = [.pointOfInterest]
        }
        
        let search = MKLocalSearch(request: request)
        activeSearch = search
        
        search.start { [weak self] response, error in
            guard let self = self else { return }
            
            self.requestQueue.async {
                self.activeSearch = nil
            }
            
            if let error = error {
                print("❌ [Apple Maps] 周边POI搜索失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let response = response else {
                DispatchQueue.main.async {
                    completion(.failure(GeocodeError.invalidResponse))
                }
                return
            }
            
            let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            let poiInfos = response.mapItems.compactMap { item -> GeocodeResult.POIInfo? in
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = itemLocation.distance(from: centerLocation)
                
                // 只返回在搜索半径内的POI
                guard distance <= Double(radius) else {
                    return nil
                }
                
                return GeocodeResult.POIInfo(
                    name: item.name ?? "未知地点",
                    category: item.pointOfInterestCategory?.rawValue,
                    distance: distance,
                    address: self.buildAddressString(from: item.placemark),
                    coordinate: item.placemark.coordinate
                )
            }.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
            
            print("✅ [Apple Maps] 找到 \(poiInfos.count) 个周边POI")
            
            let result = NearbyPOIResult(
                pois: poiInfos,
                center: coordinate,
                radius: radius
            )
            
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }
    
    func cancelAllRequests() {
        requestQueue.async {
            print("⚠️ [Apple Maps] 取消所有进行中的请求")
            self.geocoder.cancelGeocode()
            self.activeSearch?.cancel()
            self.activeSearch = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func convertPlacemarkToResult(placemark: CLPlacemark, coordinate: CLLocationCoordinate2D) -> GeocodeResult {
        let addressInfo = GeocodeResult.AddressInfo(
            country: placemark.country,
            province: placemark.administrativeArea,
            city: placemark.locality ?? placemark.administrativeArea,
            district: placemark.subAdministrativeArea,
            street: placemark.thoroughfare,
            streetNumber: placemark.subThoroughfare,
            formattedAddress: buildFormattedAddress(from: placemark)
        )
        
        let poiInfo: GeocodeResult.POIInfo? = {
            if let poiName = placemark.areasOfInterest?.first {
                return GeocodeResult.POIInfo(
                    name: poiName,
                    category: nil,
                    distance: nil,
                    address: placemark.thoroughfare,
                    coordinate: coordinate
                )
            }
            return nil
        }()
        
        return GeocodeResult(
            coordinate: coordinate,
            address: addressInfo,
            poi: poiInfo,
            source: .apple
        )
    }
    
    private func buildFormattedAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let streetNumber = placemark.subThoroughfare {
            components.append(streetNumber)
        }
        if let city = placemark.locality ?? placemark.administrativeArea {
            components.append(city)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.joined(separator: " ")
    }
    
    private func buildAddressString(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let streetNumber = placemark.subThoroughfare {
            components.append(streetNumber)
        }
        if let city = placemark.locality ?? placemark.administrativeArea {
            components.append(city)
        }
        
        return components.joined(separator: " ")
    }
}

