//
//  TripRouteMapView.swift
//  Footprint
//
//  Created by K.X on 2025/01/XX.
//

import SwiftUI
import SwiftData
import MapKit

/// 线路详情地图视图：显示旅程路线示意图，包括地点标记、路线连接和距离
struct TripRouteMapView: View {
    let destinations: [TravelDestination]
    let height: CGFloat
    
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var routes: [MKRoute] = []
    @State private var isLoadingRoutes = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var sortedDestinations: [TravelDestination] {
        destinations.sorted { $0.visitDate < $1.visitDate }
    }
    
    // 计算总路线距离
    var totalDistance: CLLocationDistance {
        routes.reduce(0) { $0 + $1.distance }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题和总距离
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.primary)
                    Text("route_map".localized)
                        .font(.headline)
                    Spacer()
                }
                
                // 总距离显示
                if !routes.isEmpty && totalDistance > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "road.lanes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDistance(totalDistance))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 地图
            Map(position: $cameraPosition) {
                // 显示地点标记
                ForEach(Array(sortedDestinations.enumerated()), id: \.element.id) { index, destination in
                    Annotation(destination.name, coordinate: destination.coordinate) {
                        ZStack {
                            // 起点标记为红色，其他为蓝色
                            if index == 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(radius: 3)
                            } else {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                
                // 显示路线
                if !routes.isEmpty {
                    ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                        // 路线
                        MapPolyline(route.polyline)
                            .stroke(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        
                        // 距离标注
                        if let midpoint = midpointOfPolyline(route.polyline) {
                            Annotation("", coordinate: midpoint) {
                                RouteDistanceLabel(distance: route.distance)
                            }
                        }
                    }
                } else if !isLoadingRoutes && sortedDestinations.count >= 2 {
                    // 如果没有计算好的路线，显示直线作为占位
                    ForEach(Array(sortedDestinations.enumerated()), id: \.offset) { index, _ in
                        if index < sortedDestinations.count - 1 {
                            let source = sortedDestinations[index]
                            let destination = sortedDestinations[index + 1]
                            
                            MapPolyline(coordinates: [source.coordinate, destination.coordinate])
                                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 5]))
                            
                            // 计算直线距离作为占位
                            let distance = source.coordinate.distance(to: destination.coordinate)
                            if let midpoint = midpointOfLine(from: source.coordinate, to: destination.coordinate) {
                                Annotation("", coordinate: midpoint) {
                                    RouteDistanceLabel(distance: distance)
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .frame(height: height)
            .cornerRadius(12)
            .overlay(
                Group {
                    if isLoadingRoutes {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            )
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            calculateRoutes()
            adjustCameraPosition()
        }
        .onChange(of: destinations.count) { _, _ in
            calculateRoutes()
            adjustCameraPosition()
        }
    }
    
    /// 计算所有路线
    private func calculateRoutes() {
        guard sortedDestinations.count >= 2 else {
            routes = []
            return
        }
        
        isLoadingRoutes = true
        
        let coordinates = sortedDestinations.map { $0.coordinate }
        
        Task {
            var calculatedRoutes: [MKRoute] = []
            
            // 计算每两个连续地点之间的路线
            for i in 0..<coordinates.count - 1 {
                let source = coordinates[i]
                let destination = coordinates[i + 1]
                
                await withCheckedContinuation { continuation in
                    routeManager.calculateRoute(from: source, to: destination) { route in
                        if let route = route {
                            calculatedRoutes.append(route)
                        }
                        continuation.resume()
                    }
                }
            }
            
            await MainActor.run {
                routes = calculatedRoutes
                isLoadingRoutes = false
            }
        }
    }
    
    /// 调整地图相机位置，使其包含所有地点
    private func adjustCameraPosition() {
        guard !sortedDestinations.isEmpty else { return }
        
        let coordinates = sortedDestinations.map { $0.coordinate }
        
        // 计算边界
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        // 计算中心点
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // 计算跨度，添加一些边距
        let latSpan = max((maxLat - minLat) * 1.5, 0.01) // 至少0.01度
        let lonSpan = max((maxLon - minLon) * 1.5, 0.01)
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(region)
        }
    }
    
    /// 计算路线多边形的中点坐标
    private func midpointOfPolyline(_ polyline: MKPolyline) -> CLLocationCoordinate2D? {
        let pointCount = polyline.pointCount
        guard pointCount > 0 else { return nil }
        
        let points = polyline.points()
        let middleIndex = pointCount / 2
        let middlePoint = points[middleIndex]
        
        return CLLocationCoordinate2D(
            latitude: middlePoint.coordinate.latitude,
            longitude: middlePoint.coordinate.longitude
        )
    }
    
    /// 计算两点连线的中点
    private func midpointOfLine(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        return CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
    }
    
    /// 格式化距离
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        return formatter.string(fromDistance: distance)
    }
}


#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    
    let trip = TravelTrip(
        name: "测试线路",
        desc: "测试描述",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7)
    )
    
    let dest1 = TravelDestination(
        name: "北京",
        country: "中国",
        latitude: 39.9042,
        longitude: 116.4074,
        visitDate: Date()
    )
    
    let dest2 = TravelDestination(
        name: "上海",
        country: "中国",
        latitude: 31.2304,
        longitude: 121.4737,
        visitDate: Date().addingTimeInterval(86400)
    )
    
    dest1.trip = trip
    dest2.trip = trip
    
    container.mainContext.insert(trip)
    container.mainContext.insert(dest1)
    container.mainContext.insert(dest2)
    
    return TripRouteMapView(destinations: [dest1, dest2], height: 300)
        .modelContainer(container)
        .padding()
}

