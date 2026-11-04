//
//  MapView+PhotoImport.swift
//  Footprint
//
//  从 MapView.swift 拆分（编译加速）
//

import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import Combine
import AudioToolbox
import UIKit
import PhotosUI
import Photos
import ImageIO
import Contacts

extension MapView {
    func handlePhotoImportSelection(_ items: [PhotosPickerItem]) {
        Task {
            print("📸 开始处理 \(items.count) 张图片导入...")
            
            var loaded: [(item: PhotosPickerItem, data: Data, processed: (Data, Data))] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    print("⚠️ 跳过无法加载的图片")
                    continue
                }
                loaded.append((item, data, ImageProcessor.process(data: data)))
                print("✅ 图片数据加载成功，大小: \(data.count / 1024) KB")
            }
            
            guard !loaded.isEmpty else {
                print("❌ 图片加载失败：所选图片均无法读取")
                await MainActor.run {
                    photoImportError = .failedToLoad
                    showingQuickCheckIn = false
                    pendingPhotoPrefill = nil
                    photoImportItems = []
                    showingPhotoImportPicker = false
                }
                return
            }
            
            let resolved = resolveImportMetadata(
                items: loaded.map(\.item),
                loadedData: loaded.map(\.data)
            )
            let photoDatas = loaded.map { $0.processed.0 }
            let thumbnailDatas = loaded.map { $0.processed.1 }
            
