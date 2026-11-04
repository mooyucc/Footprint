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
    @State private var detailDestination: TravelDestination?
    @State private var filteredDestinationsCache: [TravelDestination] = []
    @State private var searchFilterDebounceTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @StateObject private var countryManager = CountryManager.shared
    @ObservedObject private var destinationRevision = DestinationDataRevision.shared
    @State private var statisticsCache: (total: Int, domestic: Int, international: Int, countries: Int)?
    @State private var lastHandledStatisticsRevision = -1
    @State private var yearStatisticsDebounceTask: Task<Void, Never>?
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @State private var shareItem: TripShareItem?
    @State private var showingLayoutSelection = false
    @State private var selectedLayout: TripShareLayout = .list
    
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
    
    private func recomputeFilteredDestinations() {
        var result = allDestinations
        
        if let category = filterCategory {
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
        
        filteredDestinationsCache = result
    }
    
    private func scheduleSearchFilterRefresh() {
        searchFilterDebounceTask?.cancel()
        searchFilterDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                recomputeFilteredDestinations()
            }
        }
    }
    
    var statistics: (total: Int, domestic: Int, international: Int, countries: Int) {
        statisticsCache ?? computeYearStatistics(from: allDestinations)
    }
    
    private func computeYearStatistics(from destinations: [TravelDestination]) -> (total: Int, domestic: Int, international: Int, countries: Int) {
        let total = destinations.count
        let domestic = destinations.filter { countryManager.isDomestic(country: $0.country) }.count
        let international = total - domestic
        let countries = Set(destinations.map(\.country)).count
        return (total, domestic, international, countries)
    }

    private func refreshYearStatisticsIfNeeded() {
        let rev = destinationRevision.revision
        guard statisticsCache == nil || rev != lastHandledStatisticsRevision else { return }
        lastHandledStatisticsRevision = rev
        statisticsCache = computeYearStatistics(from: allDestinations)
    }

    private func scheduleYearStatisticsRefresh() {
        yearStatisticsDebounceTask?.cancel()
        yearStatisticsDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                refreshYearStatisticsIfNeeded()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                FootprintAtmosphereBackground(
                    accent: brandColorManager.currentBrandColor,
                    secondaryAccent: FootprintTheme.Accent.secondary
                )
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        YearStatisticsCard(year: year, statistics: statistics)
                        
                        FootprintFilterChipRow(
                            selection: $filterCategory,
                            options: [
                                (nil, "all".localized),
                                ("domestic", "domestic".localized),
                                ("international", "international".localized)
                            ],
                            accent: brandColorManager.currentBrandColor
                        )
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                                .font(.subheadline)
                            
                            TextField("search_places_countries_notes".localized, text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .footprintCapsuleChrome()
                        
                        if !filteredDestinationsCache.isEmpty {
                            Text("travel_destinations".localized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                                .padding(.top, 4)
                            
                            ForEach(filteredDestinationsCache) { destination in
                                Button {
                                    detailDestination = destination
                                } label: {
                                    DestinationRowCard(destination: destination, highResolutionCover: true)
                                }
                                .buttonStyle(.plain)
                                .cylinderScrollEffect()
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
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 44))
                                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                                Text("no_destinations_found".localized)
                                    .font(.headline)
                                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .contentMargins(.vertical, 16, for: .scrollContent)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("year_travel_records".localized(with: year))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLayoutSelection = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(item: $detailDestination) { destination in
                NavigationStack {
                    DestinationDetailView(destination: destination)
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
            }
            .sheet(item: $shareItem) { item in
                if let image = item.image {
                    SystemShareSheet(items: [image])
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .destinationDeleted)) { notification in
                if let userInfo = notification.userInfo,
                   let deletedDestinationId = userInfo["destinationId"] as? UUID {
                    if let editing = editingDestination, editing.id == deletedDestinationId {
                        editingDestination = nil
                    }
                    if let detail = detailDestination, detail.id == deletedDestinationId {
                        detailDestination = nil
                    }
                } else {
                    if editingDestination != nil {
                        editingDestination = nil
                    }
                    if detailDestination != nil {
                        detailDestination = nil
                    }
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
            .onAppear {
                refreshYearStatisticsIfNeeded()
                recomputeFilteredDestinations()
            }
            .onChange(of: filterCategory) { _, _ in
                recomputeFilteredDestinations()
            }
            .onChange(of: searchText) { _, _ in
                scheduleSearchFilterRefresh()
            }
            .onChange(of: destinationRevision.revision) { _, _ in
                scheduleYearStatisticsRefresh()
                recomputeFilteredDestinations()
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
            let destination = filteredDestinationsCache[index]
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(brandColorManager.currentBrandColor)
                    .font(.headline)
                Text("year_travel_statistics".localized(with: year))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(statistics.total)")
                    .font(.system(size: 52, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(statistics.total)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("total_destinations".localized)
                    .font(.subheadline)
                    .foregroundStyle(FootprintChrome.secondaryLabel(colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            FootprintRowDivider()

            HStack(spacing: 0) {
                ProfileStatSecondaryCell(
                    value: statistics.countries,
                    label: "countries_visited".localized
                )
                Rectangle()
                    .fill(FootprintChrome.hairline(colorScheme))
                    .frame(width: FootprintChrome.hairlineHeight)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
                ProfileStatSecondaryCell(
                    value: statistics.domestic,
                    label: "domestic_travel".localized
                )
                Rectangle()
                    .fill(FootprintChrome.hairline(colorScheme))
                    .frame(width: FootprintChrome.hairlineHeight)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
                ProfileStatSecondaryCell(
                    value: statistics.international,
                    label: "international_travel".localized
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .footprintGlassCard(glow: brandColorManager.currentBrandColor)
    }
}

struct DestinationRowCard: View {
    let destination: TravelDestination
    /// 列表默认 168；时光轮播等场景可传入更高值
    var height: CGFloat = 168
    /// 时光大卡：优先主图高清解码
    var highResolutionCover: Bool = false
    /// 封面取色氛围光（光晕在 clip 之外）
    var showsAmbientGlow: Bool = false
    /// 仅中心卡显示氛围光
    var isAmbientFocused: Bool = false
    /// 聚焦卡主色变化时回调（供时光转轮等外层光晕）
    var onAmbientColorChange: ((Color?) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ambientColor: Color?

    private var visitDateText: String {
        DestinationRowCard.dateFormatter.string(from: destination.visitDate)
    }
    
    private var regionTag: (text: String, color: Color)? {
        if CountryManager.shared.isDomestic(country: destination.country) {
            return ("domestic".localized, Color(red: 0x3A/255.0, green: 0x8B/255.0, blue: 0xBB/255.0)) // #3A8BBB
        } else if !destination.country.isEmpty {
            return ("international".localized, Color(red: 0x50/255.0, green: 0xA3/255.0, blue: 0x7B/255.0)) // #50A37B
        }
        return nil
    }
    
    var body: some View {
        cardContent
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous)
                    .stroke(FootprintChrome.cardStroke(colorScheme), lineWidth: 0.5)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
                radius: 18,
                y: 8
            )
            .contentShape(RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous))
            // HealthUI 同款：底部椭圆渗光（透明度对齐 footprintGlassCard）
            .background(alignment: .bottom) {
                if showsAmbientGlow, let ambientColor {
                    Ellipse()
                        .fill(ambientColor.opacity(colorScheme == .dark ? 0.55 : 0.22))
                        .frame(height: 48)
                        .blur(radius: 26)
                        .padding(.horizontal, 24)
                        .offset(y: 12)
                        .opacity(isAmbientFocused ? 1 : 0)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.45),
                            value: ambientColor
                        )
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.3),
                            value: isAmbientFocused
                        )
                        .allowsHitTesting(false)
                }
            }
            .frame(height: height)
            .onChange(of: isAmbientFocused) { _, focused in
                guard focused else { return }
                onAmbientColorChange?(ambientColor)
            }
            .onChange(of: ambientColor) { _, color in
                guard isAmbientFocused else { return }
                onAmbientColorChange?(color)
            }
    }

    private var cardContent: some View {
        ZStack(alignment: .bottomLeading) {
            DestinationRowCardBackground(
                destination: destination,
                highResolutionCover: highResolutionCover,
                onDominantColor: showsAmbientGlow
                    ? { color in
                        ambientColor = color
                    }
                    : nil
            )

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
            .clipShape(RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous))
            .allowsHitTesting(false)

            // 内容层
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(destination.name.isEmpty ? "-" : destination.name)
                                .font(.system(size: 22, weight: .black, design: .default))
                                .tracking(-0.3)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                            if destination.isFavorite {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                    .font(.caption)
                            }

                            Spacer()
                        }

                        HStack(spacing: 8) {
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

                            Text("·")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            Text(visitDateText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))

                            Spacer()
                        }
                    }
                    .padding(16)
                }

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
    }
    
    private static let cardRadius = FootprintTheme.Radius.card
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct DestinationRowCardBackground: View {
    let destination: TravelDestination
    var highResolutionCover: Bool = false
    var onDominantColor: ((Color) -> Void)? = nil
    @State private var image: UIImage?

    private static let placeholderColor = Color(red: 0x67/255.0, green: 0x93/255.0, blue: 0xC3/255.0)

    private var coverFullData: Data? {
        if let first = destination.photoDatas.first, !first.isEmpty { return first }
        return destination.photoData
    }

    private var coverThumbnailData: Data? {
        if let first = destination.photoThumbnailDatas.first, !first.isEmpty { return first }
        return destination.photoThumbnailData
    }

    var body: some View {
        Group {
            if let image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(highResolutionCover ? .high : .medium)
                        .antialiased(true)
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            } else {
                RoundedRectangle(cornerRadius: FootprintTheme.Radius.card, style: .continuous)
                    .fill(Self.placeholderColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FootprintTheme.Radius.card, style: .continuous))
        .allowsHitTesting(false)
        .task(id: destination.id) {
            let loaded: UIImage?
            if highResolutionCover {
                if let cached = DestinationThumbnailCache.shared.cachedTimeCapsuleCoverImage(for: destination.id) {
                    loaded = cached
                } else {
                    loaded = await DestinationThumbnailCache.shared.imageForTimeCapsuleCover(
                        for: destination.id,
                        fullData: coverFullData,
                        thumbnailData: coverThumbnailData
                    )
                }
            } else if let cached = DestinationThumbnailCache.shared.cachedListCardImage(for: destination.id) {
                loaded = cached
            } else {
                loaded = await DestinationThumbnailCache.shared.imageForListCard(
                    for: destination.id,
                    thumbnailData: coverThumbnailData,
                    fallbackData: coverFullData
                )
            }
            image = loaded

            guard let loaded, let onDominantColor else { return }
            let uiColor = await Task.detached(priority: .utility) {
                ImageProcessor.dominantColor(from: loaded)
            }.value
            if let uiColor {
                onDominantColor(Color(uiColor))
            }
        }
    }
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
        applyChrome(to: segmentedControl)
        
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
        applyChrome(to: uiView)
        // 更新选中状态
        if let index = options.firstIndex(where: { $0.tag == selection }) {
            if uiView.selectedSegmentIndex != index {
                uiView.selectedSegmentIndex = index
            }
        } else if uiView.selectedSegmentIndex != 0 {
            uiView.selectedSegmentIndex = 0
        }
    }

    /// 玻璃卡上的分段控件：未选中用 secondaryLabel，选中用 label + 系统填充
    private func applyChrome(to control: UISegmentedControl) {
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.secondaryLabel
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.label
        ], for: .selected)
        control.selectedSegmentTintColor = .secondarySystemGroupedBackground
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
