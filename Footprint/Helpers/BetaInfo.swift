//
//  BetaInfo.swift
//  Footprint
//
//  Created by Auto on 2025/12/09.
//

import Foundation

/// 信息汇总：用于测试版有效期与提示逻辑
enum BetaInfo {
    /// UserDefaults 键名，用于存储首次启动日期
    private static let firstLaunchDateKey = "BetaFirstLaunchDate"
    /// UserDefaults 键名，用于存储上次记录的构建号
    private static let lastBuildNumberKey = "BetaLastBuildNumber"
    
    /// 是否为 Beta 构建（通过编译条件判断）
    static let isBetaBuild: Bool = {
        #if BETA
        return true
        #else
        return false
        #endif
    }()
    
    /// 获取当前构建号
    private static var currentBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    
    /// 用户首次打开应用的日期（从 UserDefaults 读取，如果不存在或检测到新版本则记录当前日期）
    static var firstLaunchDate: Date {
        // 只在 Beta 版本中记录和读取
        guard isBetaBuild else {
            // 非 Beta 版本返回一个默认日期（不会使用）
            return Date()
        }
        
        let currentBuild = currentBuildNumber
        let lastBuild = UserDefaults.standard.string(forKey: lastBuildNumberKey)
        
        // 如果构建号变化，说明是新安装或更新，重置首次启动日期
        let isNewInstall = lastBuild == nil || lastBuild != currentBuild
        
        if isNewInstall {
            // 新安装或更新：重置首次启动日期为当前日期
            let today = Calendar.current.startOfDay(for: Date())
            UserDefaults.standard.set(today, forKey: firstLaunchDateKey)
            UserDefaults.standard.set(currentBuild, forKey: lastBuildNumberKey)
            print("🔄 检测到新版本（构建号: \(currentBuild)），重置测试版首次启动日期为: \(today)")
            return today
        }
        
        // 尝试从 UserDefaults 读取已保存的首次启动日期
        if let savedDate = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date {
            return savedDate
        }
        
        // 如果没有保存的日期（理论上不应该发生），记录当前日期
        let today = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: firstLaunchDateKey)
        UserDefaults.standard.set(currentBuild, forKey: lastBuildNumberKey)
        return today
    }
    
    /// 测试有效天数（自首次启动日起 7 天）
    private static let validityDays: Int = 7
    /// 审核预留天数（倒计时从 7 天起）
    private static let reviewBufferDays: Int = 0
    
    /// 过期日期（从首次启动日期开始计算）
    static var expiryDate: Date? {
        guard isBetaBuild else { return nil }
        let start = firstLaunchDate
        return Calendar.current.date(byAdding: .day, value: validityDays, to: start)
    }
    
    /// 是否已过期
    static var isExpired: Bool {
        guard isBetaBuild, let expiry = expiryDate else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let expiryDay = Calendar.current.startOfDay(for: expiry)
        return today >= expiryDay
    }
    
    /// 实际剩余天数（不足 0 时返回 0，未配置日期时默认 validityDays）
    private static var remainingDays: Int {
        guard isBetaBuild else { return 0 }
        guard let expiry = expiryDate else { return validityDays }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: expiry)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry)
        return max(0, components.day ?? validityDays)
    }
    
    /// 展示用剩余天数（扣除审核期，起始 7 天）
    static var displayRemainingDays: Int {
        max(0, remainingDays - reviewBufferDays)
    }
}

