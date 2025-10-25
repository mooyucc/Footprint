//
//  DestinationListView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData

struct DestinationListView: View {
    @Query(sort: \TravelDestination.visitDate, order: .reverse) private var destinations: [TravelDestination]
    @State private var showingAddDestination = false
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var editingDestination: TravelDestination?
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()
    
    var filteredDestinations: [TravelDestination] {
        var result = destinations
        
        if let category = filterCategory {
            result = result.filter { $0.normalizedCategory == category }
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
        let total = destinations.count
        let domestic = destinations.filter { $0.normalizedCategory == "domestic" }.count
        let international = destinations.filter { $0.normalizedCategory == "international" }.count
        let countries = Set(destinations.map { $0.country }).count
        return (total, domestic, international, countries)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 统计信息卡片
                Section {
                    StatisticsCard(statistics: statistics)
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
            .navigationTitle("my_footprints".localized)
            .searchable(text: $searchText, prompt: "search_places_countries_notes".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddDestination = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddDestination) {
                AddDestinationView()
            }
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .overlay {
                if destinations.isEmpty {
                    EmptyStateView(showingAddDestination: $showingAddDestination)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // 语言变化时刷新界面
                refreshID = UUID()
            }
            .onAppear {
                // 数据迁移：将本地化字符串转换为标准格式
                migrateCategoryData()
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
    
    private func migrateCategoryData() {
        // 查找需要迁移的数据（包含本地化字符串的分类）
        let destinationsToMigrate = destinations.filter { destination in
            destination.category == "国内" || destination.category == "国外"
        }
        
        if !destinationsToMigrate.isEmpty {
            print("🔄 发现 \(destinationsToMigrate.count) 个目的地需要数据迁移")
            for destination in destinationsToMigrate {
                destination.migrateCategoryToStandard()
            }
            print("✅ 数据迁移完成")
        }
    }
}

struct DestinationRow: View {
    let destination: TravelDestination
    
    var body: some View {
        HStack(spacing: 12) {
            // 照片或图标
            if let photoData = destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(destination.category == "domestic" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "location.fill")
                        .foregroundColor(destination.category == "domestic" ? .red : .blue)
                        .font(.title2)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(destination.name)
                        .font(.headline)
                    
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Text(destination.country)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 显示所属旅程
                if let trip = destination.trip {
                    HStack(spacing: 4) {
                        Image(systemName: "suitcase.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text(trip.name)
                            .font(.caption)
                            .foregroundColor(.purple)
                            .lineLimit(1)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destination.visitDate.localizedFormatted(dateStyle: .medium))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(destination.visitDate.localizedFormatted(dateStyle: .none, timeStyle: .short))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(destination.localizedCategory)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(destination.category == "domestic" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundColor(destination.category == "domestic" ? .red : .blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatisticsCard: View {
    let statistics: (total: Int, domestic: Int, international: Int, countries: Int)
    
    var body: some View {
        VStack(spacing: 16) {
            Text("travel_statistics".localized)
                .font(.headline)
            
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

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateView: View {
    @Binding var showingAddDestination: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("no_travel_records".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("start_recording_footprints".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddDestination = true
            } label: {
                Label("add_first_destination".localized, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(15)
            }
        }
        .padding()
    }
}

#Preview {
    DestinationListView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
}

