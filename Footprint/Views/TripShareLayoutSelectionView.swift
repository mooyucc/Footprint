//
//  TripShareLayoutSelectionView.swift
//  Footprint
//
//  旅程分享海报：预览驱动（对齐地点分享页交互）
//

import SwiftUI
import SwiftData
import UIKit

struct TripShareLayoutSelectionView: View {
    let trip: TravelTrip
    @Binding var selectedLayout: TripShareLayout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var previewImage: UIImage?
    @State private var isGeneratingPreview = false
    @State private var isExporting = false
    @State private var shareItem: TripShareItem?
    @State private var showPaywall = false
    @State private var toastMessage: String?
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: Color.footprintRed,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            previewSection
                            styleSection
                        }
                        .padding()
                        .padding(.bottom, 8)
                    }

                    bottomActions
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("destination_share_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.78)))
                        .padding(.bottom, 100)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .sheet(item: $shareItem) { item in
            SystemShareSheet(items: Self.activityItems(from: item))
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseManager)
                .environmentObject(entitlementManager)
        }
        .onAppear {
            if !allowedLayouts.contains(selectedLayout) {
                selectedLayout = allowedLayouts.first ?? .extendedGrid
            }
            schedulePreviewRefresh()
        }
        .onChange(of: selectedLayout) { _, _ in schedulePreviewRefresh() }
        .onDisappear {
            previewTask?.cancel()
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Group {
            if let previewImage {
                ScrollView {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 420)
            } else if isGeneratingPreview {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
            }
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("destination_share_style_section".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TripShareLayout.allCases) { layout in
                        let locked = !allowedLayouts.contains(layout)
                        TripLayoutThumbnailChip(
                            layout: layout,
                            isSelected: selectedLayout == layout,
                            isLocked: locked
                        ) {
                            if locked {
                                showPaywall = true
                            } else {
                                selectedLayout = layout
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await saveToPhotos() }
            } label: {
                Label(
                    isExporting ? "share_generating".localized : "destination_share_save_photos".localized,
                    systemImage: "square.and.arrow.down"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isExporting || isGeneratingPreview)

            Button {
                Task { await shareImage() }
            } label: {
                Group {
                    if isExporting {
                        Label {
                            Text("share_generating".localized)
                        } icon: {
                            ProgressView()
                        }
                    } else {
                        Label("share".localized, systemImage: "square.and.arrow.up")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.footprintRed)
            .disabled(isExporting || isGeneratingPreview)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Entitlements

    private var allowedLayouts: [TripShareLayout] {
        entitlementManager.allowedTripShareLayouts()
    }

    // MARK: - Preview / Export

    private static func activityItems(from item: TripShareItem) -> [Any] {
        var items: [Any] = []
        if let image = item.image { items.append(image) }
        if !item.text.isEmpty { items.append(item.text) }
        return items.isEmpty ? [""] : items
    }

    private func schedulePreviewRefresh() {
        previewTask?.cancel()
        isGeneratingPreview = true
        previewImage = nil

        let layout = selectedLayout
        let applyWatermark = entitlementManager.shouldApplyShareWatermark

        previewTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            let image = await renderShareImage(layout: layout, applyWatermark: applyWatermark)

            guard !Task.isCancelled else { return }
            previewImage = image
            isGeneratingPreview = false
        }
    }

    private func renderShareImage(layout: TripShareLayout, applyWatermark: Bool) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = ShareImageUtilities.applyingWatermarkIfNeeded(
                    TripImageGenerator.generateTripImage(from: trip, layout: layout),
                    shouldApply: applyWatermark
                )
                continuation.resume(returning: image)
            }
        }
    }

    private func shareImage() async {
        guard allowedLayouts.contains(selectedLayout) else {
            showPaywall = true
            return
        }

        isExporting = true
        let image = await renderShareImage(
            layout: selectedLayout,
            applyWatermark: entitlementManager.shouldApplyShareWatermark
        )
        isExporting = false
        guard let image else { return }
        shareItem = TripShareItem(text: "", image: image)
    }

    private func saveToPhotos() async {
        guard allowedLayouts.contains(selectedLayout) else {
            showPaywall = true
            return
        }

        isExporting = true
        let image = await renderShareImage(
            layout: selectedLayout,
            applyWatermark: entitlementManager.shouldApplyShareWatermark
        )

        guard let image else {
            isExporting = false
            showToast("destination_share_save_failed".localized)
            return
        }

        let ok = await ShareImageUtilities.saveToPhotoLibrary(image)
        isExporting = false
        showToast(ok ? "destination_share_saved".localized : "destination_share_save_failed".localized)
    }

    private func showToast(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }
}

// MARK: - 版式缩略芯片

struct TripLayoutThumbnailChip: View {
    let layout: TripShareLayout
    let isSelected: Bool
    var isLocked: Bool = false
    let action: () -> Void

    /// 与地点分享 3:4 版式芯片同尺寸
    private let thumbSize = CGSize(width: 78, height: 104)

    private var imageFill: Color {
        isSelected && !isLocked ? Color.footprintRed.opacity(0.22) : Color.primary.opacity(0.12)
    }

    private var textFill: Color {
        isSelected && !isLocked ? Color.footprintRed.opacity(0.45) : Color.primary.opacity(0.22)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))

                    TripLayoutSchematicView(
                        layout: layout,
                        imageFill: imageFill,
                        textFill: textFill
                    )
                    .padding(10)

                    if isLocked {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                        Image(systemName: "lock.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: thumbSize.width, height: thumbSize.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected && !isLocked ? Color.footprintRed : Color.primary.opacity(0.08),
                            lineWidth: isSelected && !isLocked ? 2.5 : 1
                        )
                )

                Text(layout.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isLocked ? .secondary : (isSelected ? Color.footprintRed : .primary))
                    .lineLimit(1)
            }
            .frame(width: thumbSize.width + 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 版式结构示意图
private struct TripLayoutSchematicView: View {
    let layout: TripShareLayout
    let imageFill: Color
    let textFill: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gap: CGFloat = 3
            let lineH = max(3, min(5, h * 0.05))

            switch layout {
            case .extendedGrid:
                VStack(spacing: gap) {
                    Capsule().fill(textFill).frame(width: w * 0.55, height: lineH)
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: gap) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(imageFill)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

            case .timeline:
                HStack(alignment: .top, spacing: 6) {
                    Capsule()
                        .fill(textFill.opacity(0.7))
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                    VStack(spacing: gap) {
                        Capsule().fill(textFill).frame(width: w * 0.5, height: lineH)
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(imageFill)
                                .frame(height: h * 0.22)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 年份分享仍使用的列表卡

struct LayoutOptionCard: View {
    let layout: TripShareLayout
    let isSelected: Bool
    let isLocked: Bool
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
        selectedLayout: .constant(.extendedGrid)
    )
    .modelContainer(container)
}
