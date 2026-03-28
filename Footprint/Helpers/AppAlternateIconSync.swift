//
//  AppAlternateIconSync.swift
//  Footprint
//
//  根据 Pro 权益同步主屏幕备用图标（需在 Asset Catalog 与构建设置中注册 AppIconPro）。
//

import Foundation

#if os(iOS)
import UIKit

enum AppAlternateIconSync {
    /// 须与 Assets 中 App Icon 集名称、`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` 一致
    static let proIconName = "AppIconPro"

    @MainActor
    static func applyHomeScreenIcon(isProActive: Bool) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let desired: String? = isProActive ? proIconName : nil
        guard UIApplication.shared.alternateIconName != desired else { return }
        UIApplication.shared.setAlternateIconName(desired) { error in
            if let error {
                print("⚠️ 主屏幕图标切换失败: \(error.localizedDescription)")
            }
        }
    }
}
#else
enum AppAlternateIconSync {
    static func applyHomeScreenIcon(isProActive: Bool) {}
}
#endif
