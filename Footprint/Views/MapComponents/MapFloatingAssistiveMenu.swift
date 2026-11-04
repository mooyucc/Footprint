//
//  MapFloatingAssistiveMenu.swift
//  Footprint
//
//  从 MapView.swift 提取的浮动辅助菜单（编译拆分）
//

import SwiftUI
import UIKit

struct AssistiveMenuAction: Identifiable {
    let id: String
    let icon: String
    let title: String
    let isActive: Bool
    var isHighlighted: Bool = false
    let action: () -> Void
}

struct FloatingAssistiveMenu: View {
    static let collapsedDiameter: CGFloat = 60
    static let menuRadius: CGFloat = 120
    static let margin: CGFloat = 12
    static let highlightedButtonPadding: CGFloat = 16
    static let normalButtonPadding: CGFloat = 14
    /// 液滴颈断裂距离（相对按钮直径；越大越能拉长）
    static let metaballBreakDistance: CGFloat = collapsedDiameter * 3.1
    static let metaballActivateDistance: CGFloat = 6
    
    let actions: [AssistiveMenuAction]
    @Binding var isExpanded: Bool
    @Binding var position: CGPoint
    let canvasSize: CGSize
    let safeAreaInsets: EdgeInsets
    let menuTitle: String
    let isDarkStyle: Bool
    let highlightColor: Color
    let showHighlightBadge: Bool
    let iconProvider: (String, Bool, Bool) -> AnyView
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var dragStartPosition: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var showMetaball: Bool = false
    @State private var neckBroken: Bool = false
    @State private var lastCanvasSize: CGSize = .zero
    @State private var lastSafeAreaInsets: EdgeInsets = EdgeInsets()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if isExpanded {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        collapseMenu()
                    }
            }
            
            if showMetaball && !reduceMotion {
                metaballLayer
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
            
            menuLayer
                .position(position)
                .highPriorityGesture(dragGesture)
                .accessibilityLabel(menuTitle)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .onChange(of: canvasSize) { newSize in
            handleGeometryChange(newSize: newSize, newInsets: safeAreaInsets)
        }
        .onChange(of: safeAreaInsets) { newInsets in
            handleGeometryChange(newSize: canvasSize, newInsets: newInsets)
        }
    }
    
    /// 锚点残影 + 液滴连接颈（纯几何，不叠 glass）
    private var metaballLayer: some View {
        let radius = Self.collapsedDiameter / 2
        let distance = hypot(position.x - dragStartPosition.x, position.y - dragStartPosition.y)
        let stretch = min(1, distance / Self.metaballBreakDistance)
        let ghostScale = neckBroken ? 0.88 : (1 - stretch * 0.12)
        let ghostOpacity = neckBroken ? 0.2 : (0.45 - stretch * 0.2)
        
        return ZStack {
            // 仅在跟手拖拽时画颈，松手贴边弹簧时不拉丝
            if isDragging, !neckBroken, distance > Self.metaballActivateDistance {
                MetaballNeckShape(
                    from: dragStartPosition,
                    to: position,
                    radius: radius,
                    maxDistance: Self.metaballBreakDistance
                )
                .fill(
                    LinearGradient(
                        colors: [
                            highlightColor.opacity(0.55),
                            highlightColor.opacity(0.35)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 0.6)
            }
            
            Circle()
                .fill(highlightColor.opacity(ghostOpacity))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isDarkStyle ? 0.2 : 0.35), lineWidth: 1)
                )
                .frame(width: Self.collapsedDiameter, height: Self.collapsedDiameter)
                .scaleEffect(ghostScale)
                .position(dragStartPosition)
        }
    }
    
    private var menuLayer: some View {
        ZStack {
            ForEach(Array(actions.enumerated()), id: \.1.id) { index, action in
                radialButton(for: action, at: index)
            }
            mainButton
        }
    }
   
    private var mainButton: some View {
        Button {
            toggleMenu()
        } label: {
            mainButtonContent
                .overlay(alignment: .topTrailing) {
                    if showHighlightBadge && !isExpanded {
                        Circle()
                            .fill(highlightColor)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                            )
                            .offset(x: -2, y: 2)
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityHint(menuTitle)
    }
    
    private var mainButtonIcon: some View {
        ZStack {
            Image(systemName: "circle.hexagongrid.fill")
                .opacity(isExpanded ? 0 : 1)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .scaleEffect(isExpanded ? 0.6 : 1)
            
            Image(systemName: "xmark")
                .opacity(isExpanded ? 1 : 0)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .scaleEffect(isExpanded ? 1 : 0.6)
        }
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(isDarkStyle ? Color.white : Color.primary)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
    
    private var mainButtonContent: some View {
        mainButtonIcon
            .footprintMapGlassCircle(diameter: Self.collapsedDiameter, isDarkMap: isDarkStyle)
    }
    
    private func radialButton(for action: AssistiveMenuAction, at index: Int) -> some View {
        let offsets = radialOffsets(for: index)
        let expandDelay = Double(index) * 0.045
        let collapseDelay = Double(max(actions.count - 1 - index, 0)) * 0.035
        
        return Button {
            select(action)
        } label: {
            radialButtonContent(for: action)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
        .offset(x: isExpanded ? offsets.x : 0, y: isExpanded ? offsets.y : 0)
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1 : 0.5, anchor: .center)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.78)
                .delay(isExpanded ? expandDelay : collapseDelay),
            value: isExpanded
        )
        .allowsHitTesting(isExpanded)
    }
    
    @ViewBuilder
    private func radialButtonContent(for action: AssistiveMenuAction) -> some View {
        let padding = action.isHighlighted ? Self.highlightedButtonPadding : Self.normalButtonPadding
        let diameter = 24 + padding * 2
        
        VStack(spacing: 0) {
            if action.isHighlighted {
                highlightedRadialButton(for: action, padding: padding)
            } else {
                iconProvider(action.icon, action.isActive, false)
                    .frame(width: 24, height: 24)
                    .footprintMapGlassCircle(diameter: diameter, isDarkMap: isDarkStyle)
                    .overlay {
                        if action.isActive {
                            Circle()
                                .stroke(Color.white.opacity(isDarkStyle ? 0.25 : 0.2), lineWidth: 1.6)
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private func highlightedRadialButton(for action: AssistiveMenuAction, padding: CGFloat) -> some View {
        iconProvider(action.icon, action.isActive, true)
            .frame(width: 24, height: 24)
            .padding(padding)
            .background(
                Circle()
                    .fill(highlightColor.gradient)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    )
            )
            .contentShape(Circle())
            .shadow(color: highlightColor.opacity(0.45), radius: 10, x: 0, y: 4)
    }
    
    private func radialOffsets(for index: Int) -> (x: CGFloat, y: CGFloat) {
        guard actions.count > 1 else { return (0, 0) }
        let spread = Double.pi * 0.9
        let start = -spread / 2
        let step = spread / Double(actions.count - 1)
        let angle = start + step * Double(index)
        let baseX = CGFloat(cos(angle)) * Self.menuRadius
        let baseY = CGFloat(sin(angle)) * Self.menuRadius
        let horizontalDirection: CGFloat = position.x > canvasSize.width / 2 ? -1 : 1
        return (abs(baseX) * horizontalDirection, baseY)
    }
    
    private func toggleMenu() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if isExpanded {
            collapseMenu()
        } else {
            clampPosition(requiresMenuSpace: true)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isExpanded = true
            }
        }
    }
    
    private func select(_ action: AssistiveMenuAction) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        collapseMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action.action()
        }
    }
    
    private func collapseMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isExpanded = false
        }
        clampPosition(requiresMenuSpace: false)
        snapToNearestEdge()
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    neckBroken = false
                    dragStartPosition = position
                    if !reduceMotion {
                        showMetaball = true
                    }
                }
                
                if isExpanded {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
                
                let next = CGPoint(
                    x: dragStartPosition.x + value.translation.width,
                    y: dragStartPosition.y + value.translation.height
                )
                position = next
                
                if !reduceMotion, !neckBroken {
                    let distance = hypot(next.x - dragStartPosition.x, next.y - dragStartPosition.y)
                    if distance >= Self.metaballBreakDistance {
                        neckBroken = true
                        let feedback = UIImpactFeedbackGenerator(style: .rigid)
                        feedback.impactOccurred(intensity: 0.85)
                    }
                }
            }
            .onEnded { value in
                let released = CGPoint(
                    x: dragStartPosition.x + value.translation.width,
                    y: dragStartPosition.y + value.translation.height
                )
                // 触手未断：弹回原点；已断：落在新位置并贴边
                let shouldReturn = !neckBroken
                
                isDragging = false
                
                // 保留 dragStartPosition，避免残影在淡出时跳到原点
                withAnimation(.easeOut(duration: 0.18)) {
                    showMetaball = false
                    neckBroken = false
                }
                
                if shouldReturn {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        position = dragStartPosition
                    }
                } else {
                    position = released
                    clampPosition(requiresMenuSpace: false)
                    snapToNearestEdge()
                }
            }
    }
    
    private func snapToNearestEdge(size: CGSize? = nil, insets: EdgeInsets? = nil) {
        let canvas = size ?? canvasSize
        let safeArea = insets ?? safeAreaInsets
        let collapsedRadius = Self.collapsedDiameter / 2
        let left = safeArea.leading + Self.margin + collapsedRadius
        let right = canvas.width - safeArea.trailing - Self.margin - collapsedRadius
        let targetX = position.x < canvas.width / 2 ? left : right
        let clampedY = min(
            max(position.y, safeArea.top + Self.margin + collapsedRadius),
            canvas.height - safeArea.bottom - Self.margin - collapsedRadius
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            position = CGPoint(x: targetX, y: clampedY)
        }
    }
    
    private func clampPosition(requiresMenuSpace: Bool) {
        clampPosition(
            to: canvasSize,
            insets: safeAreaInsets,
            requiresMenuSpace: requiresMenuSpace
        )
    }
    
    private func clampPosition(to size: CGSize, insets: EdgeInsets, requiresMenuSpace: Bool) {
        position = FloatingAssistiveMenu.clamp(
            position,
            in: size,
            safeArea: insets,
            requiresMenuSpace: requiresMenuSpace
        )
    }
    
    private func handleGeometryChange(newSize: CGSize, newInsets: EdgeInsets) {
        guard newSize.width.isFinite, newSize.height.isFinite else { return }
        
        let sizeDelta = abs(lastCanvasSize.width - newSize.width) + abs(lastCanvasSize.height - newSize.height)
        let insetDelta =
            abs(lastSafeAreaInsets.top - newInsets.top) +
            abs(lastSafeAreaInsets.leading - newInsets.leading) +
            abs(lastSafeAreaInsets.bottom - newInsets.bottom) +
            abs(lastSafeAreaInsets.trailing - newInsets.trailing)
        
        let isInitialMeasurement = lastCanvasSize == .zero
        lastCanvasSize = newSize
        lastSafeAreaInsets = newInsets
        
        if isInitialMeasurement {
            clampPosition(to: newSize, insets: newInsets, requiresMenuSpace: isExpanded)
            return
        }
        
        if sizeDelta > 10 || insetDelta > 2 {
            if isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isExpanded = false
                }
            }
            clampPosition(to: newSize, insets: newInsets, requiresMenuSpace: false)
            snapToNearestEdge(size: newSize, insets: newInsets)
        } else {
            clampPosition(to: newSize, insets: newInsets, requiresMenuSpace: isExpanded)
        }
    }
    
    static func defaultPosition(in size: CGSize, safeArea: EdgeInsets) -> CGPoint {
        CGPoint(
            x: size.width - safeArea.trailing - margin - (collapsedDiameter / 2),
            y: size.height - safeArea.bottom - margin - (collapsedDiameter / 2) - 120
        )
    }
    
    static func clamp(
        _ position: CGPoint,
        in size: CGSize,
        safeArea: EdgeInsets,
        requiresMenuSpace: Bool
    ) -> CGPoint {
        guard size.width.isFinite, size.height.isFinite else { return position }
        let collapsedRadius = collapsedDiameter / 2
        let minX = safeArea.leading + margin + collapsedRadius
        let maxX = size.width - safeArea.trailing - margin - collapsedRadius
        let minY = safeArea.top + margin + collapsedRadius
        let maxY = size.height - safeArea.bottom - margin - collapsedRadius
        
        var clampedX = min(max(position.x, minX), maxX)
        var clampedY = min(max(position.y, minY), maxY)
        
        guard requiresMenuSpace else {
            return CGPoint(x: clampedX, y: clampedY)
        }
        
        // 根据浮球所在区域，仅为展开方向预留空间，避免整体被挤到屏幕中间
        let horizontalMid = (minX + maxX) / 2
        if clampedX >= horizontalMid {
            let minAllowedX = minX + menuRadius
            if clampedX < minAllowedX {
                clampedX = minAllowedX
            }
        } else {
            let maxAllowedX = maxX - menuRadius
            if clampedX > maxAllowedX {
                clampedX = maxAllowedX
            }
        }
        
        // 垂直方向仅在需要时进行最小幅度的校正
        let availableTop = clampedY - minY
        if availableTop < menuRadius {
            clampedY = minY + menuRadius
        }
        
        let availableBottom = maxY - clampedY
        if availableBottom < menuRadius {
            clampedY = maxY - menuRadius
        }
        
        return CGPoint(x: clampedX, y: clampedY)
    }
}

