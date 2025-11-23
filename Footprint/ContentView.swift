//
//  ContentView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Label {
                        Text("map".localized)
                    } icon: {
                        Image("LocationIcon")
                            .renderingMode(.template)
                    }
                }
                .tag(0)
            
            RoutesView()
                .tabItem {
                    Label {
                        Text("trips".localized)
                    } icon: {
                        Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                    }
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label {
                        Text("profile".localized)
                    } icon: {
                        Image(systemName: "person.fill")
                    }
                }
                .tag(2)
        }
        .tint(brandColorManager.currentBrandColor) // 使用品牌红色，确保所有 tab 一致，并响应颜色变化
        .onAppear {
            configureTabBarAppearance(for: colorScheme, brandColor: brandColorManager.currentBrandColor)
        }
        .onChange(of: colorScheme) { newScheme in
            configureTabBarAppearance(for: newScheme, brandColor: brandColorManager.currentBrandColor)
        }
        .onChange(of: brandColorManager.currentBrandColor) { newColor in
            // 当品牌颜色改变时，立即更新 TabBar 外观
            configureTabBarAppearance(for: colorScheme, brandColor: newColor)
            // 强制刷新 TabView，确保所有标签页（包括"我的"）都能立即更新
            DispatchQueue.main.async {
                // 通过重新设置 selectedTab 来触发 TabView 刷新
                let currentTab = selectedTab
                // 先切换到无效的 tab 索引，强制 TabView 刷新
                selectedTab = -1
                // 立即切换回原 tab，触发所有标签页的重新渲染
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    selectedTab = currentTab
                    // 再次确保 TabBar 外观已更新
                    configureTabBarAppearance(for: colorScheme, brandColor: newColor)
                }
            }
        }
        .onChange(of: selectedTab) { _ in
            // 当切换 tab 时重新应用配置，确保颜色正确
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                configureTabBarAppearance(for: colorScheme, brandColor: brandColorManager.currentBrandColor)
            }
        }
    }
    
    private func configureTabBarAppearance(for scheme: ColorScheme, brandColor: Color) {
        // 使用品牌颜色作为选中颜色，确保所有 tab 一致
        let selectedColor: UIColor = UIColor(brandColor)
        let unselectedColor: UIColor = scheme == .dark ? UIColor.white.withAlphaComponent(0.6) : UIColor.secondaryLabel
        
        // 首先设置全局 tint 颜色，这是最关键的
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
        
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        
        // 配置所有布局样式（stacked 是主要使用的布局）
        let stackedLayout = appearance.stackedLayoutAppearance
        let inlineLayout = appearance.inlineLayoutAppearance
        let compactLayout = appearance.compactInlineLayoutAppearance
        
        // 选中状态：确保图标和文字颜色完全一致
        [stackedLayout, inlineLayout, compactLayout].forEach { layout in
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [
                .foregroundColor: selectedColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
        }
        
        // 未选中状态：确保图标和文字颜色完全一致
        [stackedLayout, inlineLayout, compactLayout].forEach { layout in
            layout.normal.iconColor = unselectedColor
            layout.normal.titleTextAttributes = [
                .foregroundColor: unselectedColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .regular)
            ]
        }
        
        // 应用外观配置
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // 使用 UITabBarItem.appearance 确保所有 TabBarItem 都应用颜色
        UITabBarItem.appearance().setTitleTextAttributes(
            [.foregroundColor: selectedColor],
            for: .selected
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.foregroundColor: unselectedColor],
            for: .normal
        )
        
        // 强制刷新所有现有的 TabBar 实例
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    // 递归查找并更新所有 TabBar
                    func updateTabBar(_ view: UIView) {
                        if let tabBar = view as? UITabBar {
                            tabBar.tintColor = selectedColor
                            tabBar.unselectedItemTintColor = unselectedColor
                            tabBar.standardAppearance = appearance
                            tabBar.scrollEdgeAppearance = appearance
                            // 强制刷新 TabBar 的布局
                            tabBar.setNeedsLayout()
                            tabBar.layoutIfNeeded()
                        }
                        view.subviews.forEach { updateTabBar($0) }
                    }
                    if let rootView = window.rootViewController?.view {
                        updateTabBar(rootView)
                    }
                }
            }
        }
    }
}

 

