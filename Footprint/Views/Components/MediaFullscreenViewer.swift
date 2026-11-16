//
//  MediaFullscreenViewer.swift
//  Footprint
//
//  全屏媒体浏览（在地点 sheet 外层呈现）
//  - 下拉只带动当前照片，底下 sheet 保持不动
//  - 未放大才可下拉关闭；页内双指/双击缩放与左右翻页
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct MediaFullscreenItem: Identifiable {
    let id: String
    let kind: Kind
    
    enum Kind {
        case photo(Data)
        case video(Data)
    }
}

// MARK: - SwiftUI shell

struct MediaFullscreenViewer: View {
    let items: [MediaFullscreenItem]
    @Binding var currentIndex: Int
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        PhotosGalleryRepresentable(
            items: items,
            currentIndex: $currentIndex,
            onClose: { close() }
        )
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
    
    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

// MARK: - Representable

private struct PhotosGalleryRepresentable: UIViewControllerRepresentable {
    let items: [MediaFullscreenItem]
    @Binding var currentIndex: Int
    let onClose: () -> Void
    
    func makeUIViewController(context: Context) -> PhotosGalleryViewController {
        let vc = PhotosGalleryViewController(items: items, initialIndex: currentIndex)
        vc.onIndexChange = { index in
            if currentIndex != index {
                currentIndex = index
            }
        }
        vc.onClose = onClose
        return vc
    }
    
    func updateUIViewController(_ vc: PhotosGalleryViewController, context: Context) {
        vc.onClose = onClose
        vc.onIndexChange = { index in
            if currentIndex != index {
                currentIndex = index
            }
        }
        if vc.currentIndex != currentIndex {
            vc.scrollToPage(currentIndex, animated: false)
        }
    }
}

// MARK: - Downsampled decode

enum MediaImageDecoder {
    /// 按目标最长边降采样，避免主线程解全尺寸原图
    static func downsampledImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    static var screenMaxPixelSize: CGFloat {
        let screen = UIScreen.main
        let longSide = max(screen.bounds.width, screen.bounds.height) * screen.scale
        // 留一点余量给双击放大
        return longSide * 2
    }
}

// MARK: - Gallery VC

final class PhotosGalleryViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let items: [MediaFullscreenItem]
    private(set) var currentIndex: Int
    
    var onIndexChange: ((Int) -> Void)?
    var onClose: (() -> Void)?
    
    private let pagingScrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let closeButton = UIButton(type: .system)
    private var pageViews: [GalleryPageView] = []
    private var hasLaidOutPages = false
    private var lastPagingBoundsSize: CGSize = .zero
    private let maxPixelSize = MediaImageDecoder.screenMaxPixelSize
    private var dismissInteractionActive = false
    
