//
//  JourneyDrawer.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的旅程抽屉组件
//

import SwiftUI
import MapKit
import SwiftData

// MARK: - 旅程抽屉组件
/// 可拖拽的旅程卡片抽屉，支持缩小和展开两种状态
struct JourneyDrawer: View {
    let trips: [TravelTrip]
    let tripRoutes: [UUID: [MKRoute?]]
    let sortedDestinations: (UUID) -> [TravelDestination]
    let selectedTripId: Binding<UUID?>
    let scrollPosition: Binding<UUID?>
    let onTripSelected: (TravelTrip, [TravelDestination]) -> Void
    let onCardTap: (TravelTrip) -> Void
    var hasMoreTrips: Bool = false
    var onLoadMoreTrips: (() -> Void)? = nil
    
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @Environment(\.colorScheme) private var colorScheme
    
    // 抽屉高度定义
    private let collapsedHeight: CGFloat = 100 // 缩小状态高度
    private let expandedHeight: CGFloat = 350 // 展开状态高度（适配旅程卡片大小）
    private let dragThreshold: CGFloat = 50 // 拖拽阈值，超过此值切换状态
    
    // 找到当前选中的旅程
    private var currentTrip: TravelTrip? {
        guard let selectedId = selectedTripId.wrappedValue else { return trips.first }
        return trips.first(where: { $0.id == selectedId }) ?? trips.first
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let safeAreaInsets = geometry.safeAreaInsets
            // TabBar 在底部会有一些水平 padding，通常左右各约 16-20pt
            // 收起状态下，抽屉宽度应与 TabBar 的实际可见宽度一致
            let horizontalPadding: CGFloat = 32 // 左右各 16pt，总共 32pt
            let tabBarWidth = screenWidth - horizontalPadding
            
            VStack(spacing: 0) {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // 拖拽指示器
                        dragIndicator
                        
                        // 抽屉内容
                        if isExpanded {
                            expandedContent
                        } else {
                            collapsedContent
                        }
                    }
                    .frame(height: isExpanded ? expandedHeight : collapsedHeight)
                    .frame(width: isExpanded ? nil : tabBarWidth) // 收起状态下固定宽度与导航栏一致
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isExpanded)
                    .background(
                        // 使用毛玻璃效果
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
                    .offset(y: dragOffset)
                    .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                            }
                            
                            // 实时跟随手指，不使用动画确保流畅
                            let newOffset = value.translation.height
                            
