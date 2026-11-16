//
//  BadgeProgressSummaryCard.swift
//  Footprint
//
//  点亮进度摘要卡：标题 + 进度条 + 徽章平铺网格（可选跨维度 hint）
//

import SwiftUI
import UIKit

struct BadgeProgressSummaryCard: View {
    let items: [BadgeOverlapItem]
    let unlocked: Int
    let total: Int
    let unitLabel: String
    let emptyText: String
    var title: String = "badges_progress".localized
    var crossHintText: String? = nil
    var accent: Color = Color.footprintRed
    /// 为 false 时仅显示标题/进度/跨维度入口（勋章页下方已有完整网格时用）
    var showsBadgeTiles: Bool = true
    /// 省份用彩底票根，国家仍是圆标
    var usesProvinceTickets: Bool = false
    var onSelectItem: ((BadgeOverlapItem) -> Void)? = nil
    var onCrossHintTap: (() -> Void)? = nil
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var dataRevision = DestinationDataRevision.shared
    @State private var provinceReady: [String: ProvinceTicketReady] = [:]
    /// 网格容器宽度。列宽只由它决定，滚动时不再重新量高。
    @State private var provinceGridWidth: CGFloat = 0
    
    private let circleSize: CGFloat = 48
    private let gridSpacing: CGFloat = 12
    private let columnSpacing: CGFloat = 10
    
    private var columnCount: Int {
        if usesProvinceTickets {
            return horizontalSizeClass == .regular ? 3 : 2
        }
        return horizontalSizeClass == .regular ? 6 : 4
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
            repeating: GridItem(.flexible(), spacing: usesProvinceTickets ? 0 : columnSpacing),
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
        .task(id: provinceLoadKey) {
            await loadProvinceFaces()
        }
    }

    private var provinceLoadKey: String {
        guard usesProvinceTickets else { return "off" }
        return "\(dataRevision.revision)#\(items.map(\.id).joined(separator: "|"))"
    }

    /// 地点快照未变时直接读上次的票面。变了才重算并写回。
    private func loadProvinceFaces() async {
        guard usesProvinceTickets else {
            provinceReady = [:]
            return
        }
        let snapshots = ProfileCacheStore.shared.destinationSnapshots
        let fingerprint = ProvinceTicketDiskCache.fingerprint(of: snapshots)
        if !snapshots.isEmpty, let cached = ProvinceTicketDiskCache.load(fingerprint: fingerprint) {
            provinceReady = cached
            return
        }
        var next: [String: ProvinceTicketReady] = [:]
        next.reserveCapacity(items.count)
        for item in items {
            let destinations = TabListSnapshotStore.shared.destinations(matchingProvince: item.title)
            let face = ProvinceTicketPicker.face(seed: item.shortTitle, destinations: destinations)
            let image: UIImage?
            if let id = face.destinationId {
                image = await DestinationThumbnailCache.shared.imageForListCard(
                    for: id,
                    thumbnailData: face.thumbnailData,
                    fallbackData: face.fullData
                )
            } else {
                image = nil
            }
            next[item.id] = ProvinceTicketReady(
                face: face,
                image: image,
                palette: ProvinceTicketPicker.colors(for: image, paletteIndex: face.paletteIndex)
            )
        }
        if !snapshots.isEmpty {
            ProvinceTicketDiskCache.save(fingerprint: fingerprint, items: next)
        }
        provinceReady = next
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(accent)
            Text(title)
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
            let barHeight: CGFloat = 12
            let badgeDiameter: CGFloat = 22
            let badgeRadius = badgeDiameter / 2
            let minCenterX = badgeRadius
            let maxCenterX = max(minCenterX, geo.size.width - badgeRadius)
            let centerX = minCenterX + (maxCenterX - minCenterX) * progressFraction
            let fillWidth = max(centerX, 1)
            let endColor = progressBarEndColor(from: accent)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: barHeight)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, endColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth, height: barHeight)
                
                Text("\(unlocked)")
                    .font(.system(size: unlocked >= 100 ? 9 : 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: badgeDiameter, height: badgeDiameter)
                    .background(Circle().fill(Color(.systemBackground)))
                    .overlay(
                        Circle()
                            .strokeBorder(endColor, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .offset(x: centerX - badgeRadius)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
    
    /// 与分享海报时间线条一致：色相略推移、饱和度降低、亮度抬高。
    private func progressBarEndColor(from brand: Color) -> Color {
        let ui = UIColor(brand)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard ui.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return brand
        }
        let shiftedHue = (hue + 0.04).truncatingRemainder(dividingBy: 1)
        return Color(
            UIColor(
                hue: shiftedHue,
                saturation: min(max(saturation * 0.75, 0), 1),
                brightness: min(brightness + 0.16, 1),
                alpha: alpha
            )
        )
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
        } else if usesProvinceTickets {
            provinceTicketGrid
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

    private var provinceColumnSide: CGFloat {
        guard provinceGridWidth > 1 else { return 0 }
        return provinceGridWidth / CGFloat(columnCount)
    }

    /// 懒加载网格：屏外小票不参与合成；列宽仍只量一次，避免滚动改尺寸。
    private var provinceTicketGrid: some View {
        let side = provinceColumnSide
        let cellHeight = side > 1 ? side / ProvinceTicketMetrics.aspect : 1
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(items) { item in
                Button {
                    onSelectItem?(item)
                } label: {
                    Group {
                        if side > 1 {
                            provinceTicketTile(for: item, side: side)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: cellHeight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: ProvinceGridWidthKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(ProvinceGridWidthKey.self) { newValue in
            // 只定一次列宽；首帧偏小时允许变大纠正，滚动中不接受变小以免抖动
            guard newValue > 1 else { return }
            if provinceGridWidth == 0 {
                provinceGridWidth = newValue
            } else if newValue > provinceGridWidth + 1 {
                provinceGridWidth = newValue
            }
        }
    }

    private func provinceTicketTile(for item: BadgeOverlapItem, side: CGFloat) -> some View {
        let ready = provinceReady[item.id]
        let face = ready?.face ?? ProvinceTicketPicker.placeholder(seed: item.shortTitle)
        let palette = ready?.palette
            ?? ProvinceTicketPicker.colors(for: nil, paletteIndex: face.paletteIndex)
        return ProvinceTicketTile(
            face: face,
            image: ready?.image,
            palette: palette,
            side: side
        )
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
        guard total > 0 else { return title }
        return "\(title), \(unlocked)/\(total), \(progressPercentage)%"
    }
}

private struct ProvinceGridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

