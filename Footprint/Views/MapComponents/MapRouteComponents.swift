//
//  MapRouteComponents.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的路线相关组件
//

import SwiftUI
import MapKit
import CoreLocation
import SwiftData
import Combine

// MARK: - 路线卡片组件
/// 显示旅程路线信息的卡片组件
struct RouteCard: View {
    let trip: TravelTrip
    let destinations: [TravelDestination]
    let precomputedRoutes: [MKRoute]? // 从 MapView 传递的已计算路线（可选，避免重复计算）
    let onTap: (() -> Void)?
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var routes: [MKRoute] = []
    @State private var isLoadingRoutes = false
    @State private var totalDistance: CLLocationDistance = 0
    @State private var lastDestinationsHash: Int = 0 // 用于检测 destinations 变化
    @State private var showingLayoutSelection = false // 控制版面选择视图显示
    @State private var selectedLayout: TripShareLayout = .list // 默认选择清单版面
    @State private var isVisible = false // 卡片是否在可见区域
    @State private var cacheCheckTimer: Timer? // 用于定期检查缓存更新
    @State private var showingAIDescription = false // 控制AI描述生成sheet显示
    @State private var calculationTask: Task<Void, Never>? // 用于管理计算任务，防止重复计算
    @State private var lastPrecomputedRoutesHash: Int = 0 // 用于检测 precomputedRoutes 变化
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    
    init(trip: TravelTrip, destinations: [TravelDestination], precomputedRoutes: [MKRoute]? = nil, onTap: (() -> Void)? = nil) {
        self.trip = trip
        self.destinations = destinations
        self.precomputedRoutes = precomputedRoutes
        self.onTap = onTap
    }
    
    // 生成 destinations 的哈希值，用于检测变化
    // 包括地点ID、坐标和访问日期，确保能检测到所有相关变化
    // 性能优化：destinations 在传入时已经按 visitDate 排序，无需重复排序
    private var destinationsHash: Int {
        let hashString = destinations
            .map { "\($0.id.uuidString)|\($0.coordinate.latitude)|\($0.coordinate.longitude)|\($0.visitDate.timeIntervalSince1970)" }
            .joined(separator: ",")
        return hashString.hashValue
    }
    
    // 生成 precomputedRoutes 的哈希值，用于检测 MapView 计算的路线变化
    private var precomputedRoutesHash: Int {
        guard let precomputedRoutes = precomputedRoutes else {
            return 0
        }
        // 使用路线数量和总距离来生成哈希值
        let totalDistance = precomputedRoutes.reduce(0) { $0 + $1.footprintDistance }
        return "\(precomputedRoutes.count)|\(totalDistance)".hashValue
    }
    
    // 检查是否有封面图片
    private var hasCoverPhoto: Bool {
        trip.coverPhotoData != nil
    }
    
