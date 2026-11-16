//
//  SplashScreenView.swift
//  Footprint
//
//  Created by Auto on 2025/01/XX.
//

import SwiftUI

/// 启动画面：只播品牌动画，不在动画期间挂载主界面 / 打库，避免卡帧
struct SplashScreenView: View {
    @Binding var isPresented: Bool
    
    @State private var showBars = false
    @State private var showSquid = false
    @State private var showText = false
    
    /// 动画播完再关（色块 → 墨鱼 → 文字）
    private let displayDuration: TimeInterval = 1.6
    private let fadeOutDuration: TimeInterval = 0.3
    private static var hasTriggeredDismissThisSession = false
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.white
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    ZStack {
                        Group {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.8, green: 0.87, blue: 0.45))
                                .frame(width: 260, height: 70)
                                .rotationEffect(.degrees(-5))
                                .offset(
                                    x: -10,
                                    y: showBars ? -40 : -90
                                )
                                .opacity(showBars ? 1 : 0)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.98, green: 0.91, blue: 0.51))
                                .frame(width: 270, height: 70)
                                .offset(y: 0)
                                .opacity(showBars ? 0.8 : 0)
                                .scaleEffect(showBars ? 1 : 0.5)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.58, green: 0.9, blue: 0.83))
                                .frame(width: 260, height: 70)
                                .rotationEffect(.degrees(3))
                                .offset(
                                    x: 10,
                                    y: showBars ? 40 : 90
                                )
                                .opacity(showBars ? 1 : 0)
                        }
                        
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
                    .frame(height: 280)
                    
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
            Self.hasTriggeredDismissThisSession = false
            performAnimation()
        }
    }
    
    private func performAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
            showBars = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showSquid = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                showText = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            dismissSplash()
        }
    }
    
    private func dismissSplash() {
        guard !Self.hasTriggeredDismissThisSession else { return }
        Self.hasTriggeredDismissThisSession = true
        
        withAnimation(.easeInOut(duration: fadeOutDuration)) {
            showBars = false
            showSquid = false
            showText = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
            isPresented = false
            print("✅ 启动画面：动画结束，进入主界面骨架")
            NotificationCenter.default.post(name: .splashScreenDismissed, object: nil)
        }
    }
}

extension Notification.Name {
    static let splashScreenDismissed = Notification.Name("splashScreenDismissed")
}

#Preview {
    SplashScreenView(isPresented: .constant(true))
}
