//
//  YearAlbumLibrary.swift
//  Footprint
//
//  年鉴首页：每个年份一个文件夹，封面从袋口探出，年份印在封面上。
//

import SwiftUI
import UIKit

struct YearAlbumImage: Identifiable {
    let id: UUID
    let image: UIImage
}

struct YearAlbumLibrary: View {
    let items: [(year: Int, count: Int)]
    let images: [Int: [YearAlbumImage]]
    var yearLabel: (Int) -> String
    var zoomNamespace: Namespace.ID
    var scrollToYear: Int?
    var onSelect: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone 竖屏 2 / 横屏 3；iPad 竖屏 4 / 横屏 5
    private var columnCount: Int {
        switch (horizontalSizeClass, verticalSizeClass) {
        case (.regular, .regular): return 4
        case (.regular, _): return 5
        case (_, .compact): return 3
        default: return 2
        }
    }

    private var gridMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 1100 : .infinity
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 16),
                        count: columnCount
                    ),
                    spacing: 8
                ) {
                    ForEach(items, id: \.year) { item in
                        YearAlbumCell(
                            year: item.year,
                            count: item.count,
                            yearText: yearLabel(item.year),
                            images: images[item.year] ?? [],
                            zoomNamespace: zoomNamespace,
                            action: { onSelect(item.year) }
                        )
                        .frame(maxWidth: 280)
                        .frame(maxWidth: .infinity)
                        .id(item.year)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .frame(maxWidth: gridMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .onChange(of: scrollToYear) { _, year in
                guard let year else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(year, anchor: .center)
                }
            }
        }
    }
}

private struct YearAlbumCell: View {
    let year: Int
    let count: Int
    let yearText: String
    let images: [YearAlbumImage]
    let zoomNamespace: Namespace.ID
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var brandColorManager: BrandColorManager
    /// 骨架先出文件夹与年份；封面就绪后淡入。
    @State private var photosVisible = false

    private static let frontRadius: CGFloat = 22
    private static let rimHeight: CGFloat = 7

    private var imageIDs: [UUID] { images.map(\.id) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Color.clear
                    .aspectRatio(1.05, contentMode: .fit)
                    .overlay { pocketCanvas }
                // 光晕画在计入布局的预留区内，避免 LazyVGrid 裁切超出 cell 的绘制
                Color.clear
                    .frame(height: glowReserveHeight)
                    .overlay(alignment: .top) { folderGlow }
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .matchedTransitionSource(id: year, in: zoomNamespace) { source in
            // zoom 默认按直角矩形 morph；与前盖同圆角，避免收回时闪直角阴影
            source.clipShape(
                RoundedRectangle(cornerRadius: Self.frontRadius, style: .continuous)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(yearText)，\(count)" + "destinations_count".localized))
        .accessibilityAddTraits(.isButton)
        .onAppear {
            if !images.isEmpty {
                photosVisible = true
            }
        }
        .onChange(of: imageIDs) { _, ids in
            guard !ids.isEmpty else {
                photosVisible = false
                return
            }
            guard !photosVisible else { return }
            if reduceMotion {
                photosVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    photosVisible = true
                }
            }
        }
    }

    private var pocketCanvas: some View {
        GeometryReader { geo in
            let photoWidth = geo.size.width * 0.42
            let photoHeight = photoWidth * 1.28
            // 前盖略矮，给袋口探出的照片留顶边，避免被格子裁切
            let pocketHeight = geo.size.height * 0.58
            let frontHeight = pocketHeight - Self.rimHeight
            // 骨架与真图共用同一 slot 数（最多 3），避免加载后扇形跳位。
            let slotCount = count > 0 ? min(3, count) : 0
            let transforms = Self.fanTransforms(year: year, count: slotCount)
            let showingPhotos = photosVisible && !images.isEmpty

            ZStack {
                folderRim
                    .frame(height: frontHeight + Self.rimHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(0)

                if slotCount > 0 {
                    ForEach(0..<slotCount, id: \.self) { index in
                        let spec = index < transforms.count
                            ? transforms[index]
                            : (x: CGFloat(0), angle: 0.0)
                        albumPhotoSkeleton(width: photoWidth, height: photoHeight)
                            .rotationEffect(.degrees(spec.angle))
                            .offset(x: spec.x * geo.size.width)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, frontHeight * 0.72)
                            .opacity(showingPhotos ? 0 : 1)
                            .zIndex(Double(index) + 1)
                    }
                }

                ForEach(Array(images.enumerated()), id: \.element.id) { index, item in
                    let spec = index < transforms.count ? transforms[index] : (x: CGFloat(0), angle: 0.0)
                    albumPhoto(item.image, width: photoWidth, height: photoHeight)
                        .rotationEffect(.degrees(spec.angle))
                        .offset(x: spec.x * geo.size.width)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, frontHeight * 0.72)
                        .opacity(photosVisible ? 1 : 0)
                        .zIndex(Double(index) + 1)
                }

                folderFront(yearFontSize: min(geo.size.width * 0.15, 30))
                    .frame(maxWidth: .infinity)
                    .frame(height: frontHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(10)
            }
        }
    }

    private var folderRim: some View {
        RoundedRectangle(cornerRadius: Self.frontRadius, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.94))
    }

