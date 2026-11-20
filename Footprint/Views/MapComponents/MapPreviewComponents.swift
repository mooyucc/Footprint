//
//  MapPreviewComponents.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的预览相关组件
//

import SwiftUI
import MapKit


// MARK: - POI预览卡片
/// 显示地图上点击的POI或地址信息的预览卡片
struct POIPreviewCard: View {
    let mapItem: MKMapItem
    let onAddDestination: () -> Void
    let onDismiss: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // POI名称或地址
                    Text(mapItem.name ?? "unknown_location".localized)
                        .font(.headline)
                        .lineLimit(2)
                    
                    // 地址信息
                    if let address = formatAddress(from: mapItem.placemark) {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // POI类别（如果有）
                    if let category = mapItem.pointOfInterestCategory {
                        HStack(spacing: 4) {
                            Image(systemName: categoryIcon(for: category))
                                .font(.caption2)
                            Text(category.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 关闭按钮
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 操作按钮
            HStack(spacing: 12) {
                // 在Apple Maps中打开
                Button {
                    mapItem.openInMaps()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                        Text("open_in_maps".localized)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                // 添加目的地
                Button {
                    onAddDestination()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("add_destination".localized)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .footprintGlassCard(cornerRadius: 15)
    }
    
    // 格式化地址
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        // 街道地址
        if let streetNumber = placemark.subThoroughfare,
           let street = placemark.thoroughfare {
            components.append("\(streetNumber) \(street)")
        } else if let street = placemark.thoroughfare {
            components.append(street)
        }
        
        // 城市
        if let city = placemark.locality {
            components.append(city)
        } else if let area = placemark.administrativeArea {
            components.append(area)
        }
        
        // 国家
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // 获取POI类别图标
    private func categoryIcon(for category: MKPointOfInterestCategory) -> String {
        switch category {
        case .restaurant:
            return "fork.knife"
        case .cafe:
            return "cup.and.saucer.fill"
        case .hotel:
            return "bed.double.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .airport:
            return "airplane"
        case .park:
            return "leaf.fill"
        case .museum:
            return "building.columns.fill"
        case .theater:
            return "theatermasks.fill"
        case .store:
            return "bag.fill"
        case .school:
            return "graduationcap.fill"
        case .hospital:
            return "cross.case.fill"
        case .bank:
            return "building.columns.fill"
        default:
            return "mappin.circle.fill"
        }
    }
}

// MARK: - POI搜索加载卡片
/// 显示POI搜索状态的卡片组件
struct POISearchingCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 加载动画图标
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("searching_location".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("please_wait".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .footprintGlassCard(cornerRadius: 15)
    }
}
