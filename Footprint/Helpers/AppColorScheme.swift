//
//  AppColorScheme.swift
//  Footprint
//
//  Created on 2025/01/27.
//  统一的配色工具类，遵循App配色标准
//

import SwiftUI
import UIKit
import Combine

// MARK: - Color 扩展

extension Color {
    // MARK: - 品牌色
    /// 默认品牌红色（强调色）
    /// - 颜色值：`#F75C62` (RGB: 247, 92, 98)
    /// - 用途：强调色、重要操作、品牌标识、图标颜色等
    static let footprintRedDefault = Color(red: 247/255, green: 92/255, blue: 98/255)
    
    /// 品牌红色（强调色）- 支持自定义
    /// - 如果用户设置了自定义品牌颜色，则返回自定义颜色；否则返回默认颜色
    /// - 颜色值：默认 `#F75C62` (RGB: 247, 92, 98)
    /// - 用途：强调色、重要操作、品牌标识、图标颜色等
    /// - 注意：此属性会从 BrandColorManager 获取当前颜色，确保颜色变化时视图能自动更新
    static var footprintRed: Color {
        BrandColorManager.shared.currentBrandColor
    }
    
    /// 页面背景米色 #F7F3EB
    static let footprintBeige = Color(red: 0.969, green: 0.953, blue: 0.922)
    
    /// 卡片背景米色 #F0E7DA
    static let footprintCardBeige = Color(red: 0.941, green: 0.906, blue: 0.855)
    
    /// 渐变结束色（浅粉色） #F5E6D3
    static let footprintGradientEnd = Color(red: 0.961, green: 0.902, blue: 0.827)
    
    // MARK: - 文字色
    /// 主文字色（已废弃，请使用 `.primary` 或 `AppColorScheme.primaryText(for:)`）
    /// - 注意：现在统一使用 `Color.primary`，系统会自动适配浅色/深色模式
    @available(*, deprecated, message: "使用 Color.primary 或 AppColorScheme.primaryText(for:) 替代")
    static let footprintPrimaryText = Color(red: 0.2, green: 0.2, blue: 0.2)
    
    /// 主按钮背景色（浅色模式） #333333
    static let footprintButtonBackground = Color(red: 0.2, green: 0.2, blue: 0.2)
    
    // MARK: - 图标色
    /// 通用图标颜色（品牌红色）
    /// - 用途：统计图标、功能图标、状态图标、列表项图标等（按钮图标除外）
    /// - 颜色：品牌红色 `#F75C62` (RGB: 247, 92, 98)
    /// - 使用方式：Image(systemName: "icon").foregroundColor(.footprintIconColor)
    static let footprintIconColor = Color.footprintRed
}

// MARK: - BrandColorManager

/// 品牌颜色管理器，用于管理自定义品牌颜色并通知所有视图更新
class BrandColorManager: ObservableObject {
    static let shared = BrandColorManager()
    
    /// UserDefaults 键名，用于存储自定义品牌颜色
    private let customBrandColorKey = "CustomBrandColor"
    
    /// 默认品牌颜色（RGB: 247, 92, 98）
    let defaultBrandColor = Color(red: 247/255, green: 92/255, blue: 98/255)
    
    /// 当前品牌颜色（可观察属性，变化时自动通知所有视图）
    @Published var currentBrandColor: Color
    
    /// 是否使用自定义颜色
    @Published var isUsingCustomColor: Bool
    
    private init() {
        // 先初始化存储属性为默认值
        self.currentBrandColor = defaultBrandColor
        self.isUsingCustomColor = false
        
        // 然后从 UserDefaults 读取自定义颜色
        if let customColor = Self.loadCustomColor(key: customBrandColorKey) {
            self.currentBrandColor = customColor
            self.isUsingCustomColor = true
        }
    }
    
