//
//  YearFilteredDestinationView.swift
//  Footprint
//
//  Created by K.X on 2025/01/27.
//

import SwiftUI
import SwiftData

struct YearFilteredDestinationView: View {
    let year: Int
    @Query private var allDestinations: [TravelDestination]
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var editingDestination: TravelDestination?
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var refreshID = UUID()
    
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
            List {
                // 年份统计信息卡片
                Section {
                    YearStatisticsCard(year: year, statistics: statistics)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                // 筛选器
                Section {
                    Picker("filter".localized, selection: $filterCategory) {
                        Text("all".localized).tag(nil as String?)
                        Text("domestic".localized).tag("domestic" as String?)
                        Text("international".localized).tag("international" as String?)
                    }
                    .pickerStyle(.segmented)
                }
                
                // 目的地列表
                Section {
                    ForEach(filteredDestinations) { destination in
                        NavigationLink {
                            DestinationDetailView(destination: destination)
                        } label: {
                            DestinationRow(destination: destination)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                editingDestination = destination
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteDestination(destination)
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteDestinations)
                }
            }
            .navigationTitle(languageManager.currentLanguage == .chinese ? "\(year)年旅行记录" : "\(year) Travel Records")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "search_places_countries_notes".localized)
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .overlay {
                if allDestinations.isEmpty {
                    EmptyYearStateView(year: year)
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
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text(languageManager.currentLanguage == .chinese ? "\(year)年旅行统计" : "\(year) Travel Statistics")
                    .font(.headline)
            }
            
            HStack(spacing: 20) {
                StatItem(title: "total".localized, value: "\(statistics.total)", icon: "map.fill", color: .purple)
                StatItem(title: "domestic".localized, value: "\(statistics.domestic)", icon: "house.fill", color: .red)
                StatItem(title: "international".localized, value: "\(statistics.international)", icon: "airplane", color: .blue)
                StatItem(title: "countries".localized, value: "\(statistics.countries)", icon: "globe.asia.australia.fill", color: .green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
        )
        .padding()
    }
}

struct EmptyYearStateView: View {
    let year: Int
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
    }
}

#Preview {
    YearFilteredDestinationView(year: 2024)
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
}
