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
                        generateAndShare()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("share".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
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
        let yearImage = YearImageGenerator.generateYearImage(year: year, destinations: destinations, layout: selectedLayout)
        shareItem = TripShareItem(text: "", image: yearImage)
    }
}

#Preview {
    YearShareLayoutSelectionView(
        year: 2025,
        destinations: [],
        selectedLayout: .constant(.list)
    )
}