    /// 从 UserDefaults 加载自定义颜色（静态方法，不依赖实例）
    private static func loadCustomColor(key: String) -> Color? {
        guard let colorData = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        // 从 Data 中解码颜色
        // 明确指定允许的类集合，包括 NSArray 和 NSNumber（CGFloat 在归档时会被转换为 NSNumber）
        if let components = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSArray.self, NSNumber.self],
            from: colorData
        ) as? [CGFloat],
           components.count >= 3 {
            return Color(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2]))
        }
        
        return nil
    }
    
    /// 设置自定义品牌颜色
    func setCustomBrandColor(_ color: Color) {
        // 将 Color 转换为 RGB 组件
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // 存储 RGB 组件
        let components = [red, green, blue]
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: components, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: customBrandColorKey)
        }
        
        // 更新状态（会自动通知所有观察者）
        currentBrandColor = color
        isUsingCustomColor = true
        
        // 发送通知（用于其他需要监听的地方）
        NotificationCenter.default.post(name: .brandColorChanged, object: nil)
    }
    
    /// 重置品牌颜色为默认值
    func resetBrandColorToDefault() {
        UserDefaults.standard.removeObject(forKey: customBrandColorKey)
        
        // 更新状态（会自动通知所有观察者）
        currentBrandColor = defaultBrandColor
        isUsingCustomColor = false
        
        // 发送通知（用于其他需要监听的地方）
        NotificationCenter.default.post(name: .brandColorChanged, object: nil)
    }
}

// MARK: - AppColorScheme 工具类

/// 统一的配色工具类，提供所有视图的配色方案
/// 根据当前颜色模式自动适配
struct AppColorScheme {
    /// 当前颜色模式（需要在View中通过Environment获取）
    static var colorScheme: ColorScheme = .light
    
    // MARK: - 自定义品牌颜色（兼容旧代码）
    
    /// 默认品牌颜色（RGB: 247, 92, 98）
    static let defaultBrandColor = Color(red: 247/255, green: 92/255, blue: 98/255)
    
    /// 获取自定义品牌颜色（如果已设置）
    /// - Returns: 自定义颜色，如果未设置则返回 nil
    static var customBrandColor: Color? {
        if BrandColorManager.shared.isUsingCustomColor {
            return BrandColorManager.shared.currentBrandColor
        }
        return nil
    }
    
    /// 设置自定义品牌颜色
    /// - Parameter color: 要设置的颜色
    static func setCustomBrandColor(_ color: Color) {
        BrandColorManager.shared.setCustomBrandColor(color)
    }
    
    /// 重置品牌颜色为默认值
    static func resetBrandColorToDefault() {
        BrandColorManager.shared.resetBrandColorToDefault()
    }
    
    /// 检查是否使用了自定义品牌颜色
    static var isUsingCustomBrandColor: Bool {
        return BrandColorManager.shared.isUsingCustomColor
    }
    
    // MARK: - 背景色
    
