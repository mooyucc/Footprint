//
//  TripImageGenerator.swift
//  Footprint
//
//  Created on 2025/10/20.
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation
import MapKit

// MARK: - 版面生成器协议
protocol TripLayoutGenerator {
    func generateImage(from trip: TravelTrip) -> UIImage?
}

// MARK: - 地点分享版面生成器协议
protocol DestinationLayoutGenerator {
    func generateImage(
        from destination: TravelDestination,
        canvasSize: CGSize,
        scale: CGFloat,
        coverPhotoIndex: Int,
        overlayCaption: String?
    ) -> UIImage?
}

// MARK: - Array 扩展（用于分组）
extension Array {
    /// 将数组分成指定大小的块
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - 图片生成器主类
struct TripImageGenerator {
    /// 生成旅程图片（使用默认行程版面，保持向后兼容）
    static func generateTripImage(from trip: TravelTrip) -> UIImage? {
        return ExtendedGridLayoutGenerator().generateImage(from: trip)
    }
    
    /// 根据版面类型生成图片
    static func generateTripImage(from trip: TravelTrip, layout: TripShareLayout) -> UIImage? {
        switch layout {
        case .extendedGrid:
            return ExtendedGridLayoutGenerator().generateImage(from: trip)
        case .timeline:
            return TimelineLayoutGenerator().generateImage(from: trip)
        }
    }
    
    /// 生成地点分享图片（默认大图打卡 + 3:4）
    static func generateDestinationImage(from destination: TravelDestination) -> UIImage? {
        return generateDestinationImage(
            from: destination,
            layout: .photoPoster,
            aspectRatio: .portrait34
        )
    }
    
    /// 根据版面与画布比例生成地点分享图片
    static func generateDestinationImage(
        from destination: TravelDestination,
        layout: DestinationShareLayout,
        aspectRatio: DestinationShareAspectRatio = .portrait34,
        scale: CGFloat = 2,
        coverPhotoIndex: Int = 0,
        overlayCaption: String? = nil
    ) -> UIImage? {
        let canvasSize = aspectRatio.canvasSize
        switch layout {
        case .photoPoster:
            return PhotoPosterDestinationLayoutGenerator().generateImage(
                from: destination,
                canvasSize: canvasSize,
                scale: scale,
                coverPhotoIndex: coverPhotoIndex,
                overlayCaption: overlayCaption
            )
        case .gallerySide:
            return GallerySideDestinationLayoutGenerator().generateImage(
                from: destination,
                canvasSize: canvasSize,
                scale: scale,
                coverPhotoIndex: coverPhotoIndex,
                overlayCaption: overlayCaption
            )
        case .galleryStack:
            return GalleryStackDestinationLayoutGenerator().generateImage(
                from: destination,
                canvasSize: canvasSize,
                scale: scale,
                coverPhotoIndex: coverPhotoIndex,
                overlayCaption: overlayCaption
            )
        }
    }
    
