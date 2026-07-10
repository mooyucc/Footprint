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
    /// 已实例化的 Tab 索引；默认仅加载地图 Tab，避免启动时 4 个 Tab 同时 @Query 全量数据
    @State private var loadedTabs: Set<Int> = [0]
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 足迹地图（个人）
            lazyTabContent(0) {
                MapView()
            }
            .tabItem {
                Label {
                    Text("footprint_map".localized)
                } icon: {
                    Image(systemName: "map.fill")
                }
            }
            .tag(0)
            
            lazyTabContent(1) {
                JourneyCardsStackView()
            }
            .tabItem {
                Label {
                    Text("journey_cards_tab".localized)
                } icon: {
                    Image(systemName: "square.stack.3d.up.fill")
                }
            }
            .tag(1)
            
            lazyTabContent(2) {
                BadgeView(isTabSelected: selectedTab == 2)
            }
            .tabItem {
                Label {
                    Text("badges".localized)
                } icon: {
                    Image(systemName: "medal.star")
                }
            }
            .tag(2)
            
            lazyTabContent(3) {
                ProfileView()
            }
            .tabItem {
                Label {
                    Text("profile".localized)
                } icon: {
                    Image(systemName: "person.fill")
                }
            }
            .tag(3)
        }
        .tint(brandColorManager.currentBrandColor) // 使用品牌主题色，确保所有 tab 一致，并响应颜色变化
        .onAppear {
            configureTabBarAppearance(for: colorScheme, brandColor: brandColorManager.currentBrandColor)
            // 默认选中足迹地图 tab 时不会触发 onChange(selectedTab)，定位改由此处与 scenePhase 统一启动（原 MapView.onAppear 已仅用于嵌入全屏地图）
            if selectedTab == 0 {
                LocationManager.shared.startUpdatingLocation(mode: .mapBrowsing)
            }
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
        .onChange(of: selectedTab) { oldValue, newValue in
            // Tab 切换不再重复 configureTabBarAppearance：全局 appearance 已在 onAppear / 主题与深浅色变化时设置；
            // 此前每次切换递归整窗 UIView + layoutIfNeeded 会加重首切 Tab 时的主线程卡顿。
            if newValue >= 0 {
                loadedTabs.insert(newValue)
            }
            let locationManager = LocationManager.shared
            if newValue == 0 {
                // 切换到地图 tab（足迹地图），启动实时定位
                locationManager.startUpdatingLocation(mode: .mapBrowsing)
                print("📍 切换到地图 tab，启动实时定位")
            } else if oldValue == 0 {
                // 从地图 tab 切换到其他 tab，停止实时定位以节省电量
                locationManager.stopUpdatingLocation()
                print("📍 离开地图 tab，停止实时定位")
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // 当 app 进入后台时，停止实时定位以节省电量
            let locationManager = LocationManager.shared
            if newPhase == .background || newPhase == .inactive {
                // App 进入后台或非活跃状态，停止实时定位
                locationManager.stopUpdatingLocation()
                print("📍 App 进入后台/非活跃状态，停止实时定位")
            } else if newPhase == .active && selectedTab == 0 {
                // App 回到前台且当前在足迹地图 tab，重新启动实时定位
                locationManager.startUpdatingLocation(mode: .mapBrowsing)
                print("📍 App 回到前台且在地图 tab，重新启动实时定位")
            }
        }
    }

    @ViewBuilder
    private func lazyTabContent<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        if index == 0 {
            // 地图 Tab：离屏即卸载，停止 GPU/内存占用
            if selectedTab == 0 {
                content()
            } else {
                Color.clear
            }
        } else if loadedTabs.contains(index) {
            content()
        } else {
            Color.clear
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
        
        // 仅沿 UIViewController 树查找 UITabBarController，避免遍历 Map 等深层 UIView 子树
        DispatchQueue.main.async {
            Self.refreshTabBarsInKeyWindows(
                appearance: appearance,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor
            )
        }
    }
    
    /// 在窗口的根/子/模态 VC 链上查找 `UITabBarController`，更新其 `tabBar`（不做整树 `layoutIfNeeded`）。
    private static func refreshTabBarsInKeyWindows(
        appearance: UITabBarAppearance,
        selectedColor: UIColor,
        unselectedColor: UIColor
    ) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                guard let root = window.rootViewController else { continue }
                var stack: [UIViewController] = [root]
                var i = 0
                while i < stack.count {
                    let vc = stack[i]
                    i += 1
                    if let tab = vc as? UITabBarController {
                        let bar = tab.tabBar
                        bar.tintColor = selectedColor
                        bar.unselectedItemTintColor = unselectedColor
                        bar.standardAppearance = appearance
                        bar.scrollEdgeAppearance = appearance
                        bar.setNeedsLayout()
                    }
                    if let presented = vc.presentedViewController {
                        stack.append(presented)
                    }
                    stack.append(contentsOf: vc.children)
                }
            }
        }
    }
}

 

