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
    
    var filteredDestinations: [TravelDestination] {
        var result = destinations
        
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
        let total = destinations.count
        let domestic = destinations.filter { $0.category == "国内" }.count
        let international = destinations.filter { $0.category == "国外" }.count
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
            .navigationTitle("我的足迹")
            .searchable(text: $searchText, prompt: "搜索地点、国家或笔记")
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
                        .fill(destination.category == "国内" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "location.fill")
                        .foregroundColor(destination.category == "国内" ? .red : .blue)
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
                        Text(destination.visitDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(destination.visitDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(destination.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(destination.category == "国内" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundColor(destination.category == "国内" ? .red : .blue)
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
            Text("旅行统计")
                .font(.headline)
            
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
            
            Text("还没有旅行记录")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("点击右上角的 + 按钮\n开始记录你的旅行足迹吧！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddDestination = true
            } label: {
                Label("添加第一个目的地", systemImage: "plus.circle.fill")
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

