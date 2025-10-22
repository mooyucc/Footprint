//
//  DestinationDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import MapKit

struct DestinationDetailView: View {
    let destination: TravelDestination
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var cameraPosition: MapCameraPosition
    
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
                    // 照片
                    let imageHeight = geometry.size.width * 2 / 3
                    
                    if let photoData = destination.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width)
                            .frame(height: imageHeight)
                            .clipped()
                            .cornerRadius(15)
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(destination.category == "国内" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                .frame(width: geometry.size.width)
                                .frame(height: imageHeight)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("暂无照片")
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
                        
                        Text(destination.category)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(destination.category == "国内" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                            .foregroundColor(destination.category == "国内" ? .red : .blue)
                            .cornerRadius(10)
                    }
                    
                    // 访问日期
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(destination.visitDate.formatted(date: .complete, time: .omitted))
                                .font(.headline)
                            Text(destination.visitDate.formatted(date: .omitted, time: .shortened))
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
                                    Text("所属旅程")
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
                            Text("位置坐标")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("纬度: \(destination.latitude, specifier: "%.6f")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text("经度: \(destination.longitude, specifier: "%.6f")")
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
                                    .fill(destination.category == "国内" ? Color.red : Color.blue)
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
                                Text("旅行笔记")
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
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditDestinationView(destination: destination)
            }
        }
    }
}


#Preview {
    NavigationStack {
        DestinationDetailView(destination: TravelDestination(
            name: "雷克雅未克",
            country: "冰岛",
            latitude: 64.1466,
            longitude: -21.9426,
            visitDate: Date(),
            notes: "美丽的北极光和温泉体验",
            category: "国外",
            isFavorite: true
        ))
    }
}

