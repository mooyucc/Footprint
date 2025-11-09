//
//  TripImageGenerator.swift
//  Footprint
//
//  Created on 2025/10/20.
//

import SwiftUI
import UIKit

// MARK: - 分享相关
struct TripShareItem: Identifiable {
    let id = UUID()
    let text: String
    let image: UIImage?
    let url: URL?
    
    init(text: String, image: UIImage? = nil, url: URL? = nil) {
        self.text = text
        self.image = image
        self.url = url
    }
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TripImageGenerator {
    static func generateTripImage(from trip: TravelTrip) -> UIImage? {
        // 获取屏幕宽度
        let screenWidth = UIScreen.main.bounds.width
        
        // 计算内容高度
        let contentHeight = calculateContentHeight(for: trip, width: screenWidth)
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        // 创建图片渲染器（禁用Alpha通道以减少文件体积）
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 设置背景色
            cgContext.setFillColor(UIColor.systemBackground.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY: CGFloat = 0
            
            // 绘制封面图片区域
            if let photoData = trip.coverPhotoData,
               let coverImage = UIImage(data: photoData) {
                // 绘制封面图片，保持宽高比，不变形
                let coverRect = CGRect(x: 0, y: 0, width: screenWidth, height: 250)
                let imageAspectRatio = coverImage.size.width / coverImage.size.height
                let rectAspectRatio = coverRect.width / coverRect.height
                
                var drawRect = coverRect
                if imageAspectRatio > rectAspectRatio {
                    // 图片更宽，以高度为准
                    let scaledWidth = coverRect.height * imageAspectRatio
                    drawRect = CGRect(x: (coverRect.width - scaledWidth) / 2, y: 0, width: scaledWidth, height: coverRect.height)
                } else {
                    // 图片更高，以宽度为准
                    let scaledHeight = coverRect.width / imageAspectRatio
                    drawRect = CGRect(x: 0, y: (coverRect.height - scaledHeight) / 2, width: coverRect.width, height: scaledHeight)
                }
                
                coverImage.draw(in: drawRect)
            } else {
                // 绘制默认封面
                let coverRect = CGRect(x: 0, y: 0, width: screenWidth, height: 250)
                drawDefaultCover(for: trip, in: cgContext, rect: coverRect)
            }
            
            currentY = 250
            
            // 绘制内容区域背景
            let contentRect = CGRect(x: 0, y: currentY, width: screenWidth, height: imageSize.height - currentY)
            cgContext.setFillColor(UIColor.systemBackground.cgColor)
            cgContext.fill(contentRect)
            
            // 绘制内容
            currentY += 20
            
            // 绘制标题
            drawTitle(trip.name, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += 40
            
            // 绘制描述
            if !trip.desc.isEmpty {
                drawDescription(trip.desc, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                currentY += 32
            }
            
            // 绘制时间信息卡片
            currentY += 20
            let timeCardHeight = drawTimeCard(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += timeCardHeight + 20
            
            // 绘制行程路线
            let routeCardHeight = drawRouteCard(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += routeCardHeight + 20
            
            // 绘制底部签名
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }
    
    private static func calculateContentHeight(for trip: TravelTrip, width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        
        // 封面图片区域
        height += 250 // 封面图片高度
        
        // 内容区域padding
        height += 20
        
        // 标题区域
        height += 28 + 12 // title + spacing
        if !trip.desc.isEmpty {
            height += 16 + 12 // desc + spacing
        }
        
        // 时间信息卡片
        height += 20 + 100 + 20 // padding + card + margin (增加卡片高度)
        
        // 行程路线卡片
        let destinationCount = trip.destinations?.count ?? 0
        let routeHeight = destinationCount > 0 ? CGFloat(destinationCount) * 60 + 90 : 136 // header + destinations or empty state (增加行间距和底部padding)
        height += routeHeight + 20
        
        // 底部签名
        height += 20 + 50 + 20 // padding + signature + padding (增加签名区域高度)
        
        return height
    }
    
    private static func drawDefaultCover(for trip: TravelTrip, in context: CGContext, rect: CGRect) {
        // 绘制渐变背景
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor] as CFArray, locations: nil)!
        
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
    
    private static func drawTitle(_ title: String, at point: CGPoint, width: CGFloat, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.label
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
    
    private static func drawDescription(_ description: String, at point: CGPoint, width: CGFloat, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let attributedString = NSAttributedString(string: description, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: point.x,
            y: point.y,
            width: width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
    }
    
    private static func drawTimeCard(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let cardHeight: CGFloat = 100 // 增加卡片高度
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: cardHeight)
        
        // 绘制圆角卡片背景
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 12)
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.secondarySystemBackground.cgColor)
        context.fillPath()
        
        // 绘制时间信息
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
        
        let startDate = dateFormatter.string(from: trip.startDate)
        let endDate = dateFormatter.string(from: trip.endDate)
        let duration = "\(trip.durationDays) " + "trip_share_days".localized
        
        let centerY = cardRect.midY
        let itemWidth = width / 3
        
        // 绘制分割线
        let lineY1 = cardRect.minY + 25
        let lineY2 = cardRect.maxY - 25
        let lineX1 = cardRect.minX + itemWidth
        let lineX2 = cardRect.minX + itemWidth * 2
        
        context.setStrokeColor(UIColor.systemGray4.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: lineX1, y: lineY1))
        context.addLine(to: CGPoint(x: lineX1, y: lineY2))
        context.move(to: CGPoint(x: lineX2, y: lineY1))
        context.addLine(to: CGPoint(x: lineX2, y: lineY2))
        context.strokePath()
        
        // 开始日期
        drawTimeItem("trip_share_start".localized, value: startDate, icon: "calendar.badge.plus", at: CGPoint(x: cardRect.minX + itemWidth/2, y: centerY), context: context)
        
        // 结束日期
        drawTimeItem("trip_share_end".localized, value: endDate, icon: "calendar.badge.minus", at: CGPoint(x: cardRect.minX + itemWidth + itemWidth/2, y: centerY), context: context)
        
        // 时长
        drawTimeItem("trip_share_duration".localized, value: duration, icon: "clock", at: CGPoint(x: cardRect.minX + itemWidth*2 + itemWidth/2, y: centerY), context: context)
        
        return cardHeight
    }
    
    private static func drawTimeItem(_ label: String, value: String, icon: String, at point: CGPoint, context: CGContext) {
        // 绘制图标
        let iconImage = UIImage(systemName: icon)
        if let iconImage = iconImage {
            let iconSize: CGFloat = 16
            let iconRect = CGRect(x: point.x - iconSize/2, y: point.y - 30, width: iconSize, height: iconSize)
            iconImage.draw(in: iconRect)
        }
        
        // 绘制标签
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        let labelSize = labelString.size()
        let labelRect = CGRect(x: point.x - labelSize.width/2, y: point.y - 10, width: labelSize.width, height: labelSize.height)
        labelString.draw(in: labelRect)
        
        // 绘制值，支持多行显示
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.label
        ]
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        let maxWidth: CGFloat = 100 // 限制宽度，强制换行
        let valueSize = valueString.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
        let valueRect = CGRect(x: point.x - valueSize.width/2, y: point.y + 10, width: valueSize.width, height: valueSize.height)
        valueString.draw(in: valueRect)
    }
    
    private static func drawRouteCard(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        let destinationCount = sortedDestinations.count
        
        var currentY = point.y
        let headerHeight: CGFloat = 50
        let itemHeight: CGFloat = 60 // 与实际绘制的行间距保持一致
        
        // 绘制卡片背景
        let totalHeight = headerHeight + (destinationCount > 0 ? CGFloat(destinationCount) * itemHeight : 80) + 40 // 增加底部padding
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: totalHeight)
        
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 12)
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.secondarySystemBackground.cgColor)
        context.fillPath()
        
