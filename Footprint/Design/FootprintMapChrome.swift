//
//  FootprintMapChrome.swift
//  Footprint
//
//  地图浮层专用玻璃壳：圆形按钮 / 胶囊条。
//  地图本身是「舞台」，此处只做框架层玻璃（勿叠 Atmosphere）。
//

import SwiftUI

// MARK: - Circle

struct FootprintMapGlassCircleModifier: ViewModifier {
    var diameter: CGFloat = 44
    /// 深色地图样式或深色外观时，旧版 Material 叠层略提亮
    var isDarkMap: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        } else {
            content
                .frame(width: diameter, height: diameter)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(isDarkMap ? Color.white.opacity(0.12) : Color.white.opacity(0.85))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isDarkMap ? 0.25 : 0.35), lineWidth: 1)
                        )
                }
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Capsule bar

struct FootprintMapGlassCapsuleModifier: ViewModifier {
    var isDarkMap: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background {
                    Capsule().fill(.clear)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .contentShape(Capsule())
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        } else {
            content
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule().stroke(
                                Color.white.opacity(isDarkMap ? 0.22 : 0.35),
                                lineWidth: 0.5
                            )
                        )
                }
                .contentShape(Capsule())
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        }
    }
}

/// 打卡等「品牌描边」圆形玻璃
struct FootprintMapBrandGlassCircleModifier: ViewModifier {
    var diameter: CGFloat
    var brand: Color
    var isDark: Bool
    var strokeWidth: CGFloat = 2

    func body(content: Content) -> some View {
        let stroke = LinearGradient(
            colors: [
                .white.opacity(0.7),
                brand.opacity(0.5),
                .white.opacity(0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        if #available(iOS 26, *) {
            content
                .frame(width: diameter, height: diameter)
                .background {
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .overlay {
                    Circle().strokeBorder(stroke, lineWidth: strokeWidth)
                }
                .contentShape(Circle())
                .opacity(0.95)
                .shadow(
                    color: Color.black.opacity(isDark ? 0.45 : 0.3),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        } else {
            content
                .frame(width: diameter, height: diameter)
                .background {
                    Circle().fill(.ultraThinMaterial)
                }
                .overlay {
                    Circle().strokeBorder(stroke, lineWidth: strokeWidth)
                }
                .contentShape(Circle())
                .opacity(0.88)
                .shadow(
                    color: Color.black.opacity(isDark ? 0.4 : 0.25),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        }
    }
}

// MARK: - View helpers

extension View {
    /// 地图浮层圆形玻璃按钮（样式切换、径向菜单等）
    func footprintMapGlassCircle(diameter: CGFloat = 44, isDarkMap: Bool = false) -> some View {
        modifier(FootprintMapGlassCircleModifier(diameter: diameter, isDarkMap: isDarkMap))
    }

    /// 地图浮层胶囊条（提示条、搜索条）
    func footprintMapGlassCapsule(isDarkMap: Bool = false) -> some View {
        modifier(FootprintMapGlassCapsuleModifier(isDarkMap: isDarkMap))
    }

    /// 打卡类品牌描边圆形玻璃
    func footprintMapBrandGlassCircle(
        diameter: CGFloat,
        brand: Color,
        isDark: Bool,
        strokeWidth: CGFloat = 2
    ) -> some View {
        modifier(
            FootprintMapBrandGlassCircleModifier(
                diameter: diameter,
                brand: brand,
                isDark: isDark,
                strokeWidth: strokeWidth
            )
        )
    }
}
