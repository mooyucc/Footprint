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
    
    /// 所有 AI 调用次数产品 ID 列表
    static let all: [String] = [
        tenCalls
    ]
}

