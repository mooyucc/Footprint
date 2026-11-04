//
//  MapPreviewComponents.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的预览相关组件
//

import SwiftUI
import MapKit
import SwiftData

// MARK: - 目的地预览卡片
/// 显示目的地预览信息的卡片组件
struct DestinationPreviewCard: View {
    let destination: TravelDestination
    let onOpenDetail: () -> Void
    @State private var shareItem: TripShareItem?
    @State private var showingSelectTrip = false
    @State private var showingAINotePreview = false
    @State private var showingShareLayoutSelection = false
    @State private var selectedDestinationLayout: DestinationShareLayout = .classic
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    @StateObject private var countryManager = CountryManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            photoThumbnail
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(destination.name)
                        .font(.headline)
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // 显示旅程信息
                if let trip = destination.trip {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.caption2)
                        Text(trip.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
                
                HStack(spacing: 4) {
                    if !destination.province.isEmpty {
                        Text(destination.province)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(countryManager.getLocalizedCountryName(from: destination.country))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(destination.visitDate.localizedFormatted(dateStyle: .medium))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 显示笔记
                if !destination.notes.isEmpty {
                    Text(destination.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }
            
            Spacer(minLength: 12)
            
            // 按钮组 - 2x2布局
            VStack(spacing: 8) {
                // 第一行：分享和喜欢按钮
                HStack(spacing: 5) {
                    // 分享按钮
                    Button {
                        showingShareLayoutSelection = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(
                                Circle().fill(Color.white.opacity(0.5))
                            )
                    }
                    
                    // 喜爱按钮
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: destination.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(destination.isFavorite ? .red : .black)
                            .padding(10)
                            .background(
                                Circle().fill(Color.white.opacity(0.5))
                            )
                    }
                }
                
                // 第二行：AI笔记和创建/添加旅程按钮
                HStack(spacing: 5) {
                    // AI笔记生成按钮
                    Button {
                        showingAINotePreview = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(
                                Circle().fill(Color.white.opacity(0.5))
                            )
                    }
                    .disabled(!canUseAI)
                    .opacity(canUseAI ? 1.0 : 0.5)
                    
                    // 创建/添加旅程按钮
                    Button {
                        showingSelectTrip = true
                    } label: {
                        Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.filled.scurvepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(
                                Circle().fill(Color.white.opacity(0.5))
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(radius: 10)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            onOpenDetail()
        }
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                SystemShareSheet(items: [image])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .sheet(isPresented: $showingSelectTrip) {
            SelectOrCreateTripView(destination: destination)
        }
        .sheet(isPresented: $showingAINotePreview) {
            AINotePreviewSheet(destination: destination)
        }
    }
    
    // 检查是否有权限使用AI功能
    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    private var photoThumbnail: some View {
        Group {
            if let photoData = destination.photoThumbnailData ?? destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("ImageMooyu")
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)  // 高质量插值，确保边缘光滑
                    .antialiased(true)     // 启用抗锯齿
                    .scaledToFill()
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        .sheet(isPresented: $showingShareLayoutSelection) {
            DestinationShareLayoutSelectionView(
                destination: destination,
                selectedLayout: $selectedDestinationLayout
            )
        }
    }
    
    // 切换喜爱状态的方法
    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            destination.isFavorite.toggle()
            try? modelContext.save()
            DestinationChangeNotifier.postUpdated()
        }
    }
    
    // 分享地点图片（由版面选择视图处理，保留方法占位）
    private func shareDestination() { }
}

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
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
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
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
