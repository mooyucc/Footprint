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
    
    /// 无交通方式（跨天连接线，使用浅灰虚线表示，不计算实际路线）
    /// 使用 0x200 (512) 作为 rawValue，用于跨天两地间的路线表达
    static let none: MKDirectionsTransportType = MKDirectionsTransportType(rawValue: 0x200)
    
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
    
    // 失败路线缓存（避免重复尝试计算明显无法成功的路线）；带时间戳，过期后允许自动重试
    // 以下情况会再次尝试路线计算，不会一直显示占位线：
    // 1. 超过 failedRouteRetryInterval（默认 10 分钟）后再次请求该段路线
    // 2. 用户为该段切换交通方式（会清除该段缓存与失败标记）
    // 3. 调用 clearRouteCache / clearAllRouteCache 后
    // 4. 应用冷启动后（failedRoutes 仅内存，重启后为空）
    private var failedRoutes: [String: Date] = [:]
    private let failedRoutesQueue = DispatchQueue(label: "com.footprint.route.failed")
    /// 失败路线在此时间（秒）后可再次尝试计算，避免一直显示占位线
    private let failedRouteRetryInterval: TimeInterval = 600 // 10 分钟
    
    // 进行中的请求合并：同一 cacheKey 只发起一次 MKDirections，多个调用方共享结果
    private var pendingCompletions: [String: [(MKRoute?) -> Void]] = [:]
    private let pendingQueue = DispatchQueue(label: "com.footprint.route.pending", attributes: .concurrent)
    
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
    ///   - transportType: 交通方式（nil 表示使用用户偏好或默认机动车）
    ///   - completion: 完成回调，返回计算出的路线或 nil
    func calculateRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType? = nil,
        completion: @escaping (MKRoute?) -> Void
    ) {
        // 确定使用的交通方式：优先使用传入的参数，其次使用用户偏好，最后使用默认机动车
        let finalTransportType: MKDirectionsTransportType
        if let specifiedType = transportType {
            finalTransportType = specifiedType
        } else if let userPreference = getUserTransportType(from: source, to: destination) {
            finalTransportType = userPreference
        } else {
            // 默认使用机动车
            finalTransportType = .automobile
        }
        
        let cacheKey = routeKey(from: source, to: destination, transportType: finalTransportType)
        
        // 计算两点间的直线距离（使用可复用函数）
        let distance = Self.calculateDistance(from: source, to: destination)
        
        // 检查缓存（线程安全）
        cacheQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // 检查距离限制
            if distance > self.maxRouteDistance {
                print("⚠️ 路线距离过远 (\(String(format: "%.1f", distance/1000))km)，跳过计算")
                // 记录到失败列表
                self.failedRoutesQueue.async(flags: .barrier) {
                    self.failedRoutes[cacheKey] = Date()
                }
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let cachedRoute = self.cacheQueue.sync(execute: { self.routeCache[cacheKey] }) {
                // 更新 published 属性在主线程，确保触发 objectWillChange（即使是从缓存返回）
                DispatchQueue.main.async {
                    self.routes[cacheKey] = cachedRoute
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
                    // 更新 published 属性在主线程，确保触发 objectWillChange（即使是从持久化存储恢复）
                    DispatchQueue.main.async {
                        self.routes[cacheKey] = restoredRoute
                        completion(restoredRoute)
                    }
                    return
                } else {
                    self.removePersistedRoute(for: cacheKey)
                }
            }
            
            // 已知无法获取路线的段（如「路线不可用」）直接返回占位，避免重复请求导致 XPC 过载
            // 超过 failedRouteRetryInterval 后视为过期，会再次尝试计算，避免一直显示占位线
            let (isFailedRoute, shouldClearCache) = self.failedRoutesQueue.sync(flags: .barrier) {
                let now = Date()
                if let failedAt = self.failedRoutes[cacheKey] {
                    if now.timeIntervalSince(failedAt) > self.failedRouteRetryInterval {
                        self.failedRoutes.removeValue(forKey: cacheKey)
                        return (false, true) // 过期，允许重试，并清除占位缓存
                    }
                    return (true, false)
                }
                return (false, false)
            }
            if shouldClearCache {
                self.cacheQueue.async(flags: .barrier) {
                    self.routeCache.removeValue(forKey: cacheKey)
                }
            }
            if isFailedRoute {
                let placeholder = self.makePlaceholderRoute(source: source, destination: destination, distance: distance, transportType: finalTransportType)
                DispatchQueue.main.async {
                    completion(placeholder)
                }
                return
            }
            
            // 请求合并：同一 cacheKey 已有请求在进行时，只追加 completion，不重复发起 MKDirections
            let shouldDispatch = self.pendingQueue.sync(flags: .barrier) {
                if var list = self.pendingCompletions[cacheKey] {
                    list.append(completion)
                    self.pendingCompletions[cacheKey] = list
                    return false
                } else {
                    self.pendingCompletions[cacheKey] = [completion]
                    return true
                }
            }
            guard shouldDispatch else { return }
            
            // 请求节流：避免短时间内发送过多请求导致被限流
            // 在后台队列中等待，避免阻塞主线程
            self.requestThrottleQueue.async {
                let now = Date()
                let timeSinceLastRequest = now.timeIntervalSince(self.lastRequestTime)
                if timeSinceLastRequest < self.minRequestInterval {
                    let waitTime = self.minRequestInterval - timeSinceLastRequest
                    Thread.sleep(forTimeInterval: waitTime)
                }
                self.lastRequestTime = Date()
                
                let wrappedCompletion: (MKRoute?) -> Void = { [weak self] route in
                    guard let self = self else { return }
                    let list = self.pendingQueue.sync(flags: .barrier) {
                        self.pendingCompletions.removeValue(forKey: cacheKey) ?? []
                    }
                    DispatchQueue.main.async {
                        for c in list { c(route) }
                    }
                }
                // 继续执行路线计算
                self.performRouteCalculation(
                    source: source,
                    destination: destination,
                    distance: distance,
                    cacheKey: cacheKey,
                    transportType: finalTransportType,
                    completion: wrappedCompletion
                )
            }
        }
    }
    
    /// 创建占位路线（直线），用于失败或跳过计算时仍能显示距离
    private func makePlaceholderRoute(
        source: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        transportType: MKDirectionsTransportType
    ) -> MKRoute {
        let coordinates = [source, destination]
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        let route = MKRoute()
        route.setValue(polyline, forKey: "polyline")
        route.footprintDistance = distance
        route.footprintExpectedTravelTime = distance / 50.0
        route.footprintTransportType = transportType
        return route
    }
    
    // 执行实际的路线计算（从节流逻辑中分离出来）
    private func performRouteCalculation(
        source: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        cacheKey: String,
        transportType: MKDirectionsTransportType,
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
        
        // 使用确定的交通方式（已在 calculateRoute 中确定）
        let selectedTransportType = transportType
        
        // 如果是飞机模式或"无"模式，直接计算直线，不调用 MKDirections
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
            
            // 更新 published 属性在主线程（与机动车模式保持一致，触发 objectWillChange）
            DispatchQueue.main.async {
                self.routes[cacheKey] = route
                completion(route)
            }
            return
        }
        
        // "无"模式：直接创建直线路线（浅灰虚线，用于跨天两地）
        if selectedTransportType == Self.none {
            self.requestSemaphore.signal()
            self.requestCountQueue.async {
                self.activeRequestCount -= 1
            }
            
            let coordinates = [source, destination]
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            let route = MKRoute()
            route.setValue(polyline, forKey: "polyline")
            route.footprintDistance = distance
            route.footprintExpectedTravelTime = 0
            route.footprintTransportType = Self.none
            
            self.cacheQueue.async(flags: .barrier) {
                self.routeCache[cacheKey] = route
            }
            self.persistRoute(route, cacheKey: cacheKey, source: source, destination: destination)
            
            DispatchQueue.main.async {
                self.routes[cacheKey] = route
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
                
                // 路线不可用等错误加入失败集合（带时间戳），避免重复请求导致 XPC 过载；过期后会再次尝试
                if let self = self {
                    self.failedRoutesQueue.async(flags: .barrier) {
                        self.failedRoutes[cacheKey] = Date()
                    }
                    let placeholderRoute = self.makePlaceholderRoute(source: source, destination: destination, distance: distance, transportType: selectedTransportType)
                    self.cacheQueue.async(flags: .barrier) {
                        self.routeCache[cacheKey] = placeholderRoute
                    }
                    DispatchQueue.main.async {
                        self.routes[cacheKey] = placeholderRoute
                        completion(placeholderRoute)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
                return
            }
            
            guard let route = response?.routes.first else {
                print("⚠️ 未找到路线 [距离: \(String(format: "%.1f", distance/1000))km, 耗时: \(String(format: "%.2f", elapsedTime))s]")
                
                // 无路线也记为失败（带时间戳），过期后会再次尝试
                if let self = self {
                    self.failedRoutesQueue.async(flags: .barrier) {
                        self.failedRoutes[cacheKey] = Date()
                    }
                    let placeholderRoute = self.makePlaceholderRoute(source: source, destination: destination, distance: distance, transportType: selectedTransportType)
                    self.cacheQueue.async(flags: .barrier) {
                        self.routeCache[cacheKey] = placeholderRoute
                    }
                    DispatchQueue.main.async {
                        self.routes[cacheKey] = placeholderRoute
                        completion(placeholderRoute)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
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
    ///   - transportType: 交通方式（nil 表示使用用户偏好或默认机动车）
    /// - Returns: 如果已缓存则返回路线，否则返回 nil
    func getCachedRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType? = nil
    ) -> MKRoute? {
        // 确定使用的交通方式（与 calculateRoute 逻辑一致）
        let finalTransportType: MKDirectionsTransportType
        if let specifiedType = transportType {
            finalTransportType = specifiedType
        } else if let userPreference = getUserTransportType(from: source, to: destination) {
            finalTransportType = userPreference
        } else {
            finalTransportType = .automobile
        }
        
        let cacheKey = routeKey(from: source, to: destination, transportType: finalTransportType)
        
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
    /// 包含交通方式信息，确保不同交通方式的路线分别缓存
    private func routeKey(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType? = nil) -> String {
        let baseKey = "\(source.latitude),\(source.longitude)->\(destination.latitude),\(destination.longitude)"
        if let transportType = transportType {
            return "\(baseKey)|\(transportType.rawValue)"
        }
        // 如果没有指定交通方式，使用默认的机动车方式作为 key
        return "\(baseKey)|\(MKDirectionsTransportType.automobile.rawValue)"
    }
    
    /// 计算两点间的直线距离（可复用函数）
    static func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return sourceLocation.distance(from: destinationLocation)
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
    
    /// 导入路线段（用于从分享的旅程文件恢复路线与交通方式，避免重新计算）
    /// - Parameters:
    ///   - source: 起点
    ///   - destination: 终点
    ///   - transportTypeRawValue: 交通方式 rawValue，0 表示自动
    ///   - distance: 路线距离（米）
    ///   - expectedTravelTime: 预计时长（秒）
    ///   - coordinates: 路线折点；nil 或不足 2 点时只设置交通方式偏好，不写入路线几何
    func importRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportTypeRawValue: UInt,
        distance: Double,
        expectedTravelTime: Double,
        coordinates: [CLLocationCoordinate2D]?
    ) {
        let transportType: MKDirectionsTransportType = transportTypeRawValue == 0
            ? .automobile
            : MKDirectionsTransportType(rawValue: transportTypeRawValue)
        let cacheKey = routeKey(from: source, to: destination, transportType: transportType)
        
        if transportTypeRawValue != 0 {
            setUserTransportPreferenceOnly(from: source, to: destination, transportType: transportType)
        }
        
        guard let coords = coordinates, coords.count >= 2 else {
            return
        }
        
        let coordinateEntries = coords.map {
            PersistedRouteEntry.Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        let entry = PersistedRouteEntry(
            startLatitude: source.latitude,
            startLongitude: source.longitude,
            endLatitude: destination.latitude,
            endLongitude: destination.longitude,
            distance: distance,
            expectedTravelTime: expectedTravelTime,
            transportTypeRawValue: transportType.rawValue,
            timestamp: Date(),
            coordinates: coordinateEntries
        )
        
        if let route = routeFromPersistedEntry(entry) {
            cacheQueue.async(flags: .barrier) {
                self.routeCache[cacheKey] = route
            }
            DispatchQueue.main.async {
                self.routes[cacheKey] = route
            }
        }
        
        cacheQueue.async(flags: .barrier) {
            self.persistedRouteEntries[cacheKey] = entry
            let snapshot = self.persistedRouteEntries
            self.persistenceWriteQueue.async {
                Self.savePersistedCache(snapshot, to: self.cacheFileURL)
            }
        }
    }
    
    /// 仅写入交通方式偏好并持久化，不清除该段路线缓存（供 importRoute 使用）
    private func setUserTransportPreferenceOnly(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) {
        let key = routeKey(from: source, to: destination)
        preferencesQueue.async(flags: .barrier) {
            self.userTransportPreferences[key] = transportType.rawValue
            let snapshot = self.userTransportPreferences
            DispatchQueue.global(qos: .utility).async {
                Self.saveTransportPreferences(snapshot, to: self.preferencesFileURL)
            }
        }
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
    ///   - transportType: 交通方式（nil 表示清除所有交通方式的缓存）
    func clearRouteCache(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType? = nil) {
        if let transportType = transportType {
            // 清除特定交通方式的缓存
            let cacheKey = routeKey(from: source, to: destination, transportType: transportType)
            cacheQueue.async(flags: .barrier) {
                self.routeCache.removeValue(forKey: cacheKey)
            }
            removePersistedRoute(for: cacheKey)
            failedRoutesQueue.async(flags: .barrier) {
                self.failedRoutes.removeValue(forKey: cacheKey)
            }
        } else {
            // 清除所有交通方式的缓存（遍历所有可能的交通方式）
            let transportTypes: [MKDirectionsTransportType] = [.automobile, .walking, .transit, .any, Self.airplane, Self.none]
            for type in transportTypes {
                let cacheKey = routeKey(from: source, to: destination, transportType: type)
                cacheQueue.async(flags: .barrier) {
                    self.routeCache.removeValue(forKey: cacheKey)
                }
                removePersistedRoute(for: cacheKey)
                failedRoutesQueue.async(flags: .barrier) {
                    self.failedRoutes.removeValue(forKey: cacheKey)
                }
            }
            print("🗑️ 已清除所有交通方式的路径缓存")
            return
        }
        
        print("🗑️ 已清除路径缓存")
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
        if self == RouteManager.none {
            return "line.diagonal"
        } else if self == RouteManager.airplane {
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
        if self == RouteManager.none {
            return "无"
        } else if self == RouteManager.airplane {
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
        if type == Self.none {
            return "无"
        } else if type == Self.airplane {
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

// MARK: - 与 `RouteCard` 一致的总里程（旅程卡片等复用）
extension RouteManager {
    /// 与 `MapRouteComponents.RouteCard` / `calculateRoutesSelf` 一致：每段均有 `getCachedRoute` 时累加 `footprintDistance`；任一段未命中缓存则退回整条折线的直线距离之和。
    func totalDistanceMetersMatchingRouteCard(destinations: [TravelDestination]) -> CLLocationDistance {
        totalDistanceMetersMatchingRouteCard(destinations: destinations, precomputedRoutes: nil)
    }
    
    /// 与 `JourneyDrawer` → `RouteCard` 一致：优先使用 MapView 同步来的 `precomputedRoutes`（与地图同源）；否则同 `totalDistanceMetersMatchingRouteCard(destinations:)`。
    func totalDistanceMetersMatchingRouteCard(destinations: [TravelDestination], precomputedRoutes: [MKRoute]?) -> CLLocationDistance {
        if let pre = precomputedRoutes, !pre.isEmpty {
            return pre.reduce(0) { $0 + $1.footprintDistance }
        }
        let sorted = destinations.sorted { $0.visitDate < $1.visitDate }
        guard sorted.count >= 2 else { return 0 }
        let coordinates = sorted.map { $0.coordinate }
        var roadSum: CLLocationDistance = 0
        for i in 0..<coordinates.count - 1 {
            guard let route = getCachedRoute(from: coordinates[i], to: coordinates[i + 1]) else {
                return Self.straightLineChainDistance(coordinates: coordinates)
            }
            roadSum += route.footprintDistance
        }
        return roadSum
    }
    
    private static func straightLineChainDistance(coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coordinates.count >= 2 else { return 0 }
        var sum: CLLocationDistance = 0
        for i in 0..<coordinates.count - 1 {
            sum += calculateDistance(from: coordinates[i], to: coordinates[i + 1])
        }
        return sum
    }
    
    /// 与 `RouteCard` 内 `MKDistanceFormatter` 设置一致
    static func formatDistanceForRouteCard(_ distance: CLLocationDistance, languageManager: LanguageManager) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
}

