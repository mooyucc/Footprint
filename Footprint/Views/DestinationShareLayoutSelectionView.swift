import SwiftUI
import SwiftData

struct DestinationShareLayoutSelectionView: View {
    let destination: TravelDestination
    @Binding var selectedLayout: DestinationShareLayout
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
                            ForEach(DestinationShareLayout.allCases) { layout in
                                DestinationLayoutOptionCard(
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
    
    private var allowedLayouts: [DestinationShareLayout] {
        entitlementManager.allowedDestinationShareLayouts()
    }
    
    private func generateAndShare() {
        guard !isGenerating else { return }
        guard allowedLayouts.contains(selectedLayout) else {
            showPaywall = true
            return
        }
        
        isGenerating = true
        let applyWatermark = entitlementManager.shouldApplyShareWatermark
        
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ShareImageUtilities.applyingWatermarkIfNeeded(
                TripImageGenerator.generateDestinationImage(from: destination, layout: selectedLayout),
                shouldApply: applyWatermark
            )
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.shareItem = TripShareItem(text: "", image: image)
            }
        }
    }
}

struct DestinationLayoutOptionCard: View {
    let layout: DestinationShareLayout
    let isSelected: Bool
    var isLocked: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: layout.iconName)
                    .font(.title2)
                    .foregroundStyle(isLocked ? .secondary.opacity(0.4) : (isSelected ? Color.footprintRed : .secondary))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.footprintRed.opacity(0.12) : Color.primary.opacity(0.06))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(layout.displayName)
                        .font(.headline)
                        .foregroundStyle(isLocked ? .secondary : .primary)
                    
                    Text(layout.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
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
