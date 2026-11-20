import SwiftUI
import UIKit

struct DestinationShareLayoutSelectionView: View {
    let destination: TravelDestination
    @Binding var selectedLayout: DestinationShareLayout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    
    @State private var selectedAspect: DestinationShareAspectRatio = .square11
    @State private var selectedCoverIndex: Int = 0
    /// 画在海报上的副标题短句
    @State private var overlayText: String = ""
    /// 副标题允许为空，故用标记避免 onAppear 反复从备注回填
    @State private var didSeedOverlay = false
    /// 系统分享 / 复制用的配文
    @State private var shareCaptionText: String = ""
    @State private var showTextEditor = false
    @State private var previewImage: UIImage?
    @State private var isGeneratingPreview = false
    @State private var isExporting = false
    @State private var shareItem: TripShareItem?
    @State private var showPaywall = false
    @State private var toastMessage: String?
    @State private var previewTask: Task<Void, Never>?
    @State private var captionPreviewTask: Task<Void, Never>?
    
    /// 海报短句编辑上限。中日韩 30 字；英文及法、西、德按最多 20 个词留出字符空间。
    private var overlayMaxLength: Int {
        switch LanguageManager.shared.currentLanguage {
        case .chinese, .chineseTraditional, .japanese, .korean:
            return 30
        case .english, .french, .spanish, .german:
            return 160
        }
    }
    
    private var availablePhotoDatas: [Data] {
        DestinationSharePhotoSource.photoDatas(from: destination)
    }
    
    /// 当前尺寸下可选的版式（再与权益交叉）
    private var layoutsForCurrentAspect: [DestinationShareLayout] {
        DestinationShareLayout.allCases.filter { $0.supports(selectedAspect) }
    }
    
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
                            
                            if showsProUpgradeBanner {
                                ShareProUpgradeBanner {
                                    showPaywall = true
                                }
                            }
                            
                            if availablePhotoDatas.count > 1 {
                                coverPhotoSection
                            }
                            
