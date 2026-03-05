//
//  AccessibilityModifiers.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的无障碍修饰符
//

import SwiftUI

// MARK: - 无障碍提示修饰符
/// 解决类型歧义问题的无障碍提示修饰符
struct AccessibilityHintModifier: ViewModifier {
    let hint: String
    
    func body(content: Content) -> some View {
        content.accessibilityHint(hint)
    }
}
