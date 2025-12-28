//
//  YearImageGenerator.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI
import UIKit

// MARK: - 年份图片生成器
struct YearImageGenerator {
    /// 生成年份记录分享图片（使用默认清单版面，保持向后兼容）
    static func generateYearImage(year: Int, destinations: [TravelDestination]) -> UIImage? {
        return generateYearImage(year: year, destinations: destinations, layout: .list)
    }
    
    /// 根据版面类型生成年份记录分享图片（复用 TripShareLayout 枚举）
    static func generateYearImage(year: Int, destinations: [TravelDestination], layout: TripShareLayout) -> UIImage? {
        switch layout {
        case .list:
            return YearListLayoutGenerator().generateImage(year: year, destinations: destinations)
        case .grid:
            return YearGridLayoutGenerator().generateImage(year: year, destinations: destinations)
        case .extendedGrid:
            return YearExtendedGridLayoutGenerator().generateImage(year: year, destinations: destinations)
        }
    }
    
    // MARK: - 背景渐变（共享方法）
    /// 使用 AppColorScheme 统一方法
    static func drawGradientBackground(in rect: CGRect, context: CGContext) {
        AppColorScheme.drawGradientBackground(in: rect, context: context)
    }
    
    // MARK: - 绘制标题（共享方法）
    static func drawTitle(_ title: String, at point: CGPoint, width: CGFloat, context: CGContext) {
        let fontSize = calculateDynamicTitleFontSize(for: title, availableWidth: width)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), // 黑色
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 4
                return style
            }()
        ]
        
        let attributedString = NSAttributedString(string: title, attributes: titleAttributes)
        let maxHeight: CGFloat = fontSize * 2.5
        let textRect = attributedString.boundingRect(
            with: CGSize(width: width, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let drawRect = CGRect(
            x: point.x,
            y: point.y,
            width: width,
            height: ceil(textRect.height)
        )
        
        attributedString.draw(in: drawRect)
    }
    
    // MARK: - 绘制统计信息卡片（共享方法）
    static func drawStatisticsCard(year: Int, destinations: [TravelDestination], at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let cardHeight: CGFloat = 100
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: cardHeight)
        
        // 绘制圆角卡片背景
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 20)
        context.saveGState()
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        context.fillPath()
        context.restoreGState()
        
        // 计算统计数据
        let countryManager = CountryManager.shared
        let total = destinations.count
        let domestic = destinations.filter { countryManager.isDomestic(country: $0.country) }.count
        let international = destinations.filter { !countryManager.isDomestic(country: $0.country) }.count
        let countries = Set(destinations.map { $0.country }).count
        
        let centerY = cardRect.midY
        let itemWidth = width / 4
        
        // 绘制分割线
        let lineY1 = cardRect.minY + 25
        let lineY2 = cardRect.maxY - 25
        let lineX1 = cardRect.minX + itemWidth
        let lineX2 = cardRect.minX + itemWidth * 2
        let lineX3 = cardRect.minX + itemWidth * 3
        
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.06).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: lineX1, y: lineY1))
        context.addLine(to: CGPoint(x: lineX1, y: lineY2))
        context.move(to: CGPoint(x: lineX2, y: lineY1))
        context.addLine(to: CGPoint(x: lineX2, y: lineY2))
        context.move(to: CGPoint(x: lineX3, y: lineY1))
        context.addLine(to: CGPoint(x: lineX3, y: lineY2))
        context.strokePath()
        
        // 绘制统计项
        drawStatItem("total_destinations".localized, value: "\(total)", icon: "map.fill", at: CGPoint(x: cardRect.minX + itemWidth/2, y: centerY), context: context)
        drawStatItem("domestic".localized, value: "\(domestic)", icon: "house.fill", at: CGPoint(x: cardRect.minX + itemWidth + itemWidth/2, y: centerY), context: context)
        drawStatItem("international".localized, value: "\(international)", icon: "airplane", at: CGPoint(x: cardRect.minX + itemWidth*2 + itemWidth/2, y: centerY), context: context)
        drawStatItem("countries".localized, value: "\(countries)", icon: "globe.asia.australia.fill", at: CGPoint(x: cardRect.minX + itemWidth*3 + itemWidth/2, y: centerY), context: context)
        
        return cardHeight
    }
    
    static func drawStatItem(_ label: String, value: String, icon: String, at point: CGPoint, context: CGContext) {
        // 绘制图标
        let iconImage = UIImage(systemName: icon)
        if let iconImage = iconImage {
            let iconSize: CGFloat = 16
            let iconRect = CGRect(x: point.x - iconSize/2, y: point.y - 30, width: iconSize, height: iconSize)
            let tintedIcon = iconImage.withTintColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        // 绘制标签
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        let labelSize = labelString.size()
        let labelRect = CGRect(x: point.x - labelSize.width/2, y: point.y - 10, width: labelSize.width, height: labelSize.height)
        labelString.draw(in: labelRect)
        
        // 绘制值
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        let valueSize = valueString.size()
        let valueRect = CGRect(x: point.x - valueSize.width/2, y: point.y + 10, width: valueSize.width, height: valueSize.height)
        valueString.draw(in: valueRect)
    }
    
    // MARK: - 绘制目的地列表卡片（共享方法，使用卡片样式）
    static func drawDestinationsCard(destinations: [TravelDestination], at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let sortedDestinations = destinations.sorted { $0.visitDate < $1.visitDate }
        let displayCount = sortedDestinations.count // 显示所有目的地
        let destinationCount = sortedDestinations.count
        
        var currentY = point.y
        let headerHeight: CGFloat = 50
        let cardHeight: CGFloat = 160
        let cardSpacing: CGFloat = 12
        
        // 计算总高度（卡片样式）
        let totalCardsHeight = displayCount > 0 ? CGFloat(displayCount) * cardHeight + CGFloat(displayCount - 1) * cardSpacing : 0
        let totalHeight = headerHeight + (displayCount > 0 ? totalCardsHeight : 80) + 40
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: totalHeight)
        
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 20)
        context.saveGState()
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        context.fillPath()
        context.restoreGState()
        
        // 绘制标题
        currentY += 20
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        
        // 绘制目的地图标
        let iconImage = UIImage(systemName: "location.fill")
        if let iconImage = iconImage {
            let iconSize: CGFloat = 16
            let iconRect = CGRect(x: point.x + 20, y: currentY, width: iconSize, height: iconSize)
            let tintedIcon = iconImage.withTintColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        // 绘制标题文字
        let titleText = LanguageManager.shared.currentLanguage == .chinese ? "旅行目的地" : "Travel Destinations"
        let titleString = NSAttributedString(string: titleText, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: point.x + 50, y: currentY))
        
        let countString = NSAttributedString(string: "\(destinationCount) " + "destinations_count".localized, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ])
        let countSize = countString.size()
        countString.draw(at: CGPoint(x: point.x + width - countSize.width - 20, y: currentY))
        
        currentY += 30
        
        if displayCount > 0 {
            // 绘制所有目的地卡片列表
            for (index, destination) in sortedDestinations.enumerated() {
                drawDestinationCard(destination, at: CGPoint(x: point.x + 20, y: currentY), width: width - 40, context: context)
                currentY += cardHeight
                // 最后一个卡片不添加间距
                if index < sortedDestinations.count - 1 {
                    currentY += cardSpacing
                }
            }
        } else {
            // 绘制空状态
            let emptyText = LanguageManager.shared.currentLanguage == .chinese ? "还没有旅行记录" : "No travel records"
            let emptyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            ]
            let emptyString = NSAttributedString(string: emptyText, attributes: emptyAttributes)
            let emptySize = emptyString.size()
            emptyString.draw(at: CGPoint(x: point.x + width/2 - emptySize.width/2, y: currentY + 20))
        }
        
        return totalHeight
    }
    
    /// 绘制地点卡片（卡片样式，类似 DestinationRowCard）
    static func drawDestinationCard(_ destination: TravelDestination, at point: CGPoint, width: CGFloat, context: CGContext) {
        let cardHeight: CGFloat = 160
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: cardHeight)
        let cornerRadius: CGFloat = 12
        
        // 1. 绘制卡片背景（照片或蓝色背景）
        let backgroundPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)
        context.saveGState()
        context.addPath(backgroundPath.cgPath)
        context.clip()
        
        if let photoData = destination.photoData ?? destination.photoThumbnailData,
           let photoImage = UIImage(data: photoData) {
            // 绘制照片，保持宽高比填充
            let imageAspectRatio = photoImage.size.width / photoImage.size.height
            let rectAspectRatio = cardRect.width / cardRect.height
            
            var drawRect = cardRect
            if imageAspectRatio > rectAspectRatio {
                // 图片更宽，以高度为准
                let scaledWidth = cardRect.height * imageAspectRatio
                drawRect = CGRect(x: cardRect.midX - scaledWidth/2, y: cardRect.minY, width: scaledWidth, height: cardRect.height)
            } else {
                // 图片更高，以宽度为准
                let scaledHeight = cardRect.width / imageAspectRatio
                drawRect = CGRect(x: cardRect.minX, y: cardRect.midY - scaledHeight/2, width: cardRect.width, height: scaledHeight)
            }
            photoImage.draw(in: drawRect)
        } else {
            // 绘制默认蓝色背景 #6793C3
            context.setFillColor(UIColor(red: 0x67/255.0, green: 0x93/255.0, blue: 0xC3/255.0, alpha: 1.0).cgColor)
            context.fill(cardRect)
        }
        context.restoreGState()
        
        // 2. 绘制深色渐变遮罩（从透明到黑色，底部更暗）
        context.saveGState()
        context.addPath(backgroundPath.cgPath)
        context.clip()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.2).cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor
        ]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: [0.0, 0.5, 1.0])!
        context.drawLinearGradient(gradient, start: CGPoint(x: cardRect.midX, y: cardRect.minY), end: CGPoint(x: cardRect.midX, y: cardRect.maxY), options: [])
        context.restoreGState()
        
        // 3. 绘制左上角标签（国内/国际）
        let countryManager = CountryManager.shared
        let isDomestic = countryManager.isDomestic(country: destination.country)
        if !destination.country.isEmpty {
            let tagText = isDomestic ? "domestic".localized : "international".localized
            let tagColor = isDomestic ?
                UIColor(red: 0x3A/255.0, green: 0x8B/255.0, blue: 0xBB/255.0, alpha: 0.85) : // #3A8BBB
                UIColor(red: 0x50/255.0, green: 0xA3/255.0, blue: 0x7B/255.0, alpha: 0.85) // #50A37B
            
            let tagAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let tagString = NSAttributedString(string: tagText, attributes: tagAttributes)
            let tagSize = tagString.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
            
            let tagPaddingX: CGFloat = 8
            let tagPaddingY: CGFloat = 4
            let tagWidth = tagSize.width + tagPaddingX * 2
            let tagHeight = tagSize.height + tagPaddingY * 2
            let tagRect = CGRect(x: cardRect.minX + 16, y: cardRect.minY + 12, width: tagWidth, height: tagHeight)
            
            // 绘制胶囊形状的标签背景
            let tagPath = UIBezierPath(roundedRect: tagRect, cornerRadius: tagHeight / 2)
            context.setFillColor(tagColor.cgColor)
            context.addPath(tagPath.cgPath)
            context.fillPath()
            
            // 绘制标签文字
            tagString.draw(at: CGPoint(x: tagRect.minX + tagPaddingX, y: tagRect.midY - tagSize.height / 2))
        }
        
        // 4. 绘制底部白色文字内容
        let bottomPadding: CGFloat = 16
        var textY = cardRect.maxY - bottomPadding
        
        // 绘制地点和时间信息（caption字体）
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
        var locationText = destination.country.isEmpty ? "-" : destination.country
        if !destination.province.isEmpty {
            locationText = "\(destination.province) · \(locationText)"
        }
        let dateText = dateFormatter.string(from: destination.visitDate)
        let subtitleText = "\(locationText) · \(dateText)"
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let subtitleString = NSAttributedString(string: subtitleText, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: cardRect.minX + bottomPadding, y: textY - subtitleSize.height))
        textY -= subtitleSize.height + 2
        
        // 绘制标题（24pt粗体，带收藏图标）
        let titleText = destination.name.isEmpty ? "-" : destination.name
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let titleString = NSAttributedString(string: titleText, attributes: titleAttributes)
        let titleX = cardRect.minX + bottomPadding
        
        // 计算标题尺寸（单行显示）
        let titleSize = titleString.size()
        
        // 绘制收藏图标（如果有，先绘制以便正确计算标题位置）
        var heartWidth: CGFloat = 0
        if destination.isFavorite {
            if let heartImage = UIImage(systemName: "heart.fill") {
                let heartSize: CGFloat = 16
                let heartSpacing: CGFloat = 6
                heartWidth = heartSize + heartSpacing
                let heartX = cardRect.maxX - bottomPadding - heartSize
                let heartY = textY - titleSize.height / 2 - heartSize / 2
                let tintedHeart = heartImage.withTintColor(.systemPink, renderingMode: .alwaysOriginal)
                tintedHeart.draw(in: CGRect(x: heartX, y: heartY, width: heartSize, height: heartSize))
            }
        }
        
        // 绘制标题（限制宽度，避免与收藏图标重叠）
        let titleMaxWidth = width - bottomPadding * 2 - heartWidth
        let titleRect = titleString.boundingRect(with: CGSize(width: titleMaxWidth, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        // 如果标题过长，截断显示
        if titleRect.width > titleMaxWidth {
            // 使用单行绘制，自动截断
            titleString.draw(in: CGRect(x: titleX, y: textY - titleRect.height, width: titleMaxWidth, height: titleRect.height))
        } else {
            titleString.draw(at: CGPoint(x: titleX, y: textY - titleSize.height))
        }
        
        // 5. 绘制卡片边框和阴影
        context.saveGState()
        // 绘制阴影
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: UIColor.black.withAlphaComponent(0.08).cgColor)
        // 绘制边框（浅色半透明边框）
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.addPath(backgroundPath.cgPath)
        context.strokePath()
        context.restoreGState()
    }
    
    static func drawDestinationItem(_ destination: TravelDestination, index: Int, at point: CGPoint, width: CGFloat, context: CGContext) {
        // 绘制序号圆圈
        let circleRect = CGRect(x: point.x, y: point.y + 14, width: 32, height: 32)
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fillEllipse(in: circleRect)
        
        // 绘制序号文字
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let numberString = NSAttributedString(string: "\(index)", attributes: numberAttributes)
        let numberSize = numberString.size()
        let numberCenterX = point.x + 16
        let numberCenterY = point.y + 30
        numberString.draw(at: CGPoint(x: numberCenterX - numberSize.width/2, y: numberCenterY - numberSize.height/2))
        
        // 绘制目的地照片或图标
        let photoRect = CGRect(x: point.x + 50, y: point.y + 8, width: 50, height: 50)
        if let photoData = destination.photoThumbnailData ?? destination.photoData,
           let photoImage = UIImage(data: photoData) {
            let path = UIBezierPath(roundedRect: photoRect, cornerRadius: 8)
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()
            photoImage.draw(in: photoRect)
            context.restoreGState()
        } else {
            let iconRect = CGRect(x: point.x + 50, y: point.y + 8, width: 50, height: 50)
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 8)
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()
            
            if let defaultImage = UIImage(named: "ImageMooyu") {
                let originalImage = defaultImage.withRenderingMode(.alwaysOriginal)
                let imageAspectRatio = defaultImage.size.width / defaultImage.size.height
                let rectAspectRatio = iconRect.width / iconRect.height
                
                var drawRect: CGRect
                if imageAspectRatio > rectAspectRatio {
                    let scaledWidth = iconRect.height * imageAspectRatio
                    drawRect = CGRect(
                        x: iconRect.midX - scaledWidth/2,
                        y: iconRect.minY,
                        width: scaledWidth,
                        height: iconRect.height
                    )
                } else {
                    let scaledHeight = iconRect.width / imageAspectRatio
                    drawRect = CGRect(
                        x: iconRect.minX,
                        y: iconRect.midY - scaledHeight/2,
                        width: iconRect.width,
                        height: scaledHeight
                    )
                }
                
                originalImage.draw(in: drawRect)
            }
            
            context.restoreGState()
        }
        
        // 绘制目的地信息
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        nameString.draw(at: CGPoint(x: point.x + 110, y: point.y + 10))
        
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
        let subtitle = "\(destination.country) • \(dateFormatter.string(from: destination.visitDate))"
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        subtitleString.draw(at: CGPoint(x: point.x + 110, y: point.y + 32))
    }
    
    // MARK: - 绘制签名（共享方法）
    static func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
        // 使用与旅程分享图片相同的签名
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        signatureString.draw(at: CGPoint(x: point.x - signatureSize.width/2, y: point.y))
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width/2, y: point.y + 25))
    }
    
    // MARK: - 动态字号计算（共享方法）
    static func calculateDynamicTitleFontSize(for title: String, availableWidth: CGFloat, minSize: CGFloat = 34, maxSize: CGFloat = 40) -> CGFloat {
        var fontSize = maxSize
        let step: CGFloat = 1
        
        while fontSize >= minSize {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let attributedString = NSAttributedString(string: title, attributes: attributes)
            let maxHeight: CGFloat = fontSize * 2.5
            
            let boundingRect = attributedString.boundingRect(
                with: CGSize(width: availableWidth, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            if boundingRect.width <= availableWidth && boundingRect.height <= maxHeight {
                return fontSize
            }
            
            fontSize -= step
        }
        
        return minSize
    }
    
    // MARK: - 绘制标题区域（共享方法，包含年份标题和用户名）
    static func drawHeader(year: Int, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        var currentY: CGFloat = point.y
        
        let userName = AppleSignInManager.shared.displayName
        
        let yearTitle = LanguageManager.shared.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records"
        let fontSize = calculateDynamicTitleFontSize(for: yearTitle, availableWidth: width)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 4
                return style
            }()
        ]
        let titleString = NSAttributedString(string: yearTitle, attributes: titleAttributes)
        let maxHeight: CGFloat = fontSize * 2.5
        let titleRect = titleString.boundingRect(
            with: CGSize(width: width, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleDrawRect = CGRect(
            x: point.x,
            y: currentY,
            width: width,
            height: ceil(titleRect.height)
        )
        titleString.draw(in: titleDrawRect)
        currentY += ceil(titleRect.height) + 16
        
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ]
        let userNameString = NSAttributedString(string: userName, attributes: userNameAttributes)
        let userNameSize = userNameString.size()
        let userNameX = point.x + (width - userNameSize.width) / 2
        userNameString.draw(at: CGPoint(x: userNameX, y: currentY))
        currentY += userNameSize.height + 12
        
        return currentY - point.y
    }
}

