//
//  VideoSelectionSection.swift
//  Footprint
//
//  Created by K.X on 2025/01/XX.
//

import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

/// 可复用的视频选择组件
/// 限制：只能选择1段视频，视频时长不超过10秒
struct VideoSelectionSection: View {
    @Binding var videoData: Data?
    @State private var selectedVideo: [PhotosPickerItem] = []
    @State private var showVideoError = false
    @State private var videoErrorMessage = ""
    @State private var videoThumbnail: UIImage?
    
    private let maxDurationSeconds: Double = 10.0
    
    var body: some View {
        Section("video".localized) {
            videoPickerButton
            if let videoData = videoData, let thumbnail = videoThumbnail {
                videoPreviewView(videoData: videoData, thumbnail: thumbnail)
            }
        }
        .onChange(of: selectedVideo) { oldValue, newValue in
            handleVideoSelection(newValue)
        }
        .onChange(of: videoData) { oldValue, newValue in
            handleVideoDataChange(oldValue: oldValue, newValue: newValue)
        }
        .onAppear {
            handleOnAppear()
        }
        .alert("video_error".localized, isPresented: $showVideoError) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text(videoErrorMessage)
        }
    }
    
    private var videoPickerButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            PhotosPicker(
                selection: $selectedVideo,
                maxSelectionCount: 1,
                matching: .videos
            ) {
                HStack {
                    Image(systemName: "video")
                        .foregroundColor(Color.footprintRed)
                    Text("select_video".localized)
                        .foregroundColor(.primary)
                }
            }
            
            Text("video_limit_hint".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func videoPreviewView(videoData: Data, thumbnail: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            videoThumbnailView(thumbnail: thumbnail)
            videoPreviewFooter
        }
        .padding(.vertical, 4)
    }
    
    private func videoThumbnailView(thumbnail: UIImage) -> some View {
        ZStack(alignment: .center) {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
            
            // 播放图标覆盖层
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 60, height: 60)
            
            Image(systemName: "play.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        }
    }
    
    private var videoPreviewFooter: some View {
        HStack {
            Spacer()
            
            Button {
                removeVideo()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("delete".localized)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
    
    private func handleVideoSelection(_ newValue: [PhotosPickerItem]) {
        if let videoItem = newValue.first {
            loadVideo(from: videoItem)
        }
    }
    
    private func handleVideoDataChange(oldValue: Data?, newValue: Data?) {
        // 当 videoData 从外部更新时（如编辑模式下加载已有视频），生成缩略图
        if let newValue = newValue, videoThumbnail == nil {
            generateThumbnailFromData(newValue)
        } else if newValue == nil {
            // 如果 videoData 被清空，同时清空缩略图
            videoThumbnail = nil
        }
    }
    
    private func handleOnAppear() {
        // 组件出现时，如果已有 videoData 但没有缩略图，生成缩略图
        if let data = videoData, videoThumbnail == nil {
            generateThumbnailFromData(data)
        }
    }
    
    private func loadVideo(from item: PhotosPickerItem) {
        Task {
            do {
                // 获取视频数据
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        showVideoError(message: "video_load_failed".localized)
                    }
                    return
                }
                
                // 创建临时文件来检查视频时长
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                
                try data.write(to: tempURL)
                defer {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                // 检查视频时长
                let asset = AVAsset(url: tempURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                if durationSeconds > maxDurationSeconds {
                    await MainActor.run {
                        showVideoError(message: "video_too_long".localized(with: Int(maxDurationSeconds)))
                        selectedVideo = []
                    }
                    return
                }
                
                // 生成视频缩略图
                let thumbnail = await generateThumbnail(from: asset)
                
                await MainActor.run {
                    self.videoData = data
                    self.videoThumbnail = thumbnail
                }
            } catch {
                await MainActor.run {
                    showVideoError(message: error.localizedDescription)
                    selectedVideo = []
                }
            }
        }
    }
    
    private func generateThumbnail(from asset: AVAsset) async -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let result = try await imageGenerator.image(at: .zero)
            let cgImage = result.image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    
    private func generateThumbnailFromData(_ data: Data) {
        Task {
            // 创建临时文件来生成缩略图
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            
            do {
                try data.write(to: tempURL)
                defer {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                let asset = AVAsset(url: tempURL)
                let thumbnail = await generateThumbnail(from: asset)
                
                await MainActor.run {
                    self.videoThumbnail = thumbnail
                }
            } catch {
                // 如果生成缩略图失败，静默失败（不影响功能）
                print("Failed to generate video thumbnail: \(error.localizedDescription)")
            }
        }
    }
    
    private func removeVideo() {
        videoData = nil
        videoThumbnail = nil
        selectedVideo = []
    }
    
    private func showVideoError(message: String) {
        videoErrorMessage = message
        showVideoError = true
    }
}

#Preview {
    Form {
        VideoSelectionSection(videoData: .constant(nil))
    }
}

