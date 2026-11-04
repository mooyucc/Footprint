//
//  MapRoutePreviewCard.swift
//  Footprint
//
//  从 MapRouteComponents.swift 提取（编译拆分）
//

import SwiftUI
import MapKit
import CoreLocation
import SwiftData
import Combine

struct RoutePreviewCard: View {
    let trip: TravelTrip
    let destinations: [TravelDestination]
    let onOpenDetail: () -> Void
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var routes: [MKRoute] = []
    @State private var isLoadingRoutes = false
    @State private var totalDistance: CLLocationDistance = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 旅程名称和日期
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDateRange(trip.startDate, trip.endDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 描述
            if !trip.desc.isEmpty {
                Text(trip.desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 线路信息
            HStack(spacing: 16) {
                // 地点数量
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    Text("\(destinations.count)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                    Text("route_card_location".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 总距离
                if totalDistance > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "road.lanes")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(formatDistance(totalDistance))
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Text("route_card_total_distance".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if isLoadingRoutes {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("route_card_calculating".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 起点和终点
            if let start = destinations.first, let end = destinations.last {
                HStack(spacing: 5) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text(start.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        Text("route_card_start_point".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text(end.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        Text("route_card_end_point".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // 查看详情按钮
            Button {
                onOpenDetail()
            } label: {
                HStack {
                    Text("view_details".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            onOpenDetail()
        }
        .onAppear {
            calculateRoutes()
        }
        .onReceive(routeManager.objectWillChange) { _ in
            // 当 RouteManager 有任何变化时（包括路线计算完成），检查并更新总距离
            // 这会在用户更改交通方式后，地图重新计算路线时触发
            // 使用延迟检查，确保路线已经更新到缓存中
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateTotalDistanceFromCache()
            }
        }
    }
    
    // 从缓存更新总距离（用于响应 RouteManager 路线缓存更新）
    private func updateTotalDistanceFromCache() {
        guard destinations.count >= 2 else {
            return
        }
        
        let coordinates = destinations.map { $0.coordinate }
        var cachedRoutes: [MKRoute] = []
        
        // 检查所有路线是否都已缓存
        for i in 0..<coordinates.count - 1 {
            if let cachedRoute = routeManager.getCachedRoute(
                from: coordinates[i],
                to: coordinates[i + 1]
            ) {
                cachedRoutes.append(cachedRoute)
            } else {
                // 如果有路线未缓存，不更新（可能正在计算中）
                return
            }
        }
        
        // 所有路线都已缓存，更新总距离
        if cachedRoutes.count == coordinates.count - 1 {
            routes = cachedRoutes
            let newTotalDistance = cachedRoutes.reduce(0) { $0 + $1.footprintDistance }
            // 只有当距离发生变化时才更新，避免不必要的视图刷新
            if abs(newTotalDistance - totalDistance) > 1.0 { // 1米的最小变化阈值
                totalDistance = newTotalDistance
            }
        }
    }
    
    // 计算路线
    private func calculateRoutes() {
        guard destinations.count >= 2 else {
            routes = []
            totalDistance = 0
            return
        }
        
        isLoadingRoutes = true
        let coordinates = destinations.map { $0.coordinate }
        
        Task {
            let calculatedRoutes = await routeManager.calculateRoutes(for: coordinates)
            
            await MainActor.run {
                routes = calculatedRoutes
                
                // 计算总距离：如果路线计算成功，使用路线距离；否则使用直线距离
                if calculatedRoutes.count == coordinates.count - 1 {
                    // 所有路线都计算成功，使用路线距离
                    totalDistance = calculatedRoutes.reduce(0) { $0 + $1.footprintDistance }
                } else {
                    // 部分或全部路线计算失败，使用直线距离作为备用
                    var straightLineDistance: CLLocationDistance = 0
                    for i in 0..<coordinates.count - 1 {
                        straightLineDistance += coordinates[i].distance(to: coordinates[i + 1])
                    }
                    totalDistance = straightLineDistance
                }
                
                isLoadingRoutes = false
            }
        }
    }
    
    // 格式化日期范围
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = languageManager.currentLanguage == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) - \(endString)"
    }
    
    // 格式化距离（与 `RouteManager.formatDistanceForRouteCard` 一致）
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        RouteManager.formatDistanceForRouteCard(distance, languageManager: languageManager)
    }
}

// MARK: - 路线距离标签视图
/// 路线距离标签视图（带交通方式选择），用于线路卡片模式显示路线距离