// MARK: - 版面生成器协议
protocol YearLayoutGenerator {
    func generateImage(year: Int, destinations: [TravelDestination]) -> UIImage?
}

// MARK: - 清单版面生成器
struct YearListLayoutGenerator: YearLayoutGenerator {
    func generateImage(year: Int, destinations: [TravelDestination]) -> UIImage? {
        // 获取屏幕宽度
        let screenWidth = UIScreen.main.bounds.width
        
        // 计算内容高度
        let contentHeight = calculateContentHeight(year: year, destinations: destinations, width: screenWidth)
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        // 创建图片渲染器
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 绘制三色线性渐变背景（符合App配色标准）
            YearImageGenerator.drawGradientBackground(in: CGRect(origin: .zero, size: imageSize), context: cgContext)
            
            var currentY: CGFloat = 0
            
            // 绘制内容
            currentY += 40
            
            // 绘制标题区域（使用共享方法，与九宫格拼图版面保持一致）
            let headerHeight = YearImageGenerator.drawHeader(year: year, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += headerHeight + 12 + 20 // 描述后的间距 + 到统计卡片的间距
            
            // 绘制统计信息卡片
            let statsCardHeight = YearImageGenerator.drawStatisticsCard(year: year, destinations: destinations, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += statsCardHeight + 20
            
            // 绘制目的地列表卡片
            let destinationsCardHeight = YearImageGenerator.drawDestinationsCard(destinations: destinations, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += destinationsCardHeight
            
            // 绘制底部签名（与上面内容间距40，离底部边缘20）
            currentY += 24
            YearImageGenerator.drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }
    
    // MARK: - 计算内容高度（清单版面）
    private func calculateContentHeight(year: Int, destinations: [TravelDestination], width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        
        // 顶部padding（与绘制时保持一致）
        height += 20
        
        // 标题区域（使用与 drawHeader 相同的计算方式，确保完全一致）
        let yearTitle = LanguageManager.shared.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records"
        let fontSize = YearImageGenerator.calculateDynamicTitleFontSize(for: yearTitle, availableWidth: width - 40)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 4
                return style
            }()
        ]
        let titleString = NSAttributedString(string: yearTitle, attributes: titleAttributes)
        let maxHeight: CGFloat = fontSize * 2.5
        let titleRect = titleString.boundingRect(
            with: CGSize(width: width - 40, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        // 计算标题区域高度（与 drawHeader 中的计算完全一致）
        var headerHeight: CGFloat = ceil(titleRect.height) + 16
        
        // 用户姓名高度（与 drawHeader 中的计算完全一致）
        let userName = AppleSignInManager.shared.displayName
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular)
        ]
        let userNameString = NSAttributedString(string: userName, attributes: userNameAttributes)
        let userNameSize = userNameString.size()
        headerHeight += userNameSize.height + 12
        
        // 标题区域总高度 + 间距（与绘制时完全一致：headerHeight + 12 + 20）
        height += headerHeight + 12 + 20
        
        // 统计信息卡片
        height += 100 + 20 // card + margin
        
        // 目的地列表卡片（卡片样式，显示所有目的地）
        let destinationCount = destinations.count
        let cardHeight: CGFloat = 160
        let cardSpacing: CGFloat = 12
        let cardHeaderHeight: CGFloat = 50
        let totalCardsHeight = destinationCount > 0 ? CGFloat(destinationCount) * cardHeight + CGFloat(destinationCount - 1) * cardSpacing : 0
        let destinationsHeight = destinationCount > 0 ? cardHeaderHeight + totalCardsHeight + 40 : 80
        height += destinationsHeight
        
        // 底部签名（与绘制时完全一致：currentY += 40，然后绘制签名）
        height += 40 // 与上面内容的间距
        // 签名高度：签名文字14pt + 间距25pt + 副标题12pt ≈ 51pt，加上一些余量确保完整显示
        height += 70 // 签名区域高度（包括签名和副标题，增加余量确保完整显示）
        height += 30 // 底部padding（增加余量确保签名不会被裁剪）
        
        return height
    }
}

// MARK: - 共享九宫格布局辅助（用于年份分享）
fileprivate enum ShareGridFullWidthStyle {
    case none
    case tall
    case squareHeight
}

fileprivate func shareGridFullWidthStyle(for totalItemCount: Int) -> ShareGridFullWidthStyle {
    switch totalItemCount {
    case 2:
        return .tall
    case 5, 8:
        return .squareHeight
    default:
        return .none
    }
}

// MARK: - 九宫格拼图版面生成器
struct YearGridLayoutGenerator: YearLayoutGenerator {
    func generateImage(year: Int, destinations: [TravelDestination]) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let sortedDestinations = destinations.sorted { $0.visitDate < $1.visitDate }
        
