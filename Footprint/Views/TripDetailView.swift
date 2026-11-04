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
                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                .padding(.horizontal, 2)
            ForEach(group.destinations) { destination in
                NavigationLink {
                    DestinationDetailView(destination: destination)
                } label: {
                    DestinationRowCard(destination: destination, highResolutionCover: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// 封面中央电影开场式标题
    private var tripCoverTitleOverlay: some View {
        Text(trip.name)
            .font(.system(size: 42, weight: .black, design: .serif))
            .tracking(4)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isHeader)
    }
    
    @ViewBuilder
    private func tripCoverView(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let photoData = trip.coverPhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                ZStack {
                    brandColorManager.currentBrandColor.opacity(colorScheme == .dark ? 0.28 : 0.18)
                    Ellipse()
                        .fill(brandColorManager.currentBrandColor.opacity(0.45))
                        .frame(width: width * 0.9, height: width * 0.55)
                        .blur(radius: 40)
                        .offset(x: width * 0.15, y: -height * 0.1)
                    Ellipse()
                        .fill(FootprintTheme.Accent.secondary.opacity(0.28))
                        .frame(width: width * 0.7, height: width * 0.45)
                        .blur(radius: 36)
                        .offset(x: -width * 0.2, y: height * 0.2)
                }
                .frame(width: width, height: height)
            }
            
            // 轻压暗，保证白字可读
            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            
            tripCoverTitleOverlay
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: FootprintTheme.Radius.hero,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: FootprintTheme.Radius.hero,
                style: .continuous
            )
        )
    }
    
    /// 同一天只显示一个日期；跨天用短横连接起止
    private var tripDateRangeText: String {
        let calendar = Calendar.current
        if calendar.isDate(trip.startDate, inSameDayAs: trip.endDate) {
            return trip.startDate.localizedFormatted(dateStyle: .medium)
        }
        let start = trip.startDate.localizedFormatted(dateStyle: .medium)
        let end = trip.endDate.localizedFormatted(dateStyle: .medium)
        return "\(start) – \(end)"
    }
    
    private var tripDurationText: String {
        "\(max(trip.durationDays, 0)) \("days".localized)"
    }
    
    /// 行程路线副标题：起始日期 · 总天数
    private var tripRouteSubtitleText: String {
        "\(tripDateRangeText) · \(tripDurationText)"
    }
    
    /// Hero：封面（中央大标题）+ 可选描述（HealthUI：舞台 → 玻璃，hero 圆角 32）
    @ViewBuilder
    private func tripHeroCard(contentWidth: CGFloat) -> some View {
        let coverHeight = contentWidth * 2 / 3
        let hasDescription = !trip.desc.isEmpty
        VStack(alignment: .leading, spacing: 0) {
            tripCoverView(width: contentWidth, height: coverHeight)
            
            if hasDescription {
                Text(trip.desc)
                    .font(.body)
                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .footprintGlassCard(
            cornerRadius: FootprintTheme.Radius.hero,
            glow: brandColorManager.currentBrandColor
        )
    }
    
    @ViewBuilder
    private var tripRouteCard: some View {
        // 标题直接铺在氛围底上；地点卡本身已是内容卡，避免玻璃套玻璃
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.headline)
                        .foregroundStyle(brandColorManager.currentBrandColor)
                    Text("trip_route".localized)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer(minLength: 8)
                    
                    Text("\(sortedDestinations.count) \("locations".localized)")
                        .font(.caption)
                        .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                }
                
                Text(tripRouteSubtitleText)
                    .font(.subheadline)
                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
            }
            .padding(.horizontal, 2)
            
            if sortedDestinations.isEmpty {
                FootprintSectionCard {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 44))
                            .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                        
                        Text("no_destinations_added".localized)
                            .font(.subheadline)
                            .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                            .multilineTextAlignment(.center)
                        
                        Button {
                            showingAddDestination = true
                        } label: {
                            Label("add_destination".localized, systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(brandColorManager.currentBrandColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
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
                                DestinationRowCard(destination: destination, highResolutionCover: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(geometry.size.width - 32, 0)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tripHeroCard(contentWidth: contentWidth)
                    tripRouteCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
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
    
    /// 在「地图」App 中打开本旅程路线
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

