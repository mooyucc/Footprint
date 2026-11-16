//
//  DestinationShareLayoutGenerators.swift
//  Footprint
//
//  地点社媒分享海报生成（固定画布比例）
//

import SwiftUI
import UIKit

enum DestinationSharePhotoSource {
    /// 地点可用照片数据（优先多图列表）
    static func photoDatas(from destination: TravelDestination) -> [Data] {
        if !destination.photoDatas.isEmpty {
            return destination.photoDatas
        }
        if let data = destination.photoData {
            return [data]
        }
        return []
    }
    
    static func image(from destination: TravelDestination, at index: Int) -> UIImage? {
        let datas = photoDatas(from: destination)
        guard !datas.isEmpty else { return nil }
        let clamped = min(max(0, index), datas.count - 1)
        return UIImage(data: datas[clamped])
    }
}

// MARK: - 大图打卡（默认，最适合发帖）

struct PhotoPosterDestinationLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(
        from destination: TravelDestination,
        canvasSize: CGSize,
        scale: CGFloat,
        coverPhotoIndex: Int,
        overlayCaption: String?
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: canvasSize)
            
            let photo = DestinationSharePhotoSource.image(from: destination, at: coverPhotoIndex)
            if let photo {
                Self.drawAspectFill(photo, in: bounds, context: cg)
            } else {
                Self.drawPlaceholderBackground(in: bounds, context: cg)
            }
            
            // 底部渐变，保证白字可读
            let gradientHeight = canvasSize.height * 0.46
            let gradientRect = CGRect(
                x: 0,
                y: canvasSize.height - gradientHeight,
                width: canvasSize.width,
                height: gradientHeight
            )
            let colors = [
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0.55).cgColor,
                UIColor.black.withAlphaComponent(0.78).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.45, 1]
            ) {
                cg.saveGState()
                cg.addRect(gradientRect)
                cg.clip()
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: gradientRect.minY),
                    end: CGPoint(x: 0, y: gradientRect.maxY),
                    options: []
                )
                cg.restoreGState()
            }
            
            let padding = canvasSize.width * 0.07
            let contentWidth = canvasSize.width - padding * 2
            var cursorY = canvasSize.height - padding
            
            // 日期（MooFootprint 注脚仅由免费版 applyingWatermarkIfNeeded 统一叠加）
            let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium, timeStyle: .none)
            let dateText = dateFormatter.string(from: destination.visitDate)
            let dateFont = UIFont.systemFont(ofSize: canvasSize.width * 0.032, weight: .medium)
            let dateAttr = NSAttributedString(
                string: dateText,
                attributes: [
                    .font: dateFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.88)
                ]
            )
            let dateSize = dateAttr.size()
            cursorY -= dateSize.height
            dateAttr.draw(at: CGPoint(x: padding, y: cursorY))
            cursorY -= canvasSize.height * 0.018
            
            // 地点副标题（省 / 国家）
            let locationLine = Self.locationSubtitle(for: destination)
            if !locationLine.isEmpty {
                let locFont = UIFont.systemFont(ofSize: canvasSize.width * 0.034, weight: .regular)
                let locAttr = NSAttributedString(
                    string: locationLine,
                    attributes: [
                        .font: locFont,
                        .foregroundColor: UIColor.white.withAlphaComponent(0.9)
                    ]
                )
                let locSize = locAttr.boundingRect(
                    with: CGSize(width: contentWidth, height: locFont.lineHeight * 2),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let locHeight = ceil(locSize.height)
                cursorY -= locHeight
                locAttr.draw(in: CGRect(x: padding, y: cursorY, width: contentWidth, height: locHeight))
                cursorY -= canvasSize.height * 0.014
            }
            
            // 主标题：可编辑图上短句，空则回退地点名
            let titleText = DestinationGalleryCardStyle.primaryCaption(
                destination: destination,
                overlayCaption: overlayCaption
            )
            let titleFontSize = canvasSize.width * 0.078
            let titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .bold)
            let titleStyle = NSMutableParagraphStyle()
            titleStyle.lineBreakMode = .byWordWrapping
            titleStyle.lineSpacing = 2
            let titleAttr = NSAttributedString(
                string: titleText,
                attributes: [
                    .font: titleFont,
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: titleStyle,
                    .kern: -0.5
                ]
            )
            let maxTitleHeight = titleFont.lineHeight * 3
            let titleRect = titleAttr.boundingRect(
                with: CGSize(width: contentWidth, height: maxTitleHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let titleHeight = min(ceil(titleRect.height), maxTitleHeight)
            cursorY -= titleHeight
            cg.saveGState()
            cg.addRect(CGRect(x: padding, y: cursorY, width: contentWidth, height: titleHeight))
            cg.clip()
            titleAttr.draw(in: CGRect(x: padding, y: cursorY, width: contentWidth, height: titleHeight))
            cg.restoreGState()
        }
    }
    
    private static func locationSubtitle(for destination: TravelDestination) -> String {
        let parts = [destination.province, destination.country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }
    
    static func drawAspectFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.addRect(rect)
        context.clip()
        
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            context.restoreGState()
            return
        }
        
        let targetAspect = rect.width / rect.height
        let imageAspect = imageSize.width / imageSize.height
        var drawRect = rect
        if imageAspect > targetAspect {
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(
                x: rect.midX - scaledWidth / 2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            let scaledHeight = rect.width / imageAspect
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
    
    private static func drawPlaceholderBackground(in rect: CGRect, context: CGContext) {
        let colors = [
            UIColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1).cgColor,
            UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1).cgColor
        ] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: []
            )
        } else {
            context.setFillColor(UIColor.darkGray.cgColor)
            context.fill(rect)
        }
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: rect.width * 0.12, weight: .light)
        if let pin = UIImage(systemName: "mappin.and.ellipse", withConfiguration: symbolConfig)?
            .withTintColor(UIColor.white.withAlphaComponent(0.35), renderingMode: .alwaysOriginal) {
            let size = pin.size
            let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2 - rect.height * 0.08)
            pin.draw(at: origin)
        }
    }
}

