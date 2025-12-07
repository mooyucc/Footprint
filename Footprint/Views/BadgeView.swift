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
    @State private var lastDestinationsSignature = ""
    
    // 全屏详情视图状态
    @State private var selectedBadge: BadgeDetail?
    @State private var showingBadgeDetail = false
    
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
        // 生成一个基于所有目的地的国家、省份的签名
        let signature = destinations.map { destination in
            "\(destination.country)|\(destination.province)"
        }.sorted().joined(separator: ";")
        return signature
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
        // 如果数据没有变化，且已有缓存，且不是强制更新，则跳过更新
        let countChanged = destinations.count != lastUpdateDestinationCount
        let hasNoCache = cachedSortedCountryBadges.isEmpty
        
        guard forceUpdate || countChanged || hasNoCache else {
            return
        }
        
        // 设置加载状态
        isLoading = true
        lastUpdateDestinationCount = destinations.count
        
        // 在后台线程执行计算
        Task.detached(priority: .userInitiated) {
            // 在主线程获取必要的数据
            let (allCountryBadges, allProvinceBadges, destinationsCopy, visitedCountriesSet, visitedProvincesSet, isChina) = await MainActor.run {
                (
                    BadgeDataProvider.getAllCountryBadges(),
                    // 只有当前国家是中国时才获取省份勋章
                    countryManager.currentCountry == .china ? BadgeDataProvider.getAllProvinceBadges() : [],
                    destinations,
                    badgeManager.getVisitedCountries(from: destinations),
                    badgeManager.getVisitedProvinces(from: destinations),
                    countryManager.currentCountry == .china
                )
            }
            
            // 预先构建目的地索引字典，提高查询效率
            var countryDestinationsMap: [String: [TravelDestination]] = [:]
            var provinceDestinationsMap: [String: [TravelDestination]] = [:]
            
            for destination in destinationsCopy {
                // 国家索引
                let countryCodes = [
                    destination.country,
                    badgeManager.normalizeCountryName(destination.country)
                ]
                for code in countryCodes {
                    if !code.isEmpty {
                        countryDestinationsMap[code, default: []].append(destination)
                    }
                }
                
                // 省份索引（仅限中国）
                let isChina = destination.country == "中国" || 
                             destination.country == "CN" || 
                             destination.country == "China"
                if isChina && !destination.province.isEmpty {
                    let normalizedProvince = badgeManager.normalizeProvinceName(destination.province)
                    if !normalizedProvince.isEmpty {
                        provinceDestinationsMap[normalizedProvince, default: []].append(destination)
                    }
                }
            }
            
            // 计算国家勋章
            var countryBadgeDataCache: [String: (destinations: [TravelDestination], yearRange: String?)] = [:]
            let countryBadgeData = allCountryBadges.map { badge -> (badge: CountryBadge, isUnlocked: Bool, earliestYear: Int) in
                let isUnlocked = badgeManager.isCountryBadgeUnlocked(
                    country: badge.country,
                    visitedCountries: visitedCountriesSet
                )
                
                var countryDestinations: [TravelDestination] = []
                if isUnlocked {
                    // 从索引字典中查找，提高效率
                    let countryCodes = [badge.country.rawValue, badge.country.displayName, badge.country.englishName]
                    for code in countryCodes {
                        if let dests = countryDestinationsMap[code] {
                            countryDestinations.append(contentsOf: dests)
                        }
                    }
                    // 去重
                    countryDestinations = Array(Set(countryDestinations.map { $0.id })).compactMap { id in
                        countryDestinations.first { $0.id == id }
                    }
                }
                
                // 计算最早年份和年份范围（在后台线程中直接计算）
                let calendar = Calendar.current
                let years = countryDestinations.compactMap { destination in
                    calendar.component(.year, from: destination.visitDate)
                }
                let earliestYear = years.min() ?? Int.max
                let yearRange: String? = {
                    guard !years.isEmpty, let minYear = years.min(), let maxYear = years.max() else { return nil }
                    if minYear == maxYear {
                        return "\(minYear)"
                    } else {
                        return "\(minYear)～\(maxYear)"
                    }
                }()
                
                // 缓存数据
                countryBadgeDataCache[badge.id] = (destinations: countryDestinations, yearRange: yearRange)
                
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
            }.map { $0.badge }
            
            // 计算省份勋章（只有当前国家是中国时才计算）
            var provinceBadgeDataCache: [String: (destinations: [TravelDestination], yearRange: String?)] = [:]
            let provinceBadgeData = isChina ? allProvinceBadges.map { badge -> (badge: ProvinceBadge, isUnlocked: Bool, earliestYear: Int) in
                let normalizedProvince = badgeManager.normalizeProvinceName(badge.provinceName)
                let isUnlocked = badgeManager.isProvinceBadgeUnlocked(
                    provinceName: normalizedProvince,
                    visitedProvinces: visitedProvincesSet
                )
                
                var provinceDestinations: [TravelDestination] = []
                if isUnlocked {
                    // 从索引字典中查找（使用标准化后的名称）
                    // 索引字典的key已经是标准化后的名称（在构建索引时处理）
                    // 支持"新疆"和"新疆维吾尔自治区"都能匹配，因为两者标准化后都是"新疆"
                    if let dests = provinceDestinationsMap[normalizedProvince] {
                        provinceDestinations = dests
                    }
                }
                
                // 计算最早年份和年份范围（在后台线程中直接计算）
                let calendar = Calendar.current
                let years = provinceDestinations.compactMap { destination in
                    calendar.component(.year, from: destination.visitDate)
                }
                let earliestYear = years.min() ?? Int.max
                let yearRange: String? = {
                    guard !years.isEmpty, let minYear = years.min(), let maxYear = years.max() else { return nil }
                    if minYear == maxYear {
                        return "\(minYear)"
                    } else {
                        return "\(minYear)～\(maxYear)"
                    }
                }()
                
                // 缓存数据
                provinceBadgeDataCache[badge.id] = (destinations: provinceDestinations, yearRange: yearRange)
                
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
            }.map { $0.badge } : []
            
            // 回到主线程更新UI
            await MainActor.run {
                self.cachedSortedCountryBadges = sortedCountryBadges
                self.cachedSortedProvinceBadges = sortedProvinceBadges
                self.countryBadgeDataCache = countryBadgeDataCache
                self.provinceBadgeDataCache = provinceBadgeDataCache
                self.isLoading = false
            }
        }
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
                
                // 进度条统计信息（黑色卡片样式）
                // 只有在国家勋章模式，或者省份勋章模式且当前国家是中国时才显示
                if selectedType == .country || (selectedType == .province && isCurrentCountryChina) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            // 标题：品牌红色
                            Text("badges_progress".localized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorScheme.iconColor)
                            
                            Spacer()
                            
                            // 百分比：浅灰色
                            Text("\(Int(progressPercentage))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                        }
                        
                        // 描述文字：白色
                        Text("\(statistics.unlocked)/\(statistics.total) \(selectedType == .country ? "country_badges".localized : "province_badges".localized)")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        // 进度条
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // 背景：深灰色
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColorScheme.progressBarBackground)
                                
                                // 进度：品牌红色
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColorScheme.progressBarFill)
                                    .frame(width: geometry.size.width * progressPercentage / 100)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progressPercentage)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(12)
                    .darkCardStyle(for: colorScheme, cornerRadius: 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                
                // 勋章网格
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    let horizontalPadding: CGFloat = 16
                    let columnSpacing: CGFloat = 16
                    let numberOfColumns: CGFloat = 3
                    
                    // 计算每个卡片的宽度：可用宽度 = 屏幕宽度 - 左右padding - 列间距
                    let availableWidth = screenWidth - (horizontalPadding * 2) - (columnSpacing * (numberOfColumns - 1))
                    let cardWidth = availableWidth / numberOfColumns
                    
                    ZStack {
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
                            .padding(.vertical, 16)
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
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { _ in
                // 当目的地被删除时，延迟更新以确保数据已同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateSortedBadges()
                    lastDestinationsSignature = destinationsSignature
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationUpdated)) { _ in
                // 当目的地被更新时（如添加省份、修改国家），强制更新以确保数据已同步
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateSortedBadges(forceUpdate: true)
                    lastDestinationsSignature = destinationsSignature
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .countryChanged)) { _ in
                // 当所在国家改变时，强制更新勋章列表
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateSortedBadges(forceUpdate: true)
                    lastDestinationsSignature = destinationsSignature
                }
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
}

#Preview {
    BadgeView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
}

