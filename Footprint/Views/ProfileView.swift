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
    @ObservedObject private var tabSnapshots = TabListSnapshotStore.shared
    @State private var showSettings = false
    @State private var statsForShare: TravelStats?
    @State private var refreshID = UUID()
    @State private var showAllDestinations = false
    @State private var selectedBadgeDetail: ProfileBadgeDetail?
    @ObservedObject private var profileCache = ProfileCacheStore.shared
    @Environment(\.modelContext) private var modelContext
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
        tabSnapshots.favoriteDestinations
    }

    private var destinationSnapshots: [ProfileDestinationSnapshot] {
        profileCache.destinationSnapshots
    }
    
    var body: some View {
        NavigationStack {
            FootprintHubScaffold(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
                statisticsCard
                
                countryBadgesCard
                
                if isBadgeCountryChina {
                    provinceBadgesCard
                }
                
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
            .sheet(item: $statsForShare) { stats in
                StatsSharePreviewView(stats: stats)
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
                TabListSnapshotStore.shared.attach(modelContext: modelContext)
                TabListSnapshotStore.shared.ensureProfileData()
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
                    presentStatsSharePreview()
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
        CountryManager.shared.currentCountry == .china
    }
    
    private var unlockedCountryBadges: [CountryBadge] {
        let badgeManager = BadgeManager.shared
        let visited = badgeManager.getVisitedCountries(from: destinationSnapshots)
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
        let visited = badgeManager.getVisitedProvinces(from: destinationSnapshots)
        return BadgeDataProvider.getAllProvinceBadges().filter { badge in
            badgeManager.isProvinceBadgeUnlocked(
                provinceName: badge.provinceName,
                visitedProvinces: visited
            )
        }
    }
    
    private var countryBadgeOverlapItems: [BadgeOverlapItem] {
        unlockedCountryBadges.map { badge in
            BadgeOverlapItem(
                id: badge.id,
                imageName: badge.imageName,
                title: badge.displayName,
                shortTitle: badge.displayName
            )
        }
    }
    
    private var provinceBadgeOverlapItems: [BadgeOverlapItem] {
        unlockedProvinceBadges.map { badge in
            BadgeOverlapItem(
                id: badge.id,
                imageName: badge.imageName,
                title: badge.provinceName,
                shortTitle: badge.displayName
            )
        }
    }
    
    private var countryBadgesCard: some View {
        BadgeProgressSummaryCard(
            items: countryBadgeOverlapItems,
            unlocked: unlockedCountryBadges.count,
            total: BadgeDataProvider.getAllCountryBadges().count,
            unitLabel: "badges_countries_unit".localized,
            emptyText: "badges_no_countries_yet".localized,
            title: "badges_progress_countries".localized,
            accent: Color.footprintRed,
            usesProvinceTickets: false,
            onSelectItem: { item in
                openBadgeDetail(for: item, type: .country)
            }
        )
    }
    
    private var provinceBadgesCard: some View {
        BadgeProgressSummaryCard(
            items: provinceBadgeOverlapItems,
            unlocked: unlockedProvinceBadges.count,
            total: BadgeDataProvider.getAllProvinceBadges().count,
            unitLabel: "badges_provinces_unit".localized,
            emptyText: "badges_no_provinces_yet".localized,
            title: "badges_progress_provinces".localized,
            accent: Color.footprintRed,
            usesProvinceTickets: true,
            onSelectItem: { item in
                openBadgeDetail(for: item, type: .province)
            }
        )
    }
    
    private func openBadgeDetail(for item: BadgeOverlapItem, type: BadgeType) {
        if type == .country {
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
        tabSnapshots.destinations(matchingCountry: country)
    }
    
    private func destinationsForProvince(_ provinceName: String) -> [TravelDestination] {
        tabSnapshots.destinations(matchingProvince: provinceName)
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

    // MARK: - 统计分享预览
    private func presentStatsSharePreview() {
        statsForShare = TravelStats(
            totalDestinations: statistics.total,
            domesticDestinations: statistics.domestic,
            internationalDestinations: statistics.international,
            countries: statistics.countries,
            countryData: countryShareData(),
            yearlyData: profileCache.timelineYearItems,
            userName: userProfileManager.displayName
        )
    }
    
    /// 按本地化国家名聚合地点数（供分享构成环）
    private func countryShareData() -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for snapshot in profileCache.destinationSnapshots {
            let name = snapshot.country.isEmpty
                ? "—"
                : CountryManager.shared.getLocalizedCountryName(from: snapshot.country)
            counts[name, default: 0] += 1
        }
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
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
