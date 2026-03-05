//
//  View+GlassEffect.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的毛玻璃效果扩展
//

import SwiftUI

// MARK: - 毛玻璃效果扩展
/// 毛玻璃效果修饰符（兼容不同 iOS 版本）
extension View {
    func glassEffect(_ style: GlassEffectStyle, in shape: some Shape) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
    }
}
