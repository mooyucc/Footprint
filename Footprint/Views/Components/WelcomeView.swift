//
//  WelcomeView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

/// 欢迎页面：类似iPhone开机时的"你好"界面
struct WelcomeView: View {
    @EnvironmentObject var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) var colorScheme
    let onContinue: () -> Void
    
    @State private var showHello = false
    @State private var showSubtitle = false
    @State private var showButton = false
    @State private var helloOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 渐变背景：使用App配色标准（浅蓝色到浅粉色）
            AppColorScheme.pageBackgroundGradient(for: colorScheme)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 40) {
                Spacer()
                
                // "你好"主标题
                Text("onboarding_welcome_hello".localized)
                    .font(.system(size: 64, weight: .light, design: .default))
                    .foregroundColor(.primary)
                    .opacity(showHello ? 1 : 0)
                    .offset(y: showHello ? helloOffset : 20)
                
                // 副标题
                Text("onboarding_welcome_subtitle".localized)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                
                Spacer()
                
                // 继续按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onContinue()
                    }
                } label: {
                    Text("onboarding_welcome_continue".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(brandColorManager.currentBrandColor)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.9)
            }
        }
        .onAppear {
            // 动画序列：标题 -> 副标题 -> 按钮
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                showHello = true
            }
            
            // 启动"你好"文字的上下扭动动画
            startHelloAnimation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    showSubtitle = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showButton = true
                }
            }
        }
    }
    
    // MARK: - 动画方法
    
    /// 启动"你好"文字的上下扭动动画
    private func startHelloAnimation() {
        // 延迟启动，等待文字出现动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 使用 easeInOut 和 repeatForever 实现持续循环的上下扭动
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                helloOffset = 8
            }
        }
    }
}

#Preview {
    WelcomeView {
        print("Continue tapped")
    }
    .environmentObject(BrandColorManager.shared)
}

