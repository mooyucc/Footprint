//
//  TripListLayoutGenerator.swift
//  Footprint
//
//  从 TripImageGenerator.swift 提取（编译拆分）
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation
import MapKit

// MARK: - 清单版面生成器
struct ListLayoutGenerator: TripLayoutGenerator {
    func generateImage(from trip: TravelTrip) -> UIImage? {
        // 获取屏幕宽度
        let screenWidth = UIScreen.main.bounds.width
        
        // 计算内容高度
        let contentHeight = calculateContentHeight(for: trip, width: screenWidth)
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        print("📏 [ListLayout] 计算高度: \(contentHeight), 图片尺寸: \(imageSize)")
        
        // 创建图片渲染器（禁用Alpha通道以减少文件体积）
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 绘制三色线性渐变背景（符合App配色标准）
            TripImageGenerator.drawGradientBackground(in: CGRect(origin: .zero, size: imageSize), context: cgContext)
            
            var currentY: CGFloat = 0
            
            // 动态计算封面高度以适配标题和描述内容，最小高度380pt
            let coverHeight = calculateCoverHeight(for: trip, width: screenWidth)
            let coverRect = CGRect(x: 0, y: 0, width: screenWidth, height: coverHeight)
            
            if let photoData = trip.coverPhotoData,
               let coverImage = UIImage(data: photoData) {
                // 绘制封面图片，使用 scaledToFill 模式，填充整个封面区域，超出部分裁剪
                // 这样可以确保图片不会变形，也不会超出 380 的高度限制
                let imageAspectRatio = coverImage.size.width / coverImage.size.height
                let rectAspectRatio = coverRect.width / coverRect.height
                
                // 先设置裁剪区域，确保图片不会超出封面范围
                cgContext.saveGState()
                cgContext.clip(to: coverRect)
                
                var drawRect = coverRect
                if imageAspectRatio > rectAspectRatio {
                    // 图片更宽（横向），以高度为准填充，宽度会被裁剪
                    let scaledWidth = coverRect.height * imageAspectRatio
                    drawRect = CGRect(
                        x: (coverRect.width - scaledWidth) / 2,
                        y: 0,
                        width: scaledWidth,
                        height: coverRect.height
                    )
                } else {
                    // 图片更高（纵向）或等比例，以宽度为准填充，高度会被裁剪
                    let scaledHeight = coverRect.width / imageAspectRatio
                    drawRect = CGRect(
                        x: 0,
                        y: (coverRect.height - scaledHeight) / 2,
                        width: coverRect.width,
                        height: scaledHeight
                    )
                }
                
                coverImage.draw(in: drawRect)
                cgContext.restoreGState()
            } else {
                // 绘制默认封面
                drawDefaultCover(for: trip, in: cgContext, rect: coverRect)
            }
            
            // 在封面图片上绘制半透明灰色遮罩
            cgContext.saveGState()
            cgContext.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
            cgContext.fill(coverRect)
            cgContext.restoreGState()
            
            // 在封面图片上绘制标题和描述（使用白色文字）
            // 从底部向上布局，确保文字在封面区域内显示
            let horizontalPadding: CGFloat = 20
            let textWidth = screenWidth - horizontalPadding * 2
            let bottomPadding: CGFloat = 24 // 距离封面底部的间距（优化后减小空白）
            
            // 计算描述高度（如果有）
            var descHeight: CGFloat = 0
            if !trip.desc.isEmpty {
                let descAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 17)
                ]
                let descString = NSAttributedString(string: trip.desc, attributes: descAttributes)
                let descRect = descString.boundingRect(
                    with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                descHeight = ceil(descRect.height)
            }
            
