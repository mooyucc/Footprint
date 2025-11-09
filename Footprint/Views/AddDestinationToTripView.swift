//
//  AddDestinationToTripView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI
import MapKit

struct AddDestinationToTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allDestinations: [TravelDestination]
    @StateObject private var languageManager = LanguageManager.shared
    
    @Bindable var trip: TravelTrip
    @State private var selectedMode = 0 // 0 = 创建新目的地, 1 = 从现有目的地添加
    
    // 创建新目的地的状态
    @State private var name = ""
    @State private var country = ""
    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var category = "domestic"
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoThumbnailData: Data?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    
    // 从现有目的地添加
    @State private var selectedDestinations = Set<TravelDestination>()
    
    let categories = ["domestic", "international"]
    
    // 过滤出未关联到当前旅程的目的地
    var availableDestinations: [TravelDestination] {
        let tripDestinationIDs = Set(trip.destinations?.map { $0.id } ?? [])
        return allDestinations.filter { !tripDestinationIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 模式选择器
                Picker(NSLocalizedString("mode", comment: ""), selection: $selectedMode) {
                    Text(NSLocalizedString("create_new_destination", comment: "")).tag(0)
                    Text(NSLocalizedString("add_existing_destination", comment: "")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedMode == 0 {
                    createNewDestinationView
                } else {
                    selectExistingDestinationsView
                }
            }
            .navigationTitle(NSLocalizedString("add_destination_to_trip", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "")) {
                        saveDestinations()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        let processed = ImageProcessor.process(data: data)
                        photoData = processed.0
                        photoThumbnailData = processed.1
                    }
                }
            }
        }
    }
    
    private var createNewDestinationView: some View {
        Form {
            Section(NSLocalizedString("basic_info", comment: "")) {
                TextField(NSLocalizedString("place_name", comment: ""), text: $name)
                
                Picker(NSLocalizedString("category", comment: ""), selection: $category) {
                    ForEach(categories, id: \.self) { category in
                        Text(NSLocalizedString(category, comment: "")).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                
                TextField(NSLocalizedString("country_region", comment: ""), text: $country)
                
                DatePicker(NSLocalizedString("visit_date", comment: ""), selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
                
                Toggle(NSLocalizedString("mark_as_favorite", comment: ""), isOn: $isFavorite)
            }
            
            Section(NSLocalizedString("location_search", comment: "")) {
                HStack {
                    TextField(NSLocalizedString("search_place", comment: ""), text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(NSLocalizedString("search", comment: "")) {
                        searchLocation()
                    }
                    .disabled(searchText.isEmpty)
                }
                
                if isSearching {
                    ProgressView()
                }
                
                ForEach(searchResults, id: \.self) { item in
                    Button {
                        selectLocation(item)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name ?? NSLocalizedString("unknown_place", comment: ""))
                                .foregroundColor(.primary)
                            if let address = item.placemark.title {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if let location = selectedLocation {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("\(NSLocalizedString("selected", comment: ""))\(location.name ?? "")")
                                .font(.caption)
                            Text(String(format: NSLocalizedString("latitude_longitude", comment: ""), location.placemark.coordinate.latitude, location.placemark.coordinate.longitude))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section(NSLocalizedString("photo", comment: "")) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(NSLocalizedString("select_photo", comment: ""), systemImage: "photo")
                }
                
                if let photoData = photoThumbnailData ?? photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(10)
                }
            }
            
            Section(NSLocalizedString("notes", comment: "")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
        }
    }
    
    private var selectExistingDestinationsView: some View {
        List {
            if availableDestinations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(NSLocalizedString("no_destinations_to_add", comment: ""))
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("all_destinations_in_trip", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(availableDestinations) { destination in
                    Button {
                        toggleDestinationSelection(destination)
                    } label: {
                        HStack(spacing: 12) {
                            // 选择状态
                            Image(systemName: selectedDestinations.contains(destination) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedDestinations.contains(destination) ? .blue : .gray)
                                .font(.title3)
                            
                            // 照片或图标
                            if let photoData = destination.photoThumbnailData ?? destination.photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(destination.normalizedCategory == "domestic" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "location.fill")
                                        .foregroundColor(destination.normalizedCategory == "domestic" ? .red : .blue)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(destination.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text(destination.country)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(destination.visitDate.localizedFormatted(dateStyle: .medium))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(destination.visitDate.localizedFormatted(dateStyle: .none, timeStyle: .short))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    private var isValid: Bool {
        if selectedMode == 0 {
            return !name.isEmpty && !country.isEmpty && selectedLocation != nil
        } else {
            return !selectedDestinations.isEmpty
        }
    }
    
    private func toggleDestinationSelection(_ destination: TravelDestination) {
        if selectedDestinations.contains(destination) {
            selectedDestinations.remove(destination)
        } else {
            selectedDestinations.insert(destination)
        }
    }
    
    private func searchLocation() {
        isSearching = true
        searchResults = []
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            isSearching = false
            
            if let response = response {
                searchResults = response.mapItems
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedLocation = item
        if name.isEmpty {
            name = item.name ?? ""
        }
        if country.isEmpty {
            country = item.placemark.country ?? ""
        }
        searchResults = []
        searchText = ""
    }
    
    private func saveDestinations() {
        if selectedMode == 0 {
            // 创建新目的地并添加到旅程
            guard let location = selectedLocation else { return }
            
            let destination = TravelDestination(
                name: name,
                country: country,
                latitude: location.placemark.coordinate.latitude,
                longitude: location.placemark.coordinate.longitude,
                visitDate: visitDate,
                notes: notes,
                photoData: photoData,
                photoDatas: photoData.map { [$0] } ?? [],
                photoThumbnailData: photoThumbnailData,
                photoThumbnailDatas: photoThumbnailData.map { [$0] } ?? [],
                category: category,
                isFavorite: isFavorite
            )
            
            destination.trip = trip
            modelContext.insert(destination)
        } else {
            // 将现有目的地添加到旅程
            for destination in selectedDestinations {
                destination.trip = trip
            }
        }
        
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    
    let trip = TravelTrip(
        name: "2025年10月青甘大环线",
        desc: "穿越青海甘肃的美丽风光",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7)
    )
    container.mainContext.insert(trip)
    
    return AddDestinationToTripView(trip: trip)
        .modelContainer(container)
}

