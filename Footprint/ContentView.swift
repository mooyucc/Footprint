//
//  ContentView.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Label("地图", systemImage: "map.fill")
                }
                .tag(0)
            
            DestinationListView()
                .tabItem {
                    Label("足迹", systemImage: "location.fill")
                }
                .tag(1)
            
            TripListView()
                .tabItem {
                    Label("旅程", systemImage: "suitcase.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @Query private var destinations: [TravelDestination]
    @State private var showSettings = false
    
    var statistics: (total: Int, domestic: Int, international: Int, countries: Int, continents: Int) {
        let total = destinations.count
        let domestic = destinations.filter { $0.category == "国内" }.count
        let international = destinations.filter { $0.category == "国外" }.count
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
                                Text("iCloud 已同步")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Image(systemName: "airplane.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.blue.gradient)
                            
                            Text("我的旅行足迹")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("记录每一次精彩的旅程")
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
                                        Text("登录 Apple ID")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text("开启 iCloud 同步，保护你的旅行数据")
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
                        Text("旅行统计")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ProfileStatCard(
                                icon: "flag.fill",
                                value: "\(statistics.total)",
                                label: "总目的地",
                                color: .purple
                            )
                            
                            ProfileStatCard(
                                icon: "globe.asia.australia.fill",
                                value: "\(statistics.countries)",
                                label: "访问国家",
                                color: .green
                            )
                            
                            ProfileStatCard(
                                icon: "house.fill",
                                value: "\(statistics.domestic)",
                                label: "国内旅行",
                                color: .red
                            )
                            
                            ProfileStatCard(
                                icon: "airplane",
                                value: "\(statistics.international)",
                                label: "国外旅行",
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
                                Text("我的最爱")
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
                            Text("旅行时间线")
                                .font(.headline)
                        }
                        
                        if destinations.isEmpty {
                            Text("还没有旅行记录")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            let years = Dictionary(grouping: destinations) { destination in
                                Calendar.current.component(.year, from: destination.visitDate)
                            }
                            
                            ForEach(years.keys.sorted(by: >), id: \.self) { year in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(year)年")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    
                                    Text("\(years[year]?.count ?? 0) 个目的地")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(15)
                    
                    // 关于
                    VStack(spacing: 12) {
                        Text("Footprint - 旅行足迹")
                            .font(.headline)
                        
                        Text("记录你的精彩旅程，留下美好回忆")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Version 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("我的")
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
            if asianCountries.contains(destination.country) || destination.category == "国内" {
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
            if let photoData = destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(destination.category == "国内" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "location.fill")
                        .foregroundColor(destination.category == "国内" ? .red : .blue)
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
}