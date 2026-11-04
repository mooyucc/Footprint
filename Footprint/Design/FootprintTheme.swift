//
//  FootprintTheme.swift
//  Footprint
//
//  HealthUI-aligned design tokens + appearance helpers.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum FootprintTheme {
    enum Radius {
        static let chip: CGFloat = 12
        static let input: CGFloat = 14
        static let card: CGFloat = 24
        static let sheet: CGFloat = 28
        static let hero: CGFloat = 32
    }

    enum Accent {
        /// Default brand cyan `#00A1D8`
        static let primary = Color(red: 0 / 255, green: 161 / 255, blue: 216 / 255)
        /// Secondary glow (warm complement)
        static let secondary = Color(red: 1.0, green: 0.62, blue: 0.04)
        static let fitness = Color(red: 0.20, green: 0.78, blue: 0.35)
        static let stand = Color(red: 0.20, green: 0.78, blue: 0.95)
    }
}

extension AppearanceManager.AppearanceMode {
    /// Always resolve to a concrete scheme (never nil).
    var resolvedColorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: AppearanceManager.shared.systemColorScheme
        }
    }

    var resolutionID: String {
        let scheme = resolvedColorScheme == .dark ? "dark" : "light"
        return "\(rawValue)-\(scheme)"
    }

#if os(iOS)
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
#endif
}

extension AppearanceManager {
    /// Concrete scheme for chrome / share cards (never nil).
    var resolvedColorScheme: ColorScheme {
        currentMode.resolvedColorScheme
    }

    var resolutionID: String {
        currentMode.resolutionID
    }

#if os(iOS)
    @MainActor
    func syncInterfaceStyle() {
        let style = currentMode.userInterfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                // 从明确浅/深切到系统时，直接写 .unspecified 往往不会刷新已弹出的 sheet。
                // 先盖一层当前系统色逼出 trait 变化，再清成跟随系统。
                if style == .unspecified {
                    let resolved: UIUserInterfaceStyle = systemColorScheme == .dark ? .dark : .light
                    window.overrideUserInterfaceStyle = resolved
                    if let root = window.rootViewController {
                        applyInterfaceStyle(resolved, to: root)
                    }
                }
                window.overrideUserInterfaceStyle = style
                if let root = window.rootViewController {
                    applyInterfaceStyle(style, to: root)
                }
            }
        }
    }

    /// 已弹出的 sheet 会在自己的控制器上记住弹出时的外观，窗口级覆盖到不了它。
    @MainActor
    private func applyInterfaceStyle(_ style: UIUserInterfaceStyle, to viewController: UIViewController) {
        viewController.overrideUserInterfaceStyle = style
        for child in viewController.children {
            applyInterfaceStyle(style, to: child)
        }
        if let presented = viewController.presentedViewController {
            applyInterfaceStyle(style, to: presented)
        }
    }
#endif
}
