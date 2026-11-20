//
//  ProfileThemePalette.swift
//  Footprint
//
//  身份与星座对应的强调色。只提供已核对过的色值，不按属性计算 RGB。
//

import SwiftUI
import UIKit

struct ProfileThemeSuggestion: Identifiable {
    enum Source: String {
        case persona
        case constellation
    }

    let source: Source
    let attributeKey: String
    let red: Double
    let green: Double
    let blue: Double

    var id: String { "\(source.rawValue).\(attributeKey)" }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var sourceTitle: String {
        switch source {
        case .persona:
            return "theme_source_persona".localized
        case .constellation:
            return "theme_source_constellation".localized
        }
    }

    var attributeName: String {
        switch source {
        case .persona:
            return UserProfileOptions.localizedPersona(for: attributeKey)
        case .constellation:
            return UserProfileOptions.localizedConstellation(for: attributeKey)
        }
    }
}

enum ProfileThemePalette {
    static func suggestions(personaKey: String, constellationKey: String) -> [ProfileThemeSuggestion] {
        var result: [ProfileThemeSuggestion] = []
        if let persona = personaColors[personaKey] {
            result.append(suggestion(source: .persona, key: personaKey, rgb: persona))
        }
        if let constellation = constellationColors[constellationKey] {
            result.append(suggestion(source: .constellation, key: constellationKey, rgb: constellation))
        }
        return result
    }

    static func matches(_ color: Color, brand: Color) -> Bool {
        guard let lhs = components(of: color), let rhs = components(of: brand) else { return false }
        let tolerance: CGFloat = 0.02
        return abs(lhs.0 - rhs.0) < tolerance
            && abs(lhs.1 - rhs.1) < tolerance
            && abs(lhs.2 - rhs.2) < tolerance
    }

    private static func suggestion(
        source: ProfileThemeSuggestion.Source,
        key: String,
        rgb: (Double, Double, Double)
    ) -> ProfileThemeSuggestion {
        ProfileThemeSuggestion(
            source: source,
            attributeKey: key,
            red: rgb.0,
            green: rgb.1,
            blue: rgb.2
        )
    }

    private static func components(of color: Color) -> (CGFloat, CGFloat, CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (red, green, blue)
    }

    /// 旅行身份色。自定义和「不愿透露」没有对应色。
    private static let personaColors: [String: (Double, Double, Double)] = [
        "traveler": (0 / 255, 161 / 255, 216 / 255),
        "hiker": (46 / 255, 125 / 255, 79 / 255),
        "photographer": (196 / 255, 122 / 255, 34 / 255),
        "designer": (91 / 255, 77 / 255, 199 / 255),
        "foodie": (225 / 255, 90 / 255, 69 / 255),
        "techie": (12 / 255, 140 / 255, 156 / 255)
    ]

    /// 星座色，作为第二套可选强调色。
    private static let constellationColors: [String: (Double, Double, Double)] = [
        "aries": (214 / 255, 69 / 255, 69 / 255),
        "taurus": (47 / 255, 143 / 255, 85 / 255),
        "gemini": (196 / 255, 146 / 255, 10 / 255),
        "cancer": (78 / 255, 110 / 255, 140 / 255),
        "leo": (224 / 255, 138 / 255, 30 / 255),
        "virgo": (107 / 255, 124 / 255, 58 / 255),
        "libra": (196 / 255, 91 / 255, 134 / 255),
        "scorpio": (142 / 255, 47 / 255, 75 / 255),
        "sagittarius": (122 / 255, 78 / 255, 171 / 255),
        "capricorn": (74 / 255, 85 / 255, 96 / 255),
        "aquarius": (46 / 255, 123 / 255, 196 / 255),
        "pisces": (31 / 255, 138 / 255, 128 / 255)
    ]
}

struct OnboardingStepDots: View {
    let count: Int
    let activeIndex: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? activeColor : Color(.systemGray4))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}
