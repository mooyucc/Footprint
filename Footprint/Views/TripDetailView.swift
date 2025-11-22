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
    @StateObject private var routeManager = RouteManager.shared
    @State private var routeDistances: [UUID: CLLocationDistance] = [:]
    @State private var showingMenu = false // 控制浮动菜单显示
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
                    
                    // 线路地图示意图
                    if !sortedDestinations.isEmpty && sortedDestinations.count >= 2 {
                        TripRouteMapView(destinations: sortedDestinations, height: 300)
                    }
                    
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
                                VStack(spacing: 0) {
                                    NavigationLink {
                                        DestinationDetailView(destination: destination)
                                    } label: {
                                        TripDestinationRow(destination: destination, index: index + 1)
                                    }
                                    
                                    // 显示到下一个地点的距离
                                    if index < sortedDestinations.count - 1 {
                                        let nextDestination = sortedDestinations[index + 1]
                                        if let distance = routeDistances[destination.id] {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary.opacity(0.6))
                                                Text(formatDistance(distance))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text("→")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary.opacity(0.6))
                                                Text(nextDestination.name)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                            }
                                            .padding(.leading, 96) // 与内容对齐
                                            .padding(.top, 4)
                                            .padding(.bottom, 8)
                                        }
                                    }
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
        .overlay {
            // 点击外部区域关闭菜单（先添加，在底层）
            if showingMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingMenu = false
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            // 浮动菜单按钮和菜单（后添加，在上层，确保可点击）
            VStack(alignment: .trailing, spacing: 0) {
                // 菜单按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingMenu.toggle()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
                
                // 浮动菜单
                if showingMenu {
                    floatingMenu
                        .transition(.scale.combined(with: .opacity))
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
        .onAppear {
            calculateRouteDistances()
        }
        .onChange(of: sortedDestinations.count) { _, _ in
            calculateRouteDistances()
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
    
    /// 计算所有地点之间的距离
    private func calculateRouteDistances() {
        guard sortedDestinations.count >= 2 else {
            routeDistances = [:]
            return
        }
        
        routeDistances = [:]
        
        Task {
            for i in 0..<sortedDestinations.count - 1 {
                let source = sortedDestinations[i]
                let destination = sortedDestinations[i + 1]
                
                await withCheckedContinuation { continuation in
                    routeManager.calculateRoute(from: source.coordinate, to: destination.coordinate) { route in
                        if let route = route {
                            Task { @MainActor in
                                routeDistances[source.id] = route.footprintDistance
                            }
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    /// 格式化距离
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
    
    // 浮动菜单
    private var floatingMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 分享线路
            Button {
                showingMenu = false
                shareTrip()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    Text("share_trip".localized)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .padding(.horizontal, 8)
            
            // 分享给朋友
            Button {
                showingMenu = false
                shareTripToTeam()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    Text("share_to_team".localized)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .padding(.horizontal, 8)
            
            // 编辑线路
            Button {
                showingMenu = false
                showingEditSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    Text("edit_trip".localized)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            // 添加目的地
            Button {
                showingMenu = false
                showingAddDestination = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    Text("add_destination".localized)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .padding(.horizontal, 8)
            
            // 删除线路
            Button(role: .destructive) {
                showingMenu = false
                showingDeleteAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("delete_trip".localized)
                        .font(.body)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .padding(.top, 8)
        .padding(.trailing, 16)
        .frame(width: 200)
        .allowsHitTesting(true)
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

