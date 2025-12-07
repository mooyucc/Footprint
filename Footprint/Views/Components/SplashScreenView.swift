//
//  SplashScreenView.swift
//  Footprint
//
//  Created by Auto on 2025/01/XX.
//

import SwiftUI

/// 启动画面视图：用于提升用户体验并错开反向地理编码的高峰
struct SplashScreenView: View {
    @Binding var isPresented: Bool
    
    // 动画状态变量
    @State private var showBars = false
    @State private var showSquid = false
    @State private var showText = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 动画和初始化时间控制
    private let minDisplayTime: TimeInterval = 2.5  // 最小显示时间（保证动画流畅）
    private let maxDisplayTime: TimeInterval = 5.0  // 最大等待时间（避免等待太久）
    @State private var animationStartTime: Date?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 整体背景 - 白色（浅色模式）或深色（深色模式）
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    ZStack {
                        // 1. 背景色块 (Background Bars) - 三条彩色矩形条
                        Group {
                            // 绿色条（上）
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.8, green: 0.87, blue: 0.45)) // 近似浅绿色
                                .frame(width: 260, height: 70)
                                .rotationEffect(.degrees(-5))
                                .offset(
                                    x: -10,
                                    y: showBars ? -40 : -90  // 平滑下落动画
                                )
                                .opacity(showBars ? 1 : 0)
                            
                            // 黄色条（中）
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.98, green: 0.91, blue: 0.51)) // 近似黄色
                                .frame(width: 270, height: 70)
                                .offset(y: 0)
                                .opacity(showBars ? 0.8 : 0)
                                .scaleEffect(showBars ? 1 : 0.5) // 缩放动画
                            
                            // 蓝色条（下）
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.58, green: 0.9, blue: 0.83)) // 近似青色
                                .frame(width: 260, height: 70)
                                .rotationEffect(.degrees(3))
                                .offset(
                                    x: 10,
                                    y: showBars ? 40 : 90  // 平滑上升动画
                                )
                                .opacity(showBars ? 1 : 0)
                        }
                        
                        // 2. 墨鱼图标 (Squid Icon) - 使用项目中的图片资源
                        Image("LoginMooyu")
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180)
                            .scaleEffect(showSquid ? 1 : 0.8)
                            .opacity(showSquid ? 1 : 0)
                            .offset(y: showSquid ? 0 : 20)
                    }
                    .frame(height: 280) // 限制logo区域高度
                    
                    // 3. 文字 (Text) - 使用项目中的图片资源
                    Image("LoginText")
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                        .padding(.top, -20)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 15)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            animationStartTime = Date()
            performAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appInitializationCompleted)) { _ in
            handleInitializationComplete()
        }
    }
    
    // 执行动画序列
    func performAnimation() {
        // 步骤1：色块滑入 - 使用更平滑的spring动画
        withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
            showBars = true
        }
        
        // 步骤2：墨鱼出现 - 使用更平滑的spring动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showSquid = true
            }
        }
        
        // 步骤3：文字浮现 - 使用平滑的spring动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                showText = true
            }
        }
        
        // 设置最大等待时间，避免等待太久
        DispatchQueue.main.asyncAfter(deadline: .now() + maxDisplayTime) {
            handleInitializationComplete()
        }
    }
    
    // 处理初始化完成
    private func handleInitializationComplete() {
        guard let startTime = animationStartTime else { return }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let remainingTime = max(0, minDisplayTime - elapsedTime)
        
        // 确保至少显示最小时间
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showBars = false
                showSquid = false
                showText = false
            }
            
            // 完全隐藏启动画面
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPresented = false
                print("✅ 启动画面：初始化完成，关闭启动画面（总耗时：\(String(format: "%.2f", elapsedTime + remainingTime + 0.5))秒）")
            }
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let appInitializationCompleted = Notification.Name("appInitializationCompleted")
}

#Preview {
    SplashScreenView(isPresented: .constant(true))
}