    private lazy var dismissPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        return pan
    }()
    
    init(items: [MediaFullscreenItem], initialIndex: Int) {
        self.items = items
        self.currentIndex = min(max(initialIndex, 0), max(items.count - 1, 0))
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isOpaque = false
        view.clipsToBounds = true
        
        pagingScrollView.isPagingEnabled = true
        pagingScrollView.showsHorizontalScrollIndicator = false
        pagingScrollView.showsVerticalScrollIndicator = false
        pagingScrollView.bounces = true
        pagingScrollView.delegate = self
        pagingScrollView.contentInsetAdjustmentBehavior = .never
        pagingScrollView.backgroundColor = .clear
        view.addSubview(pagingScrollView)
        
        pageControl.numberOfPages = items.count
        pageControl.currentPage = currentIndex
        pageControl.hidesForSinglePage = true
        pageControl.isUserInteractionEnabled = false
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.35)
        view.addSubview(pageControl)
        
        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(systemName: "xmark.circle.fill")
        closeConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        closeConfig.baseForegroundColor = UIColor.white.withAlphaComponent(0.9)
        closeButton.configuration = closeConfig
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.accessibilityLabel = "close".localized
        view.addSubview(closeButton)
        
        for item in items {
            let page = GalleryPageView(item: item)
            page.onZoomScaleChange = { [weak self] in
                self?.handleZoomScaleChange()
            }
            page.onReachedHorizontalEdgeWhileZoomed = { [weak self] direction in
                self?.advancePageFromZoomEdge(direction)
            }
            pageViews.append(page)
            pagingScrollView.addSubview(page)
        }
        
        // 只先加载当前页，邻页后台补；避免打开时解全部原图
        updateLoadedPages(priorityIndex: currentIndex)
        view.addGestureRecognizer(dismissPan)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configurePopGesturePriority()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        pagingScrollView.frame = bounds
        
        let pageWidth = bounds.width
        pagingScrollView.contentSize = CGSize(width: pageWidth * CGFloat(items.count), height: bounds.height)
        
        for (index, page) in pageViews.enumerated() {
            page.frame = CGRect(x: pageWidth * CGFloat(index), y: 0, width: pageWidth, height: bounds.height)
            page.attachPlayer(to: self)
            page.layoutContentIfNeeded()
        }
        
        let topSafe = view.safeAreaInsets.top
        closeButton.frame = CGRect(x: bounds.width - 56, y: topSafe + 4, width: 44, height: 44)
        
        let controlHeight: CGFloat = 28
        let bottomSafe = view.safeAreaInsets.bottom
        pageControl.frame = CGRect(
            x: 0,
            y: bounds.height - bottomSafe - controlHeight - 12,
            width: bounds.width,
            height: controlHeight
        )
        
        let sizeChanged = abs(bounds.width - lastPagingBoundsSize.width) > 0.5
            || abs(bounds.height - lastPagingBoundsSize.height) > 0.5
        // 首次布局或转屏后页宽变化：按当前索引重对齐，避免跳回第一张
        // 先记下索引：contentSize 变化可能触发 scrollViewDidScroll 误改 currentIndex
        if !hasLaidOutPages || sizeChanged {
            let indexToKeep = currentIndex
            hasLaidOutPages = true
            lastPagingBoundsSize = bounds.size
            scrollToPage(indexToKeep, animated: false)
        }
        
        updatePagingScrollEnabled()
        updateLoadedPages(priorityIndex: currentIndex)
    }
    
    @objc private func closeTapped() {
        onClose?()
    }
    
    // MARK: - Pull to dismiss（只动当前照片）
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan else { return true }
        guard (currentPageView()?.zoomScale ?? 1) <= 1.01 else { return false }
        let velocity = dismissPan.velocity(in: view)
        return abs(velocity.y) > abs(velocity.x) && velocity.y > 0
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        false
    }
    
    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        guard let currentPage = currentPageView() else { return }
        
        switch gesture.state {
        case .began, .changed:
            let dragY = max(0, translation.y)
            let progress = min(1, dragY / 320)
            let scale = 1 - progress * 0.25
            let corner = progress * 16
            
            if !dismissInteractionActive {
                dismissInteractionActive = true
                updatePagingScrollEnabled()
                pagingScrollView.clipsToBounds = false
                view.clipsToBounds = false
                setAdjacentPagesHidden(true)
                currentPage.prepareForInteractiveDismiss()
                closeButton.isHidden = true
                pageControl.alpha = 0
            }
            
            currentPage.applyDismissTransform(
                translation: CGPoint(x: translation.x * 0.35, y: dragY),
                scale: scale,
                cornerRadius: corner
            )
            // 黑罩变透 → 露出底下不变的地点 sheet
            view.backgroundColor = UIColor.black.withAlphaComponent(1 - progress)
            
        case .ended, .cancelled:
            let dragY = max(0, translation.y)
            let shouldDismiss = dragY > 140 || velocity.y > 900
            
            if shouldDismiss {
                let targetY = view.bounds.height
                UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
                    currentPage.applyDismissTransform(
                        translation: CGPoint(x: translation.x * 0.35, y: targetY),
                        scale: 0.7,
                        cornerRadius: 16
                    )
                    self.view.backgroundColor = .clear
                } completion: { _ in
                    self.onClose?()
                }
            } else {
                UIView.animate(
                    withDuration: 0.35,
                    delay: 0,
                    usingSpringWithDamping: 0.85,
                    initialSpringVelocity: 0.4,
                    options: [.beginFromCurrentState]
                ) {
                    currentPage.resetDismissTransform()
                    self.view.backgroundColor = .black
                    self.pageControl.alpha = 1
                } completion: { _ in
                    currentPage.endInteractiveDismiss()
                    self.pagingScrollView.clipsToBounds = true
                    self.view.clipsToBounds = true
                    self.setAdjacentPagesHidden(false)
                    self.closeButton.isHidden = false
                    self.dismissInteractionActive = false
                    self.updatePagingScrollEnabled()
                }
            }
            
        default:
            break
        }
    }
    
    private func setAdjacentPagesHidden(_ hidden: Bool) {
        for (index, page) in pageViews.enumerated() where index != currentIndex {
            page.isHidden = hidden
        }
    }
    
    /// 当前页 + 左右邻页按需解码；其余卸载以省内存
    private func updateLoadedPages(priorityIndex: Int) {
        for (index, page) in pageViews.enumerated() {
            if abs(index - priorityIndex) <= 1 {
                page.loadMediaIfNeeded(maxPixelSize: maxPixelSize, highPriority: index == priorityIndex)
            } else {
                page.unloadMediaIfNeeded()
            }
        }
    }
    
    func scrollToPage(_ index: Int, animated: Bool) {
        let clamped = min(max(index, 0), max(items.count - 1, 0))
        currentIndex = clamped
        pageControl.currentPage = clamped
        let width = pagingScrollView.bounds.width
        guard width > 0 else { return }
        pagingScrollView.setContentOffset(CGPoint(x: width * CGFloat(clamped), y: 0), animated: animated)
        updatePagingScrollEnabled()
        updateLoadedPages(priorityIndex: clamped)
    }
    
    private func handleZoomScaleChange() {
        updatePagingScrollEnabled()
    }
    
    private func updatePagingScrollEnabled() {
        let zoomed = (currentPageView()?.zoomScale ?? 1) > 1.01
        pagingScrollView.isScrollEnabled = !zoomed && !dismissInteractionActive
    }
    
    private func currentPageView() -> GalleryPageView? {
        guard currentIndex >= 0, currentIndex < pageViews.count else { return nil }
        return pageViews[currentIndex]
    }
    
    private func advancePageFromZoomEdge(_ direction: GalleryPageView.EdgeDirection) {
        let next: Int
        switch direction {
        case .previous: next = currentIndex - 1
        case .next: next = currentIndex + 1
        }
        guard next >= 0, next < items.count else { return }
        
        currentPageView()?.resetZoom(animated: false)
        scrollToPage(next, animated: true)
        onIndexChange?(next)
        updatePagingScrollEnabled()
        updateLoadedPages(priorityIndex: next)
    }
    
    private func configurePopGesturePriority() {
        if #available(iOS 26.0, *) {
            if let contentPop = navigationController?.interactiveContentPopGestureRecognizer {
                contentPop.require(toFail: pagingScrollView.panGestureRecognizer)
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === pagingScrollView, scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        let clamped = min(max(page, 0), max(items.count - 1, 0))
        if clamped != currentIndex {
            pageViews[currentIndex].resetZoom(animated: false)
            currentIndex = clamped
            pageControl.currentPage = clamped
            onIndexChange?(clamped)
            updatePagingScrollEnabled()
            updateLoadedPages(priorityIndex: clamped)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === pagingScrollView else { return }
        updatePagingScrollEnabled()
        updateLoadedPages(priorityIndex: currentIndex)
    }
}

// MARK: - Page

private final class GalleryPageView: UIView, UIScrollViewDelegate {
    enum EdgeDirection {
        case previous
        case next
    }
    
    private let item: MediaFullscreenItem
    private let zoomScrollView = UIScrollView()
    private let imageView = UIImageView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private var playerController: AVPlayerViewController?
    private var tempVideoURL: URL?
    private var lastBoundsSize: CGSize = .zero
    private var fittedImageSize: CGSize = .zero
    private var photoData: Data?
    private var isPhotoConfigured = false
    private var isImageLoaded = false
    private var isVideoPrepared = false
    private var loadGeneration = 0
    
    var onZoomScaleChange: (() -> Void)?
    var onReachedHorizontalEdgeWhileZoomed: ((EdgeDirection) -> Void)?
    
    private var edgeHandoffLocked = false
    
    var zoomScale: CGFloat {
        switch item.kind {
        case .photo: return zoomScrollView.zoomScale
        case .video: return 1
        }
    }
    
    init(item: MediaFullscreenItem) {
        self.item = item
        if case .photo(let data) = item.kind {
            self.photoData = data
        }
        super.init(frame: .zero)
        backgroundColor = .black
        clipsToBounds = true
        configureShell()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func configureShell() {
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        addSubview(loadingIndicator)
        
        switch item.kind {
        case .photo:
            configurePhotoShell()
        case .video:
            break
        }
    }
    
    private func configurePhotoShell() {
        guard !isPhotoConfigured else { return }
        isPhotoConfigured = true
        
        zoomScrollView.delegate = self
        zoomScrollView.minimumZoomScale = 1
        zoomScrollView.maximumZoomScale = 5
        zoomScrollView.showsHorizontalScrollIndicator = false
        zoomScrollView.showsVerticalScrollIndicator = false
        zoomScrollView.bouncesZoom = true
        zoomScrollView.bounces = true
        zoomScrollView.alwaysBounceHorizontal = true
        zoomScrollView.alwaysBounceVertical = true
        zoomScrollView.contentInsetAdjustmentBehavior = .never
        zoomScrollView.backgroundColor = .black
        zoomScrollView.clipsToBounds = true
        zoomScrollView.isScrollEnabled = false
        zoomScrollView.panGestureRecognizer.isEnabled = false
        addSubview(zoomScrollView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.backgroundColor = .black
        zoomScrollView.addSubview(imageView)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        zoomScrollView.addGestureRecognizer(doubleTap)
        
        zoomScrollView.panGestureRecognizer.addTarget(self, action: #selector(handleZoomPan(_:)))
    }
    
    func loadMediaIfNeeded(maxPixelSize: CGFloat, highPriority: Bool) {
        switch item.kind {
        case .photo:
            loadPhotoIfNeeded(maxPixelSize: maxPixelSize, highPriority: highPriority)
        case .video(let data):
            prepareVideoIfNeeded(data)
        }
    }
    
    func unloadMediaIfNeeded() {
        switch item.kind {
        case .photo:
            guard isImageLoaded else { return }
            loadGeneration += 1
            isImageLoaded = false
            imageView.image = nil
            fittedImageSize = .zero
            resetZoom(animated: false)
        case .video:
            break
        }
    }
    
    private func loadPhotoIfNeeded(maxPixelSize: CGFloat, highPriority: Bool) {
        guard let photoData, !isImageLoaded else { return }
        configurePhotoShell()
        loadingIndicator.startAnimating()
        let generation = loadGeneration + 1
        loadGeneration = generation
        
        let priority: TaskPriority = highPriority ? .userInitiated : .utility
        Task.detached(priority: priority) { [weak self] in
            let image = MediaImageDecoder.downsampledImage(data: photoData, maxPixelSize: maxPixelSize)
            await MainActor.run {
                guard let self, self.loadGeneration == generation else { return }
                self.loadingIndicator.stopAnimating()
                guard let image else { return }
                self.imageView.image = image
                self.isImageLoaded = true
                self.fittedImageSize = .zero
                self.layoutContentIfNeeded()
            }
        }
    }
    
    private func prepareVideoIfNeeded(_ data: Data) {
        guard !isVideoPrepared else { return }
        isVideoPrepared = true
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        do {
            try data.write(to: url)
            tempVideoURL = url
            let player = AVPlayer(url: url)
            let controller = AVPlayerViewController()
            controller.player = player
            controller.showsPlaybackControls = true
            controller.view.backgroundColor = .black
            playerController = controller
            addSubview(controller.view)
            setNeedsLayout()
        } catch {
            backgroundColor = .black
        }
    }
    
    func attachPlayer(to parent: UIViewController) {
        guard let playerController, playerController.parent == nil else { return }
        parent.addChild(playerController)
        if playerController.view.superview !== self {
            addSubview(playerController.view)
        }
        playerController.didMove(toParent: parent)
        playerController.view.frame = bounds
        playerController.player?.play()
    }
    
    deinit {
        playerController?.player?.pause()
        playerController?.willMove(toParent: nil)
        playerController?.view.removeFromSuperview()
        playerController?.removeFromParent()
        if let tempVideoURL {
            try? FileManager.default.removeItem(at: tempVideoURL)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        loadingIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    func layoutContentIfNeeded() {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        
        switch item.kind {
        case .photo:
            guard isPhotoConfigured else { return }
            zoomScrollView.frame = bounds
            let boundsChanged = abs(size.width - lastBoundsSize.width) > 0.5
                || abs(size.height - lastBoundsSize.height) > 0.5
            if boundsChanged || fittedImageSize == .zero {
                lastBoundsSize = size
                resetZoom(animated: false)
                layoutImageFit()
            } else {
                centerImage()
            }
        case .video:
            playerController?.view.frame = bounds
        }
    }
    
    private var dismissTargetView: UIView {
        switch item.kind {
        case .photo:
            return imageView
        case .video:
            return playerController?.view ?? self
        }
    }
    
    func prepareForInteractiveDismiss() {
        backgroundColor = .clear
        zoomScrollView.backgroundColor = .clear
        imageView.backgroundColor = .clear
        clipsToBounds = false
        zoomScrollView.clipsToBounds = false
    }
    
    func applyDismissTransform(translation: CGPoint, scale: CGFloat, cornerRadius: CGFloat) {
        let target = dismissTargetView
        target.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
            .scaledBy(x: scale, y: scale)
        target.layer.cornerRadius = cornerRadius
        target.clipsToBounds = true
    }
    
    func resetDismissTransform() {
        let target = dismissTargetView
        target.transform = .identity
        target.layer.cornerRadius = 0
    }
    
    func endInteractiveDismiss() {
        resetDismissTransform()
        backgroundColor = .black
        zoomScrollView.backgroundColor = .black
        imageView.backgroundColor = .black
        clipsToBounds = true
        zoomScrollView.clipsToBounds = true
        dismissTargetView.clipsToBounds = false
    }
    
    func resetZoom(animated: Bool) {
        guard case .photo = item.kind else { return }
        zoomScrollView.setZoomScale(1, animated: animated)
        updateZoomPanEnabled()
        centerImage()
        onZoomScaleChange?()
    }
    
    private func layoutImageFit() {
        guard let image = imageView.image else { return }
        let boundsSize = zoomScrollView.bounds.size
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, boundsSize.width > 0, boundsSize.height > 0 else { return }
        
        let fit = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
        fittedImageSize = CGSize(width: imageSize.width * fit, height: imageSize.height * fit)
        imageView.frame = CGRect(origin: .zero, size: fittedImageSize)
        zoomScrollView.contentSize = fittedImageSize
        zoomScrollView.zoomScale = 1
        updateZoomPanEnabled()
        centerImage()
    }
    
    private func centerImage() {
        let boundsSize = zoomScrollView.bounds.size
        var frame = imageView.frame
        frame.origin.x = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) / 2 : 0
        frame.origin.y = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) / 2 : 0
        imageView.frame = frame
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        guard case .photo = item.kind else { return nil }
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
        updateZoomPanEnabled()
        onZoomScaleChange?()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale <= 1.01 {
            scrollView.setZoomScale(1, animated: false)
            centerImage()
        }
        edgeHandoffLocked = false
        updateZoomPanEnabled()
        onZoomScaleChange?()
    }
    
    private func updateZoomPanEnabled() {
        let zoomed = zoomScrollView.zoomScale > 1.01
        zoomScrollView.isScrollEnabled = zoomed
        zoomScrollView.panGestureRecognizer.isEnabled = zoomed
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScrollView.zoomScale > 1.01 {
            zoomScrollView.setZoomScale(1, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let target: CGFloat = 2.5
            let size = zoomScrollView.bounds.size
            let rect = CGRect(
                x: point.x - size.width / target / 2,
                y: point.y - size.height / target / 2,
                width: size.width / target,
                height: size.height / target
            )
            zoomScrollView.zoom(to: rect, animated: true)
        }
        updateZoomPanEnabled()
        onZoomScaleChange?()
    }
    
    @objc private func handleZoomPan(_ gesture: UIPanGestureRecognizer) {
        guard zoomScrollView.zoomScale > 1.01 else { return }
        
        if gesture.state == .began {
            edgeHandoffLocked = false
            return
        }
        
        let offsetX = zoomScrollView.contentOffset.x
        let maxOffsetX = max(0, zoomScrollView.contentSize.width - zoomScrollView.bounds.width)
        let velocity = gesture.velocity(in: zoomScrollView)
        let translation = gesture.translation(in: zoomScrollView)
        
        // 需要明显划过边缘才切页，避免刚贴边就换图
        let overscrollThreshold: CGFloat = 90
        let dragPastEdge: CGFloat = 140
        let flingVelocity: CGFloat = 900
        
        let pullingPrevious = offsetX < -overscrollThreshold
            || (offsetX <= 1.5 && translation.x > dragPastEdge)
        let pullingNext = offsetX > maxOffsetX + overscrollThreshold
            || (offsetX >= maxOffsetX - 1.5 && translation.x < -dragPastEdge)
        
        if gesture.state == .changed {
            guard !edgeHandoffLocked else { return }
            // changed 阶段要求更大位移，避免拖移看图时误触
            if pullingPrevious && translation.x > dragPastEdge + 20 {
                edgeHandoffLocked = true
                onReachedHorizontalEdgeWhileZoomed?(.previous)
            } else if pullingNext && translation.x < -(dragPastEdge + 20) {
                edgeHandoffLocked = true
                onReachedHorizontalEdgeWhileZoomed?(.next)
            }
            return
        }
        
        guard gesture.state == .ended || gesture.state == .cancelled else { return }
        guard !edgeHandoffLocked else { return }
        
        let atLeftEdge = offsetX <= 1.5 || offsetX < -overscrollThreshold * 0.5
        let atRightEdge = offsetX >= maxOffsetX - 1.5 || offsetX > maxOffsetX + overscrollThreshold * 0.5
        if atLeftEdge && (translation.x > dragPastEdge || velocity.x > flingVelocity) {
            edgeHandoffLocked = true
            onReachedHorizontalEdgeWhileZoomed?(.previous)
        } else if atRightEdge && (translation.x < -dragPastEdge || velocity.x < -flingVelocity) {
            edgeHandoffLocked = true
            onReachedHorizontalEdgeWhileZoomed?(.next)
        }
    }
}
