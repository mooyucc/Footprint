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

/// 旅程列表的「压缩堆叠 + 滚轮拨动」卡片视图：拖拽切换焦点，点按直接选中。
struct JourneyCardsStackView: View {
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingAddTrip = false
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
    
    private static let stackLimit = 24
    /// 旅程卡片固定高度（内容区 + padding(20)）
    private static let cardBaseHeight: CGFloat = 220
    /// 相邻卡片中心之间的垂直间距（滚轮节距，影响拨动手感与吸附粒度）
    private static let pitch: CGFloat = 54
    
    private var displayTrips: [TravelTrip] {
        Array(trips.prefix(Self.stackLimit))
    }
    
    private let cardGradients: [(Color, Color)] = [
        (.orange.opacity(0.95), .pink.opacity(0.75)),
        (.mint, .cyan.opacity(0.85)),
        (.indigo.opacity(0.9), .purple.opacity(0.75)),
        (.yellow.opacity(0.9), .orange.opacity(0.8)),
        (.blue.opacity(0.85), .teal.opacity(0.8)),
        (.red.opacity(0.85), .orange.opacity(0.75))
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if displayTrips.isEmpty {
                    ContentUnavailableView(
                        "no_trips_available",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("journey_cards_empty_hint".localized)
                    )
                } else {
                    journeyStack
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("journey_cards_tab".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddTrip = true
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
                clampFocusedIndex()
            }
            .onChange(of: trips.count) { _, _ in
                clampFocusedIndex()
            }
            .navigationDestination(item: $detailTripId) { tripId in
                if let trip = trips.first(where: { $0.id == tripId }) {
                    TripDetailView(trip: trip)
                } else {
                    Color.clear.onAppear { detailTripId = nil }
                }
            }
            .sheet(item: $mapSheetItem) { item in
                if let trip = trips.first(where: { $0.id == item.id }) {
                    JourneyTripRouteMapSheet(trip: trip)
                        .environmentObject(brandColorManager)
                }
            }
        }
    }
    
    private var journeyStack: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width - 40, 400)
            ZStack {
                ForEach(Array(displayTrips.enumerated()), id: \.element.id) { index, trip in
                    journeyCard(
                        for: trip,
                        index: index,
                        cardWidth: cardWidth,
                        effectiveFocus: effectiveFocus
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            // 滚轮必须优先于子视图「点按」：`Button` 会抢走手势，在卡片上拖动会被当成按钮；`highPriorityGesture` + 卡片 `onTapGesture` 可区分拖动与轻点
            .highPriorityGesture(wheelDragGesture)
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
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
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
            gradient: cardGradients[index % cardGradients.count],
            isFocused: isFocused,
            brandAccent: brandColorManager.currentBrandColor,
            onMapTap: {
                mapSheetItem = MapTripSheetItem(id: trip.id)
            }
        )
        .frame(width: cardWidth, height: Self.cardBaseHeight)
        .scaleEffect(scale)
        .opacity(cardOpacity(distance: distance))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            handleCardTap(trip: trip, index: index, isFocused: isFocused)
        }
        .offset(y: CGFloat(index - focusedIndex) * Self.pitch + dragOffset)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: focusedIndex)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: dragOffset)
        .zIndex(z)
        .shadow(
            color: .black.opacity(isFocused ? 0.22 : 0.08),
            radius: isFocused ? 18 : 8,
            x: 0,
            y: isFocused ? 10 : 4
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: trip, focused: isFocused, cardNumber: index + 1))
        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : [.isButton])
    }
    
    private func cardScale(distance: CGFloat) -> CGFloat {
        let t = distance
        let linear = 1.0 - 0.052 * t
        let curved = linear * (1.0 - 0.08 * min(t, 4))
        return max(0.78, curved)
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
        withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
            focusedIndex = index
            dragOffset = 0
        }
    }
    
    private func clampFocusedIndex() {
        guard !displayTrips.isEmpty else { return }
        focusedIndex = min(max(0, focusedIndex), displayTrips.count - 1)
    }
    
    private func importTripFromURL(_ url: URL) {
        importResult = TripDataImporter.importTrip(from: url, modelContext: modelContext)
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
        NavigationStack {
            MapView(
                autoShowRouteCards: true,
                showBottomCheckInButton: false,
                showJourneyDrawer: false,
                selectedTripIdBinding: $selectedTripId,
                selectedDayFilterBinding: $selectedDayFilter,
                tripsOverride: [trip],
                hasMoreTrips: false,
                onLoadMoreTrips: nil
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
    let gradient: (Color, Color)
    let isFocused: Bool
    let brandAccent: Color
    let onMapTap: () -> Void
    
    private static let routeMapSymbol = "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath"
    
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
    
    /// 与 `RouteCard` 相同：优先 MapView 同步的 `precomputedRoutes`，否则 `RouteManager` 缓存/直线
    private var totalMileageDisplay: String {
        let dests = trip.destinations ?? []
        let pre = tripRoutePrecomputationStore.routesByTripId[trip.id]
        let m = routeManager.totalDistanceMetersMatchingRouteCard(destinations: dests, precomputedRoutes: pre)
        guard m > 0 else { return "—" }
        return RouteManager.formatDistanceForRouteCard(m, languageManager: languageManager)
    }
    
    /// 仅最前卡片 `isFocused`：略提高渐变两端 alpha，主背景比堆叠中其它张更「实」
    private func mainGradientStop(_ color: Color) -> Color {
        guard isFocused else { return color }
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(red: r, green: g, blue: b, opacity: min(1.0, a + 0.12))
        }
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, al: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &br, alpha: &al) {
            return Color(hue: h, saturation: s, brightness: br, opacity: min(1.0, al + 0.12))
        }
        return color
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [mainGradientStop(gradient.0), mainGradientStop(gradient.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 装饰圆（参考信用卡式层次）
            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28))
                .frame(width: 120, height: 120)
                .offset(x: 200, y: -40)
                .blur(radius: 0.5)
            Circle()
                .fill(brandAccent.opacity(0.35))
                .frame(width: 88, height: 88)
                .offset(x: 220, y: 100)
            
            // padding(20) 四边一致；仅标题与日期行之间一个 Spacer，把日期区压在卡片下半部
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(cardNumber)")
                        .font(.system(size: 32, weight: .thin, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(minWidth: 36, alignment: .leading)
                        .accessibilityLabel(Text(verbatim: "\(cardNumber)"))
                    Spacer()
                    if isFocused {
                        Button {
                            onMapTap()
                        } label: {
                            Image(systemName: Self.routeMapSymbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("map".localized)
                    }
                }
                
                Text(trip.name.isEmpty ? "—" : trip.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateRangeText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.92))
                        Text("journey_cards_destinations_count".localized(with: trip.destinationCount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        Text("\("journey_cards_total_mileage".localized) \(totalMileageDisplay)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    // 天数数字：与勋章页一致的大号样式；单位「天」保持原先 caption 体量
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(trip.durationDays)")
                            .font(.system(size: 72, weight: .black, design: .default))
                            .tracking(-1)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                        Text("trip_share_days".localized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(isFocused ? 0.45 : 0.2), lineWidth: isFocused ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
