//
//  AICreditManager.swift
//  Footprint
//
//  管理 AI 调用次数（本地计数，基于 UserDefaults 持久化）。
//

import Foundation
import Combine

/// AI 调用门禁结果
enum AICallGateResult {
    case allowed
    /// 普通用户次数不足
    case insufficientCredits
    /// 无限 AI 用户触及每日公平使用上限
    case dailyLimitReached
}

/// Beta 等「不扣次数」路径的公平使用额度（正式版已取消无限 AI）
enum UnlimitedAIFairUse {
    /// 每日最多调用次数（防异常/死循环）
    static let dailyCallLimit = 30
}

@MainActor
final class AICreditManager: ObservableObject {
    static let shared = AICreditManager()
    
    @Published private(set) var remaining: Int
    @Published private(set) var used: Int
    /// 无限 AI 用户今日已用次数
    @Published private(set) var unlimitedDailyUsed: Int = 0
    
    private let remainingKey = "ai_credits_remaining"
    private let usedKey = "ai_credits_used"
    private let unlimitedDailyDateKey = "ai_unlimited_daily_date"
    private let unlimitedDailyUsedKey = "ai_unlimited_daily_used"
    private let defaults: UserDefaults
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedRemaining = defaults.object(forKey: remainingKey) as? Int ?? 0
        let storedUsed = defaults.object(forKey: usedKey) as? Int ?? 0
        self.remaining = max(0, storedRemaining)
        self.used = max(0, storedUsed)
        refreshUnlimitedDailyIfNeeded()
    }

    /// 无限 AI 用户今日剩余额度
    var unlimitedDailyRemaining: Int {
        max(0, UnlimitedAIFairUse.dailyCallLimit - unlimitedDailyUsed)
    }

    /// 首次启动赠送免费 AI 体验次数（仅一次）
    func grantFreeTrialIfNeeded() {
        guard !BetaInfo.isBetaBuild else { return }
        let grantedKey = "ai_credits_free_trial_granted"
        guard !defaults.bool(forKey: grantedKey) else { return }
        defaults.set(true, forKey: grantedKey)
        addCredits(FreeTierLimits.aiFreeTrialCredits)
    }
    
    /// 购买后增加一定数量的 AI 调用次数。
    func addCredits(_ amount: Int) {
        guard amount > 0 else { return }
        remaining += amount
        save()
    }
    
    /// 统一门禁：普通用户扣次数；无限 AI 用户扣每日公平使用额度。
    @discardableResult
    func gateAICall(isUnlimitedUser: Bool) -> AICallGateResult {
        if isUnlimitedUser {
            return consumeUnlimitedDailySlot() ? .allowed : .dailyLimitReached
        }
        return consumeOne() ? .allowed : .insufficientCredits
    }
    
    /// 尝试消耗一次调用，成功返回 true；若剩余次数不足则返回 false。
    @discardableResult
    func consumeOne() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        used += 1
        save()
        return true
    }
    
    /// 重置计数（主要用于调试或测试）。
    func reset() {
        remaining = 0
        used = 0
        save()
    }
    
    // MARK: - Unlimited daily fair use
    
    @discardableResult
    private func consumeUnlimitedDailySlot() -> Bool {
        refreshUnlimitedDailyIfNeeded()
        guard unlimitedDailyUsed < UnlimitedAIFairUse.dailyCallLimit else { return false }
        unlimitedDailyUsed += 1
        defaults.set(unlimitedDailyUsed, forKey: unlimitedDailyUsedKey)
        return true
    }
    
    private func refreshUnlimitedDailyIfNeeded() {
        let today = Self.todayDateKey()
        if defaults.string(forKey: unlimitedDailyDateKey) != today {
            defaults.set(today, forKey: unlimitedDailyDateKey)
            defaults.set(0, forKey: unlimitedDailyUsedKey)
            unlimitedDailyUsed = 0
        } else {
            unlimitedDailyUsed = max(0, defaults.integer(forKey: unlimitedDailyUsedKey))
        }
    }
    
    private static func todayDateKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func save() {
        defaults.set(remaining, forKey: remainingKey)
        defaults.set(used, forKey: usedKey)
    }
}
