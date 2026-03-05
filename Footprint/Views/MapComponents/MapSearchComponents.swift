//
//  MapSearchComponents.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的搜索相关组件
//

import SwiftUI
import MapKit

// MARK: - 搜索结果行组件
/// 显示地图搜索结果的行组件
struct SearchResultRow: View {
    let mapItem: MKMapItem
    let onTap: () -> Void
    
    private var unknownLocationText: String {
        "unknown_location".localized
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mapItem.name ?? unknownLocationText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = mapItem.placemark.title {
                        Text(address)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "location.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // 确保整个矩形区域都可以点击
        }
        .buttonStyle(PlainButtonStyle())
    }
}
