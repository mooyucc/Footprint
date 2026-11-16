//
//  TripTimelineLayoutGenerator.swift
//  Footprint
//
//  旅程分享：日程时间轴海报（按日叙事 + 氛围大图卡）
//

import SwiftUI
import UIKit

// MARK: - 日程时间轴版面生成器
struct TimelineLayoutGenerator: TripLayoutGenerator {

    private static let canvasBackground = UIColor(red: 0.969, green: 0.965, blue: 0.953, alpha: 1) // #F7F6F3
    private static let horizontalPadding: CGFloat = 20
    private static let timelineGutter: CGFloat = 28
    private static let cardSpacing: CGFloat = 14
    private static let headerBottom: CGFloat = 28
    private static let signatureTopGap: CGFloat = 28

    func generateImage(from trip: TravelTrip) -> UIImage? {
        let screenWidth = UIScreen.main.bounds.width
        let contentHeight = calculateContentHeight(for: trip, width: screenWidth)
        let imageSize = CGSize(width: screenWidth, height: contentHeight)

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = true
        rendererFormat.prefersExtendedRange = false

        let renderer = UIGraphicsImageRenderer(size: imageSize, format: rendererFormat)
        return renderer.image { context in
            let cgContext = context.cgContext
            Self.canvasBackground.setFill()
            cgContext.fill(CGRect(origin: .zero, size: imageSize))

            var currentY: CGFloat = 36
            currentY += drawHeader(for: trip, at: currentY, width: screenWidth, context: cgContext)
            currentY += Self.headerBottom

            let groups = dayGroups(for: trip)
            let contentLeft = Self.horizontalPadding
            let contentWidth = screenWidth - Self.horizontalPadding * 2
            let cardLeft = contentLeft + Self.timelineGutter
            let cardWidth = contentWidth - Self.timelineGutter
            let manyDays = groups.count >= 8
            let cardHeight: CGFloat = manyDays ? 140 : 168
            let maxTags = manyDays ? 2 : 3

            if groups.isEmpty {
                currentY += drawEmptyState(at: currentY, width: screenWidth, context: cgContext)
            } else {
                let axisX = contentLeft + 5
                let firstDotY = currentY + 10
                let lastCardBottom = currentY
                    + CGFloat(groups.count) * cardHeight
                    + CGFloat(max(groups.count - 1, 0)) * Self.cardSpacing
                drawTimelineAxis(
                    x: axisX,
                    fromY: firstDotY,
                    toY: lastCardBottom - 8,
                    context: cgContext
                )

                for (index, group) in groups.enumerated() {
                    let cardTop = currentY
                    drawTimelineDot(at: CGPoint(x: axisX, y: cardTop + 10), context: cgContext)
                    drawDayCard(
                        group: group,
                        at: CGPoint(x: cardLeft, y: cardTop),
                        width: cardWidth,
                        height: cardHeight,
                        maxTags: maxTags,
                        context: cgContext
                    )
                    currentY += cardHeight
                    if index < groups.count - 1 {
                        currentY += Self.cardSpacing
                    }
                }
            }

            currentY += Self.signatureTopGap
            drawSignature(at: CGPoint(x: screenWidth / 2, y: currentY), width: screenWidth - 40, context: cgContext)
        }
    }

    // MARK: - Height

    private func calculateContentHeight(for trip: TravelTrip, width: CGFloat) -> CGFloat {
        var height: CGFloat = 36
        height += measureHeaderHeight(for: trip, width: width)
        height += Self.headerBottom

        let groups = dayGroups(for: trip)
        if groups.isEmpty {
            height += 72
        } else {
            let cardHeight: CGFloat = groups.count >= 8 ? 140 : 168
            height += CGFloat(groups.count) * cardHeight
            height += CGFloat(max(groups.count - 1, 0)) * Self.cardSpacing
        }

        height += Self.signatureTopGap
        height += signatureBlockHeight(width: width - 40)
        height += 20
        return height
    }

    private func signatureBlockHeight(width: CGFloat) -> CGFloat {
        let signatureText = "trip_share_signature".localized
            .replacingOccurrences(of: "✨", with: "")
            .trimmingCharacters(in: .whitespaces)
        let signatureH = ceil(NSAttributedString(
            string: signatureText,
            attributes: [.font: UIFont.systemFont(ofSize: 14)]
        ).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height)
        let subtitleH = ceil(NSAttributedString(
            string: "trip_share_subtitle".localized,
            attributes: [.font: UIFont.systemFont(ofSize: 12)]
        ).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height)
        return signatureH + 25 + subtitleH
    }

    // MARK: - Header

