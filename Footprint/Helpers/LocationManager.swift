//
//  LocationManager.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的位置管理器
//

import Foundation
import CoreLocation
import Combine

// MARK: - 位置管理器
/// 位置管理器 - 单例模式，支持在启动画面期间提前初始化
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocationAccuracy: Double?
    private var isUpdatingLocation = false
    
    // 位置去重和优化
    private var lastProcessedLocation: CLLocation?
    private var lastUpdateTime: Date?
    private var consecutiveLowAccuracyCount = 0
    private var lastSpeed: Double = 0.0
    private var hasDeliveredInitialFix = false
    private var lastDeliveredAccuracy: Double = .greatestFiniteMagnitude
    
    // 配置常量
    private let minUpdateInterval: TimeInterval = 1.0 // 最小更新间隔（秒）
    private let maxAccuracyThreshold: Double = 50.0 // 最大精度阈值（米）
    private let initialAccuracyTolerance: Double = 200.0 // 初始定位阶段允许的精度
    private let accuracyImprovementThreshold: Double = 15.0 // 精度改善阈值
    private let minDistanceForUpdate: Double = 3.0 // 最小距离变化（米）
    private let staleLocationThreshold: TimeInterval = 30.0 // 位置数据过期时间（秒）
    
    private override init() {
        super.init()
        locationManager.delegate = self
        
        // ===== 综合定位技术配置 =====
        // iOS 系统会自动使用所有可用的定位技术，包括：
        // 1. GPS（全球定位系统）- 室外高精度定位
        // 2. WiFi 定位 - 通过 WiFi 热点数据库快速定位（室内/城市）
        // 3. 蜂窝网络定位 - 通过基站三角测量（快速但精度较低）
        // 4. 蓝牙定位 - 通过 iBeacon 等（室内定位）
        // 5. 气压计 - 用于高度测量
        // 6. 磁力计 - 用于方向判断
        // 系统会智能地将所有信号源结合起来，提供最快、最准确的位置信息
        // 我们只需要设置精度要求，系统会自动选择最佳组合
        
        // 使用导航级精度：精度更高（±5米或更好），系统会智能优化功耗
        // 适合长时间追踪路线，类似健身app的策略
        // 系统会自动使用 GPS + WiFi + 蜂窝网络等所有可用技术
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        // 设置距离过滤器：当位置变化超过5米时更新（平衡精度和功耗）
        locationManager.distanceFilter = 5.0
        
        // 设置活动类型为健身/导航，系统会根据活动类型优化定位技术使用和功耗
        // 例如：静止时更多使用 WiFi/蜂窝网络，运动时更多使用 GPS
        locationManager.activityType = .fitness
        
        // 允许后台位置更新（如果已授权后台权限）
        locationManager.allowsBackgroundLocationUpdates = false // 默认关闭，需要时再开启
        
        // 检查当前授权状态
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocation() {
        // 如果尚未请求权限，先请求权限
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // 请求一次性位置更新
        locationManager.requestLocation()
    }
    
    /// 开始持续定位更新（用于实时跟踪用户位置）
    func startUpdatingLocation() {
        // 如果尚未请求权限，先请求权限
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        // 检查授权状态
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("⚠️ 位置权限未授权，无法启动持续定位")
            return
        }
        
        // 如果已经在更新，则不需要重复启动
        guard !isUpdatingLocation else {
            return
        }
        
        locationManager.startUpdatingLocation()
        isUpdatingLocation = true
        print("📍 开始持续定位更新")
    }
    
    /// 停止持续定位更新（节省电量）
    /// - Parameter resetDeliveryState: 为 `true` 时重置「首次 fix」相关状态（如权限被拒）；为 `false` 时保留，避免仅因进后台/切 tab 再次前台时重复走冷启动定位逻辑、加重主线程突发负载。
    func stopUpdatingLocation(resetDeliveryState: Bool = false) {
        guard isUpdatingLocation else {
            return
        }
        
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
        
        lastProcessedLocation = nil
        lastUpdateTime = nil
        consecutiveLowAccuracyCount = 0
        lastSpeed = 0.0
        lastLocationAccuracy = nil
        if resetDeliveryState {
            hasDeliveredInitialFix = false
            lastDeliveredAccuracy = .greatestFiniteMagnitude
        }
        
        print("📍 停止持续定位更新")
    }
    
    /// 重置位置缓存（用于重新开始追踪）
    func resetLocationCache() {
        lastProcessedLocation = nil
        lastUpdateTime = nil
        consecutiveLowAccuracyCount = 0
        lastSpeed = 0.0
        lastLocationAccuracy = nil
        hasDeliveredInitialFix = false
        lastDeliveredAccuracy = .greatestFiniteMagnitude
        print("🔄 位置缓存已重置")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 获取最新位置
        guard let location = locations.last else { return }
        let now = Date()
        
        // 1. 时间戳验证：只接受新鲜的位置数据（30秒内）
        let locationAge = abs(location.timestamp.timeIntervalSinceNow)
        if locationAge > staleLocationThreshold {
            print("⚠️ 位置数据过期，忽略: 年龄=\(Int(locationAge))秒")
            return
        }
        
        if let lastTime = lastUpdateTime,
           now.timeIntervalSince(lastTime) > staleLocationThreshold {
            hasDeliveredInitialFix = false
        }
        
        let accuracy = location.horizontalAccuracy
        let effectiveThreshold = hasDeliveredInitialFix ? maxAccuracyThreshold : initialAccuracyTolerance
        
        // 2. 位置质量过滤：只接受水平精度在阈值以内的位置更新
        if accuracy < 0 || accuracy > effectiveThreshold {
            consecutiveLowAccuracyCount += 1
            // 如果连续多次低精度，可以考虑降低精度要求（但这里先严格过滤）
            if consecutiveLowAccuracyCount < 3 {
                print("⚠️ 位置精度较差，忽略此次更新: 精度=\(accuracy)米 (连续\(consecutiveLowAccuracyCount)次)")
            }
            return
        }
        
        // 重置低精度计数
        consecutiveLowAccuracyCount = 0
        
        // 3. 位置去重：避免处理相同或非常接近的位置
        if let lastLocation = lastProcessedLocation {
            let distance = location.distance(from: lastLocation)
            
            // 如果距离变化小于阈值，且时间间隔太短，则忽略（除非精度明显改善）
            if distance < minDistanceForUpdate {
                let accuracyImproved = accuracy + accuracyImprovementThreshold < lastDeliveredAccuracy
                if let lastTime = lastUpdateTime,
                   now.timeIntervalSince(lastTime) < minUpdateInterval,
                   !accuracyImproved {
                    return // 位置变化太小且没有显著精度改善，忽略
                }
            }
        }
        
        // 4. 速度检测和智能调整
        if location.speed >= 0 {
            lastSpeed = location.speed
            
            // 根据速度智能调整距离过滤器（可选优化）
            // 静止时增大距离过滤器，运动时减小
            if location.speed < 0.5 { // 静止（< 0.5 m/s）
                // 静止时可以增大距离过滤器，但这里保持5米不变
            } else if location.speed > 5.0 { // 快速移动（> 5 m/s，约18 km/h）
                // 快速移动时可以减小距离过滤器以获得更平滑的轨迹
                // 但为了省电，这里保持5米不变
            }
        }
        
        // 5. 更新位置
        // 注意：location 对象已经包含了系统综合所有定位技术（GPS + WiFi + 蜂窝网络等）的结果
        // 我们不需要关心具体使用了哪种技术，系统已经为我们选择了最佳组合
        // CoreLocation 返回 WGS84 坐标，国内地图需要 GCJ02（火星坐标）
        // 仅在坐标位于中国境内时会进行修正
        let wgsCoord = location.coordinate
        let gcjCoord = CoordinateConverter.wgs84ToGCJ02(wgsCoord)
        lastKnownLocation = gcjCoord
        lastLocationAccuracy = accuracy
        lastDeliveredAccuracy = accuracy
        if !hasDeliveredInitialFix {
            hasDeliveredInitialFix = true
            print("✅ 初始定位可用，精度=\(String(format: "%.1f", accuracy))米")
        }
        
        // 6. 记录已处理的位置
        lastProcessedLocation = location
        lastUpdateTime = Date()
        
        // 输出位置信息（精度反映了综合定位技术的效果）
        // horizontalAccuracy 越小表示精度越高，通常：
        // - < 5米：主要使用 GPS（室外）
        // - 5-20米：GPS + WiFi/蜂窝网络混合（城市环境）
        // - 20-50米：主要使用 WiFi/蜂窝网络（室内或信号弱时）
        print("📍 获取到用户位置（综合定位）: WGS84(\(wgsCoord.latitude), \(wgsCoord.longitude)) -> GCJ02(\(gcjCoord.latitude), \(gcjCoord.longitude)), 精度=\(String(format: "%.1f", location.horizontalAccuracy))米, 速度=\(String(format: "%.1f", location.speed * 3.6))km/h")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        
        // 详细的错误处理和恢复策略
        switch nsError.code {
        case CLError.locationUnknown.rawValue:
            // 位置未知，但可以继续尝试
            print("⚠️ 位置未知，继续尝试获取位置")
            
        case CLError.denied.rawValue:
            // 用户拒绝授权
            print("❌ 位置权限被拒绝")
            stopUpdatingLocation(resetDeliveryState: true)
            
        case CLError.network.rawValue:
            // 网络错误
            print("⚠️ 网络错误，无法获取位置: \(error.localizedDescription)")
            // 网络错误时可以继续尝试，系统会自动重试
            
        case CLError.headingFailure.rawValue:
            // 方向获取失败（不影响位置）
            print("⚠️ 方向获取失败")
            
        default:
            print("❌ 获取位置失败: \(error.localizedDescription) (错误码: \(nsError.code))")
        }
        
        // 如果是临时错误，系统会自动重试
        // 如果是权限错误，需要用户重新授权
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 位置授权状态变更: \(authorizationStatus.rawValue)")
        
        // 如果已授权且正在更新，重新启动定位
        if (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) && isUpdatingLocation {
            locationManager.startUpdatingLocation()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            // 如果已授权但未在更新，请求一次位置（用于一次性定位场景）
            locationManager.requestLocation()
        }
    }
}
