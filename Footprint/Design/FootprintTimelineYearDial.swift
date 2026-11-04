//
//  FootprintTimelineYearDial.swift
//  Footprint
//
//  足迹时光 Click Wheel：半透明磨砂玻璃环 + 环向步进 + 四向键 + 中心 Select
//

import SwiftUI
import UIKit
import AudioToolbox

struct FootprintTimelineYearDial: View {
    let itemCount: Int
    @Binding var selectedIndex: Int
    /// 保留参数以兼容调用方；视觉上中心钮留空（年份在屏幕状态栏）
    var centerTitle: String = ""
    var onCenterTap: (() -> Void)? = nil
    var onMenu: (() -> Void)? = nil
    var onPrevious: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil
    var onPlayPause: (() -> Void)? = nil
    /// 自动轮播中时显示暂停图标，否则显示播放
    var isPlaying: Bool = false
    var accent: Color = FootprintTheme.Accent.primary
    /// 与 footprintGlassCard(glow:) 同款渗光色（通常为当前卡封面主色）
    var glow: Color? = nil
    /// 默认约为原 220 的 95%
    var dialSize: CGFloat = 209
    var accessibilityLabelText: String = ""
    var accessibilityValueText: String = ""

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 中心钮直径相对外盘比例（贴近经典 Click Wheel）
    private let centerRatio: CGFloat = 0.36
    /// 越大越钝；约 28° 翻一张，避免拨一下连跳多卡
    private let degreesPerStep: Double = 28
    private let tapTranslationLimit: CGFloat = 14
    private let tapAngleLimit: Double = 18

    @State private var angleAccumulator: Double = 0
    @State private var lastTouchAngleDegrees: Double?
    @State private var gestureActive = false
    @State private var liveIndex: Int = 0
    @State private var gestureStartAngle: Double?
    @State private var gestureDidScroll = false
    @State private var gestureMaxTranslation: CGFloat = 0
    @State private var gestureAccumulatedAbsAngle: Double = 0

    private var clampedSelectedIndex: Int {
        guard itemCount > 0 else { return 0 }
        return min(max(selectedIndex, 0), itemCount - 1)
    }

    private var centerSize: CGFloat { dialSize * centerRatio }
    private var centerHitRadius: CGFloat { centerSize * 0.55 }

    private var ringHitShape: some Shape {
        Circle().subtracting(
            Circle().scale(centerHitRadius * 2 / dialSize)
        )
    }

    // MARK: - Glass palette

