//
//  AICreditManager.swift
//  Footprint
//
//  管理 AI 调用次数（本地计数，基于 UserDefaults 持久化）。
//

import Foundation
import Combine

@MainActor
final class AICreditManager: ObservableObject {
    static let shared = AICreditManager()
    
    @Published private(set) var remaining: Int
    @Published private(set) var used: Int
    
    private let remainingKey = "ai_credits_remaining"
    private let usedKey = "ai_credits_used"
    private let defaults: UserDefaults
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedRemaining = defaults.object(forKey: remainingKey) as? Int ?? 0
        let storedUsed = defaults.object(forKey: usedKey) as? Int ?? 0
        self.remaining = max(0, storedRemaining)
        self.used = max(0, storedUsed)
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
    
    private func save() {
        defaults.set(remaining, forKey: remainingKey)
        defaults.set(used, forKey: usedKey)
    }
}

