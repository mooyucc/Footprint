//
//  StatsImageGenerator.swift
//  Footprint
//
//  Created on 2025/10/22.
//

import SwiftUI
import UIKit

struct TravelStats: Identifiable {
    let id = UUID()
    let totalDestinations: Int
    let domesticDestinations: Int
    let internationalDestinations: Int
    let countries: Int
    /// 按国家/地区聚合（已按数量降序），用于构成环
    let countryData: [(name: String, count: Int)]
    let yearlyData: [(year: Int, count: Int)]
    let userName: String
}

struct StatsImageGenerator {
    /// 与「旅行统计」卡片一致：品牌色（分享图无 ColorScheme，取当前品牌色）
    private static var shareBrandUIColor: UIColor {
        UIColor(BrandColorManager.shared.currentBrandColor)
    }
    
    private static let contentPad: CGFloat = 60
    private static let statsRingDiameter: CGFloat = 360
    private static let statsRingLineWidth: CGFloat = 34
    private static let headerAvatarSize: CGFloat = 72
    private static let headerAvatarToTitle: CGFloat = 20
    private static let headerUserNameFontSize: CGFloat = 28
    private static let headerUserNameSpacing: CGFloat = 16
    private static let legendFontSize: CGFloat = 26
    private static let legendChipHeight: CGFloat = 48
    private static let legendDotSize: CGFloat = 12
    private static let legendChipSpacing: CGFloat = 12
    private static let legendChipLeading: CGFloat = 16
    private static let legendDotTextGap: CGFloat = 8
    private static let legendChipTrailing: CGFloat = 16
    private static let timelineBarHeight: CGFloat = 48
    private static let timelineBadgeDiameter: CGFloat = 56
    private static let timelineRowHeight: CGFloat = 100
    private static let sideStatGap: CGFloat = 32
    private static let sideStatIconDiameter: CGFloat = 80
    private static let sideStatValueFontSize: CGFloat = 64
    
    /// 计算图片动态高度
    private static func calculateImageHeight(stats: TravelStats, width: CGFloat) -> CGFloat {
        var totalHeight: CGFloat = 0
        
        // 顶部：头像行 + 标题
        totalHeight += 60 // 顶部边距
        totalHeight += headerAvatarSize
        totalHeight += headerAvatarToTitle
        totalHeight += estimatedTitleHeight(
            title: "stats_share_my_travel_footprint".localized,
            width: width - contentPad * 2
        )
        totalHeight += 36 // 标题到统计区
        
        // 旅行统计：区块标题 + 构成环 + 国家图例
        totalHeight += 56 // 区块标题行
        totalHeight += statsRingDiameter
        totalHeight += 28 // 环到图例
        let legendWidth = width - contentPad * 2
        let legendSegments = countryRingSegments(from: stats.countryData, brand: shareBrandUIColor)
        totalHeight += estimatedLegendHeight(segments: legendSegments, width: legendWidth)
        totalHeight += 36 // 区块底部间距
        
        // 足迹时光 / 时间线
        if !stats.yearlyData.isEmpty {
            let timelineHeaderHeight: CGFloat = 56
            let timelineItemHeight: CGFloat = timelineRowHeight
            let timelineTopBottomPadding: CGFloat = 36
            let maxYears = min(stats.yearlyData.count, 10)
            let timelineContentHeight = timelineHeaderHeight + CGFloat(maxYears) * timelineItemHeight + timelineTopBottomPadding
            totalHeight += timelineContentHeight
            totalHeight += 24
        }
        
        // 底部品牌区域（品牌字 26 + 间距 + 日期 22，并留出底边）
        totalHeight += 64
        totalHeight += 32
        totalHeight += 10
        totalHeight += 28
        totalHeight += 48
        
        return totalHeight
    }
    
    private static func estimatedTitleHeight(title: String, width: CGFloat) -> CGFloat {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold)
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let textRect = titleString.boundingRect(
            with: CGSize(width: width, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(textRect.height)
    }
    
    /// 生成旅行统计分享图片
    static func generateStatsImage(stats: TravelStats) -> UIImage? {
        let imageWidth: CGFloat = 1080
        let imageHeight = calculateImageHeight(stats: stats, width: imageWidth)
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            drawGradientBackground(in: cgContext, size: imageSize)
            
            var currentY: CGFloat = 60
            
            currentY = drawHeader(at: currentY, width: imageSize.width, context: cgContext)
            currentY += 36
            
            currentY = drawTravelStatisticsSection(
                stats: stats,
                at: currentY,
                width: imageSize.width,
                context: cgContext
            )
            
            currentY += 36
            
            if !stats.yearlyData.isEmpty {
                currentY = drawTimeline(
                    yearlyData: stats.yearlyData,
                    at: currentY,
                    width: imageSize.width,
                    context: cgContext
                )
            }
            
            drawFooter(at: imageSize.height - 110, width: imageSize.width, context: cgContext)
        }
    }
    
