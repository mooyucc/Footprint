# 高德API混合策略实施计划

## 📋 项目概述

**目标**：在中国地区使用高德API进行POI搜索和地理编码，其他地区继续使用Apple MapKit，地图显示统一使用Apple MapKit。

**实施策略**：混合策略，逐步迁移，风险可控。

---

## 🎯 实施目标

### 核心目标
1. ✅ 提升中国地区POI识别率（从60%提升到85%+）
2. ✅ 解决启动初期无响应问题
3. ✅ 保持全球其他地区的兼容性
4. ✅ 最小化对现有代码的影响

### 功能范围
- **POI搜索**：点击地图位置时搜索POI
- **反向地理编码**：获取地址和POI信息
- **地理编码**：根据地址获取坐标（可选）
- **周边POI搜索**：搜索指定范围内的POI列表（新增功能）

---

## 📦 准备工作

### 1. 高德开放平台配置

#### 步骤1：创建应用
1. 登录[高德开放平台](https://lbs.amap.com/)
2. 进入控制台 → 应用管理 → 创建新应用
3. 填写应用信息：
   - 应用名称：Footprint
   - 应用类型：iOS应用
   - Bundle ID：从Xcode项目获取

#### 步骤2：获取API Key
1. 创建Key，选择服务：
   - ✅ Web服务API（用于逆地理编码和POI搜索）
   - ✅ iOS SDK（可选，如果未来需要地图显示）
2. 记录API Key（后续需要配置）

#### 步骤3：配置安全设置
- 设置Bundle ID白名单
- 设置IP白名单（如果需要）
- 配置Referer（Web API）

### 2. 项目依赖管理

#### 选项A：使用Swift Package Manager（推荐）
```swift
// 高德地图iOS SDK的SPM支持
// 需要在Package.swift中添加依赖
```

#### 选项B：使用CocoaPods
```ruby
# Podfile
pod 'AMapLocation'
pod 'AMapSearch'  # 如果需要搜索功能
```

**推荐使用SPM**，因为项目可能已经在使用SPM。

---

## 🏗️ 架构设计

### 服务层架构

```
MapView (SwiftUI View)
    ↓
GeocodeService (统一接口)
    ├─→ AMapGeocodeService (高德实现) - 中国地区
    └─→ AppleGeocodeService (Apple实现) - 其他地区
```

### 文件结构

```
Footprint/
├── Helpers/
│   ├── GeocodeService.swift          # 统一地理编码接口
│   ├── AMapGeocodeService.swift      # 高德API实现（新建）
│   ├── AppleGeocodeService.swift     # Apple MapKit实现（新建）
│   └── CoordinateConverter.swift     # 坐标转换（已存在）
├── Models/
│   └── GeocodeResult.swift           # 统一结果模型（新建）
└── Views/
    └── MapView.swift                 # 修改：使用GeocodeService
```

---

## 📝 实施步骤

### 阶段1：基础架构搭建（2-3天）

#### 步骤1.1：创建统一接口和模型

**新建文件**：`Footprint/Models/GeocodeResult.swift`

```swift
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
    }
    
    struct AddressInfo {
        let country: String?
        let province: String?
        let city: String?
        let district: String?
        let street: String?
        let streetNumber: String?
        let formattedAddress: String
    }
    
    struct POIInfo {
        let name: String
        let category: String?
        let distance: Double?  // 距离搜索点的距离（米）
        let address: String?
    }
}

/// 周边POI搜索结果
struct NearbyPOIResult {
    let pois: [GeocodeResult.POIInfo]
    let center: CLLocationCoordinate2D
    let radius: Int  // 搜索半径（米）
}
```

**新建文件**：`Footprint/Helpers/GeocodeService.swift`

```swift
import Foundation
import CoreLocation

/// 统一的地理编码服务协议
protocol GeocodeServiceProtocol {
    /// 反向地理编码：根据坐标获取地址和POI信息
    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<GeocodeResult, Error>) -> Void
    )
    
    /// 搜索周边POI
    func searchNearbyPOIs(
        coordinate: CLLocationCoordinate2D,
        radius: Int,
        completion: @escaping (Result<NearbyPOIResult, Error>) -> Void
    )
    
    /// 取消所有进行中的请求
    func cancelAllRequests()
}

/// 地理编码服务工厂
class GeocodeServiceFactory {
    static func createService(for coordinate: CLLocationCoordinate2D) -> GeocodeServiceProtocol {
        let isInChina = isInChinaBoundingBox(coordinate)
        
        if isInChina {
            return AMapGeocodeService.shared
        } else {
            return AppleGeocodeService.shared
        }
    }
    
    private static func isInChinaBoundingBox(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 复用MapView中的判断逻辑
        // 或者提取到CoordinateConverter中
        return CoordinateConverter.isInChina(coordinate)
    }
}
```

#### 步骤1.2：扩展CoordinateConverter

**修改文件**：`Footprint/Helpers/CoordinateConverter.swift`

添加中国边界判断方法：

```swift
extension CoordinateConverter {
    /// 判断坐标是否在中国境内
    static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 使用简化的边界框判断
        // 可以复用MapView中的chinaMainlandPolygon逻辑
        // 或者使用更精确的多边形判断
        return isInChinaBoundingBox(coordinate)
    }
    
    private static func isInChinaBoundingBox(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 简化的边界框判断
        let minLat = 18.0
        let maxLat = 54.0
        let minLon = 73.0
        let maxLon = 135.0
        
        return coordinate.latitude >= minLat &&
               coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon &&
               coordinate.longitude <= maxLon
    }
}
```

### 阶段2：实现高德API服务（3-5天）

#### 步骤2.1：添加高德SDK依赖

**使用Swift Package Manager**

在Xcode中：
1. File → Add Package Dependencies
2. 添加高德地图SDK（如果支持SPM）
3. 或使用CocoaPods

**使用HTTP API（推荐，更轻量）**

不需要集成SDK，直接使用HTTP API：
- 更轻量，不增加应用体积
- 更容易维护
- 功能完全满足需求

#### 步骤2.2：创建高德API服务

**新建文件**：`Footprint/Helpers/AMapGeocodeService.swift`

```swift
import Foundation
import CoreLocation

/// 高德地图地理编码服务实现
class AMapGeocodeService: GeocodeServiceProtocol {
    static let shared = AMapGeocodeService()
    
    private let apiKey: String
    private let baseURL = "https://restapi.amap.com/v3"
    private var activeRequests: [URLSessionDataTask] = []
    private let requestQueue = DispatchQueue(label: "com.footprint.amap.request")
    
    private init() {
        // 从配置文件或环境变量读取API Key
        // 优先从Info.plist读取
        if let key = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String {
            self.apiKey = key
        } else if let key = ProcessInfo.processInfo.environment["AMapAPIKey"] {
            self.apiKey = key
        } else {
            fatalError("高德API Key未配置，请在Info.plist中添加AMapAPIKey")
        }
    }
    
    // MARK: - GeocodeServiceProtocol Implementation
    
    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<GeocodeResult, Error>) -> Void
    ) {
        // 转换坐标：WGS84 -> GCJ02
        let gcj02Coordinate = CoordinateConverter.wgs84ToGCJ02(coordinate)
        
        let urlString = "\(baseURL)/geocode/regeo"
        var components = URLComponents(string: urlString)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "location", value: "\(gcj02Coordinate.longitude),\(gcj02Coordinate.latitude)"),
            URLQueryItem(name: "radius", value: "1000"),
            URLQueryItem(name: "extensions", value: "all"),
            URLQueryItem(name: "output", value: "json")
        ]
        
        guard let url = components.url else {
            completion(.failure(AMapError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(AMapError.noData))
                }
                return
            }
            
            do {
                let result = try self.parseReGeocodeResponse(data: data, originalCoordinate: coordinate)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
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
    
    func searchNearbyPOIs(
        coordinate: CLLocationCoordinate2D,
        radius: Int,
        completion: @escaping (Result<NearbyPOIResult, Error>) -> Void
    ) {
        // 转换坐标：WGS84 -> GCJ02
        let gcj02Coordinate = CoordinateConverter.wgs84ToGCJ02(coordinate)
        
        let urlString = "\(baseURL)/place/around"
        var components = URLComponents(string: urlString)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "location", value: "\(gcj02Coordinate.longitude),\(gcj02Coordinate.latitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "offset", value: "20"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "extensions", value: "all")
        ]
        
        guard let url = components.url else {
            completion(.failure(AMapError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(AMapError.noData))
                }
                return
            }
            
            do {
                let result = try self.parseNearbyPOIResponse(data: data, center: coordinate, radius: radius)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
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
            self.activeRequests.forEach { $0.cancel() }
            self.activeRequests.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func parseReGeocodeResponse(data: Data, originalCoordinate: CLLocationCoordinate2D) throws -> GeocodeResult {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let status = json?["status"] as? String,
              status == "1",
              let regeocode = json?["regeocode"] as? [String: Any] else {
            throw AMapError.invalidResponse
        }
        
        let addressComponent = regeocode["addressComponent"] as? [String: Any]
        let pois = regeocode["pois"] as? [[String: Any]]
        
        // 解析地址信息
        let addressInfo = parseAddressComponent(addressComponent)
        
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
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let status = json?["status"] as? String,
              status == "1",
              let pois = json?["pois"] as? [[String: Any]] else {
            throw AMapError.invalidResponse
        }
        
        let poiInfos = pois.compactMap { poiDict -> GeocodeResult.POIInfo? in
            guard let name = poiDict["name"] as? String,
                  let locationStr = poiDict["location"] as? String else {
                return nil
            }
            
            let parts = locationStr.split(separator: ",")
            guard parts.count == 2,
                  let lon = Double(parts[0]),
                  let lat = Double(parts[1]) else {
                return nil
            }
            
            // 转换坐标：GCJ02 -> WGS84
            let gcj02Coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let wgs84Coord = CoordinateConverter.gcj02ToWGS84(gcj02Coord)
            
            // 计算距离
            let poiLocation = CLLocation(latitude: wgs84Coord.latitude, longitude: wgs84Coord.longitude)
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let distance = poiLocation.distance(from: centerLocation)
            
            return GeocodeResult.POIInfo(
                name: name,
                category: poiDict["type"] as? String,
                distance: distance,
                address: poiDict["address"] as? String
            )
        }.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }
        
        return NearbyPOIResult(
            pois: poiInfos,
            center: center,
            radius: radius
        )
    }
    
    private func parseAddressComponent(_ addressComponent: [String: Any]?) -> GeocodeResult.AddressInfo {
        guard let component = addressComponent else {
            return GeocodeResult.AddressInfo(
                country: nil,
                province: nil,
                city: nil,
                district: nil,
                street: nil,
                streetNumber: nil,
                formattedAddress: ""
            )
        }
        
        return GeocodeResult.AddressInfo(
            country: component["country"] as? String,
            province: component["province"] as? String,
            city: component["city"] as? String ?? component["district"] as? String,
            district: component["district"] as? String,
            street: component["street"] as? String,
            streetNumber: component["streetNumber"] as? String,
            formattedAddress: component["formatted_address"] as? String ?? ""
        )
    }
    
    private func parsePOIInfo(from pois: [[String: Any]]?, center: CLLocationCoordinate2D) -> GeocodeResult.POIInfo? {
        guard let pois = pois, !pois.isEmpty else { return nil }
        
        // 找到最近的POI
        let nearestPOI = pois.compactMap { poiDict -> (GeocodeResult.POIInfo, Double)? in
            guard let name = poiDict["name"] as? String,
                  let locationStr = poiDict["location"] as? String else {
                return nil
            }
            
            let parts = locationStr.split(separator: ",")
            guard parts.count == 2,
                  let lon = Double(parts[0]),
                  let lat = Double(parts[1]) else {
                return nil
            }
            
            let gcj02Coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let wgs84Coord = CoordinateConverter.gcj02ToWGS84(gcj02Coord)
            
            let poiLocation = CLLocation(latitude: wgs84Coord.latitude, longitude: wgs84Coord.longitude)
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let distance = poiLocation.distance(from: centerLocation)
            
            let poiInfo = GeocodeResult.POIInfo(
                name: name,
                category: poiDict["type"] as? String,
                distance: distance,
                address: poiDict["address"] as? String
            )
            
            return (poiInfo, distance)
        }.min { $0.1 < $1.1 }
        
        return nearestPOI?.0
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
```

### 阶段3：实现Apple MapKit服务（1-2天）

#### 步骤3.1：创建Apple MapKit服务

**新建文件**：`Footprint/Helpers/AppleGeocodeService.swift`

```swift
import Foundation
import CoreLocation
import MapKit

/// Apple MapKit地理编码服务实现
class AppleGeocodeService: GeocodeServiceProtocol {
    static let shared = AppleGeocodeService()
    
    private let geocoder = CLGeocoder()
    private var activeRequests: [CLGeocoder] = []
    
    private init() {}
    
    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<GeocodeResult, Error>) -> Void
    ) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(.failure(GeocodeError.noPlacemark))
                return
            }
            
            let result = self.convertPlacemarkToResult(placemark: placemark, coordinate: coordinate)
            completion(.success(result))
        }
    }
    
    func searchNearbyPOIs(
        coordinate: CLLocationCoordinate2D,
        radius: Int,
        completion: @escaping (Result<NearbyPOIResult, Error>) -> Void
    ) {
        let request = MKLocalSearch.Request()
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: Double(radius) / 111000.0 * 2,
                longitudeDelta: Double(radius) / 111000.0 * 2
            )
        )
        request.region = region
        
        if #available(iOS 13.0, *) {
            request.resultTypes = [.pointOfInterest]
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let response = response else {
                completion(.failure(GeocodeError.noResponse))
                return
            }
            
            let poiInfos = response.mapItems.compactMap { item -> GeocodeResult.POIInfo? in
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let centerLocation = CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                let distance = itemLocation.distance(from: centerLocation)
                
                return GeocodeResult.POIInfo(
                    name: item.name ?? "未知地点",
                    category: item.pointOfInterestCategory?.rawValue,
                    distance: distance,
                    address: item.placemark.thoroughfare
                )
            }.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }
            
            let result = NearbyPOIResult(
                pois: poiInfos,
                center: coordinate,
                radius: radius
            )
            completion(.success(result))
        }
    }
    
    func cancelAllRequests() {
        geocoder.cancelGeocode()
        activeRequests.removeAll()
    }
    
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
                    address: placemark.thoroughfare
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
}

enum GeocodeError: LocalizedError {
    case noPlacemark
    case noResponse
    
    var errorDescription: String? {
        switch self {
        case .noPlacemark:
            return "未找到地址信息"
        case .noResponse:
            return "未收到搜索响应"
        }
    }
}
```

### 阶段4：集成到MapView（2-3天）

#### 步骤4.1：修改MapView使用GeocodeService

**修改文件**：`Footprint/Views/MapView.swift`

主要修改点：

1. **添加服务实例**
```swift
// 在地图点击处理中使用
private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
    // ...
    searchPOIAtCoordinate(coordinate, isUserInitiated: true)
}

private func searchPOIAtCoordinate(_ coordinate: CLLocationCoordinate2D, searchSpan: MKCoordinateSpan?, isRetry: Bool, isUserInitiated: Bool = false) {
    // 获取适合的服务
    let service = GeocodeServiceFactory.createService(for: coordinate)
    
    // 使用统一的服务接口
    service.reverseGeocode(coordinate: coordinate) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let geocodeResult):
                self?.handleGeocodeResult(geocodeResult, coordinate: coordinate)
            case .failure(let error):
                self?.handleGeocodeError(error, coordinate: coordinate)
            }
        }
    }
    
    // 同时搜索周边POI（可选）
    if isInChina {
        service.searchNearbyPOIs(coordinate: coordinate, radius: 500) { [weak self] result in
            // 处理周边POI结果
        }
    }
}
```

2. **处理统一的结果模型**
```swift
private func handleGeocodeResult(_ result: GeocodeResult, coordinate: CLLocationCoordinate2D) {
    // 转换为MKMapItem用于显示
    let mapItem = createMapItem(from: result)
    showPOIResult(mapItem, message: "✅ 找到位置信息（来源：\(result.source == .amap ? "高德地图" : "Apple Maps")）")
}

private func createMapItem(from result: GeocodeResult) -> MKMapItem {
    let placemark = MKPlacemark(coordinate: result.coordinate)
    let mapItem = MKMapItem(placemark: placemark)
    
    // 设置名称
    if let poi = result.poi {
        mapItem.name = poi.name
    } else {
        mapItem.name = result.address.formattedAddress
    }
    
    return mapItem
}
```

### 阶段5：配置和测试（2-3天）

#### 步骤5.1：配置API Key

**修改文件**：`Footprint/Info.plist`（或通过Xcode的Build Settings）

添加：
```xml
<key>AMapAPIKey</key>
<string>你的高德API Key</string>
```

或者使用环境变量（更安全）：
- 在Xcode的Scheme中配置环境变量
- 或在CI/CD中配置

#### 步骤5.2：测试计划

**测试场景**：

1. **中国地区测试**
   - ✅ 点击知名POI（如天安门、故宫）
   - ✅ 点击小众POI
   - ✅ 点击没有POI的位置（应该显示地址信息）
   - ✅ 测试启动后立即点击POI

2. **其他地区测试**
   - ✅ 点击国外知名地点
   - ✅ 验证仍使用Apple MapKit

3. **边界测试**
   - ✅ 中国边界附近的位置
   - ✅ 坐标转换准确性

4. **性能测试**
   - ✅ 响应速度
   - ✅ 网络错误处理
   - ✅ 超时处理

#### 步骤5.3：错误处理和日志

添加详细的日志记录：
```swift
print("📍 [高德API] 反向地理编码请求: (\(coordinate.latitude), \(coordinate.longitude))")
print("✅ [高德API] 成功获取POI: \(result.poi?.name ?? "无")")
print("❌ [高德API] 请求失败: \(error.localizedDescription)")
```

---

## ✅ 实施检查清单

### 阶段1：基础架构
- [ ] 创建`GeocodeResult.swift`模型
- [ ] 创建`GeocodeService.swift`协议
- [ ] 创建`GeocodeServiceFactory`
- [ ] 扩展`CoordinateConverter`添加中国判断

### 阶段2：高德API实现
- [ ] 在高德开放平台创建应用并获取API Key
- [ ] 创建`AMapGeocodeService.swift`
- [ ] 实现反向地理编码功能
- [ ] 实现周边POI搜索功能
- [ ] 实现坐标转换（WGS84 ↔ GCJ02）
- [ ] 添加错误处理和重试机制
- [ ] 添加请求超时处理

### 阶段3：Apple MapKit实现
- [ ] 创建`AppleGeocodeService.swift`
- [ ] 实现反向地理编码功能
- [ ] 实现周边POI搜索功能
- [ ] 实现结果模型转换

### 阶段4：集成到MapView
- [ ] 修改`MapView.swift`使用`GeocodeService`
- [ ] 更新`searchPOIAtCoordinate`方法
- [ ] 更新`tryReverseGeocodeWithPOI`方法
- [ ] 实现结果处理逻辑
- [ ] 保持向后兼容性

### 阶段5：配置和测试
- [ ] 配置API Key（Info.plist或环境变量）
- [ ] 中国地区功能测试
- [ ] 其他地区功能测试
- [ ] 边界情况测试
- [ ] 性能测试
- [ ] 错误处理测试
- [ ] 添加日志记录
- [ ] 代码审查

---

## 📊 预期时间表

| 阶段 | 任务 | 预计时间 | 状态 |
|------|------|---------|------|
| 阶段1 | 基础架构搭建 | 2-3天 | ⬜ 未开始 |
| 阶段2 | 高德API实现 | 3-5天 | ⬜ 未开始 |
| 阶段3 | Apple MapKit实现 | 1-2天 | ⬜ 未开始 |
| 阶段4 | 集成到MapView | 2-3天 | ⬜ 未开始 |
| 阶段5 | 配置和测试 | 2-3天 | ⬜ 未开始 |
| **总计** | | **10-16天** | |

---

## ⚠️ 注意事项

### 1. API Key安全
- ✅ 不要将API Key提交到Git仓库
- ✅ 使用环境变量或配置文件（不纳入版本控制）
- ✅ 考虑使用服务端代理（最安全）

### 2. 坐标系统
- ✅ 高德使用GCJ-02坐标系
- ✅ Apple使用WGS-84坐标系
- ✅ 所有坐标转换必须正确

### 3. 错误处理
- ✅ 网络错误
- ✅ API错误
- ✅ 超时处理
- ✅ 降级策略（高德失败时使用Apple）

### 4. 性能优化
- ✅ 请求缓存
- ✅ 请求去重
- ✅ 合理的超时时间
- ✅ 避免过度请求

### 5. 配额管理
- ✅ 监控API调用量
- ✅ 实现请求节流
- ✅ 合理使用缓存

---

## 📚 参考资源

- [高德开放平台文档](https://lbs.amap.com/api/webservice/summary)
- [逆地理编码API文档](https://lbs.amap.com/api/webservice/guide/api/georegeo)
- [周边搜索API文档](https://lbs.amap.com/api/webservice/guide/api/search)
- [坐标转换说明](https://lbs.amap.com/faq/js-api/map-js-api/coordinate-system)

---

**最后更新**：2025-12-05
**状态**：规划阶段
**下一步**：开始阶段1 - 基础架构搭建

