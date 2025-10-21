//
//  AddTripView.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("旅程信息")) {
                    TextField("旅程名称", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("描述（可选）", text: $desc, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("时间")) {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                }
                .onChange(of: startDate) { oldValue, newValue in
                    if newValue > endDate {
                        endDate = newValue
                    }
                }
                
                Section(header: Text("封面图片（可选）")) {
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
                        Label(coverPhotoData == nil ? "添加封面图片" : "更换封面图片", systemImage: "photo.on.rectangle.angled")
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("行程时长：")
                        Text("\(durationDays)天")
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("创建旅程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
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
        dismiss()
    }
}

#Preview {
    AddTripView()
        .modelContainer(for: TravelTrip.self, inMemory: true)
}

