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

// 全局状态管理，防止重复触发分享
private class ShareSheetManager {
    static let shared = ShareSheetManager()
    private var isPresenting = false
    private let queue = DispatchQueue(label: "com.footprint.share")
    
    func canPresent() -> Bool {
        return queue.sync { !isPresenting }
    }
    
    func setPresenting(_ value: Bool) {
        queue.sync { isPresenting = value }
    }
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // 检查是否已有分享界面正在显示
        guard ShareSheetManager.shared.canPresent() else {
            // 如果已有分享界面，返回一个空的控制器
            let emptyController = UIActivityViewController(activityItems: [], applicationActivities: nil)
            return emptyController
        }
        
        ShareSheetManager.shared.setPresenting(true)
        
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // 设置完成回调，防止重复触发
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            ShareSheetManager.shared.setPresenting(false)
            
            if let error = error {
                print("⚠️ 分享错误: \(error.localizedDescription)")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 版面类型枚举
enum TripShareLayout: String, CaseIterable, Identifiable {
    case list = "list"
    case extendedGrid = "extendedGrid"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .list:
            return "trip_share_layout_list".localized
        case .extendedGrid:
            return "trip_share_layout_extended_grid".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .extendedGrid:
            return "square.grid.3x3.square.badge.ellipsis"
        }
    }
    
    var description: String {
        switch self {
        case .list:
            return "trip_share_layout_list_desc".localized
        case .extendedGrid:
            return "trip_share_layout_extended_grid_desc".localized
        }
    }
}

// MARK: - 地点分享版面类型枚举
enum DestinationShareLayout: String, CaseIterable, Identifiable {
    case classic = "classic"           // 经典版面（原有样式）
    case posterPromo = "posterPromo"  // 宣传海报样式（大图+小图）
    case posterCollage = "posterCollage" // 拼贴海报样式（3x3网格）
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .classic:
            return "经典版面"
        case .posterPromo:
            return "宣传海报"
        case .posterCollage:
            return "拼贴海报"
        }
    }
    
    var iconName: String {
        switch self {
        case .classic:
            return "rectangle.portrait"
        case .posterPromo:
            return "photo.on.rectangle.angled"
        case .posterCollage:
            return "square.grid.3x3"
        }
    }
    
    var description: String {
        switch self {
        case .classic:
            return "传统的垂直布局，适合展示详细信息"
        case .posterPromo:
            return "突出主图，底部配小图，适合宣传推广"
        case .posterCollage:
            return "3x3网格拼贴，展示多张照片，适合旅行记录"
        }
    }
}

// MARK: - 版面生成器协议
protocol TripLayoutGenerator {
    func generateImage(from trip: TravelTrip) -> UIImage?
}

// MARK: - 地点分享版面生成器协议
protocol DestinationLayoutGenerator {
    func generateImage(from destination: TravelDestination) -> UIImage?
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
    /// 生成旅程图片（使用默认清单版面，保持向后兼容）
    static func generateTripImage(from trip: TravelTrip) -> UIImage? {
        return ListLayoutGenerator().generateImage(from: trip)
    }
    
    /// 根据版面类型生成图片
    static func generateTripImage(from trip: TravelTrip, layout: TripShareLayout) -> UIImage? {
        switch layout {
        case .list:
            return ListLayoutGenerator().generateImage(from: trip)
        case .extendedGrid:
            return ExtendedGridLayoutGenerator().generateImage(from: trip)
        }
    }
    
    /// 生成地点分享图片（使用默认经典版面，保持向后兼容）
    static func generateDestinationImage(from destination: TravelDestination) -> UIImage? {
        return generateDestinationImage(from: destination, layout: .classic)
    }
    
    /// 根据版面类型生成地点分享图片
    static func generateDestinationImage(from destination: TravelDestination, layout: DestinationShareLayout) -> UIImage? {
        switch layout {
        case .classic:
            return ClassicDestinationLayoutGenerator().generateImage(from: destination)
        case .posterPromo:
            return PosterPromoLayoutGenerator().generateImage(from: destination)
        case .posterCollage:
            return PosterCollageLayoutGenerator().generateImage(from: destination)
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
        }
    }
    
    // MARK: - 地点图片绘制辅助方法
    
    /// 绘制三色线性渐变背景（符合App配色标准）
    /// 使用 AppColorScheme 统一方法
    static func drawGradientBackground(in rect: CGRect, context: CGContext) {
        AppColorScheme.drawGradientBackground(in: rect, context: context)
    }
    
