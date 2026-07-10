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
    /// 当前是否为选中的 Tab（非选中时不运行动画，降低离屏 CPU）
    var isTabSelected: Bool = true
    
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
    @State private var lastDestinationsSignature = ""
    @State private var badgeUpdateDebounceTask: Task<Void, Never>?
    
    // 全屏详情视图状态
    @State private var selectedBadge: BadgeDetail?
    @State private var showingBadgeDetail = false
    
    // 大数字百分比动画值
    @State private var animatedProgressPercentage: Double = 0
    
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
    
    // MARK: - 计算属性
    
    /// 生成目的地签名（基于国家、省份），用于检测数据变化
    private var destinationsSignature: String {
        DestinationCollectionSignature.makeForBadges(from: destinations)
    }
    
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
    private var progressPercentage: CGFloat {
        guard statistics.total > 0 else { return 0 }
        return CGFloat(statistics.unlocked) / CGFloat(statistics.total) * 100
    }

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
    private func updateSortedBadges(forceUpdate: Bool = false) {
        let countChanged = destinations.count != lastUpdateDestinationCount
        let hasNoCache = cachedSortedCountryBadges.isEmpty

        guard forceUpdate || countChanged || hasNoCache else {
            return
        }

        isLoading = true
        lastUpdateDestinationCount = destinations.count

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
        NavigationStack {
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
                    let numberOfColumns: CGFloat = 3
                    let progressCardHeight: CGFloat = shouldShowProgressCard ? 150 : 0
                    
                    // 计算每个卡片的宽度：可用宽度 = 屏幕宽度 - 左右padding - 列间距
                    let availableWidth = screenWidth - (horizontalPadding * 2) - (columnSpacing * (numberOfColumns - 1))
                    let cardWidth = availableWidth / numberOfColumns
                    
                    ZStack(alignment: .top) {
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: columnSpacing),
                                    GridItem(.flexible(), spacing: columnSpacing),
                                    GridItem(.flexible(), spacing: columnSpacing)
                                ],
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
                                        .gridCellColumns(3) // 占据整行
                                    }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, shouldShowProgressCard ? progressCardHeight : 16)
                            .padding(.bottom, 16)
                        }
                        
                        if shouldShowProgressCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    // 标题：品牌红色
                                    Text("badges_progress".localized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColorScheme.iconColor)
                                    
                                    Spacer()
                                }
                                
                                HStack(alignment: .center, spacing: 16) {
                                    // 左侧：大数字主视觉（适配深浅模式）
                                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                                        Text("\(Int(animatedProgressPercentage.rounded()))")
                                            .font(.system(size: 56, weight: .black, design: .default))
                                            .tracking(-1)
                                            .foregroundStyle(.primary)
                                            .monospacedDigit()
                                            .contentTransition(.numericText(value: animatedProgressPercentage))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.65)
                                        
                                        Text("%")
                                            .font(.system(size: 36, weight: .black, design: .default))
                                            .tracking(-0.5)
                                            .foregroundStyle(.primary)
                                            .baselineOffset(2)
                                    }
                                    
                                    Spacer(minLength: 0)
                                    
                                    // 右侧：环形表达 14/119（参考附图2）
                                    BadgeProgressRingView(
                                        unlocked: statistics.unlocked,
                                        total: statistics.total,
                                        badgeLabel: selectedType == .country ? "country_badges".localized : "province_badges".localized
                                    )
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .badgeProgressGlassCard()
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .zIndex(1)
                        }

                        // 加载指示器
                        if isLoading && cachedSortedCountryBadges.isEmpty {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(AppColorScheme.iconColor)
                        }
                    }
                }
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("badges".localized)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // 只在首次出现或数据为空时更新
                if cachedSortedCountryBadges.isEmpty {
                    updateSortedBadges()
                    lastDestinationsSignature = destinationsSignature
                }
                if isTabSelected {
                    animateProgressNumber(resetToZero: true)
                }
            }
            .onChange(of: isTabSelected) { _, selected in
                if selected {
                    animateProgressNumber(resetToZero: true)
                }
            }
            .onChange(of: destinations.count) { oldCount, newCount in
                // 当目的地数量变化时（新增或删除），更新缓存
                if oldCount != newCount {
                    updateSortedBadges()
                    lastDestinationsSignature = destinationsSignature
                }
            }
            .onChange(of: destinationsSignature) { oldSignature, newSignature in
                // 当目的地签名变化时（国家、省份变化），强制更新缓存
                // 这能检测到即使数量不变，但国家或省份发生变化的情况
                if oldSignature != newSignature && !oldSignature.isEmpty {
                    updateSortedBadges(forceUpdate: true)
                    lastDestinationsSignature = newSignature
                }
            }
            .onChange(of: selectedType) { _ in
                // 切换类型时不需要重新计算，因为两个列表都已缓存
                if isTabSelected {
                    animateProgressNumber(resetToZero: true)
                }
            }
            .onChange(of: progressPercentage) { _, _ in
                // 数据变化时同步刷新数字动画
                if isTabSelected {
                    animateProgressNumber(resetToZero: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { _ in
                scheduleBadgeUpdate(forceUpdate: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationUpdated)) { _ in
                scheduleBadgeUpdate(forceUpdate: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .countryChanged)) { _ in
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
    }
    
    // MARK: - 数字动画
    
    /// 通知触发的防抖更新，避免连发通知导致多次后台重算
    private func scheduleBadgeUpdate(forceUpdate: Bool = false) {
        badgeUpdateDebounceTask?.cancel()
        badgeUpdateDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                updateSortedBadges(forceUpdate: forceUpdate)
                lastDestinationsSignature = destinationsSignature
            }
        }
    }
    
    private func animateProgressNumber(resetToZero: Bool) {
        guard isTabSelected else { return }
        if resetToZero {
            animatedProgressPercentage = 0
            // 必须在延迟闭包内读取 progressPercentage：首次进入时缓存尚未写入，
            // 若在此处捕获 target，后续异步填充数据后仍会用 0 覆盖正确动画结果。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                let target = Double(progressPercentage)
                withAnimation(.easeOut(duration: 0.9)) {
                    animatedProgressPercentage = target
                }
            }
        } else {
            let target = Double(progressPercentage)
            withAnimation(.easeOut(duration: 0.55)) {
                animatedProgressPercentage = target
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func badgeProgressGlassCard() -> some View {
        if #available(iOS 26, *) {
            self
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18, style: .continuous))
                .contentShape(.rect(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        } else {
            self
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        }
    }
}

private struct BadgeProgressRingView: View {
    let unlocked: Int
    let total: Int
    let badgeLabel: String
    
    @State private var animatedRingProgress: CGFloat = 0
    
    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(unlocked) / CGFloat(total)
    }
    
    var body: some View {
        ZStack {
            // 单环底轨
            Circle()
                .stroke(
                    Color.primary.opacity(0.14),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: 74, height: 74)
            
            // 单环进度弧：纯色描边 + .round，线帽与线段同色；accentColor 跟随 TabView/.tint 主题色
            Circle()
                .trim(from: 0, to: animatedRingProgress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 74, height: 74)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: animatedRingProgress)
            
            VStack(spacing: 1) {
                Text("\(unlocked)/\(total)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                
                Text(badgeLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: 74, height: 74)
        .onAppear {
            animateRingProgress(restart: true)
        }
        .onChange(of: unlocked) { _, _ in
            animateRingProgress(restart: true)
        }
        .onChange(of: total) { _, _ in
            animateRingProgress(restart: true)
        }
    }
    
    private func animateRingProgress(restart: Bool) {
        if restart {
            animatedRingProgress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let target = progress
                withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) {
                    animatedRingProgress = target
                }
            }
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                animatedRingProgress = progress
            }
        }
    }
}

#Preview {
    BadgeView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
}

