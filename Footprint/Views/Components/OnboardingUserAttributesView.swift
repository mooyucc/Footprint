//
//  OnboardingUserAttributesView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 引导用户属性页：性别、年龄段、星座选择
struct OnboardingUserAttributesView: View {
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedGender: String = UserProfileOptions.localizedGender(for: "prefer_not_to_say")
    @State private var selectedAgeGroup: String = UserProfileOptions.localizedAgeGroup(for: "prefer_not_to_say")
    
    private var genderOptions: [String] {
        UserProfileOptions.localizedGenderOptions()
    }
    
    private var ageGroupOptions: [String] {
        UserProfileOptions.localizedAgeGroupOptions()
    }
    
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                // 左侧留空（保持居中）
                Spacer()
                    .frame(width: 80)
                
                Spacer()
                
                // 标题
                Text("onboarding_user_attributes_title".localized)
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
                            Image(systemName: "person.text.rectangle")
                                .font(.title2)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .frame(width: 32)
                            
                            Text("onboarding_user_attributes_title".localized)
                                .font(.headline)
                        }
                        
                        Text("onboarding_user_attributes_description_short".localized)
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
                    
                    // 性别选择卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("gender_title".localized)
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(genderOptions, id: \.self) { option in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedGender = option
                                    }
                                } label: {
                                    Text(option)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedGender == option ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                .fill(selectedGender == option ? 
                                                      brandColorManager.currentBrandColor : 
                                                      Color(.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                .stroke(selectedGender == option ? 
                                                        Color.clear : 
                                                        Color.primary.opacity(0.1), lineWidth: 0.5)
                                        )
                                        .shadow(color: selectedGender == option ? 
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
                    
                    // 年龄段选择卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("age_group_title".localized)
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(ageGroupOptions, id: \.self) { option in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedAgeGroup = option
                                    }
                                } label: {
                                    Text(option)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedAgeGroup == option ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(selectedAgeGroup == option ? 
                                                      brandColorManager.currentBrandColor : 
                                                      Color(.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(selectedAgeGroup == option ? 
                                                        Color.clear : 
                                                        Color.primary.opacity(0.1), lineWidth: 0.5)
                                        )
                                        .shadow(color: selectedAgeGroup == option ? 
                                                brandColorManager.currentBrandColor.opacity(0.3) : 
                                                Color.clear, radius: 6, x: 0, y: 3)
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
                    // 保存用户属性（如果选择"不愿透露"则不保存）
                    let preferNotToSayGender = UserProfileOptions.localizedGender(for: "prefer_not_to_say")
                    let preferNotToSayAge = UserProfileOptions.localizedAgeGroup(for: "prefer_not_to_say")
                    
                    if selectedGender != preferNotToSayGender {
                        let genderKey = UserProfileOptions.genderKey(for: selectedGender)
                        appleSignInManager.setGender(genderKey)
                    }
                    if selectedAgeGroup != preferNotToSayAge {
                        let ageGroupKey = UserProfileOptions.ageGroupKey(for: selectedAgeGroup)
                        appleSignInManager.setAgeGroup(ageGroupKey)
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
                        .fill(brandColorManager.currentBrandColor)
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
            // 如果已有保存的用户属性，恢复选择（转换为本地化显示值）
            if !appleSignInManager.gender.isEmpty {
                selectedGender = UserProfileOptions.genderLocalizedValue(for: appleSignInManager.gender)
            }
            if !appleSignInManager.ageGroup.isEmpty {
                selectedAgeGroup = UserProfileOptions.ageGroupLocalizedValue(for: appleSignInManager.ageGroup)
            }
        }
    }
}

#Preview {
    OnboardingUserAttributesView {
        print("Next tapped")
    }
    .environmentObject(BrandColorManager.shared)
    .environmentObject(AppleSignInManager.shared)
}

