//
//  DestinationDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import MapKit
import SwiftData
import AVFoundation

struct DestinationDetailView: View {
    let destination: TravelDestination
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @State private var showingEditSheet = false
    @State private var shareItem: TripShareItem?
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedPhotoIndex: Int = 0
    @State private var photosLocal: [Data] = []
    @State private var videoData: Data?
    @State private var videoThumbnail: UIImage?
    @State private var showMediaViewer = false
    @State private var cachedPhotoThumbnails: [UIImage?] = []
    @Environment(\.presentMediaViewer) private var presentMediaViewer
    @State private var showingSelectTrip = false
    @State private var showingShareLayoutSelection = false
    @State private var selectedDestinationLayout: DestinationShareLayout = .photoPoster
    
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
        
        var fullscreenItem: MediaFullscreenItem {
            switch self {
            case .photo(let data, let index):
                return MediaFullscreenItem(id: "photo_\(index)", kind: .photo(data))
            case .video(let data, _):
                return MediaFullscreenItem(id: id, kind: .video(data))
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
            ScrollViewReader { scrollProxy in
                ScrollView {
                    detailContent(geometry: geometry)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 20)
                }
                .onChange(of: selectedPhotoIndex) { _, newIndex in
                    // 查看器翻页时把对应缩略图滚进可视区，关闭 zoom 才能落回正确格子
                    guard showMediaViewer, mediaItems.indices.contains(newIndex) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo(mediaScrollID(newIndex), anchor: .center)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingShareLayoutSelection = true
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
            .sheet(isPresented: $showingShareLayoutSelection) {
                DestinationShareLayoutSelectionView(
                    destination: destination,
                    selectedLayout: $selectedDestinationLayout
                )
            }
            .sheet(isPresented: $showingSelectTrip) {
                SelectOrCreateTripView(destination: destination)
            }
            // 无外层 presenter 时本地 fullScreenCover（列表/旅程等入口）
            .fullScreenCover(isPresented: $showMediaViewer) {
                MediaFullscreenViewer(
                    items: mediaItems.map(\.fullscreenItem),
                    currentIndex: $selectedPhotoIndex,
                    onClose: { showMediaViewer = false }
                )
                .presentationBackground(.clear)
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
        .appPageBackgroundGradient(for: colorScheme)
        // 本地 cover 看图时禁止拖 sheet；地图入口由外层 MediaViewerSession 锁定
        .interactiveDismissDisabled(showMediaViewer)
    }
    
    /// HealthUI 玻璃卡底（iOS 26 glassEffect + Material 降级）
    private var detailCardBackground: some View {
        FootprintGlassBackground(cornerRadius: 18)
    }
    
    @ViewBuilder
    private func detailContent(geometry: GeometryProxy) -> some View {
        let contentWidth = geometry.size.width - 32  // 与 .padding(.horizontal, 16) 一致
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                dateSection
                mediaSection(contentWidth: contentWidth)
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
                        .font(.system(size: 26, weight: .bold, design: .default))
                        .tracking(-0.4)
                        .foregroundStyle(AppColorScheme.primaryText(for: colorScheme))
                    
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
                .font(.headline)
                .foregroundColor(brandColorManager.currentBrandColor)
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
    
    /// 相册式缩略图网格：点按进入全屏查看完整横/竖图
    @ViewBuilder
    private func mediaSection(contentWidth: CGFloat) -> some View {
        Group {
            if !mediaItems.isEmpty {
                let columns = mediaGridColumns(for: mediaItems.count)
                let spacing: CGFloat = 4
                let columnCount = CGFloat(columns.count)
                let cellSide = (contentWidth - spacing * (columnCount - 1)) / columnCount
                
                // 非 Lazy：保持全部缩略图存活，zoom 关闭时 source 始终可解析
                Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                    let columnCount = columns.count
                    let rows = stride(from: 0, to: mediaItems.count, by: columnCount).map { start in
                        Array(mediaItems[start..<min(start + columnCount, mediaItems.count)])
                    }
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowItems in
                        GridRow {
                            ForEach(Array(rowItems.enumerated()), id: \.element.id) { colIndex, item in
                                let index = rowIndex * columnCount + colIndex
                                mediaThumbnailCell(for: item, index: index, side: cellSide)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel(mediaAccessibilityLabel(item))
                            }
                            // 末行补齐空位，避免 Grid 拉伸异常
                            if rowItems.count < columnCount {
                                ForEach(0..<(columnCount - rowItems.count), id: \.self) { _ in
                                    Color.clear.frame(width: cellSide, height: cellSide)
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
                        .frame(height: contentWidth * 2 / 3)
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("no_photo".localized)
                            .foregroundColor(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
                )
            }
        }
        .padding(.top, 8)
    }
    
    private func mediaGridColumns(for count: Int) -> [GridItem] {
        let columnCount: Int
        switch count {
        case 1: columnCount = 1
        case 2, 3, 4: columnCount = 2
        default: columnCount = 3
        }
        return Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount)
    }
    
    private func mediaAccessibilityLabel(_ media: MediaItem) -> String {
        switch media {
        case .photo:
            return "photo".localized
        case .video:
            return "video".localized
        }
    }
    
    @ViewBuilder
    private var tripCard: some View {
        if let trip = destination.trip {
            NavigationLink {
                TripDetailView(trip: trip)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "suitcase.fill")
                        .font(.headline)
                        .foregroundColor(brandColorManager.currentBrandColor)
                        .frame(width: 24, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("belongs_to_trip".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trip.name)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColorScheme.primaryText(for: colorScheme))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { detailCardBackground }
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var notesCard: some View {
        if !destination.notes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.headline)
                        .foregroundColor(brandColorManager.currentBrandColor)
                        .frame(width: 24, alignment: .center)
                    Text("travel_notes".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColorScheme.primaryText(for: colorScheme))
                    Spacer(minLength: 0)
                }
                Text(destination.notes)
                    .font(.body)
                    .foregroundStyle(AppColorScheme.primaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { detailCardBackground }
        }
    }
    
    // 分享地点图片
    private func shareDestination() {
        let destinationImage = ShareImageUtilities.applyingWatermarkIfNeeded(
            TripImageGenerator.generateDestinationImage(from: destination),
            shouldApply: entitlementManager.shouldApplyShareWatermark
        )
        shareItem = TripShareItem(text: "", image: destinationImage)
    }
    
    // 切换喜爱状态
    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            destination.isFavorite.toggle()
            try? modelContext.save()
            DestinationChangeNotifier.postUpdated()
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
        preloadPhotoThumbnails(photoCount: photos.count)
    }
    
    private func preloadPhotoThumbnails(photoCount: Int) {
        guard photoCount > 0 else {
            cachedPhotoThumbnails = []
            return
        }
        let thumbDatas = destination.photoThumbnailDatas
        let singleThumb = destination.photoThumbnailData
        let photos = photosLocal
        // 按详情网格实际格宽降采样主图，避免把 320px 缩略图拉满屏发糊
        let columnCount = CGFloat(mediaGridColumns(for: max(mediaItems.count, photoCount)).count)
        let screen = UIScreen.main
        let contentWidth = max(screen.bounds.width - 32, 1)
        let spacing: CGFloat = 4
        let cellSide = (contentWidth - spacing * (columnCount - 1)) / columnCount
        let maxPixelSize = max(cellSide * screen.scale, 320)
        
        Task.detached(priority: .userInitiated) {
            var images: [UIImage?] = Array(repeating: nil, count: photoCount)
            for index in 0..<photoCount {
                if index < photos.count, !photos[index].isEmpty {
                    let full = photos[index]
                    images[index] = MediaImageDecoder.downsampledImage(data: full, maxPixelSize: maxPixelSize)
                        ?? UIImage(data: full)
                    continue
                }
                let data: Data?
                if index < thumbDatas.count, !thumbDatas[index].isEmpty {
                    data = thumbDatas[index]
                } else if index == 0, let singleThumb, !singleThumb.isEmpty {
                    data = singleThumb
                } else {
                    data = nil
                }
                if let data {
                    images[index] = UIImage(data: data)
                }
            }
            await MainActor.run {
                cachedPhotoThumbnails = images
            }
        }
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
    
    @ViewBuilder
    private func mediaThumbnailCell(for item: MediaItem, index: Int, side: CGFloat) -> some View {
        let corner: CGFloat = mediaItems.count == 1 ? 18 : 10
        ZStack {
            switch item {
            case .photo(_, let photoIndex):
                if let thumb = photoThumbnailImage(at: photoIndex) {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: side, height: side)
                }
            case .video(_, let thumbnail):
                Group {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: side, height: side)
                    }
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: min(36, side * 0.28)))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
            }
            
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        )
        .id(mediaScrollID(index))
        .onTapGesture {
            openFullscreenMedia(at: index)
        }
    }
    
    private func openFullscreenMedia(at index: Int) {
        selectedPhotoIndex = index
        let items = mediaItems.map(\.fullscreenItem)
        if let presentMediaViewer {
            // 地图：提到 sheet 外层呈现，地点 sheet 保持不动
            presentMediaViewer(items, index: index)
        } else {
            showMediaViewer = true
        }
    }
    
    private func mediaScrollID(_ index: Int) -> String {
        "media_thumb_\(index)"
    }
    
    /// 网格只用缓存缩略图，避免 body 刷新时反复解码
    private func photoThumbnailImage(at index: Int) -> UIImage? {
        if index < cachedPhotoThumbnails.count, let cached = cachedPhotoThumbnails[index] {
            return cached
        }
        return nil
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
    .environmentObject(BrandColorManager.shared)
    .environmentObject(EntitlementManager.shared)
    .environmentObject(AICreditManager.shared)
}

