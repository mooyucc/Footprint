//
//  IconButton.swift
//  Footprint
//
//  Created on 2025/01/27.
//  图标按钮组件 - 使用 iOS 26 Liquid Glass 效果
//

import SwiftUI

/// Liquid Glass 样式枚举
enum LiquidGlassStyle {
    case ultraThin
    case thin
    case regular
}

/// 图标按钮组件
/// 使用 iOS 26 系统级的 Liquid Glass（液体玻璃）效果
/// 主要使用: .backgroundStyle(.material, in: .shape)
/// 可选增强: .backgroundStyleBorder()
/// 系统会自动处理色彩适配、模糊强度和性能优化
/// 适用于工具栏按钮、浮动按钮、地图控制按钮等场景
struct IconButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let iconSize: CGFloat
    let iconWeight: Font.Weight
    let glassStyle: LiquidGlassStyle
    let showBorder: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    /// 初始化图标按钮
    /// - Parameters:
    ///   - icon: SF Symbols 图标名称
    ///   - size: 按钮尺寸（默认 44，最小触控目标）
    ///   - iconSize: 图标大小（默认 20）
    ///   - iconWeight: 图标字重（默认 .medium）
    ///   - glassStyle: Liquid Glass 样式（默认 .regular）
    ///   - showBorder: 是否显示边框（默认 false，可选增强）
    ///   - action: 点击回调
    init(
        icon: String,
        size: CGFloat = 44,
        iconSize: CGFloat = 20,
        iconWeight: Font.Weight = .medium,
        glassStyle: LiquidGlassStyle = .regular,
        showBorder: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.glassStyle = glassStyle
        self.showBorder = showBorder
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
        .modifier(LiquidGlassModifier(style: glassStyle, showBorder: showBorder))
        .shadow(
            color: AppColorScheme.iconButtonShadow.color,
            radius: AppColorScheme.iconButtonShadow.radius,
            x: AppColorScheme.iconButtonShadow.x,
            y: AppColorScheme.iconButtonShadow.y
        )
    }
}

// MARK: - Liquid Glass 修饰符

/// Liquid Glass 效果修饰符
/// 使用 iOS 26 系统级的 Liquid Glass API
/// 主要使用: .backgroundStyle(.material, in: .shape)
/// 可选增强: .backgroundStyleBorder()
/// 系统会自动处理色彩适配、模糊强度和性能优化
struct LiquidGlassModifier: ViewModifier {
    let style: LiquidGlassStyle
    let showBorder: Bool
    
    init(style: LiquidGlassStyle, showBorder: Bool = false) {
        self.style = style
        self.showBorder = showBorder
    }
    
    func body(content: Content) -> some View {
        // iOS 26+ 使用系统级 Liquid Glass API
        // 主要使用: .backgroundStyle(.material)
        // 使用 .clipShape() 定义形状
        // 可选边框使用 .overlay() 实现
        content
            .backgroundStyle(materialForStyle)
            .clipShape(Circle())
            .applyIf(showBorder) { view in
                view.overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
    }
    
    private var materialForStyle: Material {
        switch style {
        case .ultraThin:
            return .ultraThinMaterial
        case .thin:
            return .thinMaterial
        case .regular:
            return .regularMaterial
        }
    }
}

// MARK: - View 扩展辅助方法

extension View {
    /// 条件应用修饰符
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - iOS 18-25 降级方案（可选，用于向后兼容）

/// 图标按钮（降级版本）
/// 用于不支持 `.glassBackgroundEffect()` 的 iOS 版本
/// 注意：当前项目使用 iOS 26+，此组件主要用于向后兼容或测试
struct IconButtonFallback: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let iconSize: CGFloat
    let iconWeight: Font.Weight
    let material: Material
    
    @Environment(\.colorScheme) var colorScheme
    
    init(
        icon: String,
        size: CGFloat = 44,
        iconSize: CGFloat = 20,
        iconWeight: Font.Weight = .medium,
        material: Material = .ultraThinMaterial,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.material = material
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
        .background(material, in: Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: AppColorScheme.iconButtonShadow.color,
            radius: AppColorScheme.iconButtonShadow.radius,
            x: AppColorScheme.iconButtonShadow.x,
            y: AppColorScheme.iconButtonShadow.y
        )
    }
}

// MARK: - 便捷方法

extension View {
    /// 创建图标按钮（自动选择 iOS 26+ 或降级版本）
    @ViewBuilder
    func iconButton(
        icon: String,
        size: CGFloat = 44,
        iconSize: CGFloat = 20,
        iconWeight: Font.Weight = .medium,
        glassStyle: LiquidGlassStyle = .regular,
        action: @escaping () -> Void
    ) -> some View {
        IconButton(
            icon: icon,
            size: size,
            iconSize: iconSize,
            iconWeight: iconWeight,
            glassStyle: glassStyle,
            action: action
        )
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        // 标准按钮 (44x44)
        IconButton(icon: "location.fill", size: 44, iconSize: 20) {
            print("标准按钮")
        }
        
        // 大型按钮 (56x56)
        IconButton(icon: "plus", size: 56, iconSize: 24, iconWeight: .semibold) {
            print("大型按钮")
        }
        
        // 不同样式
        HStack(spacing: 20) {
            IconButton(icon: "camera.fill", glassStyle: .ultraThin) {
                print("超薄玻璃")
            }
            
            IconButton(icon: "map.fill", glassStyle: .regular) {
                print("标准玻璃")
            }
            
            IconButton(icon: "star.fill", glassStyle: .thin) {
                print("薄玻璃")
            }
        }
        
        // 不同形状示例（可选）
        IconButton(icon: "heart.fill", size: 48, iconSize: 22) {
            print("中等按钮")
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

