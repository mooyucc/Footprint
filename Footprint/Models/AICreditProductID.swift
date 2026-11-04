//
//  AICreditProductID.swift
//  Footprint
//
//  AI 调用次数相关的消耗型内购产品 ID。
//

import Foundation

enum AICreditProductID {
    /// 10 次 AI 调用（消耗型）
    static let tenCalls = "com.mooyu.footprint.ai.credits.10"
    /// 50 次 AI 调用（消耗型）
    static let fiftyCalls = "com.mooyu.footprint.ai.credits.50"

    static let all: [String] = [
        tenCalls,
        fiftyCalls
    ]

    static func creditAmount(for productID: String) -> Int? {
        switch productID {
        case tenCalls: return 10
        case fiftyCalls: return 50
        default: return nil
        }
    }
}
