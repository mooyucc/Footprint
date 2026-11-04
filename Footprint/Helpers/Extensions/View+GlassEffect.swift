//
//  View+GlassEffect.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的毛玻璃效果扩展
//
//  注意：请勿再命名为 `glassEffect`，以免与 iOS 26 系统 API 混淆。
//  地图浮层新代码请优先使用 `footprintMapGlassCircle` / 系统 `.glassEffect(.regular.interactive(), …)`。
//

import SwiftUI

extension View {
    /// 旧版 Material 玻璃（兼容 `GlassEffectStyle` 调用点）
    func materialGlassEffect(_ style: GlassEffectStyle, in shape: some Shape) -> some View {
        self.background(.ultraThinMaterial, in: shape)
    }
}
