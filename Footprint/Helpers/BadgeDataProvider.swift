//
//  BadgeDataProvider.swift
//  Footprint
//
//  Created on 2025/11/29.
//

import Foundation
import SwiftUI

/// 勋章类型
enum BadgeType {
    case country
    case province
}

/// 国家勋章数据模型
struct CountryBadge: Identifiable {
    let id: String
    let country: CountryManager.Country
    let imageName: String
    
    /// 本地化的显示名称（根据当前语言环境动态返回）
    var displayName: String {
        let countryManager = CountryManager.shared
        return countryManager.getLocalizedCountryName(for: country)
    }
    
    init(country: CountryManager.Country) {
        self.id = country.rawValue
        self.country = country
        self.imageName = BadgeManager.shared.getCountryBadgeImageName(for: country)
    }
}

/// 省份勋章数据模型
struct ProvinceBadge: Identifiable {
    let id: String
    let provinceName: String
    let imageName: String
    let displayName: String
    
    init(provinceName: String) {
        self.id = provinceName
        self.provinceName = provinceName
        let normalized = BadgeManager.shared.normalizeProvinceName(provinceName)
        self.imageName = BadgeManager.shared.getProvinceBadgeImageName(for: normalized)
        self.displayName = normalized
    }
}

/// 勋章数据提供者
class BadgeDataProvider {
    /// 获取所有国家勋章列表（基于 CountryManager）
    static func getAllCountryBadges() -> [CountryBadge] {
        return CountryManager.Country.allCases.map { CountryBadge(country: $0) }
    }
    
    /// 获取所有省份勋章列表（中国34个省级行政区，包括31个省/自治区/直辖市和3个特别行政区）
    static func getAllProvinceBadges() -> [ProvinceBadge] {
        let provinces = [
            "北京市", "天津市", "河北省", "山西省", "内蒙古自治区",
            "辽宁省", "吉林省", "黑龙江省", "上海市", "江苏省",
            "浙江省", "安徽省", "福建省", "江西省", "山东省",
            "河南省", "湖北省", "湖南省", "广东省", "广西壮族自治区",
            "海南省", "重庆市", "四川省", "贵州省", "云南省",
            "西藏自治区", "陕西省", "甘肃省", "青海省", "宁夏回族自治区",
            "新疆维吾尔自治区",
            "香港特别行政区", "澳门特别行政区", "台湾省"
        ]
        
        return provinces.map { ProvinceBadge(provinceName: $0) }
    }
}

