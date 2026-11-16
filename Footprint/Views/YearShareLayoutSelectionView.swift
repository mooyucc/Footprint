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
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var shareItem: TripShareItem?
    @State private var isGenerating = false
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: Color.footprintRed,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(TripShareLayout.allCases.filter(\.supportsYearShare)) { layout in
                                LayoutOptionCard(
                                    layout: layout,
                                    isSelected: selectedLayout == layout,
                                    isLocked: !allowedLayouts.contains(layout)
                                ) {
                                    if allowedLayouts.contains(layout) {
                                    selectedLayout = layout
                                    } else {
                                        showPaywall = true
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
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
                                Text(isGenerating ? "share_generating".localized : "share".localized)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isGenerating ? Color.gray : Color.footprintRed)
                            .cornerRadius(12)
                        }
                        .disabled(isGenerating)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("cancel".localized)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("select_layout".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                SystemShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseManager)
                .environmentObject(entitlementManager)
        }
    }
    
    private func generateAndShare() {
        guard !isGenerating else { return }
        guard allowedLayouts.contains(selectedLayout) else {
            showPaywall = true
            return
        }
        
        isGenerating = true
        let applyWatermark = entitlementManager.shouldApplyShareWatermark
        
        // 在后台线程生成图片，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            let yearImage = ShareImageUtilities.applyingWatermarkIfNeeded(
                YearImageGenerator.generateYearImage(year: year, destinations: destinations, layout: selectedLayout),
                shouldApply: applyWatermark
            )
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.shareItem = TripShareItem(text: "", image: yearImage)
            }
        }
    }

    private var allowedLayouts: [TripShareLayout] {
        entitlementManager.allowedTripShareLayouts().filter(\.supportsYearShare)
    }
}

#Preview {
    YearShareLayoutSelectionView(
        year: 2025,
        destinations: [],
        selectedLayout: .constant(.extendedGrid)
    )
}