    // MARK: - 背景渐变
    private static func drawGradientBackground(in context: CGContext, size: CGSize) {
        AppColorScheme.drawGradientBackground(
            in: CGRect(origin: .zero, size: size),
            context: context,
            colorScheme: .light
        )
    }
    
    // MARK: - 顶部标题（对齐旅程 / 年份分享：头像 + 用户名 + 大标题）
    private static func drawHeader(at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let pad = contentPad
        var currentY = y
        let contentWidth = width - pad * 2
        
        let userInfoHeight = TripImageGenerator.drawUserInfo(
            at: CGPoint(x: pad, y: currentY),
            avatarSize: headerAvatarSize,
            context: context,
            userNameFontSize: headerUserNameFontSize,
            userNameSpacing: headerUserNameSpacing
        )
        currentY += userInfoHeight + headerAvatarToTitle
        
        let titleHeight = TripImageGenerator.drawDestinationTitle(
            title: "stats_share_my_travel_footprint".localized,
            at: CGPoint(x: pad, y: currentY),
            width: contentWidth,
            context: context
        )
        currentY += titleHeight
        
        return currentY
    }
    
    // MARK: - 旅行统计（构成环：按国家 / 地区）
    
    private struct CountryRingSegment {
        let name: String
        let count: Int
        let color: UIColor
    }
    
    private static func countryRingSegments(
        from countryData: [(name: String, count: Int)],
        brand: UIColor
    ) -> [CountryRingSegment] {
        let sorted = countryData.filter { $0.count > 0 }
        guard !sorted.isEmpty else { return [] }
        
        let palette = countrySegmentPalette(brand: brand)
        return sorted.enumerated().map { index, item in
            CountryRingSegment(
                name: item.name,
                count: item.count,
                color: palette[index % palette.count]
            )
        }
    }
    
    private static func countrySegmentPalette(brand: UIColor) -> [UIColor] {
        [
            brand,
            brand.withAlphaComponent(0.78),
            UIColor.systemCyan.withAlphaComponent(0.85),
            UIColor.systemIndigo.withAlphaComponent(0.75),
            UIColor.systemTeal.withAlphaComponent(0.8),
            UIColor.systemPurple.withAlphaComponent(0.7),
            UIColor.systemOrange.withAlphaComponent(0.75),
            UIColor.systemMint.withAlphaComponent(0.8)
        ]
    }
    
