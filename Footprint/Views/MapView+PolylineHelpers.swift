//
//  MapView+PolylineHelpers.swift
//  Footprint
//
//  从 MapView.swift 拆分（编译加速）
//

import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import Combine
import AudioToolbox
import UIKit
import PhotosUI
import Photos
import ImageIO
import Contacts

extension MapView {
    // 计算路线多边形的中点坐标（按距离计算，而不是简单的点索引）
    func midpointOfPolyline(_ polyline: MKPolyline) -> CLLocationCoordinate2D? {
        let pointCount = polyline.pointCount
        guard pointCount > 0 else { return nil }
        
        // 如果只有两个点（如飞机模式的直线），直接计算两点中点
        if pointCount == 2 {
            let points = polyline.points()
            let start = points[0].coordinate
            let end = points[1].coordinate
            return midpointOfLine(from: start, to: end)
        }
        
        // 对于多点路线，计算总距离，然后找到中点位置
        let points = polyline.points()
        var totalDistance: CLLocationDistance = 0
        var segmentDistances: [CLLocationDistance] = []
        
        // 计算每段的距离和总距离
        for i in 0..<pointCount - 1 {
            let start = CLLocation(latitude: points[i].coordinate.latitude, longitude: points[i].coordinate.longitude)
            let end = CLLocation(latitude: points[i + 1].coordinate.latitude, longitude: points[i + 1].coordinate.longitude)
            let segmentDistance = start.distance(from: end)
            segmentDistances.append(segmentDistance)
            totalDistance += segmentDistance
        }
        
        // 找到中点位置（总距离的一半）
        let halfDistance = totalDistance / 2
        var accumulatedDistance: CLLocationDistance = 0
        
        for i in 0..<segmentDistances.count {
            let segmentDistance = segmentDistances[i]
            if accumulatedDistance + segmentDistance >= halfDistance {
                // 中点在这个段内
                let remainingDistance = halfDistance - accumulatedDistance
                let ratio = remainingDistance / segmentDistance
                
                let start = points[i].coordinate
                let end = points[i + 1].coordinate
                
                // 在起点和终点之间按比例插值
                return CLLocationCoordinate2D(
                    latitude: start.latitude + (end.latitude - start.latitude) * ratio,
                    longitude: start.longitude + (end.longitude - start.longitude) * ratio
                )
            }
            accumulatedDistance += segmentDistance
        }
        
        // 如果没找到（理论上不应该发生），返回中间点
        let midIndex = pointCount / 2
        guard midIndex < pointCount else { return nil }
        return points[midIndex].coordinate
    }
    
    // 计算两点连线的中点
    func midpointOfLine(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        return CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
    }
    
    // 检查两个地点是否在同一个聚合中
    func areDestinationsInSameCluster(_ destination1: TravelDestination, _ destination2: TravelDestination) -> Bool {
        // 遍历所有聚合，检查两个地点是否在同一个聚合中
        for cluster in clusterAnnotations {
            let destinationIds = Set(cluster.destinations.map { $0.id })
            if destinationIds.contains(destination1.id) && destinationIds.contains(destination2.id) {
                return true
            }
        }
        return false
    }
    
    // 计算占位线应该显示的交通方式
    func calculatePlaceholderTransportType(
        from source: TravelDestination,
        to destination: TravelDestination
    ) -> MKDirectionsTransportType {
        // 获取用户选择的交通方式，如果没有则使用默认机动车
        let userTransportType = routeManager.getUserTransportType(
            from: source.coordinate,
            to: destination.coordinate
        )
        
        // 优先使用用户选择，否则使用默认机动车
        return userTransportType ?? .automobile
    }
    
    // 占位线绘制视图（提取复杂逻辑，避免类型检查超时）
    @MapContentBuilder
    func placeholderRouteContent(
        for source: TravelDestination,
        destination: TravelDestination,
        transportType: MKDirectionsTransportType,
        tripId: UUID,
        visibleDestinations: [TravelDestination]
    ) -> some MapContent {
        // 根据交通方式选择虚线颜色
        let placeholderColor = routeColor(for: transportType)
        
        // 计算直线距离
        let distance = source.coordinate.distance(to: destination.coordinate)
        
        // 占位虚线（算完后单段 morph 替换）
        MapPolyline(coordinates: [source.coordinate, destination.coordinate])
            .stroke(
                placeholderColor.opacity(0.62),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [8, 6]
                )
            )
        
        // 显示直线距离标注（带交通方式选择，显示用户选择的交通方式图标）
        if let midpoint = midpointOfLine(from: source.coordinate, to: destination.coordinate) {
            Annotation("", coordinate: midpoint) {
                RouteDistanceLabel(
                    distance: distance,
                    transportType: transportType, // 显示用户选择的交通方式图标
                    source: source.coordinate,
                    destination: destination.coordinate,
                    onTransportTypeChange: { newType in
                        // 保存用户选择并重新计算路线
                        routeManager.setUserTransportType(
                            from: source.coordinate,
                            to: destination.coordinate,
                            transportType: newType
                        )
                        // 清除该旅程的路线缓存，强制重新计算（使用整趟行程坐标，避免按天筛选时只更新部分路线）
                        tripRoutes.removeValue(forKey: tripId)
                        syncTripRoutesToSharedStore()
                        let coordinates = sortedDestinations(for: tripId).map { $0.coordinate }
                        Task {
                            await calculateRoutesForTrip(tripId: tripId, coordinates: coordinates, incremental: false)
                        }
                    }
                )
            }
        }
    }
}
