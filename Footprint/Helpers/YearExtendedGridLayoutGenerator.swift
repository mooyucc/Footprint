//
//  YearExtendedGridLayoutGenerator.swift
//  Footprint
//
//  从 YearImageGenerator.swift 提取（编译拆分）
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation

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
            
            // 绘制三色线性渐变背景（符合App配色标准，与旅程分享一致）
            YearImageGenerator.drawGradientBackground(in: CGRect(origin: .zero, size: imageSize), context: cgContext)
            
            var currentY: CGFloat = 0
            
            // 绘制标题区域（使用共享方法）
            currentY += 40
            let headerHeight = YearImageGenerator.drawHeader(year: year, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += headerHeight // drawHeader 已经包含了到统计卡片的间距
            
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
            
            // 绘制底部签名（与旅程分享图片统一）
            currentY += 24 // 与上面内容的间距（与旅程分享统一）
            YearImageGenerator.drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }
    
    private func calculateContentHeight(year: Int, destinations: [TravelDestination], width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        
        height += 40
        
        // 标题区域（使用与 drawHeader 相同的计算方式，确保完全一致）
        // 1. 用户头像和用户名区域（高度：头像高度 + 间距）
        let avatarSize: CGFloat = 40 // 头像大小
        height += avatarSize + 16 // 头像 + 到标题的间距
        
        // 2. 标题区域（带品牌色高亮，与旅程分享一致）
        let yearTitle = LanguageManager.shared.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold), // 与旅程分享一致
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let titleString = NSAttributedString(string: yearTitle, attributes: titleAttributes)
        // 计算多行文本的实际高度（使用无限高度以完整显示所有文本）
        let titleRect = titleString.boundingRect(
            with: CGSize(width: width - 40, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleSize = ceil(titleRect.height)
        height += titleSize + 20 // 标题高度 + 到统计卡片的间距
        
        // 统计信息卡片
        height += 100 + 20
        
        // 扩展网格区域（每9张图片重复九宫格布局，与旅程分享一致）
        if !destinations.isEmpty {
            let groupSpacing: CGFloat = 6 // 每组九宫格之间的间距（与其他网格间距一致）
            let chunkSize = 9
            let chunks = destinations.chunked(into: chunkSize)
            
            for (chunkIndex, chunk) in chunks.enumerated() {
                // 如果不是第一组，添加组间距
                if chunkIndex > 0 {
                    height += groupSpacing
                }
                
                // 计算该组的高度（最多9张图片）
                let groupCount = min(chunk.count, 9)
                height += GridLayoutHelper.calculateGridHeight(photoCount: groupCount, width: width - 40)
            }
            
            // 注意：不在这里添加padding，因为绘制时网格后直接是签名间距24，没有额外的20点padding
        } else {
            height += 200 // 空状态高度
        }
        
        // 底部签名区域（与旅程分享图片统一）
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
        
        // 底部签名区域总高度计算（与旅程分享图片统一）：
        // - 与上面内容的间距: 24（与旅程分享统一）
        // - 主签名高度: signatureHeight
        // - 主副标题间距: 25（与drawSignature绘制时保持一致）
        // - 副标题高度: subtitleHeight
        // - 底部边距: 16（确保副标题完整显示，有足够的底部空间）
        height += 24 + signatureHeight + 25 + subtitleHeight + 16
        
        return height
    }
    
    private func drawExtendedGrid(destinations: [TravelDestination], at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        guard !destinations.isEmpty else { return 0 }
        
        let groupSpacing: CGFloat = 6 // 每组九宫格之间的间距（与其他网格间距一致）
        var currentY = point.y
        var globalIndex = 1 // 全局序号，用于显示序号标签
        
        // 将目的地分成每9个一组
        let chunkSize = 9
        let chunks = destinations.chunked(into: chunkSize)
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            // 如果不是第一组，添加组间距
            if chunkIndex > 0 {
                currentY += groupSpacing
            }
            
            // 获取该组的地点照片数据（每组最多9张，绘制完成后会及时释放）
            let destinationImages: [UIImage] = chunk.compactMap { destination in
                if let photoData = destination.photoData,
                   let photoImage = UIImage(data: photoData) {
                    return photoImage
                } else if let defaultImage = UIImage(named: "ImageMooyu") {
                    return defaultImage.withRenderingMode(.alwaysOriginal)
                }
                return nil
            }
            
            guard !destinationImages.isEmpty else { continue }
            
            // 使用共享的九宫格布局工具绘制该组
            let groupHeight = GridLayoutHelper.drawGridLayout(
                images: destinationImages,
                destinations: chunk,
                startIndex: globalIndex,
                at: CGPoint(x: point.x, y: currentY),
                width: width,
                context: context,
                drawMainImage: { image, destination, index, rect, ctx in
                    self.drawMainImageDestination(image, destination: destination, index: index, in: rect, context: ctx)
                },
                drawGridPhoto: { image, destination, index, rect, ctx in
                    self.drawDestinationGridPhoto(image, destination: destination, index: index, in: rect, context: ctx)
                }
            )
            
            currentY += groupHeight
            globalIndex += chunk.count
        }
        
        return currentY - point.y
    }
    
    // 绘制主图（用于年份分享图片的地点主图）
    private func drawMainImageDestination(_ image: UIImage, destination: TravelDestination, index: Int, in rect: CGRect, context: CGContext) {
        // 绘制圆角矩形（圆角12pt）
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        
        // 计算图片的绘制区域（保持宽高比，填充裁剪）
        let imageAspectRatio = image.size.width / image.size.height
        let rectAspectRatio = rect.width / rect.height
        
        var drawRect = rect
        if imageAspectRatio > rectAspectRatio {
            // 图片更宽，以高度为准，居中裁剪
            let scaledWidth = rect.height * imageAspectRatio
            drawRect = CGRect(
                x: rect.midX - scaledWidth / 2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            // 图片更高，以宽度为准，居中裁剪
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
        
        // 绘制序号标签（左上角）
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
        
        // 绘制目的地名称（底部，带半透明背景，支持文本截断）
        let namePadding: CGFloat = 8
        let availableWidth = rect.width - namePadding * 2 // 可用文本宽度
        
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail // 超出部分用省略号截断
                return style
            }()
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        
        // 计算文本在有限宽度内的实际大小（支持截断）
        let nameRect = nameString.boundingRect(
            with: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let nameHeight = ceil(nameRect.height)
        
        let nameBackgroundRect = CGRect(
            x: rect.minX,
            y: rect.maxY - nameHeight - namePadding * 2,
            width: rect.width,
            height: nameHeight + namePadding * 2
        )
        
        // 绘制半透明背景（带圆角，半径与主图一致为12）
        let cornerRadius: CGFloat = 12
        let backgroundPath = UIBezierPath(
            roundedRect: nameBackgroundRect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.addPath(backgroundPath.cgPath)
        context.fillPath()
        
        // 绘制文字（在指定矩形内绘制，自动处理截断）
        let textRect = CGRect(
            x: rect.minX + namePadding,
            y: nameBackgroundRect.midY - nameHeight / 2,
            width: availableWidth,
            height: nameHeight
        )
        nameString.draw(in: textRect)
    }
    
    // 绘制网格中的单张地点照片（带圆角12pt和智能裁剪，支持文本截断）
    private func drawDestinationGridPhoto(_ image: UIImage, destination: TravelDestination, index: Int, in rect: CGRect, context: CGContext) {
        // 绘制圆角矩形（圆角12pt）
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        
        // 计算图片的绘制区域（保持宽高比，填充裁剪）
        let imageAspectRatio = image.size.width / image.size.height
        var drawRect = rect
        
        if imageAspectRatio > 1.0 {
            // 图片更宽，以高度为准，居中裁剪
            let scaledWidth = rect.height * imageAspectRatio
            drawRect = CGRect(
                x: rect.midX - scaledWidth / 2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            // 图片更高，以宽度为准，居中裁剪
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
        
        // 绘制序号标签（左上角）
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
        
        // 绘制目的地名称（底部，带半透明背景，支持文本截断）
        let namePadding: CGFloat = 8
        let availableWidth = rect.width - namePadding * 2 // 可用文本宽度
        
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail // 超出部分用省略号截断
                return style
            }()
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        
        // 计算文本在有限宽度内的实际大小（支持截断）
        let nameRect = nameString.boundingRect(
            with: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let nameHeight = ceil(nameRect.height)
        
        let nameBackgroundRect = CGRect(
            x: rect.minX,
            y: rect.maxY - nameHeight - namePadding * 2,
            width: rect.width,
            height: nameHeight + namePadding * 2
        )
        
        // 绘制半透明背景（带圆角，半径与网格照片一致为12）
        let cornerRadius: CGFloat = 12
        let backgroundPath = UIBezierPath(
            roundedRect: nameBackgroundRect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.addPath(backgroundPath.cgPath)
        context.fillPath()
        
        // 绘制文字（在指定矩形内绘制，自动处理截断）
        let textRect = CGRect(
            x: rect.minX + namePadding,
            y: nameBackgroundRect.midY - nameHeight / 2,
            width: availableWidth,
            height: nameHeight
        )
        nameString.draw(in: textRect)
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

