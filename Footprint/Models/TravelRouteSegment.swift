//
//  TravelRouteSegment.swift
//  Footprint
//
//  Created by AI Assistant on 2026/03/04.
//

import Foundation
import SwiftData

/// 旅程中两地之间的一段路线（用于 iCloud 同步交通方式与路线 polyline）
@Model
final class TravelRouteSegment {
    var id: UUID = UUID()
    
    /// 关联的旅程（可选，便于按旅程查询）
    var trip: TravelTrip?
    
    /// 起点 / 终点 坐标
    var startLatitude: Double = 0
    var startLongitude: Double = 0
    var endLatitude: Double = 0
    var endLongitude: Double = 0
    
    /// 交通方式 rawValue（与 MKDirectionsTransportType.rawValue 对齐）
    var transportTypeRawValue: UInt = 0
    
    /// 路线距离（米）
    var distance: Double = 0
    
    /// 预计时长（秒）
    var expectedTravelTime: Double = 0
    
    /// polyline 坐标集合序列化为 Data（内部 JSON: [[lat, lon], ...]）
    var coordinatesData: Data?
    
    /// 最近更新时间（用于调试和潜在合并策略）
    var updatedAt: Date = Date()
    
    init(
        trip: TravelTrip? = nil,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        transportTypeRawValue: UInt,
        distance: Double,
        expectedTravelTime: Double,
        coordinatesData: Data?,
        updatedAt: Date = Date()
    ) {
        self.trip = trip
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.transportTypeRawValue = transportTypeRawValue
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.coordinatesData = coordinatesData
        self.updatedAt = updatedAt
    }
}