    // 封面图片
    @ViewBuilder
    private var coverImage: some View {
        if let photoData = trip.coverPhotoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Color.clear
        }
    }
    
    // 文字颜色：有封面图片时使用白色，否则使用系统颜色
    private var primaryTextColor: Color {
        hasCoverPhoto ? .white : .primary
    }
    
    private var secondaryTextColor: Color {
        hasCoverPhoto ? .white.opacity(0.9) : .secondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面图片区域（如果有）
            if hasCoverPhoto {
                coverImage
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .overlay(
                        // 顶部渐变遮罩，确保按钮可见
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        // 底部渐变遮罩，增强文字对比度
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        alignment: .bottom
                    )
                    .overlay(
                        // 顶部按钮组
                        VStack {
                            HStack {
                                Spacer()
                                // 分享按钮
                                Button {
                                    showingLayoutSelection = true
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .background(Circle().fill(Color.white.opacity(0.25)))
                                        )
                                }
                                
                                // 地图按钮
                                Button {
                                    openTripInMaps()
                                } label: {
                                    Image(systemName: "map")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .background(Circle().fill(Color.white.opacity(0.25)))
                                        )
                                }
                                
                                // AI描述生成按钮
                                Button {
                                    showingAIDescription = true
                                } label: {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .background(Circle().fill(Color.white.opacity(0.25)))
                                        )
                                }
                                .disabled(!canUseAI)
                                .opacity(canUseAI ? 1.0 : 0.5)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            
                            Spacer()
                            
                            // 底部信息（封面图上）
                            VStack(alignment: .leading, spacing: 5) {
                                Text(trip.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                
                                HStack(spacing: 16) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                        Text(formatDateRange(trip.startDate, trip.endDate))
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                        Text("\(destinations.count) \("locations".localized)")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    )
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 16) {
                // 如果没有封面图，显示标题和主要信息在顶部
                if !hasCoverPhoto {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(trip.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDateRange(trip.startDate, trip.endDate))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("\(destinations.count) \("locations".localized)")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            // 总距离
                            if totalDistance > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "road.lanes")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text(formatDistance(totalDistance))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            } else if isLoadingRoutes {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("route_card_calculating".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // 按钮组（无封面图时）
                        VStack(spacing: 8) {
                            Button {
                                showingLayoutSelection = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            }
                            
                            Button {
                                openTripInMaps()
                            } label: {
                                Image(systemName: "map")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            }
                            
                            Button {
                                showingAIDescription = true
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            }
                            .disabled(!canUseAI)
                            .opacity(canUseAI ? 1.0 : 0.5)
                        }
                    }
                }
                
                // 起点和终点（如果有封面图，显示在这里；否则已经在上面显示）
                if hasCoverPhoto {
                    // 有封面图时，显示距离和起点终点信息
                    VStack(alignment: .leading, spacing: 12) {
                        if totalDistance > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "road.lanes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatDistance(totalDistance))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        } else if isLoadingRoutes {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("route_card_calculating".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let start = destinations.first, let end = destinations.last {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                        Text(start.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    Text("route_card_start_point".localized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 8, height: 8)
                                        Text(end.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
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
                    }
                } else {
                    // 无封面图时，起点和终点
                    if let start = destinations.first, let end = destinations.last {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(start.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                Text("route_card_start_point".localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                    Text(end.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
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
                }
                
                // 如果没有目的地
                if destinations.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("trip_share_no_destinations".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Label("add_destination".localized, systemImage: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10) // 进一步缩小内边距：从16改为10
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                // 有封面图时，底部内容区域也需要白色背景
                Color(.systemBackground)
            )
        }
        .frame(width: 360)
        .background(
            Group {
                if hasCoverPhoto {
                    // 有封面图片：白色背景
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                } else {
                    // 无封面图片：使用毛玻璃效果
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle()) // 确保整个区域可点击
        .background(
            GeometryReader { geometry in
                let frame = geometry.frame(in: .global)
                Color.clear
                    .onAppear {
                        // 检测卡片是否在可见区域
                        checkVisibility(frame: frame)
                    }
                    .task {
                        // 定期检查可见性（当滚动时位置会变化）
                        var lastFrame = frame
                        while !Task.isCancelled {
                            let currentFrame = geometry.frame(in: .global)
                            // 只有当位置发生变化时才检查
                            if currentFrame != lastFrame {
                                checkVisibility(frame: currentFrame)
                                lastFrame = currentFrame
                            }
                            try? await Task.sleep(nanoseconds: 100_000_000) // 每100ms检查一次
                        }
                    }
            }
        )
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            // 首次出现时，延迟一点检查可见性（确保 GeometryReader 已经计算好位置）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if isVisible {
                    calculateRoutes()
                }
            }
        }
        .onChange(of: isVisible) { oldValue, newValue in
            // 当可见性从不可见变为可见时，计算路线
            if !oldValue && newValue {
                calculateRoutes()
            } else if !newValue {
                // 当卡片不可见时，停止定时器和计算任务
                stopCacheCheckTimer()
                calculationTask?.cancel()
                calculationTask = nil
                isLoadingRoutes = false
            }
        }
        .onChange(of: destinations.count) { oldValue, newValue in
            // 当地点数量变化时，重新计算
            calculateRoutes()
        }
        .onChange(of: destinationsHash) { oldValue, newValue in
            // 当地点列表发生变化时（新增、删除、顺序变化），重新计算
            if oldValue != 0 && oldValue != newValue {
                calculateRoutes()
            }
        }
        .onChange(of: precomputedRoutesHash) { oldValue, newValue in
            // 当 MapView 传递的预计算路线发生变化时（从空到有，或从部分到完整），更新路线
            if newValue != oldValue {
                updateRoutesFromPrecomputed()
            }
        }
        .onReceive(routeManager.objectWillChange) { _ in
            // 当 RouteManager 有任何变化时（包括路线计算完成），检查并更新总距离
            // 这会在用户更改交通方式后，地图重新计算路线时触发
            if isVisible && destinations.count >= 2 {
                // 使用延迟检查，确保路线已经更新到缓存中
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.updateTotalDistanceFromCache()
                }
            }
        }
        .sheet(isPresented: $showingLayoutSelection) {
            TripShareLayoutSelectionView(trip: trip, selectedLayout: $selectedLayout)
        }
        .sheet(isPresented: $showingAIDescription) {
            AIActionSheet(trip: trip, action: .generateDescription)
        }
    }
    
    // 检查是否有权限使用AI功能
    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    // 检测卡片是否在可见区域
    private func checkVisibility(frame: CGRect) {
        let screenWidth = UIScreen.main.bounds.width
        
        // 检查卡片是否在屏幕可见区域内（考虑左右边距，允许一些预加载）
        // 可见区域：屏幕宽度 + 左右各一个卡片宽度的缓冲区（用于预加载）
        let buffer: CGFloat = 400 // 左右各200点的缓冲区
        let visibleMinX = -buffer
        let visibleMaxX = screenWidth + buffer
        
        let wasVisible = isVisible
        isVisible = frame.maxX > visibleMinX && frame.minX < visibleMaxX
        
        // 如果从不可见变为可见，立即计算路线
        if !wasVisible && isVisible {
            calculateRoutes()
        }
    }
    
    // 从预计算路线更新（当 MapView 计算完成后调用）
    private func updateRoutesFromPrecomputed() {
        guard isVisible && destinations.count >= 2 else { return }
        
        // 如果 MapView 已经计算了完整的路线，直接使用
        if let precomputedRoutes = precomputedRoutes, !precomputedRoutes.isEmpty {
            let expectedCount = destinations.count - 1
            if precomputedRoutes.count == expectedCount {
                // 路线完整，更新并停止加载状态
                routes = precomputedRoutes
                totalDistance = precomputedRoutes.reduce(0) { $0 + $1.footprintDistance }
                isLoadingRoutes = false
                stopCacheCheckTimer()
                
                // 取消自己的计算任务（如果正在运行）
                calculationTask?.cancel()
                calculationTask = nil
                
                lastDestinationsHash = destinationsHash
                lastPrecomputedRoutesHash = precomputedRoutesHash
            } else if precomputedRoutes.count < expectedCount {
                // 部分路线已计算，显示加载状态，等待完整计算
                isLoadingRoutes = true
                // 使用部分路线更新显示
                routes = precomputedRoutes
                totalDistance = precomputedRoutes.reduce(0) { $0 + $1.footprintDistance }
                // 启动缓存检查定时器，等待剩余路线计算完成
                startCacheCheckTimer()
            }
        } else {
            // precomputedRoutes 为 nil 或空，MapView 可能正在计算中
            // 启动缓存检查定时器等待，或者如果已经等待一段时间，则自己计算
            if !isLoadingRoutes {
                isLoadingRoutes = true
                startCacheCheckTimer()
            }
        }
    }
    
    // 计算路线（优化版：优先使用预计算路线 + 缓存检查 + 实时更新）
    private func calculateRoutes() {
        // 只有可见的卡片才计算路线
        guard isVisible else {
            return
        }
        
        guard destinations.count >= 2 else {
            routes = []
            totalDistance = 0
            lastDestinationsHash = destinationsHash
            isLoadingRoutes = false
            calculationTask?.cancel()
            calculationTask = nil
            return
        }
        
        // 性能优化：如果 MapView 已经计算了路线，直接使用（避免重复计算）
        if let precomputedRoutes = precomputedRoutes, !precomputedRoutes.isEmpty {
            let expectedCount = destinations.count - 1
            if precomputedRoutes.count == expectedCount {
                routes = precomputedRoutes
                totalDistance = precomputedRoutes.reduce(0) { $0 + $1.footprintDistance }
                lastDestinationsHash = destinationsHash
                isLoadingRoutes = false
                calculationTask?.cancel()
                calculationTask = nil
                return
            }
        }
        
        // 检查是否所有路线都已缓存（用于快速更新）
        // 注意：destinations 在传入时已经按 visitDate 排序
        let coordinates = destinations.map { $0.coordinate }
        var allCached = true
        var cachedRoutes: [MKRoute] = []
        
        for i in 0..<coordinates.count - 1 {
            if let cachedRoute = routeManager.getCachedRoute(
                from: coordinates[i],
                to: coordinates[i + 1]
            ) {
                cachedRoutes.append(cachedRoute)
            } else {
                allCached = false
                break
            }
        }
        
        // 如果所有路线都已缓存，直接使用缓存（快速更新）
        if allCached && cachedRoutes.count == coordinates.count - 1 {
            routes = cachedRoutes
            totalDistance = cachedRoutes.reduce(0) { $0 + $1.footprintDistance }
            lastDestinationsHash = destinationsHash
            isLoadingRoutes = false
            calculationTask?.cancel()
            calculationTask = nil
            stopCacheCheckTimer()
            return
        }
        
        // 如果 precomputedRoutes 为空，但 MapView 可能正在计算中
        // 先启动缓存检查定时器等待一段时间，如果 MapView 没有在合理时间内完成，再自己计算
        if precomputedRoutes == nil || precomputedRoutes?.isEmpty == true {
            // 先设置加载状态并启动缓存检查定时器
            isLoadingRoutes = true
            startCacheCheckTimer()
            
            // 等待一段时间（1秒），如果 MapView 还没有完成计算，则自己计算
            calculationTask?.cancel()
            calculationTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
                
                // 检查是否被取消
                guard !Task.isCancelled else { return }
                
                // 再次检查缓存和 precomputedRoutes
                await MainActor.run {
                    // 检查 precomputedRoutes 是否已有更新
                    if let precomputedRoutes = self.precomputedRoutes, !precomputedRoutes.isEmpty {
                        let expectedCount = self.destinations.count - 1
                        if precomputedRoutes.count == expectedCount {
                            // MapView 已计算完成，使用预计算路线
                            self.routes = precomputedRoutes
                            self.totalDistance = precomputedRoutes.reduce(0) { $0 + $1.footprintDistance }
                            self.isLoadingRoutes = false
                            self.stopCacheCheckTimer()
                            self.lastDestinationsHash = self.destinationsHash
                            self.calculationTask = nil
                            return
                        }
                    }
                    
                    // 检查缓存是否已更新
                    let coordinates = self.destinations.map { $0.coordinate }
                    var allCached = true
                    var cachedRoutes: [MKRoute] = []
                    
                    for i in 0..<coordinates.count - 1 {
                        if let cachedRoute = self.routeManager.getCachedRoute(
                            from: coordinates[i],
                            to: coordinates[i + 1]
                        ) {
                            cachedRoutes.append(cachedRoute)
                        } else {
                            allCached = false
                            break
                        }
                    }
                    
                    if allCached && cachedRoutes.count == coordinates.count - 1 {
                        // 缓存已完整，使用缓存
                        self.routes = cachedRoutes
                        self.totalDistance = cachedRoutes.reduce(0) { $0 + $1.footprintDistance }
                        self.isLoadingRoutes = false
                        self.stopCacheCheckTimer()
                        self.lastDestinationsHash = self.destinationsHash
                        self.calculationTask = nil
                        return
                    }
                    
                    // MapView 还没有完成，自己计算
                    self.calculateRoutesSelf()
                }
            }
            return
        }
        
        // 如果有部分路线但未完整，使用自己的计算
        calculateRoutesSelf()
    }
    
    // 自己计算路线（当 MapView 没有计算或计算失败时调用）
    private func calculateRoutesSelf() {
        guard destinations.count >= 2 else { return }
        
        isLoadingRoutes = true
        stopCacheCheckTimer() // 停止缓存检查定时器，改为自己计算
        
        let coordinates = destinations.map { $0.coordinate }
        
        calculationTask?.cancel()
        calculationTask = Task {
            // 使用 RouteManager 的并发批量计算（与 TripRouteMapView 使用相同的方法）
            let calculatedRoutes = await routeManager.calculateRoutes(for: coordinates)
            
            await MainActor.run {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }
                
                self.routes = calculatedRoutes
                
                // 计算总距离：如果路线计算成功，使用路线距离；否则使用直线距离
                if calculatedRoutes.count == coordinates.count - 1 {
                    // 所有路线都计算成功，使用路线距离
                    self.totalDistance = calculatedRoutes.reduce(0) { $0 + $1.footprintDistance }
                } else {
                    // 部分或全部路线计算失败，使用直线距离作为备用
                    var straightLineDistance: CLLocationDistance = 0
                    for i in 0..<coordinates.count - 1 {
                        straightLineDistance += coordinates[i].distance(to: coordinates[i + 1])
                    }
                    self.totalDistance = straightLineDistance
                }
                
                self.isLoadingRoutes = false
                self.lastDestinationsHash = self.destinationsHash
                self.calculationTask = nil
            }
        }
    }
    
    // 从缓存更新总距离（用于响应 RouteManager 路线缓存更新）
    private func updateTotalDistanceFromCache() {
        guard isVisible && destinations.count >= 2 else {
            stopCacheCheckTimer()
            return
        }
        
        // 优先检查 precomputedRoutes（MapView 的计算结果）
        if let precomputedRoutes = precomputedRoutes, !precomputedRoutes.isEmpty {
            let expectedCount = destinations.count - 1
            if precomputedRoutes.count == expectedCount {
                // 路线完整，更新并停止加载状态
                routes = precomputedRoutes
                let newTotalDistance = precomputedRoutes.reduce(0) { $0 + $1.footprintDistance }
                totalDistance = newTotalDistance
                isLoadingRoutes = false
                stopCacheCheckTimer()
                
                // 取消自己的计算任务（如果正在运行）
                calculationTask?.cancel()
                calculationTask = nil
                
                lastDestinationsHash = destinationsHash
                lastPrecomputedRoutesHash = precomputedRoutesHash
                return
            }
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
                // 如果有路线未缓存，启动定期检查机制
                startCacheCheckTimer()
                return
            }
        }
        
        // 所有路线都已缓存，停止定时器并更新总距离
        stopCacheCheckTimer()
        if cachedRoutes.count == coordinates.count - 1 {
            routes = cachedRoutes
            let newTotalDistance = cachedRoutes.reduce(0) { $0 + $1.footprintDistance }
            // 只有当距离发生变化时才更新，避免不必要的视图刷新
            if abs(newTotalDistance - totalDistance) > 1.0 { // 1米的最小变化阈值
                totalDistance = newTotalDistance
            }
            isLoadingRoutes = false
            
            // 取消自己的计算任务（如果正在运行）
            calculationTask?.cancel()
            calculationTask = nil
        }
    }
    
    // 启动定期检查缓存的定时器
    private func startCacheCheckTimer() {
        // 如果定时器已经在运行，不重复启动
        guard cacheCheckTimer == nil else { return }
        
        // RouteCard 是 struct，不需要 weak/unowned，但需要确保在视图消失时停止定时器
        cacheCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            // 通过检查定时器是否仍然有效来判断视图是否还存在
            // 如果 isVisible 为 false，停止定时器
            if !self.isVisible {
                timer.invalidate()
                self.cacheCheckTimer = nil
                return
            }
            self.updateTotalDistanceFromCache()
        }
    }
    
    // 停止定期检查缓存的定时器
    private func stopCacheCheckTimer() {
        cacheCheckTimer?.invalidate()
        cacheCheckTimer = nil
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
    
    // 在Apple Maps中打开旅程（路线规划模式）
    private func openTripInMaps() {
        guard !destinations.isEmpty else { return }
        
        let sortedDestinations = destinations.sorted { $0.visitDate < $1.visitDate }
        
        // 创建所有目的地的MapItem（按访问顺序）
        var mapItems: [MKMapItem] = []
        for destination in sortedDestinations {
            let placemark = MKPlacemark(coordinate: destination.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = destination.name
            mapItems.append(mapItem)
        }
        
        guard !mapItems.isEmpty else { return }
        
        // 配置路线规划启动选项（使用驾车模式，这样会直接打开路线规划界面）
        // "d" = 驾车, "w" = 步行, "t" = 公共交通
        let options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: "d",  // 驾车模式
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ]
        
        if mapItems.count == 1 {
            // 只有一个目的地：打开从当前位置到该地点的路线规划
            mapItems[0].openInMaps(launchOptions: options)
        } else {
            // 多个目的地：创建包含所有停靠点的路线
            // 第一个作为起点，其余作为停靠点和终点
            // Apple Maps会自动处理多停靠点的路线规划，并显示路线界面
            MKMapItem.openMaps(with: mapItems, launchOptions: options)
        }
    }
}

