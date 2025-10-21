//
//  DestinationDetailView.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
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

struct ShareSheet: View {
    let destination: TravelDestination
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 预览卡片
                ShareCardPreview(destination: destination)
                    .padding()
                
                // 分享选项
                VStack(spacing: 12) {
                    ShareButton(
                        title: "生成分享图片",
                        icon: "photo",
                        color: .blue
                    ) {
                        shareAsImage()
                    }
                    
                    ShareButton(
                        title: "分享文字",
                        icon: "text.quote",
                        color: .green
                    ) {
                        shareAsText()
                    }
                    
                    ShareButton(
                        title: "分享到社交媒体",
                        icon: "square.and.arrow.up",
                        color: .orange
                    ) {
                        shareToSocial()
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("分享旅程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareAsImage() {
        // TODO: 生成分享图片
        let renderer = ImageRenderer(content: ShareCardPreview(destination: destination))
        if let image = renderer.uiImage {
            let activityVC = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    private func shareAsText() {
        let text = """
        📍 \(destination.name)
        🌍 \(destination.country)
        📅 \(destination.visitDate.formatted(date: .long, time: .omitted))
        ⏰ \(destination.visitDate.formatted(date: .omitted, time: .shortened))
        
        \(destination.notes)
        
        #旅行足迹 #\(destination.country)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func shareToSocial() {
        shareAsImage()
    }
}

struct ShareCardPreview: View {
    let destination: TravelDestination
    
    var body: some View {
        VStack(spacing: 0) {
            // 照片或渐变背景
            ZStack(alignment: .bottomLeading) {
                if let photoData = destination.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 250)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: destination.category == "国内" ? 
                            [Color.red, Color.orange] : 
                            [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 250)
                }
                
                // 叠加信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(destination.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if destination.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(destination.country)
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destination.visitDate.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                        Text(destination.visitDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            // 底部信息
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(destination.category == "国内" ? .red : .blue)
                Text("来自 Footprint 旅行足迹")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color(.systemBackground))
        }
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

struct ShareButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding()
            .background(color)
            .cornerRadius(15)
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

