//
//  DestinationWeatherManager.swift
//  Footprint
//
//  Created by GPT-5.1 Codex on 2025/11/25.
//

import Foundation
import CoreLocation
import WeatherKit
import SwiftUI
import Combine

/// 轻量天气摘要，供地点标注展示
struct WeatherSummary: Equatable {
    let temperatureText: String
    let conditionDescription: String
    let symbolName: String
    let palette: WeatherGlyphPalette
}

/// 彩色天气图标调色板
enum WeatherGlyphPalette: String, CaseIterable {
    case sun
    case warmCloud
    case rain
    case storm
    case snow
    case haze
    case night
    
    init(condition: WeatherCondition, isDaylight: Bool) {
        switch condition {
        case .clear:
            self = isDaylight ? .sun : .night
        case .mostlyClear, .partlyCloudy, .mostlyCloudy, .cloudy:
            self = isDaylight ? .warmCloud : .night
        case .rain, .drizzle, .heavyRain:
            self = .rain
        case .freezingDrizzle, .freezingRain, .sleet:
            self = .snow
        case .snow, .heavySnow, .blizzard, .flurries:
            self = .snow
        case .hail, .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms:
            self = .storm
        case .foggy, .haze:
            self = .haze
        @unknown default:
            self = isDaylight ? .warmCloud : .night
        }
    }
    
    var backgroundGradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var gradientColors: [Color] {
        switch self {
        case .sun:
            return [
                Color(red: 1.0, green: 0.84, blue: 0.35),
                Color(red: 1.0, green: 0.58, blue: 0.24)
            ]
        case .warmCloud:
            return [
                Color(red: 0.56, green: 0.73, blue: 1.0),
                Color(red: 0.32, green: 0.46, blue: 0.93)
            ]
        case .rain:
            return [
                Color(red: 0.23, green: 0.56, blue: 0.96),
                Color(red: 0.05, green: 0.31, blue: 0.68)
            ]
        case .storm:
            return [
                Color(red: 0.29, green: 0.31, blue: 0.55),
                Color(red: 0.09, green: 0.10, blue: 0.24)
            ]
        case .snow:
            return [
                Color(red: 0.85, green: 0.95, blue: 1.0),
                Color(red: 0.63, green: 0.79, blue: 0.95)
            ]
        case .haze:
            return [
                Color(red: 0.78, green: 0.78, blue: 0.72),
                Color(red: 0.59, green: 0.59, blue: 0.54)
            ]
        case .night:
            return [
                Color(red: 0.18, green: 0.23, blue: 0.42),
                Color(red: 0.04, green: 0.08, blue: 0.2)
            ]
        }
    }
    
    var symbolPrimary: Color {
        switch self {
        case .sun:
            return Color(red: 1.0, green: 0.95, blue: 0.82)
        case .warmCloud, .rain:
            return .white
        case .storm:
            return Color(red: 0.94, green: 0.96, blue: 1.0)
        case .snow:
            return Color(red: 0.36, green: 0.53, blue: 0.79)
        case .haze:
            return Color(red: 0.96, green: 0.96, blue: 0.9)
        case .night:
            return Color(red: 0.91, green: 0.94, blue: 1.0)
        }
    }
    
    var symbolSecondary: Color {
        switch self {
        case .sun:
            return Color(red: 1.0, green: 0.85, blue: 0.45)
        case .warmCloud:
            return Color(red: 0.8, green: 0.92, blue: 1.0)
        case .rain:
            return Color(red: 0.64, green: 0.83, blue: 1.0)
        case .storm:
            return Color(red: 1.0, green: 0.84, blue: 0.57)
        case .snow:
            return Color(red: 0.94, green: 0.97, blue: 1.0)
        case .haze:
            return Color(red: 0.86, green: 0.86, blue: 0.78)
        case .night:
            return Color(red: 0.54, green: 0.66, blue: 0.93)
        }
    }
}

/// 负责按地点ID缓存天气摘要，避免重复请求
@MainActor
final class DestinationWeatherManager: ObservableObject {
    @Published private(set) var summaries: [UUID: WeatherSummary] = [:]
    
    private var cacheExpiry: [UUID: Date] = [:]
    private var lastFailure: [UUID: Date] = [:]
    private var inFlight: Set<UUID> = []
    private let cacheDuration: TimeInterval = 30 * 60
    private let failureCooldown: TimeInterval = 3 * 60
    private let measurementFormatter: MeasurementFormatter
    private let weatherService = WeatherService.shared
    
    init() {
        measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.autoupdatingCurrent
        measurementFormatter.unitStyle = .short
        measurementFormatter.numberFormatter.maximumFractionDigits = 0
    }
    
    func summary(for destinationID: UUID) -> WeatherSummary? {
        summaries[destinationID]
    }
    
    func refreshWeatherIfNeeded(for destination: TravelDestination, force: Bool = false) async {
        // 旧数据依然有效，直接返回
        if !force,
           let expiry = cacheExpiry[destination.id],
           expiry > Date(),
           summaries[destination.id] != nil {
            return
        }
        
        // 失败后短时间内不再尝试，避免频繁触发限流
        if !force,
           let failure = lastFailure[destination.id],
           Date().timeIntervalSince(failure) < failureCooldown {
            return
        }
        
        guard !inFlight.contains(destination.id) else { return }
        inFlight.insert(destination.id)
        defer { inFlight.remove(destination.id) }
        
        await fetchWeather(for: destination)
    }
    
    func invalidate(destinationID: UUID) {
        cacheExpiry[destinationID] = Date(timeIntervalSince1970: 0)
    }
    
    func reset() {
        cacheExpiry.removeAll()
        lastFailure.removeAll()
    }
    
    private func fetchWeather(for destination: TravelDestination) async {
        let location = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        do {
            let weather = try await weatherService.weather(for: location)
            let summary = makeSummary(from: weather.currentWeather)
            summaries[destination.id] = summary
            cacheExpiry[destination.id] = Date().addingTimeInterval(cacheDuration)
            lastFailure[destination.id] = nil
        } catch {
            lastFailure[destination.id] = Date()
            #if DEBUG
            print("🌧️ WeatherKit请求失败: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func makeSummary(from current: CurrentWeather) -> WeatherSummary {
        let palette = WeatherGlyphPalette(condition: current.condition, isDaylight: current.isDaylight)
        let conditionText = current.condition.description
        let temperatureText = measurementFormatter.string(from: current.temperature)
        
        return WeatherSummary(
            temperatureText: temperatureText,
            conditionDescription: conditionText,
            symbolName: current.symbolName,
            palette: palette
        )
    }
}

