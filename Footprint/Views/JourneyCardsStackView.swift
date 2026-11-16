//
//  JourneyCardsStackView.swift
//  Footprint
//
//  旅程卡片：ZStack 垂直堆叠 + 拨动滚轮/传送带交互（拖拽吸附）+ 点按聚焦
//

import SwiftUI
import SwiftData
import UIKit
import AudioToolbox
import MapKit

/// 旅程列表的「压缩堆叠 + 滚轮拨动」卡片视图：拖拽切换焦点，点按直接选中。
struct JourneyCardsStackView: View {
    @ObservedObject private var tabSnapshots = TabListSnapshotStore.shared
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingAddTrip = false
    @State private var showPaywall = false
    @State private var showingFilePicker = false
    @State private var selectedURL: URL?
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    
    @State private var focusedIndex: Int = 0
    /// 点击最前卡片时进入 `TripDetailView`
    @State private var detailTripId: UUID?
    /// 从卡片打开全屏路线地图 sheet（MapView 路线卡片模式）
    @State private var mapSheetItem: MapTripSheetItem?
    /// 拖拽过程中的累积垂直位移（与 `pitch` 共同决定「有效焦点」小数）
    @State private var dragOffset: CGFloat = 0
    /// 拨动手势是否进行中（用于首次 `prepare`）
    @State private var wheelDragSessionActive = false
    /// 上一次已触发刻度的「最近邻」索引，用于跨格时只震一次
    @State private var wheelLastNearestIndex: Int?
    /// 聚焦卡片后延迟预热缺段路线
    @State private var routeWarmTask: Task<Void, Never>?
    /// 景深双缓冲：底图始终垫住，顶图淡入后再 promote，避免露亮 Atmosphere
    @State private var depthBaseImage: UIImage?
    @State private var depthBaseTripId: UUID?
    @State private var depthBaseOpacity: Double = 1
    @State private var depthTopImage: UIImage?
    @State private var depthTopTripId: UUID?
    @State private var depthTopOpacity: Double = 0
    /// 正在解码的行程 id（避免拖拽时反复 cancel/restart）
    @State private var depthCoverLoadingTripId: UUID?
    @State private var depthCoverLoadTask: Task<Void, Never>?
    
    /// 只绘制焦点附近的卡片（上下各约 2～3 张），避免顶层叠卡过远过稀
    private static let visibleCardWindow: CGFloat = 2.5
    /// 旅程卡片固定高度（内容区 + padding(20)）
    private static let cardBaseHeight: CGFloat = 220
    /// 相邻卡片中心之间的垂直间距（滚轮节距，影响拨动手感与吸附粒度）
    private static let pitch: CGFloat = 54
    /// 焦点卡中心相对内容区高度的位置（整体偏下，上半多露景深）
    private static let focusCenterYRatio: CGFloat = 0.68
    /// 焦点卡底边距内容区底的最小留白（避开 Tab / Home Indicator）
    private static let stackBottomClearance: CGFloat = 24
    
    private var displayTrips: [TravelTrip] {
        tabSnapshots.journeyTrips
    }
    
    private var tripCount: Int {
        tabSnapshots.journeyTripCount
    }
    
