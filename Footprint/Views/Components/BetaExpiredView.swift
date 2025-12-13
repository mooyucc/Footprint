//
//  BetaExpiredView.swift
//  Footprint
//
//  Created by Auto on 2025/12/09.
//

import SwiftUI

/// 测试版到期提醒：引导用户前往 App Store 下载正式版
struct BetaExpiredView: View {
    let expiryDate: Date?
    let onGoToStore: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(colorScheme == .dark ? 0.94 : 0.96)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.yellow)
                    
                    Text("beta_expired_title".localized)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("beta_expired_subtitle".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
                
                if let expiryDate {
                    Text(String(format: "beta_expired_date".localized, formatted(date: expiryDate)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08))
                        )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("beta_expired_message".localized, systemImage: "arrow.down.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Spacer()
                
                Button(action: onGoToStore) {
                    Text("beta_expired_button".localized)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
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
    BetaExpiredView(
        expiryDate: Date(),
        onGoToStore: {}
    )
}