// MARK: - 路线预览卡片组件
/// 显示旅程路线预览信息的卡片组件
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
struct RouteDistanceLabel: View {
    let distance: CLLocationDistance
    let transportType: MKDirectionsTransportType
    let source: CLLocationCoordinate2D?
    let destination: CLLocationCoordinate2D?
    let onTransportTypeChange: ((MKDirectionsTransportType?) -> Void)?
    
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var routeManager = RouteManager.shared
    
    // 兼容旧版本：不传递交通方式信息时使用
    init(distance: CLLocationDistance) {
        self.distance = distance
        self.transportType = .automobile
        self.source = nil
        self.destination = nil
        self.onTransportTypeChange = nil
    }
    
    // 新版本：包含交通方式信息
    init(
        distance: CLLocationDistance,
        transportType: MKDirectionsTransportType,
        source: CLLocationCoordinate2D? = nil,
        destination: CLLocationCoordinate2D? = nil,
        onTransportTypeChange: ((MKDirectionsTransportType?) -> Void)? = nil
    ) {
        self.distance = distance
        self.transportType = transportType
        self.source = source
        self.destination = destination
        self.onTransportTypeChange = onTransportTypeChange
    }
    
    var body: some View {
        // 如果有回调，将整个标签包装在 Menu 中，使整个标签都可以点击
        if let source = source, let destination = destination, let onChange = onTransportTypeChange {
            Menu {
                Button {
                    onChange(nil) // 恢复自动选择
                } label: {
                    Label {
                        Text("auto_select".localized)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
                
                Divider()
                
                Button {
                    onChange(.walking)
                } label: {
                    Label {
                        Text("walking".localized)
                    } icon: {
                        Image(systemName: "figure.walk")
                    }
                }
                
                Button {
                    onChange(.automobile)
                } label: {
                    Label {
                        Text("automobile".localized)
                    } icon: {
                        Image(systemName: "car.fill")
                    }
                }
                
                Button {
                    onChange(.transit)
                } label: {
                    Label {
                        Text("transit".localized)
                    } icon: {
                        Image(systemName: "tram.fill")
                    }
                }
                
                Button {
                    onChange(RouteManager.airplane)
                } label: {
                    Label {
                        Text("airplane".localized)
                    } icon: {
                        Image(systemName: "airplane")
                    }
                }
                
                Button {
                    onChange(RouteManager.none)
                } label: {
                    Label {
                        Text("transport_none".localized)
                    } icon: {
                        Image(systemName: "line.diagonal")
                    }
                }
            } label: {
                // 整个标签作为 Menu 的 label，使整个标签都可以点击
                HStack(spacing: 4) {
                    // 交通方式图标
                    Image(systemName: transportType.iconName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(transportColor(for: transportType))
                        .frame(width: 14, height: 14)
                    
                    // 距离文本
                    Text(formatDistance(distance))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .menuStyle(.borderlessButton) // 使用无边框按钮样式，确保点击响应
        } else {
            // 只显示标签，不可点击
            HStack(spacing: 4) {
                // 交通方式图标
                Image(systemName: transportType.iconName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(transportColor(for: transportType))
                    .frame(width: 14, height: 14)
                
                // 距离文本
                Text(formatDistance(distance))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        RouteManager.formatDistanceForRouteCard(distance, languageManager: languageManager)
    }
    
    private func transportColor(for type: MKDirectionsTransportType) -> Color {
        if type == RouteManager.none {
            return Color(.tertiaryLabel) // 无：浅灰色
        } else if type == RouteManager.airplane {
            return .orange // 飞机使用橙色
        } else if type.contains(.walking) && type == .walking {
            return .green
        } else if type.contains(.automobile) && type == .automobile {
            return .blue
        } else if type.contains(.transit) && type == .transit {
            return .purple
        } else {
            return .gray
        }
    }
}
