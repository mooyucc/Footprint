//
//  TripListView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData

struct TripListView: View {
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @State private var showingAddTrip = false
    @State private var searchText = ""
    @State private var shareItem: TripShareItem?
    
    var filteredTrips: [TravelTrip] {
        if searchText.isEmpty {
            return trips
        } else {
            return trips.filter { trip in
                trip.name.localizedCaseInsensitiveContains(searchText) ||
                trip.desc.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 统计信息
                Section {
                    TripStatisticsCard(trips: trips)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                // 旅行组列表
                Section {
                    ForEach(filteredTrips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            TripRow(trip: trip)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                shareTrip(trip)
                            } label: {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteTrips)
                }
            }
            .navigationTitle("我的旅程")
            .searchable(text: $searchText, prompt: "搜索旅程")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTrip = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddTripView()
            }
            .overlay {
                if trips.isEmpty {
                    EmptyTripView(showingAddTrip: $showingAddTrip)
                }
            }
            .sheet(item: $shareItem) { item in
                if let image = item.image {
                    // 只分享图片，不分享文字
                    SystemShareSheet(items: [image])
                } else {
                    SystemShareSheet(items: [item.text])
                }
            }
        }
    }
    
    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            let trip = filteredTrips[index]
            if let modelContext = trip.modelContext {
                modelContext.delete(trip)
            }
        }
    }
    
    private func shareTrip(_ trip: TravelTrip) {
        // 生成旅程图片
        let tripImage = TripImageGenerator.generateTripImage(from: trip)
        
        // 只分享图片，不分享文字（因为所有信息都已经包含在图片中）
        shareItem = TripShareItem(text: "", image: tripImage)
    }
}

struct TripRow: View {
    let trip: TravelTrip
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面图片或图标
            if let photoData = trip.coverPhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "map.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(trip.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if !trip.desc.isEmpty {
                    Text(trip.desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 12) {
                    Label("\(trip.durationDays)天", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(trip.destinationCount)个地点", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TripStatisticsCard: View {
    let trips: [TravelTrip]
    
    var statistics: (total: Int, totalDays: Int, totalDestinations: Int) {
        let total = trips.count
        let totalDays = trips.reduce(0) { $0 + $1.durationDays }
        let totalDestinations = trips.reduce(0) { $0 + $1.destinationCount }
        return (total, totalDays, totalDestinations)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("旅程统计")
                .font(.headline)
            
            HStack(spacing: 20) {
                TripStatItem(title: "旅程", value: "\(statistics.total)", icon: "suitcase.fill", color: .blue)
                TripStatItem(title: "天数", value: "\(statistics.totalDays)", icon: "calendar", color: .green)
                TripStatItem(title: "地点", value: "\(statistics.totalDestinations)", icon: "location.fill", color: .orange)
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

struct TripStatItem: View {
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

struct EmptyTripView: View {
    @Binding var showingAddTrip: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "suitcase")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("还没有旅程记录")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("点击右上角的 + 按钮\n创建你的第一个旅程吧！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddTrip = true
            } label: {
                Label("创建第一个旅程", systemImage: "plus.circle.fill")
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
    TripListView()
        .modelContainer(for: TravelTrip.self, inMemory: true)
}

