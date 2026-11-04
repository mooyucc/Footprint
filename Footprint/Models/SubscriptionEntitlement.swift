//
//  SubscriptionEntitlement.swift
//  Footprint
//
//  定义订阅权益与产品标识，供全局权限判断使用。
//

import Foundation

/// 订阅产品 ID 集合
enum SubscriptionProductID {
    // 月度订阅
    static let proMonthly = "com.mooyu.footprint.pro.monthly"
    // 年度订阅
    static let proYearly = "com.mooyu.footprint.pro.yearly"
    // 终身买断（非消耗型）
    static let proLifetime = "com.mooyu.footprint.pro.lifetime"
    // 批量加载列表
    static let all: [String] = [proMonthly, proYearly, proLifetime]
}

/// 终身买断的无限 AI 兼容规则
enum LifetimeAIPolicy {
    /// 购买日期早于该日（上海时区 0 点）的终身用户继续享有无限 AI
    static let unlimitedAICutoff: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600) ?? .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
    }()

    static func includesUnlimitedAI(originalPurchaseDate: Date) -> Bool {
        originalPurchaseDate < unlimitedAICutoff
    }
}

/// 月/年订阅的无限 AI 兼容规则：仅当前计费周期在政策日前开始的订阅，本期结束前仍不扣次
enum SubscriptionAIPolicy {
    /// 本期购买日早于该日（上海时区 0 点）则本期仍含无限 AI；续订后按次数
    static let unlimitedAICutoff: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600) ?? .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 5))!
    }()

    static func includesUnlimitedAI(periodPurchaseDate: Date) -> Bool {
        periodPurchaseDate < unlimitedAICutoff
    }
}

/// 免费版数量与体验限制
enum FreeTierLimits {
    static let maxDestinations = 15
    static let maxTrips = 3
    static let maxPhotosPerDestination = 3
    static let aiFreeTrialCredits = 5
}

/// Pro 版数量限制
enum ProTierLimits {
    static let maxPhotosPerDestination = 9
}

/// 应用内权益等级
enum SubscriptionEntitlement: String, Codable {
    case free
    /// 月/年订阅：记录类 Pro 权益；无限 AI 仅兼容本期开始于 2026-09-05 前的订阅
    case pro
    /// 终身买断：含记录/分享/导入导出；2026-08-31 起新购不含无限 AI（更早购买的由 EntitlementManager 兼容）
    case proLifetime

    var displayName: String {
        switch self {
        case .free: return "免费版"
        case .pro: return "Pro"
        case .proLifetime: return "Pro 终身"
        }
    }

    /// 已付费（订阅或终身），用于记录类权益与会员态展示
    var isPaid: Bool {
        self != .free
    }

    /// 无限地点、旅程、完整分享、本地导入导出等记录类权益
    var hasRecordingBenefits: Bool {
        switch self {
        case .pro, .proLifetime: return true
        case .free: return false
        }
    }

    // MARK: - 权限判断

    func canAddDestination(currentCount: Int) -> Bool {
        if hasRecordingBenefits { return true }
        return currentCount < FreeTierLimits.maxDestinations
    }

    func canAddTripCard(currentCount: Int) -> Bool {
        if hasRecordingBenefits { return true }
        return currentCount < FreeTierLimits.maxTrips
    }

    var maxPhotosPerDestination: Int {
        hasRecordingBenefits ? ProTierLimits.maxPhotosPerDestination : FreeTierLimits.maxPhotosPerDestination
    }

    /// 订阅与终身均可使用全部分享版面；免费版仅基础版面
    var canUseFullShareLayouts: Bool {
        hasRecordingBenefits
    }

    /// 免费版允许基础旅程/地点分享版面
    var canUseBasicShareLayouts: Bool {
        true
    }

    /// 免费版分享图带水印
    var shouldApplyShareWatermark: Bool {
        self == .free
    }

    var canImportTrips: Bool {
        true
    }

    var canLinkToSystemMaps: Bool {
        true
    }

    var canUseLocalDataIO: Bool {
        hasRecordingBenefits
    }

}
