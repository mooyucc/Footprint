//
//  YearFilteredDestinationView.swift
//  Footprint
//
//  Created by K.X on 2025/01/27.
//

import SwiftUI
import SwiftData
import UIKit

struct YearFilteredDestinationView: View {
    let year: Int
    @Query private var allDestinations: [TravelDestination]
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var filterPlaceType: String? = nil
    @State private var editingDestination: TravelDestination?
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @State private var shareItem: TripShareItem?
    @State private var showingLayoutSelection = false
    @State private var selectedLayout: TripShareLayout = .list
    
    // MARK: - 配色（使用统一的 AppColorScheme 工具类）
    
    private var primaryTextColor: Color {
        AppColorScheme.primaryText(for: colorScheme)
    }
    
    init(year: Int) {
        self.year = year
        // 创建按年份过滤的查询
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        
        let predicate = #Predicate<TravelDestination> { destination in
            destination.visitDate >= startOfYear && destination.visitDate <= endOfYear
        }
        
        self._allDestinations = Query(filter: predicate, sort: \TravelDestination.visitDate, order: .reverse)
    }
    
    var filteredDestinations: [TravelDestination] {
        var result = allDestinations
        
        if let category = filterCategory {
            // 使用 CountryManager 来判断是否为国内
            result = result.filter { destination in
                let isDomestic = countryManager.isDomestic(country: destination.country)
                return category == "domestic" ? isDomestic : !isDomestic
            }
        }
        
        if let placeType = filterPlaceType {
            result = result.filter { $0.type == placeType }
        }
        
        if !searchText.isEmpty {
            result = result.filter { destination in
                destination.name.localizedCaseInsensitiveContains(searchText) ||
                destination.country.localizedCaseInsensitiveContains(searchText) ||
                destination.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var statistics: (total: Int, domestic: Int, international: Int, countries: Int) {
        let total = allDestinations.count
        // 使用 CountryManager 来判断是否为国内
        let domestic = allDestinations.filter { countryManager.isDomestic(country: $0.country) }.count
        let international = allDestinations.filter { !countryManager.isDomestic(country: $0.country) }.count
        let countries = Set(allDestinations.map { $0.country }).count
        return (total, domestic, international, countries)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 年份统计信息卡片
                    YearStatisticsCard(year: year, statistics: statistics)
                    
                    // 筛选器卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Text("filter".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        SegmentedPickerWithGrayUnselected(
                            selection: $filterCategory,
                            options: [
                                (nil, "all".localized),
                                ("domestic", "domestic".localized),
                                ("international", "international".localized)
                            ]
                        )
                        
                        // 地点类型下拉筛选
                        HStack {
                            Text("destination_type".localized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Picker("", selection: $filterPlaceType) {
                                Text("all".localized).tag(nil as String?)
                                ForEach(TravelDestination.placeTypeFilterOptions, id: \.key) { option in
                                    Text(option.localizedKey.localized).tag(option.key as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                        }
                    }
                    .padding(20)
                    .redCardStyle(cornerRadius: 20)
                    
                    // 目的地列表
                    if !filteredDestinations.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            Text("travel_destinations".localized)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryTextColor)
                            
                            ForEach(filteredDestinations) { destination in
                                NavigationLink {
                                    DestinationDetailView(destination: destination)
                                } label: {
                                    DestinationRowCard(destination: destination)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button {
                                        editingDestination = destination
                                    } label: {
                                        Label("edit".localized, systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        deleteDestination(destination)
                                    } label: {
                                        Label("delete".localized, systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("year_travel_records".localized(with: year))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLayoutSelection = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "search_places_countries_notes".localized)
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .sheet(item: $shareItem) { item in
                if let image = item.image {
                    SystemShareSheet(items: [image])
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { notification in
                // 当当前正在编辑的地点被删除时，自动关闭编辑弹窗
                if let userInfo = notification.userInfo,
                   let deletedDestinationId = userInfo["destinationId"] as? UUID {
                    if let editing = editingDestination, editing.id == deletedDestinationId {
                        editingDestination = nil
                    }
                } else if editingDestination != nil {
                    // 批量删除等没有携带 destinationId 的情况，直接关闭编辑弹窗
                    editingDestination = nil
                }
            }
            .sheet(isPresented: $showingLayoutSelection) {
                YearShareLayoutSelectionView(
                    year: year,
                    destinations: allDestinations,
                    selectedLayout: $selectedLayout
                )
            }
            .overlay {
                if allDestinations.isEmpty {
                    EmptyYearStateView(year: year, colorScheme: colorScheme)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // 语言变化时刷新界面
                refreshID = UUID()
            }
            .id(refreshID)
        }
    }
    
    private func deleteDestination(_ destination: TravelDestination) {
        if let modelContext = destination.modelContext {
            let destinationId = destination.id
            modelContext.delete(destination)
            try? modelContext.save()
            // 发送删除通知，通知徽章视图更新
            NotificationCenter.default.post(name: .destinationDeleted, object: nil, userInfo: ["destinationId": destinationId])
        }
    }
    
    private func deleteDestinations(at offsets: IndexSet) {
        for index in offsets {
            let destination = filteredDestinations[index]
            if let modelContext = destination.modelContext {
                let destinationId = destination.id
                modelContext.delete(destination)
                try? modelContext.save()
                // 发送删除通知，通知徽章视图更新
                NotificationCenter.default.post(name: .destinationDeleted, object: nil, userInfo: ["destinationId": destinationId])
            }
        }
    }
    
}

struct YearStatisticsCard: View {
    let year: Int
    let statistics: (total: Int, domestic: Int, international: Int, countries: Int)
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var brandColorManager: BrandColorManager
    
    private var primaryTextColor: Color {
        AppColorScheme.primaryText(for: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(brandColorManager.currentBrandColor)
                    .font(.headline)
                Text("year_travel_statistics".localized(with: year))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                YearAnimatedStatCell(
                    icon: "flag.fill",
                    targetValue: statistics.total,
                    label: "total_destinations".localized
                )
                YearAnimatedStatCell(
                    icon: "globe.asia.australia.fill",
                    targetValue: statistics.countries,
                    label: "countries_visited".localized
                )
                YearAnimatedStatCell(
                    icon: "house.fill",
                    targetValue: statistics.domestic,
                    label: "domestic_travel".localized
                )
                YearAnimatedStatCell(
                    icon: "airplane",
                    targetValue: statistics.international,
                    label: "international_travel".localized
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 与「我的」旅行统计一致的数字栅格（无卡片底板 + 递增动效）
private struct YearAnimatedStatCell: View {
    let icon: String
    let targetValue: Int
    let label: String
    @EnvironmentObject var brandColorManager: BrandColorManager
    @State private var animatedValue: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
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
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .onAppear { animateStatNumber(resetToZero: true) }
        .onChange(of: targetValue) { _, _ in animateStatNumber(resetToZero: false) }
    }
    
    private func animateStatNumber(resetToZero: Bool) {
        let target = Double(targetValue)
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

struct DestinationRowCard: View {
    let destination: TravelDestination
    @StateObject private var countryManager = CountryManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    private var visitDateText: String {
        DestinationRowCard.dateFormatter.string(from: destination.visitDate)
    }
    
    private var regionTag: (text: String, color: Color)? {
        if countryManager.isDomestic(country: destination.country) {
            return ("domestic".localized, Color(red: 0x3A/255.0, green: 0x8B/255.0, blue: 0xBB/255.0)) // #3A8BBB
        } else if !destination.country.isEmpty {
            return ("international".localized, Color(red: 0x50/255.0, green: 0xA3/255.0, blue: 0x7B/255.0)) // #50A37B
        }
        return nil
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景图片层（参考图2：使用地点照片作为背景）
            // 优先使用原图，如果没有原图才使用缩略图
            if let data = destination.photoData ?? destination.photoThumbnailData,
               let image = UIImage(data: data) {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)  // 高质量插值
                        .antialiased(true)     // 启用抗锯齿
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)  // 背景图片不拦截点击事件
            } else {
                // 如果没有图片，使用新的背景颜色
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0x67/255.0, green: 0x93/255.0, blue: 0xC3/255.0)) // #6793C3
                    .allowsHitTesting(false)  // 背景不拦截点击事件
            }
            
            // 深色渐变遮罩（无论是否有图片都显示）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.58)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)  // 渐变遮罩不拦截点击事件
            
            // 内容层
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    
                    // 底部内容区域
                    VStack(alignment: .leading, spacing: 2) {
                        // 标题行：标题和收藏图标
                        HStack(spacing: 6) {
                            Text(destination.name.isEmpty ? "-" : destination.name)
                                .font(.system(size: 22, weight: .black, design: .default))
                                .tracking(-0.3)
                                .foregroundColor(.white) // 统一使用白色文字
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            if destination.isFavorite {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                    
                        // 地点和时间放在最底下一排
                        HStack(spacing: 8) {
                            // 地点信息
                            HStack(spacing: 4) {
                                if !destination.province.isEmpty {
                                    Text(destination.province)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                    Text("·")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Text(destination.country.isEmpty ? "-" : destination.country)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                            
                            // 分隔符
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            // 日期
                            Text(visitDateText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                        }
                    }
                    .padding(16)
                }
                
                // 左上角标签（独立显示在卡片左上角）
                if let tag = regionTag {
                    Text(tag.text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tag.color.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.leading, 16)
                        .padding(.top, 12)
                }
            }
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.1), radius: 14, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private var thumbnail: some View {
        Group {
            if let data = destination.photoThumbnailData ?? destination.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
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
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// 独立的地区图标容器组件
struct RegionIconView: View {
    let isDomestic: Bool
    let hasCountry: Bool
    
    var body: some View {
        Group {
            if isDomestic {
                Image(systemName: "house.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.4)) // 深灰色透明背景
                    .clipShape(Circle())
            } else if hasCountry {
                Image(systemName: "airplane")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.4)) // 深灰色透明背景
                    .clipShape(Circle())
            }
        }
    }
}

struct EmptyYearStateView: View {
    let year: Int
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("no_travel_records_for_year".localized(with: year))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("add_year_travel_footprints".localized(with: year))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appPageBackgroundGradient(for: colorScheme)
    }
}

// MARK: - 自定义 Segmented Picker（未选中文字为灰色）
struct SegmentedPickerWithGrayUnselected: UIViewRepresentable {
    @Binding var selection: String?
    let options: [(tag: String?, label: String)]
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: options.map { $0.label })
        
        // 设置未选中文字颜色：半透明白色（50%不透明度）
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.5) // 半透明白色
        ], for: .normal)
        
        // 设置选中文字颜色：黑色（在白色背景上）
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.black
        ], for: .selected)
        
        // 设置选中背景色：白色
        segmentedControl.selectedSegmentTintColor = .white
        
        // 设置初始选中状态
        if let index = options.firstIndex(where: { $0.tag == selection }) {
            segmentedControl.selectedSegmentIndex = index
        } else {
            segmentedControl.selectedSegmentIndex = 0
        }
        
        // 添加值变化监听
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        
        return segmentedControl
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        // 更新选中状态
        if let index = options.firstIndex(where: { $0.tag == selection }) {
            if uiView.selectedSegmentIndex != index {
                uiView.selectedSegmentIndex = index
            }
        } else if uiView.selectedSegmentIndex != 0 {
            uiView.selectedSegmentIndex = 0
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, options: options)
    }
    
    class Coordinator: NSObject {
        @Binding var selection: String?
        let options: [(tag: String?, label: String)]
        
        init(selection: Binding<String?>, options: [(tag: String?, label: String)]) {
            _selection = selection
            self.options = options
        }
        
        @objc func valueChanged(_ sender: UISegmentedControl) {
            let index = sender.selectedSegmentIndex
            if index >= 0 && index < options.count {
                selection = options[index].tag
            }
        }
    }
}

#Preview {
    YearFilteredDestinationView(year: 2024)
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
        .environmentObject(BrandColorManager.shared)
}
