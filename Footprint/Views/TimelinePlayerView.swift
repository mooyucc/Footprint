//
//  TimelinePlayerView.swift
//  Footprint
//
//  Created by K.X on 2025/01/XX.
//

import SwiftUI
import MapKit
import SwiftData
import Combine
import CoreLocation

/// 时间轴播放速度
enum PlaybackSpeed: Double, CaseIterable {
    case slow = 0.5
    case normal = 1.0
    case fast = 2.0
    case veryFast = 5.0
    
    var displayName: String {
        switch self {
        case .slow:
            return "0.5x"
        case .normal:
            return "1x"
        case .fast:
            return "2x"
        case .veryFast:
            return "5x"
        }
    }
    
    var interval: TimeInterval {
        // 每个目的地显示的间隔时间（秒）
        switch self {
        case .slow:
            return 2.0
        case .normal:
            return 1.0
        case .fast:
            return 0.5
        case .veryFast:
            return 0.2
        }
    }
}

/// 时间轴播放器状态
class TimelinePlayerState: ObservableObject {
    @Published var isPlaying = false
    @Published var currentIndex = 0
    @Published var playbackSpeed: PlaybackSpeed = .normal
    @Published var sortedDestinations: [TravelDestination] = []
    @Published var visibleDestinations: Set<UUID> = []
    @Published var currentDestination: TravelDestination?
    @Published var autoFollowCamera = false  // false=智能跟随（适中范围，1500km），true=精确跟随（近距离，50km）
    @Published var hasInitializedView = false  // 标记是否已初始化视图
    @Published var smoothProgress: Double = 0.0  // 平滑的进度值（0.0-1.0）
    
    var progressTimer: Timer?
    var lastUpdateTime: Date?
    var progressStartTime: Date?
    var lastCameraCenter: CLLocationCoordinate2D?  // 记录上一次相机中心位置
    
    var progress: Double {
        guard !sortedDestinations.isEmpty else { return 0 }
        return Double(currentIndex) / Double(sortedDestinations.count)
    }
    
    var currentDate: Date? {
        currentDestination?.visitDate
    }
    
    func reset() {
        currentIndex = 0
        visibleDestinations.removeAll()
        currentDestination = nil
        isPlaying = false
        hasInitializedView = false
        smoothProgress = 0.0
        progressTimer?.invalidate()
        progressTimer = nil
        lastUpdateTime = nil
        progressStartTime = nil
    }
    
    func goToIndex(_ index: Int) {
        let clampedIndex = min(max(0, index), sortedDestinations.count - 1)
        currentIndex = clampedIndex
        
        if clampedIndex > 0 {
            visibleDestinations = Set(sortedDestinations.prefix(clampedIndex).map { $0.id })
            currentDestination = sortedDestinations[clampedIndex - 1]
        } else {
            visibleDestinations.removeAll()
            currentDestination = nil
        }
    }
}

struct TimelinePlayerView: View {
    @ObservedObject var playerState: TimelinePlayerState
    @StateObject private var languageManager = LanguageManager.shared
    @State private var playbackTimer: Timer?
    var onCameraMove: ((MapCameraPosition) -> Void)?
    var isCoordinateVisible: ((CLLocationCoordinate2D) -> Bool)?  // 检查坐标是否在当前视图范围内
    
