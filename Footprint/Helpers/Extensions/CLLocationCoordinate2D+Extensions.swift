//
//  CLLocationCoordinate2D+Extensions.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  CLLocationCoordinate2D 扩展：距离计算和 Equatable 支持
//

import Foundation
import CoreLocation

// MARK: - 距离计算扩展
extension CLLocationCoordinate2D {
    /// 计算到另一个坐标的距离（米）
    /// - Parameter other: 目标坐标
    /// - Returns: 距离（米）
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Equatable 协议支持
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