    private func folderFront(yearFontSize: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.frontRadius, style: .continuous)
        return shape
            .fill(.clear)
            .modifier(FolderFrontGlass(cornerRadius: Self.frontRadius))
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.14 : 0.40),
                            Color.white.opacity(0.02),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
            }
            .overlay {
                FolderPaperGrain(cornerRadius: Self.frontRadius)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                FolderTab()
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.65),
                    lineWidth: 0.5
                )
            }
            .overlay {
                FolderCoverImprint(
                    yearText: yearText,
                    countText: String(format: "journey_cards_destinations_count".localized, count),
                    yearSize: yearFontSize
                )
            }
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.08),
                radius: 6,
                y: 3
            )
    }

    /// 预留 ≥ offset + 椭圆高 + blur + safety，避免 LazyVGrid 裁切向下渗光。
    private var glowReserveHeight: CGFloat {
        colorScheme == .dark ? 32 : 22
    }

    /// 与 footprintGlassCard 同款底边渗光。上移叠进封面底，预留区只包住向下探的 blur。
    private var folderGlow: some View {
        let isDark = colorScheme == .dark
        return Ellipse()
            .fill(
                brandColorManager.currentBrandColor.opacity(isDark ? 0.80 : 0.22)
            )
            .frame(height: isDark ? 30 : 20)
            .blur(radius: isDark ? 14 : 10)
            .padding(.horizontal, isDark ? 24 : 32)
            .offset(y: isDark ? -16 : -10)
            .allowsHitTesting(false)
    }

    private func albumPhoto(_ image: UIImage, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white)
            .frame(width: width, height: height)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width - 6, height: height - 6)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    /// 袋口纸片占位：与真图同尺寸/圆角，无上一会话内容。
    private func albumPhotoSkeleton(width: CGFloat, height: CGFloat) -> some View {
        let paper = colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.92)
        let inset = colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color(.systemGray5).opacity(0.85)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(paper)
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(inset)
                    .frame(width: width - 6, height: height - 6)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 6, y: 3)
            .accessibilityHidden(true)
    }

    /// 角度按年份固定，刷新后同一年不会换一套倾斜。
    private static func fanTransforms(year: Int, count: Int) -> [(x: CGFloat, angle: Double)] {
        let variant = abs(year) % 4
        switch count {
        case 0:
            return []
        case 1:
            let angles = [-4.0, 3.0, -2.5, 4.5]
            return [(0, angles[variant])]
        case 2:
            let pairs: [[(CGFloat, Double)]] = [
                [(-0.16, -10), (0.14, 8)],
                [(-0.12, -8), (0.16, 11)],
                [(-0.18, -12), (0.12, 7)],
                [(-0.14, -9), (0.15, 10)]
            ]
            return pairs[variant]
        default:
            let triples: [[(CGFloat, Double)]] = [
                [(-0.22, -12), (0.02, 2), (0.20, 11)],
                [(-0.20, -10), (0.0, 4), (0.22, 13)],
                [(-0.24, -13), (0.04, 1), (0.18, 10)],
                [(-0.18, -9), (-0.02, 5), (0.22, 12)]
            ]
            return Array(triples[variant].prefix(count))
        }
    }
}

