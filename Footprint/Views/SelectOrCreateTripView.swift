//
//  SelectOrCreateTripView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData

struct SelectOrCreateTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @StateObject private var languageManager = LanguageManager.shared
    
    let destination: TravelDestination
    @State private var selectedTrip: TravelTrip?
    @State private var showingCreateTrip = false
    @State private var previousTripsCount = 0
    
    var body: some View {
        NavigationStack {
            Form {
                if trips.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("no_trips_available".localized)
                                .foregroundColor(.secondary)
                            
                            Button {
                                showingCreateTrip = true
                            } label: {
                                Text("create_trip".localized)
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    Section {
                        Picker("select_trip".localized, selection: $selectedTrip) {
                            Text("none".localized).tag(nil as TravelTrip?)
                            ForEach(trips) { trip in
                                Text(trip.name).tag(trip as TravelTrip?)
                            }
                        }
                        
                        if let trip = selectedTrip {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.name)
                                        .font(.caption)
                                    Text("\(trip.startDate.localizedFormatted(dateStyle: .medium)) - \(trip.endDate.localizedFormatted(dateStyle: .medium))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button {
                            showingCreateTrip = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("create_trip".localized)
                            }
                        }
                    }
                }
            }
            .navigationTitle("add_to_trip".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveTrip()
                    }
                    .disabled(selectedTrip == nil)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingCreateTrip) {
                AddTripView()
            }
            .onChange(of: trips.count) { oldCount, newCount in
                // 当旅程数量增加时（创建了新旅程），自动选择最新的旅程
                if newCount > oldCount, let latestTrip = trips.first {
                    selectedTrip = latestTrip
                }
            }
            .onAppear {
                // 初始化时，如果目的地已经有旅程，自动选择它
                if let currentTrip = destination.trip {
                    selectedTrip = currentTrip
                }
                previousTripsCount = trips.count
            }
        }
    }
    
    private func saveTrip() {
        guard let trip = selectedTrip else { return }
        destination.trip = trip
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    
    let destination = TravelDestination(
        name: "测试地点",
        country: "测试国家",
        latitude: 39.9042,
        longitude: 116.4074,
        visitDate: Date(),
        notes: "测试笔记",
        category: "domestic",
        isFavorite: false
    )
    container.mainContext.insert(destination)
    
    return SelectOrCreateTripView(destination: destination)
        .modelContainer(container)
}

