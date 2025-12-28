//
//  OnboardingIdentityTagView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 引导身份标签页：身份标签选择
struct OnboardingIdentityTagView: View {
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedPersonaOption: String = UserProfileOptions.localizedPersona(for: "traveler")
    @State private var customPersona: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var personaOptions: [String] {
        UserProfileOptions.localizedPersonaOptions()
    }
    
    let onNext: () -> Void
    
    private var finalPersona: String {
        let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
        if selectedPersonaOption == customOptionLocalized {
            return customPersona.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return selectedPersonaOption
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
                Text("onboarding_identity_tag_title".localized)
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
                            
                            Text("onboarding_identity_tag_title".localized)
                                .font(.headline)
                        }
                        
                        Text("onboarding_identity_tag_description".localized)
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
                    
                    // 身份标签选择卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("identity_tag".localized)
                            .font(.headline)
                        
                        // 标签网格
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(personaOptions.filter { $0 != "自定义" }, id: \.self) { option in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPersonaOption = option
                                    }
                                } label: {
                                    Text(option)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedPersonaOption == option ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                .fill(selectedPersonaOption == option ? 
                                                      brandColorManager.currentBrandColor : 
                                                      Color(.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                .stroke(selectedPersonaOption == option ? 
                                                        Color.clear : 
                                                        Color.primary.opacity(0.1), lineWidth: 0.5)
                                        )
                                        .shadow(color: selectedPersonaOption == option ? 
                                                brandColorManager.currentBrandColor.opacity(0.3) : 
                                                Color.clear, radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // 自定义选项
                        VStack(alignment: .leading, spacing: 12) {
                            let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedPersonaOption = customOptionLocalized
                                    // 延迟聚焦，确保动画完成后再聚焦
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isTextFieldFocused = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(customOptionLocalized)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedPersonaOption == customOptionLocalized ? .white : .primary)
                                    
                                    Spacer()
                                    
                                    if selectedPersonaOption == customOptionLocalized {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(selectedPersonaOption == customOptionLocalized ? 
                                              brandColorManager.currentBrandColor : 
                                              Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(selectedPersonaOption == customOptionLocalized ? 
                                                Color.clear : 
                                                Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                                .shadow(color: selectedPersonaOption == customOptionLocalized ? 
                                        brandColorManager.currentBrandColor.opacity(0.3) : 
                                        Color.clear, radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if selectedPersonaOption == customOptionLocalized {
                                TextField("identity_tag_placeholder".localized, text: $customPersona)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($isTextFieldFocused)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                    // 保存身份标签
                    if !finalPersona.isEmpty {
                        let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
                        let personaToSave: String = {
                            if selectedPersonaOption == customOptionLocalized {
                                // 自定义值，直接保存
                                return customPersona.trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                // 预定义选项，保存键值
                                return UserProfileOptions.personaKey(for: selectedPersonaOption)
                            }
                        }()
                        appleSignInManager.setPersonaTag(personaToSave)
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
                .disabled(selectedPersonaOption == UserProfileOptions.localizedPersona(for: "custom") && finalPersona.isEmpty)
                .opacity(selectedPersonaOption == UserProfileOptions.localizedPersona(for: "custom") && finalPersona.isEmpty ? 0.6 : 1.0)
                
                // 页面指示器（显示基本设置的6个步骤）
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    
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
            // 如果已有保存的身份标签，恢复选择
            if !appleSignInManager.personaTag.isEmpty {
                let savedTag = appleSignInManager.personaTag
                if personaOptions.contains(savedTag) {
                    selectedPersonaOption = savedTag
                } else {
                    selectedPersonaOption = "自定义"
                    customPersona = savedTag
                }
            }
        }
    }
}

#Preview {
    OnboardingIdentityTagView {
        print("Next tapped")
    }
    .environmentObject(BrandColorManager.shared)
    .environmentObject(AppleSignInManager.shared)
}