/// 两圆之间的液滴颈：腰宽随距离收缩，超过阈值由调用方停止绘制。
struct MetaballNeckShape: Shape {
    var from: CGPoint
    var to: CGPoint
    var radius: CGFloat
    var maxDistance: CGFloat
    
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(from.x, from.y),
                AnimatablePair(to.x, to.y)
            )
        }
        set {
            from = CGPoint(x: newValue.first.first, y: newValue.first.second)
            to = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = hypot(dx, dy)
        guard distance > 1, distance < maxDistance else { return Path() }
        
        let stretch = min(1, distance / maxDistance)
        let endRadius = radius * (1 - stretch * 0.28)
        let waist = max(1.5, radius * (1 - stretch) * 0.92)
        
        let angle = atan2(dy, dx)
        let px = CGFloat(-sin(angle))
        let py = CGFloat(cos(angle))
        
        let aLeft = CGPoint(x: from.x + px * endRadius, y: from.y + py * endRadius)
        let aRight = CGPoint(x: from.x - px * endRadius, y: from.y - py * endRadius)
        let bLeft = CGPoint(x: to.x + px * endRadius, y: to.y + py * endRadius)
        let bRight = CGPoint(x: to.x - px * endRadius, y: to.y - py * endRadius)
        
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let waistLeft = CGPoint(x: mid.x + px * waist, y: mid.y + py * waist)
        let waistRight = CGPoint(x: mid.x - px * waist, y: mid.y - py * waist)
        
        var path = Path()
        path.move(to: aLeft)
        path.addQuadCurve(to: bLeft, control: waistLeft)
        // 远端圆帽：start 必须对齐 bLeft，否则会先拉出平切弦
        path.addArc(
            center: to,
            radius: endRadius,
            startAngle: .radians(angle + .pi / 2),
            endAngle: .radians(angle - .pi / 2),
            clockwise: false
        )
        path.addQuadCurve(to: aRight, control: waistRight)
        // 近端圆帽：start 对齐 aRight，经外侧 tip 到 aLeft
        path.addArc(
            center: from,
            radius: endRadius,
            startAngle: .radians(angle - .pi / 2),
            endAngle: .radians(angle + .pi / 2),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
