//
//  ShareProUpgradeBanner.swift
//  Footprint
//
//  免费用户在分享预览页看到的 Pro 升级提示（去水印 / 完整版面）。
//

import SwiftUI

struct ShareProUpgradeBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(Color.footprintRed)

                VStack(alignment: .leading, spacing: 4) {
                    Text("share_pro_banner_title".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text("share_pro_banner_subtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .footprintGlassCard(cornerRadius: 14, glow: Color.footprintRed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("share_pro_banner_title".localized)
        .accessibilityHint("share_pro_banner_subtitle".localized)
    }
}
