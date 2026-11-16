//
//  AllDestinationsListView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI
import SwiftData

struct AllDestinationsListView: View {
    /// 若传入则只浏览该子集；nil 表示全量 @Query
    private let scopedDestinations: [TravelDestination]?
    private let availableBrowseModes: [DestinationBrowseMode]
    private let navigationTitleText: String
    private let showsDismissButton: Bool
    /// 嵌入父视图时不包 NavigationStack / 氛围底 / 关闭按钮
    private let isEmbedded: Bool
    
    @Query(sort: \TravelDestination.visitDate, order: .reverse) private var queriedDestinations: [TravelDestination]
    @State private var searchText = ""
    @State private var browseMode: DestinationBrowseMode
    @State private var selectedGroupKey: String? = nil
    @State private var editingDestination: TravelDestination?
    @State private var detailDestination: TravelDestination?
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    private var calendar: Calendar { .current }
    
    init(
        scopedDestinations: [TravelDestination]? = nil,
        title: String? = nil,
        availableBrowseModes: [DestinationBrowseMode] = DestinationBrowseMode.allCases,
        initialBrowseMode: DestinationBrowseMode? = nil,
        showsDismissButton: Bool = true,
        isEmbedded: Bool = false
    ) {
        self.scopedDestinations = scopedDestinations
        let modes = availableBrowseModes.isEmpty ? DestinationBrowseMode.allCases : availableBrowseModes
        self.availableBrowseModes = modes
        self.navigationTitleText = title ?? "all_destinations".localized
        self.showsDismissButton = showsDismissButton
        self.isEmbedded = isEmbedded
        let initial = initialBrowseMode.flatMap { modes.contains($0) ? $0 : nil } ?? modes[0]
        _browseMode = State(initialValue: initial)
    }
    
    private var sourceDestinations: [TravelDestination] {
        scopedDestinations ?? queriedDestinations
    }
    
