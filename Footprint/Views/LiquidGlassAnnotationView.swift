import MapKit
import SwiftUI

final class LiquidGlassAnnotationView: MKAnnotationView {

    static let reuseID = "LiquidGlassAnnotationView"

    private let bubbleView = UIView()
    private let glowLayer = CALayer()
    private let gradientLayer = CAGradientLayer()

    override var annotation: MKAnnotation? {
        willSet {
            configure(for: newValue)
        }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 26, height: 26)
        centerOffset = CGPoint(x: 0, y: -13)
        canShowCallout = true

        bubbleView.frame = bounds
        bubbleView.layer.cornerRadius = bounds.width / 2
        bubbleView.layer.masksToBounds = true
        bubbleView.alpha = 0.92

        // 渐变层
        gradientLayer.frame = bubbleView.bounds
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = bubbleView.layer.cornerRadius
        bubbleView.layer.addSublayer(gradientLayer)

        // 发光层
        glowLayer.frame = bubbleView.bounds
        glowLayer.cornerRadius = bubbleView.layer.cornerRadius
        glowLayer.shadowOffset = .zero
        glowLayer.shadowOpacity = 0.7
        glowLayer.shadowRadius = 6
        bubbleView.layer.addSublayer(glowLayer)

        addSubview(bubbleView)
    }

    private func configure(for annotation: MKAnnotation?) {
        let name = (annotation?.title ?? nil) ?? ""

        // 简单根据名称关键字判断国内/国外（后续可替换为坐标/国家判断）
        let isForeign = name.contains("日本") || name.contains("新加坡") || name.contains("巴黎") || name.contains("美国")

        let startColor: UIColor
        let endColor: UIColor

        if isForeign {
            startColor = UIColor.systemTeal
            endColor = UIColor.systemBlue
        } else {
            startColor = UIColor.systemPink
            endColor = UIColor.systemOrange
        }

        // 设置渐变背景颜色
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]

        // 发光效果
        glowLayer.shadowColor = startColor.cgColor
        glowLayer.shadowOpacity = 0.6
        glowLayer.shadowRadius = 8
    }
}


