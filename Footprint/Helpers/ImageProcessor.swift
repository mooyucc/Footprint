//
//  ImageProcessor.swift
//  Footprint
//
//  Created by GPT-5 Codex on 2025/11/08.
//

import UIKit
import ImageIO

struct ImageProcessor {

    /// 将原始图片数据按指定最大像素尺寸进行降采样，并返回压缩后的 JPEG 数据
    /// - Parameters:
    ///   - data: 原始图片数据
    ///   - maxDimension: 最大像素尺寸（会作用于长边）
    ///   - compressionQuality: JPEG 压缩质量（默认 0.85）
    /// - Returns: 处理后的 JPEG 数据；如果处理失败则返回原始数据
    static func downsample(data: Data, maxDimension: CGFloat, compressionQuality: CGFloat = 0.85) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: compressionQuality)
    }

    /// 生成较小尺寸的缩略图数据
    /// - Parameters:
    ///   - data: 原始图片数据
    ///   - maxDimension: 最大像素尺寸（默认 256）
    ///   - compressionQuality: JPEG 压缩质量（默认 0.8）
    /// - Returns: 缩略图 JPEG 数据
    static func thumbnail(data: Data, maxDimension: CGFloat = 256, compressionQuality: CGFloat = 0.8) -> Data? {
        downsample(data: data, maxDimension: maxDimension, compressionQuality: compressionQuality)
    }

    /// 针对一张图片同时生成适合展示的主图和缩略图
    /// - Parameters:
    ///   - data: 原始图片数据
    ///   - maxDimension: 主图最大像素尺寸（默认 2048）
    ///   - thumbnailDimension: 缩略图最大像素尺寸（默认 320）
    /// - Returns: (主图数据, 缩略图数据)
    static func process(data: Data, maxDimension: CGFloat = 2048, thumbnailDimension: CGFloat = 320) -> (Data, Data) {
        let processed = downsample(data: data, maxDimension: maxDimension) ?? data
        let thumbnail = thumbnail(data: data, maxDimension: thumbnailDimension) ?? processed
        return (processed, thumbnail)
    }

    /// 从封面取氛围光主色：中心区域采样，偏向高饱和像素，再推高饱和度/亮度
    static func dominantColor(from image: UIImage) -> UIColor? {
        guard let sample = makeSampleBitmap(from: image, maxSide: 48) else { return nil }
        let width = sample.width
        let height = sample.height
        guard width > 0, height > 0, let data = sample.dataProvider?.data else { return nil }
        guard let ptr = CFDataGetBytePtr(data) else { return nil }

        let bytesPerPixel = max(sample.bitsPerPixel / 8, 4)
        let bytesPerRow = sample.bytesPerRow

        // 只看中心约 60%，减少天空/黑边干扰
        let x0 = width / 5
        let y0 = height / 5
        let x1 = width - x0
        let y1 = height - y0

        var bestSat: CGFloat = -1
        var bestR: CGFloat = 0
        var bestG: CGFloat = 0
        var bestB: CGFloat = 0

        var weightSum: CGFloat = 0
        var accR: CGFloat = 0
        var accG: CGFloat = 0
        var accB: CGFloat = 0

        for y in y0..<y1 {
            for x in x0..<x1 {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = CGFloat(ptr[offset]) / 255
                let g = CGFloat(ptr[offset + 1]) / 255
                let b = CGFloat(ptr[offset + 2]) / 255

                var h: CGFloat = 0
                var s: CGFloat = 0
                var v: CGFloat = 0
                UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: nil)

                // 过暗/过灰像素权重极低
                guard v > 0.12, s > 0.08 else { continue }

                let weight = s * s * v
                weightSum += weight
                accR += r * weight
                accG += g * weight
                accB += b * weight

                if s * v > bestSat {
                    bestSat = s * v
                    bestR = r
                    bestG = g
                    bestB = b
                }
            }
        }

        let raw: UIColor
        if weightSum > 0.001 {
            // 70% 饱和加权平均 + 30% 最艳像素，避免整图灰化
            let avgR = accR / weightSum
            let avgG = accG / weightSum
            let avgB = accB / weightSum
            raw = UIColor(
                red: avgR * 0.7 + bestR * 0.3,
                green: avgG * 0.7 + bestG * 0.3,
                blue: avgB * 0.7 + bestB * 0.3,
                alpha: 1
            )
        } else if bestSat >= 0 {
            raw = UIColor(red: bestR, green: bestG, blue: bestB, alpha: 1)
        } else {
            return nil
        }

        return boostForAmbientGlow(raw)
    }

    /// 氛围光专用：抬饱和、保亮度，暗色底上更醒目
    private static func boostForAmbientGlow(_ color: UIColor) -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        let boostedS = min(1, max(s * 1.65, 0.55))
        let boostedB = min(1, max(b * 1.25, 0.55))
        return UIColor(hue: h, saturation: boostedS, brightness: boostedB, alpha: 1)
    }

    private static func makeSampleBitmap(from image: UIImage, maxSide: Int) -> CGImage? {
        let srcW = max(image.size.width * image.scale, 1)
        let srcH = max(image.size.height * image.scale, 1)
        let scale = min(CGFloat(maxSide) / srcW, CGFloat(maxSide) / srcH, 1)
        let w = max(Int((srcW * scale).rounded()), 1)
        let h = max(Int((srcH * scale).rounded()), 1)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .medium
        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        UIGraphicsPopContext()
        return ctx.makeImage()
    }
}
