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
    @FocusState private var isFocused: Bool
    
    // 动态占位符提示 - 结合时间和天气
    private var placeholderText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // 如果有天气信息，优先使用天气相关的提示
        if let weather = weatherSummary {
            return weatherBasedPlaceholder(weather: weather, hour: hour)
        }
        
        // 否则使用时间相关的提示
        if hour >= 6 && hour < 12 {
            return "早上好！记录一下此刻的心情吧 ☀️"
        } else if hour >= 12 && hour < 18 {
            return "下午时光，想记录些什么？🌤️"
        } else if hour >= 18 && hour < 22 {
            return "傍晚时分，记录今天的心情吧 🌆"
        } else {
            return "夜深了，记录下今天的心情吧 🌙"
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
                return "今天天气真好（\(temp)），阳光明媚，心情如何？☀️"
            } else if hour >= 12 && hour < 18 {
                return "\(temp)的晴朗午后，想记录些什么？🌞"
            } else {
                return "今天天气很棒（\(temp)），记录下此刻的心情吧 ✨"
            }
        case .warmCloud:
            return "今天\(temp)，\(condition)，想记录些什么？☁️"
        case .rain:
            return "今天\(temp)，\(condition)，在这样的天气里有什么感受？🌧️"
        case .storm:
            return "今天\(temp)，\(condition)，记录下这个特别的时刻吧 ⛈️"
        case .snow:
            return "今天\(temp)，\(condition)，雪天的心情如何？❄️"
        case .haze:
            return "今天\(temp)，\(condition)，记录下此刻的感受吧 🌫️"
        case .night:
            if hour >= 18 || hour < 6 {
                return "夜晚的\(temp)，\(condition)，想记录些什么？🌙"
            } else {
                return "今天\(temp)，\(condition)，记录下此刻的心情吧 ✨"
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
            return "再写一点，让回忆更完整 💫"
        } else if wordCount < 30 {
            return "很棒！继续记录更多细节 ✨"
        } else {
            return "太棒了！这些文字会成为珍贵的回忆 🌟"
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
                
                // 字数统计和鼓励
                if wordCount > 0 {
                    HStack {
                        Spacer()
                        if let encouragement = encouragementText {
                            Text(encouragement)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(wordCount) 字")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.caption)
                Text("notes".localized)
            }
        }
    }
}

#Preview {
    Form {
        NotesSection(notes: .constant(""))
    }
}

