//
//  EditTripView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var trip: TravelTrip
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImagePicker = false
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("trip_info".localized)) {
                    TextField("trip_name".localized, text: $trip.name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("description_optional".localized, text: $trip.desc, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("time".localized)) {
                    DatePicker("start_date".localized, selection: $trip.startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
                    DatePicker("end_date".localized, selection: $trip.endDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
                }
                .onChange(of: trip.startDate) { oldValue, newValue in
                    if newValue > trip.endDate {
                        trip.endDate = newValue
                    }
                }
                
                Section(header: Text("cover_image_optional".localized)) {
                    if let photoData = trip.coverPhotoData,
                       let uiImage = UIImage(data: photoData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Button {
                                trip.coverPhotoData = nil
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(8)
                        }
                    }
                    
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label(trip.coverPhotoData == nil ? "add_cover_image".localized : "change_cover_image".localized, systemImage: "photo.on.rectangle.angled")
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("trip_duration".localized + ":")
                        Text("\(trip.durationDays) \("days".localized)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.orange)
                        Text("destination_count".localized + ":")
                        Text("\(trip.destinationCount) \("locations".localized)")
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("edit_trip".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: $selectedPhoto,
                matching: .images
            )
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        trip.coverPhotoData = data
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self,
        configurations: config
    )
    
    let trip = TravelTrip(
        name: "2025年10月青甘大环线",
        desc: "穿越青海甘肃的美丽风光",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7)
    )
    container.mainContext.insert(trip)
    
    return EditTripView(trip: trip)
        .modelContainer(container)
}

