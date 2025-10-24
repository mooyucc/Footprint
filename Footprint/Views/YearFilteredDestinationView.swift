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
            result = result.filter { $0.category == category }
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
        let domestic = allDestinations.filter { $0.category == "国内" }.count
        let international = allDestinations.filter { $0.category == "国外" }.count
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
                    Picker("筛选", selection: $filterCategory) {
                        Text("全部").tag(nil as String?)
                        Text("国内").tag("国内" as String?)
                        Text("国外").tag("国外" as String?)
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
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteDestination(destination)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteDestinations)
                }
            }
            .navigationTitle("\(year)年旅行记录")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索地点、国家或笔记")
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .overlay {
                if allDestinations.isEmpty {
                    EmptyYearStateView(year: year)
                }
            }
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
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("\(year)年旅行统计")
                    .font(.headline)
            }
            
            HStack(spacing: 20) {
                StatItem(title: "总计", value: "\(statistics.total)", icon: "map.fill", color: .purple)
                StatItem(title: "国内", value: "\(statistics.domestic)", icon: "house.fill", color: .red)
                StatItem(title: "国外", value: "\(statistics.international)", icon: "airplane", color: .blue)
                StatItem(title: "国家", value: "\(statistics.countries)", icon: "globe.asia.australia.fill", color: .green)
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
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("\(year)年还没有旅行记录")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("去添加你的\(year)年旅行足迹吧！")
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
}
