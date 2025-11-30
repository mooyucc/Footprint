//
//  BadgeItemView.swift
//  Footprint
//
//  Created on 2025/11/29.
//

import SwiftUI

/// 单个勋章组件
struct BadgeItemView: View {
    let imageName: String
    let title: String
    let isUnlocked: Bool
    let cardSize: CGFloat
    let destinationCount: Int
    let yearRange: String?
    
    @Environment(\.colorScheme) var colorScheme
    
    init(
        imageName: String,
        title: String,
        isUnlocked: Bool,
        cardSize: CGFloat,
        destinationCount: Int = 0,
        yearRange: String? = nil
    ) {
        self.imageName = imageName
        self.title = title
        self.isUnlocked = isUnlocked
        self.cardSize = cardSize
        self.destinationCount = destinationCount
        self.yearRange = yearRange
    }
    
    var body: some View {
        ZStack {
            // 背景图片（撑满整个卡片，清晰可见）
            Group {
                if let image = UIImage(named: imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)  // 高质量插值，确保边缘光滑
                        .antialiased(true)     // 启用抗锯齿
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
            
            // 底部文字信息（带渐变背景）
            VStack {
                Spacer()
                
                ZStack(alignment: .bottom) {
                    // 黑色透明渐变背景（从下往上，0.7～0.05）
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
                    VStack(alignment: .leading, spacing: 2) {
                        // 第一排：国家名称（允许最多2行，自动缩放）
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                        
                        // 白色细线分割
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                        
                        // 第二排：左边地点图标+数字，右边年份数字
                        if isUnlocked && destinationCount > 0 {
                            HStack(spacing: 4) {
                                // 左边：地点图标+数字
                                HStack(spacing: 3) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white)
                                    Text("\(destinationCount)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                // 右边：年份数字（无图标）
                                if let yearRange = yearRange {
                                    Text(yearRange)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)
                                }
                            }
                        } else {
                            Text("not_visited".localized)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            // 玻璃边缘高光效果（精细边缘）
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    lineWidth: 1
                )
        )
        .overlay(
            // 顶部边缘高光（模拟光线折射）
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.4), location: 0.0),
                            .init(color: Color.white.opacity(0.15), location: 0.15),
                            .init(color: Color.clear, location: 0.3)
                        ]),
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .mask(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .frame(height: cardSize * 0.2)
                        .offset(y: -cardSize * 0.4)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    GeometryReader { geometry in
        let screenWidth = geometry.size.width
        let horizontalPadding: CGFloat = 16
        let columnSpacing: CGFloat = 16
        let numberOfColumns: CGFloat = 3
        let availableWidth = screenWidth - (horizontalPadding * 2) - (columnSpacing * (numberOfColumns - 1))
        let cardWidth = availableWidth / numberOfColumns
        
        HStack(spacing: 16) {
            BadgeItemView(
                imageName: "CountryBadge_CN",
                title: "中国",
                isUnlocked: true,
                cardSize: cardWidth,
                destinationCount: 5,
                yearRange: "2013～2024"
            )
            
            BadgeItemView(
                imageName: "CountryBadge_US",
                title: "美国",
                isUnlocked: false,
                cardSize: cardWidth
            )
        }
        .padding()
    }
}