                            aspectSection
                            
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
            PaywallView(contextMessage: "share_pro_paywall_context".localized)
                .environmentObject(purchaseManager)
                .environmentObject(entitlementManager)
        }
        .sheet(isPresented: $showTextEditor) {
            DestinationShareTextEditorSheet(
                destination: destination,
                overlayText: $overlayText,
                overlayMaxLength: overlayMaxLength,
                defaultOverlay: ShareImageUtilities.destinationOverlayCaption(
                    for: destination,
                    maxLength: overlayMaxLength
                )
            )
            .environmentObject(entitlementManager)
            .environmentObject(purchaseManager)
            .environmentObject(aiCreditManager)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !allowedAspects.contains(selectedAspect) {
                selectedAspect = allowedAspects.first ?? .square11
            }
            syncLayoutForCurrentAspect()
            if !didSeedOverlay {
                overlayText = ShareImageUtilities.destinationOverlayCaption(
                    for: destination,
                    maxLength: overlayMaxLength
                )
                didSeedOverlay = true
            }
            if shareCaptionText.isEmpty {
                shareCaptionText = ShareImageUtilities.destinationShareCaption(for: destination)
            }
            clampCoverIndex()
            schedulePreviewRefresh()
        }
        .onChange(of: selectedLayout) { _, _ in schedulePreviewRefresh() }
        .onChange(of: selectedAspect) { _, _ in
            syncLayoutForCurrentAspect()
            schedulePreviewRefresh()
        }
        .onChange(of: selectedCoverIndex) { _, _ in
            schedulePreviewRefresh()
        }
        .onChange(of: overlayText) { _, _ in
            scheduleCaptionDrivenRefresh()
        }
        .onDisappear {
            previewTask?.cancel()
            captionPreviewTask?.cancel()
        }
    }
    
    // MARK: - Sections
    
    private var previewSection: some View {
        VStack(spacing: 12) {
            Button {
                showTextEditor = true
            } label: {
                Group {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                    } else if isGeneratingPreview {
                        ProgressView()
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: previewFrameHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("destination_share_edit_text_hint".localized)

            Text("destination_share_edit_text_hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
    
    private var previewFrameHeight: CGFloat {
        switch selectedAspect {
        case .story916: return 420
        case .portrait34: return 380
        case .square11: return 340
        }
    }
    
    private var coverPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("destination_share_cover_section".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(availablePhotoDatas.enumerated()), id: \.offset) { index, data in
                        Button {
                            selectedCoverIndex = index
                        } label: {
                            Group {
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Color.primary.opacity(0.08)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        selectedCoverIndex == index ? Color.footprintRed : Color.clear,
                                        lineWidth: 2.5
                                    )
                            )
                            .overlay(alignment: .bottomTrailing) {
                                if selectedCoverIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.footprintRed)
                                        .padding(4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("destination_share_cover_option".localized)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private var aspectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("destination_share_aspect_section".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                ForEach(DestinationShareAspectRatio.allCases) { aspect in
                    let locked = !allowedAspects.contains(aspect)
                    Button {
                        if locked {
                            showPaywall = true
                        } else {
                            selectedAspect = aspect
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(aspect.shortLabel)
                                .font(.subheadline.weight(.semibold))
                            Text(aspect.displayName)
                                .font(.caption)
                                .lineLimit(1)
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(selectedAspect == aspect && !locked ? Color.white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background {
                            Capsule()
                                .fill(selectedAspect == aspect && !locked ? Color.footprintRed : Color.primary.opacity(0.06))
                        }
                    }
                    .buttonStyle(.plain)
                }
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
                    ForEach(layoutsForCurrentAspect) { layout in
                        let locked = !allowedLayouts.contains(layout)
                        DestinationLayoutThumbnailChip(
                            layout: layout,
                            aspect: selectedAspect,
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
    
    private var allowedLayouts: [DestinationShareLayout] {
        entitlementManager.allowedDestinationShareLayouts()
    }
    
    private var allowedAspects: [DestinationShareAspectRatio] {
        entitlementManager.allowedDestinationShareAspectRatios()
    }

    private var showsProUpgradeBanner: Bool {
        !BetaInfo.isBetaBuild && !entitlementManager.canUseFullShareLayouts
    }
    
    // MARK: - Preview / Export
    
    private static func activityItems(from item: TripShareItem) -> [Any] {
        var items: [Any] = []
        if let image = item.image { items.append(image) }
        if !item.text.isEmpty { items.append(item.text) }
        return items.isEmpty ? [item.text] : items
    }
    
    private func clampCoverIndex() {
        let count = availablePhotoDatas.count
        guard count > 0 else {
            selectedCoverIndex = 0
            return
        }
        selectedCoverIndex = min(max(0, selectedCoverIndex), count - 1)
    }
    
    /// 尺寸变化时校正版式：不支持当前比例则切到可用且已解锁的版式
    private func syncLayoutForCurrentAspect() {
        let candidates = layoutsForCurrentAspect
        let unlocked = candidates.filter { allowedLayouts.contains($0) }
        if !candidates.contains(selectedLayout) || !allowedLayouts.contains(selectedLayout) {
            selectedLayout = unlocked.first ?? candidates.first ?? .photoPoster
        }
    }
    
    private func scheduleCaptionDrivenRefresh() {
        captionPreviewTask?.cancel()
        captionPreviewTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            schedulePreviewRefresh()
        }
    }
    
    private func schedulePreviewRefresh() {
        previewTask?.cancel()
        isGeneratingPreview = true
        previewImage = nil
        
        let layout = selectedLayout
        let aspect = selectedAspect
        let coverIndex = selectedCoverIndex
        let overlay = overlayText
        let applyWatermark = entitlementManager.shouldApplyShareWatermark
        
        previewTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            
            let image = await renderShareImage(
                layout: layout,
                aspect: aspect,
                coverIndex: coverIndex,
                overlay: overlay,
                scale: 1,
                applyWatermark: applyWatermark
            )
            
            guard !Task.isCancelled else { return }
            previewImage = image
            isGeneratingPreview = false
        }
    }
    
    private func renderShareImage(
        layout: DestinationShareLayout,
        aspect: DestinationShareAspectRatio,
        coverIndex: Int,
        overlay: String,
        scale: CGFloat,
        applyWatermark: Bool
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = ShareImageUtilities.applyingWatermarkIfNeeded(
                    TripImageGenerator.generateDestinationImage(
                        from: destination,
                        layout: layout,
                        aspectRatio: aspect,
                        scale: scale,
                        coverPhotoIndex: coverIndex,
                        overlayCaption: overlay
                    ),
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
        guard allowedAspects.contains(selectedAspect) else {
            showPaywall = true
            return
        }
        
        isExporting = true
        let caption = shareCaptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = await renderShareImage(
            layout: selectedLayout,
            aspect: selectedAspect,
            coverIndex: selectedCoverIndex,
            overlay: overlayText,
            scale: 2,
            applyWatermark: entitlementManager.shouldApplyShareWatermark
        )
        isExporting = false
        guard let image else { return }
        shareItem = TripShareItem(text: caption, image: image)
    }
    
    private func saveToPhotos() async {
        guard allowedLayouts.contains(selectedLayout) else {
            showPaywall = true
            return
        }
        guard allowedAspects.contains(selectedAspect) else {
            showPaywall = true
            return
        }
        
        isExporting = true
        let image = await renderShareImage(
            layout: selectedLayout,
            aspect: selectedAspect,
            coverIndex: selectedCoverIndex,
            overlay: overlayText,
            scale: 2,
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

/// 修图式文字编辑：标题为地点名（只读）；副标题可编辑 / AI 生成；分享配文仍用自动生成文案
struct DestinationShareTextEditorSheet: View {
    let destination: TravelDestination
    @Binding var overlayText: String
    let overlayMaxLength: Int
    let defaultOverlay: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @StateObject private var aiManager = AIModelManager.shared
    @FocusState private var isOverlayFocused: Bool
    @State private var isGeneratingAI = false
    @State private var aiErrorMessage: String?
    @State private var showCreditPaywall = false
    
    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(destination.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("destination_share_title_label".localized)
                        .accessibilityValue(destination.name)
                    
                    TextField(
                        "destination_share_overlay_placeholder".localized,
                        text: $overlayText,
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .focused($isOverlayFocused)
                    .disabled(isGeneratingAI)
                    .onChange(of: overlayText) { _, newValue in
                        if newValue.count > overlayMaxLength {
                            overlayText = String(newValue.prefix(overlayMaxLength))
                        }
                    }
                    
                    HStack {
                        Text("\(overlayText.count)/\(overlayMaxLength)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("destination_share_caption_reset".localized) {
                            overlayText = defaultOverlay
                        }
                        .font(.caption.weight(.medium))
                        .disabled(isGeneratingAI)
                    }
                    
                    Button {
                        generateAICaption()
                    } label: {
                        HStack {
                            if isGeneratingAI {
                                ProgressView()
                                Text("destination_share_ai_generating".localized)
                            } else {
                                Image(systemName: "sparkles")
                                Text("destination_share_ai_generate".localized)
                            }
                            Spacer()
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .disabled(isGeneratingAI)
                    
                    if let aiErrorMessage {
                        Text(aiErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("destination_share_overlay_section".localized)
                } footer: {
                    Text("destination_share_overlay_footer".localized)
                }
            }
            .navigationTitle("destination_share_edit_text".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(isGeneratingAI)
                }
            }
            .sheet(isPresented: $showCreditPaywall) {
                AICreditPaywallView()
                    .environmentObject(purchaseManager)
                    .environmentObject(aiCreditManager)
            }
            .onAppear {
                isOverlayFocused = true
            }
        }
    }
    
    private func generateAICaption() {
        guard !isGeneratingAI else { return }
        guard canUseAI else {
            showCreditPaywall = true
            return
        }
        
        switch aiCreditManager.gateAICall(isUnlimitedUser: entitlementManager.canUseAIFeatures) {
        case .allowed:
            break
        case .insufficientCredits:
            showCreditPaywall = true
            return
        case .dailyLimitReached:
            aiErrorMessage = "ai_daily_limit_reached_message".localized
            return
        }
        
        isGeneratingAI = true
        aiErrorMessage = nil
        isOverlayFocused = false
        
        Task {
            let caption = await aiManager.generateShareOverlayCaption(
                for: destination,
                maxLength: overlayMaxLength
            )
            await MainActor.run {
                isGeneratingAI = false
                let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !trimmed.isEmpty {
                    overlayText = String(trimmed.prefix(overlayMaxLength))
                } else {
                    aiErrorMessage = aiManager.errorMessage ?? "ai_error_unknown".localized
                }
            }
        }
    }
}

struct DestinationLayoutThumbnailChip: View {
    let layout: DestinationShareLayout
    let aspect: DestinationShareAspectRatio
    let isSelected: Bool
    var isLocked: Bool = false
    let action: () -> Void
    
    private var thumbSize: CGSize {
        switch aspect {
        case .square11:
            return CGSize(width: 88, height: 88)
        case .portrait34:
            return CGSize(width: 78, height: 104)
        case .story916:
            return CGSize(width: 72, height: 128)
        }
    }
    
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
                    
                    DestinationLayoutSchematicView(
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

/// 版式结构示意图：色块代表图片区域，细条代表文案
private struct DestinationLayoutSchematicView: View {
    let layout: DestinationShareLayout
    let imageFill: Color
    let textFill: Color
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gap: CGFloat = 4
            let lineH = max(3, min(5, h * 0.06))
            
            switch layout {
            case .photoPoster:
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(imageFill)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Capsule().fill(textFill).frame(width: w * 0.55, height: lineH)
                        Capsule().fill(textFill.opacity(0.7)).frame(width: w * 0.35, height: lineH)
                    }
                    .padding(6)
                }
                
            case .gallerySide:
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(imageFill)
                        .frame(width: w * 0.42)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Capsule().fill(textFill).frame(width: w * 0.42, height: lineH)
                        Capsule().fill(textFill.opacity(0.75)).frame(width: w * 0.34, height: lineH)
                        Capsule().fill(textFill.opacity(0.55)).frame(width: w * 0.28, height: lineH)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                
            case .galleryStack:
                VStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(imageFill)
                        .frame(height: h * 0.48)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Capsule().fill(textFill).frame(width: w * 0.72, height: lineH)
                        Capsule().fill(textFill.opacity(0.75)).frame(width: w * 0.55, height: lineH)
                        Capsule().fill(textFill.opacity(0.55)).frame(width: w * 0.40, height: lineH)
                        Spacer(minLength: 0)
                        Capsule().fill(textFill.opacity(0.45)).frame(width: w * 0.28, height: lineH)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 2)
                }
            }
        }
    }
}