// MARK: - 画廊卡文案与绘制辅助

enum DestinationGalleryCardStyle {
    static let creamBackground = UIColor(red: 0.965, green: 0.957, blue: 0.945, alpha: 1)
    static let primaryText = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
    static let secondaryText = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1)
    static let photoBorder = UIColor(white: 0.82, alpha: 1)
    
    static func serifFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
    
    static func monoFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .regular)
        if let descriptor = base.fontDescriptor.withDesign(.monospaced) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
    
    /// 图上主文案：优先用户编辑短句，其次默认备注/地点名（控制在一句以内）
    static func primaryCaption(destination: TravelDestination, overlayCaption: String?) -> String {
        if let overlay = overlayCaption?.trimmingCharacters(in: .whitespacesAndNewlines), !overlay.isEmpty {
            return String(overlay.prefix(40))
        }
        return ShareImageUtilities.destinationOverlayCaption(for: destination, maxLength: 40)
    }
    
    static func locationLine(for destination: TravelDestination) -> String {
        let parts = [destination.province, destination.country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }
        let type = destination.type.trimmingCharacters(in: .whitespacesAndNewlines)
        return type
    }
    
    static func dateLine(for destination: TravelDestination) -> String {
        LanguageManager.shared.localizedDateFormatter(dateStyle: .medium, timeStyle: .none)
            .string(from: destination.visitDate)
    }
    
    static func drawFramedPhoto(_ image: UIImage?, in rect: CGRect, context: CGContext) {
        context.setFillColor(UIColor(white: 0.92, alpha: 1).cgColor)
        context.fill(rect)
        if let image {
            PhotoPosterDestinationLayoutGenerator.drawAspectFill(image, in: rect, context: context)
        }
        context.setStrokeColor(photoBorder.cgColor)
        context.setLineWidth(max(1, rect.width * 0.003))
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
    }
}

// MARK: - 侧栏画廊（左竖图 + 右文案）

