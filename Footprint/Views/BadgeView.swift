//
//  BadgeView.swift
//  Footprint
//
//  Created on 2025/11/29.
//

import SwiftUI
import SwiftData

/// 勋章主视图
struct BadgeView: View {
    @Query private var destinations: [TravelDestination]
    @State private var selectedType: BadgeType = .country
    
    // 缓存的排序结果
    @State private var cachedSortedCountryBadges: [CountryBadge] = []
    @State private var cachedSortedProvinceBadges: [ProvinceBadge] = []
    
    // 缓存每个徽章的目的地列表和年份范围，避免重复计算
    @State private var countryBadgeDataCache: [String: (destinations: [TravelDestination], yearRange: String?)] = [:]
    @State private var provinceBadgeDataCache: [String: (destinations: [TravelDestination], yearRange: String?)] = [:]
    
    // 加载状态
    @State private var isLoading = false
    @State private var lastUpdateDestinationCount = 0
    @ObservedObject private var destinationRevision = DestinationDataRevision.shared
    @State private var lastHandledBadgeRevision = -1
    @State private var badgeUpdateDebounceTask: Task<Void, Never>?
    
    // 全屏详情视图状态
    @State private var selectedBadge: BadgeDetail?
    @State private var showingBadgeDetail = false
    
    /// 进度卡实测高度（用于给网格预留下方空间）
    @State private var progressCardMeasuredHeight: CGFloat = 150
    
    // 徽章详情数据模型
    struct BadgeDetail: Identifiable {
        let id: String
        let imageName: String
        let title: String
        let isUnlocked: Bool
        let destinations: [TravelDestination]
        let yearRange: String?
        let badgeType: BadgeType
    }
    
    private let badgeManager = BadgeManager.shared
    @StateObject private var countryManager = CountryManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var badgeColumnCount: Int {
        horizontalSizeClass == .regular ? 5 : 3
    }
    
