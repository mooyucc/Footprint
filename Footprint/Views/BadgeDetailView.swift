//
//  BadgeDetailView.swift
//  Footprint
//
//  Created on 2025/12/XX.
//

import SwiftUI

/// 徽章详情全屏视图，支持翻转查看地点列表
struct BadgeDetailView: View {
    let imageName: String
    let title: String
    let isUnlocked: Bool
    let destinations: [TravelDestination]
    let yearRange: String?
    let badgeType: BadgeType
    
    @Binding var isPresented: Bool
    @State private var isFlipped = false
    @State private var provinceGround: Color?
    @EnvironmentObject private var brandColorManager: BrandColorManager
    
    // 3D翻转动画
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                detailBackground
                
                // 翻转容器：仅票根做 3D；背面列表平面淡入，避免 Material/Glass 在 3D 下采样发灰
                ZStack {
                    badgeFrontView
                        .rotation3DEffect(
                            .degrees(rotationAngle),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .opacity(showsBadgeFront ? 1 : 0)
                        .zIndex(showsBadgeFront ? 1 : 0)
                        .allowsHitTesting(showsBadgeFront)
                    
                    destinationsBackView
                        .opacity(showsDestinationsBack ? 1 : 0)
                        .zIndex(showsDestinationsBack ? 1 : 0)
                        .allowsHitTesting(showsDestinationsBack)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 关闭按钮（使用Liquid Glass效果）
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColorScheme.glassCardBorder, lineWidth: 1)
                        )
                        .shadow(
                            color: AppColorScheme.iconButtonShadow.color,
                            radius: AppColorScheme.iconButtonShadow.radius,
                            x: AppColorScheme.iconButtonShadow.x,
                            y: AppColorScheme.iconButtonShadow.y
                        )
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden()
        }
    }
    
    /// 省份正面用票根深色铺满屏幕；翻到地点列表后回到氛围背景。
    @ViewBuilder
    private var detailBackground: some View {
        ZStack {
            FootprintAtmosphereBackground(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            )
            if badgeType == .province {
                provinceScreenGround
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .opacity(showsProvinceGround ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showsProvinceGround)
    }

    private var showsProvinceGround: Bool {
        badgeType == .province && !showsDestinationsBack
    }

    private var provinceScreenGround: Color {
        if let provinceGround {
            return provinceGround
        }
        let face = ProvinceTicketPicker.face(seed: title, destinations: destinations)
        return ProvinceTicketPicker.colors(for: nil, paletteIndex: face.paletteIndex).ground
    }

    // MARK: - 正面视图（票根）
    
    @ViewBuilder
    private var badgeFrontView: some View {
        if badgeType == .province {
            provinceTicketFront
        } else {
            countryTicketFront
        }
    }
    
    /// 省份：彩底票根，照片来自该省地点
    private var provinceTicketFront: some View {
        GeometryReader { geometry in
            let topReserve: CGFloat = 72
            let bottomReserve: CGFloat = 40
            let availableHeight = max(geometry.size.height - topReserve - bottomReserve, 280)
            // 与国家票根同宽：屏宽 × 70%，上限 320
            let width = min(
                geometry.size.width * 0.70,
                320,
                availableHeight * ProvinceTicketMetrics.aspect
            )
            let height = width / ProvinceTicketMetrics.aspect
            ProvinceTicketDetail(
                seed: title,
                destinations: destinations,
                size: CGSize(width: width, height: height),
                isUnlocked: isUnlocked,
                onGroundChange: { provinceGround = $0 }
            )
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onTapGesture { flipCard() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("view_destinations".localized)
            .position(
                x: geometry.size.width / 2,
                y: topReserve + availableHeight / 2
            )
        }
    }
    
    private var countryTicketFront: some View {
        GeometryReader { geometry in
            let topReserve: CGFloat = 72
            let bottomReserve: CGFloat = 40
            let availableHeight = max(geometry.size.height - topReserve - bottomReserve, 280)
            let layout = BadgeTicketLayout(
                container: CGSize(width: geometry.size.width, height: availableHeight)
            )
            let shape = BadgeTicketShape(layout: layout)
            
            ticketFace(layout: layout)
                .frame(width: layout.width, height: layout.height)
                .background(Self.ticketPaper)
                .clipShape(shape, style: FillStyle(eoFill: true))
                .overlay(ticketPerforation(layout: layout))
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
                .contentShape(shape)
                .onTapGesture { flipCard() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title), \(ticketSerialText)")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("view_destinations".localized)
                .position(
                    x: geometry.size.width / 2,
                    y: topReserve + availableHeight / 2
                )
        }
    }
    
    private func ticketFace(layout: BadgeTicketLayout) -> some View {
        VStack(spacing: 0) {
            ticketPhoto
                .frame(width: layout.photoSize.width, height: layout.photoSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, layout.photoInset)
                .padding(.horizontal, layout.photoInset)
            
            Color.clear
                .frame(height: layout.bandHeight)
            
            ticketStub
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    private var ticketPhoto: some View {
        Group {
            if let image = UIImage(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(red: 0.90, green: 0.89, blue: 0.86)
                    Image(systemName: isUnlocked ? "flag.fill" : "flag")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.28))
                }
            }
        }
        .saturation(isUnlocked ? 1.0 : 0.0)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
    
    private var ticketStub: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(ticketSerialText)
                    .tracking(showsTicketSerial ? 0.8 : 0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 8)
                Text(ticketTitleText)
                    .tracking(ticketTitleTracking)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .layoutPriority(1)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.14))
            
            BadgeTicketBarcode(seed: BadgeTicketBarcodeSeed.make(imageName + "\u{1F}" + title))
                .frame(height: 36)
                .opacity(showsTicketSerial ? 1 : 0.3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
    }
    
    private func ticketPerforation(layout: BadgeTicketLayout) -> some View {
        BadgeTicketPerforation(y: layout.notchCenterY, inset: layout.notchRadius + 8)
            .stroke(
                Color.black.opacity(0.28),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3.5, 3.5])
            )
    }
    
    private static let ticketPaper = Color(red: 0.965, green: 0.953, blue: 0.925)
    
    private var showsTicketSerial: Bool {
        isUnlocked && !destinations.isEmpty && !(yearRange?.isEmpty ?? true)
    }
    
    private var ticketSerialText: String {
        if showsTicketSerial, let yearRange, !yearRange.isEmpty {
            return "NO.\(yearRange.replacingOccurrences(of: "～", with: "~"))"
        }
        return "not_visited".localized
    }
    
    private var ticketTitleText: String {
        titleContainsCJK ? title : title.uppercased()
    }
    
    private var ticketTitleTracking: CGFloat {
        titleContainsCJK ? 0 : 1.2
    }
    
    private var titleContainsCJK: Bool {
        title.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x4E00...0x9FFF, 0x3040...0x30FF, 0xAC00...0xD7AF:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - 背面视图（地点列表）
    
    /// 复用「所有地点」列表：仅年份 / 我的最爱（地区已由徽章范围限定）。
    private var destinationsBackView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    flipCard()
                } label: {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColorScheme.glassCardBorder, lineWidth: 1)
                        )
                        .shadow(
                            color: AppColorScheme.iconButtonShadow.color,
                            radius: AppColorScheme.iconButtonShadow.radius,
                            x: AppColorScheme.iconButtonShadow.x,
                            y: AppColorScheme.iconButtonShadow.y
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("view_badge".localized)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 4)
            
            AllDestinationsListView(
                scopedDestinations: destinations,
                title: title,
                availableBrowseModes: [.year, .favorites],
                initialBrowseMode: .year,
                showsDismissButton: false,
                isEmbedded: true
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 辅助方法
    
    private var showsBadgeFront: Bool { rotationAngle < 90 }
    private var showsDestinationsBack: Bool { rotationAngle > 90 }
    
    private func flipCard() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if isFlipped {
                rotationAngle = 0
            } else {
                rotationAngle = 180
            }
            isFlipped.toggle()
        }
    }
}

