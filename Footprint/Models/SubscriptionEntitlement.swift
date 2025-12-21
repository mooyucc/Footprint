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
        // 免费版和 Pro 都无限制
        return true
    }

    func canAddTripCard(currentCount: Int) -> Bool {
        // 免费版和 Pro 都无限制
        return true
    }

    /// 免费版和 Pro 都提供完整版面
    var canUseFullShareLayouts: Bool {
        true
    }

    /// 免费版允许基础旅程分享图片
    var canUseBasicShareLayouts: Bool {
        true
    }

    var canImportTrips: Bool {
        // 免费版和 Pro 都可以导入旅程
        true
    }

    var canLinkToSystemMaps: Bool {
        // 免费版和 Pro 都可以链接系统地图
        true
    }

    var canUseLocalDataIO: Bool {
        // 仅 Pro 可以使用本地数据导入/导出
        self == .pro
    }
    
    var canUseAIFeatures: Bool {
        // 仅 Pro 可以使用AI功能
        self == .pro
    }
}

