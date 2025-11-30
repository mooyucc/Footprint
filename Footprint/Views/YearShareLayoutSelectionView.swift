//
//  YearShareLayoutSelectionView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI
import SwiftData

struct YearShareLayoutSelectionView: View {
    let year: Int
    let destinations: [TravelDestination]
    @Binding var selectedLayout: TripShareLayout
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: TripShareItem?
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 版面选择列表
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(TripShareLayout.allCases) { layout in
                            LayoutOptionCard(
                                layout: layout,
                                isSelected: selectedLayout == layout
                            ) {
                                selectedLayout = layout
                            }
                        }
                    }
                    .padding()
                }
                
                // 底部操作按钮
                VStack(spacing: 12) {
                    Button {
                        guard !isGenerating else { return }
                        generateAndShare()
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(isGenerating ? "正在生成..." : "share".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isGenerating ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isGenerating)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("cancel".localized)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("select_layout".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                SystemShareSheet(items: [image])
            }
        }
    }
    
    private func generateAndShare() {
        guard !isGenerating else { return }
        
        isGenerating = true
        
        // 在后台线程生成图片，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            let yearImage = YearImageGenerator.generateYearImage(year: year, destinations: destinations, layout: selectedLayout)
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.shareItem = TripShareItem(text: "", image: yearImage)
            }
        }
    }
}

#Preview {
    YearShareLayoutSelectionView(
        year: 2025,
        destinations: [],
        selectedLayout: .constant(.list)
    )
}

