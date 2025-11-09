//
//  ContentView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var languageManager: LanguageManager
    
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Label("map".localized, image: "LocationIcon")
                }
                .tag(0)
            
            RoutesView()
                .tabItem {
                    Label("trips".localized, image: "LinkLineIcon")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("profile".localized, systemImage: "person.fill")
                }
                .tag(2)
        }
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
                VStack(spacing: 24) {
                    // 头部 - 用户信息
                    VStack(spacing: 12) {
                        if appleSignInManager.isSignedIn {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.blue.gradient)
                            
                            Text(appleSignInManager.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.icloud.fill")
                                    .foregroundColor(.green)
                                Text("iCloud_synced".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "airplane.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.blue.gradient)
                            
                            Text("my_travel_footprint".localized)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("record_every_journey".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)
                    
                    // 登录提示卡片（仅在未登录时显示）
                    if !appleSignInManager.isSignedIn {
                        Button {
                            showSettings = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "icloud.fill")
                                            .foregroundStyle(.blue.gradient)
                                            .font(.title2)
                                        Text("sign_in_apple_id".localized)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text("enable_icloud_sync".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 统计卡片
                    VStack(spacing: 16) {
                        HStack {
                            Text("travel_statistics".localized)
                                .font(.headline)
                            
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
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ProfileStatCard(
                                icon: "flag.fill",
                                value: "\(statistics.total)",
                                label: "total_destinations".localized,
                                color: .purple
                            )
                            
                            ProfileStatCard(
                                icon: "globe.asia.australia.fill",
                                value: "\(statistics.countries)",
                                label: "countries_visited".localized,
                                color: .green
                            )
                            
                            ProfileStatCard(
                                icon: "house.fill",
                                value: "\(statistics.domestic)",
                                label: "domestic_travel".localized,
                                color: .red
                            )
                            
                            ProfileStatCard(
                                icon: "airplane",
                                value: "\(statistics.international)",
                                label: "international_travel".localized,
                                color: .blue
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(15)
                    
                    // 喜爱的目的地
                    if !favoriteDestinations.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("my_favorites".localized)
                                    .font(.headline)
                            }
                            
                            ForEach(favoriteDestinations.prefix(5)) { destination in
                                NavigationLink {
                                    DestinationDetailView(destination: destination)
                                } label: {
                                    FavoriteDestinationRow(destination: destination)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(15)
                    }
                    
                    // 时间线
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("travel_timeline".localized)
                                .font(.headline)
                        }
                        
                        if destinations.isEmpty {
                            Text("no_travel_records".localized)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            let years = Dictionary(grouping: destinations) { destination in
                                Calendar.current.component(.year, from: destination.visitDate)
                            }
                            
                            ForEach(years.keys.sorted(by: >), id: \.self) { year in
                                NavigationLink {
                                    YearFilteredDestinationView(year: year)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(languageManager.currentLanguage == .chinese ? "\(year)年" : "\(year)")
                                                .font(.headline)
                                                .foregroundColor(.blue)
                                            
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
                                    .padding()
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(15)
                    
                    // 关于
                    VStack(spacing: 12) {
                        Text("footprint_app".localized)
                            .font(.headline)
                        
                        Text("record_journey_memories".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("profile".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.blue.gradient)
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
                // 语言变化时刷新界面
                refreshID = UUID()
            }
            .id(refreshID)
        }
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
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct FavoriteDestinationRow: View {
    let destination: TravelDestination
    
    var body: some View {
        HStack(spacing: 12) {
            if let photoData = destination.photoThumbnailData ?? destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(destination.normalizedCategory == "domestic" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "location.fill")
                        .foregroundColor(destination.normalizedCategory == "domestic" ? .red : .blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(destination.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(destination.country)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
        .environmentObject(AppleSignInManager.shared)
}