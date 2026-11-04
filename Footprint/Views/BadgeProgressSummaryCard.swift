//
//  BadgeProgressSummaryCard.swift
//  Footprint
//
//  点亮进度摘要卡：进度条 + 徽章平铺网格 + 跨维度 hint
//

import SwiftUI
import UIKit

struct BadgeProgressSummaryCard: View {
    let items: [BadgeOverlapItem]
    let unlocked: Int
    let total: Int
    let unitLabel: String
    let emptyText: String
    var crossHintText: String? = nil
    var accent: Color = Color.footprintRed
    /// 为 false 时仅显示标题/进度/跨维度入口（勋章页下方已有完整网格时用）
    var showsBadgeTiles: Bool = true
    var onSelectItem: ((BadgeOverlapItem) -> Void)? = nil
    var onCrossHintTap: (() -> Void)? = nil
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    private let circleSize: CGFloat = 48
    private let gridSpacing: CGFloat = 12
    private let columnSpacing: CGFloat = 10
    
    private var columnCount: Int {
        horizontalSizeClass == .regular ? 6 : 4
    }
    
    private var progressFraction: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, CGFloat(unlocked) / CGFloat(total))
    }
    
    private var progressPercentage: Int {
        Int((progressFraction * 100).rounded())
    }
    
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: columnSpacing),
            count: columnCount
        )
    }
    
    private var badgeRingColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.22)
            : Color(.systemBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            
            if total > 0 {
                progressBar
            }
            
            if showsBadgeTiles {
                badgeGrid
            }
            
            if let crossHintText, onCrossHintTap != nil {
                FootprintCardHairline()
                crossHintRow(text: crossHintText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .footprintGlassCard(cornerRadius: 18, glow: accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(accent)
            Text("badges_progress".localized)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Spacer(minLength: 8)
            
            if total > 0 {
                Text("\(unlocked)/\(total) · \(progressPercentage)%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(unlocked) \(unitLabel), \(progressPercentage)%")
            }
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                
                Capsule()
                    .fill(accent.gradient)
                    .frame(width: max(4, geo.size.width * progressFraction))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
    
    // MARK: - Badge grid
    
    @ViewBuilder
    private var badgeGrid: some View {
        if items.isEmpty {
            Text(emptyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(items) { item in
                    Button {
                        onSelectItem?(item)
                    } label: {
                        VStack(spacing: 6) {
                            badgeCircle(for: item)
                            
                            Text(item.shortTitle)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                }
            }
        }
    }
    
    @ViewBuilder
    private func badgeCircle(for item: BadgeOverlapItem) -> some View {
        Group {
            if let image = UIImage(named: item.imageName) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .antialiased(true)
                    .scaledToFill()
            } else {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .frame(width: circleSize, height: circleSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(badgeRingColor, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Cross hint
    
    private func crossHintRow(text: String) -> some View {
        Button {
            onCrossHintTap?()
        } label: {
            HStack(spacing: 6) {
                Text(text)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 4)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(accent.opacity(0.95))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
    
    private var accessibilitySummary: String {
        guard total > 0 else { return "badges_progress".localized }
        return "\("badges_progress".localized), \(unlocked)/\(total), \(progressPercentage)%"
    }
}