    /// 绘制用户头像和用户名
    static func drawUserInfo(at point: CGPoint, avatarSize: CGFloat, context: CGContext) -> CGFloat {
        let signInManager = AppleSignInManager.shared
        let userName = signInManager.displayName
        let avatarImage = signInManager.userAvatarImage
        
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
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let userNameString = NSAttributedString(string: userName, attributes: userNameAttributes)
        let userNameX = point.x + avatarSize + 12 // 头像右侧12点间距
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
    
    private static func drawDestinationTitleWithSubtitle(title: String, subtitle: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        // 获取品牌颜色
        let brandColor = BrandColorManager.shared.currentBrandColor
        let brandUIColor = UIColor(brandColor)
        
        // 绘制主标题（参考图样式：大号字体）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        ]
        
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleString.size()
        
        // 在文字下方绘制半透明品牌色高亮
        // 高亮高度约为字体高度的 40%，位置在文字垂直中心
        let highlightHeight = titleSize.height * 0.4
        let highlightY = point.y + titleSize.height * 0.45 // 从文字中心偏上一点开始，覆盖中间部分
        let highlightWidth = titleSize.width + 24 // 稍微超出文字宽度（左右各12点）
        let highlightX = point.x - 12 // 向左偏移12点，使高亮超出文字
        
        // 设置半透明品牌色（透明度约 0.25，更接近图片效果）
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        brandUIColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let highlightColor = UIColor(red: red, green: green, blue: blue, alpha: 0.25)
        context.setFillColor(highlightColor.cgColor)
        
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
        
        // 绘制标题文字（在高亮之上）
        titleString.draw(at: point)
        
        // 绘制副标题（国家信息，稍小字体）
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        
        let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x, y: point.y + titleSize.height + 8))
        
        // 返回总高度：标题高度 + 间距 + 副标题高度
        return titleSize.height + 8 + subtitleSize.height
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
    
    private static func drawDestinationNotes(_ notes: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        // 绘制笔记标题（参考图样式：更优雅的标题）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let titleString = NSAttributedString(string: "travel_notes".localized, attributes: titleAttributes)
        titleString.draw(at: point)
        
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
            y: point.y + 28,
            width: width,
            height: ceil(notesRect.height)
        )
        
        notesString.draw(in: notesDrawRect)
        
