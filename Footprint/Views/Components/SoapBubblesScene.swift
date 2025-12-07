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
    
    /// 创建泡泡纹理
    private func createBubbleTexture(size: CGFloat, color: UIColor, isDarkMapStyle: Bool) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            
            // 设置透明背景
            context.cgContext.clear(rect)
            
            // 根据地图样式调整透明度参数（边框保持不变）
            let alphaValues: (high: CGFloat, mid: CGFloat, low: CGFloat)
            let highlightAlpha: CGFloat
            
            if isDarkMapStyle {
                // 深色地图：使用较低透明度，保持透明感
                alphaValues = (0.3, 0.15, 0.05)
                highlightAlpha = 0.4
            } else {
                // 浅色地图：增加透明度，提高可见性
                alphaValues = (0.5, 0.3, 0.15)  // 提高透明度
                highlightAlpha = 0.5  // 更明显的高光
            }
            
            // 创建圆形裁剪路径
            let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            context.cgContext.addPath(circlePath.cgPath)
            context.cgContext.clip()
            
            // 绘制径向渐变背景
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    color.withAlphaComponent(alphaValues.high).cgColor,
                    color.withAlphaComponent(alphaValues.mid).cgColor,
                    color.withAlphaComponent(alphaValues.low).cgColor
                ] as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size * 0.3, y: size * 0.3),
                startRadius: 0,
                endCenter: CGPoint(x: size * 0.5, y: size * 0.5),
                endRadius: size * 0.5,
                options: []
            )
            
            // 绘制边框（保持原有样式不变）
            let borderPath = UIBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            context.cgContext.setStrokeColor(color.withAlphaComponent(0.6).cgColor)
            context.cgContext.setLineWidth(1.5)
            context.cgContext.addPath(borderPath.cgPath)
            context.cgContext.strokePath()
            
            // 浅色地图上添加外环阴影以提高可见性
            if !isDarkMapStyle {
                let shadowPath = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
                context.cgContext.setShadow(
                    offset: CGSize(width: 0, height: 1),
                    blur: 3,
                    color: UIColor.black.withAlphaComponent(0.25).cgColor
                )
                context.cgContext.addPath(shadowPath.cgPath)
                context.cgContext.strokePath()
                context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            }
            
            // 绘制高光
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
    
    /// 创建光泽纹理
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
            
            // 绘制水平渐变光泽
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.clear.cgColor,
                    UIColor.white.withAlphaComponent(0.5).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 0.5, 1.0]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size * 0.5),
                end: CGPoint(x: size, y: size * 0.5),
                options: []
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
    
    /// 生成泡泡颜色变体
    private func generateBubbleColors() -> [UIColor] {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            // 默认颜色：浅色地图使用更深的颜色以提高可见性
            if isDarkMapStyle {
                return [
                    UIColor(red: 255/255, green: 120/255, blue: 100/255, alpha: 0.3),
                    UIColor(red: 255/255, green: 200/255, blue: 180/255, alpha: 0.25),
                    UIColor(red: 240/255, green: 180/255, blue: 200/255, alpha: 0.2),
                ]
            } else {
                return [
                    UIColor(red: 255/255, green: 100/255, blue: 80/255, alpha: 0.5),   // 更深的颜色，更高透明度
                    UIColor(red: 255/255, green: 160/255, blue: 140/255, alpha: 0.45),
                    UIColor(red: 240/255, green: 140/255, blue: 160/255, alpha: 0.4),
                ]
            }
        }
        
        // 根据地图样式调整颜色参数
        let saturationMultiplier: CGFloat = isDarkMapStyle ? 0.4 : 0.55  // 浅色地图增加饱和度
        let brightnessAdjustment: CGFloat = isDarkMapStyle ? 1.0 : 0.9  // 浅色地图稍微降低亮度以增加对比
        
        // 生成多个颜色变体
        return [
            UIColor(hue: hue, saturation: min(saturation * saturationMultiplier, 1.0), brightness: brightness * brightnessAdjustment, alpha: isDarkMapStyle ? 0.3 : 0.5),
            UIColor(hue: (hue + 0.05).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * (saturationMultiplier * 0.9), 1.0), 
                   brightness: brightness * brightnessAdjustment * 1.1, 
                   alpha: isDarkMapStyle ? 0.25 : 0.45),
            UIColor(hue: (hue - 0.05 + 1.0).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * (saturationMultiplier * 0.85), 1.0), 
                   brightness: brightness * brightnessAdjustment * 0.95, 
                   alpha: isDarkMapStyle ? 0.2 : 0.4),
            UIColor(hue: (hue + 0.1).truncatingRemainder(dividingBy: 1.0), 
                   saturation: min(saturation * (saturationMultiplier * 0.8), 1.0), 
                   brightness: brightness * brightnessAdjustment * 1.05, 
                   alpha: isDarkMapStyle ? 0.22 : 0.42),
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

