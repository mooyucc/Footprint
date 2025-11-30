//
//  BadgeManager.swift
//  Footprint
//
//  Created on 2025/11/29.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// 勋章管理器 - 管理勋章状态和逻辑
class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    
    private let countryManager = CountryManager.shared
    
    // 添加一个 @Published 属性以满足 ObservableObject 协议要求
    @Published var updateTrigger = UUID()
    
    private init() {}
    
    /// 触发更新（如果需要响应式更新）
    func triggerUpdate() {
        updateTrigger = UUID()
    }
    
    // MARK: - 获取去过的国家集合
    
    /// 从目的地列表中提取所有去过的国家（标准化后的 ISO 代码）
    func getVisitedCountries(from destinations: [TravelDestination]) -> Set<String> {
        var visitedCountries = Set<String>()
        
        for destination in destinations {
            let normalized = normalizeCountryName(destination.country)
            if !normalized.isEmpty {
                visitedCountries.insert(normalized)
            }
        }
        
        return visitedCountries
    }
    
    /// 从目的地列表中提取所有去过的省份（仅限中国）
    func getVisitedProvinces(from destinations: [TravelDestination]) -> Set<String> {
        var visitedProvinces = Set<String>()
        
        for destination in destinations {
            // 只处理中国的省份
            let isChina = destination.country == "中国" || 
                         destination.country == "CN" || 
                         destination.country == "China"
            
            if isChina && !destination.province.isEmpty {
                let normalized = normalizeProvinceName(destination.province)
                if !normalized.isEmpty {
                    visitedProvinces.insert(normalized)
                }
            }
        }
        
        return visitedProvinces
    }
    
    // MARK: - 判断勋章是否点亮
    
    /// 判断某个国家勋章是否已点亮
    func isCountryBadgeUnlocked(country: CountryManager.Country, visitedCountries: Set<String>) -> Bool {
        let countryCodes = [
            country.rawValue,           // ISO 代码，如 "CN"
            country.displayName,        // 中文名称，如 "中国"
            country.englishName         // 英文名称，如 "China"
        ]
        
        return countryCodes.contains { visitedCountries.contains($0) }
    }
    
    /// 判断某个省份勋章是否已点亮
    /// 支持灵活的匹配：如"新疆"可以匹配"新疆维吾尔自治区"，反之亦然
    /// 通过标准化名称实现匹配，确保所有变体都能正确识别
    func isProvinceBadgeUnlocked(provinceName: String, visitedProvinces: Set<String>) -> Bool {
        let normalized = normalizeProvinceName(provinceName)
        
        // visitedProvinces 中存储的已经是标准化后的名称（在 getVisitedProvinces 中处理）
        // 所以直接匹配即可
        // 例如：
        // - 目的地存储"新疆" → 标准化为"新疆" → 存储到 visitedProvinces
        // - 徽章名称"新疆维吾尔自治区" → 标准化为"新疆" → 匹配成功
        return visitedProvinces.contains(normalized)
    }
    
    // MARK: - 名称标准化
    
    /// 标准化国家名称（用于匹配）
    func normalizeCountryName(_ country: String) -> String {
        // 尝试匹配 CountryManager 中的国家
        if let countryEnum = CountryManager.Country.allCases.first(where: {
            $0.rawValue == country || 
            $0.displayName == country || 
            $0.englishName == country
        }) {
            return countryEnum.rawValue  // 返回 ISO 代码
        }
        
        // 如果找不到匹配，返回原名称（可能是其他格式）
        return country
    }
    
    /// 标准化省份名称（去除"市"、"省"等后缀）
    /// 支持识别"浙江"和"浙江省"两种格式，统一标准化为"浙江"
    /// 支持识别"新疆"和"新疆维吾尔自治区"两种格式，统一标准化为"新疆"
    func normalizeProvinceName(_ province: String) -> String {
        var normalized = province.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空字符串直接返回
        guard !normalized.isEmpty else {
            return normalized
        }
        
        // 特殊处理：如果名称本身就是标准化的核心名称（如"新疆"），直接返回
        // 这样可以确保"新疆"和"新疆维吾尔自治区"标准化后都是"新疆"
        
        // 按长度从长到短排序，先移除长的后缀，避免误删
        // 例如：先移除"维吾尔自治区"，再移除"自治区"，避免"新疆维吾尔自治区"被误处理
        let suffixes = [
            "维吾尔自治区", "壮族自治区", "回族自治区",  // 最长的后缀先处理
            "特别行政区", "自治区",                      // 中等长度
            "省", "市"                                  // 最短的后缀最后处理
        ]
        
        // 移除后缀（按顺序，一旦匹配就移除并返回）
        for suffix in suffixes {
            if normalized.hasSuffix(suffix) {
                normalized = String(normalized.dropLast(suffix.count))
                break  // 只移除一个后缀，避免重复处理
            }
        }
        
        return normalized
    }
    
    // MARK: - 获取图片名称
    
    /// 获取国家勋章图片名称（用于 Assets.xcassets）
    func getCountryBadgeImageName(for country: CountryManager.Country) -> String {
        return "CountryBadge_\(country.rawValue)"
    }
    
    /// 获取省份勋章图片名称（用于 Assets.xcassets）
    func getProvinceBadgeImageName(for provinceName: String) -> String {
        let normalized = normalizeProvinceName(provinceName)
        return "ProvinceBadge_\(normalized)"
    }
}