struct GallerySideDestinationLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(
        from destination: TravelDestination,
        canvasSize: CGSize,
        scale: CGFloat,
        coverPhotoIndex: Int,
        overlayCaption: String?
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        
        let w = canvasSize.width
        let h = canvasSize.height
        // 参考图：照片距边缘约 2.5%～3%；内嵌竖图固定 3:4
        let margin = min(w, h) * 0.028
        let gap = w * 0.048
        let minTextColumn = w * 0.26
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(DestinationGalleryCardStyle.creamBackground.cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))
            
            // 左侧 3:4 竖图：略矮于可用高度；过宽则缩回以保留右侧文案区
            let availableHeight = (h - margin * 2) * 0.88
            var photoHeight = availableHeight
            var photoWidth = photoHeight * 3.0 / 4.0
            let maxPhotoWidth = max(w * 0.48, w - margin * 2 - gap - minTextColumn)
            if photoWidth > maxPhotoWidth {
                photoWidth = maxPhotoWidth
                photoHeight = photoWidth * 4.0 / 3.0
            }
            // 照片贴顶（上/左边距一致），下方留白
            let photoY = margin
            let photoRect = CGRect(x: margin, y: photoY, width: photoWidth, height: photoHeight)
            let cover = DestinationSharePhotoSource.image(from: destination, at: coverPhotoIndex)
            DestinationGalleryCardStyle.drawFramedPhoto(cover, in: photoRect, context: cg)
            
            let textX = photoRect.maxX + gap
            let textWidth = max(40, w - textX - margin)
            
            let caption = DestinationGalleryCardStyle.primaryCaption(
                destination: destination,
                overlayCaption: overlayCaption
            )
            let captionFont = DestinationGalleryCardStyle.serifFont(size: w * 0.036)
            let captionStyle = NSMutableParagraphStyle()
            captionStyle.lineSpacing = 5
            captionStyle.lineBreakMode = .byWordWrapping
            let captionAttr = NSAttributedString(string: caption, attributes: [
                .font: captionFont,
                .foregroundColor: DestinationGalleryCardStyle.primaryText,
                .paragraphStyle: captionStyle
            ])
            let maxCaptionHeight = captionFont.lineHeight * 4
            let captionBounds = captionAttr.boundingRect(
                with: CGSize(width: textWidth, height: maxCaptionHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let captionHeight = min(ceil(captionBounds.height), maxCaptionHeight)
            
            // 主文约在照片垂直中部（文案位置不动）
            let captionY = max(
                photoRect.minY + photoHeight * 0.28,
                photoRect.midY - captionHeight * 0.55
            )
            captionAttr.draw(in: CGRect(x: textX, y: captionY, width: textWidth, height: captionHeight))
            
            // 地点 + 日期贴画布底边（右下）
            let metaFont = DestinationGalleryCardStyle.monoFont(size: w * 0.024)
            let location = DestinationGalleryCardStyle.locationLine(for: destination)
            let dateText = DestinationGalleryCardStyle.dateLine(for: destination)
            let metaLineGap = w * 0.014
            
            let locAttr: NSAttributedString? = location.isEmpty ? nil : NSAttributedString(
                string: location,
                attributes: [
                    .font: metaFont,
                    .foregroundColor: DestinationGalleryCardStyle.secondaryText
                ]
            )
            let dateAttr = NSAttributedString(
                string: dateText,
                attributes: [
                    .font: metaFont,
                    .foregroundColor: DestinationGalleryCardStyle.secondaryText
                ]
            )
            
            let locHeight = locAttr.map {
                ceil($0.boundingRect(
                    with: CGSize(width: textWidth, height: metaFont.lineHeight * 2),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                ).height)
            } ?? 0
            let dateHeight = dateAttr.size().height
            let metaBlockHeight = (locAttr == nil ? 0 : locHeight + metaLineGap) + dateHeight
            var metaY = h - margin - metaBlockHeight
            
            // 避免与主文重叠
            let captionBottom = captionY + captionHeight + w * 0.03
            if metaY < captionBottom {
                metaY = captionBottom
            }
            
            if let locAttr {
                locAttr.draw(in: CGRect(x: textX, y: metaY, width: textWidth, height: locHeight))
                metaY += locHeight + metaLineGap
            }
            dateAttr.draw(at: CGPoint(x: textX, y: metaY))
        }
    }
}

// MARK: - 上下画廊（上横图 + 下文案）

struct GalleryStackDestinationLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(
        from destination: TravelDestination,
        canvasSize: CGSize,
        scale: CGFloat,
        coverPhotoIndex: Int,
        overlayCaption: String?
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * 0.028
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(DestinationGalleryCardStyle.creamBackground.cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))
            
            let photoWidth = w - margin * 2
            // 横图更高一些，贴近参考图上半占比
            let photoHeight = min(h * 0.52, photoWidth * 0.68)
            let photoRect = CGRect(x: margin, y: margin, width: photoWidth, height: photoHeight)
            let cover = DestinationSharePhotoSource.image(from: destination, at: coverPhotoIndex)
            DestinationGalleryCardStyle.drawFramedPhoto(cover, in: photoRect, context: cg)
            
            // 图下文距适中；底部允许留白
            var textY = photoRect.maxY + w * 0.04
            let textWidth = photoWidth
            
            let caption = DestinationGalleryCardStyle.primaryCaption(
                destination: destination,
                overlayCaption: overlayCaption
            )
            let captionFont = DestinationGalleryCardStyle.serifFont(size: w * 0.038)
            let captionStyle = NSMutableParagraphStyle()
            captionStyle.lineSpacing = 6
            captionStyle.lineBreakMode = .byWordWrapping
            let captionAttr = NSAttributedString(string: caption, attributes: [
                .font: captionFont,
                .foregroundColor: DestinationGalleryCardStyle.primaryText,
                .paragraphStyle: captionStyle
            ])
            let maxCaptionHeight = captionFont.lineHeight * 4
            let captionBounds = captionAttr.boundingRect(
                with: CGSize(width: textWidth, height: maxCaptionHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let captionHeight = min(ceil(captionBounds.height), maxCaptionHeight)
            captionAttr.draw(in: CGRect(x: margin, y: textY, width: textWidth, height: captionHeight))
            textY += captionHeight + w * 0.028
            
            let metaFont = DestinationGalleryCardStyle.monoFont(size: w * 0.024)
            let location = DestinationGalleryCardStyle.locationLine(for: destination)
            if !location.isEmpty {
                let locAttr = NSAttributedString(string: location, attributes: [
                    .font: metaFont,
                    .foregroundColor: DestinationGalleryCardStyle.secondaryText
                ])
                locAttr.draw(at: CGPoint(x: margin, y: textY))
                textY += locAttr.size().height + w * 0.014
            }
            
            let dateAttr = NSAttributedString(
                string: DestinationGalleryCardStyle.dateLine(for: destination),
                attributes: [
                    .font: metaFont,
                    .foregroundColor: DestinationGalleryCardStyle.secondaryText
                ]
            )
            dateAttr.draw(at: CGPoint(x: margin, y: textY))
        }
    }
}
