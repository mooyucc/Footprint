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

/// 免费版数量与体验限制
enum FreeTierLimits {
    static let maxDestinations = 40
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
    case pro

    var displayName: String {
        switch self {
        case .free: return "免费版"
        case .pro: return "Pro"
        }
    }

    // MARK: - 权限判断

    func canAddDestination(currentCount: Int) -> Bool {
        switch self {
        case .free:
            return currentCount < FreeTierLimits.maxDestinations
        case .pro:
            return true
        }
    }

    func canAddTripCard(currentCount: Int) -> Bool {
        switch self {
        case .free:
            return currentCount < FreeTierLimits.maxTrips
        case .pro:
            return true
        }
    }

    var maxPhotosPerDestination: Int {
        switch self {
        case .free:
            return FreeTierLimits.maxPhotosPerDestination
        case .pro:
            return ProTierLimits.maxPhotosPerDestination
        }
    }

    /// Pro 可使用全部分享版面；免费版仅基础版面
    var canUseFullShareLayouts: Bool {
        self == .pro
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
        self == .pro
    }

    var canUseAIFeatures: Bool {
        self == .pro
    }
}