    private static func legendChipWidth(for text: String) -> CGFloat {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: legendFontSize, weight: .semibold)
        ]
        let textSize = NSAttributedString(string: text, attributes: textAttributes).size()
        return legendChipLeading + legendDotSize + legendDotTextGap + textSize.width + legendChipTrailing
    }
    
    private static func estimatedLegendHeight(segments: [CountryRingSegment], width: CGFloat) -> CGFloat {
        guard !segments.isEmpty else { return 0 }
        var x: CGFloat = 0
        var rows = 1
        
        for segment in segments {
            let chipWidth = legendChipWidth(for: "\(segment.name)  \(segment.count)")
            if x > 0, x + chipWidth > width {
                rows += 1
                x = 0
            }
            x += chipWidth + legendChipSpacing
        }
        return CGFloat(rows) * legendChipHeight + CGFloat(max(rows - 1, 0)) * legendChipSpacing
    }
    
    private static func drawTravelStatisticsSection(
        stats: TravelStats,
        at y: CGFloat,
        width: CGFloat,
        context: CGContext
    ) -> CGFloat {
        let pad = contentPad
        let brand = shareBrandUIColor
        var currentY = y
        
        if let icon = UIImage(systemName: "chart.bar.fill") {
            let iconSide: CGFloat = 32
            let iconRect = CGRect(x: pad, y: currentY, width: iconSide, height: iconSide)
            icon.withTintColor(brand, renderingMode: .alwaysOriginal).draw(in: iconRect)
        }
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let titleString = NSAttributedString(string: "travel_statistics".localized, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: pad + 42, y: currentY + 4))
        currentY += 56
        
        let segments = countryRingSegments(from: stats.countryData, brand: brand)
        let ringDiameter = statsRingDiameter
        let lineWidth = statsRingLineWidth
        let sideMetrics = countrySideStatMetrics(countries: stats.countries)
        let contentWidth = width - pad * 2
        let naturalGroupWidth = ringDiameter + sideStatGap + sideMetrics.width
        let groupX = pad + max((contentWidth - naturalGroupWidth) / 2, 0)
        let ringFrame = CGRect(
            x: groupX,
            y: currentY,
            width: ringDiameter,
            height: ringDiameter
        )
        let ringCenter = CGPoint(x: ringFrame.midX, y: ringFrame.midY)
        
        drawCountryCompositionRing(
            segments: segments,
            center: ringCenter,
            diameter: ringDiameter,
            lineWidth: lineWidth,
            trackColor: UIColor(white: 0, alpha: 0.08),
            context: context
        )
        
        drawRingCenterLabel(
            total: stats.totalDestinations,
            center: ringCenter
        )
        
        drawCountriesSideStat(
            metrics: sideMetrics,
            brandColor: brand,
            ringFrame: ringFrame
        )
        
        currentY += ringDiameter + 28
        
        currentY = drawCountryLegend(
            segments: segments,
            at: currentY,
            x: pad,
            width: width - pad * 2
        )
        
        currentY += 36
        return currentY
    }
    
    private static func drawCountryCompositionRing(
        segments: [CountryRingSegment],
        center: CGPoint,
        diameter: CGFloat,
        lineWidth: CGFloat,
        trackColor: UIColor,
        context: CGContext
    ) {
        let radius = (diameter - lineWidth) / 2
        let total = max(segments.reduce(0) { $0 + $1.count }, 0)
        
        context.saveGState()
        context.setLineWidth(lineWidth)
        context.setLineCap(.butt)
        
        context.setStrokeColor(trackColor.cgColor)
        context.addArc(
            center: center,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )
        context.strokePath()
        
        guard total > 0, !segments.isEmpty else {
            context.restoreGState()
            return
        }
        
        let count = segments.count
        let gap: CGFloat = count > 1 ? min(0.025, (0.12 * .pi * 2) / CGFloat(count)) : 0
        let usable: CGFloat = .pi * 2 - gap * CGFloat(count)
        let raw = segments.map { usable * CGFloat($0.count) / CGFloat(total) }
        let minSweep = min(0.04, usable / CGFloat(count))
        var sweeps = raw.map { max($0, minSweep) }
        let sweepSum = sweeps.reduce(0, +)
        if sweepSum > usable, sweepSum > 0 {
            let scale = usable / sweepSum
            sweeps = sweeps.map { $0 * scale }
        }
        var cursor: CGFloat = -.pi / 2
        
        for (index, segment) in segments.enumerated() {
            let sweep = sweeps[index]
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(
                center: center,
                radius: radius,
                startAngle: cursor,
                endAngle: cursor + sweep,
                clockwise: false
            )
            context.strokePath()
            cursor += sweep
            if index < segments.count - 1 {
                cursor += gap
            }
        }
        
        context.restoreGState()
    }
    
    private static func drawRingCenterLabel(total: Int, center: CGPoint) {
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 64, weight: .black),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
            .kern: -1.4 as CGFloat
        ]
        let valueString = NSAttributedString(string: "\(total)", attributes: valueAttributes)
        let valueSize = valueString.size()
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let labelString = NSAttributedString(string: "total_destinations".localized, attributes: labelAttributes)
        let labelSize = labelString.size()
        
        let stackHeight = valueSize.height + 6 + labelSize.height
        let valueY = center.y - stackHeight / 2
        valueString.draw(at: CGPoint(x: center.x - valueSize.width / 2, y: valueY))
        labelString.draw(at: CGPoint(x: center.x - labelSize.width / 2, y: valueY + valueSize.height + 6))
    }
    
    private struct CountrySideStatMetrics {
        let width: CGFloat
        let valueString: NSAttributedString
        let valueSize: CGSize
        let labelString: NSAttributedString
        let labelSize: CGSize
    }
    
    private static func countrySideStatMetrics(countries: Int) -> CountrySideStatMetrics {
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: sideStatValueFontSize, weight: .black),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
            .kern: -1.2 as CGFloat
        ]
        let valueString = NSAttributedString(string: "\(countries)", attributes: valueAttributes)
        let valueSize = valueString.size()
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let labelString = NSAttributedString(string: "countries_visited".localized, attributes: labelAttributes)
        let labelSize = labelString.size()
        
        let width = max(sideStatIconDiameter, ceil(valueSize.width), ceil(labelSize.width))
        return CountrySideStatMetrics(
            width: width,
            valueString: valueString,
            valueSize: valueSize,
            labelString: labelString,
            labelSize: labelSize
        )
    }
    
    private static func drawCountriesSideStat(
        metrics: CountrySideStatMetrics,
        brandColor: UIColor,
        ringFrame: CGRect
    ) {
        let sideX = ringFrame.maxX + sideStatGap
        let iconGap: CGFloat = 12
        let labelGap: CGFloat = 8
        let stackHeight = sideStatIconDiameter + iconGap + metrics.valueSize.height + labelGap + metrics.labelSize.height
        var cursorY = ringFrame.midY - stackHeight / 2
        
        let miniRect = CGRect(
            x: sideX,
            y: cursorY,
            width: sideStatIconDiameter,
            height: sideStatIconDiameter
        )
        let miniPath = UIBezierPath(ovalIn: miniRect.insetBy(dx: 4, dy: 4))
        brandColor.withAlphaComponent(0.14).setFill()
        miniPath.fill()
        
        if let icon = UIImage(systemName: "globe.asia.australia.fill") {
            let iconSide: CGFloat = 32
            let iconRect = CGRect(
                x: miniRect.midX - iconSide / 2,
                y: miniRect.midY - iconSide / 2,
                width: iconSide,
                height: iconSide
            )
            icon.withTintColor(brandColor, renderingMode: .alwaysOriginal).draw(in: iconRect)
        }
        
        cursorY = miniRect.maxY + iconGap
        metrics.valueString.draw(at: CGPoint(x: sideX, y: cursorY))
        cursorY += metrics.valueSize.height + labelGap
        metrics.labelString.draw(at: CGPoint(x: sideX, y: cursorY))
    }
    
    private static func drawCountryLegend(
        segments: [CountryRingSegment],
        at y: CGFloat,
        x: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        guard !segments.isEmpty else { return y }
        
        var cursorX = x
        var cursorY = y
        
        for segment in segments {
            let text = "\(segment.name)  \(segment.count)"
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: legendFontSize, weight: .semibold),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ]
            let textString = NSAttributedString(string: text, attributes: textAttributes)
            let textSize = textString.size()
            let chipWidth = legendChipWidth(for: text)
            
            if cursorX > x, cursorX + chipWidth > x + width {
                cursorX = x
                cursorY += legendChipHeight + legendChipSpacing
            }
            
            let chipRect = CGRect(x: cursorX, y: cursorY, width: chipWidth, height: legendChipHeight)
            let chipPath = UIBezierPath(roundedRect: chipRect, cornerRadius: legendChipHeight / 2)
            UIColor(white: 0, alpha: 0.05).setFill()
            chipPath.fill()
            
            let dotRect = CGRect(
                x: cursorX + legendChipLeading,
                y: cursorY + (legendChipHeight - legendDotSize) / 2,
                width: legendDotSize,
                height: legendDotSize
            )
            segment.color.setFill()
            UIBezierPath(ovalIn: dotRect).fill()
            
            let textX = cursorX + legendChipLeading + legendDotSize + legendDotTextGap
            textString.draw(at: CGPoint(x: textX, y: cursorY + (legendChipHeight - textSize.height) / 2))
            cursorX += chipWidth + legendChipSpacing
        }
        
        return cursorY + legendChipHeight
    }
    
    // MARK: - 足迹时光 / 时间线
    private static func drawTimeline(yearlyData: [(year: Int, count: Int)], at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let pad = contentPad
        let itemHeight = timelineRowHeight
        let brand = shareBrandUIColor
        let barEndColor = timelineEndColor(from: brand)
        
        var currentY = y + 8
        
        if let iconImage = UIImage(systemName: "clock.fill") {
            let iconSize: CGFloat = 30
            let iconRect = CGRect(x: pad, y: currentY, width: iconSize, height: iconSize)
            iconImage.withTintColor(brand, renderingMode: .alwaysOriginal).draw(in: iconRect)
        }
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let titleString = NSAttributedString(string: "travel_timeline".localized, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: pad + 42, y: currentY + 4))
        
        currentY += 56
        
        let sortedYearlyData = Array(yearlyData.sorted { $0.year > $1.year }.prefix(10))
        let maxCount = max(sortedYearlyData.map { $0.count }.max() ?? 1, 1)
        
        let leftColumnWidth: CGFloat = 150
        let barX = pad + leftColumnWidth
        let barRight = width - pad
        let barWidth = max(barRight - barX, timelineBadgeDiameter)
        let barHeight = timelineBarHeight
        let badgeDiameter = timelineBadgeDiameter
        let badgeRadius = badgeDiameter / 2
        let yearFont = UIFont.systemFont(ofSize: 40, weight: .semibold)
        
        for data in sortedYearlyData {
            let rowMidY = currentY + itemHeight / 2
            
            let yearAttributes: [NSAttributedString.Key: Any] = [
                .font: yearFont,
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ]
            let yearString = NSAttributedString(string: "\(data.year)", attributes: yearAttributes)
            let yearSize = yearString.size()
            yearString.draw(at: CGPoint(x: pad, y: rowMidY - yearSize.height / 2))
            
            let barY = rowMidY - barHeight / 2
            let trackRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
            let trackPath = UIBezierPath(roundedRect: trackRect, cornerRadius: barHeight / 2)
            context.saveGState()
            context.addPath(trackPath.cgPath)
            context.setFillColor(UIColor(white: 0, alpha: 0.08).cgColor)
            context.fillPath()
            context.restoreGState()
            
            let progress = min(max(CGFloat(data.count) / CGFloat(maxCount), 0), 1)
            let minCenterX = barX + badgeRadius
            let maxCenterX = barRight - badgeRadius
            let centerX = minCenterX + (maxCenterX - minCenterX) * progress
            let fillWidth = max(centerX - barX, 1)
            let fillRect = CGRect(x: barX, y: barY, width: fillWidth, height: barHeight)
            let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: barHeight / 2)
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [brand.cgColor, barEndColor.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                context.saveGState()
                context.addPath(fillPath.cgPath)
                context.clip()
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: barX, y: barY),
                    end: CGPoint(x: barRight, y: barY),
                    options: []
                )
                context.restoreGState()
            } else {
                context.saveGState()
                context.addPath(fillPath.cgPath)
                context.setFillColor(brand.cgColor)
                context.fillPath()
                context.restoreGState()
            }
            
            let badgeRect = CGRect(
                x: centerX - badgeRadius,
                y: rowMidY - badgeRadius,
                width: badgeDiameter,
                height: badgeDiameter
            )
            UIColor.white.setFill()
            UIBezierPath(ovalIn: badgeRect).fill()
            
            let ringWidth: CGFloat = 3.5
            let ringPath = UIBezierPath(ovalIn: badgeRect.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))
            ringPath.lineWidth = ringWidth
            barEndColor.setStroke()
            ringPath.stroke()
            
            let countText = "\(data.count)"
            let countFontSize: CGFloat = countText.count >= 3 ? 18 : 22
            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: countFontSize, weight: .bold),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ]
            let countString = NSAttributedString(string: countText, attributes: countAttributes)
            let countSize = countString.size()
            countString.draw(at: CGPoint(
                x: centerX - countSize.width / 2,
                y: rowMidY - countSize.height / 2
            ))
            
            currentY += itemHeight
        }
        
        currentY += 28
        return currentY
    }
    
    /// 进度条右端色：色相只推移约 14°，饱和度降低、亮度抬高，避免尖端沉成深色。
    private static func timelineEndColor(from brand: UIColor) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard brand.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return brand
        }
        let shiftedHue = (hue + 0.04).truncatingRemainder(dividingBy: 1)
        return UIColor(
            hue: shiftedHue,
            saturation: min(max(saturation * 0.75, 0), 1),
            brightness: min(brightness + 0.16, 1),
            alpha: alpha
        )
    }
    
    // MARK: - 底部标识
    private static func drawFooter(at y: CGFloat, width: CGFloat, context: CGContext) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let footerString = NSAttributedString(string: "stats_share_footer".localized, attributes: footerAttributes)
        let footerSize = footerString.size()
        footerString.draw(at: CGPoint(x: (width - footerSize.width) / 2, y: y))
        
        let dateFormatter = LanguageManager.shared.localizedDateFormatter()
        dateFormatter.dateFormat = LanguageManager.shared.localizedDateFormat()
        let dateString = dateFormatter.string(from: Date())
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let dateAttributedString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateSize = dateAttributedString.size()
        dateAttributedString.draw(at: CGPoint(x: (width - dateSize.width) / 2, y: y + footerSize.height + 10))
    }
}
