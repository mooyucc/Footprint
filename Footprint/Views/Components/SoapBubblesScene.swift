//
//  SoapBubblesScene.swift
//  Footprint
//
//  吹出许多肥皂泡泡的动画场景
//  从指定位置吹出多个肥皂泡泡，泡泡会飘向屏幕各处
//

import SwiftUI
import SpriteKit

/// 肥皂泡泡节点
class SoapBubbleNode: SKNode {
    private var bubbleSprite: SKSpriteNode!
    private var shimmerNode: SKSpriteNode!
    private var isDarkMapStyle: Bool
    
    init(size: CGFloat, color: UIColor, isDarkMapStyle: Bool = false) {
        self.isDarkMapStyle = isDarkMapStyle
        super.init()
        
        // 创建泡泡纹理（带渐变和光泽效果）
        let texture = createBubbleTexture(size: size, color: color, isDarkMapStyle: isDarkMapStyle)
        bubbleSprite = SKSpriteNode(texture: texture)
        bubbleSprite.size = CGSize(width: size, height: size)
        addChild(bubbleSprite)
        
        // 添加光泽闪烁效果
        let shimmerTexture = createShimmerTexture(size: size)
        shimmerNode = SKSpriteNode(texture: shimmerTexture)
        shimmerNode.size = CGSize(width: size * 1.2, height: size * 1.2)
        shimmerNode.alpha = 0.3
        addChild(shimmerNode)
        
        // 光泽动画
        let shimmerAction = SKAction.sequence([
            SKAction.moveBy(x: size * 0.6, y: 0, duration: 1.5),
            SKAction.moveBy(x: -size * 1.2, y: 0, duration: 0),
            SKAction.moveBy(x: size * 0.6, y: 0, duration: 1.5)
        ])
        shimmerNode.run(SKAction.repeatForever(shimmerAction))
        
        // 轻微旋转动画
        let rotateAction = SKAction.rotate(byAngle: .pi * 2, duration: 8)
        bubbleSprite.run(SKAction.repeatForever(rotateAction))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 创建泡泡纹理（模拟肥皂泡薄膜干涉彩虹效果）
    private func createBubbleTexture(size: CGFloat, color: UIColor, isDarkMapStyle: Bool) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            
            // 设置透明背景
            context.cgContext.clear(rect)
            
            // 根据地图样式调整透明度参数
            let baseAlpha: CGFloat = isDarkMapStyle ? 0.25 : 0.35
            let highlightAlpha: CGFloat = isDarkMapStyle ? 0.5 : 0.7
            
            // 创建圆形裁剪路径
            let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            context.cgContext.addPath(circlePath.cgPath)
            context.cgContext.clip()
            
            // 生成薄膜干涉彩虹色（基于HSL色彩空间，模拟肥皂泡的彩虹效果）
            // 肥皂泡的薄膜干涉会产生从红色到紫色的彩虹色带
            let rainbowColors = generateRainbowColors(baseColor: color, alpha: baseAlpha)
            
            // 添加随机偏移，让每个泡泡的彩虹色分布略有不同（模拟真实的薄膜厚度变化）
            let randomOffset = CGFloat.random(in: -0.1...0.1) // 随机偏移，让颜色分布更自然
            
            // 绘制多层径向渐变，模拟薄膜干涉的彩虹色带
            // 从中心向外，颜色逐渐变化，模拟不同厚度的薄膜干涉
            let centerX = size * 0.5 + randomOffset * size * 0.1
            let centerY = size * 0.5 + randomOffset * size * 0.1
            let maxRadius = size * 0.5
            
            // 第一层：中心区域（较厚的薄膜，偏红/橙/黄）
            let innerGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    rainbowColors.red.withAlphaComponent(baseAlpha * 0.8).cgColor,
                    rainbowColors.orange.withAlphaComponent(baseAlpha * 0.65).cgColor,
                    rainbowColors.yellow.withAlphaComponent(baseAlpha * 0.5).cgColor,
                    rainbowColors.green.withAlphaComponent(baseAlpha * 0.35).cgColor
                ] as CFArray,
                locations: [0.0, 0.33, 0.66, 1.0]
            )!
            context.cgContext.drawRadialGradient(
                innerGradient,
                startCenter: CGPoint(x: centerX * 0.7, y: centerY * 0.7),
                startRadius: 0,
                endCenter: CGPoint(x: centerX, y: centerY),
                endRadius: maxRadius * 0.45,
                options: []
            )
            
            // 第二层：中间区域（中等厚度，偏青/蓝）
            let midGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    rainbowColors.cyan.withAlphaComponent(baseAlpha * 0.5).cgColor,
                    rainbowColors.blue.withAlphaComponent(baseAlpha * 0.4).cgColor,
                    rainbowColors.purple.withAlphaComponent(baseAlpha * 0.3).cgColor
                ] as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            context.cgContext.drawRadialGradient(
                midGradient,
                startCenter: CGPoint(x: centerX * 0.8, y: centerY * 0.8),
                startRadius: maxRadius * 0.35,
                endCenter: CGPoint(x: centerX, y: centerY),
                endRadius: maxRadius * 0.75,
                options: []
            )
            
            // 第三层：边缘区域（较薄的薄膜，偏紫/粉，逐渐透明）
            let outerGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    rainbowColors.purple.withAlphaComponent(baseAlpha * 0.4).cgColor,
                    rainbowColors.pink.withAlphaComponent(baseAlpha * 0.3).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            context.cgContext.drawRadialGradient(
                outerGradient,
                startCenter: CGPoint(x: centerX * 0.9, y: centerY * 0.9),
                startRadius: maxRadius * 0.65,
                endCenter: CGPoint(x: centerX, y: centerY),
                endRadius: maxRadius,
                options: []
            )
            
            // 绘制柔和的彩虹色边框（模拟薄膜边缘的干涉条纹）
            // 真实的肥皂泡边缘有薄膜干涉产生的彩色边缘，但应该更柔和、更微妙
            let borderPath = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            
            // 根据泡泡大小和地图样式调整边框粗细和透明度
            let borderWidth: CGFloat = size < 30 ? 1.0 : 1.2  // 小泡泡用更细的边框
            let borderAlpha: CGFloat = isDarkMapStyle ? 0.4 : 0.5  // 降低透明度，更柔和
            
            // 使用边缘区域的主要颜色（紫/粉/青）作为边框色，更自然
            // 根据基础颜色动态选择边框色，让每个泡泡的边框略有不同
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
                // 基于基础色相选择边框色（偏向边缘的彩虹色：青、蓝、紫）
                let borderHue = (hue + 0.5).truncatingRemainder(dividingBy: 1.0)  // 选择互补色相区域
                let borderColor = UIColor(
                    hue: borderHue,
                    saturation: min(saturation * 0.8, 1.0),
                    brightness: min(brightness * 1.1, 1.0),
                    alpha: borderAlpha
                )
                context.cgContext.setLineWidth(borderWidth)
                context.cgContext.setStrokeColor(borderColor.cgColor)
            } else {
                // 回退到使用彩虹色中的青色/蓝色
                context.cgContext.setLineWidth(borderWidth)
                context.cgContext.setStrokeColor(rainbowColors.cyan.withAlphaComponent(borderAlpha).cgColor)
            }
            
            context.cgContext.addPath(borderPath.cgPath)
            context.cgContext.strokePath()
            
            // 浅色地图上添加外环阴影以提高可见性（更柔和的阴影）
            if !isDarkMapStyle {
                let shadowPath = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
                context.cgContext.setShadow(
                    offset: CGSize(width: 0, height: 1),
                    blur: 2,  // 减小模糊半径，更柔和
                    color: UIColor.black.withAlphaComponent(0.15).cgColor  // 降低阴影透明度
                )
                context.cgContext.addPath(shadowPath.cgPath)
                context.cgContext.strokePath()
                context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            }
            
            // 绘制高光（模拟光线反射）
            let highlightPath = UIBezierPath(ovalIn: CGRect(
                x: size * 0.2,
                y: size * 0.2,
                width: size * 0.3,
                height: size * 0.3
            ))
            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(highlightAlpha).cgColor)
            context.cgContext.addPath(highlightPath.cgPath)
            context.cgContext.fillPath()
        }
        return SKTexture(image: image)
    }
    
    /// 生成薄膜干涉彩虹色（模拟肥皂泡的彩虹效果）
    private func generateRainbowColors(baseColor: UIColor, alpha: CGFloat) -> (red: UIColor, orange: UIColor, yellow: UIColor, green: UIColor, cyan: UIColor, blue: UIColor, purple: UIColor, pink: UIColor) {
        // 基于HSL色彩空间生成彩虹色
        // 肥皂泡的薄膜干涉会产生从红色到紫色的连续光谱
        
        // 提取基础色的色相，作为彩虹色的起点
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var baseAlpha: CGFloat = 0
        
        if baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &baseAlpha) {
            // 基于基础色相生成彩虹色变体
            // 薄膜干涉的彩虹色通常从红色开始，经过橙、黄、绿、青、蓝、紫
            let rainbowHues: [CGFloat] = [
                hue,                           // 保持基础色
                (hue + 0.05).truncatingRemainder(dividingBy: 1.0),  // 橙
                (hue + 0.1).truncatingRemainder(dividingBy: 1.0),   // 黄
                (hue + 0.3).truncatingRemainder(dividingBy: 1.0),   // 绿
                (hue + 0.45).truncatingRemainder(dividingBy: 1.0),  // 青
                (hue + 0.6).truncatingRemainder(dividingBy: 1.0),   // 蓝
                (hue + 0.75).truncatingRemainder(dividingBy: 1.0),  // 紫
                (hue + 0.9).truncatingRemainder(dividingBy: 1.0)    // 粉
            ]
            
            return (
                red: UIColor(hue: rainbowHues[0], saturation: min(saturation * 1.2, 1.0), brightness: min(brightness * 1.1, 1.0), alpha: alpha),
                orange: UIColor(hue: rainbowHues[1], saturation: min(saturation * 1.1, 1.0), brightness: min(brightness * 1.15, 1.0), alpha: alpha),
                yellow: UIColor(hue: rainbowHues[2], saturation: min(saturation * 0.9, 1.0), brightness: min(brightness * 1.2, 1.0), alpha: alpha),
                green: UIColor(hue: rainbowHues[3], saturation: min(saturation * 1.0, 1.0), brightness: min(brightness * 0.95, 1.0), alpha: alpha),
                cyan: UIColor(hue: rainbowHues[4], saturation: min(saturation * 1.1, 1.0), brightness: min(brightness * 1.05, 1.0), alpha: alpha),
                blue: UIColor(hue: rainbowHues[5], saturation: min(saturation * 1.2, 1.0), brightness: min(brightness * 0.9, 1.0), alpha: alpha),
                purple: UIColor(hue: rainbowHues[6], saturation: min(saturation * 1.1, 1.0), brightness: min(brightness * 0.85, 1.0), alpha: alpha),
                pink: UIColor(hue: rainbowHues[7], saturation: min(saturation * 0.95, 1.0), brightness: min(brightness * 1.0, 1.0), alpha: alpha)
            )
        } else {
            // 默认彩虹色（如果无法提取HSL值）
            return (
                red: UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: alpha),
                orange: UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: alpha),
                yellow: UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: alpha),
                green: UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: alpha),
                cyan: UIColor(red: 0.2, green: 0.8, blue: 0.9, alpha: alpha),
                blue: UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: alpha),
                purple: UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: alpha),
                pink: UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: alpha)
            )
        }
    }
    
    /// 创建光泽纹理（模拟光线在肥皂泡表面的反射和折射）
    private func createShimmerTexture(size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            
            // 设置透明背景
            context.cgContext.clear(rect)
            
            // 创建圆形裁剪路径，确保光泽也是圆形的
            let circlePath = UIBezierPath(ovalIn: rect)
            context.cgContext.addPath(circlePath.cgPath)
            context.cgContext.clip()
            
            // 绘制彩虹色光泽（模拟光线在薄膜表面的干涉）
            // 使用轻微的色彩变化，模拟薄膜干涉产生的彩虹光泽
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.clear.cgColor,
                    UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.4).cgColor,  // 淡蓝白
                    UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 0.5).cgColor,  // 淡黄白
                    UIColor(red: 0.95, green: 0.9, blue: 1.0, alpha: 0.4).cgColor,  // 淡紫白
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 0.3, 0.5, 0.7, 1.0]
            )!
            
            // 水平渐变（模拟光线从左到右的反射）
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size * 0.5),
                end: CGPoint(x: size, y: size * 0.5),
                options: []
            )
            
            // 添加垂直方向的轻微渐变，增强立体感
            let verticalGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.clear.cgColor,
                    UIColor.white.withAlphaComponent(0.2).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            
            context.cgContext.drawLinearGradient(
                verticalGradient,
                start: CGPoint(x: size * 0.5, y: 0),
                end: CGPoint(x: size * 0.5, y: size),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        return SKTexture(image: image)
    }
}

