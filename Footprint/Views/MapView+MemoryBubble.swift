//
//  MapView+MemoryBubble.swift
//  Footprint
//
//  从 MapView.swift 拆分（编译加速）
//

import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import Combine
import AudioToolbox
import UIKit
import PhotosUI
import Photos
import ImageIO
import Contacts

extension MapView {
    var memoryBubbleOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                if showSoapBubbles,
                   !autoShowRouteCards,
                   !isThermallyCritical,
                   let destination = selectedBubbleDestination,
                   let region = visibleRegion ?? regionHolder.pending {
                    LocationWaterRipple(
                        region: region,
                        coordinate: destination.coordinate,
                        canvasSize: geometry.size,
                        mapStyle: currentMapStyle,
                        interfaceStyle: colorScheme == .dark ? .dark : .light,
                        onComplete: {
                            finishRippleVisual()
                        }
                    ) {
                        ripplePin(for: destination)
                    }
                    .id(soapBubblesID)
                    .zIndex(1000)
                }
            }
        }
        .background {
            if showSoapBubbles {
                Color.clear
                    .contentShape(Rectangle())
            }
        }
        .allowsHitTesting(showSoapBubbles)
    }

    /// 波纹期间不改 Map 的 allowsHitTesting，避免标注层被拆掉。用手势遮罩挡住拖动。
    func finishRippleVisual() {
        if let destination = selectedBubbleDestination {
            pinDestinationInClusters(destination)
        }
        showSoapBubbles = false
        releaseRipplePinIfClustered()
    }

    /// 聚类里已经有这枚单独标注后，再撤掉回忆流程的临时针。
    func releaseRipplePinIfClustered() {
        guard !showSoapBubbles, let destination = selectedBubbleDestination else { return }
        if isCalculatingClusters {
            return
        }
        let clustered = cachedClusterAnnotations.contains {
            $0.destinations.count == 1 && $0.destinations[0].id == destination.id
        }
        guard clustered else {
            scheduleClusterRecalculationIfNeeded()
            return
        }
        selectedBubbleDestination = nil
    }

    /// 把目标地点放进当前聚类结果，保证波纹结束后地图上仍有这枚针。
    func pinDestinationInClusters(_ destination: TravelDestination) {
        var clusters = cachedClusterAnnotations.compactMap { cluster -> ClusterAnnotation? in
            let remaining = cluster.destinations.filter { $0.id != destination.id }
            guard !remaining.isEmpty else { return nil }
            if remaining.count == cluster.destinations.count {
                return cluster
            }
            return ClusterAnnotation(destinations: remaining, displayType: cluster.displayType)
        }
        let alreadySingle = clusters.contains {
            $0.destinations.count == 1 && $0.destinations[0].id == destination.id
        }
        if !alreadySingle {
            clusters.append(ClusterAnnotation(destinations: [destination]))
        }
        cachedClusterAnnotations = clusters
    }

    func reinforceRippleDestinationPin() {
        guard let destination = selectedBubbleDestination ?? targetBubbleDestination else { return }
        pinDestinationInClusters(destination)
    }

    /// 波纹盖住地图标注时，把同一枚针画在透镜上面，圆心不跟着被折射。
    func ripplePin(for destination: TravelDestination) -> some View {
        ZStack {
            ClusterAnnotationView(
                cluster: ClusterAnnotation(destinations: [destination]),
                zoomLevel: currentZoomLevel,
                tripColorMap: tripColorMapping,
                accentColor: brandAccentColor,
                weatherSummary: nil,
                mapMode: .myFootprints
            )
            Text(destination.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .shadow(color: .white.opacity(0.9), radius: 1.5)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                .offset(y: 34)
        }
        .allowsHitTesting(false)
    }
    
    // 地图地点标注弹窗覆盖层
    @ViewBuilder
    var destinationCalloutOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                if let destination = selectedDestination {
                    // 计算地点在地图上的屏幕坐标
                    let screenPoint = convertCoordinateToScreenPoint(destination.coordinate, in: geometry.size)
                    
                    // 弹窗显示在标注上方，向上偏移约100点
                    let calloutPosition = CGPoint(
                        x: screenPoint.x,
                        y: screenPoint.y - 100
                    )
                    
                    MapDestinationCalloutView(
                        destination: destination,
                        onTap: {
                            // 点击弹窗时打开详情页
                            detailDestinationForSheet = destination
                        },
                        userProfileManager: UserProfileManager.shared
                    )
                    .position(x: calloutPosition.x, y: calloutPosition.y)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedDestination?.id)
                    .zIndex(999) // 确保在标注上方
                }
            }
        }
        .allowsHitTesting(true)
    }
    
    // 触发回忆泡泡
    func triggerMemoryBubble() {
        Task {
            let randomDestination = await MainActor.run {
                MapDestinationFetcher.fetchRandom(in: modelContext)
            }

            guard let randomDestination else {
                await MainActor.run {
                    print("🫧 没有地点可以显示回忆泡泡")
                }
                return
            }

            await MainActor.run {
                targetBubbleDestination = randomDestination
                waitingForMapToReachDestination = true

                let zoomRegion = MKCoordinateRegion(
                    center: randomDestination.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)
                )

                withAnimation(.easeInOut(duration: 0.8)) {
                    mapCameraPosition = .region(zoomRegion)
                }

                print("🫧 地图 Zoom in 到地点: \(randomDestination.name)")
                print("🫧 等待地图到达地点后荡开水波...")

                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if waitingForMapToReachDestination {
                        print("🫧 超时保护：强制触发水波动画")
                        self.checkAndTriggerBubbles()
                    }
                }
            }
        }
    }
    
    // 处理AI助手功能
    func handleAIAssistant() {
        print("🤖 点击AI助手按钮")
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        hasUsedMapAIAssistant = true
        
        // 切换AI助手界面显示状态
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingAIAssistant.toggle()
        }
    }
    
    // 检查地图是否已到达目标地点，如果到达则从地点荡开水波
    func checkAndTriggerBubbles() {
        guard waitingForMapToReachDestination,
              let target = targetBubbleDestination,
              let currentRegion = visibleRegion ?? regionHolder.pending else {
            return
        }
        
        // 计算目标地点与当前视野中心的距离
        let targetCoord = target.coordinate
        let centerCoord = currentRegion.center
        
        // 计算距离（使用简单的经纬度差值，约111km/度）
        let latDiff = abs(targetCoord.latitude - centerCoord.latitude)
        let lonDiff = abs(targetCoord.longitude - centerCoord.longitude)
        
        // 检查是否在视野范围内（允许一些误差，约1km）
        let latSpan = currentRegion.span.latitudeDelta
        let lonSpan = currentRegion.span.longitudeDelta
        
        // 如果地点在视野中心附近（距离中心小于视野范围的20%），认为已到达
        let isNearCenter = latDiff < latSpan * 0.2 && lonDiff < lonSpan * 0.2
        
        if isNearCenter {
            print("🫧 地图已到达地点，触发水波动画")
            waitingForMapToReachDestination = false
            targetBubbleDestination = nil
            
            // 触发水波：先把地点钉进聚类，结束时地图上还留着这枚针
            pinDestinationInClusters(target)
            selectedBubbleDestination = target
            showSoapBubbles = true
            soapBubblesID = UUID()
        }
    }
    
    
    // 将坐标转换为屏幕坐标
    func convertCoordinateToScreenPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        // 这里需要根据当前地图的可见区域来计算屏幕坐标
        // 由于MapKit的复杂性，我们使用一个简化的方法
        // 在实际应用中，可能需要使用MapProxy来获取准确的屏幕坐标
        
        guard let region = visibleRegion else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        let span = region.span
        let center = region.center
        
        // 计算相对位置
        let latRatio = (coordinate.latitude - center.latitude + span.latitudeDelta / 2) / span.latitudeDelta
        let lonRatio = (coordinate.longitude - center.longitude + span.longitudeDelta / 2) / span.longitudeDelta
        
        // 转换为屏幕坐标
        let x = lonRatio * size.width
        let y = (1 - latRatio) * size.height // 翻转Y轴，因为屏幕坐标系Y轴向下
        
        return CGPoint(x: x, y: y)
    }
    
    // 播放泡泡音效
    func playBubbleSound() {
        // 使用系统音效
        AudioServicesPlaySystemSound(1104) // 气泡音效
    }
    
    // 播放轻泡泡音效（用于动画过程中）
    func playLightBubbleSound() {
        // 使用较轻的系统音效（音量较低，用于连续播放）
        // 使用音效 1103 (轻微点击) 或 1104 (气泡)，但音量较低
        AudioServicesPlaySystemSound(1103) // 轻微点击音效，较轻
    }
    
    // 播放Q弹泡泡音效（变体1）
    func playBubblePopSound1() {
        AudioServicesPlaySystemSound(1104) // 气泡音效
    }
    
    // 播放Q弹泡泡音效（变体2）
    func playBubblePopSound2() {
        AudioServicesPlaySystemSound(1103) // 轻微点击音效
    }
    
    // 播放Q弹泡泡音效（变体3）
    func playBubblePopSound3() {
        AudioServicesPlaySystemSound(1057) // 消息接收音效（较轻的提示音）
    }
    
    // 播放点击音效
    func playTapSound() {
        // 使用系统音效
        AudioServicesPlaySystemSound(1105) // 点击音效
    }
    
}