    /// 每张卡的强调色（仅用于底光晕 / 装饰渗色，不再整卡铺渐变）
    private let cardAccents: [Color] = [
        .orange, .mint, .indigo, .pink, .blue, .teal
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                journeyDepthBackground
                Group {
                    if displayTrips.isEmpty {
                        ContentUnavailableView(
                            "no_trips_available".localized,
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("journey_cards_empty_hint".localized)
                        )
                    } else {
                        journeyStack
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("journey_cards_tab".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            if entitlementManager.canAddTripCard(currentCount: tripCount) {
                                showingAddTrip = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Label("create_trip".localized, systemImage: "plus.circle.fill")
                        }
                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("import_trip".localized, systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddTripView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(purchaseManager)
                    .environmentObject(entitlementManager)
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(selectedURL: $selectedURL)
            }
            .alert("import_result".localized, isPresented: $showingImportResult) {
                Button("ok".localized) { }
            } message: {
                if let result = importResult {
                    switch result {
                    case .success(let trip):
                        Text("import_success".localized + ": \(trip.name)")
                    case .duplicate(let trip):
                        Text("trip_exists".localized + ": \(trip.name)")
                    case .error(let message):
                        Text("import_failed".localized + ": \(message)")
                    }
                }
            }
            .onChange(of: selectedURL) { _, newValue in
                if let url = newValue {
                    importTripFromURL(url)
                }
            }
            .onAppear {
                TabListSnapshotStore.shared.attach(modelContext: modelContext)
                TabListSnapshotStore.shared.ensureJourneyTrips()
                clampFocusedIndex()
                scheduleRouteWarm(forFocusedIndex: focusedIndex, delay: 0.15)
                scheduleDepthCoverLoad(forEffectiveFocus: effectiveFocus)
            }
            .onChange(of: displayTrips.count) { _, _ in
                clampFocusedIndex()
                scheduleDepthCoverLoad(forEffectiveFocus: effectiveFocus)
            }
            .onChange(of: focusedIndex) { _, newIndex in
                scheduleRouteWarm(forFocusedIndex: newIndex)
                scheduleDepthCoverLoad(forEffectiveFocus: effectiveFocus)
            }
            .onChange(of: dragOffset) { _, _ in
                scheduleDepthCoverLoad(forEffectiveFocus: effectiveFocus)
            }
            .onDisappear {
                routeWarmTask?.cancel()
                routeWarmTask = nil
                depthCoverLoadTask?.cancel()
                depthCoverLoadTask = nil
            }
            .navigationDestination(item: $detailTripId) { tripId in
                if let trip = tabSnapshots.trip(id: tripId) {
                    TripDetailView(trip: trip)
                } else {
                    Color.clear.onAppear { detailTripId = nil }
                }
            }
            .sheet(item: $mapSheetItem) { item in
                if let trip = tabSnapshots.trip(id: item.id) {
                    JourneyTripRouteMapSheet(trip: trip)
                        .environmentObject(brandColorManager)
                }
            }
        }
    }
    
    /// 封面氛围背景：双缓冲 crossfade；有封面则单层轻视差，否则回退 Atmosphere
    @ViewBuilder
    private var journeyDepthBackground: some View {
        ZStack {
            FootprintAtmosphereBackground(
                accent: Color.footprintRed,
                secondaryAccent: FootprintTheme.Accent.secondary
            )
            // 常驻暗垫：即使短暂露底也不会「高亮闪」
            Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            if let depthBaseImage {
                JourneyDepthScrollBackground(
                    image: depthBaseImage,
                    scrollOffset: dragOffset
                )
                .opacity(depthBaseOpacity)
            }
            if let depthTopImage {
                JourneyDepthScrollBackground(
                    image: depthTopImage,
                    scrollOffset: dragOffset
                )
                .opacity(depthTopOpacity)
            }
        }
    }
    
    private var journeyStack: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width - 40, 400)
            // 默认 ZStack 居中；下移使焦点卡落在下半带，上半多露景深背景
            let targetCenterY = geo.size.height * Self.focusCenterYRatio
            let maxCenterY = geo.size.height - Self.cardBaseHeight * 0.5 - Self.stackBottomClearance
            let centerY = min(max(targetCenterY, Self.cardBaseHeight * 0.5), maxCenterY)
            let stackOffsetY = centerY - geo.size.height * 0.5
            ZStack {
                ForEach(Array(displayTrips.enumerated()), id: \.element.id) { index, trip in
                    if abs(CGFloat(index) - effectiveFocus) <= Self.visibleCardWindow {
                        journeyCard(
                            for: trip,
                            index: index,
                            cardWidth: cardWidth,
                            effectiveFocus: effectiveFocus
                        )
                    }
                }
            }
            .offset(y: stackOffsetY)
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            // 滚轮必须优先于子视图「点按」：`Button` 会抢走手势，在卡片上拖动会被当成按钮；`highPriorityGesture` + 卡片 `onTapGesture` 可区分拖动与轻点
            .highPriorityGesture(wheelDragGesture)
        }
    }
    
    /// 按最近邻焦点加载封面；无封面则淡出，露出 Atmosphere底
    private func scheduleDepthCoverLoad(forEffectiveFocus focus: CGFloat) {
        let count = displayTrips.count
        guard count > 0 else {
            depthCoverLoadTask?.cancel()
            depthCoverLoadingTripId = nil
            clearDepthCovers(animated: false)
            return
        }
        let nearest = Int(round(min(max(focus, 0), CGFloat(count - 1))))
        guard displayTrips.indices.contains(nearest) else { return }
        let trip = displayTrips[nearest]
        let tripId = trip.id
        // 已稳定显示该封面，或正在淡入该封面
        if tripId == depthBaseTripId, depthBaseImage != nil, depthTopImage == nil { return }
        if tripId == depthTopTripId, depthTopImage != nil { return }
        if tripId == depthCoverLoadingTripId { return }
        
        if trip.coverPhotoData == nil {
            depthCoverLoadTask?.cancel()
            depthCoverLoadingTripId = nil
            clearDepthCovers(animated: true)
            return
        }
        
        depthCoverLoadTask?.cancel()
        depthCoverLoadingTripId = tripId
        let coverData = trip.coverPhotoData
        depthCoverLoadTask = Task {
            let image = await DestinationThumbnailCache.shared.imageForJourneyDepthCover(
                for: tripId,
                coverData: coverData
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard depthCoverLoadingTripId == tripId else { return }
                depthCoverLoadingTripId = nil
                guard let image else {
                    clearDepthCovers(animated: true)
                    return
                }
                applyDepthCover(image, tripId: tripId)
            }
        }
    }
    
    /// 双缓冲：有底图时顶层淡入再 promote；无底图时底图淡入
    private func applyDepthCover(_ image: UIImage, tripId: UUID) {
        if depthBaseTripId == tripId, depthBaseImage != nil, depthTopImage == nil { return }
        
        // 打断进行中的淡入：先把顶图落到底，再开新一轮
        if let top = depthTopImage, let topId = depthTopTripId, depthTopOpacity > 0.05 {
            depthBaseImage = top
            depthBaseTripId = topId
            depthBaseOpacity = 1
            depthTopImage = nil
            depthTopOpacity = 0
        }
        
        if depthBaseImage == nil {
            depthBaseImage = image
            depthBaseTripId = tripId
            depthBaseOpacity = 0
            withAnimation(.easeInOut(duration: 0.32)) {
                depthBaseOpacity = 1
            }
            return
        }
        
        depthTopImage = image
        depthTopTripId = tripId
        depthTopOpacity = 0
        withAnimation(.easeInOut(duration: 0.38)) {
            depthTopOpacity = 1
        } completion: {
            guard depthTopTripId == tripId else { return }
            depthBaseImage = image
            depthBaseTripId = tripId
            depthBaseOpacity = 1
            depthTopImage = nil
            depthTopOpacity = 0
        }
    }
    
    private func clearDepthCovers(animated: Bool) {
        guard depthBaseImage != nil || depthTopImage != nil else { return }
        let clear = {
            depthBaseOpacity = 0
            depthTopOpacity = 0
        }
        let finish = {
            depthBaseImage = nil
            depthBaseTripId = nil
            depthBaseOpacity = 1
            depthTopImage = nil
            depthTopTripId = nil
            depthTopOpacity = 0
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.28)) {
                clear()
            } completion: {
                finish()
            }
        } else {
            clear()
            finish()
        }
    }
    
    /// 连续「有效焦点」：拖拽时为小数，松手后吸附为整数 `focusedIndex`
    private var effectiveFocus: CGFloat {
        CGFloat(focusedIndex) - dragOffset / Self.pitch
    }
    
    private var wheelDragGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                var t = value.translation.height
                if focusedIndex == 0 && t > 0 { t *= 0.32 }
                if focusedIndex == displayTrips.count - 1 && t < 0 { t *= 0.32 }
                dragOffset = t
                handleWheelDragHaptics(translationY: t)
            }
            .onEnded { _ in
                wheelDragSessionActive = false
                wheelLastNearestIndex = nil
                // 必须用当前 `dragOffset`（含边界橡皮筋），与画面上的 effectiveFocus 一致；勿用惯性预测，避免「最大那张」与吸附结果不一致
                snapWheelToFrontmostCard()
            }
    }
    
    /// 有效焦点每经过一个整数格（最近邻索引变化）触发一次刻度触感，模拟滚轮段落感。
    private func handleWheelDragHaptics(translationY: CGFloat) {
        let count = displayTrips.count
        guard count > 0 else { return }
        let ef = CGFloat(focusedIndex) - translationY / Self.pitch
        let clamped = min(max(ef, 0), CGFloat(count - 1))
        let nearest = Int(round(clamped))
        if !wheelDragSessionActive {
            wheelDragSessionActive = true
            JourneyWheelHaptics.prepareTick()
            wheelLastNearestIndex = nearest
            return
        }
        if nearest != wheelLastNearestIndex {
            wheelLastNearestIndex = nearest
            JourneyWheelHaptics.playTick()
        }
    }
    
    /// 松手时：以当前画面上「离有效焦点最近」的卡片（即视觉上最大、最前）为唯一吸附目标。
    private func snapWheelToFrontmostCard() {
        let count = displayTrips.count
        guard count > 0 else {
            dragOffset = 0
            return
        }
        let ef = CGFloat(focusedIndex) - dragOffset / Self.pitch
        let clamped = min(max(ef, 0), CGFloat(count - 1))
        let newIndex = Int(round(clamped))
        // 单一 spring：勿再叠 `.animation(..., value: focusedIndex)`，避免双重回弹
        withAnimation(.spring(response: 0.34, dampingFraction: 0.92)) {
            focusedIndex = newIndex
            dragOffset = 0
        }
        // 吸附反馈已在拨动跨格时由 `playTick()` 提供，此处不再重复震动
    }
    
    @ViewBuilder
    private func journeyCard(for trip: TravelTrip, index: Int, cardWidth: CGFloat, effectiveFocus: CGFloat) -> some View {
        let distance = abs(CGFloat(index) - effectiveFocus)
        let scale = cardScale(distance: distance)
        let z = Double(900) - distance
        let maxIdx = max(displayTrips.count - 1, 0)
        let clampedFocus = min(max(effectiveFocus, 0), CGFloat(maxIdx))
        let isFocused = index == Int(round(clampedFocus))
        
        JourneyTripCardContent(
            trip: trip,
            cardNumber: index + 1,
            accent: cardAccents[index % cardAccents.count],
            isFocused: isFocused,
            brandAccent: brandColorManager.currentBrandColor,
            onMapTap: {
                mapSheetItem = MapTripSheetItem(id: trip.id)
            }
        )
        .frame(width: cardWidth, height: Self.cardBaseHeight)
        .scaleEffect(scale)
        .opacity(cardOpacity(distance: distance))
        .contentShape(RoundedRectangle(cornerRadius: FootprintTheme.Radius.card, style: .continuous))
        .onTapGesture {
            handleCardTap(trip: trip, index: index, isFocused: isFocused)
        }
        .offset(y: CGFloat(index - focusedIndex) * Self.pitch + dragOffset)
        .zIndex(z)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: trip, focused: isFocused, cardNumber: index + 1))
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : [.isButton])
    }
    
    /// 按距焦点距离连续缩放；近焦点时平滑略放大，避免 `isFocused` 硬切 1.05 造成「跳出」
    private func cardScale(distance: CGFloat) -> CGFloat {
        let t = distance
        let linear = 1.0 - 0.052 * t
        let curved = linear * (1.0 - 0.08 * min(t, 4))
        // 焦点附近 smoothstep：distance 0→1 时 boost 从 1.05→1.0
        let focusBoost: CGFloat = {
            let edge = min(max(t, 0), 1)
            let s = edge * edge * (3 - 2 * edge)
            return 1.05 - 0.05 * s
        }()
        return max(0.78, curved * focusBoost)
    }
    
    private func cardOpacity(distance: CGFloat) -> CGFloat {
        min(1.0, max(0.55, 1.0 - 0.07 * distance))
    }
    
    /// 最前一张：进详情；其余：仅滚轮聚焦到该张
    private func handleCardTap(trip: TravelTrip, index: Int, isFocused: Bool) {
        if isFocused {
            detailTripId = trip.id
            return
        }
        selectCard(at: index)
    }
    
    private func selectCard(at index: Int) {
        guard index != focusedIndex else { return }
        JourneyWheelHaptics.playSelect()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.90)) {
            focusedIndex = index
            dragOffset = 0
        }
    }
    
    private func clampFocusedIndex() {
        guard !displayTrips.isEmpty else { return }
        focusedIndex = min(max(0, focusedIndex), displayTrips.count - 1)
    }
    
    /// 聚焦停留后预热当前卡片及相邻 ±1 张的缺段路线
    private func scheduleRouteWarm(forFocusedIndex index: Int, delay: TimeInterval = 0.35) {
        routeWarmTask?.cancel()
        routeWarmTask = Task {
            let nanos = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                warmRoutes(aroundFocusedIndex: index)
            }
        }
    }
    
    private func warmRoutes(aroundFocusedIndex index: Int) {
        guard displayTrips.indices.contains(index) else { return }
        TripRoutePrewarmer.warmMissingSegments(for: displayTrips[index], maxConcurrentMisses: 3)
        if index > 0 {
            TripRoutePrewarmer.warmMissingSegments(for: displayTrips[index - 1], maxConcurrentMisses: 2)
        }
        if index + 1 < displayTrips.count {
            TripRoutePrewarmer.warmMissingSegments(for: displayTrips[index + 1], maxConcurrentMisses: 2)
        }
    }

    private func importTripFromURL(_ url: URL) {
        importResult = TripDataImporter.importTrip(from: url, modelContext: modelContext)
        NotificationCenter.default.post(name: .tripUpdated, object: nil)
        showingImportResult = true
        selectedURL = nil
    }
    
    private func accessibilityLabel(for trip: TravelTrip, focused: Bool, cardNumber: Int) -> String {
        let name = trip.name.isEmpty ? "trip_info".localized : trip.name
        let prefix = "\(cardNumber). "
        if focused {
            return "\(prefix)\(name), \("journey_cards_focused_a11y".localized)"
        }
        return "\(prefix)\(name)"
    }
}

