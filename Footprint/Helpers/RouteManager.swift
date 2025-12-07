//
//  RouteManager.swift
//  Footprint
//
//  Created by K.X on 2025/01/XX.
//

import Foundation
import MapKit
import SwiftUI
import Combine
import ObjectiveC

/// 路线管理器：用于计算地点之间的实际道路路线
class RouteManager: ObservableObject {
    static let shared = RouteManager()
    
    // MARK: - Custom Transport Types
    /// 飞机交通方式（自定义，使用直线距离）
    /// 使用 0x100 (256) 作为 rawValue，避免与系统定义的交通方式冲突
    static let airplane: MKDirectionsTransportType = MKDirectionsTransportType(rawValue: 0x100)
    
    // MARK: - Nested Types
    private struct PersistedRouteEntry: Codable {
        struct Coordinate: Codable {
            let latitude: Double
            let longitude: Double
        }
        
        let startLatitude: Double
        let startLongitude: Double
        let endLatitude: Double
        let endLongitude: Double
        let distance: Double
        let expectedTravelTime: Double
        let transportTypeRawValue: UInt
        let timestamp: Date
        let coordinates: [Coordinate]
        
        func isExpired(referenceDate: Date, validity duration: TimeInterval) -> Bool {
            referenceDate.timeIntervalSince(timestamp) > duration
        }
    }
    
    // 缓存已计算的路线，key 为起点和终点的坐标组合
    private var routeCache: [String: MKRoute] = [:]
    private var persistedRouteEntries: [String: PersistedRouteEntry] = [:]
    
    // 存储当前计算出的所有路线
    @Published var routes: [String: MKRoute] = [:]
    
    // 用户手动选择的交通方式偏好（key: routeKey, value: transportType的rawValue）
    // nil 表示使用自动选择，非nil表示用户手动选择
    private var userTransportPreferences: [String: UInt] = [:]
    private let preferencesQueue = DispatchQueue(label: "com.footprint.route.preferences", attributes: .concurrent)
    
    private let preferencesFileURL: URL
    
    private let cacheQueue = DispatchQueue(label: "com.footprint.route.cache", attributes: .concurrent)
    
    // 信号量：限制并发请求数量（Apple 建议最多 5 个并发 MKDirections 请求）
    private let requestSemaphore = DispatchSemaphore(value: 5)
    
    // 正在进行的请求数量（用于调试）
    private var activeRequestCount: Int = 0
    private let requestCountQueue = DispatchQueue(label: "com.footprint.route.requestCount")
    
    // 请求节流：避免短时间内发送过多请求导致被限流
    private var lastRequestTime: Date = Date.distantPast
    private let minRequestInterval: TimeInterval = 0.1 // 最小请求间隔：100ms
    private let requestThrottleQueue = DispatchQueue(label: "com.footprint.route.throttle")
    private let persistenceWriteQueue = DispatchQueue(label: "com.footprint.route.persistenceWrite")
    
    // 最大路线计算距离（单位：米）- 超过此距离的路线可能无法计算或成功率低
    // 约 5000 公里，适合大多数情况
    private let maxRouteDistance: CLLocationDistance = 5_000_000
    
    // 失败路线缓存（避免重复尝试计算明显无法成功的路线）
    private var failedRoutes: Set<String> = []
    private let failedRoutesQueue = DispatchQueue(label: "com.footprint.route.failed")
    
    private let cacheFileURL: URL
    private static let cacheValidityDuration: TimeInterval = 60 * 60 * 24 * 30 // 30 天
    