        // 设置页边距
        let horizontalPadding: CGFloat = 32
        let topPadding: CGFloat = 40
        let bottomPadding: CGFloat = 20
        let contentWidth = screenWidth - horizontalPadding * 2
        
        // 计算内容高度
        let contentHeight = calculateContentHeight(year: year, destinations: sortedDestinations, width: screenWidth, horizontalPadding: horizontalPadding, topPadding: topPadding, bottomPadding: bottomPadding)
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        // 创建图片渲染器
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 设置背景色
            cgContext.setFillColor(UIColor(red: 0.969, green: 0.953, blue: 0.922, alpha: 1.0).cgColor) // #f7f3eb
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY: CGFloat = topPadding
            
            // 绘制标题区域（使用共享方法）
            let headerHeight = YearImageGenerator.drawHeader(year: year, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
            currentY += headerHeight + 12 + 20 // 描述后的间距 + 到统计卡片的间距
            
            // 绘制统计信息卡片
            let statsCardHeight = YearImageGenerator.drawStatisticsCard(year: year, destinations: destinations, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
            currentY += statsCardHeight + 20
            
            // 绘制九宫格拼图
            if !sortedDestinations.isEmpty {
                let gridHeight = drawGrid(destinations: sortedDestinations, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
                currentY += gridHeight
            } else {
                drawEmptyState(at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
                currentY += 200
            }
            
            // 绘制底部签名
            currentY += 40
            YearImageGenerator.drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: contentWidth, context: cgContext)
        }
    }
    
    private func calculateContentHeight(year: Int, destinations: [TravelDestination], width: CGFloat, horizontalPadding: CGFloat, topPadding: CGFloat, bottomPadding: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        let contentWidth = width - horizontalPadding * 2
        
        height += topPadding
        
        // 标题区域
        let yearTitle = LanguageManager.shared.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records"
        let fontSize = YearImageGenerator.calculateDynamicTitleFontSize(for: yearTitle, availableWidth: contentWidth)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 4
                return style
            }()
        ]
        let titleString = NSAttributedString(string: yearTitle, attributes: titleAttributes)
        let maxHeight: CGFloat = fontSize * 2.5
        let titleRect = titleString.boundingRect(
            with: CGSize(width: contentWidth, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        var headerHeight: CGFloat = ceil(titleRect.height) + 16
        
        let userName = AppleSignInManager.shared.displayName
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular)
        ]
        let userNameString = NSAttributedString(string: userName, attributes: userNameAttributes)
        let userNameSize = userNameString.size()
        headerHeight += userNameSize.height + 12
        
