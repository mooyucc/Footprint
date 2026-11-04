//
//  FootprintCylinderScroll.swift
//  Footprint
//
//  圆柱卷收列表：按视口中心距离插值旋转 / 缩放 / 明暗
//

import SwiftUI

extension View {
    /// 按视口中心距离插值旋转角 / 缩放 / 明暗，边缘项渐隐
    func cylinderScrollEffect() -> some View {
        modifier(CylinderScrollEffectModifier())
    }
}

private struct CylinderScrollEffectModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 边缘最大 X 轴旋转（约 ±28°，避免过强梯形挤压）
    private let maxAngleDegrees: Double = 28
    /// 边缘最小缩放（轻微即可，主形变交给旋转）
    private let edgeScale: CGFloat = 0.92
    /// 边缘最低不透明度
    private let edgeOpacity: Double = 0.55
    /// 边缘压暗量
    private let edgeDim: Double = 0.12
    /// 中心死区：此范围内几乎不变形，减少文字亚像素抖动
    private let centerDeadZone: Double = 0.15

    func body(content: Content) -> some View {
        content
            .scrollTransition(.interactive, axis: .vertical) { view, phase in
                let raw = reduceMotion ? 0 : min(max(abs(phase.value), 0), 1)
                let t = max(0, (raw - centerDeadZone) / (1 - centerDeadZone))
                // 二次缓降：中间更平、边缘更柔
                let falloff = t * t
                let scale = 1 - (1 - edgeScale) * falloff
                let opacity = 1 - (1 - edgeOpacity) * falloff
                let dim = edgeDim * falloff
                let sign = phase.value < 0 ? -1.0 : 1.0
                let angle = reduceMotion ? 0 : sign * maxAngleDegrees * falloff

                return view
                    .rotation3DEffect(
                        .degrees(angle),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.75
                    )
                    .scaleEffect(scale, anchor: .center)
                    .opacity(opacity)
                    .brightness(-dim)
            }
    }
}
