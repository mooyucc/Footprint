//
//  ShareLayoutModels.swift
//  Footprint
//
//  Created on 2026/01/26.
//  分享版面类型枚举，从 TripImageGenerator.swift 提取
//

import Foundation
import SwiftUI
import UIKit

// MARK: - 分享相关数据模型
struct TripShareItem: Identifiable {
    let id = UUID()
    let text: String
    let image: UIImage?
    let url: URL?
    
    init(text: String, image: UIImage? = nil, url: URL? = nil) {
        self.text = text
        self.image = image
        self.url = url
    }
}

// MARK: - 旅程分享版面类型枚举
enum TripShareLayout: String, CaseIterable, Identifiable {
    case list = "list"
    case extendedGrid = "extendedGrid"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .list:
            return "trip_share_layout_list".localized
        case .extendedGrid:
            return "trip_share_layout_extended_grid".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .extendedGrid:
            return "square.grid.3x3.square.badge.ellipsis"
        }
    }
    
    var description: String {
        switch self {
        case .list:
            return "trip_share_layout_list_desc".localized
        case .extendedGrid:
            return "trip_share_layout_extended_grid_desc".localized
        }
    }
}

// MARK: - 地点分享版面类型枚举
enum DestinationShareLayout: String, CaseIterable, Identifiable {
    case classic = "classic"           // 经典版面（原有样式）
    case posterPromo = "posterPromo"  // 宣传海报样式（大图+小图）
    case posterCollage = "posterCollage" // 拼贴海报样式（3x3网格）
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .classic:
            return "经典版面"
        case .posterPromo:
            return "宣传海报"
        case .posterCollage:
            return "拼贴海报"
        }
    }
    
    var iconName: String {
        switch self {
        case .classic:
            return "rectangle.portrait"
        case .posterPromo:
            return "photo.on.rectangle.angled"
        case .posterCollage:
            return "square.grid.3x3"
        }
    }
    
    var description: String {
        switch self {
        case .classic:
            return "传统的垂直布局，适合展示详细信息"
        case .posterPromo:
            return "突出主图，底部配小图，适合宣传推广"
        case .posterCollage:
            return "3x3网格拼贴，展示多张照片，适合旅行记录"
        }
    }
}
