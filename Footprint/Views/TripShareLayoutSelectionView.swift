//
//  TripShareLayoutSelectionView.swift
//  Footprint
//
//  Created on 2025/01/XX.
//

import SwiftUI
import SwiftData

struct TripShareLayoutSelectionView: View {
    let trip: TravelTrip
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
            let tripImage = TripImageGenerator.generateTripImage(from: trip, layout: selectedLayout)
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.shareItem = TripShareItem(text: "", image: tripImage)
            }
        }
    }
}

struct LayoutOptionCard: View {
    let layout: TripShareLayout
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: layout.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 文字信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(layout.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(layout.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    
    let trip = TravelTrip(
        name: "2025年10月青甘大环线",
        desc: "穿越青海甘肃的美丽风光",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7)
    )
    container.mainContext.insert(trip)
    
    return TripShareLayoutSelectionView(
        trip: trip,
        selectedLayout: .constant(.list)
    )
    .modelContainer(container)
}

