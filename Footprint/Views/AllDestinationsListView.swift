//
//  AllDestinationsListView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI
import SwiftData

struct AllDestinationsListView: View {
    @Query(sort: \TravelDestination.visitDate, order: .reverse) private var allDestinations: [TravelDestination]
    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var editingDestination: TravelDestination?
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var countryManager = CountryManager.shared
    @State private var refreshID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    TextField("search_places_countries_notes".localized, text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // 目的地列表
                if !filteredDestinations.isEmpty {
                    ScrollView {
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
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("no_destinations_found".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("all_destinations".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(item: $editingDestination) { destination in
                EditDestinationView(destination: destination)
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
}

#Preview {
    AllDestinationsListView()
        .modelContainer(for: TravelDestination.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
}

