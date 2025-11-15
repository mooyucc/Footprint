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
                    Label("profile".localized, systemImage: "person.fill")
                }
                .tag(2)
        }
        .onAppear {
            configureTabBarAppearance(for: colorScheme)
        }
        .onChange(of: colorScheme) { newScheme in
            configureTabBarAppearance(for: newScheme)
        }
    }
    
    private func configureTabBarAppearance(for scheme: ColorScheme) {
        let selectedColor: UIColor = scheme == .dark ? .white : UIColor.label
        let unselectedColor: UIColor = scheme == .dark ? UIColor.white.withAlphaComponent(0.6) : UIColor.secondaryLabel
        
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        
        let layouts = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        
        layouts.forEach { layout in
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            layout.normal.iconColor = unselectedColor
            layout.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        }
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
    }
}

 

struct ProfileView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var countryManager = CountryManager.shared
    @Query private var destinations: [TravelDestination]
    @Query private var trips: [TravelTrip]
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var pendingShare = false
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    
    // 自定义配色 - 参考附图的米色和优雅配色
    // 页面背景：非常浅的米白色 #f7f3eb
    private var pageBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(.systemGroupedBackground)
            : Color(red: 0.969, green: 0.953, blue: 0.922) // #f7f3eb
    }
    
    // 大卡片背景：纯白色 #FFFFFF
    private var largeCardBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(.secondarySystemBackground)
            : Color.white // #FFFFFF
    }
    
    // 小卡片背景：略偏米色的白色 #f0e7da
    private var cardBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(.secondarySystemBackground)
            : Color(red: 0.941, green: 0.906, blue: 0.855) // #f0e7da
    }
    
    // 主按钮颜色：深灰/黑色
    private var primaryButtonColor: Color {
        colorScheme == .dark ? Color.white : Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    }
    
    // 按钮文字颜色：根据按钮背景色适配
    private var buttonTextColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.white // 深色模式背景是白色，文字用深色；浅色模式背景是深色，文字用白色
    }
    
    // 文本颜色：深灰色
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.primary : Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    }
    
    // 边框颜色：更柔和的边框
    private var borderColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06) // 更柔和的边框
    }
    
    // 大卡片阴影：更明显的阴影效果
    private var largeCardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    // 小卡片阴影：中等强度的阴影效果
    private var smallCardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            color: Color.black.opacity(0.08),
            radius: 6,
            x: 0,
            y: 2
        )
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
            .background(pageBackgroundColor)
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
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(appleSignInManager.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text("iCloud_synced".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
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
                    .foregroundColor(primaryTextColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("sign_in_apple_id".localized)
                        .font(.headline)
                        .foregroundColor(primaryTextColor)
                    
                    Text("enable_icloud_sync".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(cardBackgroundColor)
            .cornerRadius(15)
            .shadow(color: smallCardShadow.color, radius: smallCardShadow.radius, x: smallCardShadow.x, y: smallCardShadow.y)
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
                    .foregroundColor(buttonTextColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(primaryButtonColor)
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
                    label: "total_destinations".localized,
                    color: .purple,
                    cardBackground: cardBackgroundColor
                )
                
                ProfileStatCard(
                    icon: "globe.asia.australia.fill",
                    value: "\(statistics.countries)",
                    label: "countries_visited".localized,
                    color: .green,
                    cardBackground: cardBackgroundColor
                )
                
                ProfileStatCard(
                    icon: "house.fill",
                    value: "\(statistics.domestic)",
                    label: "domestic_travel".localized,
                    color: .red,
                    cardBackground: cardBackgroundColor
                )
                
                ProfileStatCard(
                    icon: "airplane",
                    value: "\(statistics.international)",
                    label: "international_travel".localized,
                    color: .blue,
                    cardBackground: cardBackgroundColor
                )
            }
        }
        .padding(20)
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: largeCardShadow.color, radius: largeCardShadow.radius, x: largeCardShadow.x, y: largeCardShadow.y)
    }
    
    private var favoritesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.headline)
                Text("my_favorites".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
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
        .background(largeCardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: largeCardShadow.color, radius: largeCardShadow.radius, x: largeCardShadow.x, y: largeCardShadow.y)
    }
    
    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
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
        .background(largeCardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: largeCardShadow.color, radius: largeCardShadow.radius, x: largeCardShadow.x, y: largeCardShadow.y)
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
                .background(
                    colorScheme == .dark 
                        ? Color(.tertiarySystemBackground)
                        : Color(red: 0.969, green: 0.949, blue: 0.918) // #f7f2ea
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
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
    let color: Color
    let cardBackground: Color
    @Environment(\.colorScheme) var colorScheme
    
    // 文本颜色：深灰色
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.primary : Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    }
    
    // 边框颜色：更柔和的边框
    private var borderColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
    
    // 小卡片阴影：中等强度的阴影效果
    private var shadowColor: Color {
        Color.black.opacity(0.08)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            colorScheme == .dark 
                ? Color(.tertiarySystemBackground)
                : Color(red: 0.969, green: 0.949, blue: 0.918) // #f7f2ea
        )
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 6, x: 0, y: 2)
    }
}

struct FavoriteDestinationRow: View {
    let destination: TravelDestination
    @Environment(\.colorScheme) var colorScheme
    
    // 文本颜色：深灰色
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.primary : Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    }
    
    // 边框颜色：更柔和的边框
    private var borderColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
    
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
                            .stroke(borderColor, lineWidth: 1)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(destination.normalizedCategory == "domestic" ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "location.fill")
                        .foregroundColor(destination.normalizedCategory == "domestic" ? .red : .blue)
                        .font(.title3)
                }
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(destination.name)
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                
                Text(destination.country)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(16)
        .background(
            colorScheme == .dark 
                ? Color(.tertiarySystemBackground)
                : Color(red: 0.969, green: 0.949, blue: 0.918) // #f7f2ea
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
        .environmentObject(AppleSignInManager.shared)
}