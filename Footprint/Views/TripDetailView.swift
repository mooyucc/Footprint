//
//  TripDetailView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import MapKit
import UIKit

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var trip: TravelTrip
    
    @State private var showingEditSheet = false
    @State private var showingAddDestination = false
    @State private var showingDeleteAlert = false
    @State private var shareItem: TripShareItem?
    @State private var shareFileItem: TripShareItem?
    @State private var showingLayoutSelection = false // 控制版面选择视图显示
    @State private var selectedLayout: TripShareLayout = .list // 默认选择清单版面
    @State private var showingAIDescription = false
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var aiCreditManager: AICreditManager
    
    private var primaryTextColor: Color {
        AppColorScheme.primaryText(for: colorScheme)
    }
    
    var sortedDestinations: [TravelDestination] {
        trip.destinations?.sorted { $0.visitDate < $1.visitDate } ?? []
    }
    
    /// 按日历「天」分组的目的地，用于多日行程按天展示；单日行程不显示日期标题
    private var destinationsByDay: [TripDayGroup] {
        let calendar = Calendar.current
        let sorted = sortedDestinations
        guard !sorted.isEmpty else { return [] }
        var groups: [(dayStart: Date, destinations: [TravelDestination])] = []
        var currentDayStart: Date?
        var currentList: [TravelDestination] = []
        for d in sorted {
            let dayStart = calendar.startOfDay(for: d.visitDate)
            if dayStart != currentDayStart {
                if let prev = currentDayStart { groups.append((prev, currentList)) }
                currentDayStart = dayStart
                currentList = [d]
            } else {
                currentList.append(d)
            }
        }
        if let last = currentDayStart { groups.append((last, currentList)) }
        return groups.enumerated().map { index, element in
            TripDayGroup(dayStart: element.dayStart, dayIndex: index + 1, destinations: element.destinations)
        }
    }
    
    /// 单日行程不显示「第 N 天」标题，仅多日时显示
    private var shouldShowDayHeaders: Bool {
        destinationsByDay.count > 1
    }
    
    private var canUseAI: Bool {
        if BetaInfo.isBetaBuild { return true }
        if entitlementManager.canUseAIFeatures { return true }
        return aiCreditManager.remaining > 0
    }
    
    @ViewBuilder
    private func tripRouteDaySection(group: TripDayGroup) -> some View {
        let dayTitle = String(format: "trip_route_day_title".localized, group.dayIndex, group.dayStart.localizedFormatted(dateStyle: .medium))
        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.top, group.id == destinationsByDay.first?.id ? 0 : 16)
            ForEach(group.destinations) { destination in
                NavigationLink {
                    DestinationDetailView(destination: destination)
                } label: {
                    DestinationRowCard(destination: destination)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let coverHeight = screenWidth * 2 / 3
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 封面（分享 / AI 与 ⋯ 菜单；「在地图中打开」在 ⋯ 内）
                    Group {
                        if let photoData = trip.coverPhotoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: screenWidth, height: coverHeight)
                                .clipped()
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(LinearGradient(
                                        colors: [brandColorManager.currentBrandColor, brandColorManager.currentBrandColor.opacity(0.55)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: screenWidth, height: coverHeight)
                                
                                VStack(spacing: 12) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(trip.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                
                VStack(alignment: .leading, spacing: 16) {
                    // 旅程标题
                    Text(trip.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryTextColor)
                    
                    // 描述
                    if !trip.desc.isEmpty {
                        Text(trip.desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // 时间信息：与「旅行统计」栅格一致，无大块灰底卡片
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        TripDetailDateStatCell(
                            icon: "calendar.badge.plus",
                            title: "start".localized,
                            date: trip.startDate
                        )
                        TripDetailDateStatCell(
                            icon: "calendar",
                            title: "end".localized,
                            date: trip.endDate
                        )
                        TripDetailDurationStatCell(days: trip.durationDays)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 目的地列表（无外层灰卡）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.headline)
                                .foregroundColor(brandColorManager.currentBrandColor)
                            Text("trip_route".localized)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(primaryTextColor)
                            
                            Spacer(minLength: 8)
                            
                            Text("\(sortedDestinations.count) \("locations".localized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if sortedDestinations.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "map")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary)
                                
                                Text("no_destinations_added".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    showingAddDestination = true
                                } label: {
                                    Label("add_destination".localized, systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                if shouldShowDayHeaders {
                                    ForEach(destinationsByDay) { group in
                                        tripRouteDaySection(group: group)
                                    }
                                } else {
                                    ForEach(sortedDestinations) { destination in
                                        NavigationLink {
                                            DestinationDetailView(destination: destination)
                                        } label: {
                                            DestinationRowCard(destination: destination)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        }
        .appPageBackgroundGradient(for: colorScheme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingLayoutSelection = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(uiColor: .label))
                            .symbolRenderingMode(.monochrome)
                            .offset(x: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("share".localized))
                    
                    Button {
                        showingAIDescription = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(uiColor: canUseAI ? .label : .tertiaryLabel))
                            .symbolRenderingMode(.monochrome)
                    }
                    .disabled(!canUseAI)
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("ai_function_trip_desc_title".localized))
                    
                    Menu {
                        Button {
                            openTripInMaps()
                        } label: {
                            tripDetailMenuRow(title: "open_in_maps".localized, systemImage: "map", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        .disabled(sortedDestinations.isEmpty)
                        
                        Button {
                            shareTripToTeam()
                        } label: {
                            tripDetailMenuRow(title: "share_to_team".localized, systemImage: "person.2.fill", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button {
                            showingEditSheet = true
                        } label: {
                            tripDetailMenuRow(title: "edit_trip".localized, systemImage: "pencil", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showingAddDestination = true
                        } label: {
                            tripDetailMenuRow(title: "add_destination".localized, systemImage: "plus", style: .neutral)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            tripDetailMenuRow(title: "delete_trip".localized, systemImage: "trash", style: .destructive)
                        }
                        .buttonStyle(.plain)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color(uiColor: .label))
                            .symbolRenderingMode(.monochrome)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("more_options".localized))
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTripView(trip: trip)
        }
        .sheet(isPresented: $showingAddDestination) {
            AddDestinationToTripView(trip: trip)
        }
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                // 只分享图片，不分享文字
                SystemShareSheet(items: [image])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .sheet(item: $shareFileItem) { item in
            if let url = item.url {
                SystemShareSheet(items: [url])
            } else {
                SystemShareSheet(items: [item.text])
            }
        }
        .sheet(isPresented: $showingLayoutSelection) {
            TripShareLayoutSelectionView(trip: trip, selectedLayout: $selectedLayout)
        }
        .sheet(isPresented: $showingAIDescription) {
            AIActionSheet(trip: trip, action: .generateDescription)
        }
        .alert("delete_trip".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                deleteTrip()
            }
        } message: {
            Text("confirm_delete_trip".localized)
        }
    }
    
    private func deleteTrip() {
        modelContext.delete(trip)
        dismiss()
    }
    
    private func shareTripToTeam() {
        // 导出旅程数据为JSON文件
        guard let fileURL = TripDataExporter.exportTrip(trip) else {
            // 导出失败，显示错误提示
            return
        }
        
        // 生成分享文本
        let shareText = TripDataExporter.generateShareText(for: trip)
        
        // 创建分享项
        shareFileItem = TripShareItem(text: shareText, image: nil, url: fileURL)
    }
    
    /// 在「地图」App 中打开本旅程路线（与 `RouteCard` 一致）
    private func openTripInMaps() {
        let destinations = sortedDestinations
        guard !destinations.isEmpty else { return }
        
        var mapItems: [MKMapItem] = []
        for destination in destinations {
            let placemark = MKPlacemark(coordinate: destination.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = destination.name
            mapItems.append(mapItem)
        }
        guard !mapItems.isEmpty else { return }
        
        let options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: "d",
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ]
        
        if mapItems.count == 1 {
            mapItems[0].openInMaps(launchOptions: options)
        } else {
            MKMapItem.openMaps(with: mapItems, launchOptions: options)
        }
    }
    
    private enum TripDetailMenuRowStyle {
        case neutral
        case destructive
    }
    
    /// 使用 `HStack` 而非 `Label`，避免菜单项图标被当作模板而染上 accent/主题色。
    private func tripDetailMenuRow(title: String, systemImage: String, style: TripDetailMenuRowStyle) -> some View {
        let iconAndText: Color = {
            switch style {
            case .neutral: return Color(UIColor.label)
            case .destructive: return Color(UIColor.systemRed)
            }
        }()
        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body)
                .imageScale(.medium)
                .foregroundStyle(iconAndText)
                .symbolRenderingMode(.monochrome)
                .frame(width: 22, height: 22, alignment: .center)
            Text(title)
                .font(.body)
                .foregroundStyle(iconAndText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - 旅程详情统计（与 YearAnimatedStatCell / ProfileStatCard 节奏一致）

private struct TripDetailDateStatCell: View {
    let icon: String
    let title: String
    let date: Date
    @EnvironmentObject var brandColorManager: BrandColorManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(brandColorManager.currentBrandColor)
            
            Text(date.localizedFormatted(dateStyle: .medium))
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct TripDetailDurationStatCell: View {
    let days: Int
    @EnvironmentObject var brandColorManager: BrandColorManager
    @State private var animatedValue: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "clock")
                .font(.headline)
                .foregroundColor(brandColorManager.currentBrandColor)
            
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(Int(animatedValue.rounded()))")
                    .font(.system(size: 34, weight: .black, design: .default))
                    .tracking(-0.8)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: animatedValue))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 0)
            }
            
            Text("duration".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .onAppear {
            animateStatNumber(resetToZero: true)
        }
        .onChange(of: days) { _, _ in
            animateStatNumber(resetToZero: false)
        }
        .accessibilityLabel(Text("duration".localized))
        .accessibilityValue(Text("\(days) \("days".localized)"))
    }
    
    private func animateStatNumber(resetToZero: Bool) {
        let target = Double(max(days, 0))
        if resetToZero {
            animatedValue = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.easeOut(duration: 0.9)) {
                    animatedValue = target
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.55)) {
                animatedValue = target
            }
        }
    }
}

/// 按天分组的一批目的地，用于行程路线按天展示
private struct TripDayGroup: Identifiable {
    let dayStart: Date
    let dayIndex: Int
    let destinations: [TravelDestination]
    var id: Date { dayStart }
}

#Preview {
    NavigationStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: TravelTrip.self, TravelDestination.self,
            configurations: config
        )
        
        let trip = TravelTrip(
            name: "2025年10月青甘大环线",
            desc: "穿越青海甘肃的美丽风光",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7)
        )
        container.mainContext.insert(trip)
        
        return TripDetailView(trip: trip)
            .modelContainer(container)
            .environmentObject(LanguageManager.shared)
            .environmentObject(BrandColorManager.shared)
            .environmentObject(EntitlementManager.shared)
            .environmentObject(AICreditManager.shared)
    }
}

