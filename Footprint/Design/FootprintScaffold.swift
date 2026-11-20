//
//  FootprintScaffold.swift
//  Footprint
//
//  Hub / Form scaffolds + section cards + nav rows (HealthUI).
//

import SwiftUI

struct FootprintHubScaffold<Content: View>: View {
    var accent: Color = FootprintTheme.Accent.primary
    var secondaryAccent: Color = FootprintTheme.Accent.secondary
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            FootprintAtmosphereBackground(accent: accent, secondaryAccent: secondaryAccent)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

extension View {
    /// 在氛围底页面上隐藏导航栏底，让 mesh / 光斑透上来
    func footprintHideNavigationChrome() -> some View {
        toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct FootprintFormScaffold<Content: View>: View {
    var accent: Color = FootprintTheme.Accent.primary
    var secondaryAccent: Color = FootprintTheme.Accent.secondary
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            FootprintAtmosphereBackground(accent: accent, secondaryAccent: secondaryAccent)
            content()
                .scrollContentBackground(.hidden)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct FootprintSectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String? = nil
    var glow: Color? = nil
    var contentSpacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            if let title {
                Text(title)
                    .font(FootprintType.cardKicker)
                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .footprintGlassCard(glow: glow)
    }
}

struct FootprintRowDivider: View {
    var body: some View {
        FootprintCardHairline().padding(.vertical, 2)
    }
}

struct FootprintNavRow: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    var systemImage: String
    var tint: Color = FootprintTheme.Accent.primary
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(FootprintType.row).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(FootprintType.caption)
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(FootprintType.caption.weight(.semibold))
                .foregroundStyle(FootprintChrome.tertiaryLabel(colorScheme))
        }
        .contentShape(Rectangle())
    }
}

struct FootprintEmptyText: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    var body: some View {
        Text(text)
            .font(FootprintType.secondary)
            .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
    }
}

/// 横向筛选胶囊：全部 / 国内 / 国外 等
struct FootprintFilterChipRow: View {
    @Binding var selection: String?
    let options: [(tag: String?, label: String)]
    var accent: Color = FootprintTheme.Accent.primary

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selection == option.tag
                Button {
                    selection = option.tag
                } label: {
                    Text(option.label)
                        .font(FootprintType.chip)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                Capsule().fill(accent)
                            } else {
                                FootprintCapsuleChromeBackground()
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
