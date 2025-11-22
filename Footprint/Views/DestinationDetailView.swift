//
//  DestinationDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import MapKit
import SwiftData

struct DestinationDetailView: View {
    let destination: TravelDestination
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditSheet = false
    @State private var shareItem: TripShareItem?
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedPhotoIndex: Int = 0
    @State private var photosLocal: [Data] = []
    
    init(destination: TravelDestination) {
        self.destination = destination
        _cameraPosition = State(initialValue: .camera(
            MapCamera(
                centerCoordinate: destination.coordinate,
                distance: 10000,
                heading: 0,
                pitch: 0
            )
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 照片与缩略图
                    let imageHeight = geometry.size.width * 2 / 3
                    let allPhotos: [Data] = photosLocal
                    
                    if !allPhotos.isEmpty, let mainImage = UIImage(data: allPhotos[min(selectedPhotoIndex, allPhotos.count - 1)]) {
                        VStack(spacing: 10) {
                            Image(uiImage: mainImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width)
                                .frame(height: imageHeight)
                                .clipped()
                                .cornerRadius(15)
                            
                            if allPhotos.count > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(allPhotos.enumerated()), id: \.offset) { index, data in
                                            if let thumb = UIImage(data: data) {
                                                Image(uiImage: thumb)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 70, height: 70)
                                                    .clipped()
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(index == selectedPhotoIndex ? Color.accentColor : Color.clear, lineWidth: 2)
                                                    )
                                                    .cornerRadius(8)
                                                    .onTapGesture { selectedPhotoIndex = index }
                                                    // 详情页不支持排序，仅支持选择预览
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(destination.normalizedCategory == "domestic" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                .frame(width: geometry.size.width)
                                .frame(height: imageHeight)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("no_photo".localized)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .cornerRadius(15)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                    // 标题和标签
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(destination.name)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                if destination.isFavorite {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                }
                            }
                            
                            Text(destination.country)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(destination.localizedCategory)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(destination.normalizedCategory == "domestic" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                            .foregroundColor(destination.normalizedCategory == "domestic" ? .red : .blue)
                            .cornerRadius(10)
                    }
                    
                    // 访问日期
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(destination.visitDate.localizedFormatted(dateStyle: .full))
                                .font(.headline)
                            Text(destination.visitDate.localizedFormatted(dateStyle: .none, timeStyle: .short))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                    
                    // 所属旅程
                    if let trip = destination.trip {
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            HStack {
                                Image(systemName: "suitcase.fill")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("belongs_to_trip".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(trip.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                    
                    // 坐标信息
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.red)
                            Text("location_coordinates".localized)
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\("latitude".localized): \(destination.latitude, specifier: "%.6f")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text("\("longitude".localized): \(destination.longitude, specifier: "%.6f")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    
                    // 地图
                    Map(position: $cameraPosition) {
                        Annotation(destination.name, coordinate: destination.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(destination.normalizedCategory == "domestic" ? Color.red : Color.blue)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                            }
                        }
                    }
                    .frame(height: 250)
                    .cornerRadius(15)
                    .allowsHitTesting(true)
                    
                    // 笔记
                    if !destination.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.orange)
                                Text("travel_notes".localized)
                                    .font(.headline)
                            }
                            
                            Text(destination.notes)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            shareDestination()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                        
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditDestinationView(destination: destination)
            }
            .sheet(item: $shareItem) { item in
                if let image = item.image {
                    // 只分享图片，不分享文字（因为所有信息都已经包含在图片中）
                    SystemShareSheet(items: [image])
                } else {
                    SystemShareSheet(items: [item.text])
                }
            }
            .onAppear {
                photosLocal = !destination.photoDatas.isEmpty ? destination.photoDatas : (destination.photoData.map { [$0] } ?? [])
            }
            .onChange(of: destination.photoDatas) { _, newValue in
                if !newValue.isEmpty { photosLocal = newValue }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // 语言变化时刷新界面
            }
        }
    }
    
    // 分享地点图片
    private func shareDestination() {
        // 生成地点分享图片
        let destinationImage = TripImageGenerator.generateDestinationImage(from: destination)
        // 只分享图片，不分享文字（因为所有信息都已经包含在图片中）
        shareItem = TripShareItem(text: "", image: destinationImage)
    }
}

// 详情页已移除拖拽排序能力，排序请前往编辑页处理


#Preview {
    NavigationStack {
        DestinationDetailView(destination: TravelDestination(
            name: "雷克雅未克",
            country: "冰岛",
            latitude: 64.1466,
            longitude: -21.9426,
            visitDate: Date(),
            notes: "美丽的北极光和温泉体验",
            category: "international",
            isFavorite: true
        ))
    }
}

