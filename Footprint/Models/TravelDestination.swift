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
    var province: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var visitDate: Date = Date()
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    @Attribute(.externalStorage) var photoThumbnailData: Data?
    // 多图：外置，避免全表 @Query 把二进制一并装进主库行
    @Attribute(.externalStorage) var photoDatas: [Data] = []
    @Attribute(.externalStorage) var photoThumbnailDatas: [Data] = []
    // 新增：支持视频（限制1段，10秒以内）
    @Attribute(.externalStorage) var videoData: Data?
    var category: String = "international" // domestic or international
    var type: String = "" // 地点类型：自然奇观、城市风貌、历史人文、美食盛宴、休闲娱乐、户外冒险、文艺打卡
    var isFavorite: Bool = false
    var trip: TravelTrip? // 所属的旅行组
    
    init(
        name: String,
        country: String,
        province: String = "",
        latitude: Double,
        longitude: Double,
        visitDate: Date = Date(),
        notes: String = "",
        photoData: Data? = nil,
        photoDatas: [Data] = [],
        photoThumbnailData: Data? = nil,
        photoThumbnailDatas: [Data] = [],
        videoData: Data? = nil,
        category: String = "international",
        type: String = "",
        isFavorite: Bool = false
    ) {
        self.name = name
        self.country = country
        self.province = province
        self.latitude = latitude
        self.longitude = longitude
        self.visitDate = visitDate
        self.notes = notes
        self.photoData = photoData
        self.photoDatas = photoDatas
        self.photoThumbnailData = photoThumbnailData
        self.photoThumbnailDatas = photoThumbnailDatas
        self.videoData = videoData
        self.category = category
        self.type = type
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
    
    // 获取本地化的类型显示名称
    var localizedType: String {
        guard !type.isEmpty else { return "" }
        let typeKeyMap: [String: String] = [
            "natural_wonder": "destination_type_natural_wonder",
            "urban_landscape": "destination_type_urban_landscape",
            "historical_culture": "destination_type_historical_culture",
            "food_feast": "destination_type_food_feast",
            "leisure_entertainment": "destination_type_leisure_entertainment",
            "outdoor_adventure": "destination_type_outdoor_adventure",
            "artistic_checkin": "destination_type_artistic_checkin"
        ]
        if let localizedKey = typeKeyMap[type] {
            return localizedKey.localized
        }
        return type
    }
    
    /// 地点类型筛选选项（与编辑页一致，用于统计/列表筛选）
    static var placeTypeFilterOptions: [(key: String, localizedKey: String)] {
        [
            ("natural_wonder", "destination_type_natural_wonder"),
            ("urban_landscape", "destination_type_urban_landscape"),
            ("historical_culture", "destination_type_historical_culture"),
            ("food_feast", "destination_type_food_feast"),
            ("leisure_entertainment", "destination_type_leisure_entertainment"),
            ("outdoor_adventure", "destination_type_outdoor_adventure"),
            ("artistic_checkin", "destination_type_artistic_checkin")
        ]
    }
}

