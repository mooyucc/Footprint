//
//  YearFilteredDestinationView.swift
//  Footprint
//
//  Created by K.X on 2025/01/27.
//

import SwiftUI
import SwiftData
import UIKit

struct YearFilteredDestinationView: View {
    let year: Int
    @Query private var allDestinations: [TravelDestination]
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var editingDestination: TravelDestination?
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    
    // 自定义配色 - 与"我的"tab保持一致
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
    
    init(year: Int) {
        self.year = year
        // 创建按年份过滤的查询
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        
        let predicate = #Predicate<TravelDestination> { destination in
            destination.visitDate >= startOfYear && destination.visitDate <= endOfYear
        }
        
        self._allDestinations = Query(filter: predicate, sort: \TravelDestination.visitDate, order: .reverse)
    }
    
    var filteredDestinations: [TravelDestination] {
        var result = allDestinations
        
        if let category = filterCategory {
            // 使用 CountryManager 来判断是否为国内
            result = result.filter { destination in
                let isDomestic = countryManager.isDomestic(country: destination.country)
                return category == "domestic" ? isDomestic : !isDomestic
            }
        }
        
        if !searchText.isEmpty {
            result = result.filter { destination in
                destination.name.localizedCaseInsensitiveContains(searchText) ||
                destination.country.localizedCaseInsensitiveContains(searchText) ||
                destination.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var statistics: (total: Int, domestic: Int, international: Int, countries: Int) {
        let total = allDestinations.count
        // 使用 CountryManager 来判断是否为国内
        let domestic = allDestinations.filter { countryManager.isDomestic(country: $0.country) }.count
        let international = allDestinations.filter { !countryManager.isDomestic(country: $0.country) }.count
        let countries = Set(allDestinations.map { $0.country }).count
        return (total, domestic, international, countries)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 年份统计信息卡片
                    YearStatisticsCard(
                        year: year,
                        statistics: statistics,
                        cardBackgroundColor: cardBackgroundColor,
                        primaryTextColor: primaryTextColor,
                        borderColor: borderColor,
                        shadow: largeCardShadow
                    )
                    
                    // 筛选器卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Text("filter".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(primaryTextColor)
                        
                        Picker("filter".localized, selection: $filterCategory) {
                            Text("all".localized).tag(nil as String?)
                            Text("domestic".localized).tag("domestic" as String?)
                            Text("international".localized).tag("international" as String?)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(20)
                    .background(largeCardBackgroundColor)
                    .cornerRadius(20)
                    .shadow(color: largeCardShadow.color, radius: largeCardShadow.radius, x: largeCardShadow.x, y: largeCardShadow.y)
                    
                    // 目的地列表
                    if !filteredDestinations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(languageManager.currentLanguage == .chinese ? "旅行目的地" : "Travel Destinations")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryTextColor)
                                .padding(.horizontal, 4)
                            
                            ForEach(filteredDestinations) { destination in
                                NavigationLink {
                                    DestinationDetailView(destination: destination)
                                } label: {
                                    DestinationRowCard(destination: destination, primaryTextColor: primaryTextColor)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button {
                                        editingDestination = destination
                                    } label: {
                                        Label("edit".localized, systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        deleteDestination(destination)
                                    } label: {
                                        Label("delete".localized, systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(largeCardBackgroundColor)
                        .cornerRadius(20)
                        .shadow(color: largeCardShadow.color, radius: largeCardShadow.radius, x: largeCardShadow.x, y: largeCardShadow.y)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(pageBackgroundColor)
            .navigationTitle(languageManager.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "search_places_countries_notes".localized)
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .overlay {
                if allDestinations.isEmpty {
                    EmptyYearStateView(year: year, pageBackgroundColor: pageBackgroundColor)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // 语言变化时刷新界面
                refreshID = UUID()
            }
            .id(refreshID)
        }
    }
    
    private func deleteDestination(_ destination: TravelDestination) {
        if let modelContext = destination.modelContext {
            modelContext.delete(destination)
        }
    }
    
    private func deleteDestinations(at offsets: IndexSet) {
        for index in offsets {
            let destination = filteredDestinations[index]
            if let modelContext = destination.modelContext {
                modelContext.delete(destination)
            }
        }
    }
}

struct YearStatisticsCard: View {
    let year: Int
    let statistics: (total: Int, domestic: Int, international: Int, countries: Int)
    let cardBackgroundColor: Color
    let primaryTextColor: Color
    let borderColor: Color
    let shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)
                Text(languageManager.currentLanguage == .chinese ? "\(year)年旅行统计" : "\(year) Travel Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
            }
            
            HStack(spacing: 12) {
                StatItem(title: "total".localized, value: "\(statistics.total)", icon: "map.fill", color: .purple)
                StatItem(title: "domestic".localized, value: "\(statistics.domestic)", icon: "house.fill", color: .red)
                StatItem(title: "international".localized, value: "\(statistics.international)", icon: "airplane", color: .blue)
                StatItem(title: "countries".localized, value: "\(statistics.countries)", icon: "globe.asia.australia.fill", color: .green)
            }
        }
        .padding(20)
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

struct DestinationRowCard: View {
    let destination: TravelDestination
    let primaryTextColor: Color
    @StateObject private var countryManager = CountryManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // 小卡片背景：略偏米色的白色 #f0e7da
    private var cardBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(.secondarySystemBackground)
            : Color(red: 0.941, green: 0.906, blue: 0.855) // #f0e7da
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
    
    private var visitDateText: String {
        DestinationRowCard.dateFormatter.string(from: destination.visitDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(destination.name.isEmpty ? "-" : destination.name)
                        .font(.headline)
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                    
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                    }
                }
                
                Text(destination.country.isEmpty ? "-" : destination.country)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(visitDateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if countryManager.isDomestic(country: destination.country) {
                Image(systemName: "house.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if !destination.country.isEmpty {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
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
        .shadow(color: shadowColor, radius: 6, x: 0, y: 2)
    }
    
    private var thumbnail: some View {
        Group {
            if let data = destination.photoThumbnailData ?? destination.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            .blue.opacity(0.3),
                            .purple.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: countryManager.isDomestic(country: destination.country) ? "location.fill" : "globe.asia.australia.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(14)
                }
            }
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct EmptyYearStateView: View {
    let year: Int
    let pageBackgroundColor: Color
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(languageManager.currentLanguage == .chinese ? "\(year)年还没有旅行记录" : "No travel records for \(year)")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(languageManager.currentLanguage == .chinese ? "去添加你的\(year)年旅行足迹吧！" : "Start adding your \(year) travel footprints!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackgroundColor)
    }
}

#Preview {
    YearFilteredDestinationView(year: 2024)
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
}
