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
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddTrip = false
    @State private var searchText = ""
    @State private var shareItem: TripShareItem?
    @State private var showingImportAlert = false
    @State private var showingFilePicker = false
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var selectedURL: URL?
    @EnvironmentObject var languageManager: LanguageManager
    @State private var refreshID = UUID()
    
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
                                Label("share".localized, systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteTrips)
                }
            }
            .navigationTitle("my_trips".localized)
            .searchable(text: $searchText, prompt: "search_trips".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddTrip = true
                        } label: {
                            Label("create_trip".localized, systemImage: "plus.circle.fill")
                        }
                        
                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("import_trip".localized, systemImage: "square.and.arrow.down")
                        }
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
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(selectedURL: $selectedURL)
            }
            .alert("import_result".localized, isPresented: $showingImportResult) {
                Button("ok".localized) { }
            } message: {
                if let result = importResult {
                    switch result {
                    case .success(let trip):
                        Text("import_success".localized + ": \(trip.name)")
                    case .duplicate(let trip):
                        Text("trip_exists".localized + ": \(trip.name)")
                    case .error(let message):
                        Text("import_failed".localized + ": \(message)")
                    }
                }
            }
            .onChange(of: selectedURL) { oldValue, newValue in
                if let url = newValue {
                    importTripFromURL(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // 语言变化时刷新界面
                refreshID = UUID()
            }
            .id(refreshID)
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
    
    private func importTripFromURL(_ url: URL) {
        // 导入旅程
        importResult = TripDataImporter.importTrip(from: url, modelContext: modelContext)
        showingImportResult = true
        
        // 重置selectedURL
        selectedURL = nil
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
                    Label("\(trip.durationDays) \("days".localized)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(trip.destinationCount) \("locations".localized)", systemImage: "location.fill")
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
    @EnvironmentObject var languageManager: LanguageManager
    
    var statistics: (total: Int, totalDays: Int, totalDestinations: Int) {
        let total = trips.count
        let totalDays = trips.reduce(0) { $0 + $1.durationDays }
        let totalDestinations = trips.reduce(0) { $0 + $1.destinationCount }
        return (total, totalDays, totalDestinations)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("trip_statistics".localized)
                .font(.headline)
            
            HStack(spacing: 20) {
                TripStatItem(title: "trips".localized, value: "\(statistics.total)", icon: "suitcase.fill", color: .blue)
                TripStatItem(title: "days".localized, value: "\(statistics.totalDays)", icon: "calendar", color: .green)
                TripStatItem(title: "locations".localized, value: "\(statistics.totalDestinations)", icon: "location.fill", color: .orange)
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
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "suitcase")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("no_trip_records".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(languageManager.currentLanguage == .chinese ? "点击右上角的 + 按钮\n创建你的第一个旅程吧！" : "Tap the + button in the top right\nto create your first trip!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddTrip = true
            } label: {
                Label("create_first_trip".localized, systemImage: "plus.circle.fill")
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
        .environmentObject(LanguageManager.shared)
}