        height += headerHeight + 12 + 20
        
        // 统计信息卡片
        height += 100 + 20
        
        // 九宫格区域
        if !destinations.isEmpty {
            let displayCount = min(destinations.count, 9)
            height += calculateSmartGridHeight(destinations: displayCount, width: contentWidth) + 20
        } else {
            height += 200
        }
        
        height += 40 + 40 + bottomPadding
        
        return height
    }
    
    private func drawHeader(year: Int, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        var currentY: CGFloat = point.y
        
        let userName = AppleSignInManager.shared.displayName
        
        let yearTitle = LanguageManager.shared.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records"
        let fontSize = YearImageGenerator.calculateDynamicTitleFontSize(for: yearTitle, availableWidth: width)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 4
                return style
            }()
        ]
        let titleString = NSAttributedString(string: yearTitle, attributes: titleAttributes)
        let maxHeight: CGFloat = fontSize * 2.5
        let titleRect = titleString.boundingRect(
            with: CGSize(width: width, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleDrawRect = CGRect(
            x: point.x,
            y: currentY,
            width: width,
            height: ceil(titleRect.height)
        )
        titleString.draw(in: titleDrawRect)
        currentY += ceil(titleRect.height) + 16
        
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ]
        let userNameString = NSAttributedString(string: userName, attributes: userNameAttributes)
        let userNameSize = userNameString.size()
        let userNameX = point.x + (width - userNameSize.width) / 2
        userNameString.draw(at: CGPoint(x: userNameX, y: currentY))
        currentY += userNameSize.height + 12
        
        return currentY - point.y
    }
    
    private func drawGrid(destinations: [TravelDestination], at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let displayDestinations = Array(destinations.prefix(9))
        let displayCount = displayDestinations.count
        guard displayCount > 0 else { return 0 }
        
        let spacing: CGFloat = 6
        var currentY = point.y
        
        let destinationImages: [UIImage] = displayDestinations.compactMap { destination in
            if let photoData = destination.photoData,
               let photoImage = UIImage(data: photoData) {
                return photoImage
            } else if let defaultImage = UIImage(named: "ImageMooyu") {
                return defaultImage.withRenderingMode(.alwaysOriginal)
            }
            return nil
        }
        
        guard !destinationImages.isEmpty else { return 0 }
        
        if displayCount == 1 {
            let mainImageHeight = width * (2.0/3.0)
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageHeight)
            drawMainImageDestination(destinationImages[0], destination: displayDestinations[0], index: 1, in: mainImageRect, context: context)
            return mainImageHeight
        } else if displayCount == 9 {
            let gridHeight = drawSmartDestinationGrid(
                images: destinationImages,
                destinations: displayDestinations,
                totalCount: displayCount,
                startIndex: 1,
                at: CGPoint(x: point.x, y: currentY),
                width: width,
                context: context
            )
            return gridHeight
        } else {
            let mainImageSize = width * 0.6
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
            drawMainImageDestination(destinationImages[0], destination: displayDestinations[0], index: 1, in: mainImageRect, context: context)
            currentY += mainImageSize + spacing
            
            let remainingImages = Array(destinationImages[1..<destinationImages.count])
            let remainingDestinations = Array(displayDestinations[1..<displayDestinations.count])
            let gridHeight = drawSmartDestinationGrid(
                images: remainingImages,
                destinations: remainingDestinations,
                totalCount: displayCount,
                startIndex: 2,
                at: CGPoint(x: point.x, y: currentY),
                width: width,
                context: context
            )
            currentY += gridHeight
            
            return currentY - point.y
        }
    }
    
    private func calculateSmartGridHeight(destinations totalDestinations: Int, width: CGFloat) -> CGFloat {
        guard totalDestinations > 0 else { return 0 }
        
        if totalDestinations == 1 {
            return width * 0.75
        }
        
        if totalDestinations == 9 {
            return self.enumerateShareGridRects(
                itemCount: 9,
                totalCountStyle: ShareGridFullWidthStyle.none,
                origin: .zero,
                width: width
            ) { _, _ in }
        }
        
        let mainImageSize = width * 0.6
        let remainingCount = totalDestinations - 1
        let gridHeight = self.enumerateShareGridRects(
            itemCount: remainingCount,
            totalCountStyle: self.shareGridFullWidthStyle(for: totalDestinations),
            origin: .zero,
            width: width
        ) { _, _ in }
        
        if gridHeight == 0 {
            return mainImageSize
        }
        
        return mainImageSize + 6 + gridHeight
    }
    
    private func drawMainImageDestination(_ image: UIImage, destination: TravelDestination, index: Int, in rect: CGRect, context: CGContext) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        
        let imageAspectRatio = image.size.width / image.size.height
        let rectAspectRatio = rect.width / rect.height
        
        var drawRect = rect
        if imageAspectRatio > rectAspectRatio {
            let scaledWidth = rect.height * imageAspectRatio
            drawRect = CGRect(
                x: rect.midX - scaledWidth / 2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            let scaledHeight = rect.width / imageAspectRatio
            drawRect = CGRect(
                x: rect.minX,
                y: rect.midY - scaledHeight / 2,
                width: rect.width,
                height: scaledHeight
            )
        }
        
        image.draw(in: drawRect)
        context.restoreGState()
        
        let badgeSize: CGFloat = 28
        let badgeRect = CGRect(x: rect.minX + 8, y: rect.minY + 8, width: badgeSize, height: badgeSize)
        context.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        context.fillEllipse(in: badgeRect)
        
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let numberString = NSAttributedString(string: "\(index)", attributes: numberAttributes)
        let numberSize = numberString.size()
        numberString.draw(at: CGPoint(x: badgeRect.midX - numberSize.width/2, y: badgeRect.midY - numberSize.height/2))
        
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        let nameSize = nameString.size()
        let namePadding: CGFloat = 8
        let nameBackgroundRect = CGRect(
            x: rect.minX,
            y: rect.maxY - nameSize.height - namePadding * 2,
            width: rect.width,
            height: nameSize.height + namePadding * 2
        )
        
        let cornerRadius: CGFloat = 12
        let backgroundPath = UIBezierPath(
            roundedRect: nameBackgroundRect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.addPath(backgroundPath.cgPath)
        context.fillPath()
        
        nameString.draw(at: CGPoint(x: rect.minX + namePadding, y: nameBackgroundRect.midY - nameSize.height/2))
    }
    
    private func drawSmartDestinationGrid(
        images: [UIImage],
        destinations: [TravelDestination],
        totalCount: Int,
        startIndex: Int,
        at point: CGPoint,
        width: CGFloat,
        context: CGContext
    ) -> CGFloat {
        return self.enumerateShareGridRects(
            itemCount: images.count,
            totalCountStyle: self.shareGridFullWidthStyle(for: totalCount),
            origin: point,
            width: width
        ) { index, rect in
            guard index < images.count, index < destinations.count else { return }
            drawDestinationGridPhoto(images[index], destination: destinations[index], index: startIndex + index, in: rect, context: context)
        }
    }
    
    private func drawDestinationGridPhoto(_ image: UIImage, destination: TravelDestination, index: Int, in rect: CGRect, context: CGContext) {
        let isFullWidth = rect.width > rect.height * 2.5
        
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        
        let imageAspectRatio = image.size.width / image.size.height
        let rectAspectRatio = rect.width / rect.height
        var drawRect = rect
        
        if isFullWidth {
            let scaledHeight = rect.width / imageAspectRatio
            drawRect = CGRect(
                x: rect.minX,
                y: rect.midY - scaledHeight / 2,
                width: rect.width,
                height: scaledHeight
            )
        } else if imageAspectRatio > rectAspectRatio {
            let scaledWidth = rect.height * imageAspectRatio
            drawRect = CGRect(
                x: rect.midX - scaledWidth / 2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            let scaledHeight = rect.width / imageAspectRatio
            drawRect = CGRect(
                x: rect.minX,
                y: rect.midY - scaledHeight / 2,
                width: rect.width,
                height: scaledHeight
            )
        }
        
        image.draw(in: drawRect)
        context.restoreGState()
        
        let badgeSize: CGFloat = 28
        let badgeRect = CGRect(x: rect.minX + 8, y: rect.minY + 8, width: badgeSize, height: badgeSize)
        context.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        context.fillEllipse(in: badgeRect)
        
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let numberString = NSAttributedString(string: "\(index)", attributes: numberAttributes)
        let numberSize = numberString.size()
        numberString.draw(at: CGPoint(x: badgeRect.midX - numberSize.width/2, y: badgeRect.midY - numberSize.height/2))
        
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        let nameSize = nameString.size()
        let namePadding: CGFloat = 8
        let nameBackgroundRect = CGRect(
            x: rect.minX,
            y: rect.maxY - nameSize.height - namePadding * 2,
            width: rect.width,
            height: nameSize.height + namePadding * 2
        )
        
        let cornerRadius: CGFloat = 8
        let backgroundPath = UIBezierPath(
            roundedRect: nameBackgroundRect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.addPath(backgroundPath.cgPath)
        context.fillPath()
        
        nameString.draw(at: CGPoint(x: rect.minX + namePadding, y: nameBackgroundRect.midY - nameSize.height/2))
    }
    
    private func drawEmptyState(at point: CGPoint, width: CGFloat, context: CGContext) {
        let emptyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let emptyText = LanguageManager.shared.currentLanguage == .chinese ? "还没有旅行记录" : "No travel records"
        let emptyString = NSAttributedString(string: emptyText, attributes: emptyAttributes)
        let emptySize = emptyString.size()
        emptyString.draw(at: CGPoint(x: point.x + width/2 - emptySize.width/2, y: point.y + 100))
    }
    
    // 复用 TripImageGenerator 中的网格布局辅助函数
    private func enumerateShareGridRects(
        itemCount: Int,
        totalCountStyle: ShareGridFullWidthStyle,
        origin: CGPoint,
        width: CGFloat,
        spacing: CGFloat = 6,
        columns: Int = 3,
        handler: (_ index: Int, _ rect: CGRect) -> Void
    ) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        
        let standardTileSize = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let allowFullWidthSingleRow = totalCountStyle != .none
        
        if itemCount <= columns {
            if itemCount == 1 && allowFullWidthSingleRow {
                let rectHeight = fullWidthGridRowHeight(
                    width: width,
                    standardTileSize: standardTileSize,
                    style: totalCountStyle
                )
                let rect = CGRect(x: origin.x, y: origin.y, width: width, height: rectHeight)
                handler(0, rect)
                return rectHeight
            }
            
            let photoSize = (width - spacing * CGFloat(itemCount - 1)) / CGFloat(itemCount)
            var currentX = origin.x
            
            for index in 0..<itemCount {
                let rect = CGRect(x: currentX, y: origin.y, width: photoSize, height: photoSize)
                handler(index, rect)
                currentX += photoSize + spacing
            }
            return photoSize
        }
        
        let photoSize = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var currentY = origin.y
        var processedIndex = 0
        var remaining = itemCount
        
        while remaining > 0 {
            let photosInRow = min(columns, remaining)
            let isLastRow = photosInRow == remaining
            let isLonelyLastRow = isLastRow && photosInRow == 1 && allowFullWidthSingleRow
            
            if isLonelyLastRow {
                let rectHeight = fullWidthGridRowHeight(
                    width: width,
                    standardTileSize: standardTileSize,
                    style: totalCountStyle
                )
                let rect = CGRect(x: origin.x, y: currentY, width: width, height: rectHeight)
                handler(processedIndex, rect)
                currentY += rectHeight
                processedIndex += 1
            } else {
                let shouldSplitLastRow = isLastRow && photosInRow == 2 && !allowFullWidthSingleRow
                let itemWidth: CGFloat
                if shouldSplitLastRow {
                    itemWidth = (width - spacing) / 2.0
                } else {
                    itemWidth = photoSize
                }
                
                var currentX = origin.x
                for _ in 0..<photosInRow {
                    let rect = CGRect(x: currentX, y: currentY, width: itemWidth, height: photoSize)
                    handler(processedIndex, rect)
                    currentX += itemWidth + spacing
                    processedIndex += 1
                }
                currentY += photoSize
            }
            
            remaining -= photosInRow
            if remaining > 0 {
                currentY += spacing
            }
        }
        
        return currentY - origin.y
    }
    
    private func shareGridFullWidthStyle(for totalItemCount: Int) -> ShareGridFullWidthStyle {
        switch totalItemCount {
        case 2:
            return .tall
        case 5, 8:
            return .squareHeight
        default:
            return .none
        }
    }
    
    private func fullWidthGridRowHeight(
        width: CGFloat,
        standardTileSize: CGFloat,
        style: ShareGridFullWidthStyle
    ) -> CGFloat {
        switch style {
        case .tall:
            return width * 0.6
        case .squareHeight:
            return standardTileSize
        case .none:
            return standardTileSize
        }
    }
}

// MARK: - 扩展网格版面生成器
struct YearExtendedGridLayoutGenerator: YearLayoutGenerator {
    func generateImage(year: Int, destinations: [TravelDestination]) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let sortedDestinations = destinations.sorted { $0.visitDate < $1.visitDate }
        
        // 计算内容高度
        let contentHeight = calculateContentHeight(year: year, destinations: sortedDestinations, width: screenWidth)
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        // 创建图片渲染器
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 设置背景色
            cgContext.setFillColor(UIColor(red: 0.969, green: 0.953, blue: 0.922, alpha: 1.0).cgColor) // #f7f3eb
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY: CGFloat = 0
            
            // 绘制标题区域（使用共享方法）
            currentY += 40
            let headerHeight = YearImageGenerator.drawHeader(year: year, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += headerHeight + 12 + 20
            
            // 绘制统计信息卡片
            let statsCardHeight = YearImageGenerator.drawStatisticsCard(year: year, destinations: destinations, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += statsCardHeight + 20
            
            // 绘制扩展网格拼图
            if !sortedDestinations.isEmpty {
                let gridHeight = drawExtendedGrid(destinations: sortedDestinations, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                currentY += gridHeight
            } else {
                drawEmptyState(at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                currentY += 200
            }
            
            // 绘制底部签名
            currentY += 40
            YearImageGenerator.drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }
    
    private func calculateContentHeight(year: Int, destinations: [TravelDestination], width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        
        height += 40
        
        // 标题区域
        let yearTitle = LanguageManager.shared.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records"
        let fontSize = YearImageGenerator.calculateDynamicTitleFontSize(for: yearTitle, availableWidth: width - 40)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineSpacing = 4
                return style
            }()
        ]
        let titleString = NSAttributedString(string: yearTitle, attributes: titleAttributes)
        let maxHeight: CGFloat = fontSize * 2.5
        let titleRect = titleString.boundingRect(
            with: CGSize(width: width - 40, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        var headerHeight: CGFloat = ceil(titleRect.height) + 16
        
        let userName = AppleSignInManager.shared.displayName
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular)
        ]
        let userNameString = NSAttributedString(string: userName, attributes: userNameAttributes)
        let userNameSize = userNameString.size()
        headerHeight += userNameSize.height + 12
        
        height += headerHeight + 12 + 20
        
        // 统计信息卡片
        height += 100 + 20
        
        // 扩展网格区域
        if !destinations.isEmpty {
            let columns: CGFloat = 3
            let rows = ceil(CGFloat(destinations.count) / columns)
            let gridSize = (width - 40) / 3
            height += gridSize * rows + 20
        } else {
            height += 200
        }
        
        height += 40 + 40 + 20
        
        return height
    }
    
    private func drawExtendedGrid(destinations: [TravelDestination], at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let columns: CGFloat = 3
        let spacing: CGFloat = 8
        let actualGridSize = (width - spacing * 2) / 3
        
        let displayCount = destinations.count
        let rows = ceil(CGFloat(displayCount) / columns)
        
        for (index, destination) in destinations.enumerated() {
            let row = index / 3
            let col = index % 3
            
            let x = point.x + CGFloat(col) * (actualGridSize + spacing)
            let y = point.y + CGFloat(row) * (actualGridSize + spacing)
            
            let gridRect = CGRect(x: x, y: y, width: actualGridSize, height: actualGridSize)
            drawGridItem(destination: destination, index: index + 1, in: gridRect, context: context)
        }
        
        return actualGridSize * rows + spacing * (rows - 1)
    }
    
    private func drawGridItem(destination: TravelDestination, index: Int, in rect: CGRect, context: CGContext) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        
        if let photoData = destination.photoData,
           let photoImage = UIImage(data: photoData) {
            let imageAspectRatio = photoImage.size.width / photoImage.size.height
            let rectAspectRatio = rect.width / rect.height
            
            var drawRect = rect
            if imageAspectRatio > rectAspectRatio {
                let scaledWidth = rect.height * imageAspectRatio
                drawRect = CGRect(x: rect.midX - scaledWidth/2, y: rect.minY, width: scaledWidth, height: rect.height)
            } else {
                let scaledHeight = rect.width / imageAspectRatio
                drawRect = CGRect(x: rect.minX, y: rect.midY - scaledHeight/2, width: rect.width, height: scaledHeight)
            }
            
            photoImage.draw(in: drawRect)
        } else {
            if let defaultImage = UIImage(named: "ImageMooyu") {
                let originalImage = defaultImage.withRenderingMode(.alwaysOriginal)
                let imageAspectRatio = defaultImage.size.width / defaultImage.size.height
                let rectAspectRatio = rect.width / rect.height
                
                var drawRect: CGRect
                if imageAspectRatio > rectAspectRatio {
                    let scaledWidth = rect.height * imageAspectRatio
                    drawRect = CGRect(
                        x: rect.midX - scaledWidth/2,
                        y: rect.minY,
                        width: scaledWidth,
                        height: rect.height
                    )
                } else {
                    let scaledHeight = rect.width / imageAspectRatio
                    drawRect = CGRect(
                        x: rect.minX,
                        y: rect.midY - scaledHeight/2,
                        width: rect.width,
                        height: scaledHeight
                    )
                }
                
                originalImage.draw(in: drawRect)
            }
        }
        
        context.restoreGState()
        
        let badgeSize: CGFloat = 28
        let badgeRect = CGRect(x: rect.minX + 8, y: rect.minY + 8, width: badgeSize, height: badgeSize)
        context.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        context.fillEllipse(in: badgeRect)
        
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let numberString = NSAttributedString(string: "\(index)", attributes: numberAttributes)
        let numberSize = numberString.size()
        numberString.draw(at: CGPoint(x: badgeRect.midX - numberSize.width/2, y: badgeRect.midY - numberSize.height/2))
        
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        let nameSize = nameString.size()
        let namePadding: CGFloat = 8
        let nameBackgroundRect = CGRect(
            x: rect.minX,
            y: rect.maxY - nameSize.height - namePadding * 2,
            width: rect.width,
            height: nameSize.height + namePadding * 2
        )
        
        let cornerRadius: CGFloat = 12
        let backgroundPath = UIBezierPath(
            roundedRect: nameBackgroundRect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.addPath(backgroundPath.cgPath)
        context.fillPath()
        
        nameString.draw(at: CGPoint(x: rect.minX + namePadding, y: nameBackgroundRect.midY - nameSize.height/2))
    }
    
    private func drawEmptyState(at point: CGPoint, width: CGFloat, context: CGContext) {
        let emptyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let emptyText = LanguageManager.shared.currentLanguage == .chinese ? "还没有旅行记录" : "No travel records"
        let emptyString = NSAttributedString(string: emptyText, attributes: emptyAttributes)
        let emptySize = emptyString.size()
        emptyString.draw(at: CGPoint(x: point.x + width/2 - emptySize.width/2, y: point.y + 100))
    }
}

