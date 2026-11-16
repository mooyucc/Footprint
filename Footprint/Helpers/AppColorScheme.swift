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
    /// 默认品牌主题色（强调色）
    /// - 颜色值：`#00A1D8` (RGB: 0, 161, 216)
    /// - 用途：强调色、重要操作、品牌标识、图标颜色等
    static let footprintRedDefault = Color(red: 0/255, green: 161/255, blue: 216/255)
    
    /// 品牌主题色（强调色）- 支持自定义
    /// - 如果用户设置了自定义品牌颜色，则返回自定义颜色；否则返回默认颜色
    /// - 颜色值：默认 `#00A1D8` (RGB: 0, 161, 216)
    /// - 用途：强调色、重要操作、品牌标识、图标颜色等
    /// - 注意：此属性会从 BrandColorManager 获取当前颜色，确保颜色变化时视图能自动更新
    static var footprintRed: Color {
        BrandColorManager.shared.currentBrandColor
    }
    
}

// MARK: - BrandColorManager

/// 品牌颜色管理器，用于管理自定义品牌颜色并通知所有视图更新
class BrandColorManager: ObservableObject {
    static let shared = BrandColorManager()
    
    /// UserDefaults 键名，用于存储自定义品牌颜色
    private let customBrandColorKey = "CustomBrandColor"
    
    /// 默认品牌颜色 `#00A1D8`（RGB: 0, 161, 216）
    let defaultBrandColor = Color(red: 0/255, green: 161/255, blue: 216/255)
    
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
    // MARK: - Core Graphics 渐变背景（用于图片生成）
    
    /// 绘制分享图背景（跟随当前外观的浅/深壳）
    /// - Parameters:
    ///   - rect: 绘制区域
    ///   - context: Core Graphics 上下文
    ///   - colorScheme: 指定壳；默认用 `AppearanceManager.resolvedColorScheme`
    static func drawGradientBackground(
        in rect: CGRect,
        context: CGContext,
        colorScheme: ColorScheme? = nil
    ) {
        let scheme = colorScheme ?? AppearanceManager.shared.resolvedColorScheme
        if scheme == .dark {
            drawDarkShareBackground(in: rect, context: context)
        } else {
            drawLightShareBackground(in: rect, context: context)
        }
    }

    /// HealthUI light share：`#F7F5FC` → `#EDEFF7`
    private static func drawLightShareBackground(in rect: CGRect, context: CGContext) {
        let top = UIColor(red: 0.969, green: 0.961, blue: 0.988, alpha: 1)      // #F7F5FC
        let bottom = UIColor(red: 0.929, green: 0.937, blue: 0.969, alpha: 1)   // #EDEFF7
        drawVerticalGradient(in: rect, context: context, colors: [top, bottom], fallback: top)
    }

    /// HealthUI dark share：black → `rgb(0.12, 0.14, 0.18)`
    private static func drawDarkShareBackground(in rect: CGRect, context: CGContext) {
        let top = UIColor.black
        let bottom = UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        drawVerticalGradient(in: rect, context: context, colors: [top, bottom], fallback: top)
    }

    private static func drawVerticalGradient(
        in rect: CGRect,
        context: CGContext,
        colors: [UIColor],
        fallback: UIColor
    ) {
        let cgColors = colors.map(\.cgColor) as CFArray
        let locations = (0..<colors.count).map { CGFloat($0) / CGFloat(max(colors.count - 1, 1)) }
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: cgColors,
            locations: locations
        ) else {
            context.setFillColor(fallback.cgColor)
            context.fill(rect)
            return
        }
        context.saveGState()
        context.addRect(rect)
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
        context.restoreGState()
    }
    
    // MARK: - 文字颜色
    
    /// 主文字颜色
    /// - 浅色模式: `.primary` (系统自动的深灰色，通常为 #333333)
    /// - 深色模式: `.primary` (系统自动适配)
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        Color.primary  // 系统自动适配浅色/深色模式
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
    
}

// MARK: - View 扩展 - 便捷方法

extension View {
    /// 应用页面氛围底（HealthUI：浅 pastel mesh / 深色双光斑+斜纹）
    /// - Parameter colorScheme: 保留参数以兼容旧调用；实际跟随当前 Environment
    func appPageBackgroundGradient(for colorScheme: ColorScheme) -> some View {
        modifier(FootprintAtmospherePageModifier())
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
    
}

/// 将内容叠在 Footprint 氛围底上（供 `appPageBackgroundGradient` 使用）
private struct FootprintAtmospherePageModifier: ViewModifier {
    @ObservedObject private var brandColorManager = BrandColorManager.shared

    func body(content: Content) -> some View {
        ZStack {
            FootprintAtmosphereBackground(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            )
            content
        }
        .toolbarBackground(.hidden, for: .navigationBar)
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
    
    /// 设置外观模式。窗口样式在本次更新里同步写入，已弹出的 sheet 就地换色。
    @MainActor
    func setAppearanceMode(_ mode: AppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: appearanceModeKey)
        currentMode = mode
        syncInterfaceStyle()
        NotificationCenter.default.post(name: .appearanceModeChanged, object: nil)
    }
    
    /// 获取当前应该使用的 ColorScheme（用于 .preferredColorScheme 修饰符）
    var preferredColorScheme: ColorScheme? {
        currentMode.toColorScheme()
    }
    
    /// 系统当前的颜色模式。读屏幕 trait，不受窗口 `overrideUserInterfaceStyle` 影响。
    var systemColorScheme: ColorScheme {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let style = scene?.screen.traitCollection.userInterfaceStyle ?? .light
        return style == .dark ? .dark : .light
    }
}

// MARK: - Notification.Name 扩展

extension Notification.Name {
    /// 品牌颜色更改通知
    static let brandColorChanged = Notification.Name("brandColorChanged")
    
    /// 外观模式更改通知
    static let appearanceModeChanged = Notification.Name("appearanceModeChanged")
}

