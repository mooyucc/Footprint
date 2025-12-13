//
//  BetaReminderView.swift
//  Footprint
//
//  Created by Auto on 2025/12/09.
//

import SwiftUI

/// 测试版提醒：显示剩余有效期并提示数据备份，确认后再进入启动动画
struct BetaReminderView: View {
    let daysRemaining: Int
    let expiryDate: Date?
    let onContinue: () -> Void
    let onGoToStore: () -> Void
    
    @State private var showBackupGuide = false
    @Environment(\.colorScheme) private var colorScheme
    
    // 动画状态
    @State private var showBars = false
    @State private var showSquid = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // 整体背景固定白色（与启动画面保持一致）
            Color.white
                .ignoresSafeArea()
            
            // 背景装饰：彩色条（来自启动动画）
            ZStack {
                // 绿色条（上）
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.8, green: 0.87, blue: 0.45))
                    .frame(width: 280, height: 80)
                    .rotationEffect(.degrees(-5))
                    .offset(
                        x: -20,
                        y: showBars ? -180 : -250
                    )
                    .opacity(showBars ? 0.15 : 0)
                
                // 黄色条（中）
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.98, green: 0.91, blue: 0.51))
                    .frame(width: 290, height: 80)
                    .offset(y: showBars ? -100 : -150)
                    .opacity(showBars ? 0.12 : 0)
                    .scaleEffect(showBars ? 1 : 0.8)
                
                // 蓝色条（下）
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.58, green: 0.9, blue: 0.83))
                    .frame(width: 280, height: 80)
                    .rotationEffect(.degrees(3))
                    .offset(
                        x: 20,
                        y: showBars ? -20 : 50
                    )
                    .opacity(showBars ? 0.15 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)
                    
                    // 主卡片容器
                    VStack(spacing: 0) {
                        // 卡片顶部：墨鱼图标区域（带渐变背景）
                        ZStack {
                            // 渐变背景
                            LinearGradient(
                                colors: [
                                    Color(red: 0.8, green: 0.87, blue: 0.45).opacity(0.2),
                                    Color(red: 0.98, green: 0.91, blue: 0.51).opacity(0.15),
                                    Color(red: 0.58, green: 0.9, blue: 0.83).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 16) {
                                // 墨鱼图标
                                Image("LoginMooyu")
                                    .resizable()
                                    .interpolation(.high)
                                    .antialiased(true)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(showSquid ? 1 : 0.8)
                                    .opacity(showSquid ? 1 : 0)
                                
                                // 警告图标徽章
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 48, height: 48)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                                    
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.orange, .yellow],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                .offset(y: -20)
                                .opacity(showSquid ? 1 : 0)
                            }
                            .padding(.top, 20)
                            .padding(.bottom, 8)
                        }
                        .frame(height: 180)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 20
                            )
                        )
                        
                        // 卡片内容区域
                        VStack(spacing: 20) {
                            // 标题区域
                            VStack(spacing: 8) {
                                Text("beta_reminder_title".localized)
                                    .font(.title.bold())
                                    .foregroundStyle(.primary)
                                
                                Text("beta_reminder_subtitle".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 24)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 10)
                            
                            // 剩余天数卡片（突出显示）
                            VStack(spacing: 6) {
                                Text("beta_reminder_days_label".localized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text("\(daysRemaining)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.8, green: 0.87, blue: 0.45),
                                                Color(red: 0.58, green: 0.9, blue: 0.83)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                if let expiryDate {
                                    Text(String(format: "beta_reminder_expiry_date".localized, formatted(date: expiryDate)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.8, green: 0.87, blue: 0.45).opacity(0.1),
                                        Color(red: 0.58, green: 0.9, blue: 0.83).opacity(0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.8, green: 0.87, blue: 0.45).opacity(0.3),
                                                Color(red: 0.58, green: 0.9, blue: 0.83).opacity(0.3)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 10)
                            
                            // 备份提示卡片
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "externaldrive.fill.badge.icloud")
                                        .font(.body)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    Text("beta_reminder_backup_tip".localized)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Button(action: { showBackupGuide = true }) {
                                    HStack {
                                        Text("beta_reminder_backup_button".localized)
                                            .fontWeight(.medium)
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 10)
                        }
                        .padding(24)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                        .frame(height: 24)
                    
                    // 底部按钮区域
                    VStack(spacing: 12) {
                        // 前往 App Store 按钮（更醒目）
                        Button(action: onGoToStore) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title3)
                                Text("beta_expired_button".localized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        
                        // 继续使用Beta按钮（次要按钮）
                        Button(action: onContinue) {
                            Text("beta_reminder_continue_button".localized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .onAppear {
            performAnimation()
        }
        .sheet(isPresented: $showBackupGuide) {
            backupGuideSheet
                .presentationDetents([.medium])
        }
    }
    
    // 执行动画序列
    private func performAnimation() {
        // 步骤1：彩色条滑入
        withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
            showBars = true
        }
        
        // 步骤2：墨鱼出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showSquid = true
            }
        }
        
        // 步骤3：内容浮现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                showContent = true
            }
        }
    }
    
    private var backupGuideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("beta_reminder_backup_guide_message".localized)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Label("beta_reminder_backup_step1".localized, systemImage: "1.circle.fill")
                        Label("beta_reminder_backup_step2".localized, systemImage: "2.circle.fill")
                        Label("beta_reminder_backup_step3".localized, systemImage: "3.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("beta_reminder_backup_guide_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        showBackupGuide = false
                    }
                }
            }
        }
    }
    
    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    BetaReminderView(
        daysRemaining: 45,
        expiryDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
        onContinue: {},
        onGoToStore: {}
    )
}

