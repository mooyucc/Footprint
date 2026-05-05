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
    case modernPoster = "modernPoster"   // 现代海报风格版面
    case circlePoster = "circlePoster"   // 极简海报版面（圆形构图实现）
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .classic:
            return "destination_share_layout_classic".localized
        case .modernPoster:
            return "destination_share_layout_modern_poster".localized
        case .circlePoster:
            return "destination_share_layout_circle_poster".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .classic:
            return "rectangle.portrait"
        case .modernPoster:
            return "chart.bar.fill"
        case .circlePoster:
            return "circle.lefthalf.filled"
        }
    }
    
    var description: String {
        switch self {
        case .classic:
            return "destination_share_layout_classic_desc".localized
        case .modernPoster:
            return "destination_share_layout_modern_poster_desc".localized
        case .circlePoster:
            return "destination_share_layout_circle_poster_desc".localized
        }
    }
}
