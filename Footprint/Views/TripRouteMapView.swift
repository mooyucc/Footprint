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
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @State private var routes: [MKRoute] = []
    @State private var isLoadingRoutes = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // MARK: - Route Color Helper
    /// 根据交通方式返回路线颜色
    /// - Parameter transportType: 交通方式
    /// - Returns: 路线颜色（徒步：绿色，机动车：蓝色，其他：灰色）
    private func routeColor(for transportType: MKDirectionsTransportType) -> Color {
        if transportType == RouteManager.airplane {
            // 飞机模式：使用橙色
            return .orange
        } else if transportType.contains(.walking) && transportType == .walking {
            // 徒步模式：使用绿色，更符合自然、步行的感觉
            return .green
        } else if transportType.contains(.automobile) && transportType == .automobile {
            // 机动车模式：使用蓝色（保持原有颜色）
            return .blue
        } else if transportType.contains(.transit) && transportType == .transit {
            // 公共交通：使用紫色
            return .purple
        } else {
            // 其他或混合模式：使用灰色
            return .gray
        }
    }
    
    var sortedDestinations: [TravelDestination] {
        destinations.sorted { $0.visitDate < $1.visitDate }
    }
    
    // 计算总路线距离
    var totalDistance: CLLocationDistance {
        routes.reduce(0) { $0 + $1.distance }
    }
    
    private var brandAccentColor: Color {
        brandColorManager.currentBrandColor
    }
    
    // 计算占位线应该显示的交通方式
    private func calculatePlaceholderTransportType(
        from source: TravelDestination,
        to destination: TravelDestination
    ) -> MKDirectionsTransportType {
        // 获取用户选择的交通方式，如果没有则使用默认机动车
        let userTransportType = routeManager.getUserTransportType(
            from: source.coordinate,
            to: destination.coordinate
        )
        
        // 优先使用用户选择，否则使用默认机动车
        return userTransportType ?? .automobile
    }
    
    // 占位线绘制视图（提取复杂逻辑，避免类型检查超时）
    @MapContentBuilder
    private func placeholderRouteContent(
        for source: TravelDestination,
        destination: TravelDestination,
        transportType: MKDirectionsTransportType
    ) -> some MapContent {
        // 根据交通方式选择虚线颜色
        let placeholderColor = routeColor(for: transportType)
        
        // 计算直线距离
        let distance = source.coordinate.distance(to: destination.coordinate)
        
        // 绘制虚线（更细的线条，更短的虚线间隔）
        MapPolyline(coordinates: [source.coordinate, destination.coordinate])
            .stroke(placeholderColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [3, 2]))
        
        // 显示直线距离标注（带交通方式选择，显示用户选择的交通方式图标）
        if let midpoint = midpointOfLine(from: source.coordinate, to: destination.coordinate) {
            Annotation("", coordinate: midpoint) {
                RouteDistanceLabel(
                    distance: distance,
                    transportType: transportType, // 显示用户选择的交通方式图标
                    source: source.coordinate,
                    destination: destination.coordinate,
                    onTransportTypeChange: { newType in
                        // 保存用户选择并重新计算路线
                        routeManager.setUserTransportType(
                            from: source.coordinate,
                            to: destination.coordinate,
                            transportType: newType
                        )
                        // 清除当前路线，强制重新计算
                        routes = []
                        // 重新计算路线
                        calculateRoutes()
                    }
                )
            }
        }
    }
    
    // 路线绘制视图（提取复杂逻辑，避免类型检查超时）
    // 注意：MapContent 需要使用 Group 来组合多个内容
    @MapContentBuilder
    private func routePolylineContent(for route: MKRoute, at index: Int) -> some MapContent {
        // 根据交通方式选择颜色
        let routeColorValue = routeColor(for: route.footprintTransportType)
        
        // 路线 - 使用 Apple 设计标准的样式（白色描边 + 主体颜色）
        // 先绘制白色背景（更粗），创建描边效果
        MapPolyline(route.polyline)
            .stroke(
                Color.white,
                style: StrokeStyle(
                    lineWidth: 7,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        // 再绘制主体颜色（较细），叠加在白色背景上
        MapPolyline(route.polyline)
            .stroke(
                routeColorValue,
                style: StrokeStyle(
                    lineWidth: 5,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        
        // 距离标注（带交通方式选择）
        if let midpoint = midpointOfPolyline(route.polyline),
           index < sortedDestinations.count - 1 {
            let source = sortedDestinations[index]
            let destination = sortedDestinations[index + 1]
            Annotation("", coordinate: midpoint) {
                RouteDistanceLabel(
                    distance: route.footprintDistance,
                    transportType: route.footprintTransportType,
                    source: source.coordinate,
                    destination: destination.coordinate,
                    onTransportTypeChange: { newType in
                        // 保存用户选择并重新计算路线
                        routeManager.setUserTransportType(
                            from: source.coordinate,
                            to: destination.coordinate,
                            transportType: newType
                        )
                        // 清除当前路线，强制重新计算
                        routes = []
                        // 重新计算路线（totalDistance 会自动从 routes 计算得出）
                        calculateRoutes()
                    }
                )
            }
        }
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
                            // 统一使用品牌红色
                            Circle()
                                .fill(brandAccentColor)
                                .frame(width: index == 0 ? 20 : 16, height: index == 0 ? 20 : 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: index == 0 ? 3 : 2)
                                )
                                .shadow(radius: index == 0 ? 3 : 2)
                        }
                    }
                }
                
                // 显示路线
                if !routes.isEmpty {
                    ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                        routePolylineContent(for: route, at: index)
                    }
                } else if !isLoadingRoutes && sortedDestinations.count >= 2 {
                    // 如果没有计算好的路线，显示直线作为占位
                    ForEach(Array(sortedDestinations.enumerated()), id: \.offset) { index, _ in
                        if index < sortedDestinations.count - 1 {
                            let source = sortedDestinations[index]
                            let destination = sortedDestinations[index + 1]
                            let transportType = calculatePlaceholderTransportType(from: source, to: destination)
                            placeholderRouteContent(for: source, destination: destination, transportType: transportType)
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
            // 使用 RouteManager 的并发批量计算
            let calculatedRoutes = await routeManager.calculateRoutes(for: coordinates)
            
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
    
    /// 计算路线多边形的中点坐标（按距离计算，而不是简单的点索引）
    private func midpointOfPolyline(_ polyline: MKPolyline) -> CLLocationCoordinate2D? {
        let pointCount = polyline.pointCount
        guard pointCount > 0 else { return nil }
        
        // 如果只有两个点（如飞机模式的直线），直接计算两点中点
        if pointCount == 2 {
            let points = polyline.points()
            let start = points[0].coordinate
            let end = points[1].coordinate
            return midpointOfLine(from: start, to: end)
        }
        
        // 对于多点路线，计算总距离，然后找到中点位置
        let points = polyline.points()
        var totalDistance: CLLocationDistance = 0
        var segmentDistances: [CLLocationDistance] = []
        
        // 计算每段的距离和总距离
        for i in 0..<pointCount - 1 {
            let start = CLLocation(latitude: points[i].coordinate.latitude, longitude: points[i].coordinate.longitude)
            let end = CLLocation(latitude: points[i + 1].coordinate.latitude, longitude: points[i + 1].coordinate.longitude)
            let segmentDistance = start.distance(from: end)
            segmentDistances.append(segmentDistance)
            totalDistance += segmentDistance
        }
        
        // 找到中点位置（总距离的一半）
        let halfDistance = totalDistance / 2
        var accumulatedDistance: CLLocationDistance = 0
        
        for i in 0..<segmentDistances.count {
            let segmentDistance = segmentDistances[i]
            if accumulatedDistance + segmentDistance >= halfDistance {
                // 中点在这个段内
                let remainingDistance = halfDistance - accumulatedDistance
                let ratio = remainingDistance / segmentDistance
                
                let start = points[i].coordinate
                let end = points[i + 1].coordinate
                
                // 在起点和终点之间按比例插值
                return CLLocationCoordinate2D(
                    latitude: start.latitude + (end.latitude - start.latitude) * ratio,
                    longitude: start.longitude + (end.longitude - start.longitude) * ratio
                )
            }
            accumulatedDistance += segmentDistance
        }
        
        // 如果没找到（理论上不应该发生），返回中间点
        let midIndex = pointCount / 2
        guard midIndex < pointCount else { return nil }
        return points[midIndex].coordinate
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
        name: "测试旅程",
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
        .environmentObject(BrandColorManager.shared)
        .padding()
}

