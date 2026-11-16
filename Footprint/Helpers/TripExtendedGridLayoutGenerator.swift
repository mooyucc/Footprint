//
//  TripExtendedGridLayoutGenerator.swift
//  Footprint
//
//  从 TripImageGenerator.swift 提取（编译拆分）
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation
import MapKit

// MARK: - 扩展网格版面生成器（支持超过9个地点）
struct ExtendedGridLayoutGenerator: TripLayoutGenerator {
    func generateImage(from trip: TravelTrip) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        
        // 计算内容高度
        let contentHeight = calculateContentHeight(for: trip, destinations: sortedDestinations, width: screenWidth)
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        print("📏 [ExtendedGridLayout] 计算高度: \(contentHeight), 图片尺寸: \(imageSize), 描述长度: \(trip.desc.count), 地点数量: \(sortedDestinations.count)")
        
        // 创建图片渲染器
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
            
            // 绘制标题区域
            currentY += 40
            let headerHeight = drawHeader(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            // 标题区域高度（drawHeader 已包含到时间卡片的间距20pt）
            currentY += headerHeight
            
            // 行程概要：开始 / 结束 / 时长
            let statsH = TripImageGenerator.drawTripShareModernStatsBlock(
                trip: trip,
                at: CGPoint(x: 20, y: currentY),
                width: screenWidth - 40,
                context: cgContext
            )
            currentY += statsH + 4
            
            // 绘制扩展网格拼图（按天分段，某天超过 9 个地点时多行九宫格）
            if sortedDestinations.isEmpty {
                drawEmptyState(at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                currentY += 200
            } else {
                let groups = dayGroups(for: trip)
                if groups.count <= 1 {
                    let result = drawExtendedGrid(destinations: sortedDestinations, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext, startIndex: 1)
                    currentY += result.height
                } else {
                    var globalIndex = 1
                    for group in groups {
                        let headerHeight = drawDaySectionHeader(dayIndex: group.dayIndex, dayStart: group.dayStart, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                        currentY += headerHeight
                        let result = drawExtendedGrid(destinations: group.destinations, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext, startIndex: globalIndex)
                        currentY += result.height
                        globalIndex = result.nextIndex
                    }
                }
            }
            
            // 绘制底部签名（优化间距以减少空白，与清单版面统一）
            currentY += 24 // 与上面地点图片的间距（与清单版面统一）
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
            // 确保底部有足够的边距（副标题在 point.y + 25，需要额外空间）
            // 高度计算中已包含：signatureHeight + 12 + subtitleHeight + 4
            // 这里不需要额外添加，因为 currentY 只是用于绘制定位
        }
    }
    
    private func calculateContentHeight(for trip: TravelTrip, destinations: [TravelDestination], width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        let contentWidth = width - 40 // 内容宽度（左右边距各20）
        
        // 顶部padding
        height += 40
        
        // 用户头像和用户名区域（高度：头像高度 + 间距）
        let avatarSize: CGFloat = 40 // 头像大小
        height += avatarSize + 16 // 头像 + 到标题的间距
        
        // 标题区域（动态计算，包括标题和描述，支持多行）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold), // 与地点分享图片一致
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
        // 计算多行文本的实际高度（使用无限高度以完整显示所有文本）
        let titleRect = titleString.boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleSize = ceil(titleRect.height)
        // 扩展网格版面不显示描述文字，只显示标题
        var headerHeight: CGFloat = titleSize + 20 // 标题高度 + 到时间卡片的间距（20pt）
        height += headerHeight // 标题区域高度（已包含到统计区的间距）
        
        // 日期三列
        height += TripImageGenerator.tripShareModernStatsBlockHeight(contentWidth: contentWidth) + 4
        
        // 扩展网格区域（按天分段，每天内每 9 个一组多行九宫格）
        if !destinations.isEmpty {
            let groupSpacing: CGFloat = 6
            let chunkSize = 9
            let groups = dayGroups(for: trip)
            
            if groups.count <= 1 {
                let chunks = destinations.chunked(into: chunkSize)
                for (chunkIndex, chunk) in chunks.enumerated() {
                    if chunkIndex > 0 { height += groupSpacing }
                    height += GridLayoutHelper.calculateGridHeight(photoCount: min(chunk.count, 9), width: contentWidth)
                }
            } else {
                for group in groups {
                    height += Self.gridLayoutDaySectionHeaderHeight
                    let dayChunks = group.destinations.chunked(into: chunkSize)
                    for (chunkIndex, chunk) in dayChunks.enumerated() {
                        if chunkIndex > 0 { height += groupSpacing }
                        height += GridLayoutHelper.calculateGridHeight(photoCount: min(chunk.count, 9), width: contentWidth)
                    }
                }
            }
        } else {
            height += 200 // 空状态高度
        }
        
        // 底部签名区域高度（优化间距以减少空白，与清单版面统一）
        // 计算签名的实际高度
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14)
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureRect = signatureString.boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let signatureHeight = ceil(signatureRect.height)
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleRect = subtitleString.boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let subtitleHeight = ceil(subtitleRect.height)
        
        // 底部签名区域总高度计算（优化间距以减少空白，与清单版面统一）：
        // - 与上面地点图片的间距: 24（与清单版面统一）
        // - 主签名高度: signatureHeight
        // - 主副标题间距: 25（与drawSignature绘制时保持一致）
        // - 副标题高度: subtitleHeight
        // - 底部边距: 16（确保副标题完整显示，有足够的底部空间）
        height += 24 + signatureHeight + 25 + subtitleHeight + 16
        
        return height
    }
    
