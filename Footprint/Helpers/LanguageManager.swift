//
//  LanguageManager.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import Foundation
import SwiftUI
import Combine

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: Language = .chinese
    
    // 当前使用的Bundle，用于动态切换语言
    private var currentBundle: Bundle = Bundle.main
    
    enum Language: String, CaseIterable {
        case chinese = "zh-Hans"
        case chineseTraditional = "zh-Hant"
        case english = "en"
        case japanese = "ja"
        case french = "fr"
        case spanish = "es"
        case korean = "ko"
        case german = "de"
        
        var displayName: String {
            switch self {
            case .chinese:
                return "简体中文"
            case .chineseTraditional:
                return "繁體中文"
            case .english:
                return "English"
            case .japanese:
                return "日本語"
            case .french:
                return "Français"
            case .spanish:
                return "Español"
            case .korean:
                return "한국어"
            case .german:
                return "Deutsch"
            }
        }
        
        var flag: String {
            switch self {
            case .chinese:
                return "🇨🇳"
            case .chineseTraditional:
                return "🇭🇰"
            case .english:
                return "🇺🇸"
            case .japanese:
                return "🇯🇵"
            case .french:
                return "🇫🇷"
            case .spanish:
                return "🇪🇸"
            case .korean:
                return "🇰🇷"
            case .german:
                return "🇩🇪"
            }
        }
    }
    
    private init() {
        // 从UserDefaults读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage"),
           let language = Language(rawValue: savedLanguage) {
            currentLanguage = language
            updateBundle(for: language)
        } else {
            // 如果没有保存的设置，根据系统语言自动选择
            // 优先匹配支持的语言，如果不支持则使用英文作为默认值
            currentLanguage = detectSystemLanguage()
            updateBundle(for: currentLanguage)
        }
    }
    
    // 检测系统语言并返回最匹配的应用语言
    private func detectSystemLanguage() -> Language {
        // 获取系统首选语言列表
        let preferredLanguages = Locale.preferredLanguages
        
        // 遍历系统语言列表，查找支持的语言
        for systemLang in preferredLanguages {
            // 检查是否为繁体中文
            if systemLang.hasPrefix("zh-Hant") || systemLang.hasPrefix("zh-TW") || systemLang.hasPrefix("zh-HK") {
                return .chineseTraditional
            }
            // 检查是否为简体中文（支持 zh-Hans, zh-CN 等）
            if systemLang.hasPrefix("zh") {
                return .chinese
            }
            // 检查是否为英文
            if systemLang.hasPrefix("en") {
                return .english
            }
            // 检查是否为日语
            if systemLang.hasPrefix("ja") {
                return .japanese
            }
            // 检查是否为法语
            if systemLang.hasPrefix("fr") {
                return .french
            }
            // 检查是否为西班牙语
            if systemLang.hasPrefix("es") {
                return .spanish
            }
            // 检查是否为韩语
            if systemLang.hasPrefix("ko") {
                return .korean
            }
            // 检查是否为德语
            if systemLang.hasPrefix("de") {
                return .german
            }
        }
        
        // 如果系统语言都不支持，默认使用英文
        // 这是iOS应用的标准做法：使用英文作为通用语言
        return .english
    }
    
    // 更新Bundle以支持动态语言切换
    private func updateBundle(for language: Language) {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // 如果找不到对应的语言包，使用主Bundle
            currentBundle = Bundle.main
            return
        }
        currentBundle = bundle
    }
    
    // 获取当前使用的Bundle
    var bundle: Bundle {
        return currentBundle
    }
    
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "SelectedLanguage")
        updateBundle(for: language)
        
        // 通知应用语言已更改
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    // 使用标准的NSLocalizedString机制
    func localizedString(for key: String) -> String {
        return NSLocalizedString(key, bundle: currentBundle, comment: "")
    }
    
    // 获取本地化的日期格式化器
    func localizedDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: currentLanguage.rawValue)
        return formatter
    }
    
    // 获取本地化的日期样式格式化器
    func localizedDateFormatter(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style = .none) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale(identifier: currentLanguage.rawValue)
        return formatter
    }
    
    // 获取本地化的日期格式字符串
    func localizedDateFormat() -> String {
        switch currentLanguage {
        case .chinese, .chineseTraditional:
            return "yyyy年MM月dd日"
        case .english:
            return "MMM dd, yyyy"
        case .japanese:
            return "yyyy年MM月dd日"
        case .french:
            return "dd MMM yyyy"
        case .spanish:
            return "dd MMM yyyy"
        case .korean:
            return "yyyy년 MM월 dd일"
        case .german:
            return "dd.MM.yyyy"
        }
    }
    
    // 获取本地化的时间格式字符串
    func localizedTimeFormat() -> String {
        switch currentLanguage {
        case .chinese, .chineseTraditional:
            return "HH:mm"
        case .english:
            return "h:mm a"
        case .japanese:
            return "HH:mm"
        case .french:
            return "HH:mm"
        case .spanish:
            return "HH:mm"
        case .korean:
            return "HH:mm"
        case .german:
            return "HH:mm"
        }
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
    static let openDestinationDrawer = Notification.Name("OpenDestinationDrawer")
    static let destinationDeleted = Notification.Name("DestinationDeleted")
    static let destinationUpdated = Notification.Name("DestinationUpdated")
    static let tripUpdated = Notification.Name("TripUpdated")
}

// 本地化字符串扩展
extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let localizedFormat = self.localized
        return String(format: localizedFormat, arguments: arguments)
    }
}

// 日期格式化扩展
extension Date {
    func localizedFormatted(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .none) -> String {
        let formatter = LanguageManager.shared.localizedDateFormatter(dateStyle: dateStyle, timeStyle: timeStyle)
        return formatter.string(from: self)
    }
    
    func localizedFormatted(format: String) -> String {
        let formatter = LanguageManager.shared.localizedDateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

