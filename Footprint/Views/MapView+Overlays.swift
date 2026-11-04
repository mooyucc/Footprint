//
//  MapView+Overlays.swift
//  Footprint
//
//  从 MapView.swift 拆分（编译加速）
//

import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import Combine
import AudioToolbox
import UIKit
import PhotosUI
import Photos
import ImageIO
import Contacts

extension MapView {
    @ViewBuilder
    var dismissOverlay: some View {
        if showingPOIPreview || selectedDestination != nil {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        if showingPOIPreview {
                            showingPOIPreview = false
                            selectedPOI = nil
                        }
                        if selectedDestination != nil {
                            selectedDestination = nil
                            mapSelection = nil
                        }
                    }
                }
                .zIndex(1)
        }
    }
    
    // 键盘覆盖层：当搜索栏显示且有焦点时，阻止地图交互
    @ViewBuilder
    var keyboardOverlay: some View {
        if showSearchBar && isSearchFocused {
            // 使用 GeometryReader 来覆盖键盘区域
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    // 覆盖键盘区域，阻止地图交互
                    // 使用 clear 颜色但拦截事件，阻止传递到地图
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: max(geometry.size.height * 0.45, 350)) // 覆盖键盘区域（约屏幕高度的45%，至少350点）
                        .allowsHitTesting(true) // 允许接收事件，阻止事件传递到地图
                        .onTapGesture {
                            // 空手势处理，拦截点击事件，阻止传递到地图层
                            // 这样点击键盘区域时不会关闭搜索框
                        }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .allowsHitTesting(true) // 确保覆盖层可以接收事件
            .zIndex(1.5) // 在地图之上（zIndex 0），但在搜索框和按钮容器之下（zIndex 4）
        }
    }
    
    // 预览卡片
    var previewCard: some View {
        VStack {
            Spacer()
            if showingPOIPreview, let poi = selectedPOI {
                POIPreviewCard(mapItem: poi, onAddDestination: {
                    // 点击"添加目的地"按钮，打开添加目的地界面
                    handlePOIAddDestination(poi: poi)
                }, onDismiss: {
                    // 关闭POI预览
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showingPOIPreview = false
                        selectedPOI = nil
                    }
                })
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isSearchingPOI {
                // 显示加载状态的POI搜索卡片
                POISearchingCard()
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .zIndex(2)
    }
    
    // 获取排序后的地点列表（带缓存，避免重复排序）
    func sortedDestinations(for tripId: UUID) -> [TravelDestination] {
        // 检查缓存
        if let cached = sortedDestinationsCache[tripId] {
            return cached
        }
        
        // 查找旅程并排序
        if let trip = effectiveTrips.first(where: { $0.id == tripId }),
           let destinations = trip.destinations {
            let sorted = destinations.sorted(by: { $0.visitDate < $1.visitDate })
            // 延迟写入缓存，避免在视图更新期间修改 @State（消除 "Modifying state during view update" 并防止多余重绘）
            let tid = tripId
            DispatchQueue.main.async {
                sortedDestinationsCache[tid] = sorted
            }
            return sorted
        }
        
        return []
    }
    
    // 清除排序缓存（当地点发生变化时调用）
    func clearSortedDestinationsCache(for tripId: UUID? = nil) {
        if let tripId = tripId {
            sortedDestinationsCache.removeValue(forKey: tripId)
        } else {
            sortedDestinationsCache.removeAll()
        }
    }
    
    /// 当前选中旅程按天分组（用于「第几天」筛选）
    var selectedTripDayGroups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] {
        guard let tripId = selectedTripId,
              let trip = effectiveTrips.first(where: { $0.id == tripId }),
              let dests = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }), !dests.isEmpty else {
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
    
    /// 当前选中旅程、考虑「第几天」筛选后的目的地列表（用于连线和标注）
    var visibleDestinationsForSelectedTrip: [TravelDestination] {
        guard let tripId = selectedTripId else { return [] }
        let sorted = sortedDestinations(for: tripId)
        guard !sorted.isEmpty else { return [] }
        guard let dayIndex = selectedDayFilter,
              let group = selectedTripDayGroups.first(where: { $0.dayIndex == dayIndex }) else {
            return sorted
        }
        return group.destinations
    }
    
    /// 当前选中旅程、考虑「第几天」筛选后的路线段（与 visibleDestinationsForSelectedTrip 对应）
    var visibleRoutesForSelectedTrip: (destinations: [TravelDestination], routes: [MKRoute?]) {
        let allSorted = sortedDestinations(for: selectedTripId ?? UUID())
        guard let tripId = selectedTripId, !allSorted.isEmpty else { return ([], []) }
        guard let dayIndex = selectedDayFilter,
              let group = selectedTripDayGroups.first(where: { $0.dayIndex == dayIndex }) else {
            let routes = tripRoutes[tripId] ?? []
            return (allSorted, routes)
        }
        let dayDests = group.destinations
        guard dayDests.count >= 2 else { return (dayDests, []) }
        let startIndex = allSorted.firstIndex(where: { $0.id == dayDests.first!.id }) ?? 0
        let fullRoutes = tripRoutes[tripId] ?? []
        let segmentCount = dayDests.count - 1
        let routeSlice = (0..<segmentCount).map { i in
            let idx = startIndex + i
            return idx < fullRoutes.count ? fullRoutes[idx] : nil as MKRoute?
        }
        return (dayDests, routeSlice)
    }
    
    // 清除聚合缓存（用于旅程切换等）
    var floatingButtons: some View {
        ZStack {
            // 顶部地图样式切换按钮（与“发现”tab保持一致）；嵌入 NavigationStack 时由父视图导航栏 leading 放置，此处不显示
            if !showSearchBar, !mapViewInNavigationStack {
                VStack {
                    topToolbar
                    Spacer()
                }
            }
            
            // iOS 26标准搜索栏覆盖层
            if showSearchBar {
                VStack {
                    searchBarOverlay
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if shouldShowAssistiveMenu {
                GeometryReader { proxy in
                    FloatingAssistiveMenu(
                        actions: assistiveMenuActions,
                        isExpanded: $assistiveMenuExpanded,
                        position: $assistiveMenuPosition,
                        canvasSize: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        menuTitle: "map_button_menu".localized,
                        isDarkStyle: colorScheme == .dark || isDarkMapStyle,
                        highlightColor: brandColorManager.currentBrandColor,
                        showHighlightBadge: !hasUsedMapAIAssistant,
                        iconProvider: { icon, isActive, isHighlighted in
                            menuIcon(for: icon, isActive: isActive, isHighlighted: isHighlighted)
                        }
                    )
                    .onAppear {
                        if assistiveMenuPosition == .zero {
                            assistiveMenuPosition = FloatingAssistiveMenu.defaultPosition(
                                in: proxy.size,
                                safeArea: proxy.safeAreaInsets
                            )
                        } else {
                            assistiveMenuPosition = FloatingAssistiveMenu.clamp(
                                assistiveMenuPosition,
                                in: proxy.size,
                                safeArea: proxy.safeAreaInsets,
                                requiresMenuSpace: false
                            )
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .zIndex(4) // 确保浮动按钮在折叠覆盖层之上
        .onChange(of: shouldShowAssistiveMenu) { newValue in
            if !newValue {
                assistiveMenuExpanded = false
            }
        }
    }
    
    // 顶部工具栏：地图样式切换按钮（与嵌入导航栏中的按钮一致：LinearGradient 图标 + 与导航栏相同的 .bar 背景）
    var topToolbar: some View {
        HStack {
            Button {
                // 循环切换地图样式
                let styles = MapStyle.allCases
                if let currentIndex = styles.firstIndex(of: currentMapStyle),
                   currentIndex < styles.count - 1 {
                    mapStyleRawValue = styles[currentIndex + 1].rawValue
                } else {
                    mapStyleRawValue = styles[0].rawValue
                }
            } label: {
                Image(systemName: currentMapStyle.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .footprintMapGlassCircle(diameter: 44, isDarkMap: isDarkMapStyle)
            }
            .accessibilityLabel("map_button_style".localized)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        // 无额外 top padding，紧贴安全区顶部（此前上方废弃的旅程按钮已移除）
    }
    
    var bottomCheckInButton: some View {
        Button {
            handleCheckIn()
        } label: {
            ZStack {
                // 外圈脉冲光晕（品牌色，呼吸感）
                Circle()
                    .fill(brandColorManager.currentBrandColor.opacity(0.25))
                    .frame(width: 92, height: 92)
                    .scaleEffect(checkInPulseScale)
                    .opacity(checkInPulseOpacity)
                
                checkInIcon
                    .footprintMapBrandGlassCircle(
                        diameter: 72,
                        brand: brandColorManager.currentBrandColor,
                        isDark: colorScheme == .dark,
                        strokeWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("map_button_check_in".localized)
        .modifier(AccessibilityHintModifier(hint: checkInAccessibilityHint))
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(searchText.isEmpty)
        .opacity(searchText.isEmpty ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                checkInPulseScale = 1.3
                checkInPulseOpacity = 0.0
            }
        }
        .onDisappear {
            checkInPulseScale = 1.0
            checkInPulseOpacity = 0.45
        }
    }
    
    // 打卡按钮图标视图，便于在不同外观分支中复用
    var checkInIcon: some View {
        Image("DakaIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            // 图标颜色使用品牌色，固定透明度
            .foregroundStyle(brandColorManager.currentBrandColor)
            // 图标缩放随脉冲在 1.0 → 1.1 之间变化，与外圈脉冲同步
            .scaleEffect(1.0 + (checkInPulseScale - 1.0) * (0.1 / 0.3))
    }
    
    /// 浮动菜单中使用的打卡图标（小号版本），复用与底部按钮一致的颜色与脉冲动画
    var assistiveCheckInMenuIcon: some View {
        ZStack {
            // 外圈脉冲光晕（缩小版）
            Circle()
                .fill(brandColorManager.currentBrandColor.opacity(0.25))
                .frame(width: 60, height: 60)
                .scaleEffect(checkInPulseScale)
                .opacity(checkInPulseOpacity)
            
            checkInIcon
                .footprintMapBrandGlassCircle(
                    diameter: 46,
                    brand: brandColorManager.currentBrandColor,
                    isDark: colorScheme == .dark,
                    strokeWidth: 1.6
                )
        }
        // 当仅保留浮动菜单时，在这里启动/重置打卡脉冲动画
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                checkInPulseScale = 1.3
                checkInPulseOpacity = 0.0
            }
        }
        .onDisappear {
            checkInPulseScale = 1.0
            checkInPulseOpacity = 0.45
        }
    }
    
    var assistiveMenuActions: [AssistiveMenuAction] {
        [
            AssistiveMenuAction(
                id: "ai",
                icon: "sparkles",
                title: "map_button_ai".localized,
                isActive: showingAIAssistant,
                isHighlighted: true,
                action: {
                    handleAIAssistant()
                }
            ),
            AssistiveMenuAction(
                id: "import_photo",
                icon: "photo.badge.plus",
                title: "map_button_import_photo".localized,
                isActive: false,
                action: {
                    handleFootprintsImport()
                }
            ),
            AssistiveMenuAction(
                id: "search",
                icon: "magnifyingglass",
                title: "map_button_search".localized,
                isActive: showSearchBar || !searchText.isEmpty,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSearchBar.toggle()
                        if showSearchBar {
                            // 延迟一点让动画完成后再聚焦
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isSearchFocused = true
                            }
                        } else {
                            searchText = ""
                            searchResults = []
                            isSearchFocused = false
                        }
                    }
                }
            ),
            AssistiveMenuAction(
                id: "locate",
                icon: "location.fill",
                title: "map_button_locate".localized,
                isActive: false,
                action: {
                    centerMapOnCurrentLocation()
                }
            ),
            AssistiveMenuAction(
                id: "memory",
                icon: "PaopaoIcon",
                title: "map_button_memory".localized,
                isActive: false,
                action: {
                    triggerMemoryBubble()
                }
            )
        ]
    }
    
    
    @ViewBuilder
    func menuIcon(for icon: String, isActive: Bool, isHighlighted: Bool = false) -> AnyView {
        let iconColor: Color = isHighlighted ? .white : buttonIconColor(isActive: isActive)
        switch icon {
        case "PaopaoIcon":
            return AnyView(
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundColor(iconColor)
                    .frame(width: 22, height: 22)
            )
        default:
            return AnyView(
                Image(systemName: icon)
                    .font(.system(size: isHighlighted ? 21 : 20, weight: .semibold))
                    .foregroundColor(iconColor)
                    .symbolEffect(.pulse, options: .repeating.speed(0.6), isActive: isHighlighted)
            )
        }
    }
    
    // 根据地图样式和激活状态返回按钮图标颜色
    func buttonIconColor(isActive: Bool) -> Color {
        if isActive {
            // 激活状态：深色地图模式使用白色，浅色地图模式使用黑色
            return isDarkMapStyle ? .white : .black
        } else {
            // 非激活状态：深色地图模式下使用白色/浅灰色，浅色地图模式下使用深色
            return isDarkMapStyle ? .white.opacity(0.9) : .primary
        }
    }
    
    // 根据地图样式返回容器背景材质（深色地图模式透明度为0.1）
    @ViewBuilder
    var containerBackgroundMaterial: some View {
        if isDarkMapStyle {
            // 深色地图模式：使用黑色半透明背景（透明度0.1），叠加超薄材质
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.1))
            }
        } else {
            // 浅色地图模式：使用标准材质
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
    
    
    // iOS 26标准搜索栏覆盖层
    var searchBarOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 搜索输入框
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15, weight: .medium))
                    
                    TextField(searchPlaceholderText, text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                        .focused($isSearchFocused)
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                searchResults = []
                            } else {
                                performSearch()
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .footprintMapGlassCapsule(isDarkMap: isDarkMapStyle)
                
                // 关闭按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSearchBar = false
                        searchText = ""
                        searchResults = []
                        isSearchFocused = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18)) // 进一步缩小图标：从24改为18
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.regularMaterial)
            
            // 搜索结果列表
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(searchResults.prefix(10).enumerated()), id: \.offset) { index, result in
                            SearchResultRow(mapItem: result) {
                                selectSearchResult(result)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showSearchBar = false
                                }
                            }
                            
                            if index < min(9, searchResults.count - 1) {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
                .background(.regularMaterial)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // 地图样式选择器
    var mapStylePicker: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("map_style_title".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    ForEach(MapStyle.allCases, id: \.self) { style in
                        MapStyleCard(
                            style: style,
                            isSelected: currentMapStyle == style
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                mapStyleRawValue = style.rawValue
                                showingMapStylePicker = false
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        showingMapStylePicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
    }
    
    // “快速打卡”弹窗内容
    @ViewBuilder
    var quickCheckInSheet: some View {
        if let prefill = addDestinationPrefill {
            // 使用 .id 确保 prefill 从 nil 变为有值时 SwiftUI 会重建视图，从而正确应用预填数据
            let idKey: String = {
                let name = prefill.name ?? ""
                guard let loc = prefill.location else { return name.isEmpty ? UUID().uuidString : name }
                let c = loc.placemark.coordinate
                return "\(name)-\(c.latitude)-\(c.longitude)"
            }()
            QuickCheckInView(prefill: prefill)
                .id(idKey)
        } else if isGeocodingLocation {
            // 快速打卡模式的加载状态
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("getting_location_info".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("identifying_location".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
            }
        } else {
            // 快速打卡模式但还没有位置信息，显示简化界面（会显示加载状态）
            QuickCheckInView(prefill: nil)
        }
    }
    
    // 普通"添加目的地"弹窗内容
    @ViewBuilder
    var addDestinationSheet: some View {
        // 只有在明确标记应该使用预填充数据时才使用（例如照片导入）
        // 普通"添加目的地"功能不使用自动地理编码的残留数据
        if shouldUsePrefillForAddDestination, let prefill = addDestinationPrefill {
            AddDestinationView(prefill: prefill, mapRegion: visibleRegion)
        } else if isGeocodingLocation && shouldUsePrefillForAddDestination {
            // 只有在明确需要预填充时才显示加载状态（例如照片导入正在地理编码）
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("getting_location_info".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("identifying_location".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
            }
        } else {
            // 普通"添加目的地"：显示空页面，不使用预填充数据
            AddDestinationView(mapRegion: visibleRegion)
        }
    }
    
    
    // 计算当前缩放级别
    var currentZoomLevel: Double {
        guard let region = visibleRegion else { return 10 }
        let span = region.span.longitudeDelta
        // 根据经度跨度计算缩放级别 (0-20)
        let zoomLevel = log2(360.0 / span)
        return max(0, min(20, zoomLevel))
    }
    
    // 旅程统一颜色映射
    var tripColorMapping: [UUID: Color] {
        var mapping: [UUID: Color] = [:]
        for trip in effectiveTrips {
            mapping[trip.id] = .blue // 所有旅程使用统一的蓝色
        }
        return mapping
    }
    
    // 获取旅程颜色
    func tripColor(for trip: TravelTrip) -> Color {
        .blue // 所有旅程使用统一的蓝色
    }
    
    // 根据缩放级别计算聚合距离
    var clusterDistance: Double {
        return currentZoomLevelEnum.distance
    }
    
    // 获取当前缩放级别枚举
    var currentZoomLevelEnum: ZoomLevel {
        let zoom = currentZoomLevel
        if zoom < 4 { return .world }
        else if zoom < 6 { return .country }
        else if zoom < 8 { return .province }
        else if zoom < 10 { return .city }
        else if zoom < 12 { return .district }
        else { return .street }
    }
    
    // 生成地点签名（用于检测地点变化：删除、坐标变化、所属旅程变化）
    var destinationsSignature: String {
        trackedDestinationsSignature
    }
    
    // 获取屏幕可见区域内的地点（按区域 fetch，无全量 @Query）
    var visibleDestinationsInRegion: [TravelDestination] {
        // 如果在线路tab且选中了线路卡片，只显示该线路的地点（并考虑「第几天」筛选）
        if autoShowRouteCards, selectedTripId != nil {
            return visibleDestinationsForSelectedTrip
        }
        
        // 使用区域 fetch 结果（fetch 进行中时保留上一份缓存，避免闪烁）
        return destinationsInVisibleRegion ?? []
    }
    
    // 生成可见区域的缓存键（用于判断区域是否变化）
    var visibleRegionKey: String {
        guard let region = visibleRegion ?? regionHolder.pending else { return "" }
        let centerLat = String(format: "%.2f", region.center.latitude)
        let centerLon = String(format: "%.2f", region.center.longitude)
        let spanLat = String(format: "%.2f", region.span.latitudeDelta)
        let spanLon = String(format: "%.2f", region.span.longitudeDelta)
        let tripIdSuffix = autoShowRouteCards ? (selectedTripId?.uuidString ?? "nil") : "all"
        let daySuffix = (autoShowRouteCards && selectedDayFilter != nil) ? "\(selectedDayFilter!)" : "all"
        return "\(centerLat),\(centerLon),\(spanLat),\(spanLon),\(tripIdSuffix),\(daySuffix)"
    }
    
    /// 只读缓存，聚类由显式调度触发（避免 body 求值副作用）
    var clusterAnnotations: [ClusterAnnotation] {
        cachedClusterAnnotations
    }
}
