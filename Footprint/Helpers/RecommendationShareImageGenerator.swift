//
//  RecommendationShareImageGenerator.swift
//  Footprint
//
//  将旅行目的地推荐卡片渲染为可分享图片
//

import SwiftUI
import UIKit

/// 推荐分享图生成
enum RecommendationShareImageGenerator {
    private static let shareWidth: CGFloat = 390
    
    @MainActor
    static func generate(content: String, generatedAt: Date? = nil) -> UIImage? {
        let scheme = AppearanceManager.shared.resolvedColorScheme
        let card = RecommendationShareCardView(content: content, generatedAt: generatedAt)
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
            .frame(width: shareWidth)
        
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: shareWidth, height: nil)
        return renderer.uiImage
    }
}

/// 分享专用推荐卡片（浅/深双壳，固定宽度，便于 ImageRenderer）
struct RecommendationShareCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: String
    var generatedAt: Date?
    
    private var primaryText: Color {
        colorScheme == .dark
            ? .white
            : Color(red: 0.08, green: 0.08, blue: 0.10)
    }
    
    private var secondaryText: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.55)
            : Color(red: 0.40, green: 0.40, blue: 0.43)
    }
    
    private var cardBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [.black, Color(red: 0.12, green: 0.14, blue: 0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.969, green: 0.961, blue: 0.988),
                Color(red: 0.929, green: 0.937, blue: 0.969)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ai_function_recommend_title".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryText)
                    
                    if let generatedAt {
                        Text(formatGeneratedDate(generatedAt))
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                    }
                }
                
                RecommendationContentCardView(content: content)
            }
            
            destinationStyleBrandFooter
                .padding(.top, 24)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FootprintTheme.Radius.card, style: .continuous))
        .overlay {
            if colorScheme == .light {
                RoundedRectangle(cornerRadius: FootprintTheme.Radius.card, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            }
        }
        .shadow(
            color: colorScheme == .light ? Color.black.opacity(0.08) : .clear,
            radius: 16,
            y: 6
        )
    }
    
    /// 与地点分享极简海报同款底栏：左品牌两行 + 居中 AppIconLine + 右英文两行
    private var destinationStyleBrandFooter: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MooFootprint")
                    .font(.system(size: 6, weight: .regular))
                    .foregroundStyle(primaryText.opacity(0.85))
                Text("Record Every Journey")
                    .font(.system(size: 6, weight: .regular))
                    .foregroundStyle(secondaryText)
            }
            
            Spacer(minLength: 8)
            
            brandLogoImage
                .frame(width: Self.brandLogoSize, height: Self.brandLogoSize)
            
            Spacer(minLength: 8)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Record wonderful journeys")
                    .font(.system(size: 6, weight: .regular))
                    .foregroundStyle(primaryText.opacity(0.85))
                Text("Share beautiful moments")
                    .font(.system(size: 6, weight: .regular))
                    .foregroundStyle(secondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MooFootprint")
    }
    
    /// 略大于地点分享 14pt，分享预览里更易辨认
    private static let brandLogoSize: CGFloat = 18
    
    /// 用 UIKit 按屏幕 scale 预绘圆形 logo，避免 ImageRenderer 缩放发虚
    @ViewBuilder
    private var brandLogoImage: some View {
        if let logo = Self.makeCircularBrandLogo(size: Self.brandLogoSize) {
            Image(uiImage: logo)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
        } else {
            Image("AppIconLine")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .clipShape(Circle())
        }
    }
    
    private static func makeCircularBrandLogo(size: CGFloat) -> UIImage? {
        guard let icon = UIImage(named: "AppIconLine") else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()
            icon.draw(in: rect)
        }
    }
    
    private func formatGeneratedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