    /// 搜索 + 收藏维度后的基础集合
    private var baseFilteredDestinations: [TravelDestination] {
        var result = sourceDestinations
        
        if !searchText.isEmpty {
            result = result.filter { destination in
                destination.name.localizedCaseInsensitiveContains(searchText) ||
                destination.country.localizedCaseInsensitiveContains(searchText) ||
                destination.province.localizedCaseInsensitiveContains(searchText) ||
                destination.notes.localizedCaseInsensitiveContains(searchText) ||
                destination.localizedType.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if browseMode == .favorites {
            result = result.filter(\.isFavorite)
        }
        
        return result
    }
    
    private var indexGroups: [DestinationIndexGroup] {
        switch browseMode {
        case .region:
            return regionGroups(from: baseFilteredDestinations)
        case .favorites:
            // 无「地区」模式时（如徽章范围），收藏也按年份分组，避免单国家只剩一组
            if availableBrowseModes.contains(.region) {
                return regionGroups(from: baseFilteredDestinations)
            }
            return yearGroups(from: baseFilteredDestinations)
        case .year:
            return yearGroups(from: baseFilteredDestinations)
        }
    }
    
    private var collapsesRingOverflow: Bool {
        switch browseMode {
        case .year:
            return true
        case .favorites:
            return !availableBrowseModes.contains(.region)
        case .region:
            return false
        }
    }
    
    private var ringSegments: [DestinationRingSegment] {
        DestinationFootprintRingBuilder.segments(
            from: indexGroups,
            accent: brandColorManager.currentBrandColor,
            collapsesOverflow: collapsesRingOverflow
        )
    }
    
    private var displayedGroups: [DestinationIndexGroup] {
        guard let selectedGroupKey else { return indexGroups }
        
        if selectedGroupKey == DestinationFootprintRingBuilder.otherKey {
            let topKeys = Set(ringSegments.filter { $0.id != DestinationFootprintRingBuilder.otherKey }.map(\.id))
            let rest = indexGroups.filter { !topKeys.contains($0.id) }
            if rest.isEmpty { return [] }
            return [
                DestinationIndexGroup(
                    id: DestinationFootprintRingBuilder.otherKey,
                    title: "destinations_ring_other".localized,
                    systemImage: "ellipsis.circle.fill",
                    accentHint: nil,
                    destinations: rest.flatMap(\.destinations).sorted { $0.visitDate > $1.visitDate }
                )
            ]
        }
        
        return indexGroups.filter { $0.id == selectedGroupKey }
    }
    
    private var displayedDestinationCount: Int {
        displayedGroups.reduce(0) { $0 + $1.destinations.count }
    }
    
    var body: some View {
        Group {
            if isEmbedded {
                listScrollContent
            } else {
                NavigationStack {
                    ZStack {
                        FootprintAtmosphereBackground(
                            accent: brandColorManager.currentBrandColor,
                            secondaryAccent: FootprintTheme.Accent.secondary
                        )
                        
                        listScrollContent
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationTitle(navigationTitleText)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if showsDismissButton {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $detailDestination) { destination in
            NavigationStack {
                DestinationDetailView(destination: destination)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingDestination) { destination in
            EditDestinationView(destination: destination)
        }
        .onChange(of: browseMode) { _, _ in
            selectedGroupKey = nil
        }
        .onChange(of: searchText) { _, _ in
            selectedGroupKey = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { notification in
            if let userInfo = notification.userInfo,
               let deletedDestinationId = userInfo["destinationId"] as? UUID {
                if let editing = editingDestination, editing.id == deletedDestinationId {
                    editingDestination = nil
                }
                if let detail = detailDestination, detail.id == deletedDestinationId {
                    detailDestination = nil
                }
            } else {
                if editingDestination != nil {
                    editingDestination = nil
                }
                if detailDestination != nil {
                    detailDestination = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
        .id(refreshID)
    }
    
    private var listScrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if availableBrowseModes.count > 1 {
                    browseModeChipRow
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                        .font(.subheadline)
                    
                    TextField("search_places_countries_notes".localized, text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .footprintCapsuleChrome()
                
                if !baseFilteredDestinations.isEmpty {
                    DestinationFootprintRingCard(
                        segments: ringSegments,
                        totalCount: baseFilteredDestinations.count,
                        selection: $selectedGroupKey,
                        accent: brandColorManager.currentBrandColor
                    )
                    
                    summaryHeader
                    
                    ForEach(displayedGroups) { group in
                        indexGroupCard(group)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: browseMode == .favorites ? "heart.slash" : "location.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                        Text(
                            browseMode == .favorites
                                ? "destinations_no_favorites".localized
                                : "no_destinations_found".localized
                        )
                        .font(.headline)
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, isEmbedded ? 0 : 8)
            .padding(.bottom, 28)
        }
        .contentMargins(.vertical, isEmbedded ? 8 : 16, for: .scrollContent)
    }
    
    private var browseModeChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableBrowseModes) { mode in
                    let isSelected = browseMode == mode
                    Button {
                        browseMode = mode
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule().fill(brandColorManager.currentBrandColor)
                                } else {
                                    FootprintCapsuleChromeBackground()
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var groupCountUnitText: String {
        switch browseMode {
        case .region:
            return "stats_share_countries_count".localized
        case .year:
            return "destinations_group_unit_years".localized
        case .favorites:
            return availableBrowseModes.contains(.region)
                ? "stats_share_countries_count".localized
                : "destinations_group_unit_years".localized
        }
    }
    
    private var summaryHeader: some View {
        HStack(spacing: 8) {
            Text(
                String(
                    format: "journey_cards_destinations_count".localized,
                    displayedDestinationCount
                )
                + " · "
                + "\(displayedGroups.count) "
                + groupCountUnitText
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
            
            if selectedGroupKey != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGroupKey = nil
                    }
                } label: {
                    Text("destinations_clear_ring_filter".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(brandColorManager.currentBrandColor)
                }
                .buttonStyle(.plain)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private func indexGroupCard(_ group: DestinationIndexGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let systemImage = group.systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(brandColorManager.currentBrandColor)
                }
                
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("\(group.destinations.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(brandColorManager.currentBrandColor.opacity(0.12)))
                
                Spacer(minLength: 0)
                
                if let accentHint = group.accentHint {
                    Image(systemName: accentHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(brandColorManager.currentBrandColor.opacity(0.85))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            FootprintCardHairline()
                .padding(.horizontal, 16)
            
            ForEach(Array(group.destinations.enumerated()), id: \.element.id) { index, destination in
                Button {
                    detailDestination = destination
                } label: {
                    AllDestinationsIndexRow(destination: destination, showsCountry: browseMode != .region)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editingDestination = destination
                    } label: {
                        Label("edit".localized, systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        deleteDestination(destination)
                    } label: {
                        Label("delete".localized, systemImage: "trash")
                    }
                }
                
                if index < group.destinations.count - 1 {
                    FootprintCardHairline()
                        .padding(.leading, 78)
                        .padding(.trailing, 16)
                }
            }
        }
        .padding(.bottom, 6)
        .footprintGlassCard(cornerRadius: 18)
    }
    
    private func regionGroups(from destinations: [TravelDestination]) -> [DestinationIndexGroup] {
        let grouped = Dictionary(grouping: destinations) { destination in
            destination.country.isEmpty ? "_" : destination.country
        }
        
        return grouped.map { key, items in
            let sorted = items.sorted { $0.visitDate > $1.visitDate }
            let title = key == "_"
                ? "—"
                : countryManager.getLocalizedCountryName(from: key)
            let isDomestic = key != "_" && countryManager.isDomestic(country: key)
            return DestinationIndexGroup(
                id: key,
                title: title,
                systemImage: isDomestic ? "house.fill" : "globe.asia.australia.fill",
                accentHint: nil,
                destinations: sorted
            )
        }
        .sorted { lhs, rhs in
            let lhsDomestic = lhs.id != "_" && countryManager.isDomestic(country: lhs.id)
            let rhsDomestic = rhs.id != "_" && countryManager.isDomestic(country: rhs.id)
            if lhsDomestic != rhsDomestic { return lhsDomestic && !rhsDomestic }
            let lhsDate = lhs.destinations.first?.visitDate ?? .distantPast
            let rhsDate = rhs.destinations.first?.visitDate ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
    
    private func yearGroups(from destinations: [TravelDestination]) -> [DestinationIndexGroup] {
        let grouped = Dictionary(grouping: destinations) { destination in
            String(calendar.component(.year, from: destination.visitDate))
        }
        
        return grouped.map { key, items in
            DestinationIndexGroup(
                id: key,
                title: key,
                systemImage: "calendar",
                accentHint: nil,
                destinations: items.sorted { $0.visitDate > $1.visitDate }
            )
        }
        .sorted { (Int($0.id) ?? 0) > (Int($1.id) ?? 0) }
    }
    
    private func deleteDestination(_ destination: TravelDestination) {
        if let modelContext = destination.modelContext {
            let destinationId = destination.id
            modelContext.delete(destination)
            try? modelContext.save()
            NotificationCenter.default.post(name: .destinationDeleted, object: nil, userInfo: ["destinationId": destinationId])
        }
    }
}

// MARK: - Browse Mode

enum DestinationBrowseMode: String, CaseIterable, Identifiable {
    case region
    case year
    case favorites
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .region: return "destinations_browse_region".localized
        case .year: return "destinations_browse_year".localized
        case .favorites: return "my_favorites".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .region: return "globe.asia.australia.fill"
        case .year: return "calendar"
        case .favorites: return "heart.fill"
        }
    }
    
}

// MARK: - Group Model

private struct DestinationIndexGroup: Identifiable {
    let id: String
    let title: String
    let systemImage: String?
    let accentHint: String?
    let destinations: [TravelDestination]
}

private enum DestinationPlaceTypeStyle {
    static func symbol(for type: String) -> String? {
        switch type {
        case "natural_wonder": return "mountain.2.fill"
        case "urban_landscape": return "building.2.fill"
        case "historical_culture": return "building.columns.fill"
        case "food_feast": return "fork.knife"
        case "leisure_entertainment": return "gamecontroller.fill"
        case "outdoor_adventure": return "figure.hiking"
        case "artistic_checkin": return "paintpalette.fill"
        default: return type.isEmpty ? nil : "mappin.and.ellipse"
        }
    }
}

// MARK: - Ring

private struct DestinationRingSegment: Identifiable {
    let id: String
    let title: String
    let count: Int
    let color: Color
}

private enum DestinationFootprintRingBuilder {
    static let otherKey = "__other__"
    static let maxVisibleSegments = 7
    
    static func segments(
        from groups: [DestinationIndexGroup],
        accent: Color,
        collapsesOverflow: Bool = true
    ) -> [DestinationRingSegment] {
        let sorted = groups.sorted { $0.destinations.count > $1.destinations.count }
        guard !sorted.isEmpty else { return [] }
        
        let palette = segmentPalette(accent: accent)
        let visible: [DestinationIndexGroup]
        let restCount: Int
        if !collapsesOverflow || sorted.count <= maxVisibleSegments {
            visible = sorted
            restCount = 0
        } else {
            visible = Array(sorted.prefix(maxVisibleSegments - 1))
            restCount = sorted.dropFirst(maxVisibleSegments - 1).reduce(0) { $0 + $1.destinations.count }
        }
        
        var result = visible.enumerated().map { index, group in
            DestinationRingSegment(
                id: group.id,
                title: group.title,
                count: group.destinations.count,
                color: palette[index % palette.count]
            )
        }
        if restCount > 0 {
            result.append(
                DestinationRingSegment(
                    id: otherKey,
                    title: "destinations_ring_other".localized,
                    count: restCount,
                    color: palette[(maxVisibleSegments - 1) % palette.count]
                )
            )
        }
        return result
    }
    
    private static func segmentPalette(accent: Color) -> [Color] {
        [
            accent,
            accent.opacity(0.78),
            Color.cyan.opacity(0.85),
            Color.indigo.opacity(0.75),
            Color.teal.opacity(0.8),
            Color.purple.opacity(0.7),
            Color.orange.opacity(0.75),
            Color.mint.opacity(0.8)
        ]
    }
}

private struct DestinationFootprintRingCard: View {
    let segments: [DestinationRingSegment]
    let totalCount: Int
    @Binding var selection: String?
    var accent: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var selectedSegment: DestinationRingSegment? {
        guard let selection else { return nil }
        return segments.first(where: { $0.id == selection })
    }
    
    private var centerCount: Int {
        selectedSegment?.count ?? totalCount
    }
    
    private var centerLabel: String {
        selectedSegment?.title ?? "destinations_ring_center_label".localized
    }
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                DestinationFootprintRingView(
                    segments: segments,
                    selection: $selection,
                    lineWidth: 20
                )
                .frame(width: 180, height: 180)
                
                VStack(spacing: 2) {
                    Text("\(centerCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: centerCount)
                    Text(centerLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(centerCount) \(centerLabel)")
            }
            .frame(maxWidth: .infinity)
            
            FlowLegend(segments: segments, selection: $selection, accent: accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .footprintGlassCard(cornerRadius: 18, glow: accent)
    }
}

private struct DestinationFootprintRingView: View {
    let segments: [DestinationRingSegment]
    @Binding var selection: String?
    var lineWidth: CGFloat = 22
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = (size - lineWidth) / 2
            let total = max(segments.reduce(0) { $0 + $1.count }, 1)
            
            ZStack {
                ForEach(Array(segmentAngles(total: total).enumerated()), id: \.element.id) { _, item in
                    let isSelected = selection == item.id
                    Circle()
                        .trim(from: item.start, to: item.end)
                        .stroke(
                            item.color,
                            style: StrokeStyle(
                                lineWidth: isSelected ? lineWidth + 4 : lineWidth,
                                lineCap: .butt
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                        .opacity(selection == nil || isSelected ? 1 : 0.35)
                        .animation(.easeInOut(duration: 0.2), value: selection)
                }
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        handleTap(
                            at: value.location,
                            center: center,
                            radius: radius,
                            lineWidth: lineWidth,
                            total: total
                        )
                    }
            )
        }
    }
    
    private struct AngleItem: Identifiable {
        let id: String
        let color: Color
        let start: CGFloat
        let end: CGFloat
    }
    
    private func segmentAngles(total: Int) -> [AngleItem] {
        let count = segments.count
        guard count > 0 else { return [] }
        
        // 国家一多时缩小间隔，保证每一段都落在圆环内
        let gap: CGFloat = count > 1 ? min(0.01, 0.12 / CGFloat(count)) : 0
        let usable = max(1 - gap * CGFloat(count), 0.01)
        let safeTotal = CGFloat(max(total, 1))
        let raw = segments.map { CGFloat($0.count) / safeTotal * usable }
        let minSweep = min(0.02, usable / CGFloat(count))
        var sweeps = raw.map { max($0, minSweep) }
        let sweepSum = sweeps.reduce(CGFloat(0), +)
        if sweepSum > usable, sweepSum > 0 {
            let scale = usable / sweepSum
            sweeps = sweeps.map { $0 * scale }
        }
        
        var cursor: CGFloat = 0
        return zip(segments, sweeps).map { segment, sweep in
            let start = cursor
            let end = cursor + sweep
            cursor = end + gap
            return AngleItem(id: segment.id, color: segment.color, start: start, end: min(end, 1))
        }
    }
    
    private func handleTap(
        at point: CGPoint,
        center: CGPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        total: Int
    ) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let inner = radius - lineWidth * 0.55
        let outer = radius + lineWidth * 0.55
        
        if distance < inner {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = nil
            }
            return
        }
        
        guard distance <= outer else { return }
        
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }
        let progress = angle / (2 * .pi)
        
        let items = segmentAngles(total: total)
        guard let hit = items.first(where: { progress >= $0.start && progress < $0.end })
                ?? items.last else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selection = selection == hit.id ? nil : hit.id
        }
    }
}

private struct FlowLegend: View {
    let segments: [DestinationRingSegment]
    @Binding var selection: String?
    var accent: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        FlexibleChipWrap(spacing: 8) {
            ForEach(segments) { segment in
                let isSelected = selection == segment.id
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = isSelected ? nil : segment.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 8, height: 8)
                        Text(segment.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .lineLimit(1)
                        Text("\(segment.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.9) : FootprintChrome.secondaryLabel(colorScheme))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        if isSelected {
                            Capsule().fill(accent)
                        } else {
                            Capsule().fill(FootprintChrome.hairline(colorScheme).opacity(0.35))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 简易横向换行布局（图例芯片）
private struct FlexibleChipWrap: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var height: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            height = y + rowHeight
        }
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Compact Index Row

private struct AllDestinationsIndexRow: View {
    let destination: TravelDestination
    var showsCountry: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var thumbnail: UIImage?
    
    private var subtitleParts: [String] {
        var parts: [String] = []
        if showsCountry, !destination.country.isEmpty {
            parts.append(countryManager.getLocalizedCountryName(from: destination.country))
        }
        if !destination.province.isEmpty {
            parts.append(destination.province)
        }
        if !destination.localizedType.isEmpty {
            parts.append(destination.localizedType)
        }
        parts.append(destination.visitDate.localizedFormatted(dateStyle: .medium))
        return parts
    }
    
    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(destination.name.isEmpty ? "—" : destination.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.pink)
                    }
                }
                
                HStack(spacing: 6) {
                    if let symbol = DestinationPlaceTypeStyle.symbol(for: destination.type) {
                        Image(systemName: symbol)
                            .font(.caption2)
                            .foregroundStyle(brandColorManager.currentBrandColor)
                    }
                    
                    Text(subtitleParts.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FootprintChrome.tertiaryLabel(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .task(id: destination.id) {
            thumbnail = await DestinationThumbnailCache.shared.imageForListCard(
                for: destination.id,
                thumbnailData: destination.photoThumbnailData,
                fallbackData: destination.photoData
            )
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(FootprintChrome.cardStroke(colorScheme), lineWidth: 0.5)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(brandColorManager.currentBrandColor.opacity(0.14))
                    .frame(width: 48, height: 48)
                
                Image(systemName: DestinationPlaceTypeStyle.symbol(for: destination.type) ?? "location.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(brandColorManager.currentBrandColor)
            }
        }
    }
}

#Preview {
    AllDestinationsListView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
        .environmentObject(BrandColorManager.shared)
}
