//
//  OnboardingConstellationView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 引导星座页：星座选择
struct OnboardingConstellationView: View {
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedConstellation: String = UserProfileOptions.localizedConstellation(for: "prefer_not_to_say")
    
    private var constellationOptions: [String] {
        UserProfileOptions.localizedConstellationOptions()
    }
    
    let onNext: () -> Void
    
    // 星座图标映射（使用Assets中的图标）
    private func iconNameForConstellation(_ constellation: String) -> String? {
        switch constellation {
        case "白羊座": return "Aries"
        case "金牛座": return "Taurus"
        case "双子座": return "Gemini"
        case "巨蟹座": return "Cancer"
        case "狮子座": return "Leo"
        case "处女座": return "Virgo"
        case "天秤座": return "Libra"
        case "天蝎座": return "Scorpio"
        case "射手座": return "Sagittarius"
        case "摩羯座": return "Capricornus"
        case "水瓶座": return "Aquarius"
        case "双鱼座": return "Pisces"
        case "不愿透露": return nil  // 使用系统图标
        default: return nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                // 左侧留空（保持居中）
                Spacer()
                    .frame(width: 80)
                
                Spacer()
                
                // 标题
                Text("onboarding_constellation_title".localized)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 右侧占位（保持居中）
                Spacer()
                    .frame(width: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            // 内容区域
            ScrollView {
                VStack(spacing: 24) {
                    // 说明文字卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .frame(width: 32)
                            
                            Text("onboarding_constellation_title".localized)
                                .font(.headline)
                        }
                        
                        Text("onboarding_constellation_description".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    
                    // 星座选择卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("constellation_title".localized)
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(constellationOptions, id: \.self) { option in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedConstellation = option
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        if let iconName = iconNameForConstellation(option) {
                                            // 使用Assets中的星座图标
                                            if let uiImage = UIImage(named: iconName) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 28, height: 28)
                                                    .opacity(selectedConstellation == option ? 1.0 : 0.7)
                                            } else {
                                                // 如果找不到图片，使用默认图标
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 24, weight: .medium))
                                                    .foregroundColor(selectedConstellation == option ? .white : brandColorManager.currentBrandColor)
                                                    .frame(height: 28)
                                            }
                                        } else {
                                            // "不愿透露"使用系统图标
                                            Image(systemName: "eye.slash.fill")
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundColor(selectedConstellation == option ? .white : brandColorManager.currentBrandColor)
                                                .frame(height: 28)
                                        }
                                        
                                        Text(option)
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.medium)
                                            .foregroundColor(selectedConstellation == option ? .white : .primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .fill(selectedConstellation == option ? 
                                                  brandColorManager.currentBrandColor : 
                                                  Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .stroke(selectedConstellation == option ? 
                                                    Color.clear : 
                                                    Color.primary.opacity(0.1), lineWidth: 0.5)
                                    )
                                    .shadow(color: selectedConstellation == option ? 
                                            brandColorManager.currentBrandColor.opacity(0.3) : 
                                            Color.clear, radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            
            // 底部按钮
            VStack(spacing: 12) {
                Button {
                    // 保存星座（如果选择"不愿透露"则不保存）
                    let preferNotToSayConstellation = UserProfileOptions.localizedConstellation(for: "prefer_not_to_say")
                    if selectedConstellation != preferNotToSayConstellation {
                        let constellationKey = UserProfileOptions.constellationKey(for: selectedConstellation)
                        appleSignInManager.setConstellation(constellationKey)
                    }
                    onNext()
                } label: {
                    Text("onboarding_next".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(brandColorManager.currentBrandColor)
                        )
                }
                .padding(.horizontal, 20)
                
                // 页面指示器（显示基本设置的6个步骤）
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(brandColorManager.currentBrandColor)
                        .frame(width: 8, height: 8)
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    Color.pink.opacity(0.08),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
        )
        .onAppear {
            // 如果已有保存的星座，恢复选择
            if !appleSignInManager.constellation.isEmpty {
                selectedConstellation = appleSignInManager.constellation
            }
        }
    }
}

#Preview {
    OnboardingConstellationView {
        print("Next tapped")
    }
    .environmentObject(BrandColorManager.shared)
    .environmentObject(AppleSignInManager.shared)
}