    private func drawHeader(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        var currentY: CGFloat = point.y
        
        // 1. 绘制用户头像和用户名（与地点分享图片一致）
        let avatarSize: CGFloat = 40
        let userInfoHeight = TripImageGenerator.drawUserInfo(
            at: CGPoint(x: point.x, y: currentY),
            avatarSize: avatarSize,
            context: context
        )
        currentY += userInfoHeight + 16 // 用户信息高度 + 到标题的间距
        
        // 2. 绘制标题（带品牌色高亮，与地点分享图片一致）
        let titleHeight = TripImageGenerator.drawDestinationTitle(
            title: trip.name,
            at: CGPoint(x: point.x, y: currentY),
            width: width,
            context: context
        )
        // 扩展网格版面不显示描述文字，只显示标题
        currentY += titleHeight + 20 // 标题高度 + 到时间卡片的间距
        
        return currentY - point.y // 返回实际占用的高度
    }
    
    /// 将旅程目的地按天分组（与清单版面 / MapView 逻辑一致），用于网格版面按天分段
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
    
    /// 网格版面「第 N 天」分段标题高度（与清单版面一致）
    private static let gridLayoutDaySectionHeaderHeight: CGFloat = 12 + 22 + 6
    
    /// 绘制「第 N 天 · 日期」分段标题，返回占用高度
    private func drawDaySectionHeader(dayIndex: Int, dayStart: Date, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
        let dateString = dateFormatter.string(from: dayStart)
        let title = String(format: "trip_route_day_title".localized, dayIndex, dateString)
        let topMargin: CGFloat = 12
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let attributed = NSAttributedString(string: title, attributes: attributes)
        attributed.draw(at: CGPoint(x: point.x, y: point.y + topMargin))
        return Self.gridLayoutDaySectionHeaderHeight
    }
    
    private func drawExtendedGrid(destinations: [TravelDestination], at point: CGPoint, width: CGFloat, context: CGContext, startIndex: Int = 1) -> (height: CGFloat, nextIndex: Int) {
        guard !destinations.isEmpty else { return (0, startIndex) }
        
        let groupSpacing: CGFloat = 6
        var currentY = point.y
        var globalIndex = startIndex
        
        let chunkSize = 9
        let chunks = destinations.chunked(into: chunkSize)
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            if chunkIndex > 0 {
                currentY += groupSpacing
            }
            
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
        
        return (currentY - point.y, globalIndex)
    }
    
    // 绘制主图（用于旅程分享图片的地点主图）
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
        
        // 绘制目的地名称（底部，带半透明背景）
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
    
    // 绘制网格中的单张地点照片（带圆角12pt和智能裁剪）
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
        
        // 绘制目的地名称（底部，带半透明背景）
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
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // #666666
        ]
        let emptyString = NSAttributedString(string: "trip_share_no_destinations".localized, attributes: emptyAttributes)
        let emptySize = emptyString.size()
        emptyString.draw(at: CGPoint(x: point.x + width/2 - emptySize.width/2, y: point.y + 100))
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