    /// 生成地点分享图片（旧方法，已废弃，保留用于向后兼容）
    @available(*, deprecated, message: "使用 generateDestinationImage(from:layout:) 替代")
    static func generateDestinationImageClassic(from destination: TravelDestination) -> UIImage? {
        // 获取屏幕宽度，并设置左右边距
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 32 // 左右边距（参考图有较大边距）
        let topPadding: CGFloat = 40 // 顶部边距
        let bottomPadding: CGFloat = 20 // 底部边距（与布局简图说明一致）
        let contentWidth = screenWidth - horizontalPadding * 2
        let titleWidth = contentWidth * 0.8
        
        // 获取所有照片（优先使用 photoDatas，如果没有则使用 photoData）
        let allPhotos: [Data] = {
            if !destination.photoDatas.isEmpty {
                return destination.photoDatas
            } else if let photoData = destination.photoData {
                return [photoData]
            } else {
                return []
            }
        }()
        
        let photoCount = min(allPhotos.count, 9)
        
        // 计算内容高度
        var contentHeight: CGFloat = 0
        contentHeight += topPadding
        
        // 用户头像和用户名区域（高度：头像高度 + 间距）
        let avatarSize: CGFloat = 40 // 头像大小
        let userNameHeight: CGFloat = 20 // 用户名文字高度
        contentHeight += avatarSize + 16 // 头像 + 到标题的间距
        
        // 标题（需要计算实际高度，支持多行）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let titleString = NSAttributedString(string: destination.name, attributes: titleAttributes)
        // 使用boundingRect计算多行文本的实际高度，与绘制时保持一致
        let maxTitleHeight: CGFloat = 200 // 最大高度限制
        let titleRect = titleString.boundingRect(
            with: CGSize(width: contentWidth, height: maxTitleHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleHeight = ceil(titleRect.height)
        
        contentHeight += titleHeight + 20 // 标题 + 到笔记的间距
        
        // 笔记区域（如果有，放在标题下面）
        if !destination.notes.isEmpty {
            let notesAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 6 // 增加行距，提升可读性（与绘制时保持一致）
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            let notesString = NSAttributedString(string: destination.notes, attributes: notesAttributes)
            let notesRect = notesString.boundingRect(
                with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            contentHeight += ceil(notesRect.height) + 20 // 笔记高度 + 到时间的间距
        } else {
            contentHeight += 20 // 如果没有笔记，直接到时间的间距
        }
        
        // 时间信息（需要计算实际高度）
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .full, timeStyle: .none)
        let dateString = dateFormatter.string(from: destination.visitDate)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16)
        ]
        let dateStringAttr = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateRect = dateStringAttr.boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let dateHeight = ceil(dateRect.height)
        contentHeight += dateHeight
        
        // 照片区域（根据数量智能布局）
        let photoSpacing: CGFloat = 6 // 统一图片间距（上下左右一致）
        if photoCount > 0 {
            if photoCount == 1 {
                // 单张照片：显示为大图（3:2比例，宽度×2/3，与布局简图说明一致）
                contentHeight += contentWidth * 2.0 / 3.0 // 大图高度（3:2比例）
            } else if photoCount == 9 {
                // 9张照片：不设置主图，直接3x3排列
                let cols = 3
                let photoSize = (contentWidth - photoSpacing * CGFloat(cols - 1)) / CGFloat(cols)
                let rows = 3
                contentHeight += CGFloat(rows) * photoSize + CGFloat(rows - 1) * photoSpacing
            } else {
                // 多张照片（2-8张）：第一张大图 + 其余网格
                let mainImageHeight = contentWidth * 0.6 // 主图高度
                let remainingPhotos = photoCount - 1
                let gridHeight = calculateSmartGridHeight(photoCount: remainingPhotos, width: contentWidth)
                contentHeight += mainImageHeight + photoSpacing + gridHeight // 主图 + 间距 + 网格
            }
        }
        
        // 底部签名区域（与旅程分享图片统一）
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
        
        // 底部签名区域总高度计算（与旅程分享图片统一）：
        // - 与上面照片的间距: 24（与旅程分享统一）
        // - 主签名高度: signatureHeight
        // - 主副标题间距: 25（与drawSignature绘制时保持一致）
        // - 副标题高度: subtitleHeight
        // - 底部边距: 16（确保副标题完整显示，有足够的底部空间）
        contentHeight += 24 + signatureHeight + 25 + subtitleHeight + 16
        
        // 计算右侧封面图尺寸（3:2 高宽比）
        let rightCoverHeight = contentHeight  // 高度 = 左侧内容高度
        let rightCoverWidth = rightCoverHeight * 2.0 / 3.0  // 宽度 = 高度 * 2/3（3:2比例）
        let columnSpacing: CGFloat = 12  // 左右分栏之间的间距
        
        // 整体图片尺寸 = 左侧宽度 + 右侧宽度 + 间距
        let totalImageWidth = screenWidth + rightCoverWidth + columnSpacing
        let imageSize = CGSize(width: totalImageWidth, height: contentHeight)
        
        // 创建图片渲染器
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 绘制三色线性渐变背景（符合App配色标准）
            drawGradientBackground(in: CGRect(origin: .zero, size: imageSize), context: cgContext)
            
            var currentY: CGFloat = topPadding
            
            // 绘制用户头像和用户名
            let avatarSize: CGFloat = 40
            let userInfoHeight = drawUserInfo(
                at: CGPoint(x: horizontalPadding, y: currentY),
                avatarSize: avatarSize,
                context: cgContext
            )
            currentY += userInfoHeight + 16 // 用户信息高度 + 到标题的间距
            
            // 绘制标题（只绘制标题，不绘制副标题）
            let titleHeight = drawDestinationTitle(
                title: destination.name,
                at: CGPoint(x: horizontalPadding, y: currentY),
                width: contentWidth,
                context: cgContext
            )
            currentY += titleHeight + 20 // 标题高度 + 到笔记的间距
            
            // 绘制笔记（如果有，放在标题下面）
            if !destination.notes.isEmpty {
                let notesHeight = drawDestinationNotesBelowTitle(
                    destination.notes,
                    at: CGPoint(x: horizontalPadding, y: currentY),
                    width: contentWidth,
                    context: cgContext
                )
                currentY += notesHeight + 20 // 笔记高度 + 到时间的间距
            } else {
                currentY += 20 // 如果没有笔记，直接到时间的间距
            }
            
            // 绘制时间信息（需要计算实际高度）
            let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .full, timeStyle: .none)
            let dateString = dateFormatter.string(from: destination.visitDate)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16)
            ]
            let dateStringAttr = NSAttributedString(string: dateString, attributes: dateAttributes)
            let dateRect = dateStringAttr.boundingRect(
                with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let dateHeight = ceil(dateRect.height)
            drawDestinationDateSimple(for: destination, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
            currentY += dateHeight
            
            // 绘制照片（智能布局）
            let photoSpacing: CGFloat = 6 // 统一图片间距（上下左右一致）
        if photoCount > 0 {
            if photoCount == 1 {
                // 单张照片：显示为大图（3:2比例，宽度×2/3，与布局简图说明一致）
                autoreleasepool {
                    if let photoImage = UIImage(data: allPhotos[0]) {
                        let mainImageHeight = contentWidth * 2.0 / 3.0 // 3:2比例
                        let mainImageRect = CGRect(x: horizontalPadding, y: currentY, width: contentWidth, height: mainImageHeight)
                        drawMainImage(photoImage, in: mainImageRect, context: cgContext)
                        currentY += mainImageHeight
                    }
                }
                } else if photoCount == 9 {
                    // 9张照片：不设置主图，直接3x3排列（所有照片圆角12pt）
                    let cols = 3
                    let photoSize = (contentWidth - photoSpacing * CGFloat(cols - 1)) / CGFloat(cols)
                    var gridY = currentY
                    
                    for row in 0..<3 {
                        var gridX = horizontalPadding
                        for col in 0..<cols {
                            let index = row * cols + col
                            autoreleasepool {
                                if index < allPhotos.count,
                                   let photoImage = UIImage(data: allPhotos[index]) {
                                    let photoRect = CGRect(x: gridX, y: gridY, width: photoSize, height: photoSize)
                                    drawGridPhoto(photoImage, in: photoRect, context: cgContext)
                                }
                            }
                            gridX += photoSize + photoSpacing
                        }
                        if row < 2 {
                            gridY += photoSize + photoSpacing
                        } else {
                            gridY += photoSize
                        }
                    }
                        currentY = gridY
                } else {
                    // 多张照片（2-8张）：第一张大图 + 其余网格
                    autoreleasepool {
                        if let mainPhotoImage = UIImage(data: allPhotos[0]) {
                            let mainImageHeight = contentWidth * 0.6
                            let mainImageRect = CGRect(x: horizontalPadding, y: currentY, width: contentWidth, height: mainImageHeight)
                            drawMainImage(mainPhotoImage, in: mainImageRect, context: cgContext)
                            currentY += mainImageHeight + photoSpacing
                        }
                    }
                    
                    // 绘制其余照片的网格
                    let remainingPhotos = Array(allPhotos[1..<photoCount])
                    let gridHeight = drawSmartPhotoGrid(
                        photos: remainingPhotos,
                        at: CGPoint(x: horizontalPadding, y: currentY),
                        width: contentWidth,
                        context: cgContext
                    )
                    currentY += gridHeight
                }
            }
            
            // 绘制底部签名（与旅程分享图片统一）
            currentY += 24 // 与上面照片的间距（与旅程分享统一）
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: contentWidth, context: cgContext)
            
            // 绘制右侧封面图（3:2比例，无圆角）
            if let coverPhoto = allPhotos.first, let coverImage = UIImage(data: coverPhoto) {
                let rightCoverX = screenWidth + columnSpacing
                let rightCoverRect = CGRect(
                    x: rightCoverX,
                    y: 0,
                    width: rightCoverWidth,
                    height: rightCoverHeight
                )
                drawRightCoverImage(coverImage, in: rightCoverRect, context: cgContext)
            }
        }
    }
    
    // MARK: - 地点图片绘制辅助方法
    
    /// 绘制三色线性渐变背景（符合App配色标准）
    /// 使用 AppColorScheme 统一方法
    static func drawGradientBackground(in rect: CGRect, context: CGContext) {
        AppColorScheme.drawGradientBackground(in: rect, context: context, colorScheme: .light)
    }
    
    // MARK: - 旅程分享（现代 UI：渐变上直接排版，与 StatsImageGenerator / 风格指南一致）
    
    /// 与分享图一致的旅程品牌色
    static var tripShareBrandUIColor: UIColor {
        UIColor(BrandColorManager.shared.currentBrandColor)
    }
    
    /// 用于高度预估：日期三列（开始 / 结束 / 时长）
    static func tripShareModernStatsBlockHeight(contentWidth _: CGFloat) -> CGFloat {
        124
    }
    
    /// 绘制：三列「开始 / 结束 / 时长」，无白底大卡片
    static func drawTripShareModernStatsBlock(trip: TravelTrip, at origin: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        drawTripShareDateStrip(trip: trip, at: origin, width: width, context: context)
    }
    
    private static func drawTripShareDateStrip(trip: TravelTrip, at origin: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let brand = tripShareBrandUIColor
        let colGap: CGFloat = 12
        // 时长列窄且靠右；剩余宽度平分给开始/结束，便于日期单行显示
        let durationColW: CGFloat = 72
        let dateColW = (width - durationColW - 2 * colGap) / 2
        let df = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
        let startStr = df.string(from: trip.startDate)
        let endStr = df.string(from: trip.endDate)
        let days = trip.durationDays
        
        let iconSide: CGFloat = 28
        var bottoms: [CGFloat] = [origin.y, origin.y, origin.y]
        
        for col in 0..<3 {
            let isDuration = col == 2
            let colW = isDuration ? durationColW : dateColW
            let x: CGFloat = isDuration
                ? origin.x + width - durationColW
                : origin.x + CGFloat(col) * (dateColW + colGap)
            var y = origin.y
            
            let iconName: String
            let labelKey: String
            switch col {
            case 0:
                iconName = "calendar.badge.plus"
                labelKey = "trip_share_start"
            case 1:
                iconName = "calendar"
                labelKey = "trip_share_end"
            default:
                iconName = "clock"
                labelKey = "trip_share_duration"
            }
            
            if let img = UIImage(systemName: iconName) {
                let iconX = isDuration ? x + (colW - iconSide) / 2 : x
                img.withTintColor(brand, renderingMode: .alwaysOriginal)
                    .draw(in: CGRect(x: iconX, y: y, width: iconSide, height: iconSide))
            }
            y += iconSide + 10
            
            if isDuration {
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .black),
                    .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
                    .kern: -0.9 as CGFloat
                ]
                let vs = NSAttributedString(string: "\(days)", attributes: valueAttrs)
                let vsSize = vs.size()
                vs.draw(at: CGPoint(x: x + (colW - vsSize.width) / 2, y: y))
                y += vsSize.height + 8
            } else {
                let dateStr = col == 0 ? startStr : endStr
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
                ]
                let vs = NSAttributedString(string: dateStr, attributes: valueAttrs)
                let b = vs.boundingRect(
                    with: CGSize(width: colW, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                vs.draw(in: CGRect(x: x, y: y, width: colW, height: ceil(b.height)))
                y += ceil(b.height) + 8
            }
            
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            ]
            let ls = NSAttributedString(string: labelKey.localized, attributes: labelAttrs)
            let lb = ls.boundingRect(
                with: CGSize(width: colW, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let labelX = isDuration ? x + (colW - lb.width) / 2 : x
            ls.draw(in: CGRect(x: labelX, y: y, width: ceil(lb.width), height: ceil(lb.height)))
            y += ceil(lb.height)
            bottoms[col] = y
        }
        
        return max(bottoms[0], bottoms[1], bottoms[2]) - origin.y
    }
    
    /// 绘制用户头像和用户名
    /// `userNameFontSize` / `userNameSpacing` 默认保持旅程、年份分享卡的现有比例。
    static func drawUserInfo(
        at point: CGPoint,
        avatarSize: CGFloat,
        context: CGContext,
        userNameFontSize: CGFloat = 16,
        userNameSpacing: CGFloat = 12
    ) -> CGFloat {
        let profile = UserProfileManager.shared
        let userName = profile.displayName
        let avatarImage = profile.userAvatarImage
        
        // 获取品牌颜色作为默认头像背景色
        let brandColor = BrandColorManager.shared.currentBrandColor
        let brandUIColor = UIColor(brandColor)
        
        // 绘制头像
        let avatarRect = CGRect(x: point.x, y: point.y, width: avatarSize, height: avatarSize)
        
        if let avatarImage = avatarImage {
            // 如果有用户头像，绘制圆形头像
            context.saveGState()
            let avatarPath = UIBezierPath(ovalIn: avatarRect)
            context.addPath(avatarPath.cgPath)
            context.clip()
            
            // 缩放头像以适应圆形
            let imageSize = avatarImage.size
            let scale = max(avatarSize / imageSize.width, avatarSize / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let imageRect = CGRect(
                x: point.x + (avatarSize - scaledSize.width) / 2,
                y: point.y + (avatarSize - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            avatarImage.draw(in: imageRect)
            context.restoreGState()
        } else {
            // 如果没有头像，绘制默认圆形图标
            context.saveGState()
            
            // 绘制圆形背景（使用品牌颜色）
            context.setFillColor(brandUIColor.cgColor)
            let avatarPath = UIBezierPath(ovalIn: avatarRect)
            context.addPath(avatarPath.cgPath)
            context.fillPath()
            
            // 绘制白色人形图标
            if let personIcon = UIImage(systemName: "person.fill") {
                let iconSize: CGFloat = avatarSize * 0.5
                let iconRect = CGRect(
                    x: point.x + (avatarSize - iconSize) / 2,
                    y: point.y + (avatarSize - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                let tintedIcon = personIcon.withTintColor(.white, renderingMode: .alwaysOriginal)
                tintedIcon.draw(in: iconRect)
            }
            
            context.restoreGState()
        }
        
        // 绘制用户名
        let userNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: userNameFontSize, weight: .medium),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let userNameString = NSAttributedString(string: userName, attributes: userNameAttributes)
        let userNameX = point.x + avatarSize + userNameSpacing
        let userNameY = point.y + (avatarSize - userNameString.size().height) / 2 // 垂直居中
        userNameString.draw(at: CGPoint(x: userNameX, y: userNameY))
        
        // 返回用户信息区域高度（头像高度）
        return avatarSize
    }
    
    /// 绘制标题（只绘制标题，不绘制副标题）
    /// 支持多行显示，当标题文字较多时自动换行
    static func drawDestinationTitle(title: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        // 获取品牌颜色
        let brandColor = BrandColorManager.shared.currentBrandColor
        let brandUIColor = UIColor(brandColor)
        
        // 绘制主标题（参考图样式：大号字体）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        
        // 计算多行文本的实际高度和宽度
        let maxHeight: CGFloat = 200 // 最大高度限制
        let textRect = titleString.boundingRect(
            with: CGSize(width: width, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let actualHeight = ceil(textRect.height)
        let actualWidth = min(textRect.width, width) // 确保不超过可用宽度
        
        // 在文字下方绘制半透明品牌色高亮（只覆盖标题文字，不延伸到描述区域）
        // 高亮高度约为字体高度的 40%，位置在文字垂直中心
        let font = UIFont.systemFont(ofSize: 42, weight: .bold)
        let lineHeight = font.lineHeight
        let highlightHeight = lineHeight * 0.4
        let highlightOffsetY = lineHeight * 0.45 // 从文字中心偏上一点开始
        
        // 设置半透明品牌色（透明度约 0.25，更接近图片效果）
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        brandUIColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let highlightColor = UIColor(red: red, green: green, blue: blue, alpha: 0.25)
        context.setFillColor(highlightColor.cgColor)
        
        // 使用 Core Text 获取每一行的实际位置和宽度，确保高亮精确覆盖标题文字
        // 注意：Core Text 坐标系统从底部开始，需要转换为从顶部开始的坐标
        let framesetter = CTFramesetterCreateWithAttributedString(titleString)
        // 创建文本框架路径（Core Text 使用从底部开始的坐标系统，所以 y 从 0 开始）
        let textPath = CGPath(rect: CGRect(x: point.x, y: 0, width: width, height: actualHeight), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), textPath, nil)
        
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var lineOrigins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigins)
        
        // 为每一行绘制高亮，使用每行的实际宽度
        for (lineIndex, line) in lines.enumerated() {
            let lineOrigin = lineOrigins[lineIndex]
            // Core Text 坐标系统从底部开始，lineOrigin.y 是相对于框架底部（y=0）的距离
            // 转换为从顶部开始的坐标：actualHeight - lineOrigin.y - lineHeight = 从顶部到行顶部的距离
            let lineY = point.y + actualHeight - lineOrigin.y - lineHeight
            
            // 获取这一行的实际宽度
            let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            let actualLineWidth = CGFloat(lineWidth)
            
            // 计算高亮位置（只在标题文字范围内，不延伸到描述区域）
            let highlightY = lineY + highlightOffsetY
            let highlightWidth = min(actualLineWidth, width) + 24 // 稍微超出文字宽度（左右各12点），但不超过可用宽度
            let highlightX = point.x - 12 // 向左偏移12点，使高亮超出文字
            
            // 确保高亮完全在标题文字范围内，不会延伸到标题文字底部之外
            // 高亮的最底部应该在标题文字的最底部之前（留出一些余量，避免延伸到描述区域）
            let titleBottom = point.y + actualHeight
            let highlightBottom = highlightY + highlightHeight
            // 确保高亮不会超出标题文字区域，并且高亮底部至少距离标题底部有 highlightHeight 的余量
            if highlightY >= point.y && highlightBottom <= titleBottom - highlightHeight * 0.1 {
                // 绘制圆角矩形高亮
                let highlightRect = CGRect(
                    x: highlightX,
                    y: highlightY,
                    width: highlightWidth,
                    height: highlightHeight
                )
                let highlightPath = UIBezierPath(roundedRect: highlightRect, cornerRadius: 4)
                context.addPath(highlightPath.cgPath)
                context.fillPath()
            }
        }
        
        // 绘制标题文字（在高亮之上，支持多行）
        let drawRect = CGRect(
            x: point.x,
            y: point.y,
            width: width,
            height: actualHeight
        )
        titleString.draw(in: drawRect)
        
        // 返回标题高度
        return actualHeight
    }
    
    /// 在标题下面绘制笔记（不包含笔记标题）
    private static func drawDestinationNotesBelowTitle(_ notes: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        // 绘制笔记内容（参考图样式：更舒适的字体和行距）
        let notesAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .regular),
            .foregroundColor: UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 6 // 增加行距，提升可读性
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
        
        let notesDrawRect = CGRect(
            x: point.x,
            y: point.y,
            width: width,
            height: ceil(notesRect.height)
        )
        
        notesString.draw(in: notesDrawRect)
        
        return ceil(notesRect.height)
    }
    
    private static func drawDestinationDateSimple(for destination: TravelDestination, at point: CGPoint, width: CGFloat, context: CGContext) {
        // 格式化日期（只显示年月日和星期几，不显示时间）
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .full, timeStyle: .none)
        let dateString = dateFormatter.string(from: destination.visitDate)
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let dateStringAttr = NSAttributedString(string: dateString, attributes: dateAttributes)
        dateStringAttr.draw(at: point)
    }
    
    // 绘制主图（大图，参考图样式）
    private static func drawMainImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        // 绘制圆角矩形
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
    }
    
    // 计算智能网格的高度（根据照片数量自动调整布局，与布局简图说明一致）
    private static func calculateSmartGridHeight(photoCount: Int, width: CGFloat) -> CGFloat {
        guard photoCount > 0 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片之间的间距
        
        if photoCount == 1 {
            // 1张：单行占满，矩形（宽度100%，高度60%宽度，圆角12pt）
            let mainImageSize = width * 0.6 // 高度为60%宽度
            return mainImageSize
        } else if photoCount <= 3 {
            // 2-3张：单行显示，均分宽度
            let photoSize = (width - spacing * CGFloat(photoCount - 1)) / CGFloat(photoCount)
            return photoSize
        } else if photoCount == 4 {
            // 4张（5个地点时剩余4张）：第1行3张（3列网格），第2行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            return photoSize + spacing + photoSize // 第1行高度 + 间距 + 第2行高度（等于标准网格方块高度）
        } else if photoCount == 5 {
            // 5张（6个地点时剩余5张）：第1行3张（3列网格），第2行2张（单行均分，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            return photoSize + spacing + photoSize // 第1行高度 + 间距 + 第2行高度（等于标准网格方块高度）
        } else if photoCount == 6 {
            // 6张（7个地点时剩余6张）：第1行3张（3列网格），第2行3张（3列网格）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let rows = 2
            return CGFloat(rows) * photoSize + CGFloat(rows - 1) * spacing
        } else if photoCount == 7 {
            // 7张（8个地点时剩余7张）：第1行3张（3列网格），第2行3张（3列网格），第3行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            return CGFloat(2) * photoSize + CGFloat(2) * spacing + photoSize // 第1行高度 + 间距 + 第2行高度 + 间距 + 第3行高度（等于标准网格方块高度）
        } else {
            // 8张：第1行3张（3列网格），第2行3张（3列网格），第3行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            return CGFloat(2) * photoSize + CGFloat(2) * spacing + photoSize // 第1行高度 + 间距 + 第2行高度 + 间距 + 第3行高度（等于标准网格方块高度）
        }
    }
    
    // 绘制智能照片网格（根据数量自动调整布局，与布局简图说明一致）
    private static func drawSmartPhotoGrid(photos: [Data], at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let photoCount = photos.count
        guard photoCount > 0 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片之间的间距
        var currentY = point.y
        var photoIndex = 0
        
        if photoCount == 1 {
            // 1张：单行占满，矩形（宽度100%，高度60%宽度，圆角12pt）
            var result: CGFloat = 0
            autoreleasepool {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let mainImageSize = width * 0.6 // 高度为60%宽度
                    let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
                    drawMainImage(photoImage, in: mainImageRect, context: context)
                    result = mainImageSize
                }
            }
            return result
        } else if photoCount <= 3 {
            // 2-3张：单行显示，均分宽度
            let photoSize = (width - spacing * CGFloat(photoCount - 1)) / CGFloat(photoCount)
            var currentX = point.x
            
            for _ in 0..<photoCount {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            return photoSize
        } else if photoCount == 4 {
            // 4张（5个地点时剩余4张）：第1行3张（3列网格），第2行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：1张占满整行，矩形（高度=标准网格方块高度）
            autoreleasepool {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: photoSize)
                    drawMainImage(photoImage, in: mainImageRect, context: context)
                    currentY += photoSize
                }
            }
            
            return currentY - point.y
        } else if photoCount == 5 {
            // 5张（6个地点时剩余5张）：第1行3张（3列网格），第2行2张（单行均分，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：2张单行均分（高度=标准网格方块高度）
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            currentX = point.x
            
            for col in 0..<remainingPhotos {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: rowPhotoSize, height: photoSize) // 高度使用标准网格方块高度
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += rowPhotoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize
            
            return currentY - point.y
        } else if photoCount == 6 {
            // 6张（7个地点时剩余6张）：第1行3张（3列网格），第2行3张（3列网格）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize
            
            return currentY - point.y
        } else if photoCount == 7 {
            // 7张（8个地点时剩余7张）：第1行3张（3列网格），第2行3张（3列网格），第3行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第3行：1张占满整行，矩形（高度=标准网格方块高度）
            autoreleasepool {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: photoSize)
                    drawMainImage(photoImage, in: mainImageRect, context: context)
                    currentY += photoSize
                }
            }
            
            return currentY - point.y
        } else {
            // 8张及以上：第1行3张（3列网格），第2行3张（3列网格），第3行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                autoreleasepool {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第3行：1张占满整行，矩形（高度=标准网格方块高度）
            autoreleasepool {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: photoSize)
                    drawMainImage(photoImage, in: mainImageRect, context: context)
                    currentY += photoSize
                }
            }
            
            return currentY - point.y
        }
    }
    
    // 绘制网格中的单张照片（带圆角和智能裁剪）
    private static func drawGridPhoto(_ image: UIImage, in rect: CGRect, context: CGContext) {
        // 绘制圆角矩形（圆角12pt，与布局简图说明一致）
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
    }
    
    /// 绘制右侧封面图（无圆角，3:2比例，scaledToFill填充）
    private static func drawRightCoverImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        // 不使用圆角，直接使用矩形裁剪
        context.addRect(rect)
        context.clip()
        
        // 计算图片缩放和位置（scaledToFill 方式，居中裁剪）
        let imageSize = image.size
        let rectAspectRatio = rect.width / rect.height  // 应该是 2/3
        let imageAspectRatio = imageSize.width / imageSize.height
        
        var drawRect = rect
        if imageAspectRatio > rectAspectRatio {
            // 图片更宽，以高度为准，水平居中裁剪
            let scaledWidth = rect.height * imageAspectRatio
            drawRect = CGRect(
                x: rect.midX - scaledWidth/2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            // 图片更高，以宽度为准，垂直居中裁剪
            let scaledHeight = rect.width / imageAspectRatio
            drawRect = CGRect(
                x: rect.minX,
                y: rect.midY - scaledHeight/2,
                width: rect.width,
                height: scaledHeight
            )
        }
        
        image.draw(in: drawRect)
        context.restoreGState()
    }
    
    static func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
        // 获取品牌图标：优先使用 assets 中的 AppIconLine，其次回退到 AppIcon
        let appIcon: UIImage? = {
            if let lineIcon = UIImage(named: "AppIconLine") {
                return lineIcon
            }
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
            .font: UIFont.systemFont(ofSize: 12),
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
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width/2, y: point.y + 25))
    }
    
    /// 地点分享：极简海报同款底栏（左品牌两行 + 居中 AppIconLine + 右英文两行）
    /// 字号随画布宽度缩放（基准宽 390）
    static func drawDestinationShareCircleStyleBrandRow(
        topY: CGFloat,
        canvasWidth: CGFloat,
        horizontalPadding: CGFloat,
        context: CGContext
    ) -> CGFloat {
        let scale = max(canvasWidth / 390.0, 1.0)
        let fontSize = 6 * scale
        let lineGap = 2 * scale
        
        let brandMainAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor(white: 0.25, alpha: 1.0)
        ]
        let brandSubAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
        ]
        
        let leftLine1 = "MooFootprint"
        let leftLine2 = "Record Every Journey"
        let rightLine1 = "Record wonderful journeys"
        let rightLine2 = "Share beautiful moments"
        
        let brandMainLine1 = NSAttributedString(string: leftLine1, attributes: brandMainAttributes)
        let brandMainLine2 = NSAttributedString(string: leftLine2, attributes: brandSubAttributes)
        let brandSubLine1 = NSAttributedString(string: rightLine1, attributes: brandMainAttributes)
        let brandSubLine2 = NSAttributedString(string: rightLine2, attributes: brandSubAttributes)
        
        let brandMainLine1Size = brandMainLine1.size()
        let brandMainLine2Size = brandMainLine2.size()
        let brandSubLine1Size = brandSubLine1.size()
        let brandSubLine2Size = brandSubLine2.size()
        
        let leftBlockHeight = brandMainLine1Size.height + lineGap + brandMainLine2Size.height
        let rightBlockHeight = brandSubLine1Size.height + lineGap + brandSubLine2Size.height
        let rowVisualHeight = max(leftBlockHeight, rightBlockHeight)
        
        let iconSize: CGFloat = 14 * scale
        if let icon = UIImage(named: "AppIconLine") {
            let iconX = canvasWidth / 2.0 - iconSize / 2.0
            let iconY = topY + (rowVisualHeight - iconSize) / 2.0
            let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
            context.saveGState()
            let path = UIBezierPath(ovalIn: iconRect)
            context.addPath(path.cgPath)
            context.clip()
            icon.draw(in: iconRect)
            context.restoreGState()
        }
        
        let brandMainX = horizontalPadding
        brandMainLine1.draw(at: CGPoint(x: brandMainX, y: topY))
        brandMainLine2.draw(at: CGPoint(x: brandMainX, y: topY + brandMainLine1Size.height + lineGap))
        
        let rightEdgeX = canvasWidth - horizontalPadding
        brandSubLine1.draw(at: CGPoint(x: rightEdgeX - brandSubLine1Size.width, y: topY))
        brandSubLine2.draw(at: CGPoint(x: rightEdgeX - brandSubLine2Size.width, y: topY + brandSubLine1Size.height + lineGap))
        
        return rowVisualHeight
    }
}
