//
//  YearGridLayoutGenerator.swift
//  Footprint
//
//  从 YearImageGenerator.swift 提取（编译拆分）
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation

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
        
        let userName = UserProfileManager.shared.displayName
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
        
        let userName = UserProfileManager.shared.displayName
        
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
        
        // 加载图片数据（最多9张，内存影响有限，但绘制完成后会及时释放）
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
