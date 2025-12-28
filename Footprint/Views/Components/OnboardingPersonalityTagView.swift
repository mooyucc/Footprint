//
//  OnboardingPersonalityTagView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 引导性格标签页：MBTI性格类型选择
struct OnboardingPersonalityTagView: View {
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedMbti: String = "INTJ"
    
    private let mbtiOptions: [String] = [
        "INTJ","INTP","ENTJ","ENTP",
        "INFJ","INFP","ENFJ","ENFP",
        "ISTJ","ISFJ","ESTJ","ESFJ",
        "ISTP","ISFP","ESTP","ESFP"
    ]
    
    let onNext: () -> Void
    
    // MBTI图标映射
    private func iconForMBTI(_ mbti: String) -> String {
        switch mbti {
        case "INTJ": return "brain.head.profile"      // 建筑师
        case "INTP": return "gearshape.2.fill"        // 逻辑学家
        case "ENTJ": return "crown.fill"              // 指挥官
        case "ENTP": return "lightbulb.fill"          // 辩论家
        case "INFJ": return "sparkles"                // 提倡者
        case "INFP": return "heart.text.square.fill"  // 调停者
        case "ENFJ": return "person.2.fill"           // 主人公
        case "ENFP": return "flame.fill"              // 竞选者
        case "ISTJ": return "checklist.checked"       // 物流师
        case "ISFJ": return "hand.raised.fill"        // 守护者
        case "ESTJ": return "building.2.fill"         // 总经理
        case "ESFJ": return "person.wave.2.fill"      // 执政官
        case "ISTP": return "wrench.and.screwdriver.fill" // 鉴赏家
        case "ISFP": return "paintbrush.fill"         // 探险家
        case "ESTP": return "bolt.fill"               // 企业家
        case "ESFP": return "sparkles.rectangle.stack.fill" // 表演者
        default: return "person.fill"
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
                Text("onboarding_personality_tag_title".localized)
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
                            Image(systemName: "brain.head.profile")
                                .font(.title2)
                                .foregroundColor(brandColorManager.currentBrandColor)
                                .frame(width: 32)
                            
                            Text("onboarding_personality_tag_title".localized)
                                .font(.headline)
                        }
                        
                        Text("onboarding_personality_tag_description".localized)
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
                    
                    // MBTI选择卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("mbti_title".localized)
                            .font(.headline)
                        
                        // MBTI网格 - 4列布局
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(mbtiOptions, id: \.self) { mbti in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedMbti = mbti
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: iconForMBTI(mbti))
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(selectedMbti == mbti ? .white : brandColorManager.currentBrandColor)
                                            .frame(height: 28)
                                        
                                        Text(mbti)
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundColor(selectedMbti == mbti ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(selectedMbti == mbti ? 
                                                  brandColorManager.currentBrandColor : 
                                                  Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedMbti == mbti ? 
                                                    Color.clear : 
                                                    Color.primary.opacity(0.1), lineWidth: 0.5)
                                    )
                                    .shadow(color: selectedMbti == mbti ? 
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
                    // 保存MBTI类型
                    appleSignInManager.setMbtiType(selectedMbti)
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
                        .fill(brandColorManager.currentBrandColor)
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
            // 如果已有保存的MBTI类型，恢复选择
            if !appleSignInManager.mbtiType.isEmpty {
                selectedMbti = appleSignInManager.mbtiType
            }
        }
    }
}

#Preview {
    OnboardingPersonalityTagView {
        print("Next tapped")
    }
    .environmentObject(BrandColorManager.shared)
    .environmentObject(AppleSignInManager.shared)
}