/// 吹出肥皂泡泡的场景
class SoapBubblesScene: SKScene {
    
    // MARK: - 属性
    
    /// 是否为深色地图样式
    var isDarkMapStyle: Bool = false
    
    /// 播放音效的回调闭包（带索引，用于播放不同音效）
    var onPlaySound: ((Int) -> Void)?
    
    // MARK: - 颜色系统
    
    /// 获取当前主题色
    private var baseColor: UIColor {
        UIColor(BrandColorManager.shared.currentBrandColor)
    }
    
    /// 生成泡泡颜色变体（基于薄膜干涉彩虹色）
    private func generateBubbleColors() -> [UIColor] {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            // 默认彩虹色：模拟肥皂泡的薄膜干涉效果
            if isDarkMapStyle {
                return [
                    UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.3),      // 红
                    UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.25),     // 橙
                    UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 0.25),      // 绿
                    UIColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 0.25),      // 青
                    UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.25),     // 蓝
                    UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 0.2),       // 紫
                ]
            } else {
                return [
                    UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.5),        // 红
                    UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.45),       // 橙
                    UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.45),       // 绿
                    UIColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 0.45),       // 青
                    UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.45),      // 蓝
                    UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.4),       // 紫
                ]
            }
        }
        
        // 根据地图样式调整颜色参数
        let saturationMultiplier: CGFloat = isDarkMapStyle ? 0.5 : 0.65  // 增加饱和度，让彩虹色更鲜艳
        let brightnessAdjustment: CGFloat = isDarkMapStyle ? 1.0 : 0.95
        let baseAlpha: CGFloat = isDarkMapStyle ? 0.3 : 0.45
        
        // 生成薄膜干涉彩虹色变体（覆盖整个光谱）
        // 每个泡泡会有不同的主要颜色，模拟不同厚度的薄膜干涉
        return [
            // 红色系（较厚的薄膜）
            UIColor(hue: hue, saturation: min(saturation * saturationMultiplier * 1.2, 1.0), brightness: brightness * brightnessAdjustment * 1.1, alpha: baseAlpha),
            // 橙色系
            UIColor(hue: (hue + 0.05).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * saturationMultiplier * 1.1, 1.0), 
                   brightness: brightness * brightnessAdjustment * 1.15, 
                   alpha: baseAlpha * 0.95),
            // 黄色系
            UIColor(hue: (hue + 0.1).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * saturationMultiplier * 0.9, 1.0), 
                   brightness: brightness * brightnessAdjustment * 1.2, 
                   alpha: baseAlpha * 0.9),
            // 绿色系（中等厚度）
            UIColor(hue: (hue + 0.3).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * saturationMultiplier * 1.0, 1.0), 
                   brightness: brightness * brightnessAdjustment * 0.95, 
                   alpha: baseAlpha),
            // 青色系
            UIColor(hue: (hue + 0.45).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * saturationMultiplier * 1.1, 1.0), 
                   brightness: brightness * brightnessAdjustment * 1.05, 
                   alpha: baseAlpha * 0.95),
            // 蓝色系（较薄的薄膜）
            UIColor(hue: (hue + 0.6).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * saturationMultiplier * 1.2, 1.0), 
                   brightness: brightness * brightnessAdjustment * 0.9, 
                   alpha: baseAlpha * 0.9),
            // 紫色系
            UIColor(hue: (hue + 0.75).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * saturationMultiplier * 1.1, 1.0), 
                   brightness: brightness * brightnessAdjustment * 0.85, 
                   alpha: baseAlpha * 0.85),
            // 粉色系
            UIColor(hue: (hue + 0.9).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * saturationMultiplier * 0.95, 1.0), 
                   brightness: brightness * brightnessAdjustment * 1.0, 
                   alpha: baseAlpha * 0.9),
        ]
    }
    
    // MARK: - 吹出泡泡动画
    
    /// 从指定位置吹出肥皂泡泡
    /// - Parameters:
    ///   - position: 起始位置（屏幕坐标，左上角为原点）
    ///   - direction: 吹出方向（角度，0度为向右，90度为向上）
    ///   - spreadAngle: 扩散角度范围（弧度）
    func blowBubbles(from position: CGPoint, direction: CGFloat = .pi / 2, spreadAngle: CGFloat = .pi / 3) {
        // 清除之前的泡泡
        removeAllChildren()
        
        // 转换坐标系统：SpriteKit 的坐标原点在左下角
        let spriteKitPosition = CGPoint(
            x: position.x,
            y: size.height - position.y
        )
        
        let bubbleColors = generateBubbleColors()
        let bubbleCount = 15 // 泡泡数量
        
        // 创建多个泡泡
        for i in 0..<bubbleCount {
            let delay = Double(i) * 0.05 // 错开创建时间，营造连续吹出的效果
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.createBubble(
                    at: spriteKitPosition,
                    direction: direction,
                    spreadAngle: spreadAngle,
                    colors: bubbleColors,
                    index: i
                )
                
                // 在更多泡泡出现时播放音效，营造Q弹感
                // 策略：每2-3个泡泡播放一次音效，使用不同音效变体
                // 让音效更有节奏感和层次感
                
                // 每个泡泡都播放音效，但使用不同延迟和音效类型
                let soundDelay = Double.random(in: 0.01...0.02) // 轻微随机延迟，更自然
                
                // 根据泡泡索引选择音效类型（循环使用3种音效变体）
                let soundType = i % 3
                
                DispatchQueue.main.asyncAfter(deadline: .now() + soundDelay) {
                    self.onPlaySound?(soundType)
                }
            }
        }
    }
    
    /// 创建单个泡泡
    private func createBubble(
        at position: CGPoint,
        direction: CGFloat,
        spreadAngle: CGFloat,
        colors: [UIColor],
        index: Int
    ) {
        // 随机选择颜色
        let color = colors.randomElement() ?? baseColor
        
        // 随机大小（20-40点）
        let size = CGFloat.random(in: 20...40)
        
        // 创建泡泡节点（传递地图样式信息）
        let bubble = SoapBubbleNode(size: size, color: color, isDarkMapStyle: isDarkMapStyle)
        bubble.position = position
        addChild(bubble)
        
        // 计算目标位置（随机方向，但主要朝向指定方向）
        let angleVariation = CGFloat.random(in: -spreadAngle/2...spreadAngle/2)
        let finalDirection = direction + angleVariation
        
        // 随机距离（200-400点）
        let distance = CGFloat.random(in: 200...400)
        
        // 如果是全方向扩散（360度），不使用额外的水平偏移，让扩散更自然
        // 否则添加随机水平偏移，避免所有泡泡都朝一个方向
        let horizontalOffset: CGFloat = spreadAngle >= 2 * .pi ? 0 : CGFloat.random(in: -150...150)
        
        let targetX = position.x + cos(finalDirection) * distance + horizontalOffset
        // 如果是全方向扩散，Y方向也完全随机；否则主要向上
        let yOffset = spreadAngle >= 2 * .pi ? CGFloat.random(in: -150...150) : CGFloat.random(in: 50...150)
        let targetY = position.y + sin(finalDirection) * distance + yOffset
        
        let targetPosition = CGPoint(x: targetX, y: targetY)
        
        // 上升动画（泡泡会上升并飘动）
        let moveAction = SKAction.move(to: targetPosition, duration: Double.random(in: 2.5...4.0))
        
        // 轻微的水平摆动（模拟空气流动）
        let horizontalSway = CGFloat.random(in: -30...30)
        let swayAction = SKAction.sequence([
            SKAction.moveBy(x: horizontalSway, y: 0, duration: 1.0),
            SKAction.moveBy(x: -horizontalSway * 2, y: 0, duration: 1.0),
            SKAction.moveBy(x: horizontalSway, y: 0, duration: 1.0)
        ])
        
        // 组合动画
        let combinedAction = SKAction.group([
            moveAction,
            SKAction.repeat(swayAction, count: 3)
        ])
        
        // 透明度变化（逐渐消失）
        let fadeAction = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeAlpha(to: 0.7, duration: 1.0),
            SKAction.fadeAlpha(to: 0.3, duration: 1.0),
            SKAction.fadeAlpha(to: 0, duration: 0.5)
        ])
        
        // 轻微缩放（模拟泡泡在空气中变化）
        let scaleVariation = CGFloat.random(in: 0.9...1.1)
        let scaleAction = SKAction.sequence([
            SKAction.scale(to: scaleVariation, duration: 1.0),
            SKAction.scale(to: 1.0, duration: 1.0),
            SKAction.scale(to: scaleVariation, duration: 1.0)
        ])
        
        // 执行所有动画
        bubble.run(SKAction.group([
            combinedAction,
            fadeAction,
            SKAction.repeat(scaleAction, count: 2)
        ])) {
            // 动画完成后移除
            bubble.removeFromParent()
        }
    }
}

