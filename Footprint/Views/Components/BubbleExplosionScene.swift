//
//  BubbleExplosionScene.swift
//  Footprint
//
//  回忆泡泡炸开粒子效果场景
//

import SwiftUI
import SpriteKit

/// 回忆泡泡炸开的粒子爆炸场景
/// 使用品牌色（红色和米色）创建多层次粒子效果，模拟真实肥皂泡泡炸开
class BubbleExplosionScene: SKScene {
    
    // MARK: - 颜色系统
    
    /// 获取当前主题色（从 BrandColorManager）
    private var baseColor: UIColor {
        UIColor(BrandColorManager.shared.currentBrandColor)
    }
    
    /// 根据主题色生成辅助色系（色轮上相邻的颜色）
    private func generateAccentColors(from baseColor: UIColor) -> [UIColor] {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            // 如果无法获取色相，返回默认的辅助色
            return [
                UIColor(red: 255/255, green: 120/255, blue: 100/255, alpha: 1.0),
                UIColor(red: 255/255, green: 100/255, blue: 130/255, alpha: 1.0),
                UIColor(red: 240/255, green: 90/255, blue: 120/255, alpha: 1.0),
            ]
        }
        
        // 在色轮上生成相邻颜色（向左右各偏移15-30度）
        let hueOffset1: CGFloat = 15.0 / 360.0  // 向橙色方向
        let hueOffset2: CGFloat = -15.0 / 360.0 // 向紫色方向
        let hueOffset3: CGFloat = 25.0 / 360.0   // 更向橙色
        
