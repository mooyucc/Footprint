//
//  EditTripView.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var trip: TravelTrip
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("旅程信息")) {
                    TextField("旅程名称", text: $trip.name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("描述（可选）", text: $trip.desc, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("时间")) {
                    DatePicker("开始日期", selection: $trip.startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $trip.endDate, displayedComponents: .date)
                }
                .onChange(of: trip.startDate) { oldValue, newValue in
                    if newValue > trip.endDate {
                        trip.endDate = newValue
                    }
                }
                
                Section(header: Text("封面图片（可选）")) {
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
                        Label(trip.coverPhotoData == nil ? "添加封面图片" : "更换封面图片", systemImage: "photo.on.rectangle.angled")
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("行程时长：")
                        Text("\(trip.durationDays)天")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.orange)
                        Text("目的地数量：")
                        Text("\(trip.destinationCount)个")
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("编辑旅程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
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