/// SwiftUI 包装视图
struct SoapBubblesView: UIViewRepresentable {
    let position: CGPoint
    let direction: CGFloat
    let spreadAngle: CGFloat
    let isDarkMapStyle: Bool
    let onPlaySound: ((Int) -> Void)?
    let onComplete: () -> Void
    
    let id: UUID
    
    init(position: CGPoint, direction: CGFloat = .pi / 2, spreadAngle: CGFloat = .pi / 3, isDarkMapStyle: Bool = false, onPlaySound: ((Int) -> Void)? = nil, onComplete: @escaping () -> Void) {
        self.position = position
        self.direction = direction
        self.spreadAngle = spreadAngle
        self.isDarkMapStyle = isDarkMapStyle
        self.onPlaySound = onPlaySound
        self.onComplete = onComplete
        self.id = UUID()
    }
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        
        let scene = SoapBubblesScene()
        scene.isDarkMapStyle = isDarkMapStyle
        scene.onPlaySound = onPlaySound
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.anchorPoint = CGPoint(x: 0, y: 0)
        scene.size = CGSize(width: 1000, height: 1000)
        
        view.presentScene(scene)
        
        // 等待视图布局完成后再触发动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let viewSize = view.bounds.size
            if viewSize.width > 0 && viewSize.height > 0 {
                scene.size = viewSize
            } else {
                scene.size = UIScreen.main.bounds.size
            }
            
            // 触发吹泡泡动画
            scene.blowBubbles(from: position, direction: direction, spreadAngle: spreadAngle)
            
            // 动画完成后回调（最后一个泡泡大约4秒后消失）
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                onComplete()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        if let scene = uiView.scene as? SoapBubblesScene {
            let newSize = uiView.bounds.size
            if newSize.width > 0 && newSize.height > 0 {
                scene.size = newSize
            }
        }
    }
}

