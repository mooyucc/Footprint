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
        lhs.accentColorSignature == rhs.accentColorSignature &&
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
    
    // 边框颜色：如果有旅程，显示与主色不同的亮色边框
    private var borderColor: Color {
        if cluster.destinations.count == 1 {
            if cluster.destinations[0].trip != nil {
                return .white
            }
        }
        return .white
    }
    
    // 找出最常出现的元素
    private func mostFrequent(in array: [UUID]) -> UUID? {
        guard !array.isEmpty else { return nil }
        let counts = array.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
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
    
    private var accentColorSignature: String {
        UIColor(accentColor).description
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
                        appleSignInManager: AppleSignInManager.shared
                    )
                }
                
            case .simplifiedAvatar:
                // 简化头像圆圈：仅显示头像
                if let destination = cluster.destinations.first {
                    SimplifiedAvatarAnnotationView(
                        destination: destination,
                        appleSignInManager: AppleSignInManager.shared,
                        accentColor: accentColor
                    )
                }
                
            case .clusteredCard:
                // 聚合卡片：显示层叠头像和随机笔记
                ClusterCalloutAnnotationView(
                    destinations: cluster.destinations,
                    appleSignInManager: AppleSignInManager.shared
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
                            if let photoData = destination.photoData,
                               let uiImage = UIImage(data: photoData) {
                                // 有照片：使用用户照片作为标记
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: markerSize, height: markerSize)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: strokeWidth)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            } else {
                                // 无照片：使用内置形象图 ImageMooyu 作为标记
                                Image("ImageMooyu")
                                    .resizable()
                                    .interpolation(.high)  // 高质量插值，确保边缘光滑
                                    .antialiased(true)     // 启用抗锯齿
                                    .scaledToFill()
                                    .frame(width: markerSize, height: markerSize)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: strokeWidth)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
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
                                .font(.system(size: markerSize * 0.45, weight: .bold, design: .rounded))
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

// MARK: - 回忆泡泡视图
/// 显示地点回忆的泡泡视图组件
struct MemoryBubbleView: View {
    let destination: TravelDestination
    let screenPosition: CGPoint
    let animationOffset: CGFloat
    let scale: CGFloat
    let onTap: () -> Void
    
    @State private var bubbleOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -100
    
    var body: some View {
        ZStack {
            // 泡泡主体
            Circle()
                .fill(
                    // 使用品牌红与米色渐变增强质感，符合配色规范
                    RadialGradient(
                        colors: [
                            Color.footprintRed.opacity(0.9),
                            Color.footprintRed.opacity(0.6),
                            Color.footprintBeige.opacity(0.5)
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 50
                    )
                )
                .frame(width: 50, height: 50) // 进一步缩小照片：从80改为50
                .overlay(
                    // 泡泡高光效果
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7),
                                    Color.footprintBeige.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .offset(x: -15, y: -15)
                )
                .overlay(
                    // 泡泡边框
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.footprintRed.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.footprintRed.opacity(0.35), radius: 10, x: 0, y: 5)
                .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
            
            // 地点名称
            Text(destination.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            
            // 闪烁效果
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 100, height: 100)
                .offset(x: shimmerOffset)
                .opacity(bubbleOpacity)
        }
        .position(x: screenPosition.x, y: screenPosition.y + animationOffset)
        .scaleEffect(scale)
        .opacity(bubbleOpacity)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            // 出现动画
            withAnimation(.easeOut(duration: 0.5)) {
                bubbleOpacity = 1.0
            }
            
            // 闪烁动画
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 100
            }
        }
        .onDisappear {
            bubbleOpacity = 0
            shimmerOffset = -100
        }
    }
}

// MARK: - 自定义气泡图标
/// 自定义气泡图标组件
struct CustomBubbleIcon: View {
    let iconColor: Color
    
    var body: some View {
        ZStack {
            // 最大的圆形（上方）
            Circle()
                .fill(.white.opacity(0.3))
                .stroke(iconColor.opacity(0.8), lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .offset(x: -4, y: -3)
            
            // 中等圆形（中间）
            Circle()
                .fill(.white.opacity(0.5))
                .stroke(iconColor.opacity(0.8), lineWidth: 1.2)
                .frame(width: 12, height: 12)
                .offset(x: 6, y: 1) // 向右平移更多
            
            // 最小的圆形（下方）
            Circle()
                .fill(.white.opacity(0.7))
                .stroke(iconColor.opacity(0.8), lineWidth: 1.0)
                .frame(width: 8, height: 8)
                .offset(x: 2, y: 9) // 往下移动更多
        }
        .frame(width: 28, height: 28)
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
