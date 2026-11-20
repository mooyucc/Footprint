//
//  LocationWaterRipple.swift
//  Footprint
//
//  回忆动画：从地点荡开两三圈水透镜。
//  地图瓦片不进 SwiftUI 着色器，所以先按当前区域截一帧，盘内换成折射后的画面。
//

import CoreLocation
import MapKit
import SwiftUI

private enum LocationWaterRippleTiming {
    /// 与 LocationRipple.metal 的第三圈结束时间一致。
    static let playbackDuration: TimeInterval = 2.9
}

struct LocationWaterRipple<Marker: View>: View {
    let region: MKCoordinateRegion
    let coordinate: CLLocationCoordinate2D
    let canvasSize: CGSize
    let mapStyle: MapStyle
    let interfaceStyle: UIUserInterfaceStyle
    let onComplete: () -> Void
    @ViewBuilder var marker: () -> Marker

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    @State private var phase: Phase = .waiting
    @State private var didComplete = false

    var body: some View {
        ZStack {
            switch phase {
            case .waiting:
                Color.clear
            case .refracting(let image, let center, let startedAt):
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let elapsed = Float(timeline.date.timeIntervalSince(startedAt))
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .layerEffect(
                                ShaderLibrary.locationRipple(
                                    .float2(center),
                                    .float(elapsed)
                                ),
                                maxSampleOffset: CGSize(width: 44, height: 44)
                            )
                            .mask {
                                Canvas { context, size in
                                    fillRippleMask(in: context, size: size, center: center, time: elapsed)
                                }
                                .blur(radius: 12)
                            }
                        marker()
                            .position(center)
                    }
                }
            case .fadingRing(let center):
                Circle()
                    .strokeBorder(Color.black.opacity(0.18), lineWidth: 3)
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.72), lineWidth: 1.5)
                    }
                    .frame(width: 96, height: 96)
                    .position(center)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await play() }
    }

    private enum Phase {
        case waiting
        case refracting(image: UIImage, center: CGPoint, startedAt: Date)
        case fadingRing(center: CGPoint)
    }

    private func play() async {
        guard canvasSize.width > 1, canvasSize.height > 1 else {
            finish()
            return
        }

        let soft = UIImpactFeedbackGenerator(style: .soft)
        soft.prepare()

        if reduceMotion {
            phase = .fadingRing(center: screenPoint(in: canvasSize))
            soft.impactOccurred(intensity: 0.45)
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            finish()
            return
        }

        let snapshot = await Self.makeSnapshot(
            region: region,
            coordinate: coordinate,
            size: canvasSize,
            scale: displayScale,
            mapStyle: mapStyle,
            interfaceStyle: interfaceStyle
        )
        guard !Task.isCancelled else { return }

        guard let snapshot else {
            phase = .fadingRing(center: screenPoint(in: canvasSize))
            soft.impactOccurred(intensity: 0.45)
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            finish()
            return
        }

        phase = .refracting(
            image: snapshot.image,
            center: rippleCenter(in: snapshot),
            startedAt: Date()
        )
        soft.impactOccurred(intensity: 0.55)
        try? await Task.sleep(for: .seconds(LocationWaterRippleTiming.playbackDuration))
        guard !Task.isCancelled else { return }
        finish()
    }

    /// 与 LocationRipple.metal 同一组半径和衰减。盘内不透明，外缘靠模糊羽化。
    private func fillRippleMask(in context: GraphicsContext, size: CGSize, center: CGPoint, time: Float) {
        for index in 0..<3 {
            let age = time - Float(index) * 0.48
            guard age > 0 else { continue }
            let radius = 36 + age * 72
            let appear = smoothstep(0, 0.12, age)
            let life = 1 - smoothstep(1.35, 1.85, age)
            let edge = 1 - smoothstep(210, 255, radius)
            let fade = appear * life * edge
            guard fade > 0.02 else { continue }
            let outer = radius + 30
            let rect = CGRect(
                x: center.x - CGFloat(outer),
                y: center.y - CGFloat(outer),
                width: CGFloat(outer * 2),
                height: CGFloat(outer * 2)
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(Double(min(fade, 1))))
            )
        }
    }

    private func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// `point(for:)` 有时落在像素坐标。超出图像点尺寸时按 scale 折回。
    private func rippleCenter(in snapshot: MKMapSnapshotter.Snapshot) -> CGPoint {
        let raw = snapshot.point(for: coordinate)
        let imageSize = snapshot.image.size
        guard raw.x > imageSize.width * 1.5 || raw.y > imageSize.height * 1.5 else {
            return raw
        }
        let scale = max(snapshot.image.scale, 1)
        return CGPoint(x: raw.x / scale, y: raw.y / scale)
    }

    private func screenPoint(in size: CGSize) -> CGPoint {
        let span = region.span
        guard span.latitudeDelta > 0.000_01, span.longitudeDelta > 0.000_01 else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let latRatio = (coordinate.latitude - region.center.latitude + span.latitudeDelta / 2) / span.latitudeDelta
        let lonRatio = (coordinate.longitude - region.center.longitude + span.longitudeDelta / 2) / span.longitudeDelta
        return CGPoint(
            x: lonRatio * size.width,
            y: (1 - latRatio) * size.height
        )
    }

    private func finish() {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
    }

    private static func makeSnapshot(
        region: MKCoordinateRegion,
        coordinate: CLLocationCoordinate2D,
        size: CGSize,
        scale: CGFloat,
        mapStyle: MapStyle,
        interfaceStyle: UIUserInterfaceStyle
    ) async -> MKMapSnapshotter.Snapshot? {
        guard size.width > 1, size.height > 1,
              region.span.latitudeDelta > 0, region.span.longitudeDelta > 0,
              CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.preferredConfiguration = snapshotConfiguration(for: mapStyle)
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: interfaceStyle),
            UITraitCollection(displayScale: max(scale, 1))
        ])

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            return try await snapshotter.start()
        } catch {
            return nil
        }
    }

    private static func snapshotConfiguration(for style: MapStyle) -> MKMapConfiguration {
        switch style {
        case .muted:
            MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        case .standard:
            MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        case .hybrid:
            MKHybridMapConfiguration(elevationStyle: .realistic)
        case .imagery:
            MKImageryMapConfiguration(elevationStyle: .realistic)
        }
    }
}
