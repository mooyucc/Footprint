//
//  CoordinateConverter.swift
//  Footprint
//
//  Created on 2025/01/27.
//  坐标转换工具：WGS84 <-> GCJ02 (火星坐标)
//

import Foundation
import CoreLocation

/// 坐标转换工具
/// 解决国内地图坐标系统差异问题：
/// - GPS (CoreLocation): WGS84 坐标系
/// - 中国地图 (高德/百度): GCJ02 坐标系（火星坐标）
/// 两者之间存在约50-300米偏移
struct CoordinateConverter {
    
    // MARK: - WGS84 to GCJ02 转换常量
    private static let a: Double = 6378245.0              // 长半轴
    private static let ee: Double = 0.00669342162296594323 // 偏心率平方
    
    // MARK: - 坐标转换
    
    /// 将WGS84坐标转换为GCJ02坐标（火星坐标）
    /// - Parameter wgs: WGS84坐标
    /// - Returns: GCJ02坐标
    static func wgs84ToGCJ02(_ wgs: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境外
        if isOutOfChina(wgs) {
            return wgs // 中国境外，无需转换
        }
        
        var dLat = transformLat(wgs.longitude - 105.0, wgs.latitude - 35.0)
        var dLon = transformLon(wgs.longitude - 105.0, wgs.latitude - 35.0)
        
        let radLat = wgs.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        
        let mgLat = wgs.latitude + dLat
        let mgLon = wgs.longitude + dLon
        
        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }
    
    /// 将GCJ02坐标转换为WGS84坐标
    /// - Parameter gcj: GCJ02坐标
    /// - Returns: WGS84坐标
    static func gcj02ToWGS84(_ gcj: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if isOutOfChina(gcj) {
            return gcj
        }
        
        var dLat = transformLat(gcj.longitude - 105.0, gcj.latitude - 35.0)
        var dLon = transformLon(gcj.longitude - 105.0, gcj.latitude - 35.0)
        
        let radLat = gcj.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        
        let mgLat = gcj.latitude + dLat
        let mgLon = gcj.longitude + dLon
        
        return CLLocationCoordinate2D(latitude: gcj.latitude * 2 - mgLat, longitude: gcj.longitude * 2 - mgLon)
    }
    
    // MARK: - 辅助方法
    
    /// 判断坐标是否在中国境外（用于决定是否对 WGS84 做 GCJ-02 偏移）
    ///
    /// **说明**：网上常见的「粗经纬矩形」会把马来西亚、菲律宾大部、泰国南部等划进矩形内，
    /// 若不做额外排除会对这些地区误套 GCJ，产生数百米级偏移（例如沙巴亚庇）。
    /// - 中国大陆（含海南陆地）、港澳等地区：矩形内且未被下方规则排除 → 需 GCJ 与内地地图对齐。
    /// - 台湾岛：国际版 Apple 地图等为 WGS84，不应叠加 GCJ。
    /// - 北纬 18° 以南且在粗矩形内：多为东南亚等，使用 WGS84。
    static func isOutOfChina(_ coord: CLLocationCoordinate2D) -> Bool {
        let lat = coord.latitude
        let lon = coord.longitude
        
        // 快速排除：完全落在常见「中国周边」包络盒之外
        if lat < 0.8293 || lat > 55.8271 || lon < 72.004 || lon > 137.8347 {
            return true
        }
        
        // 粗矩形南侧包含了东南亚多国 —— 一律视为境外（WGS84）
        // 海南陆地最南端约北纬 18°10′ 一线；此阈值以下旅行场景按境外处理即可。
        if lat < 18.0 {
            return true
        }
        
        // 台湾岛周边（国际底图普遍为 WGS84；叠加 GCJ 会整体偏移）
        if lat >= 21.2 && lat <= 25.9 && lon >= 119.0 && lon <= 122.2 {
            return true
        }
        
        return false
    }
    
    /// 判断坐标是否在中国境内
    /// - Parameter coordinate: 要判断的坐标
    /// - Returns: 如果坐标在中国境内返回 true，否则返回 false
    static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return !isOutOfChina(coordinate)
    }
    
    /// 纬度转换
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    /// 经度转换
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}

