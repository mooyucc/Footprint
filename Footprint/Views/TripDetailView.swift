//
//  TripDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var trip: TravelTrip
    
    @State private var showingEditSheet = false
    @State private var showingAddDestination = false
    @State private var showingDeleteAlert = false
    @State private var shareItem: TripShareItem?
    @State private var shareFileItem: TripShareItem?
    
    var sortedDestinations: [TravelDestination] {
        trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let coverHeight = screenWidth * 2 / 3
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 封面图片
                    if let photoData = trip.coverPhotoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: screenWidth, height: coverHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 0))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: screenWidth, height: coverHeight)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(trip.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                
                VStack(alignment: .leading, spacing: 16) {
                    // 旅程标题
                    Text(trip.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // 描述
                    if !trip.desc.isEmpty {
                        Text(trip.desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // 时间信息卡片
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("开始", systemImage: "calendar.badge.plus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(trip.startDate, style: .date)
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("结束", systemImage: "calendar.badge.minus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(trip.endDate, style: .date)
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("时长", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(trip.durationDays) 天")
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // 目的地列表
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("行程路线", systemImage: "location.fill")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(sortedDestinations.count) 个地点")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if sortedDestinations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "map")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("还没有添加目的地")
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    showingAddDestination = true
                                } label: {
                                    Label("添加目的地", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            ForEach(Array(sortedDestinations.enumerated()), id: \.element.id) { index, destination in
                                NavigationLink {
                                    DestinationDetailView(destination: destination)
                                } label: {
                                    TripDestinationRow(destination: destination, index: index + 1)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        shareTrip()
                    } label: {
                        Label("分享旅程", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        shareTripToTeam()
                    } label: {
                        Label("分享给队友", systemImage: "person.2.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("编辑旅程", systemImage: "pencil")
                    }
                    
                    Button {
                        showingAddDestination = true
                    } label: {
                        Label("添加目的地", systemImage: "plus")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("删除旅程", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTripView(trip: trip)
        }
        .sheet(isPresented: $showingAddDestination) {
            AddDestinationToTripView(trip: trip)
        }
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                // 只分享图片，不分享文字
                SystemShareSheet(items: [image])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .sheet(item: $shareFileItem) { item in
            if let url = item.url {
                SystemShareSheet(items: [url])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .alert("删除旅程", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteTrip()
            }
        } message: {
            Text("确定要删除这个旅程吗？关联的目的地不会被删除。")
        }
    }
    
    private func deleteTrip() {
        modelContext.delete(trip)
        dismiss()
    }
    
    private func shareTrip() {
        // 生成旅程图片
        let tripImage = TripImageGenerator.generateTripImage(from: trip)
        
        // 只分享图片，不分享文字（因为所有信息都已经包含在图片中）
        shareItem = TripShareItem(text: "", image: tripImage)
    }
    
    private func shareTripToTeam() {
        // 导出旅程数据为JSON文件
        guard let fileURL = TripDataExporter.exportTrip(trip) else {
            // 导出失败，显示错误提示
            return
        }
        
        // 生成分享文本
        let shareText = TripDataExporter.generateShareText(for: trip)
        
        // 创建分享项
        shareFileItem = TripShareItem(text: shareText, image: nil, url: fileURL)
    }
}

struct TripDestinationRow: View {
    let destination: TravelDestination
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 序号
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text("\(index)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
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
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
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
        
        return TripDetailView(trip: trip)
            .modelContainer(container)
    }
}

