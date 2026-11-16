//
//  MapAnnotationComponents.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的地图标注相关组件
//

import SwiftUI
import MapKit
import SwiftData
import UIKit

// MARK: - 聚合标注视图
/// 地图上的聚合标注视图，支持单个地点和聚合显示
struct ClusterAnnotationView: View, Equatable {
    let cluster: ClusterAnnotation
    let zoomLevel: Double
    let tripColorMap: [UUID: Color]
    let accentColor: Color
    let weatherSummary: WeatherSummary?
    let mapMode: DiscoverMapMode
    
    // 实现 Equatable 协议以减少不必要的视图更新
    static func == (lhs: ClusterAnnotationView, rhs: ClusterAnnotationView) -> Bool {
        lhs.cluster.id == rhs.cluster.id &&
        abs(lhs.zoomLevel - rhs.zoomLevel) < 0.5 &&
        lhs.weatherSummary == rhs.weatherSummary &&
        lhs.mapMode == rhs.mapMode
    }
    
    private var markerSize: CGFloat {
        let zoom = zoomLevel
        // 世界 / 国家使用最小标记，省 / 市保持中等大小，区 / 街道使用较大标记
        if zoom < 6 {
            return 10   // world、country
        } else if zoom < 10 {
            return 20   // province、city
        } else {
            return 40   // district、street
        }
    }
    
    private var strokeWidth: CGFloat {
        cluster.destinations.count == 1 ? 2 : 2.5
    }
    
    
    private var hasFavorite: Bool {
        cluster.destinations.contains { $0.isFavorite }
    }
    
    // 是否属于旅程
    private var belongsToTrip: Bool {
        cluster.destinations.count == 1 && cluster.destinations[0].trip != nil
    }
    
    // 聚合中是否包含旅程地点
    private var hasTripDestinations: Bool {
        cluster.destinations.contains { $0.trip != nil }
    }
    
    var body: some View {
        // 发现地图模式下的显示逻辑
        if mapMode == .discover {
            switch cluster.displayType {
            case .detailedCard:
                // 详细卡片：显示完整信息
                if let destination = cluster.destinations.first {
                    MapDestinationCalloutAnnotationView(
                        destination: destination,
                        userProfileManager: UserProfileManager.shared
                    )
                }
                
            case .simplifiedAvatar:
                // 简化头像圆圈：仅显示头像
                if let destination = cluster.destinations.first {
                    SimplifiedAvatarAnnotationView(
                        destination: destination,
                        userProfileManager: UserProfileManager.shared,
                        accentColor: accentColor
                    )
                }
                
            case .clusteredCard:
                // 聚合卡片：显示层叠头像和随机笔记
                ClusterCalloutAnnotationView(
                    destinations: cluster.destinations,
                    userProfileManager: UserProfileManager.shared
                )
                
            case .hidden:
                // 隐藏：不显示任何内容
                EmptyView()
            }
        } else {
            // 足迹地图模式：保持原来的圆圈+天气徽章样式
            VStack(spacing: 6) {
                if shouldDisplayWeatherBadge, let summary = weatherSummary {
                    WeatherBadgeView(summary: summary)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                ZStack {
                    // 外圈：旅程标识（当包含旅程地点时显示）
                    if belongsToTrip || hasTripDestinations {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0
                            )
                            .frame(width: markerSize + 8, height: markerSize + 8)
                            .opacity(0.8)
                    }
                    
                    // 单个地点
                    if cluster.destinations.count == 1 {
                        let destination = cluster.destinations[0]
                        
                        // 照片显示规则：仅当尺寸较大（>20）且有照片时展示图片；
                        // 尺寸为20时，与无照片一致使用液态玻璃渐变
                        if markerSize > 20 {
                            MapDestinationPhotoMarker(
                                destinationID: destination.id,
                                thumbnailData: destination.photoThumbnailData,
                                fallbackData: destination.photoData,
                                markerSize: markerSize,
                                strokeWidth: strokeWidth
                            )
                        } else {
                            // 液态玻璃标注
                            LiquidGlassMarkerView(
                                size: markerSize,
                                startColor: accentColor,
                                endColor: accentColor,
                                borderWidth: strokeWidth
                            )
                        }
                        
                        // 内容图标（收藏心形）
                        if hasFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.white)
                                .font(.system(size: markerSize * 0.5))
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    } else {
                        // 聚合地点：足迹地图模式使用液态玻璃标注
                        ZStack {
                            LiquidGlassMarkerView(
                                size: markerSize,
                                startColor: accentColor,
                                endColor: accentColor,
                                borderWidth: strokeWidth
                            )
                            // 聚合数量文本
                            Text("\(cluster.destinations.count)")
                                .font(.system(size: markerSize * 0.45, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                }
            }
        }
    }

    private var shouldDisplayWeatherBadge: Bool {
        markerSize >= 40 && cluster.destinations.count == 1 && weatherSummary != nil
    }
}

/// 地图圆点照片：后台解码缩略图并缓存，避免在 body 里解原图
private struct MapDestinationPhotoMarker: View {
    let destinationID: UUID
    let thumbnailData: Data?
    let fallbackData: Data?
    let markerSize: CGFloat
    let strokeWidth: CGFloat
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            } else {
                Image("ImageMooyu")
                    .resizable()
                    .interpolation(.medium)
                    .antialiased(true)
                    .scaledToFill()
            }
        }
        .frame(width: markerSize, height: markerSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white, lineWidth: strokeWidth)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .task(id: destinationID) {
            if let cached = DestinationThumbnailCache.shared.cachedImage(for: destinationID) {
                image = cached
                return
            }
            image = await DestinationThumbnailCache.shared.image(
                for: destinationID,
                thumbnailData: thumbnailData,
                fallbackData: fallbackData
            )
        }
    }
}


// MARK: - 用户位置标注视图
/// 显示用户当前位置的标注视图
struct UserLocationAnnotationView: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // 外圈脉冲动画
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
            
            // 中间圈
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
            
            // 内圈
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onAppear {
            // 脉冲动画
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                pulseScale = 1.5
                pulseOpacity = 0.0
            }
        }
    }
}
