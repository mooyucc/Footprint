//
//  ProvinceTicketCard.swift
//  Footprint
//
//  省份徽章票根：彩底、地点照片、底部半圆缺口。
//

import SwiftUI
import UIKit

enum ProvinceTicketMetrics {
    /// 底色格子宽 : 高 = 3 : 4
    static let aspect: CGFloat = 3.0 / 4.0
}

struct ProvinceTicketPalette {
    var ground: Color
    var paper: Color
}

struct ProvinceTicketFace: Equatable {
    var provinceName: String
    var placeName: String
    var latinLines: String
    var dateText: String
    var serialText: String
    var sideCode: String
    var barcodeSeed: UInt64
    var destinationId: UUID?
    var thumbnailData: Data?
    var fullData: Data?
    var paletteIndex: Int
}

enum ProvinceTicketPicker {
    /// 没有照片时按省份名轮换色相：青绿、铁锈、橄榄、蓝、棕、灰蓝。
    private static let paletteHues: [CGFloat] = [
        0.51, 0.06, 0.15, 0.33, 0.60, 0.07, 0.09, 0.56, 0.43
    ]

    /// 各省封面地点：进程内缓存。冷启动为空会随机抽；热启动复用，避免换图。
    @MainActor
    private static var preferredDestinationIDs: [String: UUID] = [:]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy - MM"
        return formatter
    }()

    static func placeholder(seed: String) -> ProvinceTicketFace {
        face(seed: seed, destinations: [])
    }

    /// 同一色相的深底和浅票。缺口挖开浅票后露出深底。
    static func colors(for image: UIImage?, paletteIndex: Int) -> ProvinceTicketPalette {
        let sampled: (ground: Color, paper: Color)
        if let image, let pair = pair(from: image) {
            sampled = pair
        } else {
            let count = paletteHues.count
            let index = ((paletteIndex % count) + count) % count
            sampled = pair(hue: paletteHues[index], saturation: 0.62)
        }
        return ProvinceTicketPalette(ground: sampled.ground, paper: sampled.paper)
    }

    /// 冷启动随机抽一张有图地点；同进程内复用，热启动不换图。编号/色板仍按省名稳定。
    @MainActor
    static func face(seed: String, destinations: [TravelDestination]) -> ProvinceTicketFace {
        let hash = BadgeTicketBarcodeSeed.make(seed)
        let candidates = destinations.filter(hasPhoto)
        let picked = pickDestination(seed: seed, candidates: candidates)

        let dateText = picked.map { dateFormatter.string(from: $0.visitDate) } ?? ""

        return ProvinceTicketFace(
            provinceName: seed,
            placeName: seed,
            latinLines: latin(from: seed),
            dateText: dateText,
            serialText: String(format: "NO.%05d", Int(hash % 100_000)),
            sideCode: String(format: "%08X", UInt32(truncatingIfNeeded: hash)),
            barcodeSeed: hash == 0 ? 1 : hash,
            destinationId: picked?.id,
            thumbnailData: picked.flatMap(thumbnailData),
            fullData: picked.flatMap(fullData),
            paletteIndex: Int(hash % UInt64(paletteHues.count))
        )
    }

    @MainActor
    private static func pickDestination(
        seed: String,
        candidates: [TravelDestination]
    ) -> TravelDestination? {
        guard !candidates.isEmpty else {
            preferredDestinationIDs.removeValue(forKey: seed)
            return nil
        }
        if let preferred = preferredDestinationIDs[seed],
           let match = candidates.first(where: { $0.id == preferred }) {
            return match
        }
        let picked = candidates.randomElement()
        if let picked {
            preferredDestinationIDs[seed] = picked.id
        } else {
            preferredDestinationIDs.removeValue(forKey: seed)
        }
        return picked
    }

    private static func hasPhoto(_ destination: TravelDestination) -> Bool {
        thumbnailData(destination) != nil || fullData(destination) != nil
    }

    private static func thumbnailData(_ destination: TravelDestination) -> Data? {
        if let first = destination.photoThumbnailDatas.first, !first.isEmpty { return first }
        if let data = destination.photoThumbnailData, !data.isEmpty { return data }
        return nil
    }

    private static func fullData(_ destination: TravelDestination) -> Data? {
        if let first = destination.photoDatas.first, !first.isEmpty { return first }
        if let data = destination.photoData, !data.isEmpty { return data }
        return nil
    }

    private static func latin(from text: String) -> String {
        let transformed = text.applyingTransform(.toLatin, reverse: false) ?? text
        let stripped = transformed.applyingTransform(.stripDiacritics, reverse: false) ?? transformed
        return String(stripped.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func pair(from image: UIImage) -> (ground: Color, paper: Color)? {
        guard let ui = ImageProcessor.dominantColor(from: image) else { return nil }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        guard ui.getHue(&hue, saturation: &saturation, brightness: nil, alpha: nil) else {
            return nil
        }
        return pair(hue: hue, saturation: saturation)
    }

    private static func pair(hue: CGFloat, saturation: CGFloat) -> (ground: Color, paper: Color) {
        let groundSat = min(0.48, max(0.28, saturation * 0.75))
        let paperSat = min(0.62, max(0.42, saturation * 0.9))
        let ground = Color(hue: Double(hue), saturation: Double(groundSat), brightness: 0.40)
        let paper = Color(hue: Double(hue), saturation: Double(paperSat), brightness: 0.62)
        return (ground, paper)
    }
}

/// 网格上的一张成品票。照片和底色在放进列表前就算好，滚动时不再改状态。
struct ProvinceTicketReady {
    var face: ProvinceTicketFace
    var image: UIImage?
    var palette: ProvinceTicketPalette
}

struct ProvinceTicketTile: View {
    let face: ProvinceTicketFace
    let image: UIImage?
    let palette: ProvinceTicketPalette
    let side: CGFloat

    private var cellSize: CGSize {
        CGSize(width: side, height: side / ProvinceTicketMetrics.aspect)
    }

    var body: some View {
        ProvinceTicketCard(
            face: face,
            image: image,
            palette: palette,
            size: cellSize,
            showsGround: false,
            outerInsetRatio: 0.10
        )
        .frame(width: cellSize.width, height: cellSize.height)
        .clipped()
        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
        .accessibilityHidden(true)
    }
}

/// 徽章详情里的大票。地点列表由外面传入，避免再查一次。
struct ProvinceTicketDetail: View {
    let seed: String
    let destinations: [TravelDestination]
    let size: CGSize
    var isUnlocked: Bool = true
    var onGroundChange: (Color) -> Void = { _ in }

    @State private var image: UIImage?
    @State private var palette: ProvinceTicketPalette?

    private var face: ProvinceTicketFace {
        ProvinceTicketPicker.face(seed: seed, destinations: destinations)
    }

    private var shownPalette: ProvinceTicketPalette {
        palette ?? ProvinceTicketPicker.colors(for: nil, paletteIndex: face.paletteIndex)
    }

    var body: some View {
        ProvinceTicketCard(
            face: face,
            image: image,
            palette: shownPalette,
            size: size,
            isUnlocked: isUnlocked,
            castsShadow: true
        )
            .task(id: face.destinationId) {
                guard let id = face.destinationId else {
                    image = nil
                    palette = nil
                    onGroundChange(ProvinceTicketPicker.colors(for: nil, paletteIndex: face.paletteIndex).ground)
                    return
                }
                let loaded = await DestinationThumbnailCache.shared.imageForTimeCapsuleCover(
                    for: id,
                    fullData: face.fullData,
                    thumbnailData: face.thumbnailData
                )
                image = loaded
                let next = ProvinceTicketPicker.colors(for: loaded, paletteIndex: face.paletteIndex)
                palette = next
                onGroundChange(next.ground)
            }
    }
}

struct ProvinceTicketCard: View {
    let face: ProvinceTicketFace
    let image: UIImage?
    let palette: ProvinceTicketPalette
    let size: CGSize
    var isUnlocked: Bool = true
    var castsShadow: Bool = false
    var shadowStrength: CGFloat = 1
    /// 详情大票铺底色，缺口处透出；网格小票不铺。
    var showsGround: Bool = true
    /// 相对外框的留白比例；网格小票用 0.10，详情大票为 0（铺满）。
    var outerInsetRatio: CGFloat = 0

    var body: some View {
        let inset = size.width * outerInsetRatio
        let ticketSize = CGSize(
            width: max(0, size.width - inset * 2),
            height: max(0, size.height - inset * 2.15)
        )
        groundFill
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .top) {
                ticket(in: ticketSize, paper: palette.paper)
                    .padding(.top, inset)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var groundFill: some View {
        if showsGround {
            palette.ground
        } else {
            Color.clear
        }
    }

    private var accessibilityText: String {
        [face.placeName, face.latinLines, face.dateText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    @ViewBuilder
    private func ticket(in size: CGSize, paper: Color) -> some View {
        let width = size.width
        let inset = width * 0.055
        let notch = width * 0.09
        let corner = width * 0.08
        let placeSize = max(12, width * 0.095)
        let latinSize = max(9, width * 0.062)
        let dateSize = max(8, width * 0.042)
        let serialSize = max(7, width * 0.034)
        let photoHeight = size.height * 0.58

        let card = VStack(spacing: 0) {
            photo
                .frame(width: width, height: photoHeight)
                .clipped()

            Spacer(minLength: 2)

            infoRow(
                placeSize: placeSize,
                latinSize: latinSize,
                dateSize: dateSize,
                serialSize: serialSize,
                barcodeWidth: width * 0.28
            )
            .padding(.horizontal, inset)

            Color.clear
                .frame(height: notch * 0.85)
        }
        .frame(width: size.width, height: size.height)
        .background(paper)
        .overlay(alignment: .top) {
            ProvinceTicketPerforation()
                .stroke(
                    Color.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3.5, 3.5])
                )
                .frame(height: 1)
                .padding(.horizontal, inset)
                .offset(y: photoHeight)
        }
        .clipShape(
            ProvinceTicketShape(cornerRadius: corner, notchRadius: notch),
            style: FillStyle(eoFill: true)
        )
        .saturation(isUnlocked ? 1 : 0)
        .opacity(isUnlocked ? 1 : 0.72)

        if castsShadow {
            let scale = min(1, max(0.55, width / 240))
            card
                .shadow(color: .black.opacity(0.45 * shadowStrength), radius: 10 * scale, x: 0, y: 5 * scale)
                .shadow(color: .black.opacity(0.40 * shadowStrength), radius: 26 * scale, x: 0, y: 16 * scale)
        } else {
            card
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
        } else {
            Color.white.opacity(0.14)
        }
    }

    private func infoRow(
        placeSize: CGFloat,
        latinSize: CGFloat,
        dateSize: CGFloat,
        serialSize: CGFloat,
        barcodeWidth: CGFloat
    ) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            VStack(alignment: .leading, spacing: placeSize * 0.08) {
                Text(face.placeName)
                    .font(.system(size: placeSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !face.latinLines.isEmpty {
                    Text(face.latinLines)
                        .font(.system(size: latinSize, weight: .bold))
                        .tracking(0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                if !face.dateText.isEmpty {
                    Text(face.dateText)
                        .font(.system(size: dateSize, weight: .medium))
                        .monospacedDigit()
                        .padding(.top, placeSize * 0.2)
                }
                Text(face.serialText)
                    .font(.system(size: serialSize, weight: .medium))
                    .monospacedDigit()
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(face.sideCode)
                    .font(.system(size: max(6, serialSize * 0.85), weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                BadgeTicketBarcode(seed: face.barcodeSeed, ink: .white)
                    .frame(width: barcodeWidth, height: max(14, dateSize * 2.1))
            }
        }
    }
}

private struct ProvinceTicketPerforation: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

private struct ProvinceTicketShape: Shape {
    var cornerRadius: CGFloat
    var notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        path.addEllipse(in: CGRect(
            x: rect.midX - notchRadius,
            y: rect.maxY - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        ))
        return path
    }
}
