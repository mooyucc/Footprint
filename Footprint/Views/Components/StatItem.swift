//
//  StatItem.swift
//  Footprint
//
//  Created by GPT-5 Codex on 2025/11/08.
//

import SwiftUI

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