            // 计算标题高度
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold)
            ]
            let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
            let titleRect = titleString.boundingRect(
                with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let titleHeight = ceil(titleRect.height)
            
            // 计算总文字高度和间距
            let textSpacing: CGFloat = 16
            let totalTextHeight = titleHeight + textSpacing + descHeight
            
            // 从底部向上布局（封面高度已动态调整，确保文字在封面范围内）
            var textY = coverHeight - bottomPadding - totalTextHeight
            
            // 绘制标题（白色，粗体）
            drawTitleOnCover(trip.name, at: CGPoint(x: horizontalPadding, y: textY), width: textWidth, context: cgContext)
            textY += titleHeight + textSpacing
            
            // 绘制描述（白色，稍小字体）
            if !trip.desc.isEmpty {
                drawDescriptionOnCover(trip.desc, at: CGPoint(x: horizontalPadding, y: textY), width: textWidth, context: cgContext)
            }
            
            currentY = coverHeight
            
            // 行程概要 + 旅行统计（渐变上直接绘制，无白底卡片，与 StatsImageGenerator 一致）
            currentY += 20
            let statsBlockHeight = TripImageGenerator.drawTripShareModernStatsBlock(
                trip: trip,
                at: CGPoint(x: 20, y: currentY),
                width: screenWidth - 40,
                context: cgContext
            )
            currentY += statsBlockHeight + 4
            
            // 绘制行程路线（无外层大白卡）
            let routeCardHeight = drawRouteCard(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += routeCardHeight
            
            // 绘制底部签名（优化间距以减少空白）
            currentY += 24 // 与上面地点图片的间距（从40优化为24）
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }
    
    /// 计算封面高度（动态适配标题和描述内容，最小高度380pt）
    private func calculateCoverHeight(for trip: TravelTrip, width: CGFloat) -> CGFloat {
        let horizontalPadding: CGFloat = 20
        let textWidth = width - horizontalPadding * 2
        let bottomPadding: CGFloat = 24
        let textSpacing: CGFloat = 16
        let minCoverHeight: CGFloat = 380 // 最小封面高度
        
        // 计算描述高度（如果有）
        var descHeight: CGFloat = 0
        if !trip.desc.isEmpty {
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17)
            ]
            let descString = NSAttributedString(string: trip.desc, attributes: descAttributes)
            let descRect = descString.boundingRect(
                with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            descHeight = ceil(descRect.height)
        }
        
        // 计算标题高度
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
        let titleRect = titleString.boundingRect(
            with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleHeight = ceil(titleRect.height)
        
        // 计算所需的总高度：文字内容 + 间距 + 底部边距
        let requiredHeight = titleHeight + textSpacing + descHeight + bottomPadding
        
        // 返回动态高度，但不少于最小高度
        return max(requiredHeight, minCoverHeight)
    }
    
    private func calculateContentHeight(for trip: TravelTrip, width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        
        // 封面图片区域（动态计算高度以适配标题和描述）
        let coverHeight = calculateCoverHeight(for: trip, width: width)
        height += coverHeight
        
        // 封面到统计区
        height += 20
        
        // 日期三列 + 旅行统计 2×2（无白底卡片）
        let contentW = width - 40
        height += TripImageGenerator.tripShareModernStatsBlockHeight(contentWidth: contentW) + 4
        
        // 行程路线（无外层卡片；单卡高度与 DestinationRowCard 一致）
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        let destinationCount = sortedDestinations.count
        var routeHeight: CGFloat = 0
        if destinationCount > 0 {
            let cardHeight: CGFloat = 168
            let cardSpacing: CGFloat = 12
            let totalCardsHeight = CGFloat(destinationCount) * cardHeight + CGFloat(destinationCount - 1) * cardSpacing
            let dayGroupsCount = dayGroups(for: trip).count
            let daySectionHeadersHeight: CGFloat = dayGroupsCount > 1 ? CGFloat(dayGroupsCount) * Self.listLayoutDaySectionHeaderHeight : 0
            routeHeight = 40 + daySectionHeadersHeight + totalCardsHeight + 20
        } else {
            routeHeight = 40 + 80 + 20
        }
        height += routeHeight
        
        // 底部签名（与上面地点图片间距40，离底部边缘20）
        // 计算签名的实际高度
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14)
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureRect = signatureString.boundingRect(
            with: CGSize(width: width - 40, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let signatureHeight = ceil(signatureRect.height)
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleRect = subtitleString.boundingRect(
            with: CGSize(width: width - 40, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let subtitleHeight = ceil(subtitleRect.height)
        
        // 底部签名区域总高度计算（优化间距以减少空白）：
        // - 与上面地点图片的间距: 24（从40优化为24）
        // - 主签名高度: signatureHeight
        // - 主副标题间距: 25（与drawSignature绘制时保持一致）
        // - 副标题高度: subtitleHeight
        // - 底部边距: 16（确保副标题完整显示，有足够的底部空间）
        height += 24 + signatureHeight + 25 + subtitleHeight + 16
        
        return height
    }
    
    private func drawDefaultCover(for trip: TravelTrip, in context: CGContext, rect: CGRect) {
        // 绘制品牌色渐变（与 App 旅程占位封面一致）
        let brand = UIColor(BrandColorManager.shared.currentBrandColor)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [brand.cgColor, brand.withAlphaComponent(0.55).cgColor] as CFArray,
            locations: [0, 1]
        )!
        
        context.saveGState()
        context.addRect(rect)
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
        context.restoreGState()
        
        // 绘制图标和文字
        let centerX = rect.midX
        let centerY = rect.midY
        
        // 绘制地图图标
        let mapIcon = UIImage(systemName: "map.fill")
        if let mapIcon = mapIcon {
            let iconSize: CGFloat = 60
            let iconRect = CGRect(
                x: centerX - iconSize/2, 
                y: centerY - iconSize/2 - 20, 
                width: iconSize, 
                height: iconSize
            )
            
            // 使用半透明白色渲染地图图标
            let tintedIcon = mapIcon.withTintColor(UIColor.white.withAlphaComponent(0.8), renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        // 绘制旅程名称
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
        let titleSize = titleString.size()
        titleString.draw(at: CGPoint(x: centerX - titleSize.width/2, y: centerY + 20))
    }
    
    // 在封面上绘制标题（白色文字）
    private func drawTitleOnCover(_ title: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let attributedString = NSAttributedString(string: title, attributes: attributes)
        // 计算多行文本的实际高度
        let textRect = attributedString.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
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
        return drawRect.height
    }
    
    // 在封面上绘制描述（白色文字）
    private func drawDescriptionOnCover(_ description: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.white.withAlphaComponent(0.95) // 稍许透明以增加层次感
        ]
        
        let attributedString = NSAttributedString(string: description, attributes: attributes)
        // 计算多行文本的实际高度（使用无限高度以完整显示所有文本）
        let textRect = attributedString.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
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
        return drawRect.height
    }
    
    private func drawTitle(_ title: String, at point: CGPoint, width: CGFloat, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        
        let attributedString = NSAttributedString(string: title, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: point.x,
            y: point.y,
            width: width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
    }
    
    private func drawDescription(_ description: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        
        let attributedString = NSAttributedString(string: description, attributes: attributes)
        // 计算多行文本的实际高度（使用无限高度以完整显示所有文本）
        let textRect = attributedString.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
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
        return drawRect.height
    }
    
    /// 计算单个地点卡片的高度（卡片样式，固定高度）
    private func calculateDestinationItemHeight(_ destination: TravelDestination, nextDestination: TravelDestination?, width: CGFloat) -> CGFloat {
        let cardHeight: CGFloat = 168 // 固定卡片高度（与 DestinationRowCard 一致）
        let cardSpacing: CGFloat = 12 // 卡片之间的间距
        return cardHeight + cardSpacing
    }
    
    /// 格式化距离（优化版本，避免 Preference Access 错误）
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        
        // 使用更安全的本地化方式，避免访问系统偏好设置
        // 直接使用应用的语言设置，而不是系统偏好
        let appLanguage = LanguageManager.shared.currentLanguage.rawValue
        formatter.locale = Locale(identifier: appLanguage)
        
        return formatter.string(fromDistance: distance)
    }
    
    /// 将旅程目的地按天分组（与 MapView / TripDetailView 逻辑一致），用于清单版面按天分段显示
    private func dayGroups(for trip: TravelTrip) -> [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] {
        let sorted = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        guard !sorted.isEmpty else { return [] }
        let calendar = Calendar.current
        var groups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] = []
        var currentDayStart: Date?
        var currentList: [TravelDestination] = []
        for d in sorted {
            let dayStart = calendar.startOfDay(for: d.visitDate)
            if dayStart != currentDayStart {
                if let prev = currentDayStart {
                    groups.append((groups.count + 1, prev, currentList))
                }
                currentDayStart = dayStart
                currentList = [d]
            } else {
                currentList.append(d)
            }
        }
        if let last = currentDayStart {
            groups.append((groups.count + 1, last, currentList))
        }
        return groups
    }
    
    /// 清单版面「第 N 天」分段标题高度（上边距 + 一行文字 + 下边距）
    private static let listLayoutDaySectionHeaderHeight: CGFloat = 12 + 22 + 6
    
    private func drawRouteCard(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        let destinationCount = sortedDestinations.count
        let groups = dayGroups(for: trip)
        let showDaySections = destinationCount > 0 && groups.count > 1
        
        let cardHeight: CGFloat = 168
        let cardSpacing: CGFloat = 12
        let brand = TripImageGenerator.tripShareBrandUIColor
        
        var currentY = point.y
        
        if let iconImage = UIImage(systemName: "location.fill") {
            let iconSize: CGFloat = 22
            let iconRect = CGRect(x: point.x, y: currentY, width: iconSize, height: iconSize)
            iconImage.withTintColor(brand, renderingMode: .alwaysOriginal).draw(in: iconRect)
        }
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let titleString = NSAttributedString(string: "trip_share_route".localized, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: point.x + 34, y: currentY + 2))
        
        let countString = NSAttributedString(string: "\(destinationCount) " + "trip_share_locations_count".localized, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ])
        let countSize = countString.size()
        countString.draw(at: CGPoint(x: point.x + width - countSize.width, y: currentY + 4))
        
        currentY += 36
        
        if destinationCount > 0 {
            let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
            var cardIndex = 0
            
            if showDaySections {
                for group in groups {
                    let dateString = dateFormatter.string(from: group.dayStart)
                    let sectionTitle = String(format: "trip_route_day_title".localized, group.dayIndex, dateString)
                    currentY += drawDaySectionHeader(sectionTitle, at: CGPoint(x: point.x, y: currentY), width: width, context: context)
                    for destination in group.destinations {
                        drawDestinationCard(destination, at: CGPoint(x: point.x, y: currentY), width: width, context: context)
                        currentY += cardHeight
                        cardIndex += 1
                        if cardIndex < destinationCount { currentY += cardSpacing }
                    }
                }
            } else {
                for (index, destination) in sortedDestinations.enumerated() {
                    drawDestinationCard(destination, at: CGPoint(x: point.x, y: currentY), width: width, context: context)
                    currentY += cardHeight
                    if index < sortedDestinations.count - 1 { currentY += cardSpacing }
                }
            }
        } else {
            let emptyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            ]
            let emptyString = NSAttributedString(string: "trip_share_no_destinations".localized, attributes: emptyAttributes)
            let emptySize = emptyString.size()
            emptyString.draw(at: CGPoint(x: point.x + width / 2 - emptySize.width / 2, y: currentY + 20))
            currentY += 80
        }
        
        return currentY - point.y + 12
    }
    
    /// 绘制「第 N 天 · 日期」分段标题，返回占用高度（与 listLayoutDaySectionHeaderHeight 一致）
    private func drawDaySectionHeader(_ title: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let topMargin: CGFloat = 12
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let attributed = NSAttributedString(string: title, attributes: attributes)
        attributed.draw(at: CGPoint(x: point.x, y: point.y + topMargin))
        return Self.listLayoutDaySectionHeaderHeight
    }
    
    /// 绘制地点卡片（卡片样式，类似 DestinationRowCard）
    private func drawDestinationCard(_ destination: TravelDestination, at point: CGPoint, width: CGFloat, context: CGContext) {
        let cardHeight: CGFloat = 168
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: cardHeight)
        let cornerRadius: CGFloat = 18
        
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
        
        // 绘制标题（与 DestinationRowCard：22pt black + 轻阴影）
        let titleText = destination.name.isEmpty ? "-" : destination.name
        let titleShadow = NSShadow()
        titleShadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
        titleShadow.shadowOffset = CGSize(width: 0, height: 1)
        titleShadow.shadowBlurRadius = 2
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .black),
            .kern: -0.3 as CGFloat,
            .foregroundColor: UIColor.white,
            .shadow: titleShadow
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
        
        // 5. 卡片描边 + 阴影（与年度列表卡片语义一致）
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 6), blur: 14, color: UIColor.black.withAlphaComponent(0.10).cgColor)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(1)
        context.addPath(backgroundPath.cgPath)
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawDestinationItem(_ destination: TravelDestination, index: Int, nextDestination: TravelDestination?, at point: CGPoint, width: CGFloat, context: CGContext) {
        // 绘制序号圆圈
        let circleRect = CGRect(x: point.x, y: point.y + 14, width: 32, height: 32)
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fillEllipse(in: circleRect)
        
        // 绘制序号文字，确保居中
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let numberString = NSAttributedString(string: "\(index)", attributes: numberAttributes)
        let numberSize = numberString.size()
        let numberCenterX = point.x + 16
        let numberCenterY = point.y + 30
        numberString.draw(at: CGPoint(x: numberCenterX - numberSize.width/2, y: numberCenterY - numberSize.height/2))
        
        // 绘制目的地照片或图标（方形圆角）
        let photoRect = CGRect(x: point.x + 50, y: point.y + 8, width: 50, height: 50)
        if let photoData = destination.photoData,
           let photoImage = UIImage(data: photoData) {
            // 绘制圆角矩形
            let path = UIBezierPath(roundedRect: photoRect, cornerRadius: 8)
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()
            photoImage.draw(in: photoRect)
            context.restoreGState()
        } else {
            // 绘制默认图片（方形圆角）
            let iconRect = CGRect(x: point.x + 50, y: point.y + 8, width: 50, height: 50)
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 8)
            context.saveGState()
            context.addPath(path.cgPath)
            context.clip()
            
            // 使用 ImageMooyu 作为默认图片
            if let defaultImage = UIImage(named: "ImageMooyu") {
                // 使用原始渲染模式，确保颜色正确显示
                let originalImage = defaultImage.withRenderingMode(.alwaysOriginal)
                
                // 绘制图片，保持宽高比
                let imageAspectRatio = defaultImage.size.width / defaultImage.size.height
                let rectAspectRatio = iconRect.width / iconRect.height
                
                var drawRect: CGRect
                if imageAspectRatio > rectAspectRatio {
                    // 图片更宽，以高度为准
                    let scaledWidth = iconRect.height * imageAspectRatio
                    drawRect = CGRect(
                        x: iconRect.midX - scaledWidth/2,
                        y: iconRect.minY,
                        width: scaledWidth,
                        height: iconRect.height
                    )
                } else {
                    // 图片更高，以宽度为准
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
        
        // 绘制目的地信息 - 使用深灰色
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        nameString.draw(at: CGPoint(x: point.x + 110, y: point.y + 10))
        
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
        
        let subtitle = "\(destination.country) • \(dateFormatter.string(from: destination.visitDate))"
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        subtitleString.draw(at: CGPoint(x: point.x + 110, y: point.y + 30))
        
        // 绘制距离信息（如果有下一个地点）
        var currentY = point.y + 30 + 16 // 日期下方16pt处开始（与计算逻辑保持一致）
        if let nextDestination = nextDestination {
            let distance = destination.coordinate.distance(to: nextDestination.coordinate)
            let distanceText = formatDistance(distance)
            let distanceInfo = "→ \(distanceText) → \(nextDestination.name)"
            
            let distanceAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) // 更浅的灰色
            ]
            let distanceString = NSAttributedString(string: distanceInfo, attributes: distanceAttributes)
            let distanceSize = distanceString.size()
            distanceString.draw(at: CGPoint(x: point.x + 110, y: currentY))
            currentY += ceil(distanceSize.height) + 6 // 距离信息实际高度 + 间距
        }
        
        // 绘制旅行笔记（如果有）
        if !destination.notes.isEmpty {
            // 如果有距离信息，间距是4pt；如果没有距离信息，间距是8pt（与计算逻辑保持一致）
            let notesSpacing: CGFloat = nextDestination != nil ? 4 : 8
            let notesY = currentY + notesSpacing
            let notesWidth = width - 110 // 减去左侧的序号和照片区域
            let notesHeight = drawDestinationNotesContent(destination.notes, at: CGPoint(x: point.x + 110, y: notesY), width: notesWidth, context: context)
        }
    }
    
    /// 绘制地点笔记内容（清单版面专用，不包含标题）
    private func drawDestinationNotesContent(_ notes: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        // 绘制笔记内容（使用较小的字体以适应清单版面）
        let notesAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0), // 次要文本 #666666
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 4 // 行距
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let notesString = NSAttributedString(string: notes, attributes: notesAttributes)
        let notesRect = notesString.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // 使用实际计算的高度，不限制最大高度，确保完整显示
        let actualHeight = ceil(notesRect.height)
        
        let notesDrawRect = CGRect(
            x: point.x,
            y: point.y,
            width: width,
            height: actualHeight
        )
        
        notesString.draw(in: notesDrawRect)
        
        return actualHeight
    }
    
    private func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
        // 获取 AppIcon
        let appIcon: UIImage? = {
            if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let lastIcon = iconFiles.last {
                return UIImage(named: lastIcon)
            }
            return UIImage(named: "AppIcon")
        }()
        
        // 获取签名文本（移除星星图标）
        let signatureText = "trip_share_signature".localized.replacingOccurrences(of: "✨", with: "").replacingOccurrences(of: "✨ ", with: "").trimmingCharacters(in: .whitespaces)
        
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let signatureString = NSAttributedString(string: signatureText, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        
        // 图标尺寸
        let iconSize: CGFloat = 20
        let iconSpacing: CGFloat = 6 // 图标与文字的间距
        
        // 计算总宽度（图标 + 间距 + 文字）
        let totalWidth = iconSize + iconSpacing + signatureSize.width
        
        // 绘制 AppIcon（圆形）
        if let appIcon = appIcon {
            let iconRect = CGRect(
                x: point.x - totalWidth / 2,
                y: point.y + (signatureSize.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            // 绘制圆形图标
            context.saveGState()
            let iconPath = UIBezierPath(ovalIn: iconRect)
            context.addPath(iconPath.cgPath)
            context.clip()
            appIcon.draw(in: iconRect)
            context.restoreGState()
        }
        
        // 绘制签名文字（在图标右侧）
        let textX = point.x - totalWidth / 2 + iconSize + iconSpacing
        signatureString.draw(at: CGPoint(x: textX, y: point.y))
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width/2, y: point.y + 25))
    }
}

// MARK: - 共享九宫格布局工具（可复用）
