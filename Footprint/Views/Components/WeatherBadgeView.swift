//
//  WeatherBadgeView.swift
//  Footprint
//
//  Created by GPT-5.1 Codex on 2025/11/25.
//

import SwiftUI

struct WeatherBadgeView: View {
    let summary: WeatherSummary
    @State private var animateSymbol = false
    @State private var animationTimer: Timer?
    
    var body: some View {
        VStack(spacing: 4) {
            iconView
            temperatureLabel
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule(style: .circular))
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        .accessibilityLabel("\(summary.conditionDescription)，\(summary.temperatureText)")
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(summary.palette.backgroundGradient)
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            
            if #available(iOS 17.0, *) {
                Image(systemName: summary.symbolName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(summary.palette.symbolPrimary, summary.palette.symbolSecondary)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .symbolEffect(.pulse, value: animateSymbol)
            } else {
                Image(systemName: summary.symbolName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(summary.palette.symbolPrimary, summary.palette.symbolSecondary)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .scaleEffect(animateSymbol ? 1.0 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: animateSymbol
                    )
            }
        }
    }
    
    private var temperatureLabel: some View {
        Text(summary.temperatureText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .circular)
                    .fill(.black.opacity(0.55))
            )
    }
    
    private func startAnimation() {
        // 立即触发一次动画
        animateSymbol = true
        
        // 创建定时器持续触发动画（每1.1秒切换一次，模拟脉冲效果）
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.55)) {
                animateSymbol.toggle()
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

