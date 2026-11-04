//
//  ProfileView.swift
//  Footprint
//
//  从 ContentView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import UIKit

struct ProfileView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @Query private var destinations: [TravelDestination]
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var pendingShare = false
    @State private var refreshID = UUID()
    @State private var showAllDestinations = false
    @State private var badgeSelectedType: BadgeType = .country
    @State private var selectedBadgeDetail: ProfileBadgeDetail?
    @ObservedObject private var destinationRevision = DestinationDataRevision.shared
    @ObservedObject private var profileCache = ProfileCacheStore.shared
    @Environment(\.colorScheme) var colorScheme
    
    /// 「我的」页徽章弹窗数据
    private struct ProfileBadgeDetail: Identifiable {
        let id: String
        let imageName: String
        let title: String
        let destinations: [TravelDestination]
        let yearRange: String?
        let badgeType: BadgeType
    }
    
    // MARK: - 配色（使用统一的 AppColorScheme 工具类）
    
    private var primaryTextColor: Color {
        AppColorScheme.primaryText(for: colorScheme)
    }
    
    var statistics: ProfileStatistics {
        profileCache.displayStatistics
    }
    
    var favoriteDestinations: [TravelDestination] {
        let byID = Dictionary(uniqueKeysWithValues: destinations.map { ($0.id, $0) })
        return profileCache.favoriteIDs.compactMap { byID[$0] }
    }
    
    var body: some View {
        NavigationStack {
            FootprintHubScaffold(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
                statisticsCard
                
                badgesEntryCard
                
                if !favoriteDestinations.isEmpty {
                    favoritesCard
                }
            }
            .navigationTitle("profile".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    SystemShareSheet(items: [image])
                }
            }
            .sheet(isPresented: $showAllDestinations) {
                AllDestinationsListView()
            }
            .fullScreenCover(item: $selectedBadgeDetail) { badge in
                BadgeDetailView(
                    imageName: badge.imageName,
                    title: badge.title,
                    isUnlocked: true,
                    destinations: badge.destinations,
                    yearRange: badge.yearRange,
                    badgeType: badge.badgeType,
                    isPresented: Binding(
                        get: { selectedBadgeDetail != nil },
                        set: { if !$0 { selectedBadgeDetail = nil } }
                    )
                )
            }
            .onAppear {
                refreshProfileCachesIfNeeded()
            }
            .onChange(of: destinationRevision.revision) { _, newRevision in
                scheduleProfileCacheRefresh(revision: newRevision)
            }
            .onChange(of: destinations.count) { _, _ in
                // 冷启动 @Query 从空到有数据时 revision 不会 bump，需强制重算
                scheduleProfileCacheRefresh(revision: destinationRevision.revision, force: true)
            }
            .onChange(of: shareImage) { newImage in
                if newImage != nil && pendingShare {
                    showShareSheet = true
                    pendingShare = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            .id(refreshID)
        }
    }
    
    // MARK: - 子视图
    
    private var statisticsCard: some View {
        FootprintSectionCard(glow: brandColorManager.currentBrandColor, contentSpacing: 16) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(brandColorManager.currentBrandColor)
                Text("travel_statistics".localized)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)

                Button {
                    showAllDestinations = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(brandColorManager.currentBrandColor)
                        .frame(width: 36, height: 36)
                        .footprintCapsuleChrome()
                        .contentShape(Circle())
                }
                .accessibilityLabel("show_all_destinations".localized)

                Button {
                    generateAndShareStatsImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(brandColorManager.currentBrandColor)
                        .frame(width: 36, height: 36)
                        .footprintCapsuleChrome()
                        .contentShape(Circle())
                }
                .accessibilityLabel("share".localized)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(statistics.total)")
                    .font(.system(size: 52, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(statistics.total)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("total_destinations".localized)
                    .font(.subheadline)
                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            FootprintRowDivider()

            HStack(spacing: 0) {
                ProfileStatSecondaryCell(
                    value: statistics.countries,
                    label: "countries_visited".localized
                )
                Rectangle()
                    .fill(FootprintChrome.hairline(colorScheme))
                    .frame(width: FootprintChrome.hairlineHeight)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
                ProfileStatSecondaryCell(
                    value: statistics.domestic,
                    label: "domestic_travel".localized
                )
                Rectangle()
                    .fill(FootprintChrome.hairline(colorScheme))
                    .frame(width: FootprintChrome.hairlineHeight)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
                ProfileStatSecondaryCell(
                    value: statistics.international,
                    label: "international_travel".localized
                )
            }
        }
    }
    
    private var isBadgeCountryChina: Bool {
        countryManager.currentCountry == .china
    }
    
    private var unlockedCountryBadges: [CountryBadge] {
        let badgeManager = BadgeManager.shared
        let visited = badgeManager.getVisitedCountries(from: destinations)
        return CountryManager.Country.allCases.compactMap { country in
            guard badgeManager.isCountryBadgeUnlocked(country: country, visitedCountries: visited) else {
                return nil
            }
            return CountryBadge(country: country)
        }
    }
    
    private var unlockedProvinceBadges: [ProvinceBadge] {
        guard isBadgeCountryChina else { return [] }
        let badgeManager = BadgeManager.shared
        let visited = badgeManager.getVisitedProvinces(from: destinations)
        return BadgeDataProvider.getAllProvinceBadges().filter { badge in
            badgeManager.isProvinceBadgeUnlocked(
                provinceName: badge.provinceName,
                visitedProvinces: visited
            )
        }
    }
    
    private var currentBadgeOverlapItems: [BadgeOverlapItem] {
        if badgeSelectedType == .country {
            return unlockedCountryBadges.map { badge in
                BadgeOverlapItem(
                    id: badge.id,
                    imageName: badge.imageName,
                    title: badge.displayName,
                    shortTitle: badge.displayName
                )
            }
        } else {
            return unlockedProvinceBadges.map { badge in
                BadgeOverlapItem(
                    id: badge.id,
                    imageName: badge.imageName,
                    title: badge.provinceName,
                    shortTitle: badge.displayName
                )
            }
        }
    }
    
    private var badgeProgressUnlocked: Int {
        badgeSelectedType == .country
            ? unlockedCountryBadges.count
            : unlockedProvinceBadges.count
    }
    
    private var badgeProgressTotal: Int {
        badgeSelectedType == .country
            ? BadgeDataProvider.getAllCountryBadges().count
            : BadgeDataProvider.getAllProvinceBadges().count
    }
    
    private var badgeUnitLabel: String {
        badgeSelectedType == .country
            ? "badges_countries_unit".localized
            : "badges_provinces_unit".localized
    }
    
    private var badgeEmptyText: String {
        badgeSelectedType == .country
            ? "badges_no_countries_yet".localized
            : "badges_no_provinces_yet".localized
    }
    
    private var badgeCrossHint: (text: String, switchTo: BadgeType)? {
        guard isBadgeCountryChina else { return nil }
        if badgeSelectedType == .country {
            let count = unlockedProvinceBadges.count
            guard count > 0 else { return nil }
            return ("badges_domestic_provinces_hint".localized(with: count), .province)
        } else {
            let count = unlockedCountryBadges.count
            guard count > 0 else { return nil }
            return ("badges_global_countries_hint".localized(with: count), .country)
        }
    }
    
    private var badgesEntryCard: some View {
        BadgeProgressSummaryCard(
            items: currentBadgeOverlapItems,
            unlocked: badgeProgressUnlocked,
            total: badgeProgressTotal,
            unitLabel: badgeUnitLabel,
            emptyText: badgeEmptyText,
            crossHintText: badgeCrossHint?.text,
            accent: Color.footprintRed,
            onSelectItem: { item in
                openBadgeDetail(for: item)
            },
            onCrossHintTap: {
                guard let hint = badgeCrossHint else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    badgeSelectedType = hint.switchTo
                }
            }
        )
    }
    
    private func openBadgeDetail(for item: BadgeOverlapItem) {
        if badgeSelectedType == .country {
            guard let badge = unlockedCountryBadges.first(where: { $0.id == item.id }) else { return }
            let matched = destinationsForCountry(badge.country)
            selectedBadgeDetail = ProfileBadgeDetail(
                id: badge.id,
                imageName: badge.imageName,
                title: badge.displayName,
                destinations: matched,
                yearRange: yearRangeString(for: matched),
                badgeType: .country
            )
        } else {
            guard let badge = unlockedProvinceBadges.first(where: { $0.id == item.id }) else { return }
            let matched = destinationsForProvince(badge.provinceName)
            selectedBadgeDetail = ProfileBadgeDetail(
                id: badge.id,
                imageName: badge.imageName,
                title: badge.displayName,
                destinations: matched,
                yearRange: yearRangeString(for: matched),
                badgeType: .province
            )
        }
    }
    
    private func destinationsForCountry(_ country: CountryManager.Country) -> [TravelDestination] {
        let codes = [country.rawValue, country.displayName, country.englishName]
        return destinations.filter { destination in
            codes.contains { code in
                destination.country == code ||
                destination.country.localizedCaseInsensitiveContains(code)
            }
        }
    }
    
    private func destinationsForProvince(_ provinceName: String) -> [TravelDestination] {
        let badgeManager = BadgeManager.shared
        let normalized = badgeManager.normalizeProvinceName(provinceName)
        return destinations.filter { destination in
            let isChina = destination.country == "中国" ||
                destination.country == "CN" ||
                destination.country == "China"
            guard isChina else { return false }
            return badgeManager.normalizeProvinceName(destination.province) == normalized
        }
    }
    
    private func yearRangeString(for destinations: [TravelDestination]) -> String? {
        let years = destinations.map { Calendar.current.component(.year, from: $0.visitDate) }
        guard let minYear = years.min(), let maxYear = years.max() else { return nil }
        return minYear == maxYear ? "\(minYear)" : "\(minYear)～\(maxYear)"
    }
    
    private var favoritesCard: some View {
        FootprintSectionCard(glow: brandColorManager.currentBrandColor) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(brandColorManager.currentBrandColor)
                    .font(.headline)
                Text("my_favorites".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            
            ForEach(Array(favoriteDestinations.prefix(5).enumerated()), id: \.element.id) { index, destination in
                if index > 0 {
                    FootprintRowDivider()
                }
                NavigationLink {
                    DestinationDetailView(destination: destination)
                } label: {
                    FavoriteDestinationRow(destination: destination)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// 仅在 revision 变化或尚无缓存时重算（磁盘快照 + 会话内跨 Tab 保留）
    private func refreshProfileCachesIfNeeded() {
        profileCache.refreshIfNeeded(
            revision: destinationRevision.revision,
            snapshots: makeProfileSnapshots(),
            userCountry: countryManager.currentCountry
        )
    }

    /// debounce：等待 SwiftData @Query 同步后再重算
    private func scheduleProfileCacheRefresh(revision: Int, force: Bool = false) {
        profileCache.scheduleRefresh(
            revision: revision,
            snapshots: { [self] in makeProfileSnapshots() },
            userCountry: { [self] in countryManager.currentCountry },
            force: force
        )
    }

    private func makeProfileSnapshots() -> [ProfileDestinationSnapshot] {
        destinations.map {
            ProfileDestinationSnapshot(
                id: $0.id,
                country: $0.country,
                category: $0.category,
                isFavorite: $0.isFavorite,
                visitDate: $0.visitDate
            )
        }
    }

    // MARK: - 生成并分享统计图片
    private func generateAndShareStatsImage() {
        let yearlyData = profileCache.timelineYearItems

        let stats = TravelStats(
            totalDestinations: statistics.total,
            domesticDestinations: statistics.domestic,
            internationalDestinations: statistics.international,
            countries: statistics.countries,
            yearlyData: yearlyData,
            userName: userProfileManager.displayName
        )
        
        // 生成图片
        if let image = StatsImageGenerator.generateStatsImage(stats: stats) {
            // 设置待分享标志
            pendingShare = true
            // 设置图片，onChange 会自动触发分享面板显示
            shareImage = image
        }
    }
}


struct ProfileStatSecondaryCell: View {
    let value: Int
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}


struct FavoriteDestinationRow: View {
    let destination: TravelDestination
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var brandColorManager: BrandColorManager
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(FootprintChrome.cardStroke(colorScheme), lineWidth: 1)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(brandColorManager.currentBrandColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "location.fill")
                        .foregroundStyle(brandColorManager.currentBrandColor)
                        .font(.title3)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(destination.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(destination.country)
                    .font(.caption)
                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(FootprintChrome.tertiaryLabel(colorScheme))
                .font(.caption)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .task(id: destination.id) {
            thumbnail = await DestinationThumbnailCache.shared.imageForListCard(
                for: destination.id,
                thumbnailData: destination.photoThumbnailData,
                fallbackData: destination.photoData
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
        .environmentObject(UserProfileManager.shared)
        .environmentObject(BrandColorManager.shared)
}
