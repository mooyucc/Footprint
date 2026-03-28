//
//  StatsImageGenerator.swift
//  Footprint
//
//  Created on 2025/10/22.
//

import SwiftUI
import UIKit

struct TravelStats {
    let totalDestinations: Int
    let domesticDestinations: Int
    let internationalDestinations: Int
    let countries: Int
    let yearlyData: [(year: Int, count: Int)]
    let userName: String
}

struct StatsImageGenerator {
    /// 与「旅行统计」卡片一致：品牌色（分享图无 ColorScheme，取当前品牌色）
    private static var shareBrandUIColor: UIColor {
        UIColor(BrandColorManager.shared.currentBrandColor)
    }
    
    /// 计算图片动态高度
    private static func calculateImageHeight(stats: TravelStats, width: CGFloat) -> CGFloat {
        var totalHeight: CGFloat = 0
        
        // 顶部区域高度
        totalHeight += 60 // 顶部边距
        totalHeight += 80 // 图标高度
        totalHeight += 20 // 图标与用户名间距
        totalHeight += 42 // 用户名高度
        totalHeight += 15 // 用户名与副标题间距
        totalHeight += 24 // 副标题高度
        totalHeight += 40 // 顶部区域底部边距
        
        // 旅行统计：区块标题 + 2×2 栅格（无卡片背景，与 App 一致）
        totalHeight += 56 // 区块标题行
        let cellH: CGFloat = 168
        let rowGap: CGFloat = 28
        totalHeight += cellH * 2 + rowGap // 两行栅格
        totalHeight += 32 // 区块底部间距（与 drawTravelStatisticsSection 一致）
        
        // 足迹时光 / 时间线（无大卡片背景）
        if !stats.yearlyData.isEmpty {
            let timelineHeaderHeight: CGFloat = 56
            let timelineItemHeight: CGFloat = 78
            let timelineTopBottomPadding: CGFloat = 36 // 与 drawTimeline 顶部/底部留白相当
            let maxYears = min(stats.yearlyData.count, 10)
            let timelineContentHeight = timelineHeaderHeight + CGFloat(maxYears) * timelineItemHeight + timelineTopBottomPadding
            totalHeight += timelineContentHeight
            totalHeight += 24
        }
        
        // 底部品牌区域
        totalHeight += 60 // 底部边距
        totalHeight += 22 // 品牌文字高度
        totalHeight += 8 // 文字间距
        totalHeight += 18 // 日期文字高度
        totalHeight += 60 // 底部边距
        
        return totalHeight
    }
    
