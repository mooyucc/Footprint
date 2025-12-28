//
//  OnboardingCoordinatorView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 引导流程协调器：管理整个首次启动引导流程
struct OnboardingCoordinatorView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var countryManager: CountryManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    
    @State private var currentStep: OnboardingStep = .welcome
    @Binding var isPresented: Bool
    
    enum OnboardingStep {
        case welcome
        case identityTag  // 身份标签设置
        case personalityTag  // 性格标签设置
        case userAttributes  // 用户属性设置（性别、年龄段）
        case constellation  // 星座设置
        case page1  // 语言和国家设置
        case page2  // 外观模式和主题颜色设置
        case paywall  // 订阅页面
    }
    
    var body: some View {
        ZStack {
            // 确保整个引导流程有背景，防止底层内容透出
            Color(.systemBackground)
                .ignoresSafeArea()
            
            switch currentStep {
            case .welcome:
                WelcomeView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .page1
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            
            case .page1:
                OnboardingPage1View {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .page2
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            case .page2:
                OnboardingPage2View {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .identityTag
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            case .identityTag:
                OnboardingIdentityTagView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .personalityTag
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            case .personalityTag:
                OnboardingPersonalityTagView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .userAttributes
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            case .userAttributes:
                OnboardingUserAttributesView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .constellation
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            case .constellation:
                OnboardingConstellationView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentStep = .paywall
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
            case .paywall:
                PaywallView(isOnboarding: true, onSkip: {
                    completeOnboarding()
                })
                .environmentObject(purchaseManager)
                .environmentObject(entitlementManager)
                .environmentObject(brandColorManager)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }
    
    /// 完成引导流程
    private func completeOnboarding() {
        // 标记引导已完成
        FirstLaunchManager.shared.markOnboardingCompleted()
        
        // 关闭引导视图
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

#Preview {
    OnboardingCoordinatorView(isPresented: .constant(true))
        .environmentObject(LanguageManager.shared)
        .environmentObject(CountryManager.shared)
        .environmentObject(BrandColorManager.shared)
        .environmentObject(AppearanceManager.shared)
        .environmentObject(PurchaseManager.shared)
        .environmentObject(EntitlementManager.shared)
        .environmentObject(AppleSignInManager.shared)
}

