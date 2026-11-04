//
//  MapRouteDistanceLabel.swift
//  Footprint
//
//  从 MapRouteComponents.swift 提取（编译拆分）
//

import SwiftUI
import MapKit
import CoreLocation
import SwiftData
import Combine

struct RouteDistanceLabel: View {
    let distance: CLLocationDistance
    let transportType: MKDirectionsTransportType
    let source: CLLocationCoordinate2D?
    let destination: CLLocationCoordinate2D?
    let onTransportTypeChange: ((MKDirectionsTransportType?) -> Void)?
    
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var routeManager = RouteManager.shared
    
    // 兼容旧版本：不传递交通方式信息时使用
    init(distance: CLLocationDistance) {
        self.distance = distance
        self.transportType = .automobile
        self.source = nil
        self.destination = nil
        self.onTransportTypeChange = nil
    }
    
    // 新版本：包含交通方式信息
    init(
        distance: CLLocationDistance,
        transportType: MKDirectionsTransportType,
        source: CLLocationCoordinate2D? = nil,
        destination: CLLocationCoordinate2D? = nil,
        onTransportTypeChange: ((MKDirectionsTransportType?) -> Void)? = nil
    ) {
        self.distance = distance
        self.transportType = transportType
        self.source = source
        self.destination = destination
        self.onTransportTypeChange = onTransportTypeChange
    }
    
    var body: some View {
        // 如果有回调，将整个标签包装在 Menu 中，使整个标签都可以点击
        if let source = source, let destination = destination, let onChange = onTransportTypeChange {
            Menu {
                Button {
                    onChange(nil) // 恢复自动选择
                } label: {
                    Label {
                        Text("auto_select".localized)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
                
                Divider()
                
                Button {
                    onChange(.walking)
                } label: {
                    Label {
                        Text("walking".localized)
                    } icon: {
                        Image(systemName: "figure.walk")
                    }
                }
                
                Button {
                    onChange(.automobile)
                } label: {
                    Label {
                        Text("automobile".localized)
                    } icon: {
                        Image(systemName: "car.fill")
                    }
                }
                
                Button {
                    onChange(.transit)
                } label: {
                    Label {
                        Text("transit".localized)
                    } icon: {
                        Image(systemName: "tram.fill")
                    }
                }
                
                Button {
                    onChange(RouteManager.airplane)
                } label: {
                    Label {
                        Text("airplane".localized)
                    } icon: {
                        Image(systemName: "airplane")
                    }
                }
                
                Button {
                    onChange(RouteManager.none)
                } label: {
                    Label {
                        Text("transport_none".localized)
                    } icon: {
                        Image(systemName: "line.diagonal")
                    }
                }
            } label: {
                // 整个标签作为 Menu 的 label，使整个标签都可以点击
                HStack(spacing: 4) {
                    // 交通方式图标
                    Image(systemName: transportType.iconName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(transportColor(for: transportType))
                        .frame(width: 14, height: 14)
                    
                    // 距离文本
                    Text(formatDistance(distance))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .menuStyle(.borderlessButton) // 使用无边框按钮样式，确保点击响应
        } else {
            // 只显示标签，不可点击
            HStack(spacing: 4) {
                // 交通方式图标
                Image(systemName: transportType.iconName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(transportColor(for: transportType))
                    .frame(width: 14, height: 14)
                
                // 距离文本
                Text(formatDistance(distance))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        RouteManager.formatDistanceForRouteCard(distance, languageManager: languageManager)
    }
    
    private func transportColor(for type: MKDirectionsTransportType) -> Color {
        if type == RouteManager.none {
            return Color(.tertiaryLabel) // 无：浅灰色
        } else if type == RouteManager.airplane {
            return .orange // 飞机使用橙色
        } else if type.contains(.walking) && type == .walking {
            return .green
        } else if type.contains(.automobile) && type == .automobile {
            return .blue
        } else if type.contains(.transit) && type == .transit {
            return .purple
        } else {
            return .gray
        }
    }
}