// MARK: - 行程封面氛围背景（单层）

/// 以行程封面为氛围底：轻度模糊 + 暗角；拨动时跟轻微视差。
private struct JourneyDepthScrollBackground: View {
    let image: UIImage
    /// 与卡片堆相同的垂直拖拽位移（点）
    let scrollOffset: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    private static let blurRadius: CGFloat = 4
    private static let parallaxFactor: CGFloat = 0.15
    private static let coverScale: CGFloat = 1.12
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let drive = reduceMotion ? 0 : scrollOffset * Self.parallaxFactor
            
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width * Self.coverScale, height: size.height * Self.coverScale)
                    .blur(radius: Self.blurRadius)
                    .brightness(colorScheme == .dark ? 0.06 : 0.02)
                    .opacity(colorScheme == .dark ? 0.95 : 0.94)
                    .offset(y: drive)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                
                LinearGradient(
                    colors: [
                        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12),
                        Color.black.opacity(colorScheme == .dark ? 0.10 : 0.04),
                        Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 单旅程路线地图（全屏 MapView）

private struct MapTripSheetItem: Identifiable {
    let id: UUID
}

private struct JourneyTripRouteMapSheet: View {
    let trip: TravelTrip
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTripId: UUID?
    @State private var selectedDayFilter: Int?
    @AppStorage("mapStyle") private var mapStyleRawValue: String = MapStyle.muted.rawValue
    
    /// 与 MapView `selectedTripDayGroups` 相同的按日分组（单条行程）
    private var tripDayGroups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] {
        guard let dests = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }), !dests.isEmpty else {
            return []
        }
        let calendar = Calendar.current
        var groups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] = []
        var currentDayStart: Date?
        var currentList: [TravelDestination] = []
        for d in dests {
            let dayStart = calendar.startOfDay(for: d.visitDate)
            if dayStart != currentDayStart {
                if let prev = currentDayStart { groups.append((groups.count + 1, prev, currentList)) }
                currentDayStart = dayStart
                currentList = [d]
            } else {
                currentList.append(d)
            }
        }
        if let last = currentDayStart { groups.append((groups.count + 1, last, currentList)) }
        return groups
    }
    
    /// 导航栏中央：多日「第几天」下拉
    @ViewBuilder
    private var journeyDayFilterTitleView: some View {
        if tripDayGroups.count > 1 {
            let allTitle = "all".localized
            Menu {
                Button {
                    selectedDayFilter = nil
                } label: {
                    Label(allTitle, systemImage: selectedDayFilter == nil ? "checkmark.circle.fill" : "circle")
                }
                ForEach(tripDayGroups, id: \.dayStart) { group in
                    Button {
                        selectedDayFilter = group.dayIndex
                    } label: {
                        let title = String(format: "trip_route_day_title".localized, group.dayIndex, group.dayStart.localizedFormatted(dateStyle: .medium))
                        Label(title, systemImage: selectedDayFilter == group.dayIndex ? "checkmark.circle.fill" : "circle")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                    if let dayIndex = selectedDayFilter,
                       let group = tripDayGroups.first(where: { $0.dayIndex == dayIndex }) {
                        Text(String(format: "trip_route_day_title".localized, group.dayIndex, group.dayStart.localizedFormatted(dateStyle: .medium)))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else {
                        Text(allTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
            }
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
        }
    }
    
    private var navigationBarTitle: String {
        if tripDayGroups.count > 1 {
            return ""
        }
        return trip.name.isEmpty ? "trips".localized : trip.name
    }
    
    var body: some View {
        let prefilledRoutes: [UUID: [MKRoute?]] = {
            if let routes = TripRoutePrewarmer.prefillRoutes(for: trip) {
                return [trip.id: routes]
            }
            return [:]
        }()
        
        NavigationStack {
            MapView(
                autoShowRouteCards: true,
                selectedTripIdBinding: $selectedTripId,
                selectedDayFilterBinding: $selectedDayFilter,
                tripsOverride: [trip],
                prefilledTripRoutes: prefilledRoutes.isEmpty ? nil : prefilledRoutes
            )
            .environment(\.mapViewInNavigationStack, true)
            .navigationTitle(navigationBarTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    journeyDayFilterTitleView
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        let styles = MapStyle.allCases
                        let current = MapStyle(rawValue: mapStyleRawValue) ?? .muted
                        if let idx = styles.firstIndex(of: current), idx < styles.count - 1 {
                            mapStyleRawValue = styles[idx + 1].rawValue
                        } else {
                            mapStyleRawValue = styles[0].rawValue
                        }
                    } label: {
                        Image(systemName: (MapStyle(rawValue: mapStyleRawValue) ?? .muted).iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .accessibilityLabel("map_button_style".localized)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedTripId = trip.id
            TripRoutePrewarmer.syncSessionStoreFromCache(for: trip)
        }
    }
}

// MARK: - 滚轮拨动触感（刻度 + 点选）

private enum JourneyWheelHaptics {
    private static let tickGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    /// 手势开始时调用，降低首次刻度延迟
    static func prepareTick() {
        tickGenerator.prepare()
    }
    
    /// 最近邻索引每变化一格（滚轮过档）
    static func playTick() {
        tickGenerator.prepare()
        tickGenerator.impactOccurred(intensity: 0.68)
        // 与 MapView 一致的轻点击系统音，模拟滚轮刻度
        AudioServicesPlaySystemSound(1103)
    }
    
    /// 点按直接选中某张卡片
    static func playSelect() {
        selectGenerator.prepare()
        selectGenerator.impactOccurred()
        AudioServicesPlaySystemSound(1105)
    }
}

// MARK: - 单张卡片内容

private struct JourneyTripCardContent: View {
    let trip: TravelTrip
    /// 堆叠顺序编号（1…n，与列表位置一致）
    let cardNumber: Int
    /// 卡面强调色（底光晕 + 右上渗色），不铺满整卡
    let accent: Color
    let isFocused: Bool
    let brandAccent: Color
    let onMapTap: () -> Void
    
    private static let routeMapSymbol = "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath"
    private static let cardRadius = FootprintTheme.Radius.card
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject private var routeManager = RouteManager.shared
    @ObservedObject private var tripRoutePrecomputationStore = TripRoutePrecomputationStore.shared
    
    private var dateRangeText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: trip.startDate, to: trip.endDate)
    }
    
    /// 优先 MapView 同步的 `precomputedRoutes`，否则 `RouteManager` 缓存/直线
    private var totalMileageDisplay: String {
        let dests = trip.destinations ?? []
        let pre = tripRoutePrecomputationStore.routesByTripId[trip.id]
        let m = routeManager.totalDistanceMetersMatchingRouteCard(destinations: dests, precomputedRoutes: pre)
        guard m > 0 else { return "—" }
        return RouteManager.formatDistanceForRouteCard(m, languageManager: languageManager)
    }
    
    private var secondaryLabel: Color {
        if isFocused {
            return colorScheme == .dark
                ? Color.white.opacity(0.62)
                : FootprintChrome.secondaryLabel(.light)
        }
        return FootprintChrome.secondaryLabel(colorScheme)
    }
    
    private var primaryLabel: Color {
        if isFocused {
            return colorScheme == .dark ? Color.white : Color.primary
        }
        return Color.primary
    }
    
    private var focusedCardFill: Color {
        colorScheme == .dark ? Color(white: 0.10) : Color.white.opacity(0.94)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if !isFocused {
                // 非焦点：右上轻渗色，保留堆叠辨识度
                Ellipse()
                    .fill(accent.opacity(colorScheme == .dark ? 0.22 : 0.18))
                    .frame(width: 160, height: 110)
                    .blur(radius: 28)
                    .offset(x: 180, y: -36)
                    .allowsHitTesting(false)
                
                Ellipse()
                    .fill(brandAccent.opacity(colorScheme == .dark ? 0.14 : 0.10))
                    .frame(width: 120, height: 90)
                    .blur(radius: 24)
                    .offset(x: 210, y: 90)
                    .allowsHitTesting(false)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(cardNumber)")
                        .font(.system(size: 32, weight: isFocused ? .light : .thin))
                        .foregroundStyle(accent.opacity(isFocused ? 0.95 : 0.75))
                        .frame(minWidth: 36, alignment: .leading)
                        .accessibilityLabel(Text(verbatim: "\(cardNumber)"))
                    Spacer()
                    if isFocused {
                        Button {
                            onMapTap()
                        } label: {
                            Image(systemName: Self.routeMapSymbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.92)
                                        : Color.primary.opacity(0.88)
                                )
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(
                                        colorScheme == .dark
                                            ? Color.white.opacity(0.10)
                                            : Color.black.opacity(0.06)
                                    )
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(accent.opacity(0.85), lineWidth: 1.5)
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("map".localized)
                    }
                }
                
                Text(trip.name.isEmpty ? "—" : trip.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(primaryLabel)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateRangeText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(secondaryLabel)
                        Text("journey_cards_destinations_count".localized(with: trip.destinationCount))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryLabel)
                        Text("\("journey_cards_total_mileage".localized) \(totalMileageDisplay)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryLabel)
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(trip.durationDays)")
                            .font(.system(size: 72, weight: .black))
                            .tracking(-1)
                            .foregroundStyle(primaryLabel)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                        Text("trip_share_days".localized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(secondaryLabel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .background {
            if isFocused {
                RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous)
                    .fill(focusedCardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous)
                            .strokeBorder(FootprintChrome.cardStroke(colorScheme), lineWidth: 0.5)
                    }
            }
        }
        .modifier(JourneyCardChromeModifier(
            isFocused: isFocused,
            cornerRadius: Self.cardRadius,
            accent: accent
        ))
        .shadow(
            color: isFocused
                ? Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16)
                : .clear,
            radius: isFocused ? 18 : 0,
            x: 0,
            y: isFocused ? 10 : 0
        )
    }
}

/// 焦点：实底已自绘（深浅模式分色）；非焦点：沿用玻璃卡 + accent 底光晕
private struct JourneyCardChromeModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    let accent: Color
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if isFocused {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .footprintGlassCard(cornerRadius: cornerRadius, glow: accent.opacity(0.55))
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    return JourneyCardsStackView()
        .modelContainer(container)
        .environmentObject(LanguageManager.shared)
        .environmentObject(BrandColorManager.shared)
}
