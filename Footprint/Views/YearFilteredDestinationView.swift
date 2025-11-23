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
    @State private var editingDestination: TravelDestination?
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @State private var shareItem: TripShareItem?
    @State private var showingLayoutSelection = false
    @State private var selectedLayout: TripShareLayout = .list
    
    // MARK: - 配色（使用统一的 AppColorScheme 工具类）
    
    private var cardBackgroundColor: Color {
        AppColorScheme.whiteCardBackground(for: colorScheme)
    }
    
    private var primaryTextColor: Color {
        AppColorScheme.primaryText(for: colorScheme)
    }
    
    private var borderColor: Color {
        AppColorScheme.border(for: colorScheme)
    }
    
    private var largeCardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        AppColorScheme.largeCardShadow
    }
    
    private var smallCardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        AppColorScheme.smallCardShadow
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
                VStack(spacing: 20) {
                    // 年份统计信息卡片
                    YearStatisticsCard(
                        year: year,
                        statistics: statistics,
                        cardBackgroundColor: cardBackgroundColor,
                        primaryTextColor: primaryTextColor,
                        borderColor: borderColor,
                        shadow: largeCardShadow
                    )
                    
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
                    }
                    .padding(20)
                    .redCardStyle(cornerRadius: 20)
                    
                    // 目的地列表
                    if !filteredDestinations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("travel_destinations".localized)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryTextColor)
                                .padding(.horizontal, 4)
                            
                            ForEach(filteredDestinations) { destination in
                                NavigationLink {
                                    DestinationDetailView(destination: destination)
                                } label: {
                                    DestinationRowCard(destination: destination, primaryTextColor: primaryTextColor)
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
                        .padding(20)
                        .background(AppColorScheme.whiteCardBackground(for: colorScheme))
                        .cornerRadius(20)
                        .shadow(color: largeCardShadow.color, radius: largeCardShadow.radius, x: largeCardShadow.x, y: largeCardShadow.y)
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
            modelContext.delete(destination)
        }
    }
    
    private func deleteDestinations(at offsets: IndexSet) {
        for index in offsets {
            let destination = filteredDestinations[index]
            if let modelContext = destination.modelContext {
                modelContext.delete(destination)
            }
        }
    }
    
}

struct YearStatisticsCard: View {
    let year: Int
    let statistics: (total: Int, domestic: Int, international: Int, countries: Int)
    let cardBackgroundColor: Color
    let primaryTextColor: Color
    let borderColor: Color
    let shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(AppColorScheme.iconColor)
                    .font(.title2)
                Text("year_travel_statistics".localized(with: year))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
            }
            
            HStack(spacing: 12) {
                StatItem(title: "total".localized, value: "\(statistics.total)", icon: "map.fill", color: AppColorScheme.iconColor)
                StatItem(title: "domestic".localized, value: "\(statistics.domestic)", icon: "house.fill", color: AppColorScheme.iconColor)
                StatItem(title: "international".localized, value: "\(statistics.international)", icon: "airplane", color: AppColorScheme.iconColor)
                StatItem(title: "countries".localized, value: "\(statistics.countries)", icon: "globe.asia.australia.fill", color: AppColorScheme.iconColor)
            }
        }
        .padding(20)
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

struct DestinationRowCard: View {
    let destination: TravelDestination
    let primaryTextColor: Color
    @StateObject private var countryManager = CountryManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // 小卡片背景：使用浅米色卡片背景色
    private var cardBackgroundColor: Color {
        AppColorScheme.beigeCardBackground(for: colorScheme)
    }
    
    // 边框颜色：使用浅米色卡片边框颜色
    private var borderColor: Color {
        AppColorScheme.beigeCardBorder
    }
    
    // 小卡片阴影：中等强度的阴影效果
    private var shadowColor: Color {
        Color.black.opacity(0.08)
    }
    
    private var visitDateText: String {
        DestinationRowCard.dateFormatter.string(from: destination.visitDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(destination.name.isEmpty ? "-" : destination.name)
                        .font(.headline)
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                    
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                    }
                }
                
                Text(destination.country.isEmpty ? "-" : destination.country)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(visitDateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if countryManager.isDomestic(country: destination.country) {
                Image(systemName: "house.fill")
                    .foregroundColor(AppColorScheme.iconColor)
                    .font(.subheadline)
                    .padding(8)
                    .background(AppColorScheme.iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if !destination.country.isEmpty {
                Image(systemName: "airplane")
                    .foregroundColor(AppColorScheme.iconColor)
                    .font(.subheadline)
                    .padding(8)
                    .background(AppColorScheme.iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 6, x: 0, y: 2)
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
}