    private var labelColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.88 : 0.72)
    }

    private var labelDisabledColor: Color {
        Color.primary.opacity(0.22)
    }

    private var dividerColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }

    private var rimStroke: Color {
        FootprintChrome.cardStroke(colorScheme)
    }

    /// 对齐 FootprintGlassBackground 的色叠层
    private var glassTintOverlay: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.22)
        }
        return Color.white.opacity(0.55)
    }

    private var glassTintOverlayFallback: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.28)
        }
        return Color.white.opacity(0.72)
    }

    var body: some View {
        ZStack {
            ambientGlowLayer

            frostedDisc
            quadrantDividers
            cardinalLabels

            Circle()
                .fill(Color.clear)
                .frame(width: dialSize, height: dialSize)
                .contentShape(ringHitShape)
                .gesture(dialDragGesture)

            centerButton
        }
        .frame(width: dialSize, height: dialSize)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: glowDescription)
        .onAppear {
            syncToSelectedIndex(animated: false)
        }
        .onChange(of: selectedIndex) { _, newValue in
            guard !gestureActive else { return }
            let clamped = itemCount > 0 ? min(max(newValue, 0), itemCount - 1) : 0
            if liveIndex != clamped {
                syncToSelectedIndex(animated: true)
            }
        }
        .onChange(of: itemCount) { _, newCount in
            guard newCount > 0 else {
                liveIndex = 0
                return
            }
            if selectedIndex >= newCount {
                selectedIndex = newCount - 1
            }
            guard !gestureActive else { return }
            syncToSelectedIndex(animated: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabelText))
        .accessibilityValue(Text(accessibilityValueText.isEmpty ? centerTitle : accessibilityValueText))
        .accessibilityAddTraits(onCenterTap != nil ? .isButton : [])
        .accessibilityHint(Text(onCenterTap != nil ? "view_details".localized : ""))
        .accessibilityAdjustableAction { direction in
            guard itemCount > 1 else { return }
            let next: Int
            switch direction {
            case .increment:
                next = min(liveIndex + 1, itemCount - 1)
            case .decrement:
                next = max(liveIndex - 1, 0)
            @unknown default:
                return
            }
            guard next != liveIndex else { return }
            commitIndex(next, haptic: true)
        }
        .accessibilityAction(named: Text("view_details".localized)) {
            onCenterTap?()
        }
        .accessibilityAction(named: Text("time_capsule_menu".localized)) {
            onMenu?()
        }
        .accessibilityAction(named: Text("time_capsule_previous_year".localized)) {
            onPrevious?()
        }
        .accessibilityAction(named: Text("time_capsule_next_year".localized)) {
            onNext?()
        }
    }

    // MARK: - Visual layers

    /// 动画用：Color 本身非 Equatable，用描述字符串
    private var glowDescription: String {
        glow.map { String(describing: $0) } ?? "nil"
    }

    /// 对齐 footprintGlassCard 底部渗光（圆形版；不加卡片那层投影）
    @ViewBuilder
    private var ambientGlowLayer: some View {
        if let glow {
            Circle()
                .fill(glow.opacity(colorScheme == .dark ? 0.55 : 0.22))
                .frame(width: dialSize * 0.92, height: dialSize * 0.55)
                .blur(radius: 22)
                .offset(y: 10)
                .allowsHitTesting(false)
        }
    }

    /// 与 FootprintGlassBackground 同配方：glassEffect / ultraThinMaterial + 色叠层 + 描边
    @ViewBuilder
    private var frostedDisc: some View {
        if #available(iOS 26, *) {
            Circle()
                .fill(.clear)
                .frame(width: dialSize, height: dialSize)
                .glassEffect(.regular.interactive(), in: Circle())
                .overlay { Circle().fill(glassTintOverlay) }
                .overlay { Circle().strokeBorder(rimStroke, lineWidth: 0.5) }
                .overlay {
                    Circle()
                        .strokeBorder(FootprintChrome.hairline(colorScheme), lineWidth: FootprintChrome.hairlineHeight)
                        .frame(width: centerSize + 6, height: centerSize + 6)
                }
                .allowsHitTesting(false)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: dialSize, height: dialSize)
                .overlay { Circle().fill(glassTintOverlayFallback) }
                .overlay { Circle().strokeBorder(rimStroke, lineWidth: 0.5) }
                .overlay {
                    Circle()
                        .strokeBorder(FootprintChrome.hairline(colorScheme), lineWidth: FootprintChrome.hairlineHeight)
                        .frame(width: centerSize + 6, height: centerSize + 6)
                }
                .allowsHitTesting(false)
        }
    }

    /// 四等分细线（45° 起）
    private var quadrantDividers: some View {
        let innerR = centerSize * 0.58
        let outerR = dialSize * 0.47
        let length = max(outerR - innerR - 2, 12)
        let mid = (innerR + outerR) / 2

        return ZStack {
            ForEach([45.0, 135.0, 225.0, 315.0], id: \.self) { degrees in
                Capsule(style: .continuous)
                    .fill(dividerColor)
                    .frame(width: 1, height: length)
                    .offset(y: -mid)
                    .rotationEffect(.degrees(degrees))
            }
        }
        .frame(width: dialSize, height: dialSize)
        .allowsHitTesting(false)
    }

    private var cardinalLabels: some View {
        let labelRadius = dialSize * 0.355
        return ZStack {
            Text("MENU")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .tracking(0.8)
                .foregroundStyle(onMenu == nil ? labelDisabledColor : labelColor)
                .offset(y: -labelRadius)

            Image(systemName: "backward.end.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(onPrevious == nil ? labelDisabledColor : labelColor)
                .offset(x: -labelRadius)

            Image(systemName: "forward.end.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(onNext == nil ? labelDisabledColor : labelColor)
                .offset(x: labelRadius)

            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(onPlayPause == nil ? labelDisabledColor : labelColor)
                .offset(y: labelRadius)
                .contentTransition(.symbolEffect(.replace))
        }
        .allowsHitTesting(false)
    }

    private var centerButton: some View {
        Button {
            guard itemCount > 0 else { return }
            TimelineDialHaptics.playSelect()
            onCenterTap?()
        } label: {
            // 中心用 Material（非第二层 glassEffect），与外盘区分且符合不叠两层 Liquid Glass
            Circle()
                .fill(.regularMaterial)
                .frame(width: centerSize, height: centerSize)
                .overlay {
                    Circle().strokeBorder(rimStroke, lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(itemCount == 0 || onCenterTap == nil)
        .accessibilityHidden(true)
    }

    // MARK: - Gesture

    private var dialDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let center = CGPoint(x: dialSize / 2, y: dialSize / 2)
                let dist = hypot(value.location.x - center.x, value.location.y - center.y)

                if !gestureActive, dist < centerHitRadius {
                    return
                }

                let angle = Self.angleDegrees(from: center, to: value.location)
                let translation = hypot(value.translation.width, value.translation.height)
                gestureMaxTranslation = max(gestureMaxTranslation, translation)

                if !gestureActive {
                    gestureActive = true
                    gestureStartAngle = Self.angleDegrees(from: center, to: value.startLocation)
                    lastTouchAngleDegrees = angle
                    angleAccumulator = 0
                    gestureDidScroll = false
                    gestureAccumulatedAbsAngle = 0
                    gestureMaxTranslation = translation
                    TimelineDialHaptics.prepareTick()
                    return
                }

                guard itemCount > 1 else {
                    lastTouchAngleDegrees = angle
                    return
                }

                guard let last = lastTouchAngleDegrees else {
                    lastTouchAngleDegrees = angle
                    return
                }

                var delta = angle - last
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                lastTouchAngleDegrees = angle
                gestureAccumulatedAbsAngle += abs(delta)

                angleAccumulator += delta
                while angleAccumulator >= degreesPerStep {
                    angleAccumulator -= degreesPerStep
                    let next = min(liveIndex + 1, itemCount - 1)
                    if next != liveIndex {
                        gestureDidScroll = true
                        commitIndex(next, haptic: true)
                    }
                }
                while angleAccumulator <= -degreesPerStep {
                    angleAccumulator += degreesPerStep
                    let next = max(liveIndex - 1, 0)
                    if next != liveIndex {
                        gestureDidScroll = true
                        commitIndex(next, haptic: true)
                    }
                }
            }
            .onEnded { _ in
                defer {
                    gestureActive = false
                    lastTouchAngleDegrees = nil
                    angleAccumulator = 0
                    gestureStartAngle = nil
                    gestureDidScroll = false
                    gestureMaxTranslation = 0
                    gestureAccumulatedAbsAngle = 0
                }

                guard !gestureDidScroll,
                      gestureMaxTranslation < tapTranslationLimit,
                      gestureAccumulatedAbsAngle < tapAngleLimit,
                      let startAngle = gestureStartAngle else {
                    return
                }

                handleCardinalTap(at: startAngle)
            }
    }

    private enum CardinalZone {
        case menu, previous, next, playPause
    }

    private func handleCardinalTap(at angleDegrees: Double) {
        guard let zone = Self.cardinalZone(for: angleDegrees) else { return }
        switch zone {
        case .menu:
            guard onMenu != nil else { return }
            TimelineDialHaptics.playSelect()
            onMenu?()
        case .previous:
            guard onPrevious != nil else { return }
            TimelineDialHaptics.playTick()
            onPrevious?()
        case .next:
            guard onNext != nil else { return }
            TimelineDialHaptics.playTick()
            onNext?()
        case .playPause:
            guard onPlayPause != nil else { return }
            TimelineDialHaptics.playSelect()
            onPlayPause?()
        }
    }

    private static func cardinalZone(for angleDegrees: Double) -> CardinalZone? {
        let a = angleDegrees
        if abs(Self.shortestAngleDelta(a, -90)) <= 40 { return .menu }
        if abs(Self.shortestAngleDelta(a, 180)) <= 40 || abs(Self.shortestAngleDelta(a, -180)) <= 40 {
            return .previous
        }
        if abs(Self.shortestAngleDelta(a, 0)) <= 40 { return .next }
        if abs(Self.shortestAngleDelta(a, 90)) <= 40 { return .playPause }
        return nil
    }

    private static func shortestAngleDelta(_ a: Double, _ b: Double) -> Double {
        var d = a - b
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    private func commitIndex(_ index: Int, haptic: Bool) {
        liveIndex = index
        selectedIndex = index
        if haptic {
            TimelineDialHaptics.playTick()
        }
    }

    private func syncToSelectedIndex(animated: Bool) {
        liveIndex = clampedSelectedIndex
        _ = animated
        _ = reduceMotion
    }

    private static func angleDegrees(from center: CGPoint, to point: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return atan2(dy, dx) * 180 / .pi
    }
}

// MARK: - Haptics

private enum TimelineDialHaptics {
    private static let tickGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectGenerator = UIImpactFeedbackGenerator(style: .medium)

    static func prepareTick() {
        tickGenerator.prepare()
    }

    static func playTick() {
        tickGenerator.prepare()
        tickGenerator.impactOccurred(intensity: 0.68)
        AudioServicesPlaySystemSound(1103)
    }

    static func playSelect() {
        selectGenerator.prepare()
        selectGenerator.impactOccurred(intensity: 0.85)
    }
}
