//
//  TravelDestination.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class TravelDestination {
    var id: UUID = UUID()
    var name: String = ""
    var country: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var visitDate: Date = Date()
    var notes: String = ""
    var photoData: Data?
    // 新增：支持多张照片
    var photoDatas: [Data] = []
    var category: String = "international" // domestic or international
    var isFavorite: Bool = false
    var trip: TravelTrip? // 所属的旅行组
    
    init(
        name: String,
        country: String,
        latitude: Double,
        longitude: Double,
        visitDate: Date = Date(),
        notes: String = "",
        photoData: Data? = nil,
        photoDatas: [Data] = [],
        category: String = "international",
        isFavorite: Bool = false
    ) {
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.visitDate = visitDate
        self.notes = notes
        self.photoData = photoData
        self.photoDatas = photoDatas
        self.category = category
        self.isFavorite = isFavorite
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // 获取本地化的分类显示名称
    var localizedCategory: String {
        switch category {
        case "domestic":
            return "domestic".localized
        case "international":
            return "international".localized
        case "国内":
            return "domestic".localized
        case "国外":
            return "international".localized
        default:
            return category
        }
    }
    
    // 获取标准化的分类键值（用于筛选）
    var normalizedCategory: String {
        switch category {
        case "domestic", "国内":
            return "domestic"
        case "international", "国外":
            return "international"
        default:
            return category
        }
    }
    
    // 数据迁移：将本地化字符串转换为标准格式
    func migrateCategoryToStandard() {
        if category == "国内" {
            category = "domestic"
        } else if category == "国外" {
            category = "international"
        }
    }
}

