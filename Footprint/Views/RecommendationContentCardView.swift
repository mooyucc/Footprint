//
//  RecommendationContentCardView.swift
//  Footprint
//
//  推荐结果内容卡片（可复用：当前结果与已保存详情）
//

import SwiftUI

struct RecommendationContentCardView: View {
    let content: String
    
    var body: some View {
        let normalized = content
            .replacingOccurrences(of: "\n(?=\\d+\\.\\s+\\*\\*)", with: "\n\n", options: .regularExpression)
        let blocks = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block: block, isFirstBlock: index == 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    @ViewBuilder
    private func blockView(block: String, isFirstBlock: Bool) -> some View {
        let isNumbered = block.first?.isNumber == true
            && block.dropFirst().hasPrefix(". ")
            && block.contains("**")
        if isNumbered {
            itemView(block: block)
        } else {
            paragraphView(block, isIntro: isFirstBlock)
        }
    }
    
    private func paragraphView(_ text: String, isIntro: Bool) -> some View {
        Group {
            if let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
            } else {
                Text(text)
            }
        }
        .font(isIntro ? .subheadline : .body)
        .foregroundColor(.primary)
        .lineSpacing(8)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func itemView(block: String) -> some View {
        let (number, rest) = splitNumberPrefix(block)
        let (destinationPart, reasonPart) = splitRecommendationReason(rest)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let number = number {
                    Text(number)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                        .multilineTextAlignment(.center)
                }
                if let attributed = try? AttributedString(markdown: destinationPart) {
                    Text(attributed)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text(destinationPart)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            if !reasonPart.isEmpty {
                Text(reasonPart)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .padding(.bottom, 12)
    }
    
    private func splitNumberPrefix(_ block: String) -> (String?, String) {
        guard let dotRange = block.range(of: ". "),
              block[..<dotRange.lowerBound].allSatisfy(\.isNumber),
              !block[..<dotRange.lowerBound].isEmpty else {
            return (nil, block)
        }
        let num = String(block[..<dotRange.lowerBound])
        let rest = String(block[dotRange.upperBound...])
        return (num, rest)
    }
    
    private func splitRecommendationReason(_ rest: String) -> (String, String) {
        let reasonLabels = ["推荐理由:", "推荐理由：", "推荐理由"]
        var destination = rest
        var reason = ""
        for label in reasonLabels {
            if let range = rest.range(of: label) {
                destination = String(rest[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                reason = String(rest[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        if reason.isEmpty { destination = rest }
        return (destination, reason)
    }
}
