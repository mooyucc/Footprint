//
//  TimeCapsuleView.swift
//  Footprint
//
//  时光 Tab：上部屏幕区 + 下部 Click Wheel（双层 Menu：年份列表 ↔ 地点浏览）
//

import SwiftUI
import SwiftData

struct TimeCapsuleView: View {
    private enum WheelLevel {
        case yearMenu
        case destinations
    }

    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @ObservedObject private var tabSnapshots = TabListSnapshotStore.shared
    @ObservedObject private var profileCache = ProfileCacheStore.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTimelinePickerYear: Int?
    @State private var focusedDestinationID: UUID?
    @State private var detailDestination: TravelDestination?
    @State private var wheelLevel: WheelLevel = .destinations
    @State private var yearMenuIndex: Int = 0
    @State private var isAutoPlaying = false
    @State private var autoPlayTask: Task<Void, Never>?
    @State private var suppressAutoPlayInterrupt = false
    @State private var focusedAmbientGlow: Color?
    @State private var refreshID = UUID()

    /// 浏览态完整拨轮；自动轮播时收成圆形暂停钮，把空间让给地点卡片
    private let dialSize: CGFloat = 209
    private let autoPlayPauseButtonSize: CGFloat = 56
    private let carouselCardWidthRatioIdle: CGFloat = 0.78
    private let carouselCardWidthRatioPlaying: CGFloat = 0.90
    private let carouselCardSpacingIdle: CGFloat = 14
    /// 轮播时主卡更大，收紧间距（略重叠）让左右卡仍能露边
    private let carouselCardSpacingPlaying: CGFloat = -8

    private var autoPlayIntervalNanoseconds: UInt64 {
        reduceMotion ? 3_000_000_000 : 2_000_000_000
    }

    private var activeCarouselCardWidthRatio: CGFloat {
        isAutoPlaying ? carouselCardWidthRatioPlaying : carouselCardWidthRatioIdle
    }

    private var activeCarouselCardSpacing: CGFloat {
        isAutoPlaying ? carouselCardSpacingPlaying : carouselCardSpacingIdle
    }

