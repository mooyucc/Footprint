//
//  FootprintView.swift
//  Footprint
//
//  合并"足迹"(目的地) 与 "线路"(旅程) 的统一页面
//

import SwiftUI
import SwiftData

struct FootprintView: View {
    enum Segment: String, CaseIterable {
        case destinations
        case trips
        
        var title: String {
            switch self {
            case .destinations: return "my_footprints".localized
            case .trips: return "my_trips".localized
            }
        }
        
        var icon: String {
            switch self {
            case .destinations: return "location.fill"
            case .trips: return "suitcase.fill"
            }
        }
    }
    
    @State private var selectedSegment: Segment = .trips
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var showingAddDestination = false
    @State private var showingAddTrip = false
    @State private var showingFilePicker = false
    @State private var editingDestination: TravelDestination?
    @State private var shareTripItem: TripShareItem?
    @State private var selectedURL: URL?
    @State private var importResult: ImportResult?
    @State private var showingImportResult = false
    @State private var refreshID = UUID()
    @StateObject private var countryManager = CountryManager.shared
    
    @Query(sort: \TravelDestination.visitDate, order: .reverse) private var destinations: [TravelDestination]
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
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
    
    private var filteredTrips: [TravelTrip] {
        if searchText.isEmpty { return trips }
        return trips.filter { t in
            t.name.localizedCaseInsensitiveContains(searchText) ||
            t.desc.localizedCaseInsensitiveContains(searchText)
        }
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
                    Picker("segment", selection: $selectedSegment) {
                        ForEach(Segment.allCases, id: \.self) { seg in
                            Label(seg.title, systemImage: seg.icon).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if selectedSegment == .destinations {
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
                } else {
                    Section {
                        TripStatisticsCard(trips: trips)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    
                    Section {
                        ForEach(filteredTrips) { trip in
                            NavigationLink { TripDetailView(trip: trip) } label: { TripRow(trip: trip) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button { shareTrip(trip) } label: { Label("share".localized, systemImage: "square.and.arrow.up") }.tint(.blue)
                                }
                        }
                        .onDelete { offsets in
                            for index in offsets { if let ctx = filteredTrips[index].modelContext { ctx.delete(filteredTrips[index]) } }
                        }
                    }
                }
            }
            .navigationTitle("my_footprints".localized)
            .searchable(text: $searchText, prompt: selectedSegment == .destinations ? "search_places_countries_notes".localized : "search_trips".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSegment == .destinations {
                        Button { showingAddDestination = true } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                    } else {
                        Menu {
                            Button { showingAddTrip = true } label: { Label("create_trip".localized, systemImage: "plus.circle.fill") }
                            Button { showingFilePicker = true } label: { Label("import_trip".localized, systemImage: "square.and.arrow.down") }
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddDestination) { AddDestinationView() }
            .sheet(isPresented: $showingAddTrip) { AddTripView() }
            .sheet(isPresented: $showingFilePicker) { DocumentPicker(selectedURL: $selectedURL) }
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .sheet(item: $shareTripItem) { item in
                if let image = item.image { SystemShareSheet(items: [image]) } else { SystemShareSheet(items: [item.text]) }
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
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            .onChange(of: selectedURL) { oldValue, newValue in
                if let url = newValue { importTripFromURL(url) }
            }
            .id(refreshID)
        }
    }
    
    private func shareTrip(_ trip: TravelTrip) {
        let image = TripImageGenerator.generateTripImage(from: trip)
        shareTripItem = TripShareItem(text: "", image: image)
    }
    
    private func importTripFromURL(_ url: URL) {
        importResult = TripDataImporter.importTrip(from: url, modelContext: modelContext)
        showingImportResult = true
        selectedURL = nil
    }
}

#Preview {
    FootprintView()
        .modelContainer(for: [TravelDestination.self, TravelTrip.self], inMemory: true)
}