    /// 页面背景色（单色，不推荐使用）
    /// - 注意：所有视图页面背景应使用 `pageBackgroundGradient` 渐变背景，而不是此单色背景
    /// - 浅色模式: #F7F3EB (米白色)
    /// - 深色模式: 系统分组背景
    /// - 仅用于特殊场景，如需要纯色背景的组件
    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.systemGroupedBackground)
            : Color.footprintBeige
    }
    
    /// 页面背景渐变（推荐使用）
    /// - 浅色模式: 三色渐变（系统颜色半透明版本）
    ///   - 0%: Color.blue.opacity(0.12) - 浅蓝色（12% 不透明度）
    ///   - 50%: Color.pink.opacity(0.08) - 浅粉色（8% 不透明度）
    ///   - 100%: Color(.systemBackground) - 系统背景色
    /// - 深色模式: 系统分组背景（单色渐变，视觉上为单色）
    /// - 渐变方向: 从顶部到底部
    /// - 使用方式: `.appPageBackgroundGradient(for: colorScheme)`
    /// - 示例:
    ///   ```swift
    ///   ScrollView {
    ///       // 内容
    ///   }
    ///   .appPageBackgroundGradient(for: colorScheme)
    ///   ```
    static func pageBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        // 浅色模式：三色渐变（系统颜色半透明版本）
        return LinearGradient(
            colors: [
                Color.blue.opacity(0.12),      // 浅蓝色（12% 不透明度）
                Color.pink.opacity(0.08),      // 浅粉色（8% 不透明度）
                Color(.systemBackground)       // 系统背景色
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Core Graphics 渐变背景（用于图片生成）
    
    /// 绘制三色线性渐变背景（Core Graphics版本，用于分享图片生成）
    /// - 注意：分享图片始终使用浅色模式背景，不受系统深色模式影响
    /// - Parameters:
    ///   - rect: 绘制区域
    ///   - context: Core Graphics 上下文
    static func drawGradientBackground(in rect: CGRect, context: CGContext) {
        // 定义三色渐变的颜色（符合App配色标准，使用系统颜色的半透明版本）
        // 获取系统蓝色和粉色的RGB值，然后应用不透明度
        var blueRed: CGFloat = 0
        var blueGreen: CGFloat = 0
        var blueBlue: CGFloat = 0
        var blueAlpha: CGFloat = 0
        UIColor.systemBlue.getRed(&blueRed, green: &blueGreen, blue: &blueBlue, alpha: &blueAlpha)
        
        var pinkRed: CGFloat = 0
        var pinkGreen: CGFloat = 0
        var pinkBlue: CGFloat = 0
        var pinkAlpha: CGFloat = 0
        UIColor.systemPink.getRed(&pinkRed, green: &pinkGreen, blue: &pinkBlue, alpha: &pinkAlpha)
        
        // 创建半透明颜色（混合白色背景以模拟opacity效果）
        // 分享图片始终使用浅色模式背景（白色），不受系统深色模式影响
        let lightBackground = UIColor.white
        var bgRed: CGFloat = 1.0
        var bgGreen: CGFloat = 1.0
        var bgBlue: CGFloat = 1.0
        var bgAlpha: CGFloat = 1.0
        lightBackground.getRed(&bgRed, green: &bgGreen, blue: &bgBlue, alpha: &bgAlpha)
        
        // 计算混合后的颜色（color * opacity + background * (1 - opacity)）
        let color1 = UIColor(
            red: blueRed * 0.12 + bgRed * 0.88,
            green: blueGreen * 0.12 + bgGreen * 0.88,
            blue: blueBlue * 0.12 + bgBlue * 0.88,
            alpha: 1.0
        ) // 浅蓝色（12% 不透明度）
        
        let color2 = UIColor(
            red: pinkRed * 0.08 + bgRed * 0.92,
            green: pinkGreen * 0.08 + bgGreen * 0.92,
            blue: pinkBlue * 0.08 + bgBlue * 0.92,
            alpha: 1.0
        ) // 浅粉色（8% 不透明度）
        
        let color3 = lightBackground // 白色背景（始终使用浅色模式）
        
        // 创建颜色数组和位置数组
        let colors = [color1.cgColor, color2.cgColor, color3.cgColor]
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        
        // 创建渐变
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            // 如果创建失败，使用白色背景作为降级方案
            context.setFillColor(lightBackground.cgColor)
            context.fill(rect)
            return
        }
        
        // 渐变方向：从顶部到底部
        let startPoint = CGPoint(x: rect.midX, y: rect.minY) // 顶部中心
        let endPoint = CGPoint(x: rect.midX, y: rect.maxY)  // 底部中心
        
        // 绘制渐变
        context.saveGState()
        context.addRect(rect)
        context.clip()
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        context.restoreGState()
    }
    
    // MARK: - 卡片背景色
    
    /// 白卡片背景色（White Card）
    /// - 用途：统计卡片、信息展示卡片、数据卡片等常规内容展示
    /// - 浅色模式: #FFFFFF (纯白色)
    /// - 深色模式: 系统次要背景
    static func whiteCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground)
            : Color.white
    }
    
    /// 红卡片背景色（Red Card）
    /// - 用途：重要功能入口、设置面板、品牌强调卡片等需要突出显示的内容
    /// - 颜色: #F75C62 (品牌红色，不区分浅色/深色模式)
    static var redCardBackground: Color {
        Color.footprintRed
    }
    
    /// 黑卡片背景色（Dark Card）
    /// - 用途：进度展示、任务状态、重要通知等需要深色背景突出显示的内容
    /// - 浅色模式: #1C1C1E (深炭灰色)
    /// - 深色模式: 系统背景色
    static func darkCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.systemBackground)
            : Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
    }
    
    /// 浅米色卡片背景色（Beige Card）
    /// - 用途：文本气泡、提示信息、说明卡片、状态展示等需要柔和、温暖视觉效果的场景
    /// - 浅色模式: #FAF8F5 (浅米色)
    /// - 深色模式: 系统次要背景
    static func beigeCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground)
            : Color(red: 250/255, green: 248/255, blue: 245/255) // #FAF8F5
    }
    
    // MARK: - 卡片文字颜色
    
    /// 白卡片文字颜色
    /// - 标签文字: .secondary (灰色)
    /// - 主要文字: .primary (深灰色/黑色)
    /// - 强调元素: 品牌红色
    static func whiteCardTextColors() -> (label: Color, primary: Color, accent: Color) {
        (
            label: .secondary,
            primary: .primary,
            accent: Color.footprintRed
        )
    }
    
    /// 红卡片文字颜色
    /// - 标题/描述: 白色
    /// - 按钮文字: 品牌红色
    static func redCardTextColors() -> (title: Color, description: Color, buttonText: Color) {
        (
            title: .white,
            description: .white,
            buttonText: Color.footprintRed
        )
    }
    
    /// 黑卡片文字颜色
    /// - 标题: 品牌红色
    /// - 数值: .secondary (浅灰色)
    /// - 描述: 白色
    static func darkCardTextColors() -> (title: Color, value: Color, description: Color) {
        (
            title: Color.footprintRed,
            value: .secondary,
            description: .white
        )
    }
    
    // MARK: - 兼容性方法（保留旧方法以保持向后兼容）
    
    /// 大卡片背景色（已废弃，请使用 whiteCardBackground）
    @available(*, deprecated, message: "使用 whiteCardBackground(for:) 替代")
    static func largeCardBackground(for colorScheme: ColorScheme) -> Color {
        whiteCardBackground(for: colorScheme)
    }
    
    /// 小卡片背景色（已废弃，请使用 whiteCardBackground）
    @available(*, deprecated, message: "使用 whiteCardBackground(for:) 替代")
    static func smallCardBackground(for colorScheme: ColorScheme) -> Color {
        whiteCardBackground(for: colorScheme)
    }
    
    // MARK: - 文字颜色
    
    /// 主文字颜色
    /// - 浅色模式: `.primary` (系统自动的深灰色，通常为 #333333)
    /// - 深色模式: `.primary` (系统自动适配)
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        Color.primary  // 系统自动适配浅色/深色模式
    }
    
    // MARK: - 图标颜色
    
    /// 通用图标颜色（品牌红色）
    /// - 用途：统计图标、功能图标、状态图标、列表项图标等（按钮图标除外）
    /// - 颜色：品牌红色 `#F75C62` (RGB: 247, 92, 98)
    /// - 使用示例:
    ///   ```swift
    ///   Image(systemName: "map.fill")
    ///       .foregroundColor(AppColorScheme.iconColor)
    ///   ```
    /// - 注意：按钮图标应使用 `.primary` 颜色，配合Liquid Glass效果
    static var iconColor: Color {
        Color.footprintRed
    }
    
    // MARK: - 边框颜色
    
    /// 标准边框颜色
    /// - 浅色模式: 黑色 6% 透明度
    /// - 深色模式: 白色 8% 透明度
    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
    
    /// 浅米色卡片边框颜色（Beige Card Border）
    /// - 颜色: #EAE6DF (RGB: 234, 230, 223) - 浅米色边框
    /// - 用途：专门用于浅米色卡片，增强视觉层次和精致感
    /// - 使用示例:
    ///   ```swift
    ///   .overlay(
    ///       RoundedRectangle(cornerRadius: 15)
    ///           .stroke(AppColorScheme.beigeCardBorder, lineWidth: 1)
    ///   )
    ///   ```
    static var beigeCardBorder: Color {
        Color(red: 234/255, green: 230/255, blue: 223/255) // #EAE6DF
    }
    
    // MARK: - 按钮颜色
    
    /// 主按钮背景色
    /// - 浅色模式: #333333 (深灰色)
    /// - 深色模式: 白色
    static func primaryButtonBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white
            : Color.footprintButtonBackground
    }
    
    /// 主按钮文字颜色
    /// - 浅色模式: 白色
    /// - 深色模式: #333333 (深灰色)
    static func primaryButtonText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.footprintButtonBackground
            : Color.white
    }
    
    // MARK: - 进度条颜色
    
    /// 进度条填充色
    /// - 颜色: 品牌红色 `#F75C62` (RGB: 247, 92, 98)
    /// - 用途: 表示已完成/进行中的部分
    static var progressBarFill: Color {
        Color.footprintRed
    }
    
    /// 进度条背景色
    /// - 颜色: 深灰色 `Color.black.opacity(0.3)` 或 `#2C2C2E`
    /// - 用途: 表示未完成的部分
    static var progressBarBackground: Color {
        Color.black.opacity(0.3)
    }
    
    /// 进度条配置
    /// - height: 进度条高度（默认 6pt）
    /// - cornerRadius: 圆角半径（默认 4pt）
    static var progressBarConfig: (height: CGFloat, cornerRadius: CGFloat) {
        (height: 6, cornerRadius: 4)
    }
    
    // MARK: - 阴影配置
    
    /// 大卡片阴影
    static var largeCardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    /// 小卡片阴影
    static var smallCardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: Color.black.opacity(0.08),
            radius: 6,
            x: 0,
            y: 2
        )
    }
    
    /// 浮动元素阴影
    static var floatingShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: Color.black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    /// 图标按钮阴影
    static var iconButtonShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - 强调边框
    
    /// 强调边框颜色（用于选中状态、错误提示）
    /// - 颜色: 红色 30% 透明度
    static func accentBorder(for colorScheme: ColorScheme) -> Color {
        Color.red.opacity(0.3)
    }
    
    // MARK: - 半透明卡片（Glass Card）
    
    /// 半透明卡片阴影配置
    /// - 用于浮动面板、弹出层、覆盖层
    static var glassCardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    /// 半透明卡片边框颜色
    /// - 颜色: 白色 30% 透明度 - 半透明白色边框
    /// - 用途：专门用于半透明卡片（Glass Card），增强视觉层次和精致感
    /// - 使用示例:
    ///   ```swift
    ///   .overlay(
    ///       RoundedRectangle(cornerRadius: 15)
    ///           .stroke(AppColorScheme.glassCardBorder, lineWidth: 1)
    ///   )
    ///   ```
    static var glassCardBorder: Color {
        Color.white.opacity(0.3) // 半透明白色边框
    }
    
    // MARK: - 图标按钮辅助方法（iOS 26+ Liquid Glass）
    
    /// 创建标准图标按钮（使用Liquid Glass效果）
    /// - 使用 `.background(.material, in: Circle())` 修饰符实现Liquid Glass效果
    /// - 图标颜色：`.primary`（自动适配浅色/深色模式）
    /// - 系统优势：系统会自动处理色彩适配、模糊强度和性能优化
    /// - Parameters:
    ///   - icon: SF Symbols图标名称
    ///   - size: 按钮尺寸（默认44x44，最小触控目标）
    ///   - iconSize: 图标大小（默认20pt）
    ///   - material: 材质类型（默认.regularMaterial）
    ///     - `.regularMaterial`：标准玻璃效果（推荐用于大多数场景）
    ///     - `.ultraThinMaterial`：超薄玻璃效果（更透明，用于浮动按钮）
    ///     - `.thinMaterial`：薄玻璃效果（中等透明度）
    ///     - `.thickMaterial`：厚玻璃效果（较不透明）
    ///     - `.ultraThickMaterial`：超厚玻璃效果（最不透明）
    ///   - showBorder: 是否显示边框增强（默认false）
    ///   - action: 按钮操作
    /// - Returns: 配置好的图标按钮视图
    /// - 使用示例:
    ///   ```swift
    ///   AppColorScheme.iconButton(
    ///       icon: "location.fill",
    ///       size: 44,
    ///       iconSize: 20,
    ///       material: .regularMaterial,
    ///       showBorder: false,
    ///       action: { }
    ///   )
    ///   ```
    @ViewBuilder
    static func iconButton(
        icon: String,
        size: CGFloat = 44,
        iconSize: CGFloat = 20,
        material: Material = .regularMaterial,
        showBorder: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
        .background(material, in: Circle())
        .overlay(
            Group {
                if showBorder {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
            }
        )
        .shadow(
            color: iconButtonShadow.color,
            radius: iconButtonShadow.radius,
            x: iconButtonShadow.x,
            y: iconButtonShadow.y
        )
    }
}

