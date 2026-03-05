//
//  TravelRecommendation.swift
//  Footprint
//
//  AI 生成的旅行目的地推荐记录，用于持久化保存
//

import Foundation
import SwiftData

@Model
final class TravelRecommendation {
    var id: UUID = UUID()
    /// 生成时间
    var generatedAt: Date = Date()
    /// 推荐内容全文
    var content: String = ""

    init(generatedAt: Date = Date(), content: String) {
        self.generatedAt = generatedAt
        self.content = content
    }

    /// 用于列表展示的摘要（首行或前 60 字）
    var previewText: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        if firstLine.count <= 60 { return firstLine }
        return String(firstLine.prefix(60)) + "..."
    }
}

/// 用于 sheet(item:) 的包装，避免 TravelRecommendation 显式遵循 Identifiable 与 @Model 冲突
struct TravelRecommendationItem: Identifiable {
    var id: UUID { recommendation.id }
    let recommendation: TravelRecommendation
    init(_ recommendation: TravelRecommendation) {
        self.recommendation = recommendation
    }
}
