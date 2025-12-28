//
//  UserProfileOptions.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import Foundation

/// 用户属性选项本地化管理器
struct UserProfileOptions {
    // MARK: - 身份标签选项键值（使用英文作为存储键）
    static let personaKeys = [
        "traveler", "hiker", "photographer", "designer", 
        "foodie", "techie", "custom", "prefer_not_to_say"
    ]
    
    static func localizedPersonaOptions() -> [String] {
        return personaKeys.map { "persona_option_\($0)".localized }
    }
    
    static func personaKey(for localizedValue: String) -> String {
        for key in personaKeys {
            if "persona_option_\(key)".localized == localizedValue {
                return key
            }
        }
        // 如果是自定义值（直接的字符串），返回它
        return localizedValue
    }
    
    static func personaLocalizedValue(for storedValue: String) -> String {
        // 先尝试作为键查找
        if personaKeys.contains(storedValue) {
            return localizedPersona(for: storedValue)
        }
        
        // 处理旧数据（中文或其他语言的本地化值）
        let oldToNewMap: [String: String] = [
            "旅行家": "traveler",
            "徒步爱好者": "hiker",
            "摄影师": "photographer",
            "设计师": "designer",
            "美食家": "foodie",
            "数码玩家": "techie",
            "自定义": "custom",
            "不愿透露": "prefer_not_to_say"
        ]
        
        let normalizedKey = oldToNewMap[storedValue] ?? storedValue
        
        // 如果映射到了键值，返回当前语言的本地化值
        if personaKeys.contains(normalizedKey) {
            return localizedPersona(for: normalizedKey)
        }
        
        // 否则作为自定义值返回
        return storedValue
    }
    
    static func localizedPersona(for key: String) -> String {
        if personaKeys.contains(key) {
            return "persona_option_\(key)".localized
        }
        return key // 自定义值直接返回
    }
    
    // MARK: - 性别选项键值
    static let genderKeys = ["male", "female", "other", "prefer_not_to_say"]
    
    static func localizedGenderOptions() -> [String] {
        return genderKeys.map { "gender_option_\($0)".localized }
    }
    
    static func genderKey(for localizedValue: String) -> String {
        for key in genderKeys {
            if "gender_option_\(key)".localized == localizedValue {
                return key
            }
        }
        return "prefer_not_to_say"
    }
    
    static func localizedGender(for key: String) -> String {
        // 处理旧数据（中文）
        let oldToNewMap: [String: String] = [
            "男": "male",
            "女": "female",
            "其他": "other",
            "不愿透露": "prefer_not_to_say"
        ]
        
        let normalizedKey = oldToNewMap[key] ?? key
        
        if genderKeys.contains(normalizedKey) {
            return "gender_option_\(normalizedKey)".localized
        }
        return key
    }
    
    static func genderLocalizedValue(for storedValue: String) -> String {
        return localizedGender(for: storedValue)
    }
    
    // MARK: - 年龄段选项键值
    static let ageGroupKeys = [
        "under_18", "18_25", "26_35", "36_45", 
        "46_55", "over_56", "prefer_not_to_say"
    ]
    
    static func localizedAgeGroupOptions() -> [String] {
        return ageGroupKeys.map { "age_group_option_\($0)".localized }
    }
    
    static func ageGroupKey(for localizedValue: String) -> String {
        for key in ageGroupKeys {
            if "age_group_option_\(key)".localized == localizedValue {
                return key
            }
        }
        return "prefer_not_to_say"
    }
    
    static func localizedAgeGroup(for key: String) -> String {
        // 处理旧数据（中文）
        let oldToNewMap: [String: String] = [
            "18岁以下": "under_18",
            "18-25岁": "18_25",
            "26-35岁": "26_35",
            "36-45岁": "36_45",
            "46-55岁": "46_55",
            "56岁以上": "over_56",
            "不愿透露": "prefer_not_to_say"
        ]
        
        let normalizedKey = oldToNewMap[key] ?? key
        
        if ageGroupKeys.contains(normalizedKey) {
            return "age_group_option_\(normalizedKey)".localized
        }
        return key
    }
    
    static func ageGroupLocalizedValue(for storedValue: String) -> String {
        return localizedAgeGroup(for: storedValue)
    }
    
    // MARK: - 星座选项键值
    static let constellationKeys = [
        "aries", "taurus", "gemini", "cancer",
        "leo", "virgo", "libra", "scorpio",
        "sagittarius", "capricorn", "aquarius", "pisces", "prefer_not_to_say"
    ]
    
    static func localizedConstellationOptions() -> [String] {
        return constellationKeys.map { "constellation_option_\($0)".localized }
    }
    
    static func constellationKey(for localizedValue: String) -> String {
        for key in constellationKeys {
            if "constellation_option_\(key)".localized == localizedValue {
                return key
            }
        }
        return "prefer_not_to_say"
    }
    
    static func localizedConstellation(for key: String) -> String {
        // 处理旧数据（中文）
        let oldToNewMap: [String: String] = [
            "白羊座": "aries",
            "金牛座": "taurus",
            "双子座": "gemini",
            "巨蟹座": "cancer",
            "狮子座": "leo",
            "处女座": "virgo",
            "天秤座": "libra",
            "天蝎座": "scorpio",
            "射手座": "sagittarius",
            "摩羯座": "capricorn",
            "水瓶座": "aquarius",
            "双鱼座": "pisces",
            "不愿透露": "prefer_not_to_say"
        ]
        
        let normalizedKey = oldToNewMap[key] ?? key
        
        if constellationKeys.contains(normalizedKey) {
            return "constellation_option_\(normalizedKey)".localized
        }
        return key
    }
    
    static func constellationLocalizedValue(for storedValue: String) -> String {
        return localizedConstellation(for: storedValue)
    }
}