        return [
            // 向橙色偏移
            UIColor(hue: (hue + hueOffset1).truncatingRemainder(dividingBy: 1.0), 
                   saturation: saturation * 0.9, brightness: brightness, alpha: alpha),
            // 向紫色偏移
            UIColor(hue: (hue + hueOffset2 + 1.0).truncatingRemainder(dividingBy: 1.0), 
                   saturation: saturation * 0.95, brightness: brightness, alpha: alpha),
            // 更向橙色
            UIColor(hue: (hue + hueOffset3).truncatingRemainder(dividingBy: 1.0), 
                   saturation: saturation * 0.85, brightness: brightness * 1.05, alpha: alpha),
        ]
    }
    
    /// 根据主题色生成互补色（色轮上相对的颜色，180度）
    private func generateComplementaryColor(from baseColor: UIColor) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            // 如果无法获取色相，返回默认的互补色（青色，红色的互补色）
            return UIColor(red: 92/255, green: 247/255, blue: 255/255, alpha: 1.0)
        }
        
        // 互补色：色轮上180度相对的颜色
        let complementaryHue = (hue + 0.5).truncatingRemainder(dividingBy: 1.0)
        
        // 互补色可以稍微降低饱和度，避免过于强烈
        let adjustedSaturation = min(saturation * 0.8, 0.9)
        
        // 互补色可以稍微调整亮度，保持视觉平衡
        let adjustedBrightness = brightness * 0.9
        
        return UIColor(hue: complementaryHue, saturation: adjustedSaturation, brightness: adjustedBrightness, alpha: alpha)
    }
    
    /// 创建颜色序列（60%基础色，30%辅助色，10%对比色，并包含不同明度/饱和度的变体）
    private func createColorSequence() -> SKKeyframeSequence {
        let currentBaseColor = baseColor
        let accentColors = generateAccentColors(from: currentBaseColor)
        let complementaryColor = generateComplementaryColor(from: currentBaseColor)
        
        var colors: [UIColor] = []
        
        // 60% 基础色及其变体（6个）
        for _ in 0..<6 {
            colors.append(createColorVariant(baseColor: currentBaseColor))
        }
        
        // 30% 辅助色及其变体（3个）
        for _ in 0..<3 {
            let accentColor = accentColors.randomElement() ?? currentBaseColor
            colors.append(createColorVariant(baseColor: accentColor))
        }
        
        // 10% 对比色（互补色）及其变体（1个）
        colors.append(createColorVariant(baseColor: complementaryColor))
        
        // 创建关键帧序列，在粒子生命周期中随机变化
        let keyframeValues = colors.map { $0 }
        let times = (0..<colors.count).map { NSNumber(value: Double($0) / Double(max(colors.count - 1, 1))) }
        
        return SKKeyframeSequence(keyframeValues: keyframeValues, times: times)
    }
    
    /// 创建颜色变体（随机调整明度和饱和度）
    private func createColorVariant(baseColor: UIColor) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return baseColor
        }
        
        // 随机调整饱和度（0.6-1.0，保持颜色鲜艳但有一定变化）
        let adjustedSaturation = saturation * CGFloat.random(in: 0.6...1.0)
        
        // 随机调整明度（0.7-1.0，保持足够亮度）
        let adjustedBrightness = brightness * CGFloat.random(in: 0.7...1.0)
        
        return UIColor(hue: hue, saturation: adjustedSaturation, brightness: adjustedBrightness, alpha: alpha)
    }
    
    /// 创建高亮度颜色变体（用于高光粒子，更亮更鲜艳）
    private func createBrightColorVariant(baseColor: UIColor) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return baseColor
        }
        
        // 高光粒子：保持高饱和度，提高亮度
        let adjustedSaturation = min(saturation * 1.1, 1.0) // 稍微提高饱和度，但不超过1.0
        let adjustedBrightness = min(brightness * 1.2, 1.0)  // 提高亮度，但不超过1.0
        
        return UIColor(hue: hue, saturation: adjustedSaturation, brightness: adjustedBrightness, alpha: alpha)
    }
    
    /// 创建粒子纹理（圆形）
    private func createParticleTexture(size: CGSize, color: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // 绘制圆形粒子
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(ovalIn: rect)
            color.setFill()
            path.fill()
        }
        return SKTexture(image: image)
    }
    
    /// 创建爆炸效果
    /// - Parameter position: 爆炸位置（屏幕坐标，左上角为原点）
    func createExplosion(at position: CGPoint) {
        // 清除之前的粒子
        removeAllChildren()
        
        // 转换坐标系统：SpriteKit 的坐标原点在左下角，需要翻转 Y 轴
        let spriteKitPosition = CGPoint(
            x: position.x,
            y: size.height - position.y
        )
        
        print("💥 坐标转换: 屏幕坐标 \(position) -> SpriteKit坐标 \(spriteKitPosition), 场景大小: \(size)")
        
        // 创建多层粒子效果，模拟真实泡泡炸开
        // 第一层：主要粒子（红色系）- 快速向外扩散，使用随机颜色
        createMainParticles(at: spriteKitPosition)
        
        // 第二层：次要粒子（浅红色）- 中等速度，使用随机颜色
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.createSecondaryParticles(at: spriteKitPosition)
        }
        
        // 第三层：高光粒子（使用主题色的亮色变体）- 慢速，营造光泽感
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 使用主题色的高亮度变体作为高光
            let highlightColor = self.createBrightColorVariant(baseColor: self.baseColor)
            self.createHighlightParticles(at: spriteKitPosition, color: highlightColor)
        }
        
        // 第四层：小碎片粒子（深红色）- 快速消失，使用随机颜色
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.createFragmentParticles(at: spriteKitPosition)
        }
    }
    
    /// 创建主要粒子（快速向外扩散）
    private func createMainParticles(at position: CGPoint) {
        let emitter = SKEmitterNode()
        
        // 基础配置 - 关键：先设置高 birthRate，然后立即设为 0 来实现一次性发射
        emitter.particleBirthRate = 1000 // 先设置一个很高的值
        emitter.numParticlesToEmit = 100 // 增加粒子数量，更丰富
        emitter.particleLifetime = 0.9 // 存活时间
        emitter.particlePosition = position
        
        // 速度配置 - 快速向外扩散，模拟泡泡炸开的瞬间
        emitter.particleSpeed = 180
        emitter.particleSpeedRange = 120
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi // 360度发射
        
        // 重力效果 - 轻微向下，模拟真实物理
        emitter.particlePositionRange = CGVector(dx: 0, dy: 0)
        emitter.yAcceleration = -120
        
        // 颜色配置 - 使用颜色序列（70%基础色，30%辅助色）
        emitter.particleColor = baseColor
        emitter.particleColorBlendFactor = 1.0
        let colorSequence = createColorSequence()
        emitter.particleColorSequence = colorSequence
        
        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -1.0 // 逐渐变透明
        
        // 创建粒子纹理（使用基础色，实际颜色由 colorSequence 控制）
        let particleTexture = createParticleTexture(size: CGSize(width: 8, height: 8), color: baseColor)
        emitter.particleTexture = particleTexture
        
        // 立即生成所有粒子
        emitter.advanceSimulationTime(0.1) // 推进模拟时间，立即生成粒子
        emitter.particleBirthRate = 0 // 然后立即设为 0，停止生成新粒子
        
        // 大小配置
        emitter.particleSize = CGSize(width: 8, height: 8)
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.5 // 粒子大小在 0.5 到 1.5 之间变化
        emitter.particleScaleSpeed = -0.4 // 逐渐缩小
        
        // 旋转效果 - 增加动感
        emitter.particleRotation = 0
        emitter.particleRotationRange = 2 * .pi
        emitter.particleRotationSpeed = 3
        
        // 混合模式 - 叠加模式，让粒子发光
        emitter.particleBlendMode = .add
        
        // 添加到场景
        addChild(emitter)
        
        // 动画结束后移除
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.2),
            SKAction.removeFromParent()
        ]))
    }
    
    /// 创建次要粒子（中等速度）
    private func createSecondaryParticles(at position: CGPoint) {
        let emitter = SKEmitterNode()
        
        emitter.particleBirthRate = 800 // 先设置高值
        emitter.numParticlesToEmit = 80 // 增加数量
        emitter.particleLifetime = 1.1
        emitter.particlePosition = position
        
        // 中等速度，营造层次感
        emitter.particleSpeed = 140
        emitter.particleSpeedRange = 90
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi
        
        emitter.yAcceleration = -100
        
        // 颜色配置 - 使用颜色序列
        emitter.particleColor = baseColor
        emitter.particleColorBlendFactor = 1.0
        let colorSequence = createColorSequence()
        emitter.particleColorSequence = colorSequence
        
        emitter.particleAlpha = 0.9
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -0.8
        
        // 创建粒子纹理
        let particleTexture = createParticleTexture(size: CGSize(width: 6, height: 6), color: baseColor)
        emitter.particleTexture = particleTexture
        
        // 立即生成所有粒子
        emitter.advanceSimulationTime(0.1)
        emitter.particleBirthRate = 0
        
        emitter.particleSize = CGSize(width: 6, height: 6)
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.5 // 粒子大小变化范围
        emitter.particleScaleSpeed = -0.3
        
        // 添加旋转
        emitter.particleRotationSpeed = 2
        
        emitter.particleBlendMode = .alpha
        
        addChild(emitter)
        
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.3),
            SKAction.removeFromParent()
        ]))
    }
    
    /// 创建高光粒子（慢速，营造光泽感）
    private func createHighlightParticles(at position: CGPoint, color: UIColor) {
        let emitter = SKEmitterNode()
        
        // 创建粒子纹理
        let particleTexture = createParticleTexture(size: CGSize(width: 10, height: 10), color: color)
        emitter.particleTexture = particleTexture
        
        emitter.particleBirthRate = 500 // 先设置高值
        emitter.numParticlesToEmit = 50 // 增加高光粒子
        emitter.particleLifetime = 1.3
        emitter.particlePosition = position
        
        // 慢速，营造柔和的光泽感，模拟泡泡表面的反光
        emitter.particleSpeed = 90
        emitter.particleSpeedRange = 60
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi
        
        emitter.yAcceleration = -60
        
        // 使用颜色序列（主题色、辅助色、对比色的混合），而不是白色
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        let colorSequence = createColorSequence()
        emitter.particleColorSequence = colorSequence
        
        emitter.particleAlpha = 0.95
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.7
        
        // 立即生成所有粒子
        emitter.advanceSimulationTime(0.1)
        emitter.particleBirthRate = 0
        
        // 稍大的高光粒子
        emitter.particleSize = CGSize(width: 10, height: 10)
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.4 // 粒子大小变化范围
        emitter.particleScaleSpeed = -0.2
        
        // 高光粒子也需要旋转
        emitter.particleRotationSpeed = 1.5
        
        emitter.particleBlendMode = .add // 叠加模式让高光更亮
        
        addChild(emitter)
        
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.6),
            SKAction.removeFromParent()
        ]))
    }
    
    /// 创建小碎片粒子（快速消失）
    private func createFragmentParticles(at position: CGPoint) {
        let emitter = SKEmitterNode()
        
        emitter.particleBirthRate = 1200 // 先设置高值
        emitter.numParticlesToEmit = 120 // 更多小碎片，增加细节
        emitter.particleLifetime = 0.6 // 快速消失
        emitter.particlePosition = position
        
        // 高速小碎片，模拟泡泡炸开的瞬间碎片
        emitter.particleSpeed = 220
        emitter.particleSpeedRange = 180
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi
        
        emitter.yAcceleration = -180
        
        // 颜色配置 - 使用随机颜色序列
        emitter.particleColor = baseColor
        emitter.particleColorBlendFactor = 1.0
        let colorSequence = createColorSequence()
        emitter.particleColorSequence = colorSequence
        
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -1.3
        
        // 创建粒子纹理
        let particleTexture = createParticleTexture(size: CGSize(width: 3, height: 3), color: baseColor)
        emitter.particleTexture = particleTexture
        
        // 立即生成所有粒子
        emitter.advanceSimulationTime(0.1)
        emitter.particleBirthRate = 0
        
        // 小碎片，增加细节层次
        emitter.particleSize = CGSize(width: 3, height: 3)
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.5 // 粒子大小变化范围
        emitter.particleScaleSpeed = -0.8
        
        // 碎片快速旋转
        emitter.particleRotationSpeed = 5
        
        emitter.particleBlendMode = .alpha
        
        addChild(emitter)
        
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.removeFromParent()
        ]))
    }
}

