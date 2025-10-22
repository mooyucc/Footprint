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
    
    @Bindable var trip: TravelTrip
    @State private var selectedMode = 0 // 0 = 创建新目的地, 1 = 从现有目的地添加
    
    // 创建新目的地的状态
    @State private var name = ""
    @State private var country = ""
    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var category = "国内"
    @State private var isFavorite = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    
    // 从现有目的地添加
    @State private var selectedDestinations = Set<TravelDestination>()
    
    let categories = ["国内", "国外"]
    
    // 过滤出未关联到当前旅程的目的地
    var availableDestinations: [TravelDestination] {
        let tripDestinationIDs = Set(trip.destinations?.map { $0.id } ?? [])
        return allDestinations.filter { !tripDestinationIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 模式选择器
                Picker("模式", selection: $selectedMode) {
                    Text("创建新目的地").tag(0)
                    Text("添加现有目的地").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedMode == 0 {
                    createNewDestinationView
                } else {
                    selectExistingDestinationsView
                }
            }
            .navigationTitle("添加目的地到旅程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveDestinations()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }
    
    private var createNewDestinationView: some View {
        Form {
            Section("基本信息") {
                TextField("地点名称", text: $name)
                
                Picker("分类", selection: $category) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                
                TextField("国家/地区", text: $country)
                
                DatePicker("访问日期", selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                
                Toggle("标记为喜爱", isOn: $isFavorite)
            }
            
            Section("位置搜索") {
                HStack {
                    TextField("搜索地点...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("搜索") {
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
                            Text(item.name ?? "未知地点")
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
                            Text("已选择：\(location.name ?? "")")
                                .font(.caption)
                            Text("纬度: \(location.placemark.coordinate.latitude, specifier: "%.4f"), 经度: \(location.placemark.coordinate.longitude, specifier: "%.4f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section("照片") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("选择照片", systemImage: "photo")
                }
                
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(10)
                }
            }
            
            Section("笔记") {
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
                    
                    Text("没有可添加的目的地")
                        .foregroundColor(.secondary)
                    
                    Text("所有目的地都已在此旅程中")
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
                            if let photoData = destination.photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(destination.category == "国内" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "location.fill")
                                        .foregroundColor(destination.category == "国内" ? .red : .blue)
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
                                        Text(destination.visitDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(destination.visitDate.formatted(date: .omitted, time: .shortened))
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

