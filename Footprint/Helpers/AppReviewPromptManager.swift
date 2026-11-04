//
//  AppReviewPromptManager.swift
//  Footprint
//
//  管理系统评分弹窗的触发频率，以及 App Store 写评页入口。
//

import Foundation
import UIKit

@MainActor
final class AppReviewPromptManager {
    static let shared = AppReviewPromptManager()

    static let appStoreID = "6754274652"

    private let lastRequestDateKey = "app_review_last_request_date"
    private let cooldown: TimeInterval = 60 * 24 * 3600
    private let minimumDestinations = 3

    private var lastKnownCount: Int?
    private var requestedThisSession = false

    var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(Self.appStoreID)?action=write-review")
    }

    var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(Self.appStoreID)")
    }

    private init() {}

    /// 启动时记下当前地点数量，避免把已有数据当成「新增」而立刻弹窗。
    func seedDestinationCount(_ count: Int) {
        if lastKnownCount == nil {
            lastKnownCount = count
        }
    }

    /// 记录最新数量。仅在数量增加且达到门槛、冷却已过时返回 true。
    func consumeDestinationCount(_ count: Int) -> Bool {
        let previous = lastKnownCount
        lastKnownCount = count

        guard FirstLaunchManager.shared.hasCompletedOnboarding else { return false }
        guard !requestedThisSession else { return false }
        guard count >= minimumDestinations else { return false }
        guard let previous, count > previous else { return false }

        if let last = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date,
           Date().timeIntervalSince(last) < cooldown {
            return false
        }
        return true
    }

    func markRequested() {
        requestedThisSession = true
        UserDefaults.standard.set(Date(), forKey: lastRequestDateKey)
    }

    func openWriteReviewPage() {
        guard let url = writeReviewURL else { return }
        UIApplication.shared.open(url)
    }

    func openAppStorePage() {
        guard let url = appStoreURL else { return }
        UIApplication.shared.open(url)
    }
}
