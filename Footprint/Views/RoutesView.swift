//
//  RoutesView.swift
//  Footprint
//
//  Created by K.X on 2025/01/XX.
//

import SwiftUI
import SwiftData

struct RoutesView: View {
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()
    @State private var showingAddTrip = false
    @State private var showingFilePicker = false
    @State private var selectedURL: URL?
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @Environment(\.modelContext) private var modelContext
    
    // 过滤出至少有2个地点的旅程
    private var validTrips: [TravelTrip] {
        trips.filter { trip in
            if let destinations = trip.destinations,
               !destinations.isEmpty,
               destinations.count >= 2 {
                return true
            }
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            // 显示地图视图，并自动显示线路卡片
            MapView(autoShowRouteCards: true)
                .navigationTitle("trips".localized)
                .navigationBarTitleDisplayMode(.inline)
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
                    refreshID = UUID()
                }
                .id(refreshID)
        }
    }
    
    private func importTripFromURL(_ url: URL) {
        importResult = TripDataImporter.importTrip(from: url, modelContext: modelContext)
        showingImportResult = true
        selectedURL = nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    
    return RoutesView()
        .modelContainer(container)
        .environmentObject(LanguageManager.shared)
}