private struct FolderCoverImprint: View {
    let yearText: String
    let countText: String
    let yearSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let rule = colorScheme == .dark
            ? Color.white.opacity(0.22)
            : Color.black.opacity(0.14)
        let countSize = max(yearSize * 0.36, 9)

        VStack(spacing: 6) {
            Capsule()
                .fill(rule)
                .frame(width: yearSize * 1.55, height: 0.5)
            DebossedText(text: yearText, size: yearSize, weight: .semibold, monospaced: true)
            Capsule()
                .fill(rule)
                .frame(width: yearSize * 1.15, height: 0.5)
            DebossedText(text: countText, size: countSize, weight: .medium, monospaced: false)
                .padding(.top, 1)
        }
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }
}

private struct FolderTab: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                colorScheme == .dark
                    ? Color.white.opacity(0.10)
                    : Color.white.opacity(0.42)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.55),
                        lineWidth: 0.5
                    )
            }
            .frame(width: 54, height: 9)
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                radius: 1,
                y: 0.5
            )
    }
}

private struct FolderPaperGrain: View {
    var cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(
                RadialGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06)
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: 120
                )
            )
            Canvas { context, size in
                let line = colorScheme == .dark
                    ? Color.white.opacity(0.035)
                    : Color.black.opacity(0.028)
                var y: CGFloat = 10
                while y < size.height - 8 {
                    var path = Path()
                    path.move(to: CGPoint(x: 12, y: y))
                    path.addLine(to: CGPoint(x: size.width - 12, y: y))
                    context.stroke(path, with: .color(line), lineWidth: 0.5)
                    y += 5
                }
            }
            .clipShape(shape)
        }
    }
}

private struct DebossedText: View {
    let text: String
    let size: CGFloat
    var weight: Font.Weight = .semibold
    var monospaced: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let font = FootprintType.metric(size: size, weight: weight)
        let base = colorScheme == .dark
            ? Color.white.opacity(0.40)
            : Color.black.opacity(0.32)
        let lift = colorScheme == .dark
            ? Color.white.opacity(0.55)
            : Color.black.opacity(0.45)
        let highlight = Color.white.opacity(colorScheme == .dark ? 0.18 : 0.60)

        glyph(font)
            .foregroundStyle(base)
            .overlay {
                glyph(font)
                    .foregroundStyle(lift)
                    .offset(y: -1)
                    .blur(radius: 0.6)
                    .mask { glyph(font) }
            }
            .overlay {
                glyph(font)
                    .foregroundStyle(highlight)
                    .offset(y: 1)
                    .blur(radius: 0.4)
                    .mask { glyph(font) }
            }
    }

    private func glyph(_ font: Font) -> some View {
        Text(text)
            .font(font)
            .modifier(OptionalMonospacedDigit(enabled: monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

private struct OptionalMonospacedDigit: ViewModifier {
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.monospacedDigit()
        } else {
            content
        }
    }
}

private struct FolderFrontGlass: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let tint = reduceTransparency
            ? (colorScheme == .dark ? 0.55 : 0.82)
            : (colorScheme == .dark ? 0.10 : 0.18)
        let tintColor = colorScheme == .dark ? Color.black : Color.white

        Group {
            if #available(iOS 26, *) {
                content
                    .glassEffect(.regular, in: shape)
                    .overlay { shape.fill(tintColor.opacity(tint)) }
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay { shape.fill(tintColor.opacity(min(tint + 0.12, 0.92))) }
            }
        }
    }
}