    /// 生成旅行统计分享图片
    static func generateStatsImage(stats: TravelStats) -> UIImage? {
        // 计算动态高度
        let imageWidth: CGFloat = 1080
        let imageHeight = calculateImageHeight(stats: stats, width: imageWidth)
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        
        // 创建图片渲染器（禁用Alpha通道，避免不必要的透明通道占用）
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0  // 固定为1.0，确保输出图片宽度为1080像素（不受设备屏幕缩放影响）
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 1. 绘制渐变背景
            drawGradientBackground(in: cgContext, size: imageSize)
            
            var currentY: CGFloat = 60
            
            // 2. 绘制顶部标题区域
            currentY = drawHeader(userName: stats.userName, at: currentY, width: imageSize.width, context: cgContext)
            
            currentY += 40
            
            // 3. 旅行统计（标题 + 2×2，与「我的」页现代风格一致）
            currentY = drawTravelStatisticsSection(stats: stats, at: currentY, width: imageSize.width)
            
            currentY += 32
            
            // 4. 绘制时间线
            if !stats.yearlyData.isEmpty {
                currentY = drawTimeline(yearlyData: stats.yearlyData, at: currentY, width: imageSize.width, context: cgContext)
            }
            
            // 5. 绘制底部品牌标识
            drawFooter(at: imageSize.height - 80, width: imageSize.width, context: cgContext)
        }
    }
    
    // MARK: - 背景渐变
    /// 使用 AppColorScheme 统一方法
    private static func drawGradientBackground(in context: CGContext, size: CGSize) {
        AppColorScheme.drawGradientBackground(in: CGRect(origin: .zero, size: size), context: context)
    }
    
    // MARK: - 顶部标题
    private static func drawHeader(userName: String, at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        var currentY = y
        
        // 绘制装饰图标
        if let icon = UIImage(systemName: "airplane.circle.fill") {
            let iconSize: CGFloat = 80
            let iconRect = CGRect(
                x: (width - iconSize) / 2,
                y: currentY,
                width: iconSize,
                height: iconSize
            )
            
            // 使用深灰色渲染图标，与"我的"tab风格一致
            let tintedIcon = icon.withTintColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        currentY += 100
        
        // 绘制用户名 - 使用深灰色 #333333
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let nameString = NSAttributedString(string: userName, attributes: nameAttributes)
        let nameSize = nameString.size()
        nameString.draw(at: CGPoint(x: (width - nameSize.width) / 2, y: currentY))
        
        currentY += nameSize.height + 15
        
        // 绘制副标题 - 使用次要文本颜色
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本
        ]
        let subtitleString = NSAttributedString(string: "stats_share_my_travel_footprint".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: (width - subtitleSize.width) / 2, y: currentY))
        
        currentY += subtitleSize.height
        
        return currentY
    }
    
    // MARK: - 旅行统计（与 App 内 ProfileStatCard 栅格一致）
    private static func drawTravelStatisticsSection(stats: TravelStats, at y: CGFloat, width: CGFloat) -> CGFloat {
        let pad: CGFloat = 60
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
        
        let colGap: CGFloat = 24
        let rowGap: CGFloat = 28
        let cellW = (width - pad * 2 - colGap) / 2
        let cellH: CGFloat = 168
        
        let gridItems: [(icon: String, value: Int, labelKey: String)] = [
            ("flag.fill", stats.totalDestinations, "total_destinations"),
            ("globe.asia.australia.fill", stats.countries, "countries_visited"),
            ("house.fill", stats.domesticDestinations, "domestic_travel"),
            ("airplane", stats.internationalDestinations, "international_travel")
        ]
        
        for (index, item) in gridItems.enumerated() {
            let col = index % 2
            let row = index / 2
            let cellX = pad + CGFloat(col) * (cellW + colGap)
            let cellY = currentY + CGFloat(row) * (cellH + rowGap)
            let cellRect = CGRect(x: cellX, y: cellY, width: cellW, height: cellH)
            drawProfileStyleStatCell(
                iconName: item.icon,
                value: item.value,
                label: item.labelKey.localized,
                brandColor: brand,
                in: cellRect
            )
        }
        
        currentY += cellH * 2 + rowGap + 32
        return currentY
    }
    
    private static func drawProfileStyleStatCell(
        iconName: String,
        value: Int,
        label: String,
        brandColor: UIColor,
        in rect: CGRect
    ) {
        var y = rect.minY
        let iconSide: CGFloat = 36
        if let iconImage = UIImage(systemName: iconName) {
            let iconRect = CGRect(x: rect.minX, y: y, width: iconSide, height: iconSide)
            iconImage.withTintColor(brandColor, renderingMode: .alwaysOriginal).draw(in: iconRect)
        }
        y += iconSide + 14
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 58, weight: .black),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
            .kern: -1.2 as CGFloat
        ]
        let valueString = NSAttributedString(string: "\(value)", attributes: valueAttributes)
        valueString.draw(at: CGPoint(x: rect.minX, y: y))
        y += valueString.size().height + 10
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        let maxLabelWidth = rect.width
        let bounding = labelString.boundingRect(
            with: CGSize(width: maxLabelWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        labelString.draw(in: CGRect(x: rect.minX, y: y, width: maxLabelWidth, height: ceil(bounding.height)))
    }
    
    // MARK: - 足迹时光 / 时间线（无卡片底板，与 App 列表风格一致）
    private static func drawTimeline(yearlyData: [(year: Int, count: Int)], at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let pad: CGFloat = 60
        let itemHeight: CGFloat = 78
        let maxYears = min(yearlyData.count, 10)
        let brand = shareBrandUIColor
        
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
        
        let leftColumnWidth: CGFloat = 120
        let rightNumberReserve: CGFloat = 100
        let barX = pad + leftColumnWidth
        let barRight = width - pad - rightNumberReserve
        let barWidth = max(barRight - barX, 80)
        let barHeight: CGFloat = 10
        
        for data in sortedYearlyData {
            let yearAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ]
            let yearString = NSAttributedString(string: "\(data.year)", attributes: yearAttributes)
            yearString.draw(at: CGPoint(x: pad, y: currentY))
            
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            ]
            let captionString = NSAttributedString(string: "destinations_count".localized, attributes: captionAttributes)
            captionString.draw(at: CGPoint(x: pad, y: currentY + 32))
            
            let barY = currentY + 26
            let bgBarRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
            let bgBarPath = UIBezierPath(roundedRect: bgBarRect, cornerRadius: barHeight / 2)
            context.saveGState()
            context.addPath(bgBarPath.cgPath)
            context.setFillColor(UIColor(white: 0, alpha: 0.08).cgColor)
            context.fillPath()
            context.restoreGState()
            
            let progress = CGFloat(data.count) / CGFloat(maxCount)
            let progressWidth = max(barWidth * progress, barHeight)
            
            let progressBarRect = CGRect(x: barX, y: barY, width: progressWidth, height: barHeight)
            let progressBarPath = UIBezierPath(roundedRect: progressBarRect, cornerRadius: barHeight / 2)
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [brand.cgColor, UIColor.systemPurple.cgColor] as CFArray
            
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                context.saveGState()
                context.addPath(progressBarPath.cgPath)
                context.clip()
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: barX, y: barY),
                    end: CGPoint(x: barX + progressWidth, y: barY + barHeight),
                    options: []
                )
                context.restoreGState()
            } else {
                context.saveGState()
                context.addPath(progressBarPath.cgPath)
                context.setFillColor(brand.cgColor)
                context.fillPath()
                context.restoreGState()
            }
            
            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 36, weight: .black),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
                .kern: -0.8 as CGFloat
            ]
            let countString = NSAttributedString(string: "\(data.count)", attributes: countAttributes)
            let countSize = countString.size()
            countString.draw(at: CGPoint(x: width - pad - countSize.width, y: currentY + 18))
            
            currentY += itemHeight
        }
        
        currentY += 28
        return currentY
    }
    
    // MARK: - 底部标识
    private static func drawFooter(at y: CGFloat, width: CGFloat, context: CGContext) {
        // 绘制品牌标识 - 使用深灰色 #333333
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let footerString = NSAttributedString(string: "stats_share_footer".localized, attributes: footerAttributes)
        let footerSize = footerString.size()
        footerString.draw(at: CGPoint(x: (width - footerSize.width) / 2, y: y))
        
        // 绘制日期 - 使用次要文本颜色
        let dateFormatter = LanguageManager.shared.localizedDateFormatter()
        dateFormatter.dateFormat = LanguageManager.shared.localizedDateFormat()
        let dateString = dateFormatter.string(from: Date())
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本
        ]
        let dateAttributedString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateSize = dateAttributedString.size()
        dateAttributedString.draw(at: CGPoint(x: (width - dateSize.width) / 2, y: y + 35))
    }
}