    private var autoPlayLayoutAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86)
    }

    private var years: [Int] {
        profileCache.timelineYearItems.map(\.year)
    }

    private var resolvedYear: Int {
        if let selected = selectedTimelinePickerYear, years.contains(selected) {
            return selected
        }
        return years.first ?? 0
    }

    private var yearDestinations: [TravelDestination] {
        guard resolvedYear > 0, tabSnapshots.loadedYear == resolvedYear else { return [] }
        return tabSnapshots.yearDestinations
    }

    private var hasAnyDestinations: Bool {
        !profileCache.destinationSnapshots.isEmpty || profileCache.displayStatistics.total > 0
    }

    private var selectedYearDestinationCount: Int {
        profileCache.timelineYearItems
            .first { $0.year == resolvedYear }?
            .count ?? yearDestinations.count
    }

    private var focusedDestinationIndex: Int {
        guard let id = focusedDestinationID,
              let index = yearDestinations.firstIndex(where: { $0.id == id }) else {
            return 0
        }
        return index
    }

    private var focusedDestinationName: String {
        guard let id = focusedDestinationID,
              let destination = yearDestinations.first(where: { $0.id == id }) else {
            return ""
        }
        return destination.name
    }

    private var menuYear: Int {
        years.indices.contains(yearMenuIndex) ? years[yearMenuIndex] : resolvedYear
    }

    private var dialSelectedIndexBinding: Binding<Int> {
        switch wheelLevel {
        case .yearMenu:
            return Binding(
                get: { yearMenuIndex },
                set: { newIndex in
                    guard years.indices.contains(newIndex) else { return }
                    yearMenuIndex = newIndex
                }
            )
        case .destinations:
            return Binding(
                get: { focusedDestinationIndex },
                set: { newIndex in
                    guard yearDestinations.indices.contains(newIndex) else { return }
                    let id = yearDestinations[newIndex].id
                    if reduceMotion {
                        focusedDestinationID = id
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            focusedDestinationID = id
                        }
                    }
                }
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: Color.black,
                    secondaryAccent: Color.black
                )

                VStack(spacing: 0) {
                    screenSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    clickWheelSection
                        .padding(.top, isAutoPlaying ? 8 : 10)
                        .padding(.bottom, isAutoPlaying ? 10 : 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .animation(autoPlayLayoutAnimation, value: isAutoPlaying)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $detailDestination) { destination in
                NavigationStack {
                    DestinationDetailView(destination: destination)
                }
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                TabListSnapshotStore.shared.attach(modelContext: modelContext)
                // 时间线年份来自 Profile 快照；按需加载，不在地图启动时全表扫
                TabListSnapshotStore.shared.ensureProfileData()
                syncTimelinePickerYear()
                syncYearMenuIndex()
                // 同年已缓存则跳过 fetch，避免每次切 Tab 主线程重查
                tabSnapshots.loadYear(resolvedYear)
                syncFocusedDestination()
            }
            .onChange(of: profileCache.timelineYearItems.map(\.year)) { _, _ in
                syncTimelinePickerYear()
                syncYearMenuIndex()
            }
            .onChange(of: resolvedYear) { _, newYear in
                stopAutoPlay()
                focusedAmbientGlow = nil
                syncYearMenuIndex()
                tabSnapshots.loadYear(newYear)
                syncFocusedDestination(forceFirst: true)
            }
            .onChange(of: yearDestinations.map(\.id)) { _, _ in
                syncFocusedDestination()
            }
            .onChange(of: focusedDestinationID) { _, _ in
                guard isAutoPlaying, !suppressAutoPlayInterrupt else { return }
                stopAutoPlay()
            }
            .onChange(of: detailDestination?.id) { _, newID in
                if newID != nil { stopAutoPlay() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            .onDisappear {
                stopAutoPlay()
            }
            .id(refreshID)
        }
    }

    // MARK: - 上：屏幕区

    private var screenSection: some View {
        VStack(spacing: 12) {
            statusChrome

            if !hasAnyDestinations || years.isEmpty {
                FootprintEmptyText(text: "no_travel_records".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                Group {
                    switch wheelLevel {
                    case .yearMenu:
                        yearMenuList
                    case .destinations:
                        destinationCarouselSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statusChrome: some View {
        Group {
            if years.isEmpty {
                EmptyView()
            } else if wheelLevel == .yearMenu {
                Text("time_capsule_year_list".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(timelineYearLabel(resolvedYear))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(selectedYearDestinationCount)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("destinations_count".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - 年份菜单列表

    private var yearMenuList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(Array(years.enumerated()), id: \.element) { index, year in
                        let isFocused = index == yearMenuIndex
                        let count = profileCache.timelineYearItems
                            .first { $0.year == year }?
                            .count ?? 0

                        Button {
                            yearMenuIndex = index
                            enterYearFromMenu()
                        } label: {
                            HStack(spacing: 12) {
                                Text(timelineYearLabel(year))
                                    .font(.title3.weight(isFocused ? .bold : .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(isFocused ? Color.white : Color.primary)

                                Spacer(minLength: 8)

                                Text("\(count)")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(isFocused ? Color.white.opacity(0.9) : Color.secondary)
                                Text("destinations_count".localized)
                                    .font(.caption)
                                    .foregroundStyle(isFocused ? Color.white.opacity(0.75) : Color.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isFocused
                                          ? brandColorManager.currentBrandColor
                                          : Color.primary.opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        isFocused
                                            ? Color.clear
                                            : Color.primary.opacity(0.06),
                                        lineWidth: 0.5
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .accessibilityAddTraits(isFocused ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .onAppear {
                proxy.scrollTo(yearMenuIndex, anchor: .center)
            }
            .onChange(of: yearMenuIndex) { _, newValue in
                if reduceMotion {
                    proxy.scrollTo(newValue, anchor: .center)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - 吸附轮播

    @ViewBuilder
    private var destinationCarouselSection: some View {
        if yearDestinations.isEmpty {
            FootprintEmptyText(
                text: "no_travel_records_for_year".localized(with: resolvedYear)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            GeometryReader { geo in
                let indicatorSpacing: CGFloat = 14
                let indicatorHeight: CGFloat = 6
                let glowBleed: CGFloat = 36
                let cardHeight = max(
                    geo.size.height - indicatorSpacing - indicatorHeight - glowBleed,
                    160
                )
                let cardWidth = min(geo.size.width * activeCarouselCardWidthRatio, 340)
                let sideInset = max((geo.size.width - cardWidth) / 2, 0)
                let cardSpacing = activeCarouselCardSpacing
                let motionReduced = reduceMotion

                VStack(spacing: indicatorSpacing) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: cardSpacing) {
                            ForEach(yearDestinations) { destination in
                                let isFocused = destination.id == focusedDestinationID
                                Button {
                                    if isFocused {
                                        detailDestination = destination
                                    } else if motionReduced {
                                        focusedDestinationID = destination.id
                                    } else {
                                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                            focusedDestinationID = destination.id
                                        }
                                    }
                                } label: {
                                    DestinationRowCard(
                                        destination: destination,
                                        height: cardHeight,
                                        highResolutionCover: true,
                                        showsAmbientGlow: true,
                                        isAmbientFocused: isFocused,
                                        onAmbientColorChange: { color in
                                            guard destination.id == focusedDestinationID else { return }
                                            focusedAmbientGlow = color
                                        }
                                    )
                                    .frame(width: cardWidth)
                                    .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                        let raw = motionReduced ? 0 : min(abs(phase.value), 1)
                                        let scale = 1 - 0.12 * raw
                                        let dim = 0.14 * raw
                                        let opacity = 1 - 0.18 * raw
                                        return view
                                            .scaleEffect(scale)
                                            .brightness(-dim)
                                            .opacity(opacity)
                                    }
                                }
                                .buttonStyle(.plain)
                                .id(destination.id)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, glowBleed / 2)
                    }
                    .scrollClipDisabled()
                    .contentMargins(.horizontal, sideInset, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $focusedDestinationID)
                    .frame(height: cardHeight + glowBleed)

                    pageIndicator
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
    }

    private let maxPageDots = 7

    private var pageIndicator: some View {
        let total = yearDestinations.count
        let current = focusedDestinationIndex
        let indices = pageDotIndices(total: total, current: current)

        return HStack(spacing: 6) {
            ForEach(indices, id: \.self) { index in
                let isActive = index == current
                Capsule()
                    .fill(isActive ? brandColorManager.currentBrandColor : Color.secondary.opacity(0.35))
                    .frame(width: isActive ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: focusedDestinationID)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(current + 1) / \(total)")
    }

    private func pageDotIndices(total: Int, current: Int) -> [Int] {
        guard total > 0 else { return [] }
        guard total > maxPageDots else { return Array(0..<total) }

        let half = maxPageDots / 2
        var start = max(0, current - half)
        var end = start + maxPageDots
        if end > total {
            end = total
            start = max(0, end - maxPageDots)
        }
        return Array(start..<end)
    }

    // MARK: - 下：Click Wheel

    private var canAutoPlayDestinations: Bool {
        wheelLevel == .destinations && yearDestinations.count > 1
    }

    private var clickWheelSection: some View {
        Group {
            if !hasAnyDestinations || years.isEmpty {
                EmptyView()
            } else if isAutoPlaying {
                autoPlayPauseButton
                    .frame(maxWidth: .infinity)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.72).combined(with: .opacity)
                    )
            } else {
                FootprintTimelineYearDial(
                    itemCount: wheelLevel == .yearMenu ? years.count : yearDestinations.count,
                    selectedIndex: dialSelectedIndexBinding,
                    centerTitle: wheelLevel == .yearMenu
                        ? timelineYearLabel(menuYear)
                        : timelineYearLabel(resolvedYear),
                    onCenterTap: handleCenterTap,
                    onMenu: handleMenuTap,
                    onPrevious: {
                        stopAutoPlay()
                        shiftYear(delta: +1)
                    },
                    onNext: {
                        stopAutoPlay()
                        shiftYear(delta: -1)
                    },
                    onPlayPause: canAutoPlayDestinations ? { toggleAutoPlay() } : nil,
                    isPlaying: false,
                    accent: brandColorManager.currentBrandColor,
                    glow: wheelLevel == .destinations
                        ? (focusedAmbientGlow ?? brandColorManager.currentBrandColor)
                        : brandColorManager.currentBrandColor.opacity(0.55),
                    dialSize: dialSize,
                    accessibilityLabelText: "travel_timeline".localized,
                    accessibilityValueText: wheelAccessibilityValue
                )
                .frame(maxWidth: .infinity)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.92).combined(with: .opacity)
                )
            }
        }
    }

    private var autoPlayPauseButton: some View {
        Button {
            stopAutoPlay()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.primary)
                .footprintMapGlassCircle(
                    diameter: autoPlayPauseButtonSize,
                    isDarkMap: colorScheme == .dark
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("timeline_pause".localized)
    }

    private var wheelAccessibilityValue: String {
        switch wheelLevel {
        case .yearMenu:
            return timelineYearLabel(menuYear)
        case .destinations:
            return focusedDestinationName.isEmpty
                ? timelineYearLabel(resolvedYear)
                : focusedDestinationName
        }
    }

    // MARK: - Wheel actions

    private func handleCenterTap() {
        switch wheelLevel {
        case .yearMenu:
            enterYearFromMenu()
        case .destinations:
            openFocusedDestination()
        }
    }

    private func handleMenuTap() {
        stopAutoPlay()
        switch wheelLevel {
        case .yearMenu:
            // 已在菜单层：再按 MENU 回到地点浏览（保留当前年）
            setWheelLevel(.destinations)
        case .destinations:
            syncYearMenuIndex()
            setWheelLevel(.yearMenu)
        }
    }

    private func toggleAutoPlay() {
        if isAutoPlaying {
            stopAutoPlay()
            return
        }
        guard wheelLevel == .destinations, yearDestinations.count > 1 else { return }
        startAutoPlay()
    }

    private func startAutoPlay() {
        autoPlayTask?.cancel()
        isAutoPlaying = true
        autoPlayTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: autoPlayIntervalNanoseconds)
                guard !Task.isCancelled, isAutoPlaying else { break }
                advanceToNextDestinationLooping()
            }
        }
    }

    private func stopAutoPlay() {
        isAutoPlaying = false
        autoPlayTask?.cancel()
        autoPlayTask = nil
        suppressAutoPlayInterrupt = false
    }

    /// 自动翻到下一项；末尾回到第一项
    private func advanceToNextDestinationLooping() {
        let items = yearDestinations
        guard items.count > 1 else {
            stopAutoPlay()
            return
        }
        let next = (focusedDestinationIndex + 1) % items.count
        suppressAutoPlayInterrupt = true
        if reduceMotion {
            focusedDestinationID = items[next].id
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                focusedDestinationID = items[next].id
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            suppressAutoPlayInterrupt = false
        }
    }

    private func enterYearFromMenu() {
        guard years.indices.contains(yearMenuIndex) else { return }
        stopAutoPlay()
        let year = years[yearMenuIndex]
        if reduceMotion {
            selectedTimelinePickerYear = year
            wheelLevel = .destinations
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                selectedTimelinePickerYear = year
                wheelLevel = .destinations
            }
        }
    }

    /// years 为新→旧；delta +1 更早的年份，-1 更新的年份
    private func shiftYear(delta: Int) {
        guard !years.isEmpty else { return }

        switch wheelLevel {
        case .yearMenu:
            let next = min(max(yearMenuIndex + delta, 0), years.count - 1)
            guard next != yearMenuIndex else { return }
            yearMenuIndex = next
        case .destinations:
            guard let idx = years.firstIndex(of: resolvedYear) else { return }
            let next = idx + delta
            guard years.indices.contains(next) else { return }
            let year = years[next]
            if reduceMotion {
                selectedTimelinePickerYear = year
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    selectedTimelinePickerYear = year
                }
            }
        }
    }

    private func setWheelLevel(_ level: WheelLevel) {
        if reduceMotion {
            wheelLevel = level
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                wheelLevel = level
            }
        }
    }

    private func openFocusedDestination() {
        guard let id = focusedDestinationID,
              let destination = yearDestinations.first(where: { $0.id == id }) else {
            return
        }
        detailDestination = destination
    }

    // MARK: - Helpers

    private func timelineYearLabel(_ year: Int) -> String {
        switch languageManager.currentLanguage {
        case .chinese, .chineseTraditional:
            return "\(year)年"
        default:
            return "\(year)"
        }
    }

    private func syncTimelinePickerYear() {
        guard !years.isEmpty else {
            selectedTimelinePickerYear = nil
            return
        }
        if let selected = selectedTimelinePickerYear, years.contains(selected) {
            return
        }
        selectedTimelinePickerYear = years.first
    }

    private func syncYearMenuIndex() {
        guard !years.isEmpty else {
            yearMenuIndex = 0
            return
        }
        if let idx = years.firstIndex(of: resolvedYear) {
            yearMenuIndex = idx
        } else {
            yearMenuIndex = 0
        }
    }

    private func syncFocusedDestination(forceFirst: Bool = false) {
        let ids = yearDestinations.map(\.id)
        guard let first = ids.first else {
            focusedDestinationID = nil
            return
        }
        if forceFirst {
            focusedDestinationID = first
            return
        }
        if let current = focusedDestinationID, ids.contains(current) {
            return
        }
        focusedDestinationID = first
    }

}
