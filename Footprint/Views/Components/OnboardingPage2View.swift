//
//  OnboardingPage2View.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 引导第二页：外观模式和主题颜色设置
struct OnboardingPage2View: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) private var colorScheme
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                // 左侧留空（保持居中）
                Spacer()
                    .frame(width: 80)
                
                Spacer()
                
                // 标题
                Text("onboarding_page2_title".localized)
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
                    // 外观模式设置卡片
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "paintbrush.fill")
                                .font(.title2)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .frame(width: 32)
                            
                            Text("onboarding_page2_appearance_title".localized)
                                .font(.headline)
                        }
                        
                        Picker("appearance_mode".localized, selection: Binding(
                            get: { appearanceManager.currentMode },
                            set: { newMode in
                                appearanceManager.setAppearanceMode(newMode)
                            }
                        )) {
                            ForEach(AppearanceManager.AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.displayName)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("onboarding_page2_appearance_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    
                    // 主题颜色设置卡片
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "paintpalette.fill")
                                .font(.title2)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .frame(width: 32)
                            
                            Text("onboarding_page2_color_title".localized)
                                .font(.headline)
                        }
                        
                        HStack(spacing: 16) {
                            // 颜色预览
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(brandColorManager.currentBrandColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("onboarding_page2_color_preview".localized)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if brandColorManager.isUsingCustomColor {
                                    Text("onboarding_page2_color_custom".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("onboarding_page2_color_default".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            ColorPicker("select_brand_color".localized, selection: Binding(
                                get: {
                                    brandColorManager.currentBrandColor
                                },
                                set: { newColor in
                                    brandColorManager.setCustomBrandColor(newColor)
                                }
                            ), supportsOpacity: false)
                            .labelsHidden()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        
                        // 重置按钮（仅在使用了自定义颜色时显示）
                        if brandColorManager.isUsingCustomColor {
                            Button {
                                brandColorManager.resetBrandColorToDefault()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("reset_to_default_color".localized)
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        
                        Text("onboarding_page2_color_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
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
                    onComplete()
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
                        .fill(brandColorManager.currentBrandColor)
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
        .preferredColorScheme(appearanceManager.preferredColorScheme)
    }
}

#Preview {
    OnboardingPage2View {
        print("Complete tapped")
    }
    .environmentObject(AppearanceManager.shared)
    .environmentObject(BrandColorManager.shared)
}

