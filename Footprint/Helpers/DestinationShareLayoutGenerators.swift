//
//  DestinationShareLayoutGenerators.swift
//  Footprint
//
//  从 TripImageGenerator.swift 提取（编译拆分）
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation
import MapKit

struct ClassicDestinationLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(from destination: TravelDestination) -> UIImage? {
        return TripImageGenerator.generateDestinationImageClassic(from: destination)
    }
}

/// 现代统计风格地点分享版面（原野哉感：大留白 + 强轴线）

struct ModernStatsDestinationLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(from destination: TravelDestination) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 28
        let topPadding: CGFloat = 44
        let bottomPadding: CGFloat = 40
        let contentWidth = screenWidth - horizontalPadding * 2
        
        // 照片（主图优先用第一张）
        let allPhotos: [Data] = {
            if !destination.photoDatas.isEmpty {
                return destination.photoDatas
            } else if let photoData = destination.photoData {
                return [photoData]
            } else {
                return []
            }
        }()
        let mainImage = allPhotos.first.flatMap { UIImage(data: $0) }
        let hasPhoto = mainImage != nil
        
        // 正文：完整备注（仅极端长文截断，与极简海报一致）
        let bodyNotesText: String = {
            if destination.notes.isEmpty { return "" }
            let maxChars = 4000
            if destination.notes.count <= maxChars { return destination.notes }
            return String(destination.notes.prefix(maxChars))
        }()
        
        // 计算高度：标题 + 副标题 + 分隔线 + 正文 + 统计行 + 照片 + 品牌签名
        var contentHeight: CGFloat = 0
        contentHeight += topPadding
        
        // 标题（目的地名称，极简海报风）
        let titleWidth = contentWidth * 0.8
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .black),
            .foregroundColor: UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0),
            .kern: 1.5,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let titleString = NSAttributedString(string: destination.name, attributes: titleAttributes)
        let titleRect = titleString.boundingRect(
            with: CGSize(width: titleWidth, height: 160),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleHeight = ceil(titleRect.height)
        contentHeight += titleHeight + 10
        
        // 副标题（备注首句或城市信息）
        var subtitleHeight: CGFloat = 0
        let subtitleText: String = {
            if !destination.notes.isEmpty {
                // 取备注第一句（按句号/换行切分），过长再截断
                let separators: CharacterSet = ["。", ".", "\n"].reduce(into: CharacterSet()) { set, ch in
                    set.insert(charactersIn: String(ch))
                }
                let components = destination.notes.components(separatedBy: separators).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                let firstSentence = components.first ?? destination.notes
                let trimmed = firstSentence.trimmingCharacters(in: .whitespaces)
                return String(trimmed.prefix(40))
            } else if let trip = destination.trip {
                return trip.name
            } else {
                return ""
            }
        }()
        
        if !subtitleText.isEmpty {
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0),
                .kern: 1.0,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            let subtitleString = NSAttributedString(string: subtitleText, attributes: subtitleAttributes)
            let subtitleRect = subtitleString.boundingRect(
                with: CGSize(width: contentWidth, height: 80),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            subtitleHeight = ceil(subtitleRect.height)
            contentHeight += subtitleHeight + 18
        } else {
            contentHeight += 16
        }
        
        // 分隔线
        let dividerHeight: CGFloat = 1
        contentHeight += dividerHeight + 18
        
        // 正文与下方统计行之间的留白（略大，让整页到图片的视觉空隙更舒展）
        let bodyBottomSpacing: CGFloat = 48
        
        // 正文（宽度与 content 同宽；高度按全文测量，避免 120 字与限高裁切）
        var bodyHeight: CGFloat = 0
        if !bodyNotesText.isEmpty {
            let notesAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 5
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            let notesString = NSAttributedString(string: bodyNotesText, attributes: notesAttributes)
            let notesRect = notesString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            bodyHeight = ceil(notesRect.height)
            contentHeight += bodyHeight + bodyBottomSpacing
        }
        
        // 统计行（极简）
        let statsHeight: CGFloat = 16
        contentHeight += statsHeight + 32
        
        // 照片区域：与 content 同宽
        let photoWidth = contentWidth
        let photoHeight: CGFloat = hasPhoto ? photoWidth * 0.6 : 0
        contentHeight += photoHeight
        if hasPhoto {
            contentHeight += 44
        }
        
        // 品牌签名区域（与极简海报同款底栏，高度与 circle brandRow 一致）
        let signatureHeight: CGFloat = 36
        contentHeight += signatureHeight + 24
        
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景（纯白）
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY: CGFloat = topPadding
            
            // 标题（使用 fixed width 矩形绘制以保证自动换行）
            let titleDrawRect = CGRect(
                x: horizontalPadding,
                y: currentY,
                width: titleWidth,
                height: titleHeight
            )
            titleString.draw(in: titleDrawRect)
            currentY += titleHeight + 10
            
            // 副标题
            if !subtitleText.isEmpty {
                let subtitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                    .foregroundColor: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0),
                    .kern: 1.0,
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.lineBreakMode = .byWordWrapping
                        return style
                    }()
                ]
                let subtitleString = NSAttributedString(string: subtitleText, attributes: subtitleAttributes)
                let subtitleRect = subtitleString.boundingRect(
                    with: CGSize(width: contentWidth, height: 80),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                subtitleString.draw(
                    in: CGRect(
                        x: horizontalPadding,
                        y: currentY,
                        width: contentWidth,
                        height: ceil(subtitleRect.height)
                    )
                )
                currentY += ceil(subtitleRect.height) + 18
            } else {
                currentY += 16
            }
            
            // 分隔线
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: horizontalPadding, y: currentY))
            dividerPath.addLine(to: CGPoint(x: horizontalPadding + 64, y: currentY))
            cgContext.setStrokeColor(UIColor(white: 0.8, alpha: 1.0).cgColor)
            cgContext.setLineWidth(1)
            cgContext.addPath(dividerPath.cgPath)
            cgContext.strokePath()
            currentY += dividerHeight + 18
            
            // 正文（完整高度绘制）
            if !bodyNotesText.isEmpty {
                let notesAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0),
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.lineSpacing = 5
                        style.lineBreakMode = .byWordWrapping
                        return style
                    }()
                ]
                let notesString = NSAttributedString(string: bodyNotesText, attributes: notesAttributes)
                let notesRect = notesString.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let notesDrawHeight = ceil(notesRect.height)
                notesString.draw(
                    in: CGRect(
                        x: horizontalPadding,
                        y: currentY,
                        width: contentWidth,
                        height: notesDrawHeight
                    )
                )
                currentY += notesDrawHeight + bodyBottomSpacing
            }
            
            // 统计行（左文案 + 右数字）
            let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium, timeStyle: .none)
            let fullDate = dateFormatter.string(from: destination.visitDate)
            let calendar = Calendar.current
            let year = calendar.component(.year, from: destination.visitDate)
            
            // 与正文同字号、字重与色系
            let statsLeftAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0),
                .kern: 2.0,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 5
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            // 日期与正文同字号与同色系
            let statsRightAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 5
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            
            let statsLeftText = "#\(year) VISIT".uppercased()
            let statsRightText = fullDate
            
            let statsLeft = NSAttributedString(string: statsLeftText, attributes: statsLeftAttributes)
            let statsRight = NSAttributedString(string: statsRightText, attributes: statsRightAttributes)
            
            let leftSize = statsLeft.size()
            let rightSize = statsRight.size()
            
            statsLeft.draw(at: CGPoint(x: horizontalPadding, y: currentY))
            statsRight.draw(
                at: CGPoint(
                    x: screenWidth - horizontalPadding - rightSize.width,
                    y: currentY
                )
            )
            currentY += max(leftSize.height, rightSize.height) + 32
            
            // 照片（无圆角，保留直角矩形；与 content 同宽）
            if let mainImage = mainImage, hasPhoto {
                let photoWidth = contentWidth
                let photoHeight = photoWidth * 0.6
                let rect = CGRect(
                    x: horizontalPadding,
                    y: currentY,
                    width: photoWidth,
                    height: photoHeight
                )
                // 直接绘制，无裁剪圆角
                mainImage.draw(in: rect)
                currentY += photoHeight + 44
            }
            
            // 品牌签名（与极简海报同款）
            TripImageGenerator.drawDestinationShareCircleStyleBrandRow(
                topY: currentY,
                canvasWidth: screenWidth,
                horizontalPadding: horizontalPadding,
                context: cgContext
            )
        }
    }
    
    private func drawRoundedImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 18)
        context.addPath(path.cgPath)
        context.clip()
        
        let imageSize = image.size
        let rectAspect = rect.width / rect.height
        let imageAspect = imageSize.width / imageSize.height
        
        var drawRect = rect
        if imageAspect > rectAspect {
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
}