struct ProfileView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @Query private var destinations: [TravelDestination]
    @Query private var trips: [TravelTrip]
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showAICreditPaywall = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var pendingShare = false
    @State private var refreshID = UUID()
    @State private var showAllDestinations = false
    /// 缓存统计结果，避免每次进入「我的」或轻微状态变化时对所有目的地做完整计算
    @State private var statisticsCache: (total: Int, domestic: Int, international: Int, countries: Int, continents: Int)?
    /// 缓存收藏目的地列表（按时间排序）
    @State private var favoriteDestinationsCache: [TravelDestination] = []
    /// 缓存时间线年份及对应数量，避免每次渲染都重新分组
    @State private var timelineYearItemsCache: [(year: Int, count: Int)] = []
    @State private var profileCacheTask: Task<Void, Never>?
    @State private var lastProfileDestinationsSignature = ""
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
        statisticsCache ?? (0, 0, 0, 0, 0)
    }
    
    var favoriteDestinations: [TravelDestination] {
        favoriteDestinationsCache
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeaderView
                    
                    // 未登录时在订阅卡片上方显示登录提示
                    if !appleSignInManager.isSignedIn {
                        signInPromptCard
                    }
                    
                    // 始终显示订阅相关卡片（Beta版本中隐藏）
                    #if !BETA
                    if appleSignInManager.isSignedIn && entitlementManager.entitlement() == .pro {
                        membershipStatusCard
                    } else {
                        upgradeCard
                    }
                    #endif
                    
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showAICreditPaywall) {
                AICreditPaywallView()
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    SystemShareSheet(items: [image])
                }
            }
            .sheet(isPresented: $showAllDestinations) {
                AllDestinationsListView()
            }
            .onAppear {
                lastProfileDestinationsSignature = profileDestinationsSignature
                refreshProfileCaches()
            }
            .onChange(of: profileDestinationsSignature) { _, newSignature in
                guard newSignature != lastProfileDestinationsSignature else { return }
                lastProfileDestinationsSignature = newSignature
                refreshProfileCaches()
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
                    .interpolation(.high)  // 高质量插值，确保边缘光滑
                    .antialiased(true)     // 启用抗锯齿
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

    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundColor(.white)
                    .font(.title2)
                Text("paywall_banner_title".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                featureRow(title: "paywall_feature_ai".localized)
                featureRow(title: "paywall_feature_unlimited".localized)
                featureRow(title: "paywall_feature_share_layouts".localized)
                featureRow(title: "paywall_feature_import_export".localized)
            }
            
            (Text("paywall_emotional_message_part1".localized) +
             Text("\n") +
             Text("paywall_emotional_message_part2".localized)
                .fontWeight(.bold))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 4)
            
            VStack(spacing: 10) {
                Button {
                    showPaywall = true
                } label: {
                    Text("paywall_button_upgrade".localized)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColorManager.currentBrandColor)
                .controlSize(.large)
                
                Button {
                    showAICreditPaywall = true
                } label: {
                    Label("ai_buy_per_use_button".localized, systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(brandColorManager.currentBrandColor)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .controlSize(.large)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            brandColorManager.currentBrandColor.opacity(0.9),
                            brandColorManager.currentBrandColor.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
    }
    
    private func featureRow(title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.white.opacity(0.9))
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.92))
        }
    }
    
    private var subscriptionExpiryText: String {
        guard entitlementManager.entitlement() == .pro else {
            return "membership_status_subscribed".localized
        }
        
        if let expiry = entitlementManager.subscriptionExpiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "membership_status_expiry".localized(with: formatter.string(from: expiry))
        } else {
            return "membership_status_lifetime_active".localized
        }
    }
    
    private var membershipStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.white)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("membership_status_pro_active".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subscriptionExpiryText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            
            Divider()
                .overlay(Color.white.opacity(0.3))
            
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.white.opacity(0.9))
                Text("membership_status_all_features".localized)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    Text("membership_status_view_restore".localized)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.92))
                .cornerRadius(12)
                .foregroundColor(brandColorManager.currentBrandColor)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            brandColorManager.currentBrandColor.opacity(0.95),
                            brandColorManager.currentBrandColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
    }
    
    private var statisticsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("travel_statistics".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        showAllDestinations = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text("show_all_destinations".localized)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(brandColorManager.currentBrandColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(16)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    
                    Button {
                        generateAndShareStatsImage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("share".localized)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(brandColorManager.currentBrandColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(16)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ProfileStatCard(
                    icon: "flag.fill",
                    targetValue: statistics.total,
                    label: "total_destinations".localized
                )
                
                ProfileStatCard(
                    icon: "globe.asia.australia.fill",
                    targetValue: statistics.countries,
                    label: "countries_visited".localized
                )
                
                ProfileStatCard(
                    icon: "house.fill",
                    targetValue: statistics.domestic,
                    label: "domestic_travel".localized
                )
                
                ProfileStatCard(
                    icon: "airplane",
                    targetValue: statistics.international,
                    label: "international_travel".localized
                )
            }
        }
        .padding(20)
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
        ForEach(timelineYearItemsCache, id: \.year) { item in
            let year = item.year
            NavigationLink {
                YearFilteredDestinationView(year: year)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(languageManager.currentLanguage == .chinese ? "\(year)年" : "\(year)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(primaryTextColor)

                        Text("destinations_count".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("\(item.count)")
                            .font(.system(size: 32, weight: .black, design: .default))
                            .tracking(-0.8)
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .beigeCardStyle(for: colorScheme, cornerRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    /// 重新计算「我的」页相关统计与缓存（后台线程计算，主线程仅更新 UI）
    private var profileDestinationsSignature: String {
        DestinationCollectionSignature.makeForProfile(from: destinations)
    }

    private func refreshProfileCaches() {
        profileCacheTask?.cancel()

        let snapshots = destinations.map {
            ProfileDestinationSnapshot(
                id: $0.id,
                country: $0.country,
                category: $0.category,
                isFavorite: $0.isFavorite,
                visitDate: $0.visitDate
            )
        }
        let userCountry = countryManager.currentCountry

        profileCacheTask = Task {
            let computed = await Task.detached(priority: .userInitiated) {
                ProfileView.computeProfileCaches(from: snapshots, userCountry: userCountry)
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run {
                let destinationByID = Dictionary(uniqueKeysWithValues: destinations.map { ($0.id, $0) })
                statisticsCache = computed.statistics
                favoriteDestinationsCache = computed.favoriteIDs.compactMap { destinationByID[$0] }
                timelineYearItemsCache = computed.timelineYearItems
            }
        }
    }

    private struct ProfileDestinationSnapshot: Sendable {
        let id: UUID
        let country: String
        let category: String
        let isFavorite: Bool
        let visitDate: Date
    }

    private static func computeProfileCaches(
        from snapshots: [ProfileDestinationSnapshot],
        userCountry: CountryManager.Country
    ) -> (
        statistics: (total: Int, domestic: Int, international: Int, countries: Int, continents: Int),
        favoriteIDs: [UUID],
        timelineYearItems: [(year: Int, count: Int)]
    ) {
        let total = snapshots.count
        let domestic = snapshots.filter { isDomestic(country: $0.country, userCountry: userCountry) }.count
        let international = total - domestic
        let countries = Set(snapshots.map(\.country)).count
        let continents = estimateContinents(from: snapshots)

        let favoriteIDs = snapshots
            .filter(\.isFavorite)
            .sorted { $0.visitDate > $1.visitDate }
            .map(\.id)

        let calendar = Calendar.current
        let groups = Dictionary(grouping: snapshots) { snapshot in
            calendar.component(.year, from: snapshot.visitDate)
        }
        let timelineYearItems = groups
            .map { (year: $0.key, count: $0.value.count) }
            .sorted { $0.year > $1.year }

        return (
            (total, domestic, international, countries, continents),
            favoriteIDs,
            timelineYearItems
        )
    }

    private static func isDomestic(country: String, userCountry: CountryManager.Country) -> Bool {
        if country == userCountry.rawValue { return true }
        if country == userCountry.displayName { return true }
        if country == userCountry.englishName { return true }
        return false
    }

    private static func estimateContinents(from snapshots: [ProfileDestinationSnapshot]) -> Int {
        let asianCountries = ["中国", "日本", "韩国", "泰国", "新加坡", "马来西亚", "印度", "越南"]
        let europeanCountries = ["法国", "德国", "英国", "意大利", "西班牙", "瑞士", "荷兰", "冰岛"]
        let americanCountries = ["美国", "加拿大", "墨西哥", "巴西", "阿根廷"]
        let oceaniaCountries = ["澳大利亚", "新西兰"]
        let africanCountries = ["南非", "埃及", "摩洛哥", "肯尼亚"]

        var continents = Set<String>()

        for snapshot in snapshots {
            if asianCountries.contains(snapshot.country) || snapshot.category == "domestic" {
                continents.insert("Asia")
            } else if europeanCountries.contains(snapshot.country) {
                continents.insert("Europe")
            } else if americanCountries.contains(snapshot.country) {
                continents.insert("America")
            } else if oceaniaCountries.contains(snapshot.country) {
                continents.insert("Oceania")
            } else if africanCountries.contains(snapshot.country) {
                continents.insert("Africa")
            }
        }

        return continents.count
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
}

struct ProfileStatCard: View {
    let icon: String
    let targetValue: Int
    let label: String
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var brandColorManager: BrandColorManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(brandColorManager.currentBrandColor)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(targetValue)")
                    .font(.system(size: 36, weight: .black, design: .default))
                    .tracking(-0.8)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 0)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
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
