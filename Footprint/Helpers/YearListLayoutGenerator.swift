//
//  YearListLayoutGenerator.swift
//  Footprint
//
//  从 YearImageGenerator.swift 提取（编译拆分）
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation

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
            
            // 绘制标题区域（使用共享方法，与旅程分享一致）
            let headerHeight = YearImageGenerator.drawHeader(year: year, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += headerHeight // drawHeader 已经包含了到统计卡片的间距
            
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
        height += 100 + 20 // card + margin
        
        // 目的地列表卡片（卡片样式，显示所有目的地）
        let destinationCount = destinations.count
        let cardHeight: CGFloat = 160
        let cardSpacing: CGFloat = 12
        let cardHeaderHeight: CGFloat = 50
        let totalCardsHeight = destinationCount > 0 ? CGFloat(destinationCount) * cardHeight + CGFloat(destinationCount - 1) * cardSpacing : 0
        let destinationsHeight = destinationCount > 0 ? cardHeaderHeight + totalCardsHeight + 40 : 80
        height += destinationsHeight
        
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
}

// MARK: - 共享九宫格布局辅助（用于年份分享）
