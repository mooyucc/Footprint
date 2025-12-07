//
//  GeocodeService.swift
//  Footprint
//
//  Created on 2025/12/05.
//  统一的地理编码服务接口和工厂方法
//

import Foundation
import CoreLocation

/// 统一的地理编码服务协议
protocol GeocodeServiceProtocol {
    /// 反向地理编码：根据坐标获取地址和POI信息
    /// - Parameters:
    ///   - coordinate: 坐标
    ///   - completion: 完成回调
    func reverseGeocode(
        coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<GeocodeResult, Error>) -> Void
    )
    
    /// 搜索周边POI
    /// - Parameters:
    ///   - coordinate: 中心点坐标
    ///   - radius: 搜索半径（米）
    ///   - completion: 完成回调
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
    /// 根据坐标自动选择合适的地理编码服务
    /// - Parameter coordinate: 坐标
    /// - Returns: 地理编码服务实例
    static func createService(for coordinate: CLLocationCoordinate2D) -> GeocodeServiceProtocol {
        let isInChina = CoordinateConverter.isInChina(coordinate)
        
        if isInChina {
            return AMapGeocodeService.shared
        } else {
            return AppleGeocodeService.shared
        }
    }
    
    /// 获取默认服务（用于测试或特殊场景）
    /// - Parameter source: 指定的服务源
    /// - Returns: 地理编码服务实例
    static func createService(source: GeocodeResult.GeocodeSource) -> GeocodeServiceProtocol {
        switch source {
        case .amap:
            return AMapGeocodeService.shared
        case .apple:
            return AppleGeocodeService.shared
        }
    }
}

/// 地理编码错误类型
enum GeocodeError: LocalizedError {
    case invalidCoordinate
    case networkError(String)
    case apiError(String)
    case noData
    case invalidResponse
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidCoordinate:
            return "无效的坐标"
        case .networkError(let message):
            return "网络错误：\(message)"
        case .apiError(let message):
            return "API错误：\(message)"
        case .noData:
            return "未收到数据"
        case .invalidResponse:
            return "无效的响应"
        case .cancelled:
            return "请求已取消"
        }
    }
}