        return 28 + ceil(notesRect.height)
    }
    
    fileprivate static func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
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
            
            // 绘制时间信息卡片
            currentY += 20
            let timeCardHeight = drawTimeCard(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += timeCardHeight + 20
            
            // 绘制行程路线
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
        
        // 内容区域padding（封面到时间卡片的间距）
        height += 20
        
        // 时间信息卡片
        height += 20 + 100 + 20 // padding + card + margin (增加卡片高度)
        
        // 行程路线卡片（使用卡片样式）
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        let destinationCount = sortedDestinations.count
        var routeHeight: CGFloat = 0
        if destinationCount > 0 {
            // 每个卡片固定高度160pt，卡片间距12pt
            let cardHeight: CGFloat = 160
            let cardSpacing: CGFloat = 12
            let totalCardsHeight = CGFloat(destinationCount) * cardHeight + CGFloat(destinationCount - 1) * cardSpacing
            // 注意：drawRouteCard返回的高度包含20点底部padding（卡片内部），
            // 但签名是在卡片外面绘制的，所以这里不包含这个20点padding
            routeHeight = 50 + totalCardsHeight // header + cards（不包含底部padding，因为签名在卡片外）
        } else {
            routeHeight = 136 // empty state
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
    
    private func drawTimeCard(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let cardHeight: CGFloat = 100 // 增加卡片高度
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: cardHeight)
        
        // 绘制圆角卡片背景 - 使用白色背景，与"我的"tab一致
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 20) // 使用20圆角
        context.saveGState()
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        // 使用与"我的"tab一致的大卡片阴影
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        context.fillPath()
        context.restoreGState()
        
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
        
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.06).cgColor) // 更柔和的边框
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
    
    private func drawTimeItem(_ label: String, value: String, icon: String, at point: CGPoint, context: CGContext) {
        // 绘制图标
        let iconImage = UIImage(systemName: icon)
        if let iconImage = iconImage {
            let iconSize: CGFloat = 16
            let iconRect = CGRect(x: point.x - iconSize/2, y: point.y - 30, width: iconSize, height: iconSize)
            // 使用深灰色，与"我的"tab一致
            let tintedIcon = iconImage.withTintColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        // 绘制标签 - 使用次要文本颜色
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        let labelSize = labelString.size()
        let labelRect = CGRect(x: point.x - labelSize.width/2, y: point.y - 10, width: labelSize.width, height: labelSize.height)
        labelString.draw(in: labelRect)
        
        // 绘制值，单行显示 - 使用深灰色
        // 时长使用16pt加粗，日期使用13pt
        let isDuration = icon == "clock"
        let valueFontSize: CGFloat = isDuration ? 16 : 13
        let valueFontWeight: UIFont.Weight = isDuration ? .bold : .medium
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: valueFontSize, weight: valueFontWeight),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        let maxWidth: CGFloat = 150 // 增加宽度以确保单行显示
        let valueSize = valueString.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
        let valueRect = CGRect(x: point.x - valueSize.width/2, y: point.y + 10, width: min(valueSize.width, maxWidth), height: valueSize.height)
        valueString.draw(in: valueRect)
    }
    
    /// 计算单个地点卡片的高度（卡片样式，固定高度）
    private func calculateDestinationItemHeight(_ destination: TravelDestination, nextDestination: TravelDestination?, width: CGFloat) -> CGFloat {
        let cardHeight: CGFloat = 160 // 固定卡片高度
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
    
    private func drawRouteCard(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        let destinationCount = sortedDestinations.count
        
        var currentY = point.y
        let headerHeight: CGFloat = 50
        
        // 计算总高度（卡片样式，固定高度）
        var totalItemsHeight: CGFloat = 0
        if destinationCount > 0 {
            let cardHeight: CGFloat = 160
            let cardSpacing: CGFloat = 12
            totalItemsHeight = CGFloat(destinationCount) * cardHeight + CGFloat(destinationCount - 1) * cardSpacing
        }
        
        // 绘制卡片背景
        let totalHeight = headerHeight + (destinationCount > 0 ? totalItemsHeight : 80) + 20 // 底部padding
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: totalHeight)
        
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 20) // 使用20圆角，与"我的"tab一致
        context.saveGState()
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        // 使用与"我的"tab一致的大卡片阴影
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        context.fillPath()
        context.restoreGState()
        
        // 绘制标题
        currentY += 20
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        
        // 绘制行程路线图标
        let iconImage = UIImage(systemName: "location.fill")
        if let iconImage = iconImage {
            let iconSize: CGFloat = 16
            let iconRect = CGRect(x: point.x + 20, y: currentY, width: iconSize, height: iconSize)
            // 使用深灰色，与"我的"tab一致
            let tintedIcon = iconImage.withTintColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), renderingMode: .alwaysOriginal)
            tintedIcon.draw(in: iconRect)
        }
        
        // 绘制行程路线文字
        let titleString = NSAttributedString(string: "trip_share_route".localized, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: point.x + 50, y: currentY))
        
        let countString = NSAttributedString(string: "\(destinationCount) " + "trip_share_locations_count".localized, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ])
        let countSize = countString.size()
        countString.draw(at: CGPoint(x: point.x + width - countSize.width - 20, y: currentY))
        
        currentY += 30
        
        if destinationCount > 0 {
            // 绘制目的地卡片列表
            let cardSpacing: CGFloat = 12
            let cardHeight: CGFloat = 160
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
            let emptyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
            ]
            let emptyString = NSAttributedString(string: "trip_share_no_destinations".localized, attributes: emptyAttributes)
            let emptySize = emptyString.size()
            emptyString.draw(at: CGPoint(x: point.x + width/2 - emptySize.width/2, y: currentY + 20))
        }
        
        return totalHeight
    }
    
    /// 绘制地点卡片（卡片样式，类似 DestinationRowCard）
    private func drawDestinationCard(_ destination: TravelDestination, at point: CGPoint, width: CGFloat, context: CGContext) {
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
struct GridLayoutHelper {
    /// 绘制九宫格布局（支持1-9张图片的智能布局）
    /// - Parameters:
    ///   - images: 图片数组
    ///   - destinations: 目的地数组
    ///   - startIndex: 起始序号（用于显示序号标签）
    ///   - at: 起始位置
    ///   - width: 布局宽度
    ///   - context: 绘图上下文
    ///   - drawMainImage: 绘制主图的函数（用于1张或2-8张时的第一张）
    ///   - drawGridPhoto: 绘制网格照片的函数
    /// - Returns: 布局占用的高度
    static func drawGridLayout(
        images: [UIImage],
        destinations: [TravelDestination],
        startIndex: Int,
        at point: CGPoint,
        width: CGFloat,
        context: CGContext,
        drawMainImage: (UIImage, TravelDestination, Int, CGRect, CGContext) -> Void,
        drawGridPhoto: (UIImage, TravelDestination, Int, CGRect, CGContext) -> Void
    ) -> CGFloat {
        let photoCount = images.count
        guard photoCount > 0, photoCount <= 9 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片之间的间距
        var currentY = point.y
        
        if photoCount == 1 {
            // 1张照片：显示为大图（3:2比例，宽度×2/3，圆角12pt）
            let mainImageHeight = width * 2.0 / 3.0 // 3:2比例
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageHeight)
            drawMainImage(images[0], destinations[0], startIndex, mainImageRect, context)
            return mainImageHeight
        } else if photoCount == 9 {
            // 9张照片：不设置主图，直接3x3排列
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            
            for row in 0..<cols {
                var currentX = point.x
                for col in 0..<cols {
                    let index = row * cols + col
                    if index < images.count {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(images[index], destinations[index], startIndex + index, photoRect, context)
                    }
                    currentX += photoSize + spacing
                }
                
                if row < cols - 1 {
                    currentY += photoSize + spacing
                } else {
                    currentY += photoSize
                }
            }
            
            return currentY - point.y
        } else {
            // 2-8张照片：第一张主图（60%宽度高度，圆角12pt）+ 其余网格
            let mainImageSize = width * 0.6
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
            drawMainImage(images[0], destinations[0], startIndex, mainImageRect, context)
            currentY += mainImageSize + spacing
            
            // 绘制其余照片的网格
            let remainingImages = Array(images[1..<images.count])
            let remainingDestinations = Array(destinations[1..<destinations.count])
            let gridHeight = drawSmartGrid(
                images: remainingImages,
                destinations: remainingDestinations,
                startIndex: startIndex + 1,
                at: CGPoint(x: point.x, y: currentY),
                width: width,
                context: context,
                drawMainImage: drawMainImage,
                drawGridPhoto: drawGridPhoto
            )
            currentY += gridHeight
            
            return currentY - point.y
        }
    }
    
    /// 绘制智能网格（用于2-8张照片的剩余部分）
    private static func drawSmartGrid(
        images: [UIImage],
        destinations: [TravelDestination],
        startIndex: Int,
        at point: CGPoint,
        width: CGFloat,
        context: CGContext,
        drawMainImage: (UIImage, TravelDestination, Int, CGRect, CGContext) -> Void,
        drawGridPhoto: (UIImage, TravelDestination, Int, CGRect, CGContext) -> Void
    ) -> CGFloat {
        let photoCount = images.count
        guard photoCount > 0 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片之间的间距
        var currentY = point.y
        
        if photoCount == 1 {
            // 1张：单行占满，矩形（与主图类似）
            let mainImageSize = width * 0.6 // 高度为60%宽度
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
            drawMainImage(images[0], destinations[0], startIndex, mainImageRect, context)
            return mainImageSize
        } else if photoCount <= 3 {
            // 2-3张：单行显示
            let photoSize = (width - spacing * CGFloat(photoCount - 1)) / CGFloat(photoCount)
            var currentX = point.x
            
            for (index, image) in images.enumerated() {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawGridPhoto(image, destinations[index], startIndex + index, photoRect, context)
                currentX += photoSize + spacing
            }
            return photoSize
        } else if photoCount == 4 {
            // 4张：第1行3张（3列网格），第2行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawGridPhoto(images[col], destinations[col], startIndex + col, photoRect, context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：1张占满整行，矩形（高度=标准网格方块高度）
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: photoSize)
            drawMainImage(images[3], destinations[3], startIndex + 3, mainImageRect, context)
            currentY += photoSize
            
            return currentY - point.y
        } else if photoCount == 5 {
            // 5张：第1行3张（3列网格），第2行2张（单行均分，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawGridPhoto(images[col], destinations[col], startIndex + col, photoRect, context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：2张单行均分（高度=标准网格方块高度）
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            currentX = point.x
            
            for col in 0..<remainingPhotos {
                let index = cols + col
                if index < images.count {
                    let photoRect = CGRect(x: currentX, y: currentY, width: rowPhotoSize, height: photoSize) // 高度使用标准网格方块高度
                    drawGridPhoto(images[index], destinations[index], startIndex + index, photoRect, context)
                }
                currentX += rowPhotoSize + spacing
            }
            currentY += photoSize
            
            return currentY - point.y
        } else if photoCount == 6 {
            // 6张：第1行3张（3列网格），第2行3张（3列网格）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawGridPhoto(images[col], destinations[col], startIndex + col, photoRect, context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                let index = cols + col
                if index < images.count {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(images[index], destinations[index], startIndex + index, photoRect, context)
                }
                currentX += photoSize + spacing
            }
            currentY += photoSize
            
            return currentY - point.y
        } else if photoCount == 7 {
            // 7张：第1行3张（3列网格），第2行3张（3列网格），第3行1张（全宽矩形，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawGridPhoto(images[col], destinations[col], startIndex + col, photoRect, context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                let index = cols + col
                if index < images.count {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(images[index], destinations[index], startIndex + index, photoRect, context)
                }
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第3行：1张占满整行，矩形（高度=标准网格方块高度）
            let index = cols * 2
            if index < images.count {
                let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: photoSize)
                drawMainImage(images[index], destinations[index], startIndex + index, mainImageRect, context)
                currentY += photoSize
            }
            
            return currentY - point.y
        } else if photoCount == 8 {
            // 8张：第1行3张（3列网格），第2行3张（3列网格），第3行2张（单行均分，高度=标准网格方块高度）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawGridPhoto(images[col], destinations[col], startIndex + col, photoRect, context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawGridPhoto(images[cols + col], destinations[cols + col], startIndex + cols + col, photoRect, context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第3行：2张单行均分（高度=标准网格方块高度）
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            currentX = point.x
            
            for col in 0..<remainingPhotos {
                let index = cols * 2 + col
                if index < images.count {
                    let photoRect = CGRect(x: currentX, y: currentY, width: rowPhotoSize, height: photoSize)
                    drawGridPhoto(images[index], destinations[index], startIndex + index, photoRect, context)
                }
                currentX += rowPhotoSize + spacing
            }
            currentY += photoSize
            
            return currentY - point.y
        } else {
            return 0
        }
    }
    
    /// 计算九宫格布局的高度（支持1-9张图片）
    /// - Parameters:
    ///   - photoCount: 图片数量（1-9）
    ///   - width: 布局宽度
    /// - Returns: 布局占用的高度
    static func calculateGridHeight(photoCount: Int, width: CGFloat) -> CGFloat {
        guard photoCount > 0, photoCount <= 9 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片间距
        
        if photoCount == 1 {
            // 1张照片：显示为大图（3:2比例，宽度×2/3）
            return width * 2.0 / 3.0
        } else if photoCount == 9 {
            // 9张照片：不设置主图，直接3x3排列
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let rows = 3
            return CGFloat(rows) * photoSize + CGFloat(rows - 1) * spacing
        } else {
            // 2-8张照片：主图（60%宽度高度）+ 其余网格
            let mainImageSize = width * 0.6
            let remainingCount = photoCount - 1
            
            // 计算剩余照片的网格高度
            let gridHeight: CGFloat
            if remainingCount == 1 {
                // 1张：单行占满，矩形（与主图类似）
                gridHeight = width * 0.6 // 高度为60%宽度
            } else if remainingCount <= 3 {
                // 2-3张：单行显示
                let photoSize = (width - spacing * CGFloat(remainingCount - 1)) / CGFloat(remainingCount)
                gridHeight = photoSize
            } else if remainingCount == 4 {
                // 4张：第1行3张（3列网格），第2行1张（全宽矩形，高度=标准网格方块高度）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
                gridHeight = photoSize + spacing + photoSize // 第1行高度 + 间距 + 第2行高度（等于标准网格方块高度）
            } else if remainingCount == 5 {
                // 5张：第1行3张（3列网格），第2行2张（单行均分，高度=标准网格方块高度）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
                gridHeight = photoSize + spacing + photoSize // 第1行高度 + 间距 + 第2行高度（等于标准网格方块高度）
            } else if remainingCount == 6 {
                // 6张：第1行3张（3列网格），第2行3张（3列网格）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let rows = 2
                gridHeight = CGFloat(rows) * photoSize + CGFloat(rows - 1) * spacing
            } else if remainingCount == 7 {
                // 7张：第1行3张（3列网格），第2行3张（3列网格），第3行1张（全宽矩形，高度=标准网格方块高度）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
                gridHeight = CGFloat(2) * photoSize + CGFloat(2) * spacing + photoSize // 第1行高度 + 间距 + 第2行高度 + 间距 + 第3行高度（等于标准网格方块高度）
            } else {
                // 8张：第1行3张（3列网格），第2行3张（3列网格），第3行2张（单行均分，高度=标准网格方块高度）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols) // 标准网格方块高度
                gridHeight = CGFloat(2) * photoSize + CGFloat(2) * spacing + photoSize // 第1行高度 + 间距 + 第2行高度 + 间距 + 第3行高度（等于标准网格方块高度）
            }
            
            return mainImageSize + spacing + gridHeight
        }
    }
}

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
            
            // 绘制时间信息卡片
            let timeCardHeight = drawTimeCard(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += timeCardHeight + 20 // 与地点卡片间距20
            
            // 绘制扩展网格拼图（支持超过9个地点）
            if !sortedDestinations.isEmpty {
                let gridHeight = drawExtendedGrid(destinations: sortedDestinations, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                currentY += gridHeight
            } else {
                // 空状态
                drawEmptyState(at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                currentY += 200
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
        height += headerHeight // 标题区域高度（已包含到时间卡片的间距）
        
        // 时间信息卡片
        height += 100 + 20 // 与地点卡片间距20
        
        // 扩展网格区域（每9张图片重复九宫格布局）
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
                height += GridLayoutHelper.calculateGridHeight(photoCount: groupCount, width: contentWidth)
            }
            
            // 注意：不在这里添加padding，因为绘制时网格后直接是签名间距24，没有额外的20点padding
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
    
    private func drawTimeCard(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
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
        
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.06).cgColor)
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
    
    private func drawTimeItem(_ label: String, value: String, icon: String, at point: CGPoint, context: CGContext) {
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
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // #666666
        ]
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        let labelSize = labelString.size()
        let labelRect = CGRect(x: point.x - labelSize.width/2, y: point.y - 10, width: labelSize.width, height: labelSize.height)
        labelString.draw(in: labelRect)
        
        // 绘制值，单行显示
        // 时长使用16pt加粗，日期使用13pt
        let isDuration = icon == "clock"
        let valueFontSize: CGFloat = isDuration ? 16 : 13
        let valueFontWeight: UIFont.Weight = isDuration ? .bold : .medium
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: valueFontSize, weight: valueFontWeight),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        let maxWidth: CGFloat = 150 // 增加宽度以确保单行显示
        let valueSize = valueString.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
        let valueRect = CGRect(x: point.x - valueSize.width/2, y: point.y + 10, width: min(valueSize.width, maxWidth), height: valueSize.height)
        valueString.draw(in: valueRect)
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
            
            // 获取该组的地点照片数据
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
    
    private func drawGridItem(destination: TravelDestination, index: Int, in rect: CGRect, context: CGContext) {
        // 绘制圆角矩形背景
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()
        
        // 绘制图片或默认背景
        if let photoData = destination.photoData,
           let photoImage = UIImage(data: photoData) {
            // 绘制图片，保持宽高比
            let imageAspectRatio = photoImage.size.width / photoImage.size.height
            let rectAspectRatio = rect.width / rect.height
            
            var drawRect = rect
            if imageAspectRatio > rectAspectRatio {
                // 图片更宽，以高度为准
                let scaledWidth = rect.height * imageAspectRatio
                drawRect = CGRect(x: rect.midX - scaledWidth/2, y: rect.minY, width: scaledWidth, height: rect.height)
            } else {
                // 图片更高，以宽度为准
                let scaledHeight = rect.width / imageAspectRatio
                drawRect = CGRect(x: rect.minX, y: rect.midY - scaledHeight/2, width: rect.width, height: scaledHeight)
            }
            
            photoImage.draw(in: drawRect)
        } else {
            // 使用 ImageMooyu 作为默认图片
            if let defaultImage = UIImage(named: "ImageMooyu") {
                // 使用原始渲染模式，确保颜色正确显示
                let originalImage = defaultImage.withRenderingMode(.alwaysOriginal)
                
                // 绘制图片，保持宽高比
                let imageAspectRatio = defaultImage.size.width / defaultImage.size.height
                let rectAspectRatio = rect.width / rect.height
                
                var drawRect: CGRect
                if imageAspectRatio > rectAspectRatio {
                    // 图片更宽，以高度为准
                    let scaledWidth = rect.height * imageAspectRatio
                    drawRect = CGRect(
                        x: rect.midX - scaledWidth/2,
                        y: rect.minY,
                        width: scaledWidth,
                        height: rect.height
                    )
                } else {
                    // 图片更高，以宽度为准
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
        
        // 绘制半透明背景（带圆角，半径与地点照片一致为12）
        let cornerRadius: CGFloat = 12
        // 使用 UIBezierPath 的 roundedRect 方法，只给底部两个角添加圆角
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

// MARK: - 地点分享版面生成器

/// 经典版面生成器（原有样式）
struct ClassicDestinationLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(from destination: TravelDestination) -> UIImage? {
        return TripImageGenerator.generateDestinationImageClassic(from: destination)
    }
}

/// 宣传海报版面生成器（大图+小图布局）
struct PosterPromoLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(from destination: TravelDestination) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 24
        let topPadding: CGFloat = 32
        let bottomPadding: CGFloat = 24
        let contentWidth = screenWidth - horizontalPadding * 2
        
        // 获取所有照片
        let allPhotos: [Data] = {
            if !destination.photoDatas.isEmpty {
                return destination.photoDatas
            } else if let photoData = destination.photoData {
                return [photoData]
            } else {
                return []
            }
        }()
        
        let photoCount = min(allPhotos.count, 4) // 最多4张：1张大图 + 3张小图
        
        // 计算内容高度
        var contentHeight: CGFloat = 0
        contentHeight += topPadding
        
        // 标题区域
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let titleString = NSAttributedString(string: destination.name, attributes: titleAttributes)
        let titleRect = titleString.boundingRect(
            with: CGSize(width: contentWidth, height: 150),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleHeight = ceil(titleRect.height)
        contentHeight += titleHeight + 12
        
        // 副标题/描述（如果有笔记）
        var subtitleHeight: CGFloat = 0
        if !destination.notes.isEmpty {
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    return style
                }()
            ]
            let subtitleString = NSAttributedString(string: destination.notes, attributes: subtitleAttributes)
            let subtitleRect = subtitleString.boundingRect(
                with: CGSize(width: contentWidth, height: 100),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            subtitleHeight = ceil(subtitleRect.height) + 8
        }
        contentHeight += subtitleHeight + 24
        
        // 主图区域（16:9比例）
        let mainImageHeight = contentWidth * 9.0 / 16.0
        contentHeight += mainImageHeight + 16
        
        // 底部小图区域（如果有）
        if photoCount > 1 {
            let smallImageSize = (contentWidth - 16 * 2) / 3 // 3张小图，间距16
            contentHeight += smallImageSize + bottomPadding
        } else {
            contentHeight += bottomPadding
        }
        
        // 底部日期和签名
        let dateHeight: CGFloat = 20
        let signatureHeight: CGFloat = 40
        contentHeight += dateHeight + 16 + signatureHeight + bottomPadding
        
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 绘制背景（使用浅色背景，适合海报风格）
            let backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0) // 浅灰
            cgContext.setFillColor(backgroundColor.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY: CGFloat = topPadding
            
            // 绘制标题（白色文字，需要深色背景或渐变遮罩）
            if let mainPhoto = allPhotos.first, let _ = UIImage(data: mainPhoto) {
                // 在标题区域绘制渐变遮罩背景
                let titleBackgroundHeight = titleHeight + subtitleHeight + 32
                let titleBackgroundRect = CGRect(
                    x: 0,
                    y: currentY - 8,
                    width: screenWidth,
                    height: titleBackgroundHeight
                )
                
                // 绘制渐变遮罩（从黑色半透明到透明）
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        UIColor.black.withAlphaComponent(0.6).cgColor,
                        UIColor.black.withAlphaComponent(0.3).cgColor,
                        UIColor.clear.cgColor
                    ] as CFArray,
                    locations: [0.0, 0.5, 1.0]
                )!
                cgContext.saveGState()
                cgContext.addRect(titleBackgroundRect)
                cgContext.clip()
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: titleBackgroundRect.minY),
                    end: CGPoint(x: 0, y: titleBackgroundRect.maxY),
                    options: []
                )
                cgContext.restoreGState()
            }
            
            // 绘制标题文字
            titleString.draw(at: CGPoint(x: horizontalPadding, y: currentY))
            currentY += titleHeight + 12
            
            // 绘制副标题
            if !destination.notes.isEmpty {
                let subtitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.lineBreakMode = .byWordWrapping
                        return style
                    }()
                ]
                let subtitleString = NSAttributedString(string: destination.notes, attributes: subtitleAttributes)
                let subtitleRect = subtitleString.boundingRect(
                    with: CGSize(width: contentWidth, height: 100),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                subtitleString.draw(in: CGRect(x: horizontalPadding, y: currentY, width: contentWidth, height: ceil(subtitleRect.height)))
                currentY += ceil(subtitleRect.height) + 8
            }
            
            currentY += 16
            
            // 绘制主图
            autoreleasepool {
                if let mainPhoto = allPhotos.first, let mainImage = UIImage(data: mainPhoto) {
                    let mainImageRect = CGRect(x: horizontalPadding, y: currentY, width: contentWidth, height: mainImageHeight)
                    drawMainImage(mainImage, in: mainImageRect, context: cgContext)
                    currentY += mainImageHeight + 16
                }
            }
            
            // 绘制底部小图（3张小图）
            if photoCount > 1 {
                let smallImageSize = (contentWidth - 16 * 2) / 3
                var smallImageX = horizontalPadding
                let smallImageY = currentY
                
                for i in 1..<min(photoCount, 4) {
                    autoreleasepool {
                        if i < allPhotos.count, let smallImage = UIImage(data: allPhotos[i]) {
                            let smallImageRect = CGRect(
                                x: smallImageX,
                                y: smallImageY,
                                width: smallImageSize,
                                height: smallImageSize
                            )
                            drawGridPhoto(smallImage, in: smallImageRect, context: cgContext)
                            smallImageX += smallImageSize + 16
                        }
                    }
                }
                currentY += smallImageSize + 16
            }
            
            // 绘制日期
            let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .full, timeStyle: .none)
            let dateString = dateFormatter.string(from: destination.visitDate)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            ]
            let dateStringAttr = NSAttributedString(string: dateString, attributes: dateAttributes)
            let dateSize = dateStringAttr.size()
            dateStringAttr.draw(at: CGPoint(x: horizontalPadding, y: currentY))
            currentY += dateSize.height + 16
            
            // 绘制签名
            TripImageGenerator.drawSignature(
                at: CGPoint(x: screenWidth/2, y: currentY),
                width: contentWidth,
                context: cgContext
            )
        }
    }
    
    private func drawMainImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.addPath(path.cgPath)
        context.clip()
        
        // 计算图片缩放以适应矩形
        let imageSize = image.size
        let rectAspectRatio = rect.width / rect.height
        let imageAspectRatio = imageSize.width / imageSize.height
        
        var drawRect = rect
        if imageAspectRatio > rectAspectRatio {
            // 图片更宽，以高度为准
            let scaledWidth = rect.height * imageAspectRatio
            drawRect = CGRect(
                x: rect.midX - scaledWidth/2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            // 图片更高，以宽度为准
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
    
    private func drawGridPhoto(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        context.addPath(path.cgPath)
        context.clip()
        
        let imageSize = image.size
        let rectAspectRatio = rect.width / rect.height
        let imageAspectRatio = imageSize.width / imageSize.height
        
        var drawRect = rect
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
        
        image.draw(in: drawRect)
        context.restoreGState()
    }
}

/// 拼贴海报版面生成器（3x3网格布局）
struct PosterCollageLayoutGenerator: DestinationLayoutGenerator {
    func generateImage(from destination: TravelDestination) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 20
        let topPadding: CGFloat = 24
        let bottomPadding: CGFloat = 24
        let contentWidth = screenWidth - horizontalPadding * 2
        
        // 获取所有照片（最多9张）
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
        
        // 顶部标题区域
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byWordWrapping
                return style
            }()
        ]
        let titleString = NSAttributedString(string: destination.name, attributes: titleAttributes)
        let titleRect = titleString.boundingRect(
            with: CGSize(width: contentWidth, height: 120),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let titleHeight = ceil(titleRect.height)
        contentHeight += titleHeight + 12
        
        // 日期信息
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium, timeStyle: .none)
        let dateString = dateFormatter.string(from: destination.visitDate)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        ]
        let dateStringAttr = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateHeight = ceil(dateStringAttr.size().height)
        contentHeight += dateHeight + 20
        
        // 3x3网格照片区域
        if photoCount > 0 {
            let photoSpacing: CGFloat = 4
            let photoSize = (contentWidth - photoSpacing * 2) / 3
            let gridRows = min(3, (photoCount + 2) / 3) // 向上取整
            let gridHeight = CGFloat(gridRows) * photoSize + CGFloat(max(0, gridRows - 1)) * photoSpacing
            contentHeight += gridHeight + 20
        }
        
        // 笔记/引用文字区域（如果有）
        var notesHeight: CGFloat = 0
        if !destination.notes.isEmpty {
            let notesAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 15),
                .foregroundColor: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 4
                    style.lineBreakMode = .byWordWrapping
                    style.alignment = .center
                    return style
                }()
            ]
            let notesString = NSAttributedString(string: destination.notes, attributes: notesAttributes)
            let notesRect = notesString.boundingRect(
                with: CGSize(width: contentWidth, height: 200),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            notesHeight = ceil(notesRect.height) + 20
        }
        contentHeight += notesHeight
        
        // 底部签名
        let signatureHeight: CGFloat = 40
        contentHeight += signatureHeight + bottomPadding
        
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 绘制浅色背景
            let backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
            cgContext.setFillColor(backgroundColor.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY: CGFloat = topPadding
            
            // 绘制标题
            titleString.draw(at: CGPoint(x: horizontalPadding, y: currentY))
            currentY += titleHeight + 12
            
            // 绘制日期
            dateStringAttr.draw(at: CGPoint(x: horizontalPadding, y: currentY))
            currentY += dateHeight + 20
            
            // 绘制3x3网格照片
            if photoCount > 0 {
                let photoSpacing: CGFloat = 4
                let photoSize = (contentWidth - photoSpacing * 2) / 3
                var gridY = currentY
                
                for row in 0..<3 {
                    var gridX = horizontalPadding
                    for col in 0..<3 {
                        let index = row * 3 + col
                        autoreleasepool {
                            if index < photoCount, let photoImage = UIImage(data: allPhotos[index]) {
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
                currentY = gridY + 20
            }
            
            // 绘制笔记/引用文字（居中显示）
            if !destination.notes.isEmpty {
                let notesAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 15),
                    .foregroundColor: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.lineSpacing = 4
                        style.lineBreakMode = .byWordWrapping
                        style.alignment = .center
                        return style
                    }()
                ]
                let notesString = NSAttributedString(string: destination.notes, attributes: notesAttributes)
                let notesRect = notesString.boundingRect(
                    with: CGSize(width: contentWidth, height: 200),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let notesDrawRect = CGRect(
                    x: horizontalPadding,
                    y: currentY,
                    width: contentWidth,
                    height: ceil(notesRect.height)
                )
                notesString.draw(in: notesDrawRect)
                currentY += ceil(notesRect.height) + 20
            }
            
            // 绘制签名
            TripImageGenerator.drawSignature(
                at: CGPoint(x: screenWidth/2, y: currentY),
                width: contentWidth,
                context: cgContext
            )
        }
    }
    
    private func drawGridPhoto(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        context.addPath(path.cgPath)
        context.clip()
        
        let imageSize = image.size
        let rectAspectRatio = rect.width / rect.height
        let imageAspectRatio = imageSize.width / imageSize.height
        
        var drawRect = rect
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
        
        image.draw(in: drawRect)
        context.restoreGState()
    }
}
