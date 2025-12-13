//
//  BetaInfo.swift
//  Footprint
//
//  Created by Auto on 2025/12/09.
//

import Foundation

/// 信息汇总：用于测试版有效期与提示逻辑
enum BetaInfo {
    /// 是否为 Beta 构建（通过编译条件判断）
    static let isBetaBuild: Bool = {
        #if BETA
        return true
        #else
        return false
        #endif
    }()
    
    /// App Store Connect 审核通过日期（从 Info.plist 读取 ISO8601 或 yyyy-MM-dd）
    static var approvalDate: Date? {
        guard let value = Bundle.main.infoDictionary?["BetaApprovalDate"] as? String,
              !value.isEmpty else {
            return nil
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: value) {
            return date
        }
        
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd"
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        return fallback.date(from: value)
    }
    
    /// 测试有效天数（自审核通过日起 30 天）
    private static let validityDays: Int = 30
    /// 审核预留天数（倒计时从 30 天起）
    private static let reviewBufferDays: Int = 0
    
    /// 过期日期
    static var expiryDate: Date? {
        guard let start = approvalDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: validityDays, to: start)
    }
    
    /// 是否已过期
    static var isExpired: Bool {
        guard isBetaBuild, let expiry = expiryDate else { return false }
        return Date() >= expiry
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
    
    /// 展示用剩余天数（扣除审核期，起始 30 天）
    static var displayRemainingDays: Int {
        max(0, remainingDays - reviewBufferDays)
    }
}

