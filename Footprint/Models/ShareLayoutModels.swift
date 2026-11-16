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
    case extendedGrid = "extendedGrid"
    case timeline = "timeline"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .extendedGrid:
            return "trip_share_layout_extended_grid".localized
        case .timeline:
            return "trip_share_layout_timeline".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .extendedGrid:
            return "square.grid.3x3.square.badge.ellipsis"
        case .timeline:
            return "timeline.selection"
        }
    }
    
    var description: String {
        switch self {
        case .extendedGrid:
            return "trip_share_layout_extended_grid_desc".localized
        case .timeline:
            return "trip_share_layout_timeline_desc".localized
        }
    }
    
    /// 年份分享暂不支持日程海报（按旅程日叙事）
    var supportsYearShare: Bool {
        switch self {
        case .extendedGrid:
            return true
        case .timeline:
            return false
        }
    }
}

// MARK: - 地点分享画布比例（社媒友好）
enum DestinationShareAspectRatio: String, CaseIterable, Identifiable {
    case square11 = "square11"       // 1:1 方形（画廊卡推荐）
    case portrait34 = "portrait34"   // 3:4 竖图
    case story916 = "story916"       // 9:16 故事/全屏
    
    var id: String { rawValue }
    
    /// 导出逻辑尺寸（点）；配合 scale 得到像素
    var canvasSize: CGSize {
        switch self {
        case .square11:
            return CGSize(width: 1080, height: 1080)
        case .portrait34:
            return CGSize(width: 1080, height: 1440)
        case .story916:
            return CGSize(width: 1080, height: 1920)
        }
    }
    
    var displayName: String {
        switch self {
        case .square11:
            return "destination_share_aspect_square".localized
        case .portrait34:
            return "destination_share_aspect_portrait".localized
        case .story916:
            return "destination_share_aspect_story".localized
        }
    }
    
    var shortLabel: String {
        switch self {
        case .square11:
            return "1:1"
        case .portrait34:
            return "3:4"
        case .story916:
            return "9:16"
        }
    }
}

// MARK: - 地点分享版面类型枚举（仅社媒海报）
enum DestinationShareLayout: String, CaseIterable, Identifiable {
    case photoPoster = "photoPoster"     // 大图打卡（默认）
    case gallerySide = "gallerySide"     // 侧栏画廊：左竖图 + 右文案
    case galleryStack = "galleryStack"   // 上下画廊：上横图 + 下文案
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .photoPoster:
            return "destination_share_layout_photo_poster".localized
        case .gallerySide:
            return "destination_share_layout_gallery_side".localized
        case .galleryStack:
            return "destination_share_layout_gallery_stack".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .photoPoster:
            return "photo.fill"
        case .gallerySide:
            return "rectangle.split.2x1"
        case .galleryStack:
            return "rectangle.split.1x2"
        }
    }
    
    var description: String {
        switch self {
        case .photoPoster:
            return "destination_share_layout_photo_poster_desc".localized
        case .gallerySide:
            return "destination_share_layout_gallery_side_desc".localized
        case .galleryStack:
            return "destination_share_layout_gallery_stack_desc".localized
        }
    }
    
    /// 该版式适用的画布比例（用于尺寸筛选）
    var supportedAspects: [DestinationShareAspectRatio] {
        switch self {
        case .photoPoster:
            return DestinationShareAspectRatio.allCases
        case .gallerySide, .galleryStack:
            return [.square11]
        }
    }
    
    func supports(_ aspect: DestinationShareAspectRatio) -> Bool {
        supportedAspects.contains(aspect)
    }
}
