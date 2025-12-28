//
//  DestinationRow.swift
//  Footprint
//
//  Created by GPT-5 Codex on 2025/11/08.
//

import SwiftUI

struct DestinationRow: View {
    let destination: TravelDestination
    let showsDisclosureIndicator: Bool
    
    init(destination: TravelDestination, showsDisclosureIndicator: Bool = false) {
        self.destination = destination
        self.showsDisclosureIndicator = showsDisclosureIndicator
    }
    
    @StateObject private var countryManager = CountryManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    private var visitDateText: String {
        destination.visitDate.localizedFormatted(dateStyle: .medium)
    }

    private var regionTag: (text: String, color: Color)? {
        if countryManager.isDomestic(country: destination.country) {
            return ("domestic".localized, .blue)
        } else if !destination.country.isEmpty {
            return ("international".localized, .green)
        }
        return nil
    }
    
    private var countryText: String {
        if destination.country.isEmpty {
            return languageManager.currentLanguage == .chinese || languageManager.currentLanguage == .chineseTraditional ? "未知國家" : "Unknown Country"
        }
        return destination.country
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 深蓝色背景卡片
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.15, green: 0.25, blue: 0.4)) // 深蓝色背景
                .frame(height: 120)
            
            // 背景图片（如果有）
            // 优先使用原图，如果没有原图才使用缩略图
            if let data = destination.photoData ?? destination.photoThumbnailData,
               let image = UIImage(data: data) {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)  // 高质量插值
                        .antialiased(true)     // 启用抗锯齿
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.3) // 半透明背景
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            // 内容层
            VStack(alignment: .leading, spacing: 0) {
                // 顶部区域：标签和图标
                HStack(alignment: .top) {
                    // 左上角标签
                    if let tag = regionTag {
                        Text(tag.text)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.color.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // 右上角半透明图标
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Spacer()
                
                // 底部内容区域
            VStack(alignment: .leading, spacing: 6) {
                    // 地点名称
                    Text(destination.name.isEmpty ? "-" : destination.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // 国家信息（带图标）
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                        Text(countryText)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    // 日期信息（带图标）
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                Text(visitDateText)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
            }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // 底部飞机图标（右下角）
                HStack {
            Spacer()
                    Image(systemName: "airplane")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.trailing, 16)
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(height: 120)
        .contentShape(Rectangle())
    }
    
}