    private func measureHeaderHeight(for trip: TravelTrip, width: CGFloat) -> CGFloat {
        let textWidth = width - Self.horizontalPadding * 2
        var h: CGFloat = 22 // decor icon
        h += 14
        h += ceil(titleAttributed(trip.name, width: textWidth).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height)
        let keywords = makeKeywords(for: trip)
        if !keywords.isEmpty {
            h += 10
            h += 20
        }
        h += 8
        h += 18 // date
        return h
    }

    @discardableResult
    private func drawHeader(for trip: TravelTrip, at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let brand = TripImageGenerator.tripShareBrandUIColor
        let textWidth = width - Self.horizontalPadding * 2
        var currentY = y

        if let icon = UIImage(systemName: "safari") {
            let size: CGFloat = 22
            let rect = CGRect(x: (width - size) / 2, y: currentY, width: size, height: size)
            icon.withTintColor(brand.withAlphaComponent(0.7), renderingMode: .alwaysOriginal).draw(in: rect)
        }
        currentY += 22 + 14

        // decorative waves under icon
        drawWaveDecoration(centerY: currentY - 8, width: width, color: brand.withAlphaComponent(0.22), context: context)

        let title = titleAttributed(trip.name, width: textWidth)
        let titleHeight = ceil(title.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height)
        title.draw(with: CGRect(x: Self.horizontalPadding, y: currentY, width: textWidth, height: titleHeight),
                   options: [.usesLineFragmentOrigin, .usesFontLeading],
                   context: nil)
        currentY += titleHeight

        let keywords = makeKeywords(for: trip)
        if !keywords.isEmpty {
            currentY += 10
            let keywordAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1)
            ]
            let keywordString = NSAttributedString(string: keywords.joined(separator: " · "), attributes: keywordAttrs)
            let keywordSize = keywordString.size()
            keywordString.draw(at: CGPoint(x: (width - keywordSize.width) / 2, y: currentY))
            currentY += 20
        }

        currentY += 8
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
        ]
        let dateText = NSAttributedString(string: formatDateRange(trip.startDate, trip.endDate), attributes: dateAttrs)
        let dateSize = dateText.size()
        dateText.draw(at: CGPoint(x: (width - dateSize.width) / 2, y: currentY))
        currentY += 18

        return currentY - y
    }

    private func titleAttributed(_ name: String, width: CGFloat) -> NSAttributedString {
        let brand = TripImageGenerator.tripShareBrandUIColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        brand.getRed(&r, green: &g, blue: &b, alpha: &a)
        let deep = UIColor(red: r * 0.55, green: g * 0.55, blue: b * 0.55, alpha: 1)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: name, attributes: [
            .font: UIFont.systemFont(ofSize: 30, weight: .bold),
            .foregroundColor: deep,
            .paragraphStyle: style
        ])
    }

    private func drawWaveDecoration(centerY: CGFloat, width: CGFloat, color: UIColor, context: CGContext) {
        let path = UIBezierPath()
        let startX = width * 0.28
        let endX = width * 0.72
        path.move(to: CGPoint(x: startX, y: centerY))
        let mid = (startX + endX) / 2
        path.addCurve(
            to: CGPoint(x: endX, y: centerY),
            controlPoint1: CGPoint(x: mid - 18, y: centerY - 5),
            controlPoint2: CGPoint(x: mid + 18, y: centerY + 5)
        )
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()
    }

    // MARK: - Keywords / Dates

    private func makeKeywords(for trip: TravelTrip) -> [String] {
        let sorted = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        var result: [String] = []
        var seen = Set<String>()

        for d in sorted {
            let province = d.province.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !province.isEmpty, !seen.contains(province) else { continue }
            seen.insert(province)
            result.append(province)
            if result.count >= 4 { return result }
        }

        for d in sorted {
            let name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            result.append(name)
            if result.count >= 4 { return result }
        }

        if result.isEmpty {
            let desc = trip.desc.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty {
                let clipped = desc.count > 20 ? String(desc.prefix(20)) + "…" : desc
                return [clipped]
            }
        }
        return result
    }

    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let calendar = Calendar.current
        let startY = calendar.component(.year, from: start)
        let endY = calendar.component(.year, from: end)
        let df = DateFormatter()
        df.locale = Locale(identifier: LanguageManager.shared.currentLanguage.rawValue)
        if startY == endY {
            df.dateFormat = "yyyy.MM.dd"
            let left = df.string(from: start)
            df.dateFormat = "MM.dd"
            let right = df.string(from: end)
            return "\(left) – \(right)"
        } else {
            df.dateFormat = "yyyy.MM.dd"
            return "\(df.string(from: start)) – \(df.string(from: end))"
        }
    }

    // MARK: - Timeline

    private func drawTimelineAxis(x: CGFloat, fromY: CGFloat, toY: CGFloat, context: CGContext) {
        guard toY > fromY else { return }
        let brand = TripImageGenerator.tripShareBrandUIColor
        context.saveGState()
        context.setStrokeColor(brand.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: x, y: fromY))
        context.addLine(to: CGPoint(x: x, y: toY))
        context.strokePath()
        context.restoreGState()
    }

    private func drawTimelineDot(at point: CGPoint, context: CGContext) {
        let brand = TripImageGenerator.tripShareBrandUIColor
        let radius: CGFloat = 5
        context.saveGState()
        context.setFillColor(brand.cgColor)
        context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        context.setStrokeColor(Self.canvasBackground.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: point.x - radius - 1, y: point.y - radius - 1, width: (radius + 1) * 2, height: (radius + 1) * 2))
        context.restoreGState()
    }

    // MARK: - Day card

    private func drawDayCard(
        group: (dayIndex: Int, dayStart: Date, destinations: [TravelDestination]),
        at point: CGPoint,
        width: CGFloat,
        height: CGFloat,
        maxTags: Int,
        context: CGContext
    ) {
        let cardRect = CGRect(x: point.x, y: point.y, width: width, height: height)
        let cornerRadius: CGFloat = 16
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)

        context.saveGState()
        context.addPath(path.cgPath)
        context.clip()

        let hero = pickHero(from: group.destinations)
        if let image = hero.image {
            drawAspectFill(image, in: cardRect)
        } else {
            drawBrandGradient(in: cardRect, context: context)
        }

        // left-to-right dark gradient for text legibility
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor.black.withAlphaComponent(0.55).cgColor,
            UIColor.black.withAlphaComponent(0.15).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.55, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: cardRect.minX, y: cardRect.midY),
                end: CGPoint(x: cardRect.maxX, y: cardRect.midY),
                options: []
            )
        }
        context.restoreGState()

        // soft shadow outline
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        context.setStrokeColor(UIColor.clear.cgColor)
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()

        let textLeft = cardRect.minX + 16
        let textWidth = cardRect.width * 0.58
        var textY = cardRect.minY + 14

        let dayLabel = dayLabelText(dayIndex: group.dayIndex, dayStart: group.dayStart)
        let dayAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        NSAttributedString(string: dayLabel, attributes: dayAttrs).draw(at: CGPoint(x: textLeft, y: textY))
        textY += 22

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.lineBreakMode = .byTruncatingTail
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: titleStyle
        ]
        let title = NSAttributedString(string: hero.title, attributes: titleAttrs)
        title.draw(with: CGRect(x: textLeft, y: textY, width: textWidth, height: 28),
                   options: [.usesLineFragmentOrigin, .usesFontLeading],
                   context: nil)
        textY += 32

        let tags = makeTags(for: group.destinations, heroName: hero.title, maxTags: maxTags)
        if !tags.isEmpty {
            drawTags(tags, at: CGPoint(x: textLeft, y: textY), maxWidth: textWidth, context: context)
        }
    }

    private func pickHero(from destinations: [TravelDestination]) -> (title: String, image: UIImage?) {
        for d in destinations {
            if let data = d.photoData ?? d.photoThumbnailData ?? d.photoDatas.first ?? d.photoThumbnailDatas.first,
               let image = UIImage(data: data) {
                return (d.name, image)
            }
        }
        let title = destinations.first?.name ?? ""
        return (title, nil)
    }

    private func makeTags(for destinations: [TravelDestination], heroName: String, maxTags: Int) -> [String] {
        let others = destinations
            .filter { $0.name != heroName }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if others.isEmpty, let first = destinations.first {
            let type = first.localizedType
            if !type.isEmpty { return [type] }
            let province = first.province.trimmingCharacters(in: .whitespacesAndNewlines)
            if !province.isEmpty { return [province] }
            return []
        }

        guard others.count > maxTags else { return others }
        var tags = Array(others.prefix(maxTags - 1))
        tags.append("+\(others.count - (maxTags - 1))")
        return tags
    }

    private func drawTags(_ tags: [String], at point: CGPoint, maxWidth: CGFloat, context: CGContext) {
        var x = point.x
        let y = point.y
        let spacing: CGFloat = 6
        for tag in tags {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let text = NSAttributedString(string: tag, attributes: attrs)
            let textSize = text.size()
            let pillW = min(textSize.width + 16, 88)
            let pillH: CGFloat = 22
            if x + pillW - point.x > maxWidth { break }

            let pillRect = CGRect(x: x, y: y, width: pillW, height: pillH)
            let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2)
            context.saveGState()
            context.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
            context.addPath(pillPath.cgPath)
            context.fillPath()
            context.restoreGState()

            let textX = x + (pillW - min(textSize.width, pillW - 10)) / 2
            let clipped = NSMutableAttributedString(attributedString: text)
            if textSize.width > pillW - 10 {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail
                clipped.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: clipped.length))
                clipped.draw(with: CGRect(x: x + 8, y: y + (pillH - textSize.height) / 2, width: pillW - 16, height: textSize.height),
                             options: [.usesLineFragmentOrigin],
                             context: nil)
            } else {
                text.draw(at: CGPoint(x: textX, y: y + (pillH - textSize.height) / 2))
            }
            x += pillW + spacing
        }
    }

    private func dayLabelText(dayIndex: Int, dayStart: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: LanguageManager.shared.currentLanguage.rawValue)
        df.dateFormat = "M.d"
        return String(format: "trip_route_day_title".localized, dayIndex, df.string(from: dayStart))
    }

    private func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        let imageAspect = image.size.width / max(image.size.height, 1)
        let rectAspect = rect.width / max(rect.height, 1)
        var drawRect = rect
        if imageAspect > rectAspect {
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(x: rect.midX - scaledWidth / 2, y: rect.minY, width: scaledWidth, height: rect.height)
        } else {
            let scaledHeight = rect.width / imageAspect
            drawRect = CGRect(x: rect.minX, y: rect.midY - scaledHeight / 2, width: rect.width, height: scaledHeight)
        }
        image.draw(in: drawRect)
    }

    private func drawBrandGradient(in rect: CGRect, context: CGContext) {
        let brand = TripImageGenerator.tripShareBrandUIColor
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [brand.cgColor, brand.withAlphaComponent(0.55).cgColor] as CFArray,
            locations: [0, 1]
        )!
        context.saveGState()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
        context.restoreGState()
    }

    // MARK: - Empty / Signature

    private func drawEmptyState(at y: CGFloat, width: CGFloat, context: CGContext) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        ]
        let text = NSAttributedString(string: "trip_share_no_destinations".localized, attributes: attrs)
        let size = text.size()
        text.draw(at: CGPoint(x: (width - size.width) / 2, y: y + 24))
        return 72
    }

    private func drawSignature(at point: CGPoint, width: CGFloat, context: CGContext) {
        let appIcon: UIImage? = {
            if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let lastIcon = iconFiles.last {
                return UIImage(named: lastIcon)
            }
            return UIImage(named: "AppIcon")
        }()

        let signatureText = "trip_share_signature".localized
            .replacingOccurrences(of: "✨", with: "")
            .replacingOccurrences(of: "✨ ", with: "")
            .trimmingCharacters(in: .whitespaces)

        let signatureAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let signatureString = NSAttributedString(string: signatureText, attributes: signatureAttributes)
        let signatureSize = signatureString.size()
        let iconSize: CGFloat = 20
        let iconSpacing: CGFloat = 6
        let totalWidth = iconSize + iconSpacing + signatureSize.width

        if let appIcon {
            let iconRect = CGRect(
                x: point.x - totalWidth / 2,
                y: point.y + (signatureSize.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            context.saveGState()
            context.addPath(UIBezierPath(ovalIn: iconRect).cgPath)
            context.clip()
            appIcon.draw(in: iconRect)
            context.restoreGState()
        }

        signatureString.draw(at: CGPoint(x: point.x - totalWidth / 2 + iconSize + iconSpacing, y: point.y))

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        ]
        let subtitleString = NSAttributedString(string: "trip_share_subtitle".localized, attributes: subtitleAttributes)
        let subtitleSize = subtitleString.size()
        subtitleString.draw(at: CGPoint(x: point.x - subtitleSize.width / 2, y: point.y + 25))
    }

    // MARK: - Day groups

    private func dayGroups(for trip: TravelTrip) -> [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] {
        let sorted = trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
        guard !sorted.isEmpty else { return [] }
        let calendar = Calendar.current
        var groups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] = []
        var currentDayStart: Date?
        var currentList: [TravelDestination] = []
        for d in sorted {
            let dayStart = calendar.startOfDay(for: d.visitDate)
            if dayStart != currentDayStart {
                if let prev = currentDayStart {
                    groups.append((groups.count + 1, prev, currentList))
                }
                currentDayStart = dayStart
                currentList = [d]
            } else {
                currentList.append(d)
            }
        }
        if let last = currentDayStart {
            groups.append((groups.count + 1, last, currentList))
        }
        return groups
    }
}
