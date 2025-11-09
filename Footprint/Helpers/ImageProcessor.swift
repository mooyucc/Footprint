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
}


