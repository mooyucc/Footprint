//
//  DestinationDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import MapKit
import SwiftData
import AVKit
import AVFoundation

struct DestinationDetailView: View {
    let destination: TravelDestination
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @State private var showingEditSheet = false
    @State private var shareItem: TripShareItem?
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedPhotoIndex: Int = 0
    @State private var photosLocal: [Data] = []
    @State private var videoData: Data?
    @State private var videoThumbnail: UIImage?
    @State private var showVideoPlayer = false
    @State private var videoURL: URL?
    @State private var showingSelectTrip = false
    @State private var showingAINotePreview = false
    
    // 媒体项类型：照片或视频
    enum MediaItem: Identifiable {
        case photo(Data, Int)
        case video(Data, UIImage?)
        
        var id: String {
            switch self {
            case .photo(_, let index):
                return "photo_\(index)"
            case .video(let data, _):
                return "video_\(data.hashValue)"
            }
        }
    }
    
    @State private var mediaItems: [MediaItem] = []
    
    init(destination: TravelDestination) {
        self.destination = destination
        _cameraPosition = State(initialValue: .camera(
            MapCamera(
                centerCoordinate: destination.coordinate,
                distance: 10000,
                heading: 0,
                pitch: 0
            )
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                detailContent(geometry: geometry)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            shareDestination()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                        
                        Button {
                            toggleFavorite()
                        } label: {
                            Image(systemName: destination.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(destination.isFavorite ? .red : .primary)
                        }
                        
                        Button {
                            showingAINotePreview = true
                        } label: {
                            Image(systemName: "sparkles")
                                .foregroundColor(.primary)
                        }
                        .disabled(!canUseAI)
                        .opacity(canUseAI ? 1.0 : 0.5)
                        
                        Button {
                            showingSelectTrip = true
                        } label: {
                            Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.filled.scurvepath")
                                .foregroundColor(.primary)
                        }
                        
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditDestinationView(destination: destination)
            }
            .sheet(item: $shareItem) { item in
                if let image = item.image {
                    // 只分享图片，不分享文字（因为所有信息都已经包含在图片中）
                    SystemShareSheet(items: [image])
                } else {
                    SystemShareSheet(items: [item.text])
                }
            }
            .sheet(isPresented: $showingSelectTrip) {
                SelectOrCreateTripView(destination: destination)
            }
            .sheet(isPresented: $showingAINotePreview) {
                AINotePreviewSheet(destination: destination)
            }
            .sheet(isPresented: $showVideoPlayer) {
                if let videoURL = videoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .ignoresSafeArea()
                }
            }
            .onAppear {
                loadMediaItems()
            }
            .onChange(of: destination.photoDatas) { _, _ in
                loadMediaItems()
            }
            .onChange(of: destination.videoData) { _, _ in
                loadMediaItems()
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // 语言变化时刷新界面
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { notification in
                // 当地点被删除时，如果删除的是当前地点，则关闭详情页
                if let userInfo = notification.userInfo,
                   let deletedDestinationId = userInfo["destinationId"] as? UUID,
                   destination.id == deletedDestinationId {
                    dismiss()
                } else if notification.userInfo?["destinationId"] == nil {
                    // 如果是批量删除（没有 destinationId），也关闭详情页
                    dismiss()
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailContent(geometry: GeometryProxy) -> some View {
        let contentWidth = geometry.size.width - 32  // 与 .padding(.horizontal, 16) 一致
        let imageHeight = contentWidth * 2 / 3
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                dateSection
                mediaSection(imageHeight: imageHeight, contentWidth: contentWidth)
                tripCard
                notesCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(destination.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                }
                
                if !destination.province.isEmpty {
                    HStack(spacing: 4) {
                        Text(destination.province)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(destination.country)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(destination.country)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
    
    private var dateSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.visitDate.localizedFormatted(dateStyle: .full))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(destination.visitDate.localizedFormatted(dateStyle: .none, timeStyle: .short))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private func mediaSection(imageHeight: CGFloat, contentWidth: CGFloat) -> some View {
        Group {
            if !mediaItems.isEmpty {
                let selectedIndex = min(selectedPhotoIndex, mediaItems.count - 1)
                let selectedMedia = mediaItems[selectedIndex]
                VStack(spacing: 10) {
                    mainMediaView(selectedMedia: selectedMedia, imageHeight: imageHeight, contentWidth: contentWidth)
                    if mediaItems.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                                    mediaThumbnailView(for: item, index: index, isSelected: index == selectedIndex)
                                        .onTapGesture {
                                            selectedPhotoIndex = index
                                        }
                                }
                            }
                        }
                    }
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(destination.normalizedCategory == "domestic" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: contentWidth)
                        .frame(height: imageHeight)
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("no_photo".localized)
                            .foregroundColor(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func mainMediaView(selectedMedia: MediaItem, imageHeight: CGFloat, contentWidth: CGFloat) -> some View {
        Group {
            switch selectedMedia {
            case .photo(let data, _):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: contentWidth)
                        .frame(height: imageHeight)
                        .clipped()
                }
            case .video(_, let thumbnail):
                ZStack {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: contentWidth)
                            .frame(height: imageHeight)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: imageHeight)
                    }
                    Button {
                        playVideo(for: selectedMedia)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 80, height: 80)
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                    }
                }
                .cornerRadius(12)
            }
        }
        .frame(width: contentWidth, height: imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    @ViewBuilder
    private var tripCard: some View {
        if let trip = destination.trip {
            NavigationLink {
                TripDetailView(trip: trip)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "suitcase.fill")
                        .font(.body)
                        .foregroundColor(.purple)
                        .frame(width: 24, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("belongs_to_trip".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trip.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var notesCard: some View {
        if !destination.notes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.body)
                        .foregroundColor(.orange)
                        .frame(width: 24, alignment: .center)
                    Text("travel_notes".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer(minLength: 0)
                }
                Text(destination.notes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // 检查是否有权限使用AI功能
    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    // 分享地点图片
    private func shareDestination() {
        // 生成地点分享图片
        let destinationImage = TripImageGenerator.generateDestinationImage(from: destination)
        // 只分享图片，不分享文字（因为所有信息都已经包含在图片中）
        shareItem = TripShareItem(text: "", image: destinationImage)
    }
    
    // 切换喜爱状态
    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            destination.isFavorite.toggle()
            try? modelContext.save()
        }
    }
    
    // 加载媒体项（照片和视频）
    private func loadMediaItems() {
        var items: [MediaItem] = []
        
        // 加载照片
        let photos = !destination.photoDatas.isEmpty ? destination.photoDatas : (destination.photoData.map { [$0] } ?? [])
        photosLocal = photos
        for (index, photoData) in photos.enumerated() {
            items.append(.photo(photoData, index))
        }
        
        // 加载视频
        if let video = destination.videoData {
            videoData = video
            generateVideoThumbnail(video)
            items.append(.video(video, nil)) // 缩略图稍后更新
        }
        
        mediaItems = items
    }
    
    // 生成视频缩略图
    private func generateVideoThumbnail(_ data: Data) {
        Task {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            
            do {
                try data.write(to: tempURL)
                defer {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                let asset = AVAsset(url: tempURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                let result = try await imageGenerator.image(at: .zero)
                let cgImage = result.image
                let thumbnail = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    self.videoThumbnail = thumbnail
                    // 更新媒体项中的视频缩略图
                    if let index = mediaItems.firstIndex(where: {
                        if case .video = $0 { return true }
                        return false
                    }) {
                        if case .video(let videoData, _) = mediaItems[index] {
                            mediaItems[index] = .video(videoData, thumbnail)
                        }
                    }
                }
            } catch {
                print("Failed to generate video thumbnail: \(error.localizedDescription)")
            }
        }
    }
    
    // 媒体缩略图视图
    @ViewBuilder
    private func mediaThumbnailView(for item: MediaItem, index: Int, isSelected: Bool) -> some View {
        Group {
            switch item {
            case .photo(let data, _):
                if let thumb = UIImage(data: data) {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(8)
                }
            case .video(_, let thumbnail):
                ZStack {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 70, height: 70)
                    }
                    
                    // 视频标识
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                }
                .cornerRadius(8)
            }
        }
    }
    
    // 播放视频
    private func playVideo(for media: MediaItem) {
        if case .video(let data, _) = media {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            
            do {
                try data.write(to: tempURL)
                videoURL = tempURL
                showVideoPlayer = true
            } catch {
                print("Failed to create temporary video file: \(error.localizedDescription)")
            }
        }
    }
}

// 详情页已移除拖拽排序能力，排序请前往编辑页处理


#Preview {
    NavigationStack {
        DestinationDetailView(destination: TravelDestination(
            name: "雷克雅未克",
            country: "冰岛",
            latitude: 64.1466,
            longitude: -21.9426,
            visitDate: Date(),
            notes: "美丽的北极光和温泉体验",
            category: "international",
            isFavorite: true
        ))
    }
}

