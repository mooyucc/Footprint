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

// MARK: - 版面类型枚举
enum TripShareLayout: String, CaseIterable, Identifiable {
    case list = "list"
    case grid = "grid"
    case extendedGrid = "extendedGrid"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .list:
            return "trip_share_layout_list".localized
        case .grid:
            return "trip_share_layout_grid".localized
        case .extendedGrid:
            return "trip_share_layout_extended_grid".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .grid:
            return "square.grid.3x3"
        case .extendedGrid:
            return "square.grid.4x4"
        }
    }
    
    var description: String {
        switch self {
        case .list:
            return "trip_share_layout_list_desc".localized
        case .grid:
            return "trip_share_layout_grid_desc".localized
        case .extendedGrid:
            return "trip_share_layout_extended_grid_desc".localized
        }
    }
}

// MARK: - 版面生成器协议
protocol TripLayoutGenerator {
    func generateImage(from trip: TravelTrip) -> UIImage?
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
        case .grid:
            return GridLayoutGenerator().generateImage(from: trip)
        case .extendedGrid:
            return ExtendedGridLayoutGenerator().generateImage(from: trip)
        }
    }
    
    /// 生成地点分享图片
    static func generateDestinationImage(from destination: TravelDestination) -> UIImage? {
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
        
        // 标题和副标题（需要计算实际高度）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold)
        ]
        let titleString = NSAttributedString(string: destination.name, attributes: titleAttributes)
        let titleHeight = titleString.size().height
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular)
        ]
        let subtitleString = NSAttributedString(string: destination.country, attributes: subtitleAttributes)
        let subtitleHeight = subtitleString.size().height
        
        contentHeight += titleHeight + 8 + subtitleHeight + 20 // 标题 + 间距 + 副标题 + 到时间的间距
        
        // 时间信息（简单一行）
        contentHeight += 28
        
        // 照片区域（根据数量智能布局）
        let photoSpacing: CGFloat = 6 // 统一图片间距（上下左右一致）
        let photoToNotesSpacing: CGFloat = 30 // 图片与笔记标题的间距
        if photoCount > 0 {
            if photoCount == 1 {
                // 单张照片：显示为大图
                contentHeight += contentWidth * 0.75 + photoToNotesSpacing // 大图高度（4:3比例）+ 图片与笔记间距
            } else if photoCount == 9 {
                // 9张照片：不设置主图，直接3x3排列
                let cols = 3
                let photoSize = (contentWidth - photoSpacing * CGFloat(cols - 1)) / CGFloat(cols)
                let rows = 3
                contentHeight += CGFloat(rows) * photoSize + CGFloat(rows - 1) * photoSpacing + photoToNotesSpacing
            } else {
                // 多张照片（2-8张）：第一张大图 + 其余网格
                let mainImageHeight = contentWidth * 0.6 // 主图高度
                let remainingPhotos = photoCount - 1
                let gridHeight = calculateSmartGridHeight(photoCount: remainingPhotos, width: contentWidth)
                contentHeight += mainImageHeight + photoSpacing + gridHeight + photoToNotesSpacing // 主图 + 间距 + 网格 + 图片与笔记间距
            }
        }
        
        // 笔记区域（如果有）
        if !destination.notes.isEmpty {
            let notesAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular)
            ]
            let notesString = NSAttributedString(string: destination.notes, attributes: notesAttributes)
            let notesRect = notesString.boundingRect(
                with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            contentHeight += 20 + ceil(notesRect.height) + 24 // 标题间距 + 笔记高度 + 底部间距
        }
        
        // 底部签名（两行：主签名 + 副标题）
        contentHeight += 14 + 12 + 25 // 主签名高度 + 间距 + 副标题高度
        
        contentHeight += bottomPadding
        
        let imageSize = CGSize(width: screenWidth, height: contentHeight)
        
        // 创建图片渲染器
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 设置背景色 - 使用与旅程图片一致的浅米白色背景
            cgContext.setFillColor(UIColor(red: 0.969, green: 0.953, blue: 0.922, alpha: 1.0).cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            var currentY: CGFloat = topPadding
            
            // 绘制标题和副标题（参考图样式）
            let titleHeight = drawDestinationTitleWithSubtitle(
                title: destination.name,
                subtitle: destination.country,
                at: CGPoint(x: horizontalPadding, y: currentY),
                width: contentWidth,
                context: cgContext
            )
            currentY += titleHeight + 20 // 标题区域高度 + 到时间的间距
            
            // 绘制时间信息（简单一行）
            drawDestinationDateSimple(for: destination, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
            currentY += 28
            
            // 绘制照片（智能布局）
            let photoSpacing: CGFloat = 6 // 统一图片间距（上下左右一致）
            let photoToNotesSpacing: CGFloat = 30 // 图片与笔记标题的间距
            if photoCount > 0 {
                if photoCount == 1 {
                    // 单张照片：显示为大图
                    if let photoImage = UIImage(data: allPhotos[0]) {
                        let mainImageHeight = contentWidth * 0.75
                        let mainImageRect = CGRect(x: horizontalPadding, y: currentY, width: contentWidth, height: mainImageHeight)
                        drawMainImage(photoImage, in: mainImageRect, context: cgContext)
                        currentY += mainImageHeight + photoToNotesSpacing
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
                            if index < allPhotos.count,
                               let photoImage = UIImage(data: allPhotos[index]) {
                                let photoRect = CGRect(x: gridX, y: gridY, width: photoSize, height: photoSize)
                                drawGridPhoto(photoImage, in: photoRect, context: cgContext)
                            }
                            gridX += photoSize + photoSpacing
                        }
                        if row < 2 {
                            gridY += photoSize + photoSpacing
                        } else {
                            gridY += photoSize
                        }
                    }
                    currentY = gridY + photoToNotesSpacing
                } else {
                    // 多张照片（2-8张）：第一张大图 + 其余网格
                    if let mainPhotoImage = UIImage(data: allPhotos[0]) {
                        let mainImageHeight = contentWidth * 0.6
                        let mainImageRect = CGRect(x: horizontalPadding, y: currentY, width: contentWidth, height: mainImageHeight)
                        drawMainImage(mainPhotoImage, in: mainImageRect, context: cgContext)
                        currentY += mainImageHeight + photoSpacing
                        
                        // 绘制其余照片的网格
                        let remainingPhotos = Array(allPhotos[1..<photoCount])
                        let gridHeight = drawSmartPhotoGrid(
                            photos: remainingPhotos,
                            at: CGPoint(x: horizontalPadding, y: currentY),
                            width: contentWidth,
                            context: cgContext
                        )
                        currentY += gridHeight + photoToNotesSpacing
                    }
                }
            }
            
            // 绘制笔记（如果有）
            if !destination.notes.isEmpty {
                let notesHeight = drawDestinationNotes(destination.notes, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
                currentY += notesHeight + 24
            }
            
            // 绘制底部签名
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: contentWidth, context: cgContext)
        }
    }
    
    // MARK: - 地点图片绘制辅助方法
    
    private static func drawDestinationTitleWithSubtitle(title: String, subtitle: String, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        // 绘制主标题（参考图样式：大号字体）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        ]
        
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        titleString.draw(at: point)
        
        // 绘制副标题（国家信息，稍小字体）
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        
        let titleSize = titleString.size()
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
            // 4张：第1行3张（3列网格），第2行1张（矩形占满整行）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let mainImageSize = width * 0.6 // 高度为60%宽度
            return photoSize + spacing + mainImageSize
        } else if photoCount == 5 {
            // 5张：第1行3张（3列网格），第2行2张（单行均分）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            return photoSize + spacing + rowPhotoSize
        } else if photoCount == 6 {
            // 6张：2行显示（都是3列网格）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let rows = 2
            return CGFloat(rows) * photoSize + CGFloat(rows - 1) * spacing
        } else if photoCount == 7 {
            // 7张：第1行3张（3列网格），第2行3张（3列网格），第3行1张（矩形占满整行）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let mainImageSize = width * 0.6 // 高度为60%宽度
            return CGFloat(2) * photoSize + CGFloat(2) * spacing + mainImageSize
        } else {
            // 8张：第1行3张（3列网格），第2行3张（3列网格），第3行2张（单行均分）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            return CGFloat(2) * photoSize + CGFloat(2) * spacing + rowPhotoSize
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
            if photoIndex < photos.count,
               let photoImage = UIImage(data: photos[photoIndex]) {
                let mainImageSize = width * 0.6 // 高度为60%宽度
                let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
                drawMainImage(photoImage, in: mainImageRect, context: context)
                return mainImageSize
            }
            return 0
        } else if photoCount <= 3 {
            // 2-3张：单行显示，均分宽度
            let photoSize = (width - spacing * CGFloat(photoCount - 1)) / CGFloat(photoCount)
            var currentX = point.x
            
            for _ in 0..<photoCount {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            return photoSize
        } else if photoCount == 4 {
            // 4张：第1行3张（3列网格），第2行1张（矩形占满整行）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：1张占满整行，矩形（与主图类似）
            if photoIndex < photos.count,
               let photoImage = UIImage(data: photos[photoIndex]) {
                let mainImageSize = width * 0.6 // 高度为60%宽度
                let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
                drawMainImage(photoImage, in: mainImageRect, context: context)
                currentY += mainImageSize
            }
            
            return currentY - point.y
        } else if photoCount == 5 {
            // 5张：第1行3张（3列网格），第2行2张（单行均分）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：2张单行均分
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            currentX = point.x
            
            for col in 0..<remainingPhotos {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: rowPhotoSize, height: rowPhotoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += rowPhotoSize + spacing
                photoIndex += 1
            }
            currentY += rowPhotoSize
            
            return currentY - point.y
        } else if photoCount == 6 {
            // 6张：2行显示（都是3列网格）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            
            for row in 0..<2 {
                var currentX = point.x
                let photosInRow = min(cols, photoCount - row * cols)
                
                for col in 0..<photosInRow {
                    if photoIndex < photos.count,
                       let photoImage = UIImage(data: photos[photoIndex]) {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawGridPhoto(photoImage, in: photoRect, context: context)
                    }
                    currentX += photoSize + spacing
                    photoIndex += 1
                }
                
                if row < 1 {
                    currentY += photoSize + spacing
                } else {
                    currentY += photoSize
                }
            }
            
            return currentY - point.y
        } else if photoCount == 7 {
            // 7张：第1行3张（3列网格），第2行3张（3列网格），第3行1张（矩形占满整行）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第3行：1张占满整行，矩形（与主图类似）
            if photoIndex < photos.count,
               let photoImage = UIImage(data: photos[photoIndex]) {
                let mainImageSize = width * 0.6 // 高度为60%宽度
                let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
                drawMainImage(photoImage, in: mainImageRect, context: context)
                currentY += mainImageSize
            }
            
            return currentY - point.y
        } else {
            // 8张：第1行3张（3列网格），第2行3张（3列网格），第3行2张（单行均分）
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += photoSize + spacing
                photoIndex += 1
            }
            currentY += photoSize + spacing
            
            // 第3行：2张单行均分
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            currentX = point.x
            
            for col in 0..<remainingPhotos {
                if photoIndex < photos.count,
                   let photoImage = UIImage(data: photos[photoIndex]) {
                    let photoRect = CGRect(x: currentX, y: currentY, width: rowPhotoSize, height: rowPhotoSize)
                    drawGridPhoto(photoImage, in: photoRect, context: context)
                }
                currentX += rowPhotoSize + spacing
                photoIndex += 1
            }
            currentY += rowPhotoSize
            
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
    
    private static func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
        // 绘制签名（与旅程图片一致）
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        signatureString.draw(at: CGPoint(x: point.x - signatureSize.width/2, y: point.y))
        
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
        
        // 创建图片渲染器（禁用Alpha通道以减少文件体积）
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 设置背景色 - 使用与"我的"tab一致的浅米白色背景 #f7f3eb
            cgContext.setFillColor(UIColor(red: 0.969, green: 0.953, blue: 0.922, alpha: 1.0).cgColor) // #f7f3eb
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
            
            // 绘制内容区域背景 - 使用与"我的"tab一致的浅米白色背景 #f7f3eb
            let contentRect = CGRect(x: 0, y: currentY, width: screenWidth, height: imageSize.height - currentY)
            cgContext.setFillColor(UIColor(red: 0.969, green: 0.953, blue: 0.922, alpha: 1.0).cgColor) // #f7f3eb
            cgContext.fill(contentRect)
            
            // 绘制内容
            currentY += 20
            
            // 绘制标题
            drawTitle(trip.name, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += 40
            
            // 绘制描述
            if !trip.desc.isEmpty {
                let descHeight = drawDescription(trip.desc, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
                currentY += descHeight + 12 // 描述高度 + 间距
            }
            
            // 绘制时间信息卡片
            currentY += 20
            let timeCardHeight = drawTimeCard(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += timeCardHeight + 20
            
            // 绘制行程路线
            let routeCardHeight = drawRouteCard(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            currentY += routeCardHeight
            
            // 绘制底部签名（与上面地点图片间距40，离底部边缘20）
            currentY += 40 // 与上面地点图片的间距
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }
    
    private func calculateContentHeight(for trip: TravelTrip, width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        
        // 封面图片区域
        height += 250 // 封面图片高度
        
        // 内容区域padding
        height += 20
        
        // 标题区域
        height += 28 + 12 // title + spacing
        if !trip.desc.isEmpty {
            // 动态计算描述文字的实际高度（支持多行）
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16)
            ]
            let descString = NSAttributedString(string: trip.desc, attributes: descAttributes)
            let maxHeight: CGFloat = 200 // 最大高度限制
            let descRect = descString.boundingRect(
                with: CGSize(width: width - 40, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            height += ceil(descRect.height) + 12 // 实际描述高度 + 间距
        }
        
        // 时间信息卡片
        height += 20 + 100 + 20 // padding + card + margin (增加卡片高度)
        
        // 行程路线卡片
        let destinationCount = trip.destinations?.count ?? 0
        let routeHeight = destinationCount > 0 ? CGFloat(destinationCount) * 60 + 90 : 136 // header + destinations or empty state (增加行间距和底部padding)
        height += routeHeight
        
        // 底部签名（与上面地点图片间距40，离底部边缘20）
        height += 40 + 40 + 20 // 与上面地点图片的间距 + 签名高度 + 底部padding
        
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
        // 计算多行文本的实际高度
        let maxHeight: CGFloat = 200 // 最大高度限制，防止过长
        let textRect = attributedString.boundingRect(
            with: CGSize(width: width, height: maxHeight),
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
    
    private func drawRouteCard(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        let destinationCount = sortedDestinations.count
        
        var currentY = point.y
        let headerHeight: CGFloat = 50
        let itemHeight: CGFloat = 60 // 与实际绘制的行间距保持一致
        
        // 绘制卡片背景
        let totalHeight = headerHeight + (destinationCount > 0 ? CGFloat(destinationCount) * itemHeight : 80) + 40 // 增加底部padding
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
            // 绘制目的地列表
            for (index, destination) in sortedDestinations.enumerated() {
                drawDestinationItem(destination, index: index + 1, at: CGPoint(x: point.x + 20, y: currentY), width: width - 40, context: context)
                currentY += 60 // 增加行间距
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
    
    private func drawDestinationItem(_ destination: TravelDestination, index: Int, at point: CGPoint, width: CGFloat, context: CGContext) {
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
    }
    
    private func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        signatureString.draw(at: CGPoint(x: point.x - signatureSize.width/2, y: point.y))
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width/2, y: point.y + 25))
    }
}

// MARK: - 九宫格拼图版面生成器
struct GridLayoutGenerator: TripLayoutGenerator {
    func generateImage(from trip: TravelTrip) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let sortedDestinations = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        
        // 设置页边距
        let horizontalPadding: CGFloat = 32 // 左右边距
        let topPadding: CGFloat = 40 // 顶部边距
        let bottomPadding: CGFloat = 20 // 底部边距
        let contentWidth = screenWidth - horizontalPadding * 2
        
        // 计算内容高度
        let contentHeight = calculateContentHeight(for: trip, destinations: sortedDestinations, width: screenWidth, horizontalPadding: horizontalPadding, topPadding: topPadding, bottomPadding: bottomPadding)
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
            
            // 绘制标题区域
            let headerHeight = drawHeader(for: trip, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
            // 标题区域高度 + 与时间卡片的间距（描述后12 + 到时间卡片20 = 32）
            currentY += headerHeight + 12 // 描述后的间距
            currentY += 20 // 到时间卡片的间距
            
            // 绘制时间信息卡片
            let timeCardHeight = drawTimeCard(for: trip, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
            currentY += timeCardHeight + 20 // 与地点卡片间距20
            
            // 绘制九宫格拼图
            if !sortedDestinations.isEmpty {
                let gridHeight = drawGrid(destinations: sortedDestinations, at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
                currentY += gridHeight
            } else {
                // 空状态
                drawEmptyState(at: CGPoint(x: horizontalPadding, y: currentY), width: contentWidth, context: cgContext)
                currentY += 200
            }
            
            // 绘制底部签名（与上面地点图片间距40，离底部边缘20）
            currentY += 40 // 与上面地点图片的间距
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: contentWidth, context: cgContext)
        }
    }
    
    private func calculateContentHeight(for trip: TravelTrip, destinations: [TravelDestination], width: CGFloat, horizontalPadding: CGFloat, topPadding: CGFloat, bottomPadding: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        let contentWidth = width - horizontalPadding * 2
        
        // 顶部padding
        height += topPadding
        
        // 标题区域（动态计算，包括标题和描述）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold)
        ]
        let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
        let titleSize = titleString.size()
        var headerHeight: CGFloat = titleSize.height + 12 // 标题高度 + 间距12（与描述间距）
        
        if !trip.desc.isEmpty {
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16)
            ]
            let descString = NSAttributedString(string: trip.desc, attributes: descAttributes)
            let maxHeight: CGFloat = 200
            let descRect = descString.boundingRect(
                with: CGSize(width: contentWidth, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            headerHeight += ceil(descRect.height)
        }
        height += headerHeight + 12 // 描述后的间距
        height += 20 // 到时间卡片的间距（总共32点）
        
        // 时间信息卡片
        height += 100 + 20 // 与地点卡片间距20
        
        // 九宫格区域（根据数量智能布局）
        if !destinations.isEmpty {
            let displayCount = min(destinations.count, 9)
            height += calculateSmartGridHeight(destinations: displayCount, width: contentWidth) + 20 // 格子高度 + padding
        } else {
            height += 200 // 空状态高度
        }
        
        // 底部签名区域高度（与上面地点图片间距40，离底部边缘20）
        height += 40 + 40 + bottomPadding // 与上面地点图片的间距 + 签名高度 + 底部padding
        
        return height
    }
    
    private func drawHeader(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        var currentY: CGFloat = point.y
        
        // 绘制标题
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
        let titleSize = titleString.size()
        titleString.draw(at: CGPoint(x: point.x, y: currentY))
        currentY += titleSize.height + 12 // 标题高度 + 间距12（与描述间距）
        
        // 绘制描述（支持多行）
        if !trip.desc.isEmpty {
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // #666666
            ]
            let descString = NSAttributedString(string: trip.desc, attributes: descAttributes)
            // 计算多行文本的实际高度
            let maxHeight: CGFloat = 200 // 最大高度限制
            let descRect = descString.boundingRect(
                with: CGSize(width: width, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            let drawRect = CGRect(
                x: point.x,
                y: currentY,
                width: width,
                height: ceil(descRect.height)
            )
            descString.draw(in: drawRect)
            currentY += drawRect.height
        }
        
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
    
    private func drawGrid(destinations: [TravelDestination], at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let displayDestinations = Array(destinations.prefix(9))
        let displayCount = displayDestinations.count
        guard displayCount > 0 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片间距（与地点分享图片一致）
        var currentY = point.y
        
        // 获取地点照片数据
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
            // 1张照片：显示为大图（4:3比例，圆角12pt）
            let mainImageHeight = width * 0.75 // 4:3比例
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageHeight)
            drawMainImageDestination(destinationImages[0], destination: displayDestinations[0], index: 1, in: mainImageRect, context: context)
            return mainImageHeight
        } else if displayCount == 9 {
            // 9张照片：不设置主图，直接3x3排列
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            
            for row in 0..<cols {
                var currentX = point.x
                for col in 0..<cols {
                    let index = row * cols + col
                    if index < destinationImages.count {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawDestinationGridPhoto(destinationImages[index], destination: displayDestinations[index], index: index + 1, in: photoRect, context: context)
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
            drawMainImageDestination(destinationImages[0], destination: displayDestinations[0], index: 1, in: mainImageRect, context: context)
            currentY += mainImageSize + spacing
            
            // 绘制其余照片的网格
            let remainingImages = Array(destinationImages[1..<destinationImages.count])
            let remainingDestinations = Array(displayDestinations[1..<displayDestinations.count])
            let gridHeight = drawSmartDestinationGrid(
                images: remainingImages,
                destinations: remainingDestinations,
                startIndex: 2,
                at: CGPoint(x: point.x, y: currentY),
                width: width,
                context: context
            )
            currentY += gridHeight
            
            return currentY - point.y
        }
    }
    
    // 计算智能网格的高度（根据地点数量自动调整布局，与地点分享图片一致）
    private func calculateSmartGridHeight(destinations: Int, width: CGFloat) -> CGFloat {
        guard destinations > 0 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片间距（与地点分享图片一致）
        
        if destinations == 1 {
            // 1张照片：显示为大图（4:3比例）
            return width * 0.75
        } else if destinations == 9 {
            // 9张照片：不设置主图，直接3x3排列
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let rows = 3
            return CGFloat(rows) * photoSize + CGFloat(rows - 1) * spacing
        } else {
            // 2-8张照片：主图（60%宽度高度）+ 其余网格
            let mainImageSize = width * 0.6
            let remainingCount = destinations - 1
            
            // 计算剩余照片的网格高度
            let gridHeight: CGFloat
            if remainingCount == 1 {
                // 1张：单行占满，矩形（与主图类似）
                let mainImageSize = width * 0.6 // 高度为60%宽度
                gridHeight = mainImageSize
            } else if remainingCount <= 3 {
                // 2-3张：单行显示
                let photoSize = (width - spacing * CGFloat(remainingCount - 1)) / CGFloat(remainingCount)
                gridHeight = photoSize
            } else if remainingCount == 4 {
                // 4张：特殊处理 - 前3张3列网格，最后1张单行占满（矩形）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let mainImageSize = width * 0.6 // 高度为60%宽度
                gridHeight = photoSize + spacing + mainImageSize
            } else if remainingCount == 5 {
                // 5张：特殊处理 - 前3张3列网格，后2张单行均分
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let remainingPhotos = 2
                let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
                gridHeight = photoSize + spacing + rowPhotoSize
            } else if remainingCount == 6 {
                // 6张：2行显示（都是3列网格）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let rows = 2
                gridHeight = CGFloat(rows) * photoSize + CGFloat(rows - 1) * spacing
            } else if remainingCount == 7 {
                // 7张：特殊处理 - 前6张2行3列网格，最后1张单行占满（矩形）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let mainImageSize = width * 0.6 // 高度为60%宽度
                gridHeight = CGFloat(2) * photoSize + CGFloat(2) * spacing + mainImageSize
            } else {
                // 8张：3行显示（都是3列网格，最后一行2张）
                let cols = 3
                let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let rows = 3
                gridHeight = CGFloat(rows) * photoSize + CGFloat(rows - 1) * spacing
            }
            
            return mainImageSize + spacing + gridHeight
        }
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
        
        // 绘制文字
        nameString.draw(at: CGPoint(x: rect.minX + namePadding, y: nameBackgroundRect.midY - nameSize.height/2))
    }
    
    // 绘制智能地点网格（根据数量自动调整布局，与地点分享图片一致）
    private func drawSmartDestinationGrid(images: [UIImage], destinations: [TravelDestination], startIndex: Int, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        let photoCount = images.count
        guard photoCount > 0 else { return 0 }
        
        let spacing: CGFloat = 6 // 照片之间的间距
        var currentY = point.y
        
        if photoCount == 1 {
            // 1张：单行占满，矩形（与主图类似）
            let mainImageSize = width * 0.6 // 高度为60%宽度
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
            drawMainImageDestination(images[0], destination: destinations[0], index: startIndex, in: mainImageRect, context: context)
            return mainImageSize
        } else if photoCount <= 3 {
            // 2-3张：单行显示
            let photoSize = (width - spacing * CGFloat(photoCount - 1)) / CGFloat(photoCount)
            var currentX = point.x
            
            for (index, image) in images.enumerated() {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawDestinationGridPhoto(image, destination: destinations[index], index: startIndex + index, in: photoRect, context: context)
                currentX += photoSize + spacing
            }
            return photoSize
        } else if photoCount == 4 {
            // 4张：特殊处理 - 前3张3列网格，最后1张单行占满
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawDestinationGridPhoto(images[col], destination: destinations[col], index: startIndex + col, in: photoRect, context: context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：1张占满整行，矩形（与主图类似）
            let mainImageSize = width * 0.6 // 高度为60%宽度
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
            drawMainImageDestination(images[3], destination: destinations[3], index: startIndex + 3, in: mainImageRect, context: context)
            currentY += mainImageSize
            
            return currentY - point.y
        } else if photoCount == 5 {
            // 5张：特殊处理 - 前3张3列网格，后2张单行均分
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawDestinationGridPhoto(images[col], destination: destinations[col], index: startIndex + col, in: photoRect, context: context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：2张单行均分
            let remainingPhotos = 2
            let rowPhotoSize = (width - spacing * CGFloat(remainingPhotos - 1)) / CGFloat(remainingPhotos)
            currentX = point.x
            
            for col in 0..<remainingPhotos {
                let photoRect = CGRect(x: currentX, y: currentY, width: rowPhotoSize, height: rowPhotoSize)
                drawDestinationGridPhoto(images[cols + col], destination: destinations[cols + col], index: startIndex + cols + col, in: photoRect, context: context)
                currentX += rowPhotoSize + spacing
            }
            currentY += rowPhotoSize
            
            return currentY - point.y
        } else if photoCount == 7 {
            // 7张：特殊处理 - 前6张2行3列网格，最后1张单行占满
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            var currentX = point.x
            
            // 第1行：3张（3列网格）
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawDestinationGridPhoto(images[col], destination: destinations[col], index: startIndex + col, in: photoRect, context: context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第2行：3张（3列网格）
            currentX = point.x
            for col in 0..<cols {
                let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                drawDestinationGridPhoto(images[cols + col], destination: destinations[cols + col], index: startIndex + cols + col, in: photoRect, context: context)
                currentX += photoSize + spacing
            }
            currentY += photoSize + spacing
            
            // 第3行：1张占满整行，矩形（与主图类似）
            let mainImageSize = width * 0.6 // 高度为60%宽度
            let mainImageRect = CGRect(x: point.x, y: currentY, width: width, height: mainImageSize)
            drawMainImageDestination(images[6], destination: destinations[6], index: startIndex + 6, in: mainImageRect, context: context)
            currentY += mainImageSize
            
            return currentY - point.y
        } else {
            // 6张或8张：多行网格布局
            let cols = 3
            let photoSize = (width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let rows = (photoCount + cols - 1) / cols // 向上取整
            
            for row in 0..<rows {
                var currentX = point.x
                let photosInRow = min(cols, photoCount - row * cols)
                
                for col in 0..<photosInRow {
                    let index = row * cols + col
                    if index < images.count {
                        let photoRect = CGRect(x: currentX, y: currentY, width: photoSize, height: photoSize)
                        drawDestinationGridPhoto(images[index], destination: destinations[index], index: startIndex + index, in: photoRect, context: context)
                    }
                    currentX += photoSize + spacing
                }
                
                if row < rows - 1 {
                    currentY += photoSize + spacing
                } else {
                    currentY += photoSize
                }
            }
            
            return currentY - point.y
        }
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
        
        // 绘制文字
        nameString.draw(at: CGPoint(x: rect.minX + namePadding, y: nameBackgroundRect.midY - nameSize.height/2))
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
        
        // 绘制文字
        nameString.draw(at: CGPoint(x: rect.minX + namePadding, y: nameBackgroundRect.midY - nameSize.height/2))
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
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        signatureString.draw(at: CGPoint(x: point.x - signatureSize.width/2, y: point.y))
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width/2, y: point.y + 25))
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
            
            var currentY: CGFloat = 0
            
            // 绘制标题区域
            currentY += 40
            let headerHeight = drawHeader(for: trip, at: CGPoint(x: 20, y: currentY), width: screenWidth - 40, context: cgContext)
            // 标题区域高度 + 与时间卡片的间距（描述后12 + 到时间卡片20 = 32）
            currentY += headerHeight + 12 // 描述后的间距
            currentY += 20 // 到时间卡片的间距
            
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
            
            // 绘制底部签名（与上面地点图片间距40，离底部边缘20）
            currentY += 40 // 与上面地点图片的间距
            drawSignature(at: CGPoint(x: screenWidth/2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }
    
    private func calculateContentHeight(for trip: TravelTrip, destinations: [TravelDestination], width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        
        // 顶部padding
        height += 40
        
        // 标题区域（动态计算，包括标题和描述）
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold)
        ]
        let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
        let titleSize = titleString.size()
        var headerHeight: CGFloat = titleSize.height + 12 // 标题高度 + 间距12（与描述间距）
        
        if !trip.desc.isEmpty {
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16)
            ]
            let descString = NSAttributedString(string: trip.desc, attributes: descAttributes)
            let maxHeight: CGFloat = 200
            let descRect = descString.boundingRect(
                with: CGSize(width: width - 40, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            headerHeight += ceil(descRect.height)
        }
        height += headerHeight + 12 // 描述后的间距
        height += 20 // 到时间卡片的间距（总共32点）
        
        // 时间信息卡片
        height += 100 + 20 // 与地点卡片间距20
        
        // 扩展网格区域（动态计算行数）
        if !destinations.isEmpty {
            let columns: CGFloat = 3 // 固定3列
            let rows = ceil(CGFloat(destinations.count) / columns) // 根据地点数量计算行数
            let gridSize = (width - 40) / 3 // 每个格子的大小
            height += gridSize * rows + 20 // 格子高度 + padding
        } else {
            height += 200 // 空状态高度
        }
        
        // 底部签名区域高度（与上面地点图片间距40，离底部边缘20）
        height += 40 + 40 + 20 // 与上面地点图片的间距 + 签名高度 + 底部padding
        
        return height
    }
    
    private func drawHeader(for trip: TravelTrip, at point: CGPoint, width: CGFloat, context: CGContext) -> CGFloat {
        var currentY: CGFloat = point.y
        
        // 绘制标题
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let titleString = NSAttributedString(string: trip.name, attributes: titleAttributes)
        let titleSize = titleString.size()
        titleString.draw(at: CGPoint(x: point.x, y: currentY))
        currentY += titleSize.height + 12 // 标题高度 + 间距12（与描述间距）
        
        // 绘制描述（支持多行）
        if !trip.desc.isEmpty {
            let descAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // #666666
            ]
            let descString = NSAttributedString(string: trip.desc, attributes: descAttributes)
            // 计算多行文本的实际高度
            let maxHeight: CGFloat = 200 // 最大高度限制
            let descRect = descString.boundingRect(
                with: CGSize(width: width, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            let drawRect = CGRect(
                x: point.x,
                y: currentY,
                width: width,
                height: ceil(descRect.height)
            )
            descString.draw(in: drawRect)
            currentY += drawRect.height
        }
        
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
        let columns: CGFloat = 3 // 固定3列
        let spacing: CGFloat = 8 // 格子之间的间距
        let actualGridSize = (width - spacing * 2) / 3 // 实际格子大小
        
        // 显示所有目的地（不限制数量）
        let displayCount = destinations.count
        let rows = ceil(CGFloat(displayCount) / columns)
        
        for (index, destination) in destinations.enumerated() {
            let row = index / 3
            let col = index % 3
            
            let x = point.x + CGFloat(col) * (actualGridSize + spacing)
            let y = point.y + CGFloat(row) * (actualGridSize + spacing)
            
            let gridRect = CGRect(x: x, y: y, width: actualGridSize, height: actualGridSize)
            drawGridItem(destination: destination, index: index + 1, in: gridRect, context: context)
        }
        
        return actualGridSize * rows + spacing * (rows - 1)
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
        
        // 绘制文字
        nameString.draw(at: CGPoint(x: rect.minX + namePadding, y: nameBackgroundRect.midY - nameSize.height/2))
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
        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // #333333
        ]
        let signatureString = NSAttributedString(string: "trip_share_signature".localized, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        signatureString.draw(at: CGPoint(x: point.x - signatureSize.width/2, y: point.y))
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // 次要文本 #666666
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width/2, y: point.y + 25))
    }
}
