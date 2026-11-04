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
                    // 版面选择列表
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(TripShareLayout.allCases) { layout in
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
            let tripImage = ShareImageUtilities.applyingWatermarkIfNeeded(
                TripImageGenerator.generateTripImage(from: trip, layout: selectedLayout),
                shouldApply: applyWatermark
            )
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.shareItem = TripShareItem(text: "", image: tripImage)
            }
        }
    }

    private var allowedLayouts: [TripShareLayout] {
        entitlementManager.allowedTripShareLayouts()
    }
}

struct LayoutOptionCard: View {
    let layout: TripShareLayout
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: layout.iconName)
                    .font(.title2)
                    .foregroundStyle(isLocked ? .secondary.opacity(0.4) : (isSelected ? Color.footprintRed : .secondary))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.footprintRed.opacity(0.12) : Color.primary.opacity(0.06))
                    )
                
                // 文字信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(layout.displayName)
                        .font(.headline)
                        .foregroundColor(isLocked ? .secondary : .primary)
                    
                    Text(layout.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.footprintRed)
                        .font(.title3)
                }
            }
            .padding()
            .footprintGlassCard(
                cornerRadius: 16,
                glow: isSelected && !isLocked ? Color.footprintRed : nil
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isLocked ? Color.clear : (isSelected ? Color.footprintRed : Color.clear),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
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