// MARK: - View 扩展 - 便捷方法

extension View {
    /// 应用页面背景（单色，不推荐）
    /// - 注意：所有视图页面背景应使用 `appPageBackgroundGradient` 渐变背景
    /// - 仅用于特殊场景，如需要纯色背景的组件
    func appPageBackground(for colorScheme: ColorScheme) -> some View {
        self.background(AppColorScheme.pageBackground(for: colorScheme))
    }
    
    /// 应用页面背景渐变（推荐使用）
    /// - 浅色模式: 从米白色到浅粉色的渐变，提供温暖、优雅的视觉体验
    /// - 深色模式: 系统分组背景（自动适配）
    /// - 使用示例:
    ///   ```swift
    ///   ScrollView {
    ///       VStack {
    ///           // 内容
    ///       }
    ///   }
    ///   .appPageBackgroundGradient(for: colorScheme)
    ///   ```
    func appPageBackgroundGradient(for colorScheme: ColorScheme) -> some View {
        self.background(AppColorScheme.pageBackgroundGradient(for: colorScheme))
    }
    
    /// 应用白卡片样式（White Card）
    /// - 用途：统计卡片、信息展示卡片、数据卡片等常规内容展示
    /// - 背景色：纯白色 #FFFFFF
    /// - 阴影：轻微阴影效果
    func whiteCardStyle(for colorScheme: ColorScheme, cornerRadius: CGFloat = 15) -> some View {
        let shadow = AppColorScheme.smallCardShadow
        return self
            .background(AppColorScheme.whiteCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
    
    /// 应用红卡片样式（Red Card）
    /// - 用途：重要功能入口、设置面板、品牌强调卡片等需要突出显示的内容
    /// - 背景色：品牌红色 #F75C62
    /// - 阴影：中等强度阴影
    func redCardStyle(cornerRadius: CGFloat = 20) -> some View {
        let shadow = AppColorScheme.floatingShadow
        return self
            .background(AppColorScheme.redCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
    
    /// 应用黑卡片样式（Dark Card）
    /// - 用途：进度展示、任务状态、重要通知等需要深色背景突出显示的内容
    /// - 背景色：深炭灰色 #1C1C1E（浅色模式）或系统背景（深色模式）
    /// - 阴影：较强阴影效果
    func darkCardStyle(for colorScheme: ColorScheme, cornerRadius: CGFloat = 15) -> some View {
        let shadow = (color: Color.black.opacity(0.2), radius: CGFloat(10), x: CGFloat(0), y: CGFloat(4))
        return self
            .background(AppColorScheme.darkCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
    
    /// 应用浅米色卡片样式（Beige Card）
    /// - 用途：文本气泡、提示信息、说明卡片、状态展示等需要柔和、温暖视觉效果的场景
    /// - 背景色：浅米色 #FAF8F5（浅色模式）或系统次要背景（深色模式）
    /// - 边框：浅米色边框 #EAE6DF
    /// - 阴影：轻微阴影效果
    /// - 使用示例:
    ///   ```swift
    ///   @Environment(\.colorScheme) var colorScheme
    ///   
    ///   VStack(alignment: .leading, spacing: 8) {
    ///       Text("7个月开发3个APP,从被拒3次到终于过审,墨鱼足迹2.0上线,iCloud同步太难了")
    ///           .foregroundColor(.primary)
    ///           .font(.body)
    ///   }
    ///   .padding()
    ///   .beigeCardStyle(for: colorScheme)
    ///   ```
    /// - Parameters:
    ///   - colorScheme: 颜色模式（用于背景色适配，从 `@Environment(\.colorScheme)` 获取）
    ///   - cornerRadius: 圆角半径（默认 15pt）
    ///   - showBorder: 是否显示边框（默认 true）
    func beigeCardStyle(
        for colorScheme: ColorScheme,
        cornerRadius: CGFloat = 15,
        showBorder: Bool = true
    ) -> some View {
        let shadow = AppColorScheme.smallCardShadow
        return self
            .background(AppColorScheme.beigeCardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppColorScheme.beigeCardBorder, lineWidth: 1)
                    }
                }
            )
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
    
    /// 应用半透明卡片样式（Glass Card）
    /// - 用途：浮动面板、弹出层、覆盖层
    /// - 背景：系统Material材质，提供原生毛玻璃模糊效果，自动适配深色模式
    /// - 材质：默认使用 `.ultraThinMaterial`（最透明）
    /// - 文字颜色：**必须使用语义颜色**（`.primary`、`.secondary`、`.tertiary`），系统会自动根据背后背景的明暗程度调整文字颜色
    /// - 使用示例:
    ///   ```swift
    ///   @Environment(\.colorScheme) var colorScheme
    ///   
    ///   VStack {
    ///       Text("标题")
    ///           .foregroundColor(.primary)  // 自动适配
    ///       Text("副标题")
    ///           .foregroundColor(.secondary)  // 自动适配
    ///   }
    ///   .padding()
    ///   .glassCardStyle(material: .ultraThinMaterial, for: colorScheme)
    ///   ```
    /// - Parameters:
    ///   - material: Material材质类型（默认 `.ultraThinMaterial`）
    ///   - cornerRadius: 圆角半径（默认 15pt）
    ///   - showBorder: 是否显示边框（默认 true）
    ///   - colorScheme: 颜色模式（保留参数以保持向后兼容，边框颜色不再依赖此参数）
    /// - Important: 半透明卡片内的文字颜色必须使用语义颜色（`.primary`、`.secondary`、`.tertiary`），不要使用固定颜色（如 `.black`、`.white`）
    func glassCardStyle(
        material: Material = .ultraThinMaterial,
        cornerRadius: CGFloat = 15,
        showBorder: Bool = true,
        for colorScheme: ColorScheme
    ) -> some View {
        let shadow = AppColorScheme.glassCardShadow
        return self
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppColorScheme.glassCardBorder, lineWidth: 1) // 半透明白色边框
                    }
                }
            )
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
    
    // MARK: - 兼容性方法（保留旧方法以保持向后兼容）
    
    /// 应用大卡片样式（已废弃，请使用 whiteCardStyle）
    @available(*, deprecated, message: "使用 whiteCardStyle(for:cornerRadius:) 替代")
    func largeCardStyle(for colorScheme: ColorScheme, cornerRadius: CGFloat = 15) -> some View {
        whiteCardStyle(for: colorScheme, cornerRadius: cornerRadius)
    }
    
    /// 应用小卡片样式（已废弃，请使用 whiteCardStyle）
    @available(*, deprecated, message: "使用 whiteCardStyle(for:cornerRadius:) 替代")
    func smallCardStyle(for colorScheme: ColorScheme, cornerRadius: CGFloat = 12) -> some View {
        whiteCardStyle(for: colorScheme, cornerRadius: cornerRadius)
    }
}

// MARK: - View 扩展 - 品牌颜色响应

extension View {
    /// 使视图能够响应品牌颜色变化
    /// - 使用此修饰符确保视图在品牌颜色改变时自动刷新
    /// - 示例:
    ///   ```swift
    ///   Text("Hello")
    ///       .foregroundColor(.footprintRed)
    ///       .brandColorAware()
    ///   ```
    func brandColorAware() -> some View {
        self.environmentObject(BrandColorManager.shared)
    }
}

// MARK: - AppearanceManager

/// 外观模式管理器，用于管理应用的颜色模式（跟随系统/深色/浅色）
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    /// UserDefaults 键名，用于存储外观模式偏好
    private let appearanceModeKey = "AppearanceMode"
    
