//
//  OnboardingPage1View.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 引导第一页：语言和国家设置
struct OnboardingPage1View: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var countryManager: CountryManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingLanguagePicker = false
    @State private var showingCountryPicker = false
    
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
                Text("onboarding_page1_title".localized)
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
                    // 语言设置卡片
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .frame(width: 32)
                            
                            Text("onboarding_page1_language_title".localized)
                                .font(.headline)
                        }
                        
                        Button {
                            showingLanguagePicker = true
                        } label: {
                            HStack {
                                Text(languageManager.currentLanguage.flag)
                                    .font(.title2)
                                
                                Text(languageManager.currentLanguage.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
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
                    
                    // 国家设置卡片
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "flag")
                                .font(.title2)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .frame(width: 32)
                            
                            Text("onboarding_page1_country_title".localized)
                                .font(.headline)
                        }
                        
                        Button {
                            showingCountryPicker = true
                        } label: {
                            HStack {
                                Text(countryManager.currentCountry.flag)
                                    .font(.title2)
                                
                                Text(countryManager.currentCountryLocalizedName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("onboarding_page1_country_description".localized)
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
        .sheet(isPresented: $showingLanguagePicker) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingCountryPicker) {
            CountrySelectionView()
        }
    }
}

#Preview {
    OnboardingPage1View {
        print("Next tapped")
    }
    .environmentObject(LanguageManager.shared)
    .environmentObject(CountryManager.shared)
    .environmentObject(BrandColorManager.shared)
}