/// SwiftUI 包装视图，用于在 SwiftUI 中显示粒子效果
struct BubbleExplosionView: UIViewRepresentable {
    let position: CGPoint
    let onComplete: () -> Void
    
    // 使用一个标识符来确保每次位置变化时都创建新视图
    let id: UUID
    
    init(position: CGPoint, onComplete: @escaping () -> Void) {
        self.position = position
        self.onComplete = onComplete
        self.id = UUID() // 每次创建新实例时生成新的 UUID
    }
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true // 优化渲染性能
        
        let scene = BubbleExplosionScene()
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        
        // 设置场景的锚点（默认是左下角，符合 SpriteKit 坐标系统）
        scene.anchorPoint = CGPoint(x: 0, y: 0)
        
        // 设置场景大小（使用一个合理的默认值，会在 updateUIView 中更新）
        scene.size = CGSize(width: 1000, height: 1000)
        
        view.presentScene(scene)
        
        // 等待视图布局完成后再触发爆炸（增加延迟确保视图完全准备好）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // 确保场景大小已正确设置
            let viewSize = view.bounds.size
            if viewSize.width > 0 && viewSize.height > 0 {
                scene.size = viewSize
                print("💥 场景大小已更新: \(viewSize)")
            } else {
                // 如果视图大小还没准备好，使用屏幕大小
                let screenSize = UIScreen.main.bounds.size
                scene.size = screenSize
                print("💥 使用屏幕大小: \(screenSize)")
            }
            
            // 再次确保场景大小正确（因为 updateUIView 可能还没调用）
            if scene.size.width == 1000 || scene.size.height == 1000 {
                let finalSize = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
                scene.size = finalSize
                print("💥 最终场景大小: \(finalSize)")
            }
            
            // 触发爆炸效果
            print("💥 触发粒子爆炸，屏幕位置: \(position), 场景大小: \(scene.size)")
            scene.createExplosion(at: position)
            
            // 动画完成后回调
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        // 更新场景大小
        if let scene = uiView.scene as? BubbleExplosionScene {
            let newSize = uiView.bounds.size
            if newSize.width > 0 && newSize.height > 0 {
                let oldSize = scene.size
                scene.size = newSize
                if oldSize != newSize {
                    print("💥 updateUIView: 场景大小从 \(oldSize) 更新为 \(newSize)")
                }
            }
        }
    }
}

