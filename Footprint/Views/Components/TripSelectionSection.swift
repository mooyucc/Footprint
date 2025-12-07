//
//  TripSelectionSection.swift
//  Footprint
//
//  Created by K.X on 2025/11/26.
//

import SwiftUI
import SwiftData

/// 可复用的旅程选择组件
struct TripSelectionSection: View {
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedTrip: TravelTrip?
    @State private var showingCreateTrip = false
    @State private var previousTripsCount = 0
    @State private var addNewTripMarker: TravelTrip?
    
    // 用于标识"添加新旅程"标记的特殊名称
    private static let addNewTripMarkerName = "__ADD_NEW_TRIP_MARKER__"
    
    // 检查是否是标记实例
    private func isMarkerTrip(_ trip: TravelTrip?) -> Bool {
        guard let trip = trip else { return false }
        return trip.name == Self.addNewTripMarkerName
    }
    
    var body: some View {
        Section("belongs_to_trip_optional".localized) {
            if trips.isEmpty {
                // 如果没有旅程，显示添加旅程按钮 - 使用 NavigationLink 避免嵌套 sheet
                NavigationLink(destination: AddTripView().environmentObject(LanguageManager.shared)) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("create_trip".localized)
                    }
                }
            } else {
                Picker("select_trip".localized, selection: $selectedTrip) {
                    Text("none".localized).tag(nil as TravelTrip?)
                    ForEach(trips) { trip in
                        Text(trip.name).tag(trip as TravelTrip?)
                    }
                    // 添加"添加新旅程"选项
                    if let marker = addNewTripMarker {
                        Text("➕ \("create_trip".localized)").tag(marker as TravelTrip?)
                    }
                }
                
                if let trip = selectedTrip, !isMarkerTrip(trip) {
                    NavigationLink {
                        EditTripView(trip: trip)
                            .environmentObject(LanguageManager.shared)
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.name)
                                    .font(.caption)
                                Text("\(trip.startDate.localizedFormatted(dateStyle: .medium)) - \(trip.endDate.localizedFormatted(dateStyle: .medium))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            
            // 隐藏的 NavigationLink，用于从 Picker 选择"添加新旅程"时触发导航
            // 使用 NavigationLink 代替 sheet，避免嵌套 presentation 问题
            // 注意：isActive 在 iOS 16+ 中已废弃，但在 iOS 18 中仍可用
            NavigationLink(
                destination: AddTripView().environmentObject(LanguageManager.shared),
                isActive: $showingCreateTrip
            ) {
                EmptyView()
            }
            .hidden()
            .frame(width: 0, height: 0)
            .disabled(true) // 禁用直接点击，只能通过编程方式触发
        }
        .onChange(of: selectedTrip) { oldValue, newValue in
            // 如果选择了"添加新旅程"标记，通过 NavigationLink 导航到创建旅程视图
            if isMarkerTrip(newValue) {
                showingCreateTrip = true
                // 重置选择，避免重复触发
                selectedTrip = oldValue
            }
        }
        .onChange(of: trips.count) { oldCount, newCount in
            // 当旅程数量增加时（创建了新旅程），自动选择最新的旅程
            if newCount > oldCount, let latestTrip = trips.first {
                selectedTrip = latestTrip
            }
        }
        .onAppear {
            // 初始化标记实例（如果还没有创建）
            if addNewTripMarker == nil {
                addNewTripMarker = TravelTrip(
                    name: Self.addNewTripMarkerName,
                    desc: "",
                    startDate: Date(),
                    endDate: Date()
                )
            }
            previousTripsCount = trips.count
        }
    }
}

#Preview {
    Form {
        TripSelectionSection(selectedTrip: .constant(nil))
    }
    .modelContainer(for: TravelTrip.self, inMemory: true)
}