                            // 限制拖拽范围，添加阻尼效果（接近边界时阻力增大）
                            if isExpanded {
                                // 展开状态：只能向下拖拽（正值）
                                let maxDrag = expandedHeight - collapsedHeight
                                if newOffset > maxDrag {
                                    // 超过最大距离时添加阻尼
                                    let excess = newOffset - maxDrag
                                    dragOffset = maxDrag + excess * 0.3
                                } else {
                                    dragOffset = max(0, newOffset)
                                }
                            } else {
                                // 缩小状态：只能向上拖拽（负值）
                                let minDrag = -(expandedHeight - collapsedHeight)
                                if newOffset < minDrag {
                                    // 超过最大距离时添加阻尼
                                    let excess = newOffset - minDrag
                                    dragOffset = minDrag + excess * 0.3
                                } else {
                                    dragOffset = min(0, newOffset)
                                }
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // 计算速度和拖拽距离
                            let translation = value.translation.height
                            let velocity = value.predictedEndTranslation.height - value.translation.height
                            let absVelocity = abs(velocity)
                            
                            // 智能判断是否切换状态
                            // 1. 拖拽距离超过阈值
                            // 2. 或者速度足够快（向上拖拽时为负值，向下拖拽时为正值）
                            let shouldToggle: Bool
                            if isExpanded {
                                // 展开状态：向下拖拽（正值）且速度足够快，则收起
                                shouldToggle = translation > dragThreshold || (translation > 0 && absVelocity > 300)
                            } else {
                                // 缩小状态：向上拖拽（负值）且速度足够快，则展开
                                shouldToggle = translation < -dragThreshold || (translation < 0 && absVelocity > 300)
                            }
                            
                            if shouldToggle {
                                // 切换状态 - 使用更流畅的 spring 动画
                                let willExpand = !isExpanded
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0)) {
                                    isExpanded.toggle()
                                    dragOffset = 0
                                }
                                
                            } else {
                                // 回弹到原状态 - 使用更快的 spring 动画
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0)) {
                                    dragOffset = 0
                                }
                            }
                        }
                    )
                    
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 90) // 为底部导航栏留出空间
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    // 拖拽指示器
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
    }
    
    // 缩小状态内容
    private var collapsedContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if let trip = currentTrip {
                let destinations = sortedDestinations(trip.id)
                
                HStack(spacing: 12) {
                    // 封面图片缩略图
                    if let photoData = trip.coverPhotoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "map.fill")
                                    .foregroundColor(.secondary)
                            )
                    }
                    
                    // 旅程信息
                    VStack(alignment: .leading, spacing: 6) {
                        Text(trip.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatDateRange(trip.startDate, trip.endDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("\(destinations.count) \("locations".localized)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 展开按钮提示
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    // 展开状态内容
    private var expandedContent: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            // 计算响应式卡片宽度：
            // - 屏幕宽度减去左右边距（32pt × 2 = 64pt），使卡片在每一页中居中
            // - 最大宽度限制为 360pt，确保大屏幕上保持良好的阅读体验
            // - 最小宽度为 280pt，确保小屏幕上内容不会过于拥挤
            let horizontalPadding: CGFloat = 32 // 左右各 32pt，用于居中显示
            let maxCardWidth: CGFloat = 360
            let minCardWidth: CGFloat = 280
            let cardWidth = max(minCardWidth, min(screenWidth - horizontalPadding * 2, maxCardWidth))
            
            // 水平滚动的旅程卡片（分页模式）
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 0) {
                        ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                            let sortedDest = sortedDestinations(trip.id)
                            let precomputedRoutes = tripRoutes[trip.id]?.compactMap { $0 } ?? []
                            
                            // 每个卡片占据一页，使用 HStack 实现居中
                            HStack {
                                Spacer()
                                RouteCard(
                                    trip: trip,
                                    destinations: sortedDest,
                                    precomputedRoutes: precomputedRoutes.isEmpty ? nil : precomputedRoutes,
                                    onTap: {
                                        onCardTap(trip)
                                    }
                                )
                                .frame(width: cardWidth)
                                .padding(.vertical, 0)
                                Spacer()
                            }
                            .frame(width: screenWidth) // 每个卡片占据整个屏幕宽度
                            .id(trip.id)
                        }
                        
                        if hasMoreTrips, let onLoadMore = onLoadMoreTrips {
                            HStack {
                                Spacer()
                                Button {
                                    onLoadMore()
                                } label: {
                                    Label("load_more_trips".localized, systemImage: "arrow.down.circle")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                            }
                            .frame(width: screenWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollContentBackground(.hidden)
                .scrollTargetBehavior(.paging) // 使用分页模式，确保每一页只显示一个卡片
                .scrollPosition(id: scrollPosition)
                .onChange(of: scrollPosition.wrappedValue) { oldValue, newValue in
                    // 当滚动位置变化时，更新选中的旅程
                    if let newTripId = newValue,
                       newTripId != selectedTripId.wrappedValue {
                        DispatchQueue.main.async {
                            if let trip = trips.first(where: { $0.id == newTripId }) {
                                let destinations = sortedDestinations(newTripId)
                                onTripSelected(trip, destinations)
                            }
                        }
                    }
                }
                .frame(height: expandedHeight - 40) // 减去指示器高度
                .onAppear {
                    // 确保滚动位置与选中的旅程一致（如果有选中的）
                    if let currentSelectedId = selectedTripId.wrappedValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                scrollPosition.wrappedValue = currentSelectedId
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // 格式化日期范围
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) - \(endString)"
    }
}
