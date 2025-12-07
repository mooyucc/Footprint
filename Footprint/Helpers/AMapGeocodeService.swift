//
//  AMapGeocodeService.swift
//  Footprint
//
//  Created on 2025/12/05.
//  高德地图地理编码服务实现
//

import Foundation
import CoreLocation

/// 高德地图地理编码服务实现
class AMapGeocodeService: GeocodeServiceProtocol {
    static let shared = AMapGeocodeService()
    
    private let apiKey: String
    private let baseURL = "https://restapi.amap.com/v3"
    private var activeRequests: [URLSessionDataTask] = []
    private let requestQueue = DispatchQueue(label: "com.footprint.amap.request")
    
    // 请求超时时间（秒）- 增加到10秒以应对网络延迟
    private let requestTimeout: TimeInterval = 10.0
    
    private init() {
        // 从配置文件或环境变量读取API Key
        // 优先级：环境变量 > Info.plist
        if let key = ProcessInfo.processInfo.environment["AMapAPIKey"],
           !key.isEmpty {
            self.apiKey = key
            print("✅ [高德API] 从环境变量读取API Key")
        } else if let key = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String,
                  !key.isEmpty {
            self.apiKey = key
            print("✅ [高德API] 从Info.plist读取API Key")
        } else {
            fatalError("❌ [高德API] API Key未配置，请在Info.plist中添加AMapAPIKey或设置环境变量")
        }
        
        print("📍 [高德API] 服务已初始化，API Key: \(String(apiKey.prefix(8)))...")
    }
    
