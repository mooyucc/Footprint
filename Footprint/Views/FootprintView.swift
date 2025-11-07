//
//  FootprintView.swift
//  Footprint
//
//  我的足迹页面
//

import SwiftUI
import SwiftData

struct FootprintView: View {
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var showingAddDestination = false
    @State private var editingDestination: TravelDestination?
    @State private var refreshID = UUID()
    @StateObject private var countryManager = CountryManager.shared
    
    @Query(sort: \TravelDestination.visitDate, order: .reverse) private var destinations: [TravelDestination]
    @Environment(\.modelContext) private var modelContext
    
    private var filteredDestinations: [TravelDestination] {
        var result = destinations
        if let category = filterCategory {
            result = result.filter { destination in
                let isDomestic = countryManager.isDomestic(country: destination.country)
                return category == "domestic" ? isDomestic : !isDomestic
            }
        }
        if !searchText.isEmpty {
            result = result.filter { d in
                d.name.localizedCaseInsensitiveContains(searchText) ||
                d.country.localizedCaseInsensitiveContains(searchText) ||
                d.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }
    
    private var destinationStats: (total: Int, domestic: Int, international: Int, countries: Int) {
        let total = destinations.count
        let domestic = destinations.filter { countryManager.isDomestic(country: $0.country) }.count
        let international = destinations.filter { !countryManager.isDomestic(country: $0.country) }.count
        let countries = Set(destinations.map { $0.country }).count
        return (total, domestic, international, countries)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatisticsCard(statistics: destinationStats)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                Section {
                    Picker("filter".localized, selection: $filterCategory) {
                        Text("all".localized).tag(nil as String?)
                        Text("domestic".localized).tag("domestic" as String?)
                        Text("international".localized).tag("international" as String?)
                    }
                    .pickerStyle(.segmented)
                }
                
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
                            }.tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let ctx = destination.modelContext { ctx.delete(destination) }
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { if let ctx = filteredDestinations[index].modelContext { ctx.delete(filteredDestinations[index]) } }
                    }
                }
            }
            .navigationTitle("my_footprints".localized)
            .searchable(text: $searchText, prompt: "search_places_countries_notes".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddDestination = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddDestination) { AddDestinationView() }
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            .id(refreshID)
        }
    }
}

#Preview {
    FootprintView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
}