    private var badgeGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: badgeColumnCount)
    }
    
    // MARK: - 计算属性
    
    /// 获取所有国家勋章
    private var allCountryBadges: [CountryBadge] {
        BadgeDataProvider.getAllCountryBadges()
    }
    
    /// 获取所有省份勋章
    private var allProvinceBadges: [ProvinceBadge] {
        BadgeDataProvider.getAllProvinceBadges()
    }
    
    /// 获取去过的国家集合
    private var visitedCountries: Set<String> {
        badgeManager.getVisitedCountries(from: destinations)
    }
    
    /// 获取去过的省份集合
    private var visitedProvinces: Set<String> {
        badgeManager.getVisitedProvinces(from: destinations)
    }
    
    /// 统计信息（使用缓存数据，提高性能）
    private var statistics: (unlocked: Int, total: Int) {
        if selectedType == .country {
            // 从缓存中统计已解锁的徽章数量
            let unlocked = cachedSortedCountryBadges.filter { badge in
                countryBadgeDataCache[badge.id]?.destinations.count ?? 0 > 0
            }.count
            return (unlocked, BadgeDataProvider.getAllCountryBadges().count)
        } else {
            // 省份勋章：只有当前国家是中国时才统计
            if isCurrentCountryChina {
                let unlocked = cachedSortedProvinceBadges.filter { badge in
                    provinceBadgeDataCache[badge.id]?.destinations.count ?? 0 > 0
                }.count
                return (unlocked, BadgeDataProvider.getAllProvinceBadges().count)
            } else {
                // 其他国家：返回0，不显示统计信息
                return (0, 0)
            }
        }
    }
    
    /// 进度百分比
    /// 是否显示进度卡片
    private var shouldShowProgressCard: Bool {
        selectedType == .country || (selectedType == .province && isCurrentCountryChina)
    }
    
    /// 获取已激活的国家勋章列表（只显示已解锁的）
    private var unlockedCountryBadges: [CountryBadge] {
        cachedSortedCountryBadges.filter { badge in
            let cachedData = countryBadgeDataCache[badge.id]
            let destinationCount = cachedData?.destinations.count ?? 0
            return destinationCount > 0
        }
    }
    
    /// 判断当前所在国家是否是中国
    private var isCurrentCountryChina: Bool {
        countryManager.currentCountry == .china
    }
    
    /// 获取已激活的省份勋章列表（只显示已解锁的）
    private var unlockedProvinceBadges: [ProvinceBadge] {
        cachedSortedProvinceBadges.filter { badge in
            let cachedData = provinceBadgeDataCache[badge.id]
            let destinationCount = cachedData?.destinations.count ?? 0
            return destinationCount > 0
        }
    }
    
    /// 主数字单位文案
    private var primaryUnitLabel: String {
        selectedType == .country
            ? "badges_countries_unit".localized
            : "badges_provinces_unit".localized
    }
    
    /// 国内用户跨维度副文案（另一分段的解锁数）
    private var crossDimensionHint: (text: String, switchTo: BadgeType)? {
        guard isCurrentCountryChina else { return nil }
        if selectedType == .country {
            let count = unlockedProvinceBadges.count
            guard count > 0 else { return nil }
            return (
                "badges_domestic_provinces_hint".localized(with: count),
                .province
            )
        } else {
            let count = unlockedCountryBadges.count
            guard count > 0 else { return nil }
            return (
                "badges_global_countries_hint".localized(with: count),
                .country
            )
        }
    }
    
    // MARK: - 辅助方法
    
    /// 获取某个国家的地点列表
    private func getDestinations(for country: CountryManager.Country) -> [TravelDestination] {
        let countryCodes = [country.rawValue, country.displayName, country.englishName]
        return destinations.filter { destination in
            countryCodes.contains { code in
                destination.country == code || 
                destination.country.localizedCaseInsensitiveContains(code)
            }
        }
    }
    
    /// 获取某个省份的地点列表
    private func getDestinations(for provinceName: String) -> [TravelDestination] {
        let normalized = badgeManager.normalizeProvinceName(provinceName)
        return destinations.filter { destination in
            let isChina = destination.country == "中国" || 
                         destination.country == "CN" || 
                         destination.country == "China"
            if isChina {
                let destProvince = badgeManager.normalizeProvinceName(destination.province)
                return destProvince == normalized
            }
            return false
        }
    }
    
    /// 计算年份范围字符串
    private func getYearRange(from destinations: [TravelDestination]) -> String? {
        guard !destinations.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let years = destinations.compactMap { destination in
            calendar.component(.year, from: destination.visitDate)
        }
        
        guard let minYear = years.min(), let maxYear = years.max() else { return nil }
        
        if minYear == maxYear {
            return "\(minYear)"
        } else {
            return "\(minYear)～\(maxYear)"
        }
    }
    
    /// 获取最早访问年份（用于排序）
    private func getEarliestYear(from destinations: [TravelDestination]) -> Int? {
        guard !destinations.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let years = destinations.compactMap { destination in
            calendar.component(.year, from: destination.visitDate)
        }
        
        return years.min()
    }
    
    // MARK: - 计算和更新缓存
    
    /// 计算并更新排序后的勋章缓存（在后台线程执行）
    /// - Parameter forceUpdate: 是否强制更新（即使数量没变化也更新，用于处理省份、国家变化）
    private func updateSortedBadges(forceUpdate: Bool = false, forRevision revision: Int? = nil) {
        let countChanged = destinations.count != lastUpdateDestinationCount
        let hasNoCache = cachedSortedCountryBadges.isEmpty

        guard forceUpdate || countChanged || hasNoCache else {
            return
        }

        isLoading = true
        lastUpdateDestinationCount = destinations.count
        let targetRevision = revision ?? destinationRevision.revision

        // 主线程仅提取轻量快照，避免在 Task 中复制全量 SwiftData model
        let snapshots = destinations.map {
            BadgeDestinationSnapshot(
                id: $0.id,
                country: $0.country,
                province: $0.province,
                visitDate: $0.visitDate
            )
        }
        let allCountryBadges = BadgeDataProvider.getAllCountryBadges()
        let isChina = countryManager.currentCountry == .china
        let allProvinceBadges = isChina ? BadgeDataProvider.getAllProvinceBadges() : []

        Task.detached(priority: .userInitiated) {
            let result = Self.computeBadgeCaches(
                snapshots: snapshots,
                allCountryBadges: allCountryBadges,
                allProvinceBadges: allProvinceBadges,
                isChina: isChina
            )

            await MainActor.run {
                let destinationByID = Dictionary(uniqueKeysWithValues: destinations.map { ($0.id, $0) })

                func resolveDestinations(_ ids: [UUID]) -> [TravelDestination] {
                    ids.compactMap { destinationByID[$0] }
                }

                cachedSortedCountryBadges = result.sortedCountryBadges
                cachedSortedProvinceBadges = result.sortedProvinceBadges
                countryBadgeDataCache = result.countryEntries.mapValues { entry in
                    (destinations: resolveDestinations(entry.destinationIDs), yearRange: entry.yearRange)
                }
                provinceBadgeDataCache = result.provinceEntries.mapValues { entry in
                    (destinations: resolveDestinations(entry.destinationIDs), yearRange: entry.yearRange)
                }
                isLoading = false
                lastHandledBadgeRevision = targetRevision
            }
        }
    }

    private struct BadgeDestinationSnapshot: Sendable {
        let id: UUID
        let country: String
        let province: String
        let visitDate: Date
    }

    private struct BadgeCacheEntry: Sendable {
        let destinationIDs: [UUID]
        let yearRange: String?
    }

    private struct BadgeCacheComputation: Sendable {
        let sortedCountryBadges: [CountryBadge]
        let sortedProvinceBadges: [ProvinceBadge]
        let countryEntries: [String: BadgeCacheEntry]
        let provinceEntries: [String: BadgeCacheEntry]
    }

    private static func computeBadgeCaches(
        snapshots: [BadgeDestinationSnapshot],
        allCountryBadges: [CountryBadge],
        allProvinceBadges: [ProvinceBadge],
        isChina: Bool
    ) -> BadgeCacheComputation {
        let badgeManager = BadgeManager.shared
        let visitedCountriesSet = visitedCountries(from: snapshots)
        let visitedProvincesSet = visitedProvinces(from: snapshots)

        var countryDestinationsMap: [String: [UUID]] = [:]
        var provinceDestinationsMap: [String: [UUID]] = [:]

        for snapshot in snapshots {
            let countryCodes = [
                snapshot.country,
                badgeManager.normalizeCountryName(snapshot.country)
            ]
            for code in countryCodes where !code.isEmpty {
                countryDestinationsMap[code, default: []].append(snapshot.id)
            }

            let snapshotIsChina = snapshot.country == "中国" ||
                snapshot.country == "CN" ||
                snapshot.country == "China"
            if snapshotIsChina, !snapshot.province.isEmpty {
                let normalizedProvince = badgeManager.normalizeProvinceName(snapshot.province)
                if !normalizedProvince.isEmpty {
                    provinceDestinationsMap[normalizedProvince, default: []].append(snapshot.id)
                }
            }
        }

        let visitDateByID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0.visitDate) })
        var countryEntries: [String: BadgeCacheEntry] = [:]

        let countryBadgeData = allCountryBadges.map { badge -> (badge: CountryBadge, isUnlocked: Bool, earliestYear: Int) in
            let isUnlocked = badgeManager.isCountryBadgeUnlocked(
                country: badge.country,
                visitedCountries: visitedCountriesSet
            )

            var destinationIDs: [UUID] = []
            if isUnlocked {
                var seen = Set<UUID>()
                let countryCodes = [badge.country.rawValue, badge.country.displayName, badge.country.englishName]
                for code in countryCodes {
                    for id in countryDestinationsMap[code, default: []] where seen.insert(id).inserted {
                        destinationIDs.append(id)
                    }
                }
            }

            let years = destinationIDs.compactMap { id in
                visitDateByID[id].map { Calendar.current.component(.year, from: $0) }
            }
            let earliestYear = years.min() ?? Int.max
            let yearRange = yearRangeString(from: years)

            countryEntries[badge.id] = BadgeCacheEntry(destinationIDs: destinationIDs, yearRange: yearRange)
            return (badge: badge, isUnlocked: isUnlocked, earliestYear: earliestYear)
        }

        let sortedCountryBadges = countryBadgeData.sorted { data1, data2 in
            if data1.isUnlocked != data2.isUnlocked {
                return data1.isUnlocked
            }
            if data1.isUnlocked && data2.isUnlocked {
                return data1.earliestYear < data2.earliestYear
            }
            return data1.badge.country.englishName.localizedCaseInsensitiveCompare(data2.badge.country.englishName) == .orderedAscending
        }.map(\.badge)

        var provinceEntries: [String: BadgeCacheEntry] = [:]
        let provinceBadgeData = isChina ? allProvinceBadges.map { badge -> (badge: ProvinceBadge, isUnlocked: Bool, earliestYear: Int) in
            let normalizedProvince = badgeManager.normalizeProvinceName(badge.provinceName)
            let isUnlocked = badgeManager.isProvinceBadgeUnlocked(
                provinceName: normalizedProvince,
                visitedProvinces: visitedProvincesSet
            )

            let destinationIDs = isUnlocked ? (provinceDestinationsMap[normalizedProvince] ?? []) : []
            let years = destinationIDs.compactMap { id in
                visitDateByID[id].map { Calendar.current.component(.year, from: $0) }
            }
            let earliestYear = years.min() ?? Int.max
            let yearRange = yearRangeString(from: years)

            provinceEntries[badge.id] = BadgeCacheEntry(destinationIDs: destinationIDs, yearRange: yearRange)
            return (badge: badge, isUnlocked: isUnlocked, earliestYear: earliestYear)
        } : []

        let sortedProvinceBadges = isChina ? provinceBadgeData.sorted { data1, data2 in
            if data1.isUnlocked != data2.isUnlocked {
                return data1.isUnlocked
            }
            if data1.isUnlocked && data2.isUnlocked {
                return data1.earliestYear < data2.earliestYear
            }
            return data1.badge.displayName.localizedCaseInsensitiveCompare(data2.badge.displayName) == .orderedAscending
        }.map(\.badge) : []

        return BadgeCacheComputation(
            sortedCountryBadges: sortedCountryBadges,
            sortedProvinceBadges: sortedProvinceBadges,
            countryEntries: countryEntries,
            provinceEntries: provinceEntries
        )
    }

    private static func visitedCountries(from snapshots: [BadgeDestinationSnapshot]) -> Set<String> {
        var visited = Set<String>()
        let badgeManager = BadgeManager.shared
        for snapshot in snapshots {
            let normalized = badgeManager.normalizeCountryName(snapshot.country)
            if !normalized.isEmpty {
                visited.insert(normalized)
            }
        }
        return visited
    }

    private static func visitedProvinces(from snapshots: [BadgeDestinationSnapshot]) -> Set<String> {
        var visited = Set<String>()
        let badgeManager = BadgeManager.shared
        for snapshot in snapshots {
            let snapshotIsChina = snapshot.country == "中国" ||
                snapshot.country == "CN" ||
                snapshot.country == "China"
            if snapshotIsChina, !snapshot.province.isEmpty {
                let normalized = badgeManager.normalizeProvinceName(snapshot.province)
                if !normalized.isEmpty {
                    visited.insert(normalized)
                }
            }
        }
        return visited
    }

    private static func yearRangeString(from years: [Int]) -> String? {
        guard !years.isEmpty, let minYear = years.min(), let maxYear = years.max() else { return nil }
        if minYear == maxYear {
            return "\(minYear)"
        }
        return "\(minYear)～\(maxYear)"
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            FootprintAtmosphereBackground(
                accent: Color.footprintRed,
                secondaryAccent: FootprintTheme.Accent.secondary
            )
                
            VStack(spacing: 0) {
                // 类型切换器
                Picker("mode".localized, selection: $selectedType) {
                    Text("country_badges".localized)
                        .tag(BadgeType.country)
                    Text("province_badges".localized)
                        .tag(BadgeType.province)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // 勋章网格
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    let horizontalPadding: CGFloat = 16
                    let columnSpacing: CGFloat = 16
                    let numberOfColumns = CGFloat(badgeColumnCount)
                    let progressCardHeight: CGFloat = shouldShowProgressCard
                        ? max(progressCardMeasuredHeight + 12, 120)
                        : 0
                    
                    // 计算每个卡片的宽度：可用宽度 = 屏幕宽度 - 左右padding - 列间距
                    let availableWidth = screenWidth - (horizontalPadding * 2) - (columnSpacing * (numberOfColumns - 1))
                    let cardWidth = availableWidth / numberOfColumns
                    
                    ZStack(alignment: .top) {
                        ScrollView {
                            LazyVGrid(
                                columns: badgeGridColumns,
                                spacing: 16
                            ) {
                                if selectedType == .country {
                                    ForEach(unlockedCountryBadges) { badge in
                                        // 从缓存中获取数据，避免重复计算
                                        let cachedData = countryBadgeDataCache[badge.id]
                                        let destinationCount = cachedData?.destinations.count ?? 0
                                        let yearRange = cachedData?.yearRange
                                        let destinations = cachedData?.destinations ?? []
                                        
                                        BadgeItemView(
                                            imageName: badge.imageName,
                                            title: badge.displayName,
                                            isUnlocked: destinationCount > 0,
                                            cardSize: cardWidth,
                                            destinationCount: destinationCount,
                                            yearRange: yearRange
                                        )
                                        .onTapGesture {
                                            selectedBadge = BadgeDetail(
                                                id: badge.id,
                                                imageName: badge.imageName,
                                                title: badge.displayName,
                                                isUnlocked: destinationCount > 0,
                                                destinations: destinations,
                                                yearRange: yearRange,
                                                badgeType: .country
                                            )
                                            showingBadgeDetail = true
                                        }
                                    }
                                } else {
                                    // 根据当前所在国家判断是否显示省份勋章
                                    if isCurrentCountryChina {
                                        // 中国：显示省份勋章
                                        ForEach(unlockedProvinceBadges) { badge in
                                            // 从缓存中获取数据，避免重复计算
                                            let cachedData = provinceBadgeDataCache[badge.id]
                                            let destinationCount = cachedData?.destinations.count ?? 0
                                            let yearRange = cachedData?.yearRange
                                            let destinations = cachedData?.destinations ?? []
                                            
                                            BadgeItemView(
                                                imageName: badge.imageName,
                                                title: badge.displayName,
                                                isUnlocked: destinationCount > 0,
                                                cardSize: cardWidth,
                                                destinationCount: destinationCount,
                                                yearRange: yearRange
                                            )
                                            .onTapGesture {
                                                selectedBadge = BadgeDetail(
                                                    id: badge.id,
                                                    imageName: badge.imageName,
                                                    title: badge.displayName,
                                                    isUnlocked: destinationCount > 0,
                                                    destinations: destinations,
                                                    yearRange: yearRange,
                                                    badgeType: .province
                                                )
                                                showingBadgeDetail = true
                                            }
                                        }
                                    } else {
                                        // 其他国家：显示"开发中..."提示
                                        VStack(spacing: 16) {
                                            Image(systemName: "hammer.fill")
                                                .font(.system(size: 48))
                                                .foregroundColor(.secondary)
                                            
                                            Text("in_development".localized)
                                                .font(.headline)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 60)
                                        .gridCellColumns(badgeColumnCount) // 占据整行
                                    }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, shouldShowProgressCard ? progressCardHeight : 16)
                            .padding(.bottom, 16)
                        }
                        
                        if shouldShowProgressCard {
                            progressSummaryCard
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: BadgeProgressCardHeightKey.self,
                                            value: geo.size.height
                                        )
                                    }
                                )
                                .onPreferenceChange(BadgeProgressCardHeightKey.self) { height in
                                    if abs(height - progressCardMeasuredHeight) > 0.5 {
                                        progressCardMeasuredHeight = height
                                    }
                                }
                                .zIndex(1)
                        }

                        // 加载指示器
                        if isLoading && cachedSortedCountryBadges.isEmpty {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color.footprintRed)
                        }
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("badges".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshBadgesIfNeeded(forceUpdate: false)
        }
        .onChange(of: destinationRevision.revision) { _, _ in
            scheduleBadgeUpdate(forceUpdate: true)
        }
        .fullScreenCover(item: $selectedBadge) { badge in
            BadgeDetailView(
                imageName: badge.imageName,
                title: badge.title,
                isUnlocked: badge.isUnlocked,
                destinations: badge.destinations,
                yearRange: badge.yearRange,
                badgeType: badge.badgeType,
                isPresented: Binding(
                    get: { selectedBadge != nil },
                    set: { if !$0 { selectedBadge = nil } }
                )
            )
        }
    }
    
    // MARK: - 进度摘要卡
    
    private var progressSummaryCard: some View {
        BadgeProgressSummaryCard(
            items: [],
            unlocked: statistics.unlocked,
            total: statistics.total,
            unitLabel: primaryUnitLabel,
            emptyText: selectedType == .country
                ? "badges_no_countries_yet".localized
                : "badges_no_provinces_yet".localized,
            crossHintText: crossDimensionHint?.text,
            accent: Color.footprintRed,
            // 勋章页下方已有完整网格，顶部只保留进度与跨维度入口，避免重复占高
            showsBadgeTiles: false,
            onCrossHintTap: {
                guard let hint = crossDimensionHint else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedType = hint.switchTo
                }
            }
        )
    }
    
    // MARK: - 缓存刷新

    /// 仅在 revision 变化或尚无缓存时重算
    private func refreshBadgesIfNeeded(forceUpdate: Bool) {
        let rev = destinationRevision.revision
        guard forceUpdate || cachedSortedCountryBadges.isEmpty || rev != lastHandledBadgeRevision else { return }
        updateSortedBadges(
            forceUpdate: forceUpdate || cachedSortedCountryBadges.isEmpty,
            forRevision: rev
        )
    }
    
    /// 通知触发的防抖更新，避免连发通知导致多次后台重算
    private func scheduleBadgeUpdate(forceUpdate: Bool = false) {
        badgeUpdateDebounceTask?.cancel()
        badgeUpdateDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                refreshBadgesIfNeeded(forceUpdate: forceUpdate)
            }
        }
    }
}

private struct BadgeProgressCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 150
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack {
        BadgeView()
    }
    .modelContainer(for: TravelDestination.self, inMemory: true)
}