/// 极简海报版面（圆形构图，参考原型图 1 / 效果图 2）

struct CirclePosterDestinationLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(from destination: TravelDestination) -> UIImage? {
        // 目标画布宽度上限 1200pt，高宽比约 1200x1800，用于控制最小高度
        let deviceWidth = UIScreen.main.bounds.width
        let targetWidth: CGFloat = min(deviceWidth, 1200)
        let targetHeight: CGFloat = targetWidth * (1800.0 / 1200.0)
        
        let screenWidth = targetWidth
        let horizontalPadding: CGFloat = 32
        let topPadding: CGFloat = 48
        let bottomPadding: CGFloat = 16
        let circleToPhotoSpacing: CGFloat = 28
        let photoToSignatureSpacing: CGFloat = 20
        let contentWidth = screenWidth - horizontalPadding * 2
        let centerX = screenWidth / 2.0
        let titleWidth = contentWidth * 0.55
        let bodyWidth = contentWidth * 0.35
        // 与左右正文同一内容宽：左 = horizontalPadding，右 = screenWidth - horizontalPadding
        let photoWidth = contentWidth
        let photoHeight = photoWidth * 0.42
        
        // 照片
        let allPhotos: [Data] = {
            if !destination.photoDatas.isEmpty {
                return destination.photoDatas
            } else if let data = destination.photoData {
                return [data]
            } else {
                return []
            }
        }()
        let mainImage = allPhotos.first.flatMap { UIImage(data: $0) }
        
