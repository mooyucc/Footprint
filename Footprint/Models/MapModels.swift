//
//  MapModels.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的地图相关数据模型
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - 地图聚类（后台线程安全）

struct MapClusterPoint: Sendable {
    let id: UUID
    let latitude: Double
    let longitude: Double
}

enum MapClusterEngine {
    /// 地图上最多渲染的标注数（单点或聚合点）
    static let maxVisibleClusters = 50

    /// 按距离聚合，超出 `maxClusters` 时逐步加大半径直至 ≤ maxClusters（可在后台线程调用）
    static func clusterGroups(
        points: [MapClusterPoint],
        distance: Double,
        maxClusters: Int = maxVisibleClusters
    ) -> [[UUID]] {
        guard !points.isEmpty else { return [] }

        if distance <= 0 {
            if points.count <= maxClusters {
                return points.map { [$0.id] }
            }
            return points.prefix(maxClusters).map { [$0.id] }
        }

        var currentDistance = distance
        var groups = clusterGroupsAtDistance(points: points, distance: currentDistance)

        while groups.count > maxClusters && currentDistance < 500_000 {
            currentDistance *= 1.5
            groups = clusterGroupsAtDistance(points: points, distance: currentDistance)
        }

        if groups.count > maxClusters {
            groups = Array(groups.prefix(maxClusters))
        }
        return groups
    }

    private static func clusterGroupsAtDistance(points: [MapClusterPoint], distance: Double) -> [[UUID]] {
        var clusters: [[UUID]] = []
        var processed = Set<UUID>()
        let sorted = points.sorted { $0.latitude < $1.latitude }
        let latitudeThreshold = distance / 111_000.0

        for point in sorted {
            if processed.contains(point.id) { continue }

            var group = [point.id]
            processed.insert(point.id)

            for other in sorted {
                if processed.contains(other.id) { continue }
                if abs(point.latitude - other.latitude) > latitudeThreshold { continue }

                let dist = coordinateDistance(
                    lat1: point.latitude, lon1: point.longitude,
                    lat2: other.latitude, lon2: other.longitude
                )
                if dist < distance {
                    group.append(other.id)
                    processed.insert(other.id)
                }
            }
            clusters.append(group)
        }
        return clusters
    }

    private static func coordinateDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        return location1.distance(from: location2)
    }
}

// MARK: - 显示类型枚举
/// 地图标注的显示类型，用于三级显示策略
enum AnnotationDisplayType: Equatable {
    case detailedCard        // 详细卡片（完整信息）
    case simplifiedAvatar    // 简化头像圆圈（仅显示头像）
    case clusteredCard       // 聚合卡片（多个地点聚合）
    case hidden              // 隐藏（不显示）
}

// MARK: - 聚合标注数据模型
struct ClusterAnnotation: Identifiable, Equatable {
    let destinations: [TravelDestination]
    let displayType: AnnotationDisplayType  // 显示类型
    
    // 使用稳定的 ID：基于聚合中所有地点的 ID 生成
    var id: String {
        destinations
            .map { $0.id.uuidString }
            .sorted()
            .joined(separator: "-")
    }
    
    var coordinate: CLLocationCoordinate2D {
        let avgLat = destinations.map { $0.coordinate.latitude }.reduce(0, +) / Double(destinations.count)
        let avgLon = destinations.map { $0.coordinate.longitude }.reduce(0, +) / Double(destinations.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
    
    var title: String {
        destinations.count == 1 ? destinations[0].name : "\(destinations.count) " + "locations_count".localized
    }
    
    // 实现 Equatable 协议
    static func == (lhs: ClusterAnnotation, rhs: ClusterAnnotation) -> Bool {
        lhs.id == rhs.id && lhs.displayType == rhs.displayType
    }
    
    // 便利初始化方法（向后兼容）
    init(destinations: [TravelDestination], displayType: AnnotationDisplayType = .detailedCard) {
        self.destinations = destinations
        self.displayType = displayType
    }
}

// MARK: - 滚动偏移信息
struct ScrollOffsetInfo: Equatable {
    let tripId: UUID
    let offset: CGFloat
}

// MARK: - 滚动偏移偏好键
/// PreferenceKey 用于传递滚动偏移信息
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [ScrollOffsetInfo] = []
    
    static func reduce(value: inout [ScrollOffsetInfo], nextValue: () -> [ScrollOffsetInfo]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - POI 加载任务持有者
/// 任务持有者类：用于在SwiftUI View中存储DispatchWorkItem
class POILoadingTaskHolder {
    var task: DispatchWorkItem?
}