struct ProfileView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @Query private var destinations: [TravelDestination]
    @Query private var trips: [TravelTrip]
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var pendingShare = false
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - 配色（使用统一的 AppColorScheme 工具类）
    
    private var primaryButtonColor: Color {
        AppColorScheme.primaryButtonBackground(for: colorScheme)
    }
    
    private var buttonTextColor: Color {
        AppColorScheme.primaryButtonText(for: colorScheme)
    }
    
    private var primaryTextColor: Color {
        AppColorScheme.primaryText(for: colorScheme)
    }
    
    private var borderColor: Color {
        AppColorScheme.border(for: colorScheme)
    }
    
    var statistics: (total: Int, domestic: Int, international: Int, countries: Int, continents: Int) {
        let total = destinations.count
        // 使用 CountryManager 来判断是否为国内
        let domestic = destinations.filter { countryManager.isDomestic(country: $0.country) }.count
        let international = destinations.filter { !countryManager.isDomestic(country: $0.country) }.count
        let countries = Set(destinations.map { $0.country }).count
        
        // 简单的大洲判断逻辑
        let continents = estimateContinents()
        
        return (total, domestic, international, countries, continents)
    }
    
    var favoriteDestinations: [TravelDestination] {
        destinations.filter { $0.isFavorite }.sorted { $0.visitDate > $1.visitDate }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeaderView
                    
                    if !appleSignInManager.isSignedIn {
                        signInPromptCard
                    }
                    
                    statisticsCard
                    
                    if !favoriteDestinations.isEmpty {
                        favoritesCard
                    }
                    
                    timelineCard
                    
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("profile".localized)
            .navigationBarTitleDisplayMode(.inline)
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
    
    private var profileHeaderView: some View {
        VStack(spacing: 16) {
            if appleSignInManager.isSignedIn {
                Group {
                    if let avatarImage = appleSignInManager.userAvatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                
                Text(appleSignInManager.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)
                
                Text("record_every_journey".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Image("ImageMooyu")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                
                Text("my_travel_footprint".localized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)
                
                Text("record_every_journey".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private var signInPromptCard: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("sign_in_apple_id".localized)
                        .font(.headline)
                        .foregroundColor(brandColorManager.currentBrandColor)
                    
                    Text("enable_icloud_sync".localized)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(16)
            .darkCardStyle(for: colorScheme, cornerRadius: 15)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statisticsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("travel_statistics".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
                
                Spacer()
                
                Button {
                    generateAndShareStatsImage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("share".localized)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(brandColorManager.currentBrandColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ProfileStatCard(
                    icon: "flag.fill",
                    value: "\(statistics.total)",
                    label: "total_destinations".localized
                )
                
                ProfileStatCard(
                    icon: "globe.asia.australia.fill",
                    value: "\(statistics.countries)",
                    label: "countries_visited".localized
                )
                
                ProfileStatCard(
                    icon: "house.fill",
                    value: "\(statistics.domestic)",
                    label: "domestic_travel".localized
                )
                
                ProfileStatCard(
                    icon: "airplane",
                    value: "\(statistics.international)",
                    label: "international_travel".localized
                )
            }
        }
        .padding(20)
        .whiteCardStyle(for: colorScheme, cornerRadius: 20)
    }
    
    private var favoritesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.white)
                    .font(.headline)
                Text("my_favorites".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            ForEach(favoriteDestinations.prefix(5)) { destination in
                NavigationLink {
                    DestinationDetailView(destination: destination)
                } label: {
                    FavoriteDestinationRow(destination: destination)
                }
            }
        }
        .padding(20)
        .redCardStyle(cornerRadius: 20)
    }
    
    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(brandColorManager.currentBrandColor)
                    .font(.headline)
                Text("travel_timeline".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
            }
            
            if destinations.isEmpty {
                Text("no_travel_records".localized)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                timelineYearList
            }
        }
        .padding(20)
        .whiteCardStyle(for: colorScheme, cornerRadius: 20)
    }
    
    private var timelineYearList: some View {
        let years = Dictionary(grouping: destinations) { destination in
            Calendar.current.component(.year, from: destination.visitDate)
        }
        
        return ForEach(years.keys.sorted(by: >), id: \.self) { year in
            NavigationLink {
                YearFilteredDestinationView(year: year)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(languageManager.currentLanguage == .chinese ? "\(year)年" : "\(year)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(primaryTextColor)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(years[year]?.count ?? 0) \("destinations_count".localized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .beigeCardStyle(for: colorScheme, cornerRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var aboutSection: some View {
        VStack(spacing: 12) {
            Text("footprint_app".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(primaryTextColor)
            
            Text("record_journey_memories".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - 生成并分享统计图片
    private func generateAndShareStatsImage() {
        // 准备统计数据
        let yearlyData = Dictionary(grouping: destinations) { destination in
            Calendar.current.component(.year, from: destination.visitDate)
        }.map { (year: $0.key, count: $0.value.count) }
        
        let stats = TravelStats(
            totalDestinations: statistics.total,
            domesticDestinations: statistics.domestic,
            internationalDestinations: statistics.international,
            countries: statistics.countries,
            yearlyData: yearlyData,
            userName: appleSignInManager.displayName
        )
        
        // 生成图片
        if let image = StatsImageGenerator.generateStatsImage(stats: stats) {
            // 设置待分享标志
            pendingShare = true
            // 设置图片，onChange 会自动触发分享面板显示
            shareImage = image
        }
    }
    
    private func estimateContinents() -> Int {
        let asianCountries = ["中国", "日本", "韩国", "泰国", "新加坡", "马来西亚", "印度", "越南"]
        let europeanCountries = ["法国", "德国", "英国", "意大利", "西班牙", "瑞士", "荷兰", "冰岛"]
        let americanCountries = ["美国", "加拿大", "墨西哥", "巴西", "阿根廷"]
        let oceaniaCountries = ["澳大利亚", "新西兰"]
        let africanCountries = ["南非", "埃及", "摩洛哥", "肯尼亚"]
        
        var continents = Set<String>()
        
        for destination in destinations {
            if asianCountries.contains(destination.country) || destination.category == "domestic" {
                continents.insert("Asia")
            } else if europeanCountries.contains(destination.country) {
                continents.insert("Europe")
            } else if americanCountries.contains(destination.country) {
                continents.insert("America")
            } else if oceaniaCountries.contains(destination.country) {
                continents.insert("Oceania")
            } else if africanCountries.contains(destination.country) {
                continents.insert("Africa")
            }
        }
        
        return continents.count
    }
}

struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var brandColorManager: BrandColorManager
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(brandColorManager.currentBrandColor)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .beigeCardStyle(for: colorScheme, cornerRadius: 15)
    }
}

struct FavoriteDestinationRow: View {
    let destination: TravelDestination
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            if let photoData = destination.photoThumbnailData ?? destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppColorScheme.glassCardBorder, lineWidth: 1)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "location.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.title3)
                }
                .overlay(
                    Circle()
                        .stroke(AppColorScheme.glassCardBorder, lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(destination.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(destination.country)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.7))
                .font(.caption)
        }
        .padding(16)
        .glassCardStyle(material: .ultraThinMaterial, cornerRadius: 12, for: colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
        .environmentObject(AppleSignInManager.shared)
        .environmentObject(BrandColorManager.shared)
}