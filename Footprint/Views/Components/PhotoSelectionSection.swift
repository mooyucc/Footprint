//
//  PhotoSelectionSection.swift
//  Footprint
//
//  Created by K.X on 2025/11/26.
//

import SwiftUI
import PhotosUI
import UIKit

/// 可复用的照片选择组件
struct PhotoSelectionSection: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var photoDatas: [Data]
    @Binding var photoThumbnailDatas: [Data]
    
    var body: some View {
        Section("photo".localized) {
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(AppColorScheme.iconColor)
                    Text("select_photo".localized)
                        .foregroundColor(.primary)
                }
            }
            
            if !photoDatas.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                    ForEach(Array(photoDatas.enumerated()), id: \.offset) { index, data in
                        let thumbnailData = index < photoThumbnailDatas.count ? photoThumbnailDatas[index] : data
                        if let uiImage = UIImage(data: thumbnailData) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                Button {
                                    photoDatas.remove(at: index)
                                    if index < photoThumbnailDatas.count {
                                        photoThumbnailDatas.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .padding(4)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                var processed: [(Data, Data)] = []
                for item in newValue {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let result = ImageProcessor.process(data: data)
                        processed.append(result)
                    }
                }
                if !processed.isEmpty {
                    await MainActor.run {
                        for (resized, thumbnail) in processed {
                            photoDatas.append(resized)
                            photoThumbnailDatas.append(thumbnail)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    Form {
        PhotoSelectionSection(
            selectedPhotos: .constant([]),
            photoDatas: .constant([]),
            photoThumbnailDatas: .constant([])
        )
    }
}

