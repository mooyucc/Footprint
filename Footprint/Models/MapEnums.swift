//
//  MapEnums.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的地图相关枚举
//

import Foundation
import SwiftUI
import MapKit

// MARK: - 类型别名
/// MapKit 的 MapStyle 类型别名，避免与自定义 MapStyle 枚举冲突
typealias SwiftUIMapStyle = MapKit.MapStyle

// MARK: - 地图样式枚举
enum MapStyle: String, CaseIterable {
    case muted = "muted"
    case standard = "standard"
    case hybrid = "hybrid"
    case imagery = "imagery"
    
    var displayName: String {
        switch self {
        case .standard:
            return "map_style_standard"
        case .muted:
            return "map_style_muted"
        case .hybrid:
            return "map_style_hybrid"
        case .imagery:
            return "map_style_imagery"
        }
    }
    
    var iconName: String {
        switch self {
        case .standard:
            return "map"
        case .muted:
            return "map.fill"
        case .hybrid:
            return "globe.americas"
        case .imagery:
            return "camera"
        }
    }
    
    func toMapKitStyle() -> SwiftUIMapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .muted:
            return .standard(elevation: .flat, emphasis: .muted)  // 静音模式：道路不明显
        case .hybrid:
            return .hybrid(elevation: .realistic)  // 混合地图：卫星图像+标注，支持地球视图
        case .imagery:
            return .imagery(elevation: .realistic) // 卫星图像：纯卫星图像，无标注
        }
    }
}

// MARK: - 缩放级别枚举
/// 6个明确的缩放级别定义
enum ZoomLevel: Int, CaseIterable {
    case world = 1      // 世界/大洲级别
    case country = 2   // 国家级别  
    case province = 3  // 省级别
    case city = 4      // 市级别
    case district = 5  // 区级别
    case street = 6    // 街道级别
    
    var distance: Double {
        switch self {
        case .world: return 180000     // 180km
        case .country: return 90000    // 90km
        case .province: return 45000   // 45km
        case .city: return 12000       // 12km
        case .district: return 3000    // 3km
        case .street: return 0         // 不聚合
        }
    }
    
    var description: String {
        switch self {
        case .world: return "世界/大洲"
        case .country: return "国家"
        case .province: return "省份"
        case .city: return "城市"
        case .district: return "区域"
        case .street: return "街道"
        }
    }
}

// MARK: - 发现地图模式枚举
/// 发现地图模式：我的足迹 / 发现地图（公共）
enum DiscoverMapMode: String, CaseIterable {
    case myFootprints
    case discover
    
    /// 用于本地化显示的文案 key
    var titleKey: String {
        switch self {
        case .myFootprints:
            return "map_mode_my_footprints"
        case .discover:
            return "map_mode_discover"
        }
    }
}

// MARK: - 毛玻璃效果样式枚举
enum GlassEffectStyle {
    case regular
    case thin
    case thick
}
