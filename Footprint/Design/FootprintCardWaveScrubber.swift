//
//  FootprintCardWaveScrubber.swift
//  Footprint
//
//  年鉴地点波峰条：竖线铺满宽度，按住的位置鼓起波峰并跟随手指。
//

import SwiftUI

struct FootprintCardWaveScrubber: View {
    let count: Int
    let selectedIndex: Int
    var accent: Color = FootprintTheme.Accent.primary
    /// 拖动中的小数序号，0 是第一张。
    var onScrub: (CGFloat) -> Void
    var onSelect: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDragging = false
    @State private var displayedUnit: CGFloat = 0
    @State private var committedIndex: Int = 0
    @State private var scrubTick = 0

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            Canvas { context, size in
                drawBars(in: context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width))
            .accessibilityElement()
            .accessibilityLabel(Text("travel_timeline".localized))
            .accessibilityValue(Text(accessibilityValueText))
            .accessibilityAdjustableAction { direction in
                guard count > 1 else { return }
                let next: Int
                switch direction {
                case .increment:
                    next = min(selectedIndex + 1, count - 1)
                case .decrement:
                    next = max(selectedIndex - 1, 0)
                @unknown default:
                    return
                }
                guard next != selectedIndex else { return }
                onSelect(next)
            }
        }
        .frame(height: 56)
        .sensoryFeedback(.selection, trigger: scrubTick)
        .onAppear {
            committedIndex = clamped(selectedIndex)
            displayedUnit = unit(for: selectedIndex)
        }
        .onChange(of: selectedIndex) { _, newValue in
            guard !isDragging else { return }
            committedIndex = clamped(newValue)
            moveRestingPeak(to: unit(for: newValue))
        }
        .onChange(of: count) { _, _ in
            guard !isDragging else { return }
            committedIndex = clamped(selectedIndex)
            displayedUnit = unit(for: selectedIndex)
        }
    }

    private var accessibilityValueText: String {
        guard count > 0 else { return "" }
        return "\(clamped(selectedIndex) + 1) / \(count)"
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard count > 1 else { return }
                let x = min(max(value.location.x, 0), width)
                let unit = x / width
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isDragging = true
                    displayedUnit = unit
                }
                let fractional = unit * CGFloat(count - 1)
                onScrub(fractional)
                let index = clamped(Int(fractional.rounded()))
                guard index != committedIndex else { return }
                committedIndex = index
                scrubTick += 1
            }
            .onEnded { _ in
                guard isDragging else { return }
                isDragging = false
                onSelect(committedIndex)
                moveRestingPeak(to: unit(for: committedIndex))
            }
    }

    private func moveRestingPeak(to target: CGFloat) {
        if reduceMotion {
            displayedUnit = target
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                displayedUnit = target
            }
        }
    }

    private func unit(for index: Int) -> CGFloat {
        guard count > 1 else { return 0.5 }
        return CGFloat(clamped(index)) / CGFloat(count - 1)
    }

    private func clamped(_ index: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    private func drawBars(in context: GraphicsContext, size: CGSize) {
        let barSpacing: CGFloat = 5
        let barWidth: CGFloat = 2
        let barCount = max(Int(size.width / barSpacing), 1)
        let step = size.width / CGFloat(barCount)
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = isDragging ? 40 : 28
        let sigma: CGFloat = isDragging ? 0.08 : 0.045
        let denominator = 2 * sigma * sigma

        for index in 0..<barCount {
            let position = barCount == 1 ? 0.5 : CGFloat(index) / CGFloat(barCount - 1)
            let distance = abs(position - displayedUnit)
            let gain = count > 1 ? exp(-(distance * distance) / denominator) : 0
            let height = minHeight + (maxHeight - minHeight) * gain
            let x = step * CGFloat(index) + (step - barWidth) / 2
            let y = (size.height - height) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: height)
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
            context.fill(path, with: .color(barColor(gain: gain)))
        }
    }

    private func barColor(gain: CGFloat) -> Color {
        if count <= 1 {
            return Color.primary.opacity(0.28)
        }
        if gain > 0.45 {
            return accent.opacity(0.45 + 0.55 * gain)
        }
        return Color.primary.opacity(0.22 + 0.18 * gain)
    }
}