    var body: some View {
        VStack(spacing: 0) {
            // 时间信息卡片
            if let date = playerState.currentDate {
                timeInfoCard(date: date)
            }
            
            // 播放控制栏
            playbackControlBar
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .padding(.bottom, 20)
        .onDisappear {
            stopPlayback()
        }
    }
    
    // MARK: - 时间信息卡片
    private func timeInfoCard(date: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(date))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let destination = playerState.currentDestination {
                    Text(destination.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(playerState.currentIndex) / \(playerState.sortedDestinations.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if playerState.currentIndex > 0 {
                    let progress = Int(playerState.progress * 100)
                    Text("\(progress)%")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground).opacity(0.8))
        )
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    // MARK: - 播放控制栏
    private var playbackControlBar: some View {
        VStack(spacing: 12) {
            // 进度滑块（使用平滑进度值，让进度条更流畅）
            if !playerState.sortedDestinations.isEmpty {
                Slider(
                    value: Binding(
                        get: { playerState.isPlaying ? playerState.smoothProgress : playerState.progress },
                        set: { newValue in
                            // 用户拖动时暂停播放
                            if playerState.isPlaying {
                                stopPlayback()
                            }
                            
                            let index = Int(newValue * Double(playerState.sortedDestinations.count))
                            playerState.goToIndex(index)
                            playerState.smoothProgress = newValue
                            
                            if let dest = playerState.currentDestination, playerState.autoFollowCamera {
                                followDestinationSmoothly(dest)
                            }
                        }
                    ),
                    in: 0...1.0
                )
                .tint(.blue)
            }
            
            HStack(spacing: 16) {
                // 重置按钮
                Button {
                    resetPlayback()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // 播放/暂停按钮
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                
                // 速度选择
                Menu {
                    ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                        Button {
                            playerState.playbackSpeed = speed
                            restartTimerIfNeeded()
                        } label: {
                            HStack {
                                Text(speed.displayName)
                                if playerState.playbackSpeed == speed {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(playerState.playbackSpeed.displayName)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(22)
                }
                
                Spacer()
                
                // 相机跟随模式切换
                // false = 智能跟随（适中范围，默认，1500km，可以看到周围已出现的足迹）
                // true = 精确跟随（近距离，50km，更聚焦当前地点）
                Button {
                    playerState.autoFollowCamera.toggle()
                    if let dest = playerState.currentDestination {
                        if playerState.autoFollowCamera {
                            // 切换到精确跟随模式
                            followDestinationSmoothly(dest)
                        } else {
                            // 切换回智能跟随模式（默认）
                            centerOnDestination(dest, withReasonableRange: true)
                        }
                    }
                } label: {
                    Image(systemName: playerState.autoFollowCamera ? "scope" : "location")
                        .font(.title3)
                        .foregroundColor(playerState.autoFollowCamera ? .blue : .secondary)
                        .frame(width: 44, height: 44)
                        .background((playerState.autoFollowCamera ? Color.blue : Color.gray).opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
    }
    
    // MARK: - 播放控制方法
    private func togglePlayback() {
        if playerState.isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        guard !playerState.sortedDestinations.isEmpty else { return }
        
        // 如果已经到末尾，重置
        if playerState.currentIndex >= playerState.sortedDestinations.count {
            playerState.currentIndex = 0
            playerState.visibleDestinations.removeAll()
            playerState.currentDestination = nil
            playerState.hasInitializedView = false
        }
        
        // 首次播放时，调整视图到第一个地点（使用适中范围）
        if !playerState.hasInitializedView && playerState.currentIndex == 0 {
            if let firstDestination = playerState.sortedDestinations.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.centerOnDestination(firstDestination, withReasonableRange: true)
                }
            }
            playerState.hasInitializedView = true
        }
        
        playerState.isPlaying = true
        playerState.progressStartTime = Date()
        playerState.lastUpdateTime = Date()
        playerState.smoothProgress = playerState.progress
        
        // 启动平滑进度更新
        startSmoothProgressUpdate()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: playerState.playbackSpeed.interval, repeats: true) { [weak playerState] timer in
            guard let state = playerState else {
                timer.invalidate()
                return
            }
            
            if state.currentIndex < state.sortedDestinations.count {
                let destination = state.sortedDestinations[state.currentIndex]
                
                // 添加到可见集合（使用动画包装，让出现效果更丝滑）
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    state.visibleDestinations.insert(destination.id)
                    state.currentDestination = destination
                }
                
                // 自动跟随当前地点（智能模式：只在明显超出范围时移动）
                DispatchQueue.main.async {
                    // 方法1：检查地点是否已经在当前视图范围内
                    var shouldMoveView = true  // 默认需要移动
                    
                    // 方法2：如果上次移动的中心位置与当前地点距离很近，也不需要移动
                    if let lastCenter = state.lastCameraCenter {
                        let location1 = CLLocation(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude)
                        let location2 = CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude)
                        let distance = location1.distance(from: location2)
                        // 如果距离小于700km（小于1500km范围的一半），说明地点在上次视图范围内
                        if distance < 700000 {  // 700km
                            shouldMoveView = false
                        }
                    }
                    
                    // 如果距离检查通过，再用视图范围检查作为双重保险
                    if shouldMoveView, let isVisible = self.isCoordinateVisible {
                        let isInView = isVisible(destination.coordinate)
                        shouldMoveView = !isInView
                    }
                    // 如果无法检查（visibleRegion未初始化且没有上次位置），默认移动
                    
                    // 只有在确实需要移动时才移动地图
                    if shouldMoveView {
                        if !state.autoFollowCamera {
                            // 默认模式：智能跟随，使用适中范围
                            self.centerOnDestination(destination, withReasonableRange: true)
                            // 记录移动后的中心位置
                            state.lastCameraCenter = destination.coordinate
                        } else {
                            // 用户开启的精确跟随模式
                            self.followDestinationSmoothly(destination)
                            state.lastCameraCenter = destination.coordinate
                        }
                    }
                    // 如果地点已在视图内，则不移动地图，保持稳定
                }
                
                state.currentIndex += 1
                state.lastUpdateTime = Date()
            } else {
                // 播放完毕
                state.smoothProgress = 1.0
                stopPlayback()
            }
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        playerState.progressTimer?.invalidate()
        playerState.progressTimer = nil
        playerState.isPlaying = false
    }
    
    // 启动平滑进度更新
    private func startSmoothProgressUpdate() {
        guard !playerState.sortedDestinations.isEmpty else { return }
        
        let updateInterval: TimeInterval = 0.05  // 每50ms更新一次，让进度条更流畅
        
        playerState.progressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak playerState] timer in
            guard let state = playerState, state.isPlaying else {
                timer.invalidate()
                return
            }
            
            guard let lastUpdate = state.lastUpdateTime else {
                return
            }
            
            let elapsed = Date().timeIntervalSince(lastUpdate)
            let totalInterval = state.playbackSpeed.interval
            
            // 计算当前应该显示到第几个地点（带平滑过渡）
            let currentProgress = Double(state.currentIndex) / Double(state.sortedDestinations.count)
            let nextProgress = state.currentIndex < state.sortedDestinations.count ? 
                Double(state.currentIndex + 1) / Double(state.sortedDestinations.count) : currentProgress
            
            // 在当前进度和下一个进度之间插值，让进度条平滑过渡
            let progressRatio = min(elapsed / totalInterval, 1.0)
            state.smoothProgress = currentProgress + (nextProgress - currentProgress) * progressRatio
        }
    }
    
    private func resetPlayback() {
        stopPlayback()
        playerState.reset()
        
        // 重置地图视图
        withAnimation(.easeOut(duration: 1.0)) {
            onCameraMove?(.automatic)
        }
    }
    
    private func restartTimerIfNeeded() {
        if playerState.isPlaying {
            stopPlayback()
            startPlayback()
        }
    }
    
    // 平滑跟随单个目的地（用于精确跟随模式，距离较近）
    private func followDestinationSmoothly(_ destination: TravelDestination) {
        let coordinate = destination.coordinate
        let cameraPosition = MapCameraPosition.camera(
            MapCamera(
                centerCoordinate: coordinate,
                distance: 50000, // 50km
                heading: 0,
                pitch: 0
            )
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            onCameraMove?(cameraPosition)
        }
    }
    
    // 以适中范围居中显示目的地（默认模式）
    // 使用合理的视图范围，让用户既能看清当前地点，又能看到周围已出现的足迹
    private func centerOnDestination(_ destination: TravelDestination, withReasonableRange: Bool) {
        let coordinate = destination.coordinate
        
        // 适中范围：约1500km，这样可以看到当前地点及周围更大区域
        // 相当于可以看到一个大国家或大洲的一部分范围
        let reasonableDistance: Double = 1500000  // 1500km
        
        // 计算合理的跨度（约1500km对应约13.5度）
        let span: Double = reasonableDistance / 111000.0  // 1度约111km
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        
        let cameraPosition = MapCameraPosition.region(region)
        
        // 使用平滑但不太慢的动画，让视图跟随自然
        withAnimation(.easeInOut(duration: 0.6)) {
            onCameraMove?(cameraPosition)
        }
    }
    
    // MARK: - 辅助方法
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage == .chinese ? "zh_CN" : "en_US")
        
        if languageManager.currentLanguage == .chinese {
            formatter.dateFormat = "yyyy年M月d日"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        
        return formatter.string(from: date)
    }
}

