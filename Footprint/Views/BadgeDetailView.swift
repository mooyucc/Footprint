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
    @Environment(\.colorScheme) var colorScheme
    
    // 3D翻转动画
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：使用渐变背景（符合配色标准）
                AppColorScheme.pageBackgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
                
                // 翻转容器
                ZStack {
                    // 正面：徽章卡片
                    badgeFrontView
                        .rotation3DEffect(
                            .degrees(rotationAngle),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .opacity(rotationAngle < 90 ? 1 : 0)
                        .zIndex(rotationAngle < 90 ? 1 : 0)
                    
                    // 背面：地点列表
                    destinationsBackView
                        .rotation3DEffect(
                            .degrees(rotationAngle - 180),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .opacity(rotationAngle > 90 ? 1 : 0)
                        .zIndex(rotationAngle > 90 ? 1 : 0)
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
                
                // 翻转提示按钮（底部，使用半透明卡片样式）
                VStack {
                    Spacer()
                    Button {
                        flipCard()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isFlipped ? "photo.fill" : "list.bullet")
                                .font(.system(size: 16, weight: .semibold))
                            Text(isFlipped ? "view_badge".localized : (destinations.isEmpty ? "no_destinations".localized : "view_destinations".localized))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .glassCardStyle(material: .regularMaterial, cornerRadius: 24, for: colorScheme)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden()
        }
    }
    
    // MARK: - 正面视图（徽章卡片）
    
    private var badgeFrontView: some View {
        GeometryReader { geometry in
            let cardSize = min(geometry.size.width, geometry.size.height) * 0.85
            
            ZStack {
                // 背景图片
                Group {
                    if let image = UIImage(named: imageName) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: isUnlocked ? "flag.fill" : "flag")
                            .font(.system(size: cardSize * 0.3))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.tertiarySystemBackground))
                    }
                }
                .saturation(isUnlocked ? 1.0 : 0.0)
                .opacity(isUnlocked ? 1.0 : 0.6)
                .frame(width: cardSize, height: cardSize)
                .clipped()
                
                // 底部文字信息
                VStack {
                    Spacer()
                    
                    ZStack(alignment: .bottom) {
                        // 黑色透明渐变背景
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.05)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: cardSize * 0.4)
                        
                        // 文字内容
                        VStack(alignment: .leading, spacing: 4) {
                            // 标题
                            Text(title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .fixedSize(horizontal: false, vertical: true)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            
                            // 分割线
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 1)
                            
                            // 统计信息
                            if isUnlocked && !destinations.isEmpty {
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        Text("\(destinations.count) " + "locations".localized)
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    if let yearRange = yearRange {
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.8))
                                            Text(yearRange)
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            } else {
                                Text("not_visited".localized)
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                }
            }
            .frame(width: cardSize, height: cardSize)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.8), location: 0.0),
                                .init(color: Color.white.opacity(0.6), location: 0.2),
                                .init(color: Color.white.opacity(0.3), location: 0.5),
                                .init(color: Color.white.opacity(0.1), location: 0.8),
                                .init(color: Color.white.opacity(0.05), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    // MARK: - 背面视图（地点列表）
    
    private var destinationsBackView: some View {
        VStack(spacing: 0) {
            // 标题栏
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 60)
                
                if !destinations.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColorScheme.iconColor)
                        Text("\(destinations.count) " + "locations".localized)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 20)
            
            // 地点列表
            if destinations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("no_destinations".localized)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(destinations.sorted(by: { $0.visitDate > $1.visitDate })) { destination in
                            NavigationLink {
                                DestinationDetailView(destination: destination)
                            } label: {
                                DestinationRow(destination: destination, showsDisclosureIndicator: true)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .background(
                                Group {
                                    if colorScheme == .dark {
                                        // 深色模式：使用半透明深灰色背景（渲染更快）
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(.systemBackground).opacity(0.85))
                                    } else {
                                        // 浅色模式：使用半透明白色背景（渲染更快）
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.85))
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppColorScheme.glassCardBorder, lineWidth: 1)
                            )
                            .shadow(
                                color: AppColorScheme.glassCardShadow.color,
                                radius: AppColorScheme.glassCardShadow.radius,
                                x: AppColorScheme.glassCardShadow.x,
                                y: AppColorScheme.glassCardShadow.y
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 辅助方法
    
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
}

