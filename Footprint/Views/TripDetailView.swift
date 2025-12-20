//
//  TripDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import MapKit

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var trip: TravelTrip
    
    @State private var showingEditSheet = false
    @State private var showingAddDestination = false
    @State private var showingDeleteAlert = false
    @State private var shareItem: TripShareItem?
    @State private var shareFileItem: TripShareItem?
    @State private var showingLayoutSelection = false // 控制版面选择视图显示
    @State private var selectedLayout: TripShareLayout = .list // 默认选择清单版面
    @EnvironmentObject var languageManager: LanguageManager
    
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
                            Label("start".localized, systemImage: "calendar.badge.plus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(trip.startDate.localizedFormatted(dateStyle: .medium))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("end".localized, systemImage: "calendar.badge.minus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(trip.endDate.localizedFormatted(dateStyle: .medium))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("duration".localized, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(trip.durationDays) \("days".localized)")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // 目的地列表
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("trip_route".localized, systemImage: "location.fill")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(sortedDestinations.count) \("locations".localized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if sortedDestinations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "map")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("no_destinations_added".localized)
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    showingAddDestination = true
                                } label: {
                                    Label("add_destination".localized, systemImage: "plus.circle.fill")
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
                                    TripDestinationRow(
                                        destination: destination,
                                        index: index + 1,
                                        nextDestination: index < sortedDestinations.count - 1 ? sortedDestinations[index + 1] : nil
                                    )
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
                    // 分享线路
                    Button {
                        shareTrip()
                    } label: {
                        Label("share_trip".localized, systemImage: "square.and.arrow.up")
                    }
                    
                    // 分享给朋友
                    Button {
                        shareTripToTeam()
                    } label: {
                        Label("share_to_team".localized, systemImage: "person.2.fill")
                    }
                    
                    Divider()
                    
                    // 编辑线路
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("edit_trip".localized, systemImage: "pencil")
                    }
                    
                    // 添加目的地
                    Button {
                        showingAddDestination = true
                    } label: {
                        Label("add_destination".localized, systemImage: "plus")
                    }
                    
                    Divider()
                    
                    // 删除线路
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("delete_trip".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
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
        .sheet(isPresented: $showingLayoutSelection) {
            TripShareLayoutSelectionView(trip: trip, selectedLayout: $selectedLayout)
        }
        .alert("delete_trip".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                deleteTrip()
            }
        } message: {
            Text("confirm_delete_trip".localized)
        }
    }
    
    private func deleteTrip() {
        modelContext.delete(trip)
        dismiss()
    }
    
    private func shareTrip() {
        // 显示版面选择视图
        showingLayoutSelection = true
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
    let nextDestination: TravelDestination?
    
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    // 计算到下一个地点的距离
    private var distanceToNext: CLLocationDistance? {
        guard let next = nextDestination else { return nil }
        return RouteManager.calculateDistance(from: destination.coordinate, to: next.coordinate)
    }
    
    // 获取交通方式
    private var transportType: MKDirectionsTransportType {
        guard let next = nextDestination else { return .automobile }
        return routeManager.getUserTransportType(from: destination.coordinate, to: next.coordinate) ?? .automobile
    }
    
    // 格式化距离
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
    
    // 获取交通方式图标名称
    private var transportIconName: String {
        transportType.iconName
    }
    
    // 获取交通方式颜色
    private var transportColor: Color {
        if transportType == RouteManager.airplane {
            return .orange
        } else if transportType.contains(.walking) && transportType == .walking {
            return .green
        } else if transportType.contains(.automobile) && transportType == .automobile {
            return .blue
        } else if transportType.contains(.transit) && transportType == .transit {
            return .purple
        } else {
            return .gray
        }
    }
    
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
            if let photoData = destination.photoThumbnailData ?? destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image("ImageMooyu")
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)  // 高质量插值，确保边缘光滑
                    .antialiased(true)     // 启用抗锯齿
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                
                // 显示到下一个地点的距离和交通方式
                if let distance = distanceToNext {
                    HStack(spacing: 4) {
                        Image(systemName: transportIconName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(transportColor)
                            .frame(width: 14, height: 14)
                        
                        Text(formatDistance(distance))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
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