    // MARK: - GeocodeServiceProtocol Implementation
    
    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<GeocodeResult, Error>) -> Void
    ) {
        print("📍 [高德API] 反向地理编码请求: (\(coordinate.latitude), \(coordinate.longitude))")
        
        // 直接使用原始坐标，不进行转换
        // 注意：高德API使用GCJ02坐标系统，直接使用WGS84坐标可能会有50-300米偏差
        let urlString = "\(baseURL)/geocode/regeo"
        var components = URLComponents(string: urlString)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "location", value: "\(coordinate.longitude),\(coordinate.latitude)"),
            URLQueryItem(name: "radius", value: "1000"),  // 搜索半径1000米
            URLQueryItem(name: "extensions", value: "all"),  // 返回所有信息
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "roadlevel", value: "0"),  // 返回所有道路级别
            URLQueryItem(name: "homeorcorp", value: "0")  // 返回家庭或公司信息
        ]
        
        guard let url = components.url else {
            let error = AMapError.invalidURL
            print("❌ [高德API] 无效的URL")
            completion(.failure(error))
            return
        }
        
        // 创建请求配置
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.httpMethod = "GET"
        
        var task: URLSessionDataTask!
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 请求完成后从活跃列表中移除
            self.requestQueue.async {
                if let taskIndex = self.activeRequests.firstIndex(where: { $0 === task }) {
                    self.activeRequests.remove(at: taskIndex)
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                if nsError.code == NSURLErrorCancelled {
                    print("⚠️ [高德API] 请求已取消")
                    DispatchQueue.main.async {
                        completion(.failure(GeocodeError.cancelled))
                    }
                    return
                }
                
                print("❌ [高德API] 网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(GeocodeError.networkError(error.localizedDescription)))
                }
                return
            }
            
            guard let data = data else {
                print("❌ [高德API] 未接收到数据")
                DispatchQueue.main.async {
                    completion(.failure(GeocodeError.noData))
                }
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ [高德API] HTTP错误: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(.failure(AMapError.apiError("HTTP状态码: \(httpResponse.statusCode)")))
                    }
                    return
                }
            }
            
            do {
                let result = try self.parseReGeocodeResponse(data: data, originalCoordinate: coordinate)
                print("✅ [高德API] 反向地理编码成功: \(result.buildLocationName())")
                if let poi = result.poi {
                    print("   POI: \(poi.name)\(poi.formattedDistance.isEmpty ? "" : " (\(poi.formattedDistance))")")
                }
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                print("❌ [高德API] 解析响应失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        // 添加到活跃请求列表
        requestQueue.async {
            self.activeRequests.append(task)
        }
        
        task.resume()
    }
    
    func searchNearbyPOIs(
        coordinate: CLLocationCoordinate2D,
        radius: Int,
        completion: @escaping (Result<NearbyPOIResult, Error>) -> Void
    ) {
        print("📍 [高德API] 周边POI搜索请求: (\(coordinate.latitude), \(coordinate.longitude)), 半径: \(radius)米")
        
        // 直接使用原始坐标，不进行转换
        // 注意：高德API使用GCJ02坐标系统，直接使用WGS84坐标可能会有50-300米偏差
        let urlString = "\(baseURL)/place/around"
        var components = URLComponents(string: urlString)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "location", value: "\(coordinate.longitude),\(coordinate.latitude)"),
            URLQueryItem(name: "radius", value: "\(min(radius, 50000))"),  // 最大50000米
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "offset", value: "20"),  // 每页20条
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "extensions", value: "all")
        ]
        
        guard let url = components.url else {
            completion(.failure(AMapError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.httpMethod = "GET"
        
        var task: URLSessionDataTask!
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 请求完成后从活跃列表中移除
            self.requestQueue.async {
                if let taskIndex = self.activeRequests.firstIndex(where: { $0 === task }) {
                    self.activeRequests.remove(at: taskIndex)
                }
            }
            
            if let error = error {
                print("❌ [高德API] 周边POI搜索网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(GeocodeError.networkError(error.localizedDescription)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(GeocodeError.noData))
                }
                return
            }
            
            do {
                let result = try self.parseNearbyPOIResponse(data: data, center: coordinate, radius: radius)
                print("✅ [高德API] 找到 \(result.pois.count) 个周边POI")
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                print("❌ [高德API] 解析周边POI响应失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        requestQueue.async {
            self.activeRequests.append(task)
        }
        
        task.resume()
    }
    
    func cancelAllRequests() {
        requestQueue.async {
            print("⚠️ [高德API] 取消所有进行中的请求（共\(self.activeRequests.count)个）")
            self.activeRequests.forEach { $0.cancel() }
            self.activeRequests.removeAll()
        }
    }
    
    // MARK: - Private Methods - Response Parsing
    
    private func parseReGeocodeResponse(data: Data, originalCoordinate: CLLocationCoordinate2D) throws -> GeocodeResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AMapError.invalidResponse
        }
        
        // 检查API返回状态
        guard let status = json["status"] as? String,
              status == "1" else {
            let info = json["info"] as? String ?? "未知错误"
            let infocode = json["infocode"] as? String ?? ""
            print("❌ [高德API] API返回错误: \(info) (code: \(infocode))")
            throw AMapError.apiError(info)
        }
        
        guard let regeocode = json["regeocode"] as? [String: Any] else {
            throw AMapError.invalidResponse
        }
        
        let addressComponent = regeocode["addressComponent"] as? [String: Any]
        let formattedAddress = regeocode["formatted_address"] as? String ?? ""
        let pois = regeocode["pois"] as? [[String: Any]]
        
        // 解析地址信息
        let addressInfo = parseAddressComponent(addressComponent, formattedAddress: formattedAddress)
        
        // 解析POI信息（取最近的POI）
        let poiInfo = parsePOIInfo(from: pois, center: originalCoordinate)
        
        return GeocodeResult(
            coordinate: originalCoordinate,
            address: addressInfo,
            poi: poiInfo,
            source: .amap
        )
    }
    
    private func parseNearbyPOIResponse(data: Data, center: CLLocationCoordinate2D, radius: Int) throws -> NearbyPOIResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AMapError.invalidResponse
        }
        
        guard let status = json["status"] as? String,
              status == "1" else {
            let info = json["info"] as? String ?? "未知错误"
            throw AMapError.apiError(info)
        }
        
        guard let pois = json["pois"] as? [[String: Any]] else {
            // 没有找到POI，返回空结果
            return NearbyPOIResult(pois: [], center: center, radius: radius)
        }
        
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        
        let poiInfos = pois.compactMap { poiDict -> GeocodeResult.POIInfo? in
            guard let name = poiDict["name"] as? String,
                  let locationStr = poiDict["location"] as? String else {
                return nil
            }
            
            // 解析坐标字符串 "longitude,latitude"
            let parts = locationStr.split(separator: ",")
            guard parts.count == 2,
                  let lon = Double(String(parts[0])),
                  let lat = Double(String(parts[1])) else {
                return nil
            }
            
            // 直接使用高德返回的坐标，不进行转换
            // 注意：高德返回的是GCJ02坐标，直接使用可能会有偏差
            let poiCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            // 计算距离（使用原始坐标）
            let poiLocation = CLLocation(latitude: poiCoord.latitude, longitude: poiCoord.longitude)
            let distance = poiLocation.distance(from: centerLocation)
            
            // 提取POI类型
            let type = poiDict["type"] as? String
            let category = extractPOICategory(from: type)
            
                return GeocodeResult.POIInfo(
                    name: name,
                    category: category,
                    distance: distance,
                    address: poiDict["address"] as? String,
                    coordinate: poiCoord
                )
        }
        
        // 按距离排序
        let sortedPOIs = poiInfos.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
        
        return NearbyPOIResult(
            pois: sortedPOIs,
            center: center,
            radius: radius
        )
    }
    
    private func parseAddressComponent(_ addressComponent: [String: Any]?, formattedAddress: String) -> GeocodeResult.AddressInfo {
        guard let component = addressComponent else {
            return GeocodeResult.AddressInfo(
                country: nil,
                province: nil,
                city: nil,
                district: nil,
                street: nil,
                streetNumber: nil,
                formattedAddress: formattedAddress
            )
        }
        
        return GeocodeResult.AddressInfo(
            country: component["country"] as? String,
            province: component["province"] as? String,
            city: component["city"] as? String ?? component["district"] as? String,
            district: component["district"] as? String,
            street: component["street"] as? String,
            streetNumber: component["streetNumber"] as? String,
            formattedAddress: formattedAddress.isEmpty ? buildFormattedAddress(from: component) : formattedAddress
        )
    }
    
    private func buildFormattedAddress(from component: [String: Any]) -> String {
        var parts: [String] = []
        
        if let province = component["province"] as? String, !province.isEmpty {
            parts.append(province)
        }
        if let city = component["city"] as? String, !city.isEmpty {
            parts.append(city)
        }
        if let district = component["district"] as? String, !district.isEmpty {
            parts.append(district)
        }
        if let street = component["street"] as? String, !street.isEmpty {
            parts.append(street)
        }
        if let streetNumber = component["streetNumber"] as? String, !streetNumber.isEmpty {
            parts.append(streetNumber)
        }
        
        return parts.joined(separator: "")
    }
    
    private func parsePOIInfo(from pois: [[String: Any]]?, center: CLLocationCoordinate2D) -> GeocodeResult.POIInfo? {
        guard let pois = pois, !pois.isEmpty else { return nil }
        
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        
        // 找到最近的POI
        let nearestPOI = pois.compactMap { poiDict -> (GeocodeResult.POIInfo, Double)? in
            guard let name = poiDict["name"] as? String,
                  let locationStr = poiDict["location"] as? String else {
                return nil
            }
            
            let parts = locationStr.split(separator: ",")
            guard parts.count == 2,
                  let lon = Double(String(parts[0])),
                  let lat = Double(String(parts[1])) else {
                return nil
            }
            
            // 直接使用高德返回的坐标，不进行转换
            // 注意：高德返回的是GCJ02坐标，直接使用可能会有偏差
            let poiCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            let poiLocation = CLLocation(latitude: poiCoord.latitude, longitude: poiCoord.longitude)
            let distance = poiLocation.distance(from: centerLocation)
            
            let type = poiDict["type"] as? String
            let category = extractPOICategory(from: type)
            
            let poiInfo = GeocodeResult.POIInfo(
                name: name,
                category: category,
                distance: distance,
                address: poiDict["address"] as? String,
                coordinate: poiCoord
            )
            
            return (poiInfo, distance)
        }.min { $0.1 < $1.1 }
        
        return nearestPOI?.0
    }
    
    /// 从高德POI类型中提取分类信息
    private func extractPOICategory(from typeString: String?) -> String? {
        guard let type = typeString else { return nil }
        
        // 高德POI类型格式：类型代码|类型名称
        // 例如：060000|餐饮服务,060100|中餐厅
        let components = type.split(separator: "|")
        if components.count >= 2 {
            return String(components[1])  // 返回类型名称
        }
        
        return type
    }
}

// MARK: - AMap Errors

enum AMapError: LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "未接收到数据"
        case .invalidResponse:
            return "无效的API响应"
        case .apiError(let message):
            return "高德API错误：\(message)"
        }
    }
}

