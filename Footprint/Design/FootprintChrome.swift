//
//  FootprintChrome.swift
//  Footprint
//
//  Atmosphere, glass cards, hairlines, capsule chrome (HealthUI stack).
//

import SwiftUI

enum FootprintChrome {
    static let atmosphereStripeSpacing: CGFloat = 11
    static let hairlineHeight: CGFloat = 0.5

    static func secondaryLabel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.62) : Color(red: 0.56, green: 0.56, blue: 0.58)
    }

    static func tertiaryLabel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.45) : Color(red: 0.56, green: 0.56, blue: 0.58).opacity(0.85)
    }

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }
}

struct FootprintDiagonalStripePattern: View {
    var lineColor: Color = .white
    var spacing: CGFloat = FootprintChrome.atmosphereStripeSpacing
    var lineWidth: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

struct FootprintAtmosphereBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var accent: Color = FootprintTheme.Accent.primary
    var secondaryAccent: Color = FootprintTheme.Accent.secondary

    var body: some View {
        GeometryReader { geo in
            Group {
                if colorScheme == .dark {
                    darkAtmosphere(size: geo.size)
                } else {
                    lightAtmosphere(size: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: accent)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: secondaryAccent)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: colorScheme)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func darkAtmosphere(size: CGSize) -> some View {
        ZStack {
            Color.black
            Ellipse()
                .fill(accent.opacity(0.18))
                .frame(width: size.width * 1.0, height: size.width * 0.7)
                .blur(radius: 48)
                .offset(x: size.width * 0.28, y: -size.height * 0.08)
            Ellipse()
                .fill(secondaryAccent.opacity(0.12))
                .frame(width: size.width * 0.85, height: size.width * 0.6)
                .blur(radius: 56)
                .offset(x: -size.width * 0.3, y: size.height * 0.22)
            Ellipse()
                .fill(accent.opacity(0.08))
                .frame(width: size.width * 0.95, height: size.width * 0.55)
                .blur(radius: 52)
                .offset(x: size.width * 0.05, y: size.height * 0.38)
            Ellipse()
                .fill(Color.white.opacity(0.04))
                .frame(width: size.width * 0.9, height: size.width * 0.5)
                .blur(radius: 40)
                .offset(x: 0, y: size.height * 0.55)
            FootprintDiagonalStripePattern(lineColor: .white, lineWidth: 1)
                .opacity(0.035)
        }
    }

    private func lightAtmosphere(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.96, green: 0.95, blue: 0.98)
            Ellipse()
                .fill(Color(red: 0.72, green: 0.88, blue: 0.98).opacity(0.55))
                .frame(width: size.width * 1.15, height: size.width * 0.85)
                .blur(radius: 52)
                .offset(x: -size.width * 0.2, y: -size.height * 0.12)
            Ellipse()
                .fill(Color(red: 0.78, green: 0.86, blue: 0.98).opacity(0.45))
                .frame(width: size.width * 1.0, height: size.width * 0.75)
                .blur(radius: 56)
                .offset(x: size.width * 0.35, y: size.height * 0.08)
            Ellipse()
                .fill(accent.opacity(0.18))
                .frame(width: size.width * 0.95, height: size.width * 0.7)
                .blur(radius: 48)
                .offset(x: size.width * 0.05, y: size.height * 0.42)
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: size.width * 0.9, height: size.width * 0.55)
                .blur(radius: 40)
                .offset(x: -size.width * 0.1, y: size.height * 0.62)
            FootprintDiagonalStripePattern(lineColor: .black, lineWidth: 1)
                .opacity(0.02)
        }
    }
}

struct FootprintCardHairline: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Rectangle()
            .fill(FootprintChrome.hairline(colorScheme))
            .frame(height: FootprintChrome.hairlineHeight)
            .accessibilityHidden(true)
    }
}

struct FootprintGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = FootprintTheme.Radius.card

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if colorScheme == .dark {
            darkGlass(shape: shape)
        } else {
            lightGlass(shape: shape)
        }
    }

    @ViewBuilder
    private func darkGlass(shape: RoundedRectangle) -> some View {
        if #available(iOS 26, *) {
            shape.fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
                .overlay { shape.fill(Color.black.opacity(0.22)) }
                .overlay { shape.strokeBorder(FootprintChrome.cardStroke(.dark), lineWidth: 0.5) }
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay { shape.fill(Color.black.opacity(0.28)) }
                .overlay { shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5) }
        }
    }

    @ViewBuilder
    private func lightGlass(shape: RoundedRectangle) -> some View {
        if #available(iOS 26, *) {
            shape.fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
                .overlay { shape.fill(Color.white.opacity(0.55)) }
                .overlay { shape.strokeBorder(FootprintChrome.cardStroke(.light), lineWidth: 0.5) }
                .shadow(color: Color.black.opacity(0.06), radius: 18, y: 8)
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay { shape.fill(Color.white.opacity(0.72)) }
                .overlay { shape.strokeBorder(FootprintChrome.cardStroke(.light), lineWidth: 0.5) }
                .shadow(color: Color.black.opacity(0.06), radius: 18, y: 8)
        }
    }
}

struct FootprintCapsuleChromeBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        if #available(iOS 26, *) {
            Capsule().fill(.clear).glassEffect(.regular.interactive(), in: Capsule())
        } else if colorScheme == .dark {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        } else {
            Capsule()
                .fill(Color.white.opacity(0.78))
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
        }
    }
}

private struct FootprintGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    var glowColor: Color?

    func body(content: Content) -> some View {
        content
            .background { FootprintGlassBackground(cornerRadius: cornerRadius) }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(alignment: .bottom) {
                if let glowColor {
                    Ellipse()
                        .fill(glowColor.opacity(colorScheme == .dark ? 0.55 : 0.22))
                        .frame(height: 36)
                        .blur(radius: 22)
                        .padding(.horizontal, 28)
                        .offset(y: 10)
                        .allowsHitTesting(false)
                }
            }
    }
}

private struct FootprintCapsuleChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background { FootprintCapsuleChromeBackground() }
    }
}

extension View {
    func footprintGlassCard(
        cornerRadius: CGFloat = FootprintTheme.Radius.card,
        glow: Color? = nil
    ) -> some View {
        modifier(FootprintGlassCardModifier(cornerRadius: cornerRadius, glowColor: glow))
    }

    func footprintCapsuleChrome() -> some View {
        modifier(FootprintCapsuleChromeModifier())
    }
}
