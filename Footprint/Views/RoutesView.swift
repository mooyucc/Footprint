//
//  RoutesView.swift
//  Footprint
//
//  Created by K.X on 2025/01/XX.
//

import SwiftUI
import SwiftData

struct RoutesView: View {
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()
    @State private var showingAddTrip = false
    @State private var showingFilePicker = false
    @State private var selectedURL: URL?
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var selectedTripId: UUID?
    @State private var selectedDayFilter: Int?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("mapStyle") private var mapStyleRawValue: String = MapStyle.muted.rawValue
    
    /// 旅程 tab 首屏展示的行程数量上限（分页展示，减轻大量数据时的 fault-in 与绘制）
    private static let displayedTripLimit = 50
    /// 当前已展开的行程数量（用户可「加载更多」）
    @State private var displayedTripCount = displayedTripLimit
    
    // 当前用于展示的行程（仅前 displayedTripCount 条，减少 MapView/JourneyDrawer 与 validTrips 的计算量）
    private var displayedTrips: [TravelTrip] {
        Array(trips.prefix(displayedTripCount))
    }
    
    // 缓存「至少有2个地点的旅程」，避免每次 body 都遍历所有 trip.destinations（大量数据时明显卡顿）
    @State private var cachedValidTrips: [TravelTrip] = []
    
    // 过滤出至少有2个地点的旅程（仅读缓存；缓存在 onAppear / onChange / onReceive 中刷新）
    private var validTrips: [TravelTrip] {
        cachedValidTrips
    }
    
    /// 刷新 validTrips 缓存（在行程数量或目的地变更时调用，避免在 body 内写状态）
    private func refreshValidTripsCache() {
        let result = displayedTrips.filter { trip in
            if let destinations = trip.destinations,
               !destinations.isEmpty,
               destinations.count >= 2 {
                return true
            }
            return false
        }
        cachedValidTrips = result
    }
    
    /// 当前选中旅程按天分组（与 MapView 逻辑一致，用于导航栏「第几天」下拉）
    private var selectedTripDayGroups: [(dayIndex: Int, dayStart: Date, destinations: [TravelDestination])] {
        guard let tripId = selectedTripId,
              let trip = validTrips.first(where: { $0.id == tripId }),
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
    
    var body: some View {
        NavigationStack {
            // 显示地图视图，并自动显示线路卡片；传入 Binding 以便在导航栏标题位显示「第几天」筛选；传入分页后的行程列表
            MapView(
                autoShowRouteCards: true,
                showBottomCheckInButton: false,
                selectedTripIdBinding: $selectedTripId,
                selectedDayFilterBinding: $selectedDayFilter,
                tripsOverride: displayedTrips,
                hasMoreTrips: trips.count > displayedTripCount,
                onLoadMoreTrips: { displayedTripCount += Self.displayedTripLimit }
            )
                .environment(\.mapViewInNavigationStack, true)
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
                .onChange(of: selectedURL) { oldValue, newValue in
                    if let url = newValue {
                        importTripFromURL(url)
                    }
                }
                .onAppear {
                    refreshValidTripsCache()
                }
                .onChange(of: trips.count) { _, _ in
                    refreshValidTripsCache()
                }
                .onChange(of: displayedTripCount) { _, _ in
                    refreshValidTripsCache()
                }
                .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                    refreshID = UUID()
                }
                .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { _ in
                    refreshValidTripsCache()
                }
                .onReceive(NotificationCenter.default.publisher(for: .destinationUpdated)) { _ in
                    refreshValidTripsCache()
                }
                .id(refreshID)
        }
    }
    
    /// 导航栏中央：多日行程时显示「第几天」下拉，单日或无选中时占位保持平衡
    @ViewBuilder
    private var journeyDayFilterTitleView: some View {
        if selectedTripId != nil, selectedTripDayGroups.count > 1 {
            let allTitle = "all".localized
            Menu {
                Button {
                    selectedDayFilter = nil
                } label: {
                    Label(allTitle, systemImage: selectedDayFilter == nil ? "checkmark.circle.fill" : "circle")
                }
                ForEach(selectedTripDayGroups, id: \.dayStart) { group in
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
                       let group = selectedTripDayGroups.first(where: { $0.dayIndex == dayIndex }) {
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
    
    private func importTripFromURL(_ url: URL) {
        importResult = TripDataImporter.importTrip(from: url, modelContext: modelContext)
        showingImportResult = true
        selectedURL = nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    
    return RoutesView()
        .modelContainer(container)
        .environmentObject(LanguageManager.shared)
}