    /// 外观模式枚举
    enum AppearanceMode: String, CaseIterable {
        case system = "system"
        case dark = "dark"
        case light = "light"
        
        /// 显示名称（用于UI）
        var displayName: String {
            switch self {
            case .system:
                return "appearance_mode_system".localized
            case .dark:
                return "appearance_mode_dark".localized
            case .light:
                return "appearance_mode_light".localized
            }
        }
        
        /// 转换为 SwiftUI ColorScheme
        func toColorScheme() -> ColorScheme? {
            switch self {
            case .system:
                return nil  // nil 表示跟随系统
            case .dark:
                return .dark
            case .light:
                return .light
            }
        }
    }
    
    /// 当前外观模式（可观察属性，变化时自动通知所有视图）
    @Published var currentMode: AppearanceMode
    
    private init() {
        // 从 UserDefaults 读取保存的外观模式
        if let savedMode = UserDefaults.standard.string(forKey: appearanceModeKey),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.currentMode = mode
        } else {
            // 默认跟随系统
            self.currentMode = .system
        }
    }
    
    /// 设置外观模式
    func setAppearanceMode(_ mode: AppearanceMode) {
        // 直接在主线程更新（Picker 的 set 回调已经在主线程）
        UserDefaults.standard.set(mode.rawValue, forKey: appearanceModeKey)
        currentMode = mode
        
        // 当切换到系统模式时，强制触发更新以确保读取最新的系统颜色
        if mode == .system {
            // 触发 objectWillChange 以确保视图刷新
            objectWillChange.send()
        }
        
        // 发送通知（用于其他需要监听的地方）
        NotificationCenter.default.post(name: .appearanceModeChanged, object: nil)
    }
    
    /// 获取当前应该使用的 ColorScheme（用于 .preferredColorScheme 修饰符）
    var preferredColorScheme: ColorScheme? {
        currentMode.toColorScheme()
    }
    
    /// 获取系统当前的颜色模式
    var systemColorScheme: ColorScheme {
        // 使用 UITraitCollection 读取系统当前的颜色模式
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let traitCollection = window.traitCollection
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return .dark
            case .light:
                return .light
            default:
                return .light
            }
        }
        // 降级方案：使用当前窗口的 trait collection
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            switch keyWindow.traitCollection.userInterfaceStyle {
            case .dark:
                return .dark
            case .light:
                return .light
            default:
                return .light
            }
        }
        // 默认返回浅色
        return .light
    }
}

// MARK: - Notification.Name 扩展

extension Notification.Name {
    /// 品牌颜色更改通知
    static let brandColorChanged = Notification.Name("brandColorChanged")
    
    /// 外观模式更改通知
    static let appearanceModeChanged = Notification.Name("appearanceModeChanged")
}