            await MainActor.run {
                photoImportItems = []
                showingPhotoImportPicker = false
                
                if let wgsCoordinate = resolved.coordinate {
                    if let gpsIndex = resolved.gpsSourceIndex {
                        print("📍 使用第 \(gpsIndex + 1) 张照片的 GPS 信息建立地点")
                    }
                    
                    // 📍 iPhone 拍摄的照片 GPS 信息是 WGS84 坐标系
                    // 在中国境内需要转换为 GCJ02（火星坐标）才能准确定位
                    let isInChina = !CoordinateConverter.isOutOfChina(wgsCoordinate)
                    let finalCoordinate: CLLocationCoordinate2D
                    
                    if isInChina {
                        finalCoordinate = CoordinateConverter.wgs84ToGCJ02(wgsCoordinate)
                        print("📍 坐标转换（中国境内）:")
                        print("   WGS84: (\(String(format: "%.6f", wgsCoordinate.latitude)), \(String(format: "%.6f", wgsCoordinate.longitude)))")
                        print("   GCJ02: (\(String(format: "%.6f", finalCoordinate.latitude)), \(String(format: "%.6f", finalCoordinate.longitude)))")
                    } else {
                        finalCoordinate = wgsCoordinate
                        print("📍 坐标（境外，无需转换）: (\(String(format: "%.6f", finalCoordinate.latitude)), \(String(format: "%.6f", finalCoordinate.longitude)))")
                    }
                    
                    if let captureDate = resolved.visitDate {
                        print("📅 拍摄日期: \(captureDate)")
                    } else {
                        print("⚠️ 未找到拍摄日期")
                    }
                    
                    pendingPhotoPrefill = PendingPhotoPrefill(
                        visitDate: resolved.visitDate,
                        photoDatas: photoDatas,
                        photoThumbnailDatas: thumbnailDatas
                    )
                    photoImportError = nil
                    isGeocodingLocation = true
                    showingQuickCheckIn = true
                    addDestinationPrefill = nil
                    
                    print("🔄 开始逆地理编码...")
                    reverseGeocodeLocation(coordinate: finalCoordinate, forAddDestinationPrefill: true)
                } else {
                    print("⚠️ 所选图片均无 GPS，进入手动填写")
                    if let captureDate = resolved.visitDate {
                        print("📅 使用顺延得到的拍摄日期: \(captureDate)")
                    }
                    
                    pendingPhotoPrefill = nil
                    addDestinationPrefill = AddDestinationPrefill(
                        visitDate: resolved.visitDate,
                        photoDatas: photoDatas,
                        photoThumbnailDatas: thumbnailDatas
                    )
                    isGeocodingLocation = false
                    showingQuickCheckIn = true
                    photoImportError = nil
                }
            }
        }
    }
    
    /// 按选中顺序顺延解析 EXIF：GPS 决定地点；日期优先 GPS 源，否则取首张有日期的照片。
    func resolveImportMetadata(
        items: [PhotosPickerItem],
        loadedData: [Data]
    ) -> ResolvedPhotoImportMetadata {
        let metadatas = zip(items, loadedData).map { extractMetadata(for: $0.0, imageData: $0.1) }
        let gpsIndex = metadatas.firstIndex { $0.coordinate != nil }
        let visitDate: Date? = {
            if let index = gpsIndex, let date = metadatas[index].captureDate {
                return date
            }
            return metadatas.compactMap(\.captureDate).first
        }()
        
        return ResolvedPhotoImportMetadata(
            coordinate: gpsIndex.flatMap { metadatas[$0].coordinate },
            visitDate: visitDate,
            gpsSourceIndex: gpsIndex
        )
    }
    
    /// 从 EXIF GPS 字典解析 WGS84（与 CoreLocation / PHAsset 一致）；支持标量、NSNumber、度分秒数组及有理数分量。
    func coordinateFromEXIFGPSDictionary(_ gps: [CFString: Any]) -> CLLocationCoordinate2D? {
        guard let latRefRaw = gps[kCGImagePropertyGPSLatitudeRef],
              let lonRefRaw = gps[kCGImagePropertyGPSLongitudeRef] else { return nil }
        let latRef = String(describing: latRefRaw).uppercased()
        let lonRef = String(describing: lonRefRaw).uppercased()
        guard let latDeg = exifGPSDegrees(from: gps[kCGImagePropertyGPSLatitude]),
              let lonDeg = exifGPSDegrees(from: gps[kCGImagePropertyGPSLongitude]) else { return nil }
        let lat = (latRef == "S") ? -latDeg : latDeg
        let lon = (lonRef == "W") ? -lonDeg : lonDeg
        guard lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func exifGPSDegrees(from value: Any?) -> Double? {
        guard let value = value else { return nil }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let arr = value as? [Any], arr.count >= 3 {
            return exifRationalComponent(arr[0]) + exifRationalComponent(arr[1]) / 60.0 + exifRationalComponent(arr[2]) / 3600.0
        }
        if let arr = value as? NSArray, arr.count >= 3 {
            return exifRationalComponent(arr[0]) + exifRationalComponent(arr[1]) / 60.0 + exifRationalComponent(arr[2]) / 3600.0
        }
        return nil
    }
    
    func exifRationalComponent(_ value: Any?) -> Double {
        guard let value = value else { return 0 }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        if let dict = value as? NSDictionary,
           let num = dict["Numerator"] as? NSNumber,
           let den = dict["Denominator"] as? NSNumber,
           den.doubleValue != 0 {
            return num.doubleValue / den.doubleValue
        }
        return 0
    }
    
    func extractMetadata(for item: PhotosPickerItem, imageData: Data) -> PhotoMetadata {
        var coordinate: CLLocationCoordinate2D?
        var captureDate: Date?
        
        // 方法1：从 PHAsset 获取元数据（优先）
        if let identifier = item.itemIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = assets.firstObject {
                captureDate = asset.creationDate ?? asset.modificationDate
                if let location = asset.location {
                    coordinate = location.coordinate
                    print("✅ 从 PHAsset 获取坐标: (\(String(format: "%.6f", coordinate!.latitude)), \(String(format: "%.6f", coordinate!.longitude)))")
                } else {
                    print("⚠️ PHAsset 中未找到位置信息")
                }
                if captureDate != nil {
                    print("✅ 从 PHAsset 获取拍摄日期: \(captureDate!)")
                } else {
                    print("⚠️ PHAsset 中未找到拍摄日期")
                }
            } else {
                print("⚠️ 无法找到对应的 PHAsset")
            }
        }
        
        // 方法2：从图片 EXIF 数据获取元数据（备用）
        if coordinate == nil || captureDate == nil {
            if let source = CGImageSourceCreateWithData(imageData as CFData, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                
                // 提取 GPS（兼容 Double、NSNumber、度分秒数组；PHAsset 已为 WGS84）
                if coordinate == nil,
                   let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
                    if let coord = coordinateFromEXIFGPSDictionary(gps) {
                        coordinate = coord
                        print("✅ 从 EXIF GPS 获取坐标: (\(String(format: "%.6f", coord.latitude)), \(String(format: "%.6f", coord.longitude)))")
                    } else {
                        print("⚠️ EXIF 中未找到 GPS 信息")
                    }
                }
                
                // 提取拍摄日期
                if captureDate == nil {
                    if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
                       let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                        captureDate = parseExifDateString(dateString)
                        if captureDate != nil {
                            print("✅ 从 EXIF DateTimeOriginal 获取拍摄日期: \(captureDate!)")
                        }
                    }
                    if captureDate == nil,
                       let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                       let dateString = tiff[kCGImagePropertyTIFFDateTime] as? String {
                        captureDate = parseExifDateString(dateString)
                        if captureDate != nil {
                            print("✅ 从 TIFF DateTime 获取拍摄日期: \(captureDate!)")
                        }
                    }
                    if captureDate == nil {
                        print("⚠️ EXIF/TIFF 中未找到拍摄日期")
                    }
                }
            } else {
                print("⚠️ 无法读取图片 EXIF 数据")
            }
        }
        
        return PhotoMetadata(coordinate: coordinate, captureDate: captureDate)
    }
    
    func parseExifDateString(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let patterns = ["yyyy:MM:dd HH:mm:ss", "yyyy:MM:dd HH:mm:ssZ"]
        for pattern in patterns {
            formatter.dateFormat = pattern
            if pattern.hasSuffix("Z") {
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
            } else {
                formatter.timeZone = TimeZone.current
            }
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
    
    // 放大到聚合区域
}
