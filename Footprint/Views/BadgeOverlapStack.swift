//
//  BadgeOverlapStack.swift
//  Footprint
//
//  勋章重叠排列（Facepile）：收起叠放 + 展开显示名称
//

import SwiftUI

struct BadgeOverlapItem: Identifiable, Equatable {
    let id: String
    let imageName: String
    let title: String
    let shortTitle: String
}

/// 国家 / 省份勋章重叠堆叠
struct BadgeOverlapStack: View {
    let items: [BadgeOverlapItem]
    var maxVisible: Int = 5
    var circleSize: CGFloat = 36
    /// 为 false 时仅展示叠排（适合嵌在 NavigationLink 入口卡内）
    var allowsExpand: Bool = true
    var emptyText: String = "badges_overlap_empty".localized
    @Binding var isExpanded: Bool
    var onSelectItem: ((BadgeOverlapItem) -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var collapsedSpacing: CGFloat { -(circleSize / 3) }
    
    /// 叠排描边：浅色用背景色分隔，深色用淡白避免一圈黑边
    private var badgeRingColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.22)
            : Color(.systemBackground)
    }
    
    private var effectivelyExpanded: Bool {
        allowsExpand && isExpanded
    }
    
    private var visibleItems: [BadgeOverlapItem] {
        effectivelyExpanded ? items : Array(items.prefix(maxVisible))
    }
    
    private var overflowCount: Int {
        max(0, items.count - maxVisible)
    }
    
    var body: some View {
        Group {
            if items.isEmpty {
                emptyPlaceholder
            } else if effectivelyExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .accessibilityElement(children: (items.isEmpty || effectivelyExpanded) ? .contain : .combine)
        .accessibilityLabel(items.isEmpty ? emptyText : collapsedAccessibilityLabel)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(items.isEmpty || effectivelyExpanded || !allowsExpand ? [] : .isButton)
    }
    
    private var accessibilityHintText: String {
        guard !items.isEmpty, allowsExpand else { return "" }
        return effectivelyExpanded
            ? "badges_overlap_collapse_hint".localized
            : "badges_overlap_expand_hint".localized
    }
    
    // MARK: - Collapsed
    
    @ViewBuilder
    private var collapsedContent: some View {
        if allowsExpand {
            Button {
                toggleExpanded()
            } label: {
                collapsedStack
            }
            .buttonStyle(.plain)
        } else {
            collapsedStack
                .accessibilityHidden(true)
        }
    }
    
    private var collapsedStack: some View {
        HStack(spacing: collapsedSpacing) {
            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                badgeCircle(for: item)
                    .zIndex(Double(index)) // 右侧压在左侧之上
            }
            
            if overflowCount > 0 {
                overflowBadge
                    .zIndex(Double(visibleItems.count))
            }
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Expanded
    
    private var expandedContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(items) { item in
                    Button {
                        onSelectItem?(item)
                    } label: {
                        VStack(spacing: 6) {
                            badgeCircle(for: item)
                            
                            Text(item.shortTitle)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: circleSize + 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                }
                
                Button {
                    toggleExpanded()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "chevron.compact.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: circleSize, height: circleSize)
                            .background(Circle().fill(Color(.tertiarySystemFill)))
                        
                        Text("badges_overlap_collapse".localized)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("badges_overlap_collapse".localized)
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Pieces
    
    private var emptyPlaceholder: some View {
        Text(emptyText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(minHeight: circleSize)
    }
    
    private var overflowBadge: some View {
        Text("+\(overflowCount)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: circleSize, height: circleSize)
            .background(
                Circle()
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                Circle()
                    .strokeBorder(badgeRingColor, lineWidth: 2)
            )
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private func badgeCircle(for item: BadgeOverlapItem) -> some View {
        Group {
            if let image = UIImage(named: item.imageName) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .antialiased(true)
                    .scaledToFill()
            } else {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .frame(width: circleSize, height: circleSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(badgeRingColor, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
        .accessibilityHidden(!effectivelyExpanded)
    }
    
    private var collapsedAccessibilityLabel: String {
        "badges_overlap_a11y".localized(with: items.count)
    }
    
    private func toggleExpanded() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            isExpanded.toggle()
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var expanded = false
        var body: some View {
            BadgeOverlapStack(
                items: [
                    BadgeOverlapItem(id: "CN", imageName: "CountryBadge_CN", title: "中国", shortTitle: "中国"),
                    BadgeOverlapItem(id: "JP", imageName: "CountryBadge_JP", title: "日本", shortTitle: "日本"),
                    BadgeOverlapItem(id: "US", imageName: "CountryBadge_US", title: "美国", shortTitle: "美国"),
                    BadgeOverlapItem(id: "KR", imageName: "CountryBadge_KR", title: "韩国", shortTitle: "韩国"),
                    BadgeOverlapItem(id: "TH", imageName: "CountryBadge_TH", title: "泰国", shortTitle: "泰国"),
                    BadgeOverlapItem(id: "SG", imageName: "CountryBadge_SG", title: "新加坡", shortTitle: "新加坡"),
                    BadgeOverlapItem(id: "AU", imageName: "CountryBadge_AU", title: "澳大利亚", shortTitle: "澳大利亚"),
                    BadgeOverlapItem(id: "FR", imageName: "CountryBadge_FR", title: "法国", shortTitle: "法国")
                ],
                isExpanded: $expanded
            )
            .padding()
        }
    }
    return PreviewHost()
}
