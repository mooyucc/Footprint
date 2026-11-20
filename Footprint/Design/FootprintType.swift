//
//  FootprintType.swift
//  Footprint
//
//  阅读文字和计数都用系统默认字形，地图与分享画布用固定字号。
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum FootprintType {
    static let section = Font.headline.weight(.semibold)
    static let cardKicker = Font.subheadline.weight(.semibold)
    static let row = Font.body.weight(.medium)
    static let body = Font.body
    static let secondary = Font.subheadline
    static let caption = Font.caption
    static let chip = Font.subheadline.weight(.semibold)

    /// 统计主数字。默认字号等于系统 largeTitle（34pt）。
    static let metricHero = Font.system(.largeTitle).weight(.black)
    /// 环心等主计数。默认字号等于系统 title（28pt）。
    static let metric = Font.system(.title).weight(.bold)
    /// 小角标计数。默认字号等于系统 caption2（11pt）。
    static let metricCompact = Font.system(.caption2).weight(.bold)

    /// 必须跟着容器缩放时用，字形与正文相同。
    static func metric(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    /// 画在地图上的固定字号。不跟随动态字体，避免标注互相遮挡。
    enum Map {
        static let title = Font.system(size: 13, weight: .semibold)
        static let date = Font.system(size: 10, weight: .medium)
        static let note = Font.system(size: 11, weight: .regular)
        static let clusterNote = Font.system(size: 13, weight: .regular)
        static let distance = Font.system(size: 11, weight: .semibold)
        static let distanceIcon = Font.system(size: 10, weight: .medium)
    }

#if canImport(UIKit)
    /// 分享图按画布像素取字，不进 SwiftUI 文本样式。
    enum Share {
        static func title(size: CGFloat) -> UIFont {
            .systemFont(ofSize: size, weight: .bold)
        }

        static func caption(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withDesign(.serif) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        }

        static func meta(size: CGFloat) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: .regular)
            if let descriptor = base.fontDescriptor.withDesign(.monospaced) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
#endif
}

extension View {
    func footprintMetricHero() -> some View {
        font(FootprintType.metricHero)
            .monospacedDigit()
            .tracking(-1)
    }

    func footprintMetric() -> some View {
        font(FootprintType.metric)
            .monospacedDigit()
    }

    func footprintMetricCompact() -> some View {
        font(FootprintType.metricCompact)
            .monospacedDigit()
    }

    func footprintMetric(size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        font(FootprintType.metric(size: size, weight: weight))
            .monospacedDigit()
    }
}
