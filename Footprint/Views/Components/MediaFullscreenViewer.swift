//
//  MediaFullscreenViewer.swift
//  Footprint
//
//  地点详情媒体全屏预览：照片支持双指缩放/双击放大，视频用系统播放器。
//

import SwiftUI
import AVKit
import AVFoundation

struct MediaFullscreenItem: Identifiable {
    let id: String
    let kind: Kind
    
    enum Kind {
        case photo(Data)
        case video(Data)
    }
}

struct MediaFullscreenViewer: View {
    let items: [MediaFullscreenItem]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    mediaPage(for: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .white.opacity(0.35))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("close".localized)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
        .onAppear {
            let clamped = min(max(currentIndex, 0), max(items.count - 1, 0))
            if clamped != currentIndex {
                currentIndex = clamped
            }
        }
    }
    
    @ViewBuilder
    private func mediaPage(for item: MediaFullscreenItem) -> some View {
        switch item.kind {
        case .photo(let data):
            if let image = UIImage(data: data) {
                ZoomableImageView(image: image)
            } else {
                Color.black
            }
        case .video(let data):
            FullscreenVideoPlayer(data: data)
        }
    }
}

// MARK: - Zoomable Photo

private struct ZoomableImageView: View {
    let image: UIImage
    
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5
    
    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnifyGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if scale > minScale + 0.01 {
                            resetZoom()
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
        }
    }
    
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let next = lastScale * value.magnification
                scale = min(max(next, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale + 0.01 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        resetZoom()
                    }
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale + 0.01 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private func resetZoom() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Video

private struct FullscreenVideoPlayer: View {
    let data: Data
    
    @State private var player: AVPlayer?
    @State private var tempURL: URL?
    
    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear { preparePlayer() }
        .onDisappear { teardownPlayer() }
    }
    
    private func preparePlayer() {
        guard player == nil else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        do {
            try data.write(to: url)
            tempURL = url
            let avPlayer = AVPlayer(url: url)
            player = avPlayer
            avPlayer.play()
        } catch {
            print("Failed to prepare fullscreen video: \(error.localizedDescription)")
        }
    }
    
    private func teardownPlayer() {
        player?.pause()
        player = nil
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            self.tempURL = nil
        }
    }
}
