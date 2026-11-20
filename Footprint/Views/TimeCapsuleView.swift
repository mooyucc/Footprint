//
//  TimeCapsuleView.swift
//  Footprint
//
//  年鉴：首页是年份相册；点进某一年后横向轮换地点，底部波峰条拨动卡片。
//

import SwiftUI
import SwiftData

struct TimeCapsuleView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @ObservedObject private var tabSnapshots = TabListSnapshotStore.shared
    @ObservedObject private var profileCache = ProfileCacheStore.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTimelinePickerYear: Int?
    @State private var focusedDestinationID: UUID?
    @State private var detailDestination: TravelDestination?
    @State private var browsingYear: Int?
    @State private var scrollAlbumToYear: Int?
    @State private var isAutoPlaying = false
    @State private var autoPlayTask: Task<Void, Never>?
    @State private var suppressAutoPlayInterrupt = false
    @State private var albumImages: [Int: [YearAlbumImage]] = [:]
    @State private var coverLoadTask: Task<Void, Never>?
    @State private var refreshID = UUID()
    /// 仅在按住波峰时有值，卡片按这个小数位置连续翻动。松手后交回系统滚动。
    @State private var waveScrubPosition: CGFloat?
    @State private var waveScrubGeneration = 0
    /// 手指拖动轮播中：先不刷新氛围光，避免中途换焦看起来像提前吸附。
    @State private var isCarouselInteracting = false
    @State private var ambientFocusID: UUID?
    /// 程序化滚到指定卡（点选 / 波峰交还 / 自动播放落点）。不用 scrollPosition 双向绑定，避免拖动中磁吸。
    @State private var carouselScrollCommand: CarouselScrollCommand?
    @Namespace private var yearZoomNamespace

    private let carouselCardWidthRatio: CGFloat = 0.8
    private let carouselCardMaxWidth: CGFloat = 560
    private let carouselCardSpacing: CGFloat = 8

    private struct CarouselScrollCommand: Equatable {
        let id: UUID
        let animated: Bool
        let nonce: UUID
    }

    private var autoPlayIntervalNanoseconds: UInt64 {
        reduceMotion ? 3_000_000_000 : 2_000_000_000
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

    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )

                if !hasAnyDestinations || years.isEmpty {
                    FootprintEmptyText(text: "no_travel_records".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    YearAlbumLibrary(
                        items: profileCache.timelineYearItems,
                        images: albumImages,
                        yearLabel: timelineYearLabel,
                        zoomNamespace: yearZoomNamespace,
                        scrollToYear: scrollAlbumToYear,
                        onSelect: openYear
                    )
                }
            }
            .navigationTitle("time_capsule_tab".localized)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $browsingYear) { year in
                yearBrowser(for: year)
                    .navigationTransition(.zoom(sourceID: year, in: yearZoomNamespace))
            }
            .onAppear {
                TabListSnapshotStore.shared.attach(modelContext: modelContext)
                TabListSnapshotStore.shared.ensureProfileData()
                syncTimelinePickerYear()
                loadAlbumCovers()
            }
            .onChange(of: profileCache.timelineYearItems.map { "\($0.year):\($0.count)" }) { _, _ in
                let openYear = selectedTimelinePickerYear
                syncTimelinePickerYear()
                if let browsing = browsingYear, !years.contains(browsing) {
                    browsingYear = nil
                }
                if let openYear, browsingYear != nil, !years.contains(openYear) {
                    browsingYear = nil
                }
                loadAlbumCovers()
            }
            .onChange(of: browsingYear) { previous, year in
                if let year {
                    selectedTimelinePickerYear = year
                    tabSnapshots.loadYear(year)
                    syncFocusedDestination(forceFirst: true)
                } else {
                    stopAutoPlay()
                    if let previous {
                        scrollAlbumToYear = previous
                    }
                }
            }
            .onChange(of: yearDestinations.map(\.id)) { _, _ in
                guard browsingYear != nil else { return }
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
            .onChange(of: scrollAlbumToYear) { _, year in
                guard let year else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    if scrollAlbumToYear == year {
                        scrollAlbumToYear = nil
                    }
                }
            }
            .onDisappear {
                stopAutoPlay()
            }
            .id(refreshID)
        }
    }

    // MARK: - 年份内浏览

    private func yearBrowser(for year: Int) -> some View {
        ZStack {
            FootprintAtmosphereBackground(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            )

            VStack(spacing: 0) {
                // 假导航栏：随 zoom 内容一起消失，避免系统栏按钮滞后
                yearBrowserChrome(title: timelineYearLabel(year))

                yearCountChrome
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                destinationCarouselSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !yearDestinations.isEmpty {
                    FootprintCardWaveScrubber(
                        count: yearDestinations.count,
                        selectedIndex: focusedDestinationIndex,
                        accent: brandColorManager.currentBrandColor,
                        onScrub: { scrubCarousel(to: $0) },
                        onSelect: { finishWaveScrub(at: $0) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $detailDestination) { destination in
            NavigationStack {
                DestinationDetailView(destination: destination)
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            selectedTimelinePickerYear = year
            tabSnapshots.loadYear(year)
            syncFocusedDestination()
        }
        .onDisappear {
            stopAutoPlay()
        }
    }

    /// 仿系统 inline 导航栏：返回 / 年份标题 / 播放，属于页面内容以便参与 zoom。
    private func yearBrowserChrome(title: String) -> some View {
        ZStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 0) {
                yearBrowserChromeButton(systemName: "chevron.backward", accessibilityLabel: Text("Back")) {
                    browsingYear = nil
                }

                Spacer(minLength: 0)

                if yearDestinations.count > 1 {
                    yearBrowserChromeButton(
                        systemName: isAutoPlaying ? "pause.fill" : "play.fill",
                        accessibilityLabel: Text(isAutoPlaying ? "timeline_pause".localized : "timeline_play".localized)
                    ) {
                        toggleAutoPlay()
                    }
                    .sensoryFeedback(.selection, trigger: isAutoPlaying)
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                }
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
    }

    /// 与系统工具栏图标钮同一套玻璃：清晰圆底、主色符号。旧系统用薄材质圆，不再套地图浮层投影。
    @ViewBuilder
    private func yearBrowserChromeButton(
        systemName: String,
        accessibilityLabel: Text,
        action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 25, weight: .medium))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(.primary)
            .scaleEffect(0.85)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .scaleEffect(0.85)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var yearCountChrome: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
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
                let glowBleed: CGFloat = 36
                let cardHeight = max(geo.size.height - glowBleed, 160)
                let cardWidth = min(geo.size.width * carouselCardWidthRatio, carouselCardMaxWidth)
                let sideInset = max((geo.size.width - cardWidth) / 2, 0)
                let pitch = cardWidth + carouselCardSpacing
                let motionReduced = reduceMotion

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: carouselCardSpacing) {
                            ForEach(yearDestinations) { destination in
                                let visualFocusID = isCarouselInteracting
                                    ? (ambientFocusID ?? focusedDestinationID)
                                    : focusedDestinationID
                                let isFocused = destination.id == visualFocusID
                                Button {
                                    if destination.id == focusedDestinationID {
                                        detailDestination = destination
                                    } else {
                                        focusedDestinationID = destination.id
                                        ambientFocusID = destination.id
                                        requestCarouselScroll(to: destination.id, animated: !motionReduced)
                                    }
                                } label: {
                                    DestinationRowCard(
                                        destination: destination,
                                        height: cardHeight,
                                        highResolutionCover: true,
                                        showsAmbientGlow: true,
                                        isAmbientFocused: isFocused
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
                    // 仅松手后对齐；不再用 scrollPosition(id:) 双向绑定（拖过半张就会改 id 并中途磁吸）。
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.x
                    } action: { _, offsetX in
                        updateFocusedDestination(fromOffsetX: offsetX, pitch: pitch)
                    }
                    .onScrollPhaseChange { _, newPhase in
                        if newPhase == .interacting {
                            if !isCarouselInteracting {
                                ambientFocusID = focusedDestinationID
                                isCarouselInteracting = true
                            }
                        } else if isCarouselInteracting {
                            isCarouselInteracting = false
                            ambientFocusID = focusedDestinationID
                        }
                    }
                    .onAppear {
                        if let id = focusedDestinationID {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                    .onChange(of: carouselScrollCommand) { _, command in
                        guard let command else { return }
                        performCarouselScroll(proxy: proxy, command: command)
                    }
                }
                .frame(height: cardHeight + glowBleed)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .opacity(waveScrubPosition == nil ? 1 : 0)
                .overlay {
                    if let waveScrubPosition {
                        waveScrubCarousel(
                            position: waveScrubPosition,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            motionReduced: motionReduced
                        )
                    }
                }
            }
        }
    }

    private func updateFocusedDestination(fromOffsetX offsetX: CGFloat, pitch: CGFloat) {
        guard pitch > 0, !yearDestinations.isEmpty else { return }
        let index = min(max(Int((offsetX / pitch).rounded()), 0), yearDestinations.count - 1)
        let id = yearDestinations[index].id
        guard focusedDestinationID != id else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            focusedDestinationID = id
            if !isCarouselInteracting {
                ambientFocusID = id
            }
        }
    }

    private func requestCarouselScroll(to id: UUID, animated: Bool) {
        carouselScrollCommand = CarouselScrollCommand(id: id, animated: animated, nonce: UUID())
    }

    private func performCarouselScroll(proxy: ScrollViewProxy, command: CarouselScrollCommand) {
        if command.animated, !reduceMotion {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                proxy.scrollTo(command.id, anchor: .center)
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(command.id, anchor: .center)
            }
        }
    }

    // MARK: - Actions

    private var carouselLimit: CGFloat {
        CGFloat(max(yearDestinations.count - 1, 0))
    }

    /// 按住波峰时盖在系统滚动上面，按小数位置连续翻页。
    /// `position` 允许到 `count`（虚拟「末张之后」），用于自动播放从最后一张滑回第一张。
    private func waveScrubCarousel(
        position: CGFloat,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        motionReduced: Bool
    ) -> some View {
        let pitch = cardWidth + carouselCardSpacing
        let count = yearDestinations.count
        let nearest = Int(position.rounded())
        let lower = max(0, nearest - 3)
        let upper = min(count, nearest + 3)

        return ZStack {
            ForEach(lower...upper, id: \.self) { index in
                let dataIndex = index == count ? 0 : index
                let distance = CGFloat(index) - position
                let amount = motionReduced ? 0 : min(abs(distance), 1)
                DestinationRowCard(
                    destination: yearDestinations[dataIndex],
                    height: cardHeight,
                    highResolutionCover: true,
                    showsAmbientGlow: true,
                    isAmbientFocused: abs(distance) < 0.5
                )
                .frame(width: cardWidth)
                .scaleEffect(1 - 0.12 * amount)
                .brightness(-0.14 * amount)
                .opacity(1 - 0.18 * amount)
                .offset(x: distance * pitch)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 波峰拖动：位置跟手，底下的滚动视图同步到最近一张，但不做动画。
    private func scrubCarousel(to position: CGFloat) {
        waveScrubGeneration += 1
        let clamped = min(max(position, 0), carouselLimit)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            waveScrubPosition = clamped
        }
        setFocusedDestination(at: Int(clamped.rounded()))
    }

    /// 松开波峰：收到最近一张后，把翻页交回系统滚动。
    private func finishWaveScrub(at index: Int) {
        guard yearDestinations.indices.contains(index) else {
            waveScrubPosition = nil
            return
        }
        let generation = waveScrubGeneration
        let id = yearDestinations[index].id
        setFocusedDestination(at: index)
        ambientFocusID = id
        if reduceMotion {
            requestCarouselScroll(to: id, animated: false)
            waveScrubPosition = nil
            return
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            waveScrubPosition = CGFloat(index)
        } completion: {
            if waveScrubGeneration == generation {
                requestCarouselScroll(to: id, animated: false)
                waveScrubPosition = nil
            }
        }
    }

    private func setFocusedDestination(at index: Int) {
        guard yearDestinations.indices.contains(index) else { return }
        let id = yearDestinations[index].id
        guard focusedDestinationID != id else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            focusedDestinationID = id
        }
    }

    private func openYear(_ year: Int) {
        stopAutoPlay()
        selectedTimelinePickerYear = year
        tabSnapshots.loadYear(year)
        syncFocusedDestination(forceFirst: true)
        scrollAlbumToYear = year
        browsingYear = year
    }

    private func toggleAutoPlay() {
        if isAutoPlaying {
            stopAutoPlay()
            return
        }
        guard yearDestinations.count > 1 else { return }
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
        // 打断进行中的自动翻页滑动，交回系统滚动。
        waveScrubGeneration += 1
        waveScrubPosition = nil
    }

    /// 自动翻到下一项；末尾回到第一项。
    /// 用波峰翻页层做连续滑动（系统 ScrollView 程序化滚动容易硬切）。
    private func advanceToNextDestinationLooping() {
        let items = yearDestinations
        guard items.count > 1 else {
            stopAutoPlay()
            return
        }
        let from = focusedDestinationIndex
        let next = (from + 1) % items.count
        let nextID = items[next].id
        suppressAutoPlayInterrupt = true

        if reduceMotion {
            focusedDestinationID = nextID
            ambientFocusID = nextID
            requestCarouselScroll(to: nextID, animated: false)
            waveScrubPosition = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                suppressAutoPlayInterrupt = false
            }
            return
        }

        // 末张→首张：滑到虚拟位置 count（右侧再出一张首卡），避免 position 从 N-1 插值到 0 反向扫过整条。
        let targetPosition = next == 0 ? CGFloat(items.count) : CGFloat(next)

        waveScrubGeneration += 1
        let generation = waveScrubGeneration
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            waveScrubPosition = CGFloat(from)
        }

        // 先落一帧在 from，再动画到 next；同帧连写会被合并成硬切。
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard waveScrubGeneration == generation, isAutoPlaying else {
                suppressAutoPlayInterrupt = false
                return
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                waveScrubPosition = targetPosition
                focusedDestinationID = nextID
                ambientFocusID = nextID
            } completion: {
                guard waveScrubGeneration == generation else {
                    suppressAutoPlayInterrupt = false
                    return
                }
                requestCarouselScroll(to: nextID, animated: false)
                waveScrubPosition = nil
                suppressAutoPlayInterrupt = false
            }
        }
    }

    private func loadAlbumCovers() {
        coverLoadTask?.cancel()
        let yearsToLoad = years
        guard !yearsToLoad.isEmpty else {
            albumImages = [:]
            return
        }
        // 热启动：视图状态还在则跳过解码，封面 ID 由 TabListSnapshotStore 进程内缓存保证不换。
        let missingYears = yearsToLoad.filter { albumImages[$0] == nil }
        guard !missingYears.isEmpty else {
            albumImages = albumImages.filter { yearsToLoad.contains($0.key) }
            return
        }
        coverLoadTask = Task { @MainActor in
            await withTaskGroup(of: (Int, [YearAlbumImage]).self) { group in
                for year in missingYears {
                    group.addTask { @MainActor in
                        let sources = TabListSnapshotStore.shared.yearAlbumCoverSources(year: year)
                        let images = await Self.decodeAlbumImages(from: sources)
                        return (year, images)
                    }
                }
                for await (year, images) in group {
                    if Task.isCancelled {
                        group.cancelAll()
                        return
                    }
                    var loaded = albumImages
                    loaded[year] = images
                    albumImages = loaded.filter { yearsToLoad.contains($0.key) }
                }
            }
        }
    }

    /// 同一年内多张封面并行解码，保序。
    private static func decodeAlbumImages(from sources: [YearAlbumCoverSource]) async -> [YearAlbumImage] {
        guard !sources.isEmpty else { return [] }
        return await withTaskGroup(of: (Int, YearAlbumImage?).self) { group in
            for (index, source) in sources.enumerated() {
                group.addTask {
                    let image = await DestinationThumbnailCache.shared.imageForListCard(
                        for: source.id,
                        thumbnailData: source.thumbnailData,
                        fallbackData: source.fallbackData
                    )
                    guard let image else { return (index, nil) }
                    return (index, YearAlbumImage(id: source.id, image: image))
                }
            }
            var slots: [YearAlbumImage?] = Array(repeating: nil, count: sources.count)
            for await (index, item) in group {
                slots[index] = item
            }
            return slots.compactMap { $0 }
        }
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

    private func syncFocusedDestination(forceFirst: Bool = false) {
        let ids = yearDestinations.map(\.id)
        guard let first = ids.first else {
            focusedDestinationID = nil
            ambientFocusID = nil
            isCarouselInteracting = false
            return
        }
        if forceFirst {
            focusedDestinationID = first
            ambientFocusID = first
            isCarouselInteracting = false
            waveScrubPosition = nil
            requestCarouselScroll(to: first, animated: false)
            return
        }
        if let current = focusedDestinationID, ids.contains(current) {
            return
        }
        focusedDestinationID = first
        ambientFocusID = first
        isCarouselInteracting = false
        waveScrubPosition = nil
        requestCarouselScroll(to: first, animated: false)
    }
}
