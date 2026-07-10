//
//  ShareImageUtilities.swift
//  Footprint
//
//  分享图水印等后处理。
//

import UIKit

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
}
