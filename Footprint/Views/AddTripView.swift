//
//  AddTripView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var desc = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverPhotoData: Data?
    @State private var showingImagePicker = false
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("trip_info".localized)) {
                    TextField("trip_name".localized, text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("description_optional".localized, text: $desc, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("time".localized)) {
                    DatePicker("start_date".localized, selection: $startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
                    DatePicker("end_date".localized, selection: $endDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
                }
                .onChange(of: startDate) { oldValue, newValue in
                    if newValue > endDate {
                        endDate = newValue
                    }
                }
                
                Section(header: Text("cover_image_optional".localized)) {
                    if let photoData = coverPhotoData,
                       let uiImage = UIImage(data: photoData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Button {
                                coverPhotoData = nil
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
                        Label(coverPhotoData == nil ? "add_cover_image".localized : "change_cover_image".localized, systemImage: "photo.on.rectangle.angled")
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("trip_duration".localized + ":")
                        Text("\(durationDays) \("days".localized)")
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("create_trip".localized)
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
                    .disabled(name.isEmpty)
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
                        coverPhotoData = data
                    }
                }
            }
        }
    }
    
    private var durationDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return max((components.day ?? 0) + 1, 1)
    }
    
    private func saveTrip() {
        let newTrip = TravelTrip(
            name: name,
            desc: desc,
            startDate: startDate,
            endDate: endDate,
            coverPhotoData: coverPhotoData
        )
        
        modelContext.insert(newTrip)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddTripView()
        .modelContainer(for: TravelTrip.self, inMemory: true)
}