        // 标题：ASCII 「.」后强制换行，便于控制断行；末尾孤立换行去掉避免多算一行
        let titleDisplayText = destination.name
            .replacingOccurrences(of: ".", with: ".\n")
            .trimmingCharacters(in: .newlines)
        
        // 标题：严格最多三行；超出则逐级缩小字号，直至满足或降至最小字号（再裁剪）
        let titleMaxLines = 3
        let titleStartFontSize: CGFloat = 44
        let titleMinFontSize: CGFloat = 18
        var titleString = NSAttributedString(string: titleDisplayText)
        var titleHeight: CGFloat = 0
        var fittedWithinMaxLines = false
        var trySize = titleStartFontSize
        while trySize >= titleMinFontSize {
            let tryFont = UIFont.systemFont(ofSize: trySize, weight: .black)
            let maxAllowedHeight = ceil(tryFont.lineHeight * CGFloat(titleMaxLines))
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: tryFont,
                .foregroundColor: UIColor.black,
                .kern: 1.5,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            let str = NSAttributedString(string: titleDisplayText, attributes: titleAttributes)
            let rect = str.boundingRect(
                with: CGSize(width: titleWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let h = ceil(rect.height)
            if h <= maxAllowedHeight {
                titleString = str
                titleHeight = h
                fittedWithinMaxLines = true
                break
            }
            trySize -= 2
        }
        if !fittedWithinMaxLines {
            let minFont = UIFont.systemFont(ofSize: titleMinFontSize, weight: .black)
            let maxAllowedHeight = ceil(minFont.lineHeight * CGFloat(titleMaxLines))
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: minFont,
                .foregroundColor: UIColor.black,
                .kern: 1.5,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            titleString = NSAttributedString(string: titleDisplayText, attributes: titleAttributes)
            let rect = titleString.boundingRect(
                with: CGSize(width: titleWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            titleHeight = min(ceil(rect.height), maxAllowedHeight)
        }
        
        // 正文（右上；完整展示备注，仅对极端长文做上限避免性能问题）
        let bodyText: String = {
            if destination.notes.isEmpty { return "" }
            let maxChars = 4000
            if destination.notes.count <= maxChars {
                return destination.notes
            }
            return String(destination.notes.prefix(maxChars))
        }()
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .regular),
            .foregroundColor: UIColor(white: 0.2, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 3
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let bodyString = NSAttributedString(string: bodyText, attributes: bodyAttributes)
        let bodyRect = bodyString.boundingRect(
            with: CGSize(width: bodyWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let bodyHeight = ceil(bodyRect.height)
        
        // 日期
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium, timeStyle: .none)
        let dateStringValue = dateFormatter.string(from: destination.visitDate)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7, weight: .regular),
            .foregroundColor: UIColor(white: 0.2, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 3
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let dateString = NSAttributedString(string: dateStringValue, attributes: dateAttributes)
        let dateSize = dateString.size()
        
        let circleDiameter = screenWidth * 0.7
        let brandRowHeight: CGFloat = 36
        // 标题底 + 正文/日期实际占用高度可能超过圆形下沿，照片起始下移避免压住正文
        let titleBottomYLayout = topPadding + 8 + titleHeight
        let rightTopYLayout = max(topPadding + 24, titleBottomYLayout - bodyHeight)
        let notesBlockBottom = rightTopYLayout + 10 + bodyHeight + 24 + dateSize.height
        let circleBottomLayout = topPadding + circleDiameter
        let headerVisualBottom = max(circleBottomLayout, notesBlockBottom + 8)
        let photoStartY = headerVisualBottom + circleToPhotoSpacing
        
        let contentHeight = photoStartY + photoHeight + photoToSignatureSpacing + brandRowHeight + bottomPadding
        
        // 保证整体画布至少达到目标高宽比
        let imageHeight = max(contentHeight, targetHeight)
        let imageSize = CGSize(width: screenWidth, height: imageHeight)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景（纯白）
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY = topPadding
            
            // 浅灰圆形底纹（X 略向左偏移，Y 保持原有比例，但整体更小）
            let circleCenter = CGPoint(x: centerX - circleDiameter * 0.55, y: currentY + circleDiameter / 2)
            let circleRect = CGRect(
                x: circleCenter.x - circleDiameter / 2,
                y: circleCenter.y - circleDiameter / 2,
                width: circleDiameter,
                height: circleDiameter
            )
            cgContext.setFillColor(UIColor(white: 0.93, alpha: 1.0).cgColor)
            cgContext.fillEllipse(in: circleRect)
            
            // 标题（在左上，覆盖到圆形之上；高度不超过三行，超出部分裁剪）
            let titleDrawRect = CGRect(
                x: horizontalPadding,
                y: currentY + 8,
                width: titleWidth,
                height: titleHeight
            )
            cgContext.saveGState()
            cgContext.addRect(titleDrawRect)
            cgContext.clip()
            titleString.draw(in: titleDrawRect)
            cgContext.restoreGState()
            
            // 右上正文：整块右缘与 content 右缘对齐（与照片同宽区域的右边界一致）
            let rightOriginX = horizontalPadding + contentWidth - bodyWidth
            // 与标题“靠下对齐”：与布局阶段 rightTopYLayout 一致
            let rightTopY = rightTopYLayout

            // 正文（完整高度绘制，不再用 120 限高截断）
            if !bodyText.isEmpty {
                let bodyDrawRect = CGRect(
                    x: rightOriginX,
                    y: rightTopY + 10,
                    width: bodyWidth,
                    height: bodyHeight
                )
                bodyString.draw(in: bodyDrawRect)
            }
            
            // 日期（正文下方右对齐）
            let dateX = rightOriginX + bodyWidth - dateSize.width
            let dateY = rightTopY + bodyHeight + 24
            dateString.draw(at: CGPoint(x: dateX, y: dateY))
            
            // 照片起始：保证在正文+日期之下
            currentY = photoStartY
            
            // 照片（保持原比例，裁切填充；左右与标题/正文内容区对齐）
            if let mainImage = mainImage {
                let photoRect = CGRect(
                    x: horizontalPadding,
                    y: currentY,
                    width: photoWidth,
                    height: photoHeight
                )
                cgContext.saveGState()
                cgContext.addRect(photoRect)
                cgContext.clip()
                
                let imageSize = mainImage.size
                let targetAspect = photoRect.width / photoRect.height
                let imageAspect = imageSize.width / imageSize.height
                
                var drawRect = photoRect
                if imageAspect > targetAspect {
                    // 图片更宽，按高度裁切
                    let scaledWidth = photoRect.height * imageAspect
                    drawRect = CGRect(
                        x: photoRect.midX - scaledWidth / 2.0,
                        y: photoRect.minY,
                        width: scaledWidth,
                        height: photoRect.height
                    )
                } else {
                    // 图片更高，按宽度裁切
                    let scaledHeight = photoRect.width / imageAspect
                    drawRect = CGRect(
                        x: photoRect.minX,
                        y: photoRect.midY - scaledHeight / 2.0,
                        width: photoRect.width,
                        height: scaledHeight
                    )
                }
                
                mainImage.draw(in: drawRect)
                cgContext.restoreGState()
            }
            
            // 签名尽可能靠画布底部：内容流位置与「贴底」位置取较大者（满足最小高度时多出的空白在照片与签名之间）
            let flowSignatureY = photoStartY + photoHeight + photoToSignatureSpacing
            let pinnedSignatureY = imageSize.height - bottomPadding - brandRowHeight
            currentY = max(flowSignatureY, pinnedSignatureY)
            
            TripImageGenerator.drawDestinationShareCircleStyleBrandRow(
                topY: currentY,
                canvasWidth: screenWidth,
                horizontalPadding: horizontalPadding,
                context: cgContext
            )
        }
    }
}
