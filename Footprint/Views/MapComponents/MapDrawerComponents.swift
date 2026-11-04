//
//  MapDrawerComponents.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的抽屉相关组件
//

import SwiftUI
import SwiftData

// MARK: - 足迹抽屉视图
/// 显示用户足迹列表的抽屉视图组件
struct FootprintsDrawerView: View {
    let destinations: [TravelDestination]
    let onSelect: (TravelDestination) -> Void
    let onAdd: () -> Void
    
    private var orderedDestinations: [TravelDestination] {
        destinations.sorted { $0.visitDate > $1.visitDate }
    }
    
    var body: some View {
        NavigationStack {
            FootprintFormScaffold(accent: Color.footprintRed) {
                List {
                    if orderedDestinations.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "map")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.footprintRed)
                                
                                Text("start_recording_footprints".localized)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        Section {
                            ForEach(orderedDestinations) { destination in
                                Button {
                                    onSelect(destination)
                                } label: {
                                    DestinationRow(destination: destination, showsDisclosureIndicator: true)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("\(orderedDestinations.count) " + "destinations".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("my_footprints".localized)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // 添加目的地按钮
                        Button {
                            onAdd()
                        } label: {
                            FootprintsToolbarIcon(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 顶部工具栏图标按钮样式
/// 与全局风格一致的工具栏图标按钮样式
private struct FootprintsToolbarIcon: View {
    let systemName: String
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            // 图标使用系统背景色，搭配深色圆形背景，形成黑/白对比
            .foregroundColor(Color(.systemBackground))
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    // 使用系统语义前景色（浅色模式下接近黑色，深色模式下接近白色）
                    .fill(Color(.label))
            }
            .contentShape(Rectangle())
            .frame(width: 44, height: 44) // 扩大触控区域，符合HIG
    }
}
