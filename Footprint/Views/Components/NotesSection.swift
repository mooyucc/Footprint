//
//  NotesSection.swift
//  Footprint
//
//  Created by K.X on 2025/11/26.
//

import SwiftUI

/// 可复用的笔记组件 - 带有温度引导和天气关联
struct NotesSection: View {
    @Binding var notes: String
    var weatherSummary: WeatherSummary? = nil  // 可选的天气信息
    var showWeatherAttribution: Bool = false   // 是否在标题旁展示归因链接
    var onAITap: (() -> Void)? = nil  // 可选的AI按钮点击回调
    var canUseAI: Bool = false  // 是否有权限使用AI功能
    @FocusState private var isFocused: Bool
    @EnvironmentObject private var brandColorManager: BrandColorManager
    
    // 动态占位符提示 - 结合时间和天气
    private var placeholderText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // 如果有天气信息，优先使用天气相关的提示
        if let weather = weatherSummary {
            return weatherBasedPlaceholder(weather: weather, hour: hour)
        }
        
        // 否则使用时间相关的提示
        if hour >= 6 && hour < 12 {
            return "notes_placeholder_morning".localized
        } else if hour >= 12 && hour < 18 {
            return "notes_placeholder_afternoon".localized
        } else if hour >= 18 && hour < 22 {
            return "notes_placeholder_evening".localized
        } else {
            return "notes_placeholder_night".localized
        }
    }
    
    // 根据天气情况生成个性化提示
    private func weatherBasedPlaceholder(weather: WeatherSummary, hour: Int) -> String {
        let temp = weather.temperatureText
        let condition = weather.conditionDescription
        
        // 根据天气类型和时间生成不同的提示
        switch weather.palette {
        case .sun:
            if hour >= 6 && hour < 12 {
                return "notes_placeholder_weather_sun_morning".localized(with: temp)
            } else if hour >= 12 && hour < 18 {
                return "notes_placeholder_weather_sun_afternoon".localized(with: temp)
            } else {
                return "notes_placeholder_weather_sun_evening".localized(with: temp)
            }
        case .warmCloud:
            return "notes_placeholder_weather_cloud".localized(with: temp, condition)
        case .rain:
            return "notes_placeholder_weather_rain".localized(with: temp, condition)
        case .storm:
            return "notes_placeholder_weather_storm".localized(with: temp, condition)
        case .snow:
            return "notes_placeholder_weather_snow".localized(with: temp, condition)
        case .haze:
            return "notes_placeholder_weather_haze".localized(with: temp, condition)
        case .night:
            if hour >= 18 || hour < 6 {
                return "notes_placeholder_weather_night".localized(with: temp, condition)
            } else {
                return "notes_placeholder_weather_default".localized(with: temp, condition)
            }
        }
    }
    
    // 字数统计和鼓励
    private var wordCount: Int {
        notes.trimmingCharacters(in: .whitespacesAndNewlines).count
    }
    
    private var encouragementText: String? {
        guard wordCount > 0 else { return nil }
        if wordCount < 10 {
            return "notes_encouragement_short".localized
        } else if wordCount < 30 {
            return "notes_encouragement_medium".localized
        } else {
            return "notes_encouragement_long".localized
        }
    }
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // 引导性问题 - 简洁版本，不重复天气信息
                if notes.isEmpty && !isFocused {
                    HStack(spacing: 6) {
                        if weatherSummary != nil {
                            // 有天气信息时，只显示图标和简洁问题，不重复天气文字
                            Image(systemName: "heart.text.square.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("notes_guide_question".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "heart.text.square.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("notes_guide_question".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 4)
                }
                
                // 文本编辑器
                ZStack(alignment: .topLeading) {
                    // 占位符
                    if notes.isEmpty {
                        Text(placeholderText)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                }
                
                // AI按钮（如果提供了回调）
                if let onAITap = onAITap {
                    Button {
                        onAITap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .medium))
                            Text("ai_generate_notes".localized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(canUseAI ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(canUseAI ? brandColorManager.currentBrandColor : Color(.secondarySystemFill))
                        )
                    }
                    .disabled(!canUseAI)
                    .padding(.top, 8)
                }
                
                // 字数统计和鼓励
                if wordCount > 0 {
                    HStack {
                        Spacer()
                        if let encouragement = encouragementText {
                            Text(encouragement)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("notes_word_count".localized(with: wordCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.caption)
                Text("notes".localized)
                Spacer(minLength: 8)
                
                if showWeatherAttribution {
                    WeatherAttributionLink()
                }
            }
        }
    }
}

#Preview {
    Form {
        NotesSection(notes: .constant(""))
    }
}

