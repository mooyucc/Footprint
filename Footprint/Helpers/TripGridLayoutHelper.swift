//
//  TripGridLayoutHelper.swift
//  Footprint
//
//  从 TripImageGenerator.swift 提取（编译拆分）
//

import SwiftUI
import UIKit
import CoreText
import CoreLocation
import MapKit

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
