//
//  AllDestinationsListView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI
import SwiftData

struct AllDestinationsListView: View {
    @Query(sort: \TravelDestination.visitDate, order: .reverse) private var allDestinations: [TravelDestination]
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var editingDestination: TravelDestination?
    @State private var detailDestination: TravelDestination?
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var filteredDestinations: [TravelDestination] {
        var result = allDestinations
        
        if let category = filterCategory {
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        FootprintFilterChipRow(
                            selection: $filterCategory,
                            options: [
                                (nil, "all".localized),
                                ("domestic", "domestic".localized),
                                ("international", "international".localized)
                            ],
                            accent: brandColorManager.currentBrandColor
                        )
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                                .font(.subheadline)
                            
                            TextField("search_places_countries_notes".localized, text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .footprintCapsuleChrome()
                        
                        if !filteredDestinations.isEmpty {
                            Text("travel_destinations".localized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                                .padding(.top, 4)
                            
                            ForEach(filteredDestinations) { destination in
                                Button {
                                    detailDestination = destination
                                } label: {
                                    DestinationRowCard(destination: destination, highResolutionCover: true)
                                }
                                .buttonStyle(.plain)
                                .cylinderScrollEffect()
                                .contextMenu {
                                    Button {
                                        editingDestination = destination
                                    } label: {
                                        Label("edit".localized, systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        deleteDestination(destination)
                                    } label: {
                                        Label("delete".localized, systemImage: "trash")
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 44))
                                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                                Text("no_destinations_found".localized)
                                    .font(.headline)
                                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .contentMargins(.vertical, 16, for: .scrollContent)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("all_destinations".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $detailDestination) { destination in
                NavigationStack {
                    DestinationDetailView(destination: destination)
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { notification in
                if let userInfo = notification.userInfo,
                   let deletedDestinationId = userInfo["destinationId"] as? UUID {
                    if let editing = editingDestination, editing.id == deletedDestinationId {
                        editingDestination = nil
                    }
                    if let detail = detailDestination, detail.id == deletedDestinationId {
                        detailDestination = nil
                    }
                } else {
                    if editingDestination != nil {
                        editingDestination = nil
                    }
                    if detailDestination != nil {
                        detailDestination = nil
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                refreshID = UUID()
            }
            .id(refreshID)
        }
    }
    
    private func deleteDestination(_ destination: TravelDestination) {
        if let modelContext = destination.modelContext {
            let destinationId = destination.id
            modelContext.delete(destination)
            try? modelContext.save()
            NotificationCenter.default.post(name: .destinationDeleted, object: nil, userInfo: ["destinationId": destinationId])
        }
    }
}

#Preview {
    AllDestinationsListView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
        .environmentObject(BrandColorManager.shared)
}
