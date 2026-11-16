//
//  StatsSharePreviewView.swift
//  Footprint
//
//  旅行统计分享：预览驱动（对齐旅程 / 地点分享页交互）
//

import SwiftUI
import UIKit

struct StatsSharePreviewView: View {
    let stats: TravelStats
    
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
                    previewSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
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
                        .padding(.bottom, 88)
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
            schedulePreviewRefresh()
        }
        .onDisappear {
            previewTask?.cancel()
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var previewSection: some View {
        if let previewImage {
            ScrollView {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isGeneratingPreview {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        
        let applyWatermark = entitlementManager.shouldApplyShareWatermark
        let stats = stats
        
        previewTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            
            let image = await renderShareImage(stats: stats, applyWatermark: applyWatermark)
            
            guard !Task.isCancelled else { return }
            previewImage = image
            isGeneratingPreview = false
        }
    }
    
    private func renderShareImage(stats: TravelStats, applyWatermark: Bool) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = ShareImageUtilities.applyingWatermarkIfNeeded(
                    StatsImageGenerator.generateStatsImage(stats: stats),
                    shouldApply: applyWatermark
                )
                continuation.resume(returning: image)
            }
        }
    }
    
    private func shareImage() async {
        isExporting = true
        let image = await renderShareImage(
            stats: stats,
            applyWatermark: entitlementManager.shouldApplyShareWatermark
        )
        isExporting = false
        guard let image else { return }
        shareItem = TripShareItem(text: "", image: image)
    }
    
    private func saveToPhotos() async {
        isExporting = true
        let image = await renderShareImage(
            stats: stats,
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

#Preview {
    StatsSharePreviewView(
        stats: TravelStats(
            totalDestinations: 12,
            domesticDestinations: 7,
            internationalDestinations: 5,
            countries: 4,
            countryData: [
                (name: "中国", count: 7),
                (name: "日本", count: 3),
                (name: "冰岛", count: 2)
            ],
            yearlyData: [(year: 2026, count: 8), (year: 2025, count: 4)],
            userName: "KX"
        )
    )
    .environmentObject(EntitlementManager.shared)
    .environmentObject(PurchaseManager.shared)
}
