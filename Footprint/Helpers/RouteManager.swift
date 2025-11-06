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

/// 路线管理器：用于计算地点之间的实际道路路线
class RouteManager: ObservableObject {
    static let shared = RouteManager()
    
    // 缓存已计算的路线，key 为起点和终点的坐标组合
    private var routeCache: [String: MKRoute] = [:]
    
    // 存储当前计算出的所有路线
    @Published var routes: [String: MKRoute] = [:]
    
    private let cacheQueue = DispatchQueue(label: "com.footprint.route.cache", attributes: .concurrent)
    
    private init() {}
    
    /// 计算两个地点之间的路线
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    ///   - completion: 完成回调，返回计算出的路线或 nil
    func calculateRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        completion: @escaping (MKRoute?) -> Void
    ) {
        let cacheKey = routeKey(from: source, to: destination)
        
        // 检查缓存（线程安全）
        cacheQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            var cachedRoute: MKRoute?
            self.cacheQueue.sync {
                cachedRoute = self.routeCache[cacheKey]
            }
            
            if let cachedRoute = cachedRoute {
                DispatchQueue.main.async {
                    completion(cachedRoute)
                }
                return
            }
            
            // 创建起点和终点
            let sourcePlacemark = MKPlacemark(coordinate: source)
            let destinationPlacemark = MKPlacemark(coordinate: destination)
            
            let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
            let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
            
            // 创建路线请求
            let request = MKDirections.Request()
            request.source = sourceMapItem
            request.destination = destinationMapItem
            request.transportType = .automobile  // 使用汽车路线（也可以改为 .any）
            
            // 计算路线
            let directions = MKDirections(request: request)
            directions.calculate { [weak self] response, error in
                if let error = error {
                    print("⚠️ 路线计算失败: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                guard let route = response?.routes.first else {
                    print("⚠️ 未找到路线")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                // 缓存路线（线程安全）
                if let self = self {
                    self.cacheQueue.async(flags: .barrier) {
                        self.routeCache[cacheKey] = route
                    }
                    
                    // 更新 published 属性在主线程
                    DispatchQueue.main.async {
                        self.routes[cacheKey] = route
                        completion(route)
                    }
                }
            }
        }
    }
    
    /// 批量计算多个连续地点之间的路线
    /// - Parameters:
    ///   - destinations: 按顺序排列的地点坐标数组
    ///   - completion: 完成回调，返回所有计算出的路线
    func calculateRoutes(
        for destinations: [CLLocationCoordinate2D],
        completion: @escaping ([MKRoute]) -> Void
    ) {
        guard destinations.count >= 2 else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var routes: [MKRoute] = []
        let queue = DispatchQueue(label: "com.footprint.route.calculation", attributes: .concurrent)
        
        // 计算每两个连续地点之间的路线
        for i in 0..<destinations.count - 1 {
            group.enter()
            let source = destinations[i]
            let destination = destinations[i + 1]
            
            queue.async {
                self.calculateRoute(from: source, to: destination) { route in
                    if let route = route {
                        routes.append(route)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(routes)
        }
    }
    
    /// 生成缓存的 key
    private func routeKey(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> String {
        return "\(source.latitude),\(source.longitude)->\(destination.latitude),\(destination.longitude)"
    }
}

