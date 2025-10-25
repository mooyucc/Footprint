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
        
        // 主统计卡片
        totalHeight += 200 // 主统计卡片高度
        totalHeight += 40 // 卡片间距
        
        // 分类统计卡片
        totalHeight += 160 // 分类统计卡片高度
        totalHeight += 40 // 卡片间距
        
        // 时间线卡片
        if !stats.yearlyData.isEmpty {
            let timelineHeaderHeight: CGFloat = 60 // 标题区域
            let timelineItemHeight: CGFloat = 70 // 每行高度
            let timelinePadding: CGFloat = 50 // 上下内边距
            let maxYears = min(stats.yearlyData.count, 10) // 最多显示10年
            let timelineContentHeight = timelineHeaderHeight + CGFloat(maxYears) * timelineItemHeight + timelinePadding
            totalHeight += timelineContentHeight
            totalHeight += 40 // 卡片间距
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
        
        // 创建图片渲染器
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 1. 绘制渐变背景
            drawGradientBackground(in: cgContext, size: imageSize)
            
            var currentY: CGFloat = 60
            
            // 2. 绘制顶部标题区域
            currentY = drawHeader(userName: stats.userName, at: currentY, width: imageSize.width, context: cgContext)
            
            currentY += 40
            
            // 3. 绘制主要统计卡片
            currentY = drawMainStatsCard(stats: stats, at: currentY, width: imageSize.width, context: cgContext)
            
            currentY += 40
            
            // 4. 绘制分类统计
            currentY = drawCategoryStats(stats: stats, at: currentY, width: imageSize.width, context: cgContext)
            
            currentY += 40
            
            // 5. 绘制时间线
            if !stats.yearlyData.isEmpty {
                currentY = drawTimeline(yearlyData: stats.yearlyData, at: currentY, width: imageSize.width, context: cgContext)
            }
            
            // 6. 绘制底部品牌标识
            drawFooter(at: imageSize.height - 80, width: imageSize.width, context: cgContext)
        }
    }
    
    // MARK: - 背景渐变
    private static func drawGradientBackground(in context: CGContext, size: CGSize) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // 使用现代化的渐变色 - 从深蓝到紫色
        let colors = [
            UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0).cgColor,  // 深蓝
            UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0).cgColor   // 深紫
        ] as CFArray
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else {
            return
        }
        
        context.saveGState()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
        context.restoreGState()
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
            
            // 使用白色渲染图标
            let tintedIcon = icon.withTintColor(.white, renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        currentY += 100
        
        // 绘制用户名
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let nameString = NSAttributedString(string: userName, attributes: nameAttributes)
        let nameSize = nameString.size()
        nameString.draw(at: CGPoint(x: (width - nameSize.width) / 2, y: currentY))
        
        currentY += nameSize.height + 15
        
        // 绘制副标题
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let subtitleString = NSAttributedString(string: "stats_share_my_travel_footprint".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: (width - subtitleSize.width) / 2, y: currentY))
        
        currentY += subtitleSize.height
        
        return currentY
    }
    
    // MARK: - 主要统计卡片
    private static func drawMainStatsCard(stats: TravelStats, at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let cardWidth: CGFloat = width - 120
        let cardHeight: CGFloat = 200
        let cardX: CGFloat = (width - cardWidth) / 2
        
        // 绘制白色卡片背景
        let cardRect = CGRect(x: cardX, y: y, width: cardWidth, height: cardHeight)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 25)
        
        context.saveGState()
        context.addPath(cardPath.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: CGSize(width: 0, height: 10), blur: 30, color: UIColor.black.withAlphaComponent(0.15).cgColor)
        context.fillPath()
        context.restoreGState()
        
        // 绘制大数字
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 80, weight: .black),
            .foregroundColor: UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
        ]
        let numberString = NSAttributedString(string: "\(stats.totalDestinations)", attributes: numberAttributes)
        let numberSize = numberString.size()
        numberString.draw(at: CGPoint(x: cardRect.midX - numberSize.width / 2, y: cardRect.minY + 40))
        
        // 绘制标签
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .medium),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let labelString = NSAttributedString(string: "stats_share_destinations_count".localized, attributes: labelAttributes)
        let labelSize = labelString.size()
        labelString.draw(at: CGPoint(x: cardRect.midX - labelSize.width / 2, y: cardRect.minY + 135))
        
        return y + cardHeight
    }
    
    // MARK: - 分类统计
    private static func drawCategoryStats(stats: TravelStats, at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let cardWidth: CGFloat = width - 120
        let cardHeight: CGFloat = 160
        let cardX: CGFloat = (width - cardWidth) / 2
        
        // 绘制白色卡片背景
        let cardRect = CGRect(x: cardX, y: y, width: cardWidth, height: cardHeight)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 25)
        
        context.saveGState()
        context.addPath(cardPath.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: CGSize(width: 0, height: 10), blur: 30, color: UIColor.black.withAlphaComponent(0.15).cgColor)
        context.fillPath()
        context.restoreGState()
        
        // 计算每个统计项的宽度
        let itemWidth = cardWidth / 3
        
        // 绘制三个统计项
        let items: [(icon: String, value: Int, label: String, color: UIColor)] = [
            ("globe.asia.australia.fill", stats.countries, "stats_share_countries_count".localized, UIColor.systemGreen),
            ("house.fill", stats.domesticDestinations, "domestic".localized, UIColor.systemRed),
            ("airplane", stats.internationalDestinations, "international".localized, UIColor.systemBlue)
        ]
        
        for (index, item) in items.enumerated() {
            let centerX = cardRect.minX + itemWidth * CGFloat(index) + itemWidth / 2
            let centerY = cardRect.midY
            
            // 绘制图标
            if let iconImage = UIImage(systemName: item.icon) {
                let iconSize: CGFloat = 35
                let iconRect = CGRect(
                    x: centerX - iconSize / 2,
                    y: centerY - 60,
                    width: iconSize,
                    height: iconSize
                )
                let tintedIcon = iconImage.withTintColor(item.color, renderingMode: .alwaysOriginal)
                tintedIcon.draw(in: iconRect)
            }
            
            // 绘制数值
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: item.color
            ]
            let valueString = NSAttributedString(string: "\(item.value)", attributes: valueAttributes)
            let valueSize = valueString.size()
            valueString.draw(at: CGPoint(x: centerX - valueSize.width / 2, y: centerY - 10))
            
            // 绘制标签
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            let labelString = NSAttributedString(string: item.label, attributes: labelAttributes)
            let labelSize = labelString.size()
            labelString.draw(at: CGPoint(x: centerX - labelSize.width / 2, y: centerY + 35))
        }
        
        return y + cardHeight
    }
    
    // MARK: - 时间线
    private static func drawTimeline(yearlyData: [(year: Int, count: Int)], at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let cardWidth: CGFloat = width - 120
        let itemHeight: CGFloat = 70
        let maxYears = min(yearlyData.count, 10) // 最多显示10年
        let cardHeight: CGFloat = 60 + CGFloat(maxYears) * itemHeight + 50 // 增加底部padding
        let cardX: CGFloat = (width - cardWidth) / 2
        
        // 绘制白色卡片背景
        let cardRect = CGRect(x: cardX, y: y, width: cardWidth, height: cardHeight)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 25)
        
        context.saveGState()
        context.addPath(cardPath.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: CGSize(width: 0, height: 10), blur: 30, color: UIColor.black.withAlphaComponent(0.15).cgColor)
        context.fillPath()
        context.restoreGState()
        
        var currentY = cardRect.minY + 25
        
        // 绘制标题
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
        ]
        
        // 绘制时钟图标
        if let iconImage = UIImage(systemName: "clock.fill") {
            let iconSize: CGFloat = 24
            let iconRect = CGRect(x: cardRect.minX + 30, y: currentY, width: iconSize, height: iconSize)
            let tintedIcon = iconImage.withTintColor(UIColor.systemOrange, renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        let titleString = NSAttributedString(string: "stats_share_travel_timeline".localized, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: cardRect.minX + 65, y: currentY))
        
        currentY += 50
        
        // 绘制年份数据（最多10年）
        let sortedYearlyData = yearlyData.sorted { $0.year > $1.year }.prefix(10)
        
        for (index, data) in sortedYearlyData.enumerated() {
            // 绘制年份
            let yearAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            ]
            let yearString = NSAttributedString(string: "\(data.year)", attributes: yearAttributes)
            yearString.draw(at: CGPoint(x: cardRect.minX + 40, y: currentY))
            
            // 绘制进度条
            let barWidth: CGFloat = cardWidth - 280
            let barHeight: CGFloat = 12
            let barX = cardRect.minX + 160
            let barY = currentY + 8
            
            // 背景条
            let bgBarRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
            let bgBarPath = UIBezierPath(roundedRect: bgBarRect, cornerRadius: barHeight / 2)
            context.saveGState()
            context.addPath(bgBarPath.cgPath)
            context.setFillColor(UIColor(white: 0.9, alpha: 1.0).cgColor)
            context.fillPath()
            context.restoreGState()
            
            // 进度条（基于最大值计算比例）
            let maxCount = sortedYearlyData.map { $0.count }.max() ?? 1
            let progress = CGFloat(data.count) / CGFloat(maxCount)
            let progressWidth = max(barWidth * progress, 20) // 至少显示一点
            
            let progressBarRect = CGRect(x: barX, y: barY, width: progressWidth, height: barHeight)
            let progressBarPath = UIBezierPath(roundedRect: progressBarRect, cornerRadius: barHeight / 2)
            
            // 使用渐变色
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemPurple.cgColor
            ] as CFArray
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else {
                return currentY
            }
            
            context.saveGState()
            context.addPath(progressBarPath.cgPath)
            context.clip()
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: barX, y: barY),
                end: CGPoint(x: barX + progressWidth, y: barY),
                options: []
            )
            context.restoreGState()
            
            // 绘制数量
            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.systemBlue
            ]
            let countString = NSAttributedString(string: "\(data.count)", attributes: countAttributes)
            let countSize = countString.size()
            countString.draw(at: CGPoint(x: cardRect.maxX - countSize.width - 40, y: currentY))
            
            currentY += itemHeight
        }
        
        return y + cardHeight
    }
    
    // MARK: - 底部标识
    private static func drawFooter(at y: CGFloat, width: CGFloat, context: CGContext) {
        // 绘制品牌标识
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let footerString = NSAttributedString(string: "stats_share_footer".localized, attributes: footerAttributes)
        let footerSize = footerString.size()
        footerString.draw(at: CGPoint(x: (width - footerSize.width) / 2, y: y))
        
        // 绘制日期
        let dateFormatter = LanguageManager.shared.localizedDateFormatter()
        dateFormatter.dateFormat = LanguageManager.shared.localizedDateFormat()
        let dateString = dateFormatter.string(from: Date())
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        let dateAttributedString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateSize = dateAttributedString.size()
        dateAttributedString.draw(at: CGPoint(x: (width - dateSize.width) / 2, y: y + 35))
    }
}