    private init() {
        let baseDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        
        let directory = baseDirectory.appendingPathComponent("RouteCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.cacheFileURL = directory.appendingPathComponent("routes.json")
        self.preferencesFileURL = directory.appendingPathComponent("transportPreferences.json")
        
        self.persistedRouteEntries = Self.loadPersistedCache(from: cacheFileURL)
        self.userTransportPreferences = Self.loadTransportPreferences(from: preferencesFileURL)
    }
    
    /// 计算两个地点之间的路线
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    ///   - transportType: 交通方式（nil 表示自动选择：近距离优先徒步，远距离使用机动车）
    ///   - completion: 完成回调，返回计算出的路线或 nil
    func calculateRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType? = nil,
        completion: @escaping (MKRoute?) -> Void
    ) {
        let cacheKey = routeKey(from: source, to: destination)
        
        // 确定使用的交通方式：优先使用传入的参数，其次使用用户偏好，最后使用自动选择
        let finalTransportType: MKDirectionsTransportType?
        if let specifiedType = transportType {
            finalTransportType = specifiedType
        } else if let userPreference = getUserTransportType(from: source, to: destination) {
            finalTransportType = userPreference
        } else {
            finalTransportType = nil // 使用自动选择
        }
        
        // 计算两点间的直线距离
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distance = sourceLocation.distance(from: destinationLocation)
        
        // 检查缓存（线程安全）
        cacheQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // 检查是否在失败列表中
            var isFailed = false
            self.failedRoutesQueue.sync {
                isFailed = self.failedRoutes.contains(cacheKey)
            }
            
            if isFailed {
                print("⏭️ 跳过已知失败的路线: 距离 \(String(format: "%.1f", distance/1000))km")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 检查距离限制
            if distance > self.maxRouteDistance {
                print("⚠️ 路线距离过远 (\(String(format: "%.1f", distance/1000))km)，跳过计算")
                // 记录到失败列表
                self.failedRoutesQueue.async(flags: .barrier) {
                    self.failedRoutes.insert(cacheKey)
                }
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let cachedRoute = self.cacheQueue.sync(execute: { self.routeCache[cacheKey] }) {
                DispatchQueue.main.async {
                    completion(cachedRoute)
                }
                return
            }
            
            var persistedEntry: PersistedRouteEntry?
            self.cacheQueue.sync {
                persistedEntry = self.persistedRouteEntries[cacheKey]
            }
            
            if let entry = persistedEntry {
                if entry.isExpired(referenceDate: Date(), validity: Self.cacheValidityDuration) {
                    self.removePersistedRoute(for: cacheKey)
                } else if let restoredRoute = self.routeFromPersistedEntry(entry) {
                    self.cacheQueue.async(flags: .barrier) {
                        self.routeCache[cacheKey] = restoredRoute
                    }
                    DispatchQueue.main.async {
                        completion(restoredRoute)
                    }
                    return
                } else {
                    self.removePersistedRoute(for: cacheKey)
                }
            }
            
            // 请求节流：避免短时间内发送过多请求导致被限流
            // 在后台队列中等待，避免阻塞主线程
            // 捕获 finalTransportType 以便在嵌套闭包中使用
            let capturedTransportType = finalTransportType
            self.requestThrottleQueue.async {
                let now = Date()
                let timeSinceLastRequest = now.timeIntervalSince(self.lastRequestTime)
                if timeSinceLastRequest < self.minRequestInterval {
                    let waitTime = self.minRequestInterval - timeSinceLastRequest
                    Thread.sleep(forTimeInterval: waitTime)
                }
                self.lastRequestTime = Date()
                
                // 继续执行路线计算
                self.performRouteCalculation(
                    source: source,
                    destination: destination,
                    distance: distance,
                    cacheKey: cacheKey,
                    transportType: capturedTransportType,
                    completion: completion
                )
            }
        }
    }
    
    // 执行实际的路线计算（从节流逻辑中分离出来）
    private func performRouteCalculation(
        source: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        cacheKey: String,
        transportType: MKDirectionsTransportType? = nil,
        completion: @escaping (MKRoute?) -> Void
    ) {
        // 等待信号量（限制并发请求数）
        self.requestSemaphore.wait()
        
        // 更新活跃请求计数
        self.requestCountQueue.async {
            self.activeRequestCount += 1
        }
        
        // 创建起点和终点
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        
        // 智能选择交通方式
        let selectedTransportType: MKDirectionsTransportType
        if let specifiedType = transportType {
            // 如果明确指定了交通方式，使用指定的
            selectedTransportType = specifiedType
        } else {
            // 自动选择：近距离（5公里内）优先尝试徒步，远距离使用机动车
            // 对于徒步场景（山上、无道路），徒步模式更准确
            if distance <= 5_000 {
                // 5公里内，优先尝试徒步模式
                selectedTransportType = .walking
            } else if distance > 1_000_000 {
                // 超过1000公里，使用 .any 可能成功率更高
                selectedTransportType = .any
            } else {
                // 中等距离，使用机动车
                selectedTransportType = .automobile
            }
        }
        
        // 如果是飞机模式，直接计算直线距离，不调用 MKDirections
        if selectedTransportType == Self.airplane {
            // 释放信号量（飞机模式不需要网络请求）
            self.requestSemaphore.signal()
            self.requestCountQueue.async {
                self.activeRequestCount -= 1
            }
            
            // 创建直线路线
            let coordinates = [source, destination]
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            let route = MKRoute()
            route.setValue(polyline, forKey: "polyline")
            route.footprintDistance = distance
            route.footprintExpectedTravelTime = distance / 800.0 // 假设飞机平均速度 800 km/h
            route.footprintTransportType = Self.airplane
            
            // 缓存路线
            self.cacheQueue.async(flags: .barrier) {
                self.routeCache[cacheKey] = route
            }
            self.persistRoute(route, cacheKey: cacheKey, source: source, destination: destination)
            
            DispatchQueue.main.async {
                completion(route)
            }
            return
        }
        
        // 创建路线请求
        let request = MKDirections.Request()
        request.source = sourceMapItem
        request.destination = destinationMapItem
        request.transportType = selectedTransportType
        
        // 计算路线
        let directions = MKDirections(request: request)
        let startTime = Date()
        directions.calculate { [weak self] response, error in
            // 释放信号量
            self?.requestSemaphore.signal()
            
            // 更新活跃请求计数
            self?.requestCountQueue.async {
                self?.activeRequestCount -= 1
            }
            
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            if let error = error {
                let errorDescription = error.localizedDescription
                let nsError = error as NSError
                let errorCode = nsError.code
                print("⚠️ 路线计算失败 [距离: \(String(format: "%.1f", distance/1000))km, 交通方式: \(self?.transportTypeDescription(selectedTransportType) ?? "未知"), 耗时: \(String(format: "%.2f", elapsedTime))s]")
                print("   错误: \(errorDescription) (代码: \(errorCode))")
                
                // 不再自动退回，直接返回 nil，让 UI 显示占位线
                
                // 对于某些错误类型，记录到失败列表（避免重复尝试）
                // 某些错误（如找不到路线、地点不存在）应该跳过，避免重复尝试
                // 其他错误（如服务器错误、限流）可以重试
                let shouldSkip = errorCode == 3 || errorCode == 4 // directionsNotFound 或 placemarkNotFound 的常见错误码
                if shouldSkip {
                    self?.failedRoutesQueue.async(flags: .barrier) {
                        self?.failedRoutes.insert(cacheKey)
                    }
                }
                
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let route = response?.routes.first else {
                print("⚠️ 未找到路线 [距离: \(String(format: "%.1f", distance/1000))km, 耗时: \(String(format: "%.2f", elapsedTime))s]")
                
                // 不再自动退回，直接返回 nil，让 UI 显示占位线
                
                // 记录到失败列表
                self?.failedRoutesQueue.async(flags: .barrier) {
                    self?.failedRoutes.insert(cacheKey)
                }
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            print("✅ 路线计算成功 [距离: \(String(format: "%.1f", distance/1000))km, 交通方式: \(self?.transportTypeDescription(selectedTransportType) ?? "未知"), 路线距离: \(String(format: "%.1f", route.footprintDistance/1000))km, 耗时: \(String(format: "%.2f", elapsedTime))s]")
            
            // 缓存路线（线程安全）
            if let self = self {
                route.footprintDistance = route.distance
                route.footprintExpectedTravelTime = route.expectedTravelTime
                route.footprintTransportType = route.transportType
                
                self.cacheQueue.async(flags: .barrier) {
                    self.routeCache[cacheKey] = route
                }
                self.persistRoute(
                    route,
                    cacheKey: cacheKey,
                    source: source,
                    destination: destination
                )
                
                // 更新 published 属性在主线程
                DispatchQueue.main.async {
                    self.routes[cacheKey] = route
                    completion(route)
                }
            }
        }
    }
    
    /// 计算两个地点之间的路线（async/await 版本，性能更好）
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    ///   - transportType: 交通方式（nil 表示自动选择）
    /// - Returns: 计算出的路线或 nil
    func calculateRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType? = nil
    ) async -> MKRoute? {
        return await withCheckedContinuation { continuation in
            calculateRoute(from: source, to: destination, transportType: transportType) { route in
                continuation.resume(returning: route)
            }
        }
    }
    
    /// 批量计算多个连续地点之间的路线（回调版本）
    /// - Parameters:
    ///   - destinations: 按顺序排列的地点坐标数组
    ///   - completion: 完成回调，返回所有计算出的路线（按顺序）
    func calculateRoutes(
        for destinations: [CLLocationCoordinate2D],
        completion: @escaping ([MKRoute]) -> Void
    ) {
        guard destinations.count >= 2 else {
            completion([])
            return
        }
        
        Task {
            let routes = await calculateRoutes(for: destinations)
            await MainActor.run {
                completion(routes)
            }
        }
    }
    
    /// 批量计算多个连续地点之间的路线（async/await 版本，并发执行）
    /// - Parameters:
    ///   - destinations: 按顺序排列的地点坐标数组
    ///   - transportType: 交通方式（nil 表示自动选择）
    /// - Returns: 按顺序返回所有计算出的路线
    func calculateRoutes(for destinations: [CLLocationCoordinate2D], transportType: MKDirectionsTransportType? = nil) async -> [MKRoute] {
        guard destinations.count >= 2 else {
            return []
        }
        
        // 使用 TaskGroup 并发计算所有路线段
        return await withTaskGroup(of: (Int, MKRoute?).self) { group in
            var routes: [(Int, MKRoute?)] = []
            
            // 为每段路线创建任务
            for i in 0..<destinations.count - 1 {
                let source = destinations[i]
                let destination = destinations[i + 1]
                let index = i
                
                group.addTask {
                    let route = await self.calculateRoute(from: source, to: destination, transportType: transportType)
                    return (index, route)
                }
            }
            
            // 收集结果
            for await result in group {
                routes.append(result)
            }
            
            // 按索引排序并过滤掉 nil
            return routes
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
        }
    }
    
    /// 检查路线是否已缓存
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    /// - Returns: 如果已缓存则返回路线，否则返回 nil
    func getCachedRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> MKRoute? {
        let cacheKey = routeKey(from: source, to: destination)
        
        if let cachedRoute = cacheQueue.sync(execute: { routeCache[cacheKey] }) {
            return cachedRoute
        }
        
        var persistedEntry: PersistedRouteEntry?
        cacheQueue.sync {
            persistedEntry = persistedRouteEntries[cacheKey]
        }
        
        guard let entry = persistedEntry else {
            return nil
        }
        
        if entry.isExpired(referenceDate: Date(), validity: Self.cacheValidityDuration) {
            removePersistedRoute(for: cacheKey)
            return nil
        }
        
        guard let route = routeFromPersistedEntry(entry) else {
            removePersistedRoute(for: cacheKey)
            return nil
        }
        
        cacheQueue.async(flags: .barrier) {
            self.routeCache[cacheKey] = route
        }
        return route
    }
    
    /// 生成缓存的 key
    /// 注意：缓存key不包含交通方式，因为同一段路径可能用不同交通方式计算
    /// 如果交通方式改变，需要清除旧缓存
    private func routeKey(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> String {
        return "\(source.latitude),\(source.longitude)->\(destination.latitude),\(destination.longitude)"
    }
    
    // MARK: - User Transport Preferences
    
    /// 获取用户为某段路线选择的交通方式
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    /// - Returns: 用户选择的交通方式，nil 表示使用自动选择
    func getUserTransportType(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> MKDirectionsTransportType? {
        let key = routeKey(from: source, to: destination)
        return preferencesQueue.sync {
            guard let rawValue = userTransportPreferences[key] else {
                return nil
            }
            return MKDirectionsTransportType(rawValue: rawValue)
        }
    }
    
    /// 设置用户为某段路线选择的交通方式
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    ///   - transportType: 交通方式，nil 表示恢复自动选择
    func setUserTransportType(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType?
    ) {
        let key = routeKey(from: source, to: destination)
        
        preferencesQueue.async(flags: .barrier) {
            if let type = transportType {
                self.userTransportPreferences[key] = type.rawValue
            } else {
                self.userTransportPreferences.removeValue(forKey: key)
            }
            
            // 保存到文件
            let snapshot = self.userTransportPreferences
            DispatchQueue.global(qos: .utility).async {
                Self.saveTransportPreferences(snapshot, to: self.preferencesFileURL)
            }
        }
        
        // 清除该路线的缓存，强制重新计算
        clearRouteCache(from: source, to: destination)
        
        print("✅ 已设置路线交通方式偏好: \(key) -> \(transportType?.description ?? "自动")")
    }
    
    /// 加载交通方式偏好
    private static func loadTransportPreferences(from fileURL: URL) -> [String: UInt] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            return try decoder.decode([String: UInt].self, from: data)
        } catch {
            print("⚠️ 交通方式偏好加载失败: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// 保存交通方式偏好
    private static func saveTransportPreferences(_ preferences: [String: UInt], to fileURL: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(preferences)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ 交通方式偏好保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 清除特定路径的缓存（用于强制重新计算）
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    func clearRouteCache(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let cacheKey = routeKey(from: source, to: destination)
        
        cacheQueue.async(flags: .barrier) {
            self.routeCache.removeValue(forKey: cacheKey)
        }
        
        removePersistedRoute(for: cacheKey)
        
        failedRoutesQueue.async(flags: .barrier) {
            self.failedRoutes.remove(cacheKey)
        }
        
        print("🗑️ 已清除路径缓存: \(cacheKey)")
    }
    
    /// 清除所有路径缓存
    func clearAllRouteCache() {
        cacheQueue.async(flags: .barrier) {
            self.routeCache.removeAll()
        }
        
        cacheQueue.async(flags: .barrier) {
            self.persistedRouteEntries.removeAll()
            let snapshot: [String: PersistedRouteEntry] = [:]
            self.persistenceWriteQueue.async {
                Self.savePersistedCache(snapshot, to: self.cacheFileURL)
            }
        }
        
        failedRoutesQueue.async(flags: .barrier) {
            self.failedRoutes.removeAll()
        }
        
        print("🗑️ 已清除所有路径缓存")
    }
    
    // MARK: - Persistence
    private static func loadPersistedCache(from fileURL: URL) -> [String: PersistedRouteEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let originalEntries = try decoder.decode([String: PersistedRouteEntry].self, from: data)
            let now = Date()
            let filteredEntries = originalEntries.filter { _, entry in
                !entry.isExpired(referenceDate: now, validity: cacheValidityDuration)
                    && entry.coordinates.count >= 2
            }
            if filteredEntries.count < originalEntries.count {
                // 清理过期后立即保存，避免重复加载无效数据
                savePersistedCache(filteredEntries, to: fileURL)
            }
            return filteredEntries
        } catch {
            print("⚠️ 路线缓存加载失败: \(error.localizedDescription)")
            return [:]
        }
    }
    
    private static func savePersistedCache(_ entries: [String: PersistedRouteEntry], to fileURL: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ 路线缓存写入失败: \(error.localizedDescription)")
        }
    }
    
    private func persistRoute(
        _ route: MKRoute,
        cacheKey: String,
        source: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) {
        guard route.polyline.pointCount >= 2 else { return }
        
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
        route.polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: route.polyline.pointCount))
        
        let coordinateEntries = coordinates.map {
            PersistedRouteEntry.Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        
        let entry = PersistedRouteEntry(
            startLatitude: source.latitude,
            startLongitude: source.longitude,
            endLatitude: destination.latitude,
            endLongitude: destination.longitude,
            distance: route.footprintDistance,
            expectedTravelTime: route.footprintExpectedTravelTime,
            transportTypeRawValue: route.footprintTransportType.rawValue,
            timestamp: Date(),
            coordinates: coordinateEntries
        )
        
        cacheQueue.async(flags: .barrier) {
            self.persistedRouteEntries[cacheKey] = entry
            let snapshot = self.persistedRouteEntries
            self.persistenceWriteQueue.async {
                Self.savePersistedCache(snapshot, to: self.cacheFileURL)
            }
        }
    }
    
    private func removePersistedRoute(for cacheKey: String) {
        cacheQueue.async(flags: .barrier) {
            self.persistedRouteEntries.removeValue(forKey: cacheKey)
            let snapshot = self.persistedRouteEntries
            self.persistenceWriteQueue.async {
                Self.savePersistedCache(snapshot, to: self.cacheFileURL)
            }
        }
    }
    
    private func routeFromPersistedEntry(_ entry: PersistedRouteEntry) -> MKRoute? {
        let coordinates = entry.coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        
        guard coordinates.count >= 2 else {
            return nil
        }
        
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        let route = MKRoute()
        route.setValue(polyline, forKey: "polyline")
        route.footprintDistance = entry.distance
        route.footprintExpectedTravelTime = entry.expectedTravelTime
        route.footprintTransportTypeRawValue = entry.transportTypeRawValue
        return route
    }
}

// MARK: - MKRoute Footprint Extensions
private var footprintDistanceKey: UInt8 = 0
private var footprintTravelTimeKey: UInt8 = 0
private var footprintTransportTypeKey: UInt8 = 0

extension MKRoute {
    var footprintDistance: CLLocationDistance {
        get {
            if let value = objc_getAssociatedObject(self, &footprintDistanceKey) as? NSNumber {
                return value.doubleValue
            }
            return distance
        }
        set {
            objc_setAssociatedObject(self, &footprintDistanceKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var footprintExpectedTravelTime: TimeInterval {
        get {
            if let value = objc_getAssociatedObject(self, &footprintTravelTimeKey) as? NSNumber {
                return value.doubleValue
            }
            return expectedTravelTime
        }
        set {
            objc_setAssociatedObject(self, &footprintTravelTimeKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var footprintTransportType: MKDirectionsTransportType {
        get {
            if let value = objc_getAssociatedObject(self, &footprintTransportTypeKey) as? NSNumber {
                return MKDirectionsTransportType(rawValue: value.uintValue)
            }
            return transportType
        }
        set {
            objc_setAssociatedObject(self, &footprintTransportTypeKey, NSNumber(value: newValue.rawValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    fileprivate var footprintTransportTypeRawValue: UInt {
        get { footprintTransportType.rawValue }
        set { footprintTransportType = MKDirectionsTransportType(rawValue: newValue) }
    }
}


// MARK: - MKDirectionsTransportType Extension
extension MKDirectionsTransportType {
    /// 获取交通方式的图标名称
    var iconName: String {
        if self == RouteManager.airplane {
            return "airplane"
        } else if self.contains(.walking) && self == .walking {
            return "figure.walk"
        } else if self.contains(.automobile) && self == .automobile {
            return "car.fill"
        } else if self.contains(.transit) && self == .transit {
            return "tram.fill"
        } else {
            return "sparkles" // 自动或其他
        }
    }
    
    /// 获取交通方式的描述
    var description: String {
        if self == RouteManager.airplane {
            return "飞机"
        } else if self.contains(.walking) && self == .walking {
            return "步行"
        } else if self.contains(.automobile) && self == .automobile {
            return "机动车"
        } else if self.contains(.transit) && self == .transit {
            return "公共交通"
        } else {
            return "自动"
        }
    }
}

// MARK: - Helper Methods
extension RouteManager {
    /// 获取交通方式的描述
    private func transportTypeDescription(_ type: MKDirectionsTransportType) -> String {
        // MKDirectionsTransportType 是选项集，可能包含多个值，使用 if-else 检查
        if type == Self.airplane {
            return "飞机"
        } else if type.contains(.automobile) && type == .automobile {
            return "机动车"
        } else if type.contains(.walking) && type == .walking {
            return "步行"
        } else if type.contains(.transit) && type == .transit {
            return "公共交通"
        } else if type.contains(.any) || type == .any {
            return "任意"
        } else {
            // 处理组合值或其他情况
            var descriptions: [String] = []
            if type.contains(.automobile) {
                descriptions.append("机动车")
            }
            if type.contains(.walking) {
                descriptions.append("步行")
            }
            if type.contains(.transit) {
                descriptions.append("公共交通")
            }
            return descriptions.isEmpty ? "未知" : descriptions.joined(separator: "+")
        }
    }
}