        // 绘制标题
        currentY += 20
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        
        // 绘制行程路线图标
        let iconImage = UIImage(systemName: "location.fill")
        if let iconImage = iconImage {
            let iconSize: CGFloat = 16
            let iconRect = CGRect(x: point.x + 20, y: currentY, width: iconSize, height: iconSize)
            iconImage.draw(in: iconRect)
        }
        
        // 绘制行程路线文字
        let titleString = NSAttributedString(string: "trip_share_route".localized, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: point.x + 50, y: currentY))
        
        let countString = NSAttributedString(string: "\(destinationCount) " + "trip_share_locations_count".localized, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.secondaryLabel
        ])
        let countSize = countString.size()
        countString.draw(at: CGPoint(x: point.x + width - countSize.width - 20, y: currentY))
        
        currentY += 30
        
        if destinationCount > 0 {
            // 绘制目的地列表
            for (index, destination) in sortedDestinations.enumerated() {
                drawDestinationItem(destination, index: index + 1, at: CGPoint(x: point.x + 20, y: currentY), width: width - 40, context: context)
                currentY += 60 // 增加行间距
            }
        } else {
            // 绘制空状态
            let emptyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let emptyString = NSAttributedString(string: "trip_share_no_destinations".localized, attributes: emptyAttributes)
            let emptySize = emptyString.size()
            emptyString.draw(at: CGPoint(x: point.x + width/2 - emptySize.width/2, y: currentY + 20))
        }
        
        return totalHeight
    }
    
    private static func drawDestinationItem(_ destination: TravelDestination, index: Int, at point: CGPoint, width: CGFloat, context: CGContext) {
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
            // 绘制默认图标（方形圆角）
            let iconRect = CGRect(x: point.x + 50, y: point.y + 8, width: 50, height: 50)
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 8)
            context.addPath(path.cgPath)
            context.setFillColor(destination.normalizedCategory == "domestic" ? UIColor.red.withAlphaComponent(0.2).cgColor : UIColor.blue.withAlphaComponent(0.2).cgColor)
            context.fillPath()
            
            // 绘制位置图标
            let iconAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: destination.normalizedCategory == "domestic" ? UIColor.red : UIColor.blue
            ]
            let iconString = NSAttributedString(string: "📍", attributes: iconAttributes)
            let iconSize = iconString.size()
            iconString.draw(at: CGPoint(x: point.x + 75 - iconSize.width/2, y: point.y + 33 - iconSize.height/2))
        }
        
        // 绘制目的地信息
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.label
        ]
        let nameString = NSAttributedString(string: destination.name, attributes: nameAttributes)
        nameString.draw(at: CGPoint(x: point.x + 110, y: point.y + 10))
        
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium)
        
        let subtitle = "\(destination.country) • \(dateFormatter.string(from: destination.visitDate))"
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        subtitleString.draw(at: CGPoint(x: point.x + 110, y: point.y + 30))
    }
    
    private static func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        signatureString.draw(at: CGPoint(x: point.x - signatureSize.width/2, y: point.y))
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel.withAlphaComponent(0.7)
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width/2, y: point.y + 25))
    }
}