// MARK: - 票根形状

private struct BadgeTicketLayout {
    let width: CGFloat
    let photoInset: CGFloat
    let photoSize: CGSize
    let bandHeight: CGFloat
    let stubHeight: CGFloat
    let cornerRadius: CGFloat
    let notchRadius: CGFloat
    
    var notchCenterY: CGFloat { photoInset + photoSize.height + bandHeight / 2 }
    var height: CGFloat { photoInset + photoSize.height + bandHeight + stubHeight }
    
    init(container: CGSize) {
        let photoInset: CGFloat = 16
        let bandHeight: CGFloat = 28
        let stubHeight: CGFloat = 104
        let maxWidth = min(max(container.width, 1) * 0.70, 320)
        let maxHeight = max(container.height, 1)
        let overhead = photoInset + bandHeight + stubHeight
        let widthForHeight = (maxHeight - overhead) / 1.15 + photoInset * 2
        let width = min(maxWidth, max(photoInset * 2 + 96, widthForHeight))
        let photoWidth = width - photoInset * 2
        self.width = width
        self.photoInset = photoInset
        self.photoSize = CGSize(width: photoWidth, height: photoWidth * 1.15)
        self.bandHeight = bandHeight
        self.stubHeight = stubHeight
        self.cornerRadius = 20
        self.notchRadius = 11
    }
}

/// 圆角票纸减去左右两个圆孔。配合 `FillStyle(eoFill: true)` 挖出撕口。
private struct BadgeTicketShape: Shape {
    var cornerRadius: CGFloat
    var notchRadius: CGFloat
    var notchCenterY: CGFloat
    
    init(layout: BadgeTicketLayout) {
        self.cornerRadius = layout.cornerRadius
        self.notchRadius = layout.notchRadius
        self.notchCenterY = layout.notchCenterY
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        path.addEllipse(in: CGRect(
            x: -notchRadius,
            y: notchCenterY - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        ))
        path.addEllipse(in: CGRect(
            x: rect.width - notchRadius,
            y: notchCenterY - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        ))
        return path
    }
}

private struct BadgeTicketPerforation: Shape {
    var y: CGFloat
    var inset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: inset, y: y))
        path.addLine(to: CGPoint(x: rect.width - inset, y: y))
        return path
    }
}

enum BadgeTicketBarcodeSeed {
    static func make(_ string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash == 0 ? 1 : hash
    }
}

struct BadgeTicketBarcode: View {
    let seed: UInt64
    var ink: Color = Color(red: 0.10, green: 0.10, blue: 0.11)
    
    var body: some View {
        Canvas { context, size in
            var state = seed
            func nextUnit() -> UInt64 {
                state &+= 0x9E3779B97F4A7C15
                var z = state
                z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
                z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
                return z ^ (z >> 31)
            }
            
            var x: CGFloat = 0
            while x < size.width {
                let barWidth = CGFloat(1 + nextUnit() % 3)
                let gap = CGFloat(1 + nextUnit() % 2)
                let rect = CGRect(x: x, y: 0, width: min(barWidth, size.width - x), height: size.height)
                context.fill(Path(rect), with: .color(ink))
                x += barWidth + gap
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    BadgeDetailView(
        imageName: "CountryBadge_CN",
        title: "中国",
        isUnlocked: true,
        destinations: [],
        yearRange: "2013～2024",
        badgeType: .country,
        isPresented: .constant(true)
    )
    .environmentObject(BrandColorManager.shared)
}

