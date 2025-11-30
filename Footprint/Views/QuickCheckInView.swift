//
//  QuickCheckInView.swift
//  Footprint
//
//  Created by K.X on 2025/11/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import CoreLocation
import UIKit
import WeatherKit

/// 快速打卡界面 - 简化版，减少用户输入焦虑
struct QuickCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query private var allDestinations: [TravelDestination]
    @StateObject private var languageManager = LanguageManager.shared
    
    // 从外部传入的预填充数据（位置信息）
    private let prefill: AddDestinationPrefill?
    
    // 核心状态 - 最小化必填项
    @State private var name: String
    @State private var country: String
    @State private var province: String
    @State private var visitDate: Date
    @State private var selectedLocation: MKMapItem?
    @State private var category: String
    
    // 可选功能 - 简化界面中隐藏，可通过"更多选项"访问
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDatas: [Data] = []
    @State private var photoThumbnailDatas: [Data] = []
    @State private var selectedTrip: TravelTrip?
    @State private var notes = ""
    @State private var isFavorite = false
    
    // UI状态
    @State private var showFullEditor = false
    @State private var showDuplicateAlert = false
    @State private var duplicateDestinationName = ""
    @State private var existingDestination: TravelDestination?
    @State private var isSaving = false
    
    // 天气信息
    @State private var currentWeatherSummary: WeatherSummary?
    private let weatherService = WeatherService.shared
    
    init(prefill: AddDestinationPrefill? = nil) {
        self.prefill = prefill
        let initialName = prefill?.name ?? ""
        let initialCountry = prefill?.country ?? ""
        let initialProvince = prefill?.province ?? ""
        let initialCategory = prefill?.category ?? "domestic"
        let initialVisitDate = prefill?.visitDate ?? Date()
        let initialLocation = prefill?.location
        
        _name = State(initialValue: initialName)
        _country = State(initialValue: initialCountry)
        _province = State(initialValue: initialProvince)
        _visitDate = State(initialValue: initialVisitDate)
        _category = State(initialValue: initialCategory)
        _selectedLocation = State(initialValue: initialLocation)
        
        // 如果有照片预填充，也加载
        if let prefill = prefill {
            _photoDatas = State(initialValue: prefill.photoDatas)
            _photoThumbnailDatas = State(initialValue: prefill.photoThumbnailDatas)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("basic_info".localized) {
                    TextField("place_name".localized, text: $name)
                }
                
                // 使用可复用的旅程选择组件
                TripSelectionSection(selectedTrip: $selectedTrip)
                
                // 使用可复用的照片选择组件
                PhotoSelectionSection(
                    selectedPhotos: $selectedPhotos,
                    photoDatas: $photoDatas,
                    photoThumbnailDatas: $photoThumbnailDatas
                )
                
                // 使用可复用的笔记组件，传递天气信息
                NotesSection(notes: $notes, weatherSummary: currentWeatherSummary)
                
                Section {
                    Button {
                        showFullEditor = true
                    } label: {
                        HStack {
                            Label("more_options".localized, systemImage: "ellipsis.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("quick_check_in".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveDestination()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Text("save".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onChange(of: prefill?.location) { oldValue, newValue in
                updateFromPrefill()
            }
            .onChange(of: prefill?.name) { oldValue, newValue in
                updateFromPrefill()
            }
            .onAppear {
                updateFromPrefill()
                fetchWeatherIfNeeded()
            }
            .onChange(of: selectedLocation) { oldValue, newValue in
                fetchWeatherIfNeeded()
            }
            .alert("duplicate_destination_title".localized, isPresented: $showDuplicateAlert) {
                Button("duplicate_destination_overwrite".localized, role: .destructive) {
                    overwriteExistingDestination()
                }
                Button("duplicate_destination_cancel".localized, role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showFullEditor) {
                // 打开完整编辑界面，传递当前数据
                AddDestinationView(prefill: buildPrefillForFullEditor())
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 从 prefill 更新界面状态
    private func updateFromPrefill() {
        guard let prefill = prefill, let location = prefill.location else {
            return
        }
        
        // 更新位置
        selectedLocation = location
        
        // 更新名称
        let newName = prefill.name ?? location.name ?? location.placemark.locality ?? ""
        if name != newName {
            name = newName
        }
        
        // 更新国家
        let newCountry = prefill.country ?? location.placemark.country ?? ""
        if country != newCountry {
            country = newCountry
        }
        
        // 更新省份（对于中国直辖市，会将其名称作为省份）
        let newProvince = prefill.province ?? CountryManager.extractProvince(
            administrativeArea: location.placemark.administrativeArea,
            locality: location.placemark.locality,
            country: newCountry,
            isoCountryCode: location.placemark.isoCountryCode
        )
        if province != newProvince {
            province = newProvince
        }
        
        // 根据国家信息自动判断分类
        if let countryCode = location.placemark.isoCountryCode {
            let newCategory: String
            if countryCode == "CN" || country == "中国" || country == "China" {
                newCategory = "domestic"
            } else {
                newCategory = "international"
            }
            if category != newCategory {
                category = newCategory
            }
        }
        
        // 如果有访问日期，也更新
        if let visitDate = prefill.visitDate {
            self.visitDate = visitDate
        }
    }
    
    // MARK: - 验证和保存
    
    private var isValid: Bool {
        !name.isEmpty && !country.isEmpty && selectedLocation != nil
    }
    
    private var alertMessage: String {
        guard let existing = existingDestination else {
            return "duplicate_destination_message".localized(with: duplicateDestinationName, "", "", "")
        }
        
        let notesText = existing.notes.isEmpty ? "" : "\n备注：\(existing.notes)"
        return "duplicate_destination_message".localized(
            with: duplicateDestinationName,
            existing.country,
            existing.visitDate.localizedFormatted(dateStyle: .medium),
            notesText
        )
    }
    
    private func saveDestination() {
        guard let location = selectedLocation else { return }
        
        isSaving = true
        
        // 检查是否存在同名目的地
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingDestination = allDestinations.first { destination in
            destination.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedName.lowercased()
        }
        
        if let existing = existingDestination {
            self.existingDestination = existing
            duplicateDestinationName = trimmedName
            showDuplicateAlert = true
            isSaving = false
            return
        }
        
        // 没有重复，直接保存
        createAndSaveDestination()
    }
    
    private func createAndSaveDestination() {
        guard let location = selectedLocation else {
            isSaving = false
            return
        }
        
        let destination = TravelDestination(
            name: name,
            country: country,
            province: province,
            latitude: location.placemark.coordinate.latitude,
            longitude: location.placemark.coordinate.longitude,
            visitDate: visitDate,
            notes: notes,
            photoData: photoDatas.first,
            photoDatas: photoDatas,
            photoThumbnailData: photoThumbnailDatas.first,
            photoThumbnailDatas: photoThumbnailDatas,
            category: category,
            isFavorite: isFavorite
        )
        
        // 关联到旅程
        if let trip = selectedTrip {
            destination.trip = trip
        }
        
        modelContext.insert(destination)
        try? modelContext.save()
        
        // 发送更新通知，通知徽章视图更新（新增目的地）
        NotificationCenter.default.post(name: .destinationUpdated, object: nil)
        
        isSaving = false
        dismiss()
    }
    
    private func overwriteExistingDestination() {
        guard let existing = existingDestination else {
            isSaving = false
            return
        }
        
        // 更新现有目的地的信息
        existing.name = name
        existing.country = country
        existing.province = province
        existing.latitude = selectedLocation?.placemark.coordinate.latitude ?? existing.latitude
        existing.longitude = selectedLocation?.placemark.coordinate.longitude ?? existing.longitude
        existing.visitDate = visitDate
        existing.notes = notes
        existing.photoData = photoDatas.first
        existing.photoDatas = photoDatas
        existing.photoThumbnailData = photoThumbnailDatas.first
        existing.photoThumbnailDatas = photoThumbnailDatas
        existing.category = category
        existing.isFavorite = isFavorite
        
        // 更新旅程关联
        existing.trip = selectedTrip
        
        // 保存更新
        try? modelContext.save()
        
        // 发送更新通知，通知徽章视图更新（覆盖现有目的地）
        NotificationCenter.default.post(name: .destinationUpdated, object: nil)
        
        isSaving = false
        dismiss()
    }
    
    /// 构建传递给完整编辑界面的预填充数据
    private func buildPrefillForFullEditor() -> AddDestinationPrefill {
        return AddDestinationPrefill(
            location: selectedLocation,
            name: name,
            country: country,
            province: province,
            category: category,
            visitDate: visitDate,
            photoDatas: photoDatas,
            photoThumbnailDatas: photoThumbnailDatas
        )
    }
    
    // MARK: - 天气获取
    
    /// 获取当前位置的天气信息
    private func fetchWeatherIfNeeded() {
        guard let location = selectedLocation else {
            currentWeatherSummary = nil
            return
        }
        
        let coordinate = location.placemark.coordinate
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        Task {
            do {
                let weather = try await weatherService.weather(for: clLocation)
                let summary = makeWeatherSummary(from: weather.currentWeather)
                await MainActor.run {
                    currentWeatherSummary = summary
                }
            } catch {
                // 天气获取失败时静默处理，不影响主要功能
                #if DEBUG
                print("🌧️ 获取天气失败: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    currentWeatherSummary = nil
                }
            }
        }
    }
    
    /// 从CurrentWeather创建WeatherSummary
    private func makeWeatherSummary(from current: CurrentWeather) -> WeatherSummary {
        let palette = WeatherGlyphPalette(condition: current.condition, isDaylight: current.isDaylight)
        let conditionText = current.condition.description
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.autoupdatingCurrent
        measurementFormatter.unitStyle = .short
        measurementFormatter.numberFormatter.maximumFractionDigits = 0
        let temperatureText = measurementFormatter.string(from: current.temperature)
        
        return WeatherSummary(
            temperatureText: temperatureText,
            conditionDescription: conditionText,
            symbolName: current.symbolName,
            palette: palette
        )
    }
}

#Preview {
    let prefill = AddDestinationPrefill(
        location: nil,
        name: "示例地点",
        country: "中国",
        category: "domestic",
        visitDate: Date()
    )
    return QuickCheckInView(prefill: prefill)
        .modelContainer(for: TravelDestination.self, inMemory: true)
}

