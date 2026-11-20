//
//  ShareImageUtilities.swift
//  Footprint
//
//  分享图水印、文案与相册保存。
//

import UIKit
import Photos

enum ShareImageUtilities {
    /// 免费版在分享图右下角添加轻量水印
    static func applyingWatermarkIfNeeded(_ image: UIImage?, shouldApply: Bool) -> UIImage? {
        guard shouldApply, let image else { return image }

        let scale = image.scale
        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)

            let padding: CGFloat = max(12, min(size.width, size.height) * 0.03)
            let fontSize = max(11, min(size.width, size.height) * 0.028)
            let text = "MooFootprint"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            let textSize = (text as NSString).size(withAttributes: attributes)
            let textOrigin = CGPoint(
                x: size.width - textSize.width - padding,
                y: size.height - textSize.height - padding
            )
            let bgRect = CGRect(
                x: textOrigin.x - 8,
                y: textOrigin.y - 4,
                width: textSize.width + 16,
                height: textSize.height + 8
            )

            let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 6)
            UIColor.black.withAlphaComponent(0.35).setFill()
            bgPath.fill()

            (text as NSString).draw(at: textOrigin, withAttributes: attributes)
        }
    }
    
    /// 图上副标题默认值：从备注抽一句；无备注则空（标题已单独用地点名）
    static func destinationOverlayCaption(for destination: TravelDestination, maxLength: Int = 30) -> String {
        let note = destination.notes
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return "" }
        return String(note.prefix(maxLength))
    }
    
    /// 多渠道通用短文案（系统分享 / 复制）
    static func destinationShareCaption(for destination: TravelDestination) -> String {
        let dateFormatter = LanguageManager.shared.localizedDateFormatter(dateStyle: .medium, timeStyle: .none)
        let dateText = dateFormatter.string(from: destination.visitDate)
        
        let locationParts = [destination.province, destination.country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let locationLine = locationParts.isEmpty
            ? destination.name
            : "\(destination.name) · \(locationParts.joined(separator: " · "))"
        
        var lines = [
            "📍 \(locationLine)",
            "🗓️ \(dateText)"
        ]
        
        let note = destination.notes
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            lines.append(String(note.prefix(80)))
        }
        
        lines.append("#MooFootprint")
        return lines.joined(separator: "\n")
    }
    
    /// 保存到系统相册（仅需写入权限）
    static func saveToPhotoLibrary(_ image: UIImage) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
