//
//  TripDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import MapKit
import UIKit

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var trip: TravelTrip
    
    @State private var showingEditSheet = false
    @State private var showingAddDestination = false
    @State private var showingDeleteAlert = false
    @State private var shareItem: TripShareItem?
    @State private var shareFileItem: TripShareItem?
    @State private var showingLayoutSelection = false // 控制版面选择视图显示
    @State private var selectedLayout: TripShareLayout = .extendedGrid
    @State private var showingAIDescription = false
    @State private var showAICreditPaywall = false
    /// 缓存封面 UIImage，避免滚动每帧 Data→UIImage 解码造成抖动
    @State private var cachedCoverImage: UIImage?
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @ObservedObject private var tripRouteStore = TripRoutePrecomputationStore.shared
    /// 滚动探针不触发刷新；只在当前站点变化时更新界面
    @State private var scrollProbe = TripScrollProbe()
    @State private var activeStopID: UUID?
    
    /// 视差：封面相对滚动位移倍率；下拉放大上限
    private static let coverParallaxFactor: CGFloat = 0.5
    private static let coverMaxPullScale: CGFloat = 1.25
    /// 内容长卡上移盖住封面下沿
    private static let coverSheetOverlap: CGFloat = 28
    private static let scrollCoordinateSpace = "tripDetailScroll"
    /// 导航栏按钮行高度；忽略安全区后 GeometryReader 读不到这段
    private static let navigationBarHeight: CGFloat = 44
    
    /// 状态栏 + 按钮行。时间轴停在这排按钮下方。
    private var navigationPinInset: CGFloat {
        Self.keyWindowSafeTop + Self.navigationBarHeight
    }
    
    private static var keyWindowSafeTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return window?.safeAreaInsets.top ?? 59
    }
    
    private func refreshCachedCoverImage() {
        if let data = trip.coverPhotoData, let image = UIImage(data: data) {
            cachedCoverImage = image
        } else {
            cachedCoverImage = nil
        }
    }
    
    var sortedDestinations: [TravelDestination] {
        trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
    }
    
    /// 按日历「天」分组的目的地，用于多日行程按天展示；单日行程不显示日期标题
    private var destinationsByDay: [TripDayGroup] {
        let calendar = Calendar.current
        let sorted = sortedDestinations
        guard !sorted.isEmpty else { return [] }
        var groups: [(dayStart: Date, destinations: [TravelDestination])] = []
        var currentDayStart: Date?
        var currentList: [TravelDestination] = []
        for d in sorted {
            let dayStart = calendar.startOfDay(for: d.visitDate)
            if dayStart != currentDayStart {
                if let prev = currentDayStart { groups.append((prev, currentList)) }
                currentDayStart = dayStart
                currentList = [d]
            } else {
                currentList.append(d)
            }
        }
        if let last = currentDayStart { groups.append((last, currentList)) }
        return groups.enumerated().map { index, element in
            TripDayGroup(dayStart: element.dayStart, dayIndex: index + 1, destinations: element.destinations)
        }
    }
    
    /// 单日行程不显示「第 N 天」标题，仅多日时显示
    private var shouldShowDayHeaders: Bool {
        destinationsByDay.count > 1
    }
    
    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    @ViewBuilder
    private func tripRouteDaySection(group: TripDayGroup) -> some View {
        let dayTitle = String(format: "trip_route_day_title".localized, group.dayIndex, group.dayStart.localizedFormatted(dateStyle: .medium))
        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                .padding(.horizontal, 2)
            ForEach(group.destinations) { destination in
                tripDestinationLink(destination)
            }
        }
    }
    
    /// 按到访顺序去重后的地点名
    private var tripCoverPlaceNames: String {
        var seen = Set<String>()
        return sortedDestinations.compactMap { destination -> String? in
            let name = destination.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { return nil }
            return name
        }
        .joined(separator: " · ")
    }
    
    /// 右下角年份；跨年写成区间
    private var tripCoverYearText: String {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: trip.startDate)
        let endYear = calendar.component(.year, from: trip.endDate)
        return startYear == endYear ? String(startYear) : "\(startYear) – \(endYear)"
    }
    
    /// 时期不含年份，年份单独放右下角
    private var tripCoverPeriodText: String {
        let start = tripCoverShortDate(trip.startDate)
        let end = tripCoverShortDate(trip.endDate)
        if Calendar.current.isDate(trip.startDate, inSameDayAs: trip.endDate) { return start }
        return "\(start) – \(end)"
    }
    
    private func tripCoverShortDate(_ date: Date) -> String {
        let formatter = languageManager.localizedDateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
    
    /// 封面海报字：标题最大，其下描述、时期、地点，右下年份
    private func tripCoverPoster(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)
            
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    
                    if !trip.desc.isEmpty {
                        Text(trip.desc)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                    }
                    
                    Text(tripCoverPeriodText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.top, 8)
                    
                    if !tripCoverPlaceNames.isEmpty {
                        Text(tripCoverPlaceNames)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                            .padding(.top, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(tripCoverYearText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .offset(y: 12)
            }
            .offset(y: 20)
            .padding(.horizontal, 20)
            .padding(.bottom, Self.coverSheetOverlap + 44)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
    }
    
    /// 封面底图（无标题）；外层负责视差 / 位移
    @ViewBuilder
    private func tripCoverArtwork(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let uiImage = cachedCoverImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                ZStack {
                    brandColorManager.currentBrandColor.opacity(colorScheme == .dark ? 0.28 : 0.18)
                    Ellipse()
                        .fill(brandColorManager.currentBrandColor.opacity(0.45))
                        .frame(width: width * 0.9, height: width * 0.55)
                        .blur(radius: 40)
                        .offset(x: width * 0.15, y: -height * 0.1)
                    Ellipse()
                        .fill(FootprintTheme.Accent.secondary.opacity(0.28))
                        .frame(width: width * 0.7, height: width * 0.45)
                        .blur(radius: 36)
                        .offset(x: -width * 0.2, y: height * 0.2)
                }
                .frame(width: width, height: height)
            }
            
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.38), location: 0),
                    .init(color: .black.opacity(0.08), location: 0.38),
                    .init(color: .black.opacity(0.55), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipped()
    }
    
    /// 底层全宽封面：高度固定（减抖动）；下拉钉顶 + 只往下 scale；上滑逐渐透明
    @ViewBuilder
    private func tripParallaxCover(width: CGFloat, height: CGFloat, safeTop: CGFloat) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(Self.scrollCoordinateSpace)).minY
            let pull = max(0, minY)
            let scrollUp = max(0, -minY)
            
            // 下拉：固定 frame，仅 scaleEffect(anchor: .top)，避免每帧改布局高度
            let pullScale: CGFloat = {
                guard !reduceMotion, height > 0, pull > 0 else { return 1 }
                return min(1 + pull / height, Self.coverMaxPullScale)
            }()
            
            let imageOffsetY: CGFloat = {
                if reduceMotion { return 0 }
                // 下拉：抵消橡皮筋，顶边贴屏幕上沿；上滑：视差 ×0.5
                if pull > 0 { return -minY }
                return -minY * Self.coverParallaxFactor
            }()
            
            // 文字随封面一起滚走；下拉时与图同用 -minY 钉顶
            let titlePinOffset: CGFloat = (!reduceMotion && pull > 0) ? -minY : 0
            // 时间轴顶到按钮下沿时，封面刚好完全透明
            let fadeDistance = max(height - safeTop - Self.coverSheetOverlap, 1)
            let coverOpacity: CGFloat = pull > 0 ? 1 : max(0, 1 - scrollUp / fadeDistance)
            
            ZStack(alignment: .top) {
                tripCoverArtwork(width: width, height: height)
                    .frame(width: width, height: height, alignment: .top)
                    .scaleEffect(pullScale, anchor: .top)
                    .offset(y: imageOffsetY)
                
                tripCoverPoster(width: width, height: height)
                    .offset(y: titlePinOffset)
                    .allowsHitTesting(false)
            }
            .opacity(coverOpacity)
            // 禁止隐式动画与滚动抢同步（真机抖动主因之一）
            .transaction { $0.animation = nil }
        }
        // 不 clipped：下拉 scale 可往下延伸且钉顶不露白；上滑溢出由长卡盖住
        .frame(width: width, height: height, alignment: .top)
    }
    
    /// 上层长卡：行程路线 + 地点，四角圆角盖住封面
    @ViewBuilder
    private func tripContentSheet(minHeight: CGFloat) -> some View {
        let sheetRadius = FootprintTheme.Radius.sheet
        VStack(alignment: .leading, spacing: 20) {
            tripRouteSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: sheetRadius, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, y: -4)
        }
    }
    
    /// 时间轴站点：词典能对上的城市用英文主名、中文副名
    private var tripRouteTimelineStops: [TripRouteTimelineStop] {
        let destinations = sortedDestinations
        let legs = tripRouteLegMeters(for: destinations)
        return destinations.enumerated().map { index, destination in
            let names = tripRouteStopNames(for: destination)
            return TripRouteTimelineStop(
                id: destination.id,
                primary: names.primary,
                secondary: names.secondary,
                isOrigin: index == 0,
                incomingMeters: index == 0 ? nil : legs[index - 1]
            )
        }
    }
    
    private var tripRouteSummaryText: String {
        let countText = "\(sortedDestinations.count) \("locations".localized)"
        let meters = tripRouteTimelineStops.compactMap(\.incomingMeters).reduce(0, +)
        guard meters > 1 else { return countText }
        let distance = RouteManager.formatDistanceForRouteCard(meters, languageManager: languageManager)
        return "\(distance) · \(countText)"
    }
    
    private func tripRouteLegMeters(for destinations: [TravelDestination]) -> [CLLocationDistance] {
        guard destinations.count >= 2 else { return [] }
        let segmentCount = destinations.count - 1
        if let routes = tripRouteStore.precomputedRoutes(for: trip.id, segmentCount: segmentCount) {
            return (0..<segmentCount).map { index in
                let meters = routes[index].footprintDistance
                if meters > 1 { return meters }
                return RouteManager.calculateDistance(
                    from: destinations[index].coordinate,
                    to: destinations[index + 1].coordinate
                )
            }
        }
        return (0..<segmentCount).map { index in
            let from = destinations[index].coordinate
            let to = destinations[index + 1].coordinate
            if let route = RouteManager.shared.getCachedRoute(from: from, to: to), route.footprintDistance > 1 {
                return route.footprintDistance
            }
            return RouteManager.calculateDistance(from: from, to: to)
        }
    }
    
    private func tripRouteStopNames(for destination: TravelDestination) -> (primary: String, secondary: String?) {
        let raw = destination.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let city = CityDataManager.shared.findCity(by: raw),
           tripRouteNameMatchesCity(raw, city: city) {
            let secondary = city.chineseName == city.englishName ? nil : city.chineseName
            return (city.englishName, secondary)
        }
        let province = destination.province.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = destination.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondarySource = province.isEmpty ? country : province
        let secondary = secondarySource.isEmpty || secondarySource == raw ? nil : secondarySource
        return (raw, secondary)
    }
    
    private func tripDestinationLink(_ destination: TravelDestination) -> some View {
        NavigationLink {
            DestinationDetailView(destination: destination)
        } label: {
            DestinationRowCard(destination: destination, highResolutionCover: true)
        }
        .buttonStyle(.plain)
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: TripStopAnchorKey.self,
                    value: [destination.id: geo.frame(in: .named(Self.scrollCoordinateSpace)).minY]
                )
            }
        }
    }
    
    /// 判定线从时间轴底边出发，地点卡上移时它下移，滚到底时落到最后一张卡的顶边。
    /// 点亮顶边已越过这条线的最后一站。
    private func syncActiveStop() {
        let count = sortedDestinations.count
        if scrollProbe.trackedStopCount != count {
            scrollProbe.trackedStopCount = count
            scrollProbe.gapMax = 0
        }
        
        let ordered = sortedDestinations.compactMap { destination -> (id: UUID, minY: CGFloat)? in
            guard let minY = scrollProbe.anchors[destination.id] else { return nil }
            return (destination.id, minY)
        }
        guard let first = ordered.first else {
            let fallback = sortedDestinations.first?.id
            if activeStopID != fallback { activeStopID = fallback }
            return
        }
        guard scrollProbe.timelineHeight > 1,
              scrollProbe.timelineMinY < .greatestFiniteMagnitude / 2 else {
            if activeStopID != first.id { activeStopID = first.id }
            return
        }
        
        let timelineBottom = scrollProbe.timelineMinY + scrollProbe.timelineHeight
        let isPinned = scrollProbe.timelineMinY <= scrollProbe.safeTop + 4
        let anchorsReady = ordered.count == count
            && scrollProbe.viewportBottom > 1
            && scrollProbe.bottomSentinelY < .greatestFiniteMagnitude / 2
        var line = timelineBottom
        if isPinned && anchorsReady {
            // 底部安全区会让列表底边停在视口底边之上，留一点余量进度才能走到 1
            let gap = max(0, scrollProbe.bottomSentinelY - scrollProbe.viewportBottom - 48)
            if gap > scrollProbe.gapMax {
                scrollProbe.gapMax = gap
            }
            let span = scrollProbe.gapMax
            let t = span > 1 ? (1 - min(gap / span, 1)) : 0
            let lastY = ordered[ordered.count - 1].minY
            let lastAtEnd = lastY - gap
            let descend = max(0, lastAtEnd - timelineBottom)
            line = timelineBottom + t * descend
            if t >= 1 {
                line = max(line, lastY)
            }
        }
        
        let next = ordered.last(where: { $0.minY <= line })?.id ?? first.id
        if next != activeStopID {
            activeStopID = next
        }
    }
    
    private func tripRouteNameMatchesCity(_ name: String, city: CityInfo) -> Bool {
        let normalized = name.lowercased().replacingOccurrences(of: " ", with: "")
        let english = city.englishName.lowercased().replacingOccurrences(of: " ", with: "")
        let chinese = city.chineseName.replacingOccurrences(of: " ", with: "")
        return normalized == english || normalized == chinese
    }
    
    /// 跟着滚动上移，顶到导航栏下沿后由分组头固定
    private var tripTimelineHeader: some View {
        TripRouteTimelineCard(
            stops: tripRouteTimelineStops,
            summary: tripRouteSummaryText,
            accent: brandColorManager.currentBrandColor,
            activeID: activeStopID
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geo in
                let frame = geo.frame(in: .named(Self.scrollCoordinateSpace))
                Color.clear.preference(
                    key: TripTimelineFrameKey.self,
                    value: TripTimelineFrame(minY: frame.minY, height: geo.size.height)
                )
            }
        }
    }
    
    @ViewBuilder
    private var tripRouteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sortedDestinations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 44))
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                    
                    Text("no_destinations_added".localized)
                        .font(.subheadline)
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showingAddDestination = true
                    } label: {
                        Label("add_destination".localized, systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(brandColorManager.currentBrandColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if shouldShowDayHeaders {
                        ForEach(destinationsByDay) { group in
                            tripRouteDaySection(group: group)
                        }
                    } else {
                        ForEach(sortedDestinations) { destination in
                            tripDestinationLink(destination)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let coverWidth = geometry.size.width
            let pinInset = navigationPinInset
            let _ = scrollProbe.syncSafeTop(pinInset)
            // 封面约占屏高 45%；已 ignoresSafeArea 顶到最上沿，不再叠 pinInset
            let coverHeight = geometry.size.height * 0.45
            let sheetBottomGap: CGFloat = 20
            let sheetMinHeight = max(
                geometry.size.height - coverHeight + Self.coverSheetOverlap - sheetBottomGap,
                280
            )
            // 垫片顶到屏幕上沿时，卡片正好停在返回 / 分享按钮下方
            let headerSpacer = pinInset
            
            ScrollView {
                LazyVStack(spacing: -(headerSpacer + Self.coverSheetOverlap), pinnedViews: [.sectionHeaders]) {
                    tripParallaxCover(
                        width: coverWidth,
                        height: coverHeight,
                        safeTop: pinInset
                    )
                    
                    if sortedDestinations.isEmpty {
                        tripContentSheet(minHeight: sheetMinHeight)
                            .padding(.bottom, sheetBottomGap)
                    } else {
                        Section {
                            tripRouteSection
                                .padding(.horizontal, 16)
                                // LazyVStack 负 spacing 也会作用在 header↔content 之间，这里抵消并把地点卡推回时间轴下方
                                .padding(.top, headerSpacer + Self.coverSheetOverlap + 12)
                                .padding(.bottom, sheetBottomGap)
                                .frame(maxWidth: .infinity, minHeight: sheetMinHeight, alignment: .topLeading)
                                .background {
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: TripScrollBottomKey.self,
                                            value: geo.frame(in: .named(Self.scrollCoordinateSpace)).maxY
                                        )
                                    }
                                }
                        } header: {
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: headerSpacer)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                                tripTimelineHeader
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TripViewportBottomKey.self,
                        value: geo.frame(in: .named(Self.scrollCoordinateSpace)).maxY
                    )
                }
                .frame(height: 1)
                .allowsHitTesting(false)
            }
            .coordinateSpace(name: Self.scrollCoordinateSpace)
        }
        .ignoresSafeArea(edges: .top)
        .appPageBackgroundGradient(for: colorScheme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingLayoutSelection = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(uiColor: .label))
                            .symbolRenderingMode(.monochrome)
                            .offset(x: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("share".localized))
                    
                    Button {
                        if canUseAI {
                            showingAIDescription = true
                        } else {
                            showAICreditPaywall = true
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(uiColor: .label))
                            .symbolRenderingMode(.monochrome)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("ai_function_trip_desc_title".localized))
                    
                    Menu {
                        Button {
                            openTripInMaps()
                        } label: {
                            tripDetailMenuRow(title: "open_in_maps".localized, systemImage: "map", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        .disabled(sortedDestinations.isEmpty)
                        
                        Button {
                            shareTripToTeam()
                        } label: {
                            tripDetailMenuRow(title: "share_to_team".localized, systemImage: "person.2.fill", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button {
                            showingEditSheet = true
                        } label: {
                            tripDetailMenuRow(title: "edit_trip".localized, systemImage: "pencil", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showingAddDestination = true
                        } label: {
                            tripDetailMenuRow(title: "add_destination".localized, systemImage: "plus", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            tripDetailMenuRow(title: "delete_trip".localized, systemImage: "trash", style: .destructive)
                        }
                        .buttonStyle(.plain)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color(uiColor: .label))
                            .symbolRenderingMode(.monochrome)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("more_options".localized))
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTripView(trip: trip)
        }
        .sheet(isPresented: $showingAddDestination) {
            AddDestinationToTripView(trip: trip)
        }
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                // 只分享图片，不分享文字
                SystemShareSheet(items: [image])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .sheet(item: $shareFileItem) { item in
            if let url = item.url {
                SystemShareSheet(items: [url])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .sheet(isPresented: $showingLayoutSelection) {
            TripShareLayoutSelectionView(trip: trip, selectedLayout: $selectedLayout)
        }
        .sheet(isPresented: $showingAIDescription) {
            AIActionSheet(trip: trip, action: .generateDescription)
        }
        .sheet(isPresented: $showAICreditPaywall) {
            AICreditPaywallView()
                .environmentObject(aiCreditManager)
        }
        .alert("delete_trip".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                deleteTrip()
            }
        } message: {
            Text("confirm_delete_trip".localized)
        }
        .onAppear {
            refreshCachedCoverImage()
            if activeStopID == nil {
                activeStopID = sortedDestinations.first?.id
            }
        }
        .onPreferenceChange(TripTimelineFrameKey.self) { frame in
            scrollProbe.timelineMinY = frame.minY
            scrollProbe.timelineHeight = frame.height
            syncActiveStop()
        }
        .onPreferenceChange(TripStopAnchorKey.self) { anchors in
            scrollProbe.anchors = anchors
            syncActiveStop()
        }
        .onPreferenceChange(TripScrollBottomKey.self) { bottom in
            scrollProbe.bottomSentinelY = bottom
            syncActiveStop()
        }
        .onPreferenceChange(TripViewportBottomKey.self) { bottom in
            scrollProbe.viewportBottom = bottom
            syncActiveStop()
        }
        .onChange(of: trip.coverPhotoData) { _, _ in
            refreshCachedCoverImage()
        }
    }
    
    private func deleteTrip() {
        modelContext.delete(trip)
        dismiss()
    }
    
    private func shareTripToTeam() {
        // 导出旅程数据为JSON文件
        guard let fileURL = TripDataExporter.exportTrip(trip) else {
            // 导出失败，显示错误提示
            return
        }
        
        // 生成分享文本
        let shareText = TripDataExporter.generateShareText(for: trip)
        
        // 创建分享项
        shareFileItem = TripShareItem(text: shareText, image: nil, url: fileURL)
    }
    
    /// 在「地图」App 中打开本旅程路线
    private func openTripInMaps() {
        let destinations = sortedDestinations
        guard !destinations.isEmpty else { return }
        
        var mapItems: [MKMapItem] = []
        for destination in destinations {
            let placemark = MKPlacemark(coordinate: destination.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = destination.name
            mapItems.append(mapItem)
        }
        guard !mapItems.isEmpty else { return }
        
        let options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: "d",
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ]
        
        if mapItems.count == 1 {
            mapItems[0].openInMaps(launchOptions: options)
        } else {
            MKMapItem.openMaps(with: mapItems, launchOptions: options)
        }
    }
    
    private enum TripDetailMenuRowStyle {
        case neutral
        case destructive
    }
    
    /// 使用 `HStack` 而非 `Label`，避免菜单项图标被当作模板而染上 accent/主题色。
    private func tripDetailMenuRow(title: String, systemImage: String, style: TripDetailMenuRowStyle) -> some View {
        let iconAndText: Color = {
            switch style {
            case .neutral: return Color(UIColor.label)
            case .destructive: return Color(UIColor.systemRed)
            }
        }()
        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body)
                .imageScale(.medium)
                .foregroundStyle(iconAndText)
                .symbolRenderingMode(.monochrome)
                .frame(width: 22, height: 22, alignment: .center)
            Text(title)
                .font(.body)
                .foregroundStyle(iconAndText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// 行程时间轴上的一站
private struct TripRouteTimelineStop: Identifiable {
    let id: UUID
    let primary: String
    let secondary: String?
    let isOrigin: Bool
    /// 与上一站的距离（米）；第一站为 nil
    let incomingMeters: CLLocationDistance?
}

/// 玻璃行程时间轴：右上角总里程与站数，站间标距离；超出一屏横向滑动
private struct TripRouteTimelineCard: View {
    let stops: [TripRouteTimelineStop]
    let summary: String
    let accent: Color
    let activeID: UUID?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let minColumnWidth: CGFloat = 76
    @State private var viewportWidth: CGFloat = 0
    
    private var columnWidth: CGFloat {
        guard viewportWidth > 1, !stops.isEmpty else { return minColumnWidth }
        return max(minColumnWidth, viewportWidth / CGFloat(stops.count))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(summary)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                            stopColumn(stop, isFirst: index == 0)
                                .frame(width: columnWidth)
                                .id(stop.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: TripRouteCardWidthKey.self, value: geo.size.width)
                    }
                }
                .onPreferenceChange(TripRouteCardWidthKey.self) { newWidth in
                    if newWidth > 1, abs(newWidth - viewportWidth) > 0.5 {
                        viewportWidth = newWidth
                    }
                }
                .onChange(of: activeID) { _, id in
                    guard let id else { return }
                    if reduceMotion {
                        proxy.scrollTo(id, anchor: .center)
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .footprintGlassCard()
        .accessibilityElement(children: .contain)
    }
    
    private func stopColumn(_ stop: TripRouteTimelineStop, isFirst: Bool) -> some View {
        let isActive = stop.id == activeID || (activeID == nil && stop.isOrigin)
        let nameColor = isActive ? accent : Color.primary
        let secondaryColor = isActive ? accent.opacity(0.85) : FootprintChrome.secondaryLabel(colorScheme)
        let lineColor = FootprintChrome.hairline(colorScheme)
        return VStack(spacing: 4) {
            Text(distanceLabel(for: stop))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FootprintChrome.tertiaryLabel(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: isFirst ? columnWidth * 0.9 : columnWidth, height: 12)
                .offset(x: isFirst ? 0 : -columnWidth / 2, y: 4)
            
            ZStack {
                if !isFirst {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: columnWidth, height: FootprintChrome.hairlineHeight)
                        .offset(x: -columnWidth / 2)
                }
                if isActive {
                    Circle()
                        .fill(accent)
                        .frame(width: 16, height: 16)
                } else {
                    Circle()
                        .stroke(FootprintChrome.secondaryLabel(colorScheme), lineWidth: 1.5)
                        .frame(width: 11, height: 11)
                }
            }
            .frame(height: 18)
            
            VStack(spacing: 2) {
                Text(stop.primary)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(nameColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                if let secondary = stop.secondary, !secondary.isEmpty {
                    Text(secondary)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
    
    private func distanceLabel(for stop: TripRouteTimelineStop) -> String {
        guard let meters = stop.incomingMeters, meters > 1 else { return " " }
        return RouteManager.formatDistanceForRouteCard(meters, languageManager: LanguageManager.shared)
    }
}

private struct TripRouteCardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TripTimelineFrame: Equatable {
    var minY: CGFloat
    var height: CGFloat
}

private struct TripTimelineFrameKey: PreferenceKey {
    static var defaultValue = TripTimelineFrame(minY: .greatestFiniteMagnitude, height: 0)
    static func reduce(value: inout TripTimelineFrame, nextValue: () -> TripTimelineFrame) {
        let next = nextValue()
        if next.height > 0 { value = next }
    }
}

private struct TripStopAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// 地点列表底边，用来判断是否已经滚到底
private struct TripScrollBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

/// 滚动视口底边，与地点锚点同一坐标空间
private struct TripViewportBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 滚动中的时间轴位置与地点顶边，避免每帧刷新整页
private final class TripScrollProbe {
    var safeTop: CGFloat = 0
    var viewportBottom: CGFloat = 0
    var timelineMinY: CGFloat = .greatestFiniteMagnitude
    var timelineHeight: CGFloat = 0
    var anchors: [UUID: CGFloat] = [:]
    var bottomSentinelY: CGFloat = .greatestFiniteMagnitude
    /// 吸顶后见过的最大剩余滚动量，用来把进度归一化到 0...1
    var gapMax: CGFloat = 0
    var trackedStopCount: Int = -1
    
    func syncSafeTop(_ value: CGFloat) {
        if abs(safeTop - value) > 0.5 {
            safeTop = value
        }
    }
}

/// 按天分组的一批目的地，用于行程路线按天展示
private struct TripDayGroup: Identifiable {
    let dayStart: Date
    let dayIndex: Int
    let destinations: [TravelDestination]
    var id: Date { dayStart }
}

#Preview {
    NavigationStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: TravelTrip.self, TravelDestination.self,
            configurations: config
        )
        
        let trip = TravelTrip(
            name: "2025年10月青甘大环线",
            desc: "穿越青海甘肃的美丽风光",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7)
        )
        container.mainContext.insert(trip)
        
        return TripDetailView(trip: trip)
            .modelContainer(container)
            .environmentObject(LanguageManager.shared)
            .environmentObject(BrandColorManager.shared)
            .environmentObject(EntitlementManager.shared)
            .environmentObject(AICreditManager.shared)
    }
}

