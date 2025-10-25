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
    
    // 本地化字符串字典
    private var localizedStrings: [String: [String: String]] = [:]
    
    enum Language: String, CaseIterable {
        case chinese = "zh-Hans"
        case english = "en"
        
        var displayName: String {
            switch self {
            case .chinese:
                return "简体中文"
            case .english:
                return "English"
            }
        }
        
        var flag: String {
            switch self {
            case .chinese:
                return "🇨🇳"
            case .english:
                return "🇺🇸"
            }
        }
    }
    
    private init() {
        loadLocalizedStrings()
        
        // 从UserDefaults读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage"),
           let language = Language(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // 如果没有保存的设置，根据系统语言自动选择
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            if systemLanguage.hasPrefix("zh") {
                currentLanguage = .chinese
            } else {
                currentLanguage = .english
            }
        }
    }
    
    private func loadLocalizedStrings() {
        // 中文字符串
        localizedStrings["zh-Hans"] = [
            "settings": "设置",
            "done": "完成",
            "account": "账户",
            "not_logged_in": "未登录",
            "login_sync_description": "登录后数据自动同步到 iCloud",
            "data_sync": "数据同步",
            "icloud_sync": "iCloud 同步",
            "enabled": "已启用",
            "not_enabled": "未启用",
            "data_storage": "数据存储",
            "local": "本地",
            "icloud": "iCloud",
            "sync_description_logged_in": "你的旅行数据正在自动同步到 iCloud，可以在所有设备上访问。",
            "sync_description_not_logged_in": "登录 Apple ID 后，数据将自动同步到 iCloud，并在你的所有设备间保持同步。",
            "about": "关于",
            "version": "版本",
            "app_name": "应用名称",
            "sign_out": "退出登录",
            "language": "语言",
            "language_selection": "语言选择",
            "edit_username": "编辑用户名",
            "custom_username": "自定义用户名",
            "username_description": "设置一个你喜欢的显示名称",
            "enter_username": "请输入用户名",
            "cancel": "取消",
            "save": "保存",
            "iCloud_synced": "iCloud 已同步",
            "footprint": "Footprint",
            // 我的视图相关
            "map": "地图",
            "destinations": "足迹",
            "trips": "旅程",
            "profile": "我的",
            "my_travel_footprint": "我的旅行足迹",
            "record_every_journey": "记录每一次精彩的旅程",
            "sign_in_apple_id": "登录 Apple ID",
            "enable_icloud_sync": "开启 iCloud 同步，保护你的旅行数据",
            "travel_statistics": "旅行统计",
            "share": "分享",
            "total_destinations": "总目的地",
            "countries_visited": "访问国家",
            "domestic_travel": "国内旅行",
            "international_travel": "国外旅行",
            "my_favorites": "我的最爱",
            "travel_timeline": "旅行时间线",
            "no_travel_records": "还没有旅行记录",
            "destinations_count": "个目的地",
            "footprint_app": "Footprint - 旅行足迹",
            "record_journey_memories": "记录你的精彩旅程，留下美好回忆",
            "sign_in_with_apple": "通过Apple登录",
            // 年份过滤视图相关
            "filter": "筛选",
            "all": "全部",
            "domestic": "国内",
            "international": "国外",
            "edit": "编辑",
            "delete": "删除",
            "search_places_countries_notes": "搜索地点、国家或笔记",
            "total": "总计",
            "countries": "国家",
            // 旅程相关
            "my_trips": "我的旅程",
            "search_trips": "搜索旅程",
            "create_trip": "创建旅程",
            "import_trip": "导入旅程",
            "import_result": "导入结果",
            "ok": "确定",
            "import_success": "成功导入旅程",
            "trip_exists": "旅程已存在",
            "import_failed": "导入失败",
            "days": "天",
            "locations": "个地点",
            "trip_statistics": "旅程统计",
            "no_trip_records": "还没有旅程记录",
            "create_first_trip": "创建第一个旅程",
            "start": "开始",
            "end": "结束",
            "duration": "时长",
            "trip_route": "行程路线",
            "no_destinations_added": "还没有添加目的地",
            "share_trip": "分享旅程",
            "share_to_team": "分享给队友",
            "edit_trip": "编辑旅程",
            "delete_trip": "删除旅程",
            "confirm_delete_trip": "确定要删除这个旅程吗？关联的目的地不会被删除。",
            "trip_info": "旅程信息",
            "trip_name": "旅程名称",
            "description_optional": "描述（可选）",
            "time": "时间",
            "start_date": "开始日期",
            "end_date": "结束日期",
            "cover_image_optional": "封面图片（可选）",
            "add_cover_image": "添加封面图片",
            "change_cover_image": "更换封面图片",
            "trip_duration": "行程时长",
            "destination_count": "目的地数量",
            // 目的地详情视图相关
            "no_photo": "暂无照片",
            "belongs_to_trip": "所属旅程",
            "location_coordinates": "位置坐标",
            "latitude": "纬度",
            "longitude": "经度",
            "travel_notes": "旅行笔记",
            // 目的地列表视图相关
            "my_footprints": "我的足迹",
            "add_first_destination": "添加第一个目的地",
            "start_recording_footprints": "点击右上角的 + 按钮开始记录你的旅行足迹吧！",
            // 编辑目的地视图相关
            "edit_destination": "编辑目的地",
            "location_info": "位置信息",
            "current_location": "当前位置",
            "add_photo": "添加照片",
            "change_photo": "更换照片",
            "unknown_place": "未知地点",
            "latitude_longitude": "纬度: %.4f, 经度: %.4f",
            // 地图视图相关
            "getting_location_info": "正在获取位置信息...",
            "identifying_location": "请稍候，我们正在识别您选择的位置",
            "unknown_city": "未知城市",
            "unknown_country": "未知国家",
            "locations_count": "个地点",
            "delete_destination": "删除地点",
            "confirm_delete_destination": "确定要删除「%@」吗？此操作无法撤销。",
            "reverse_geocoding_failed": "反向地理编码失败: %@，尝试备用方案…",
            "nearby_search_success": "附近搜索成功，使用邻近地点推断: %@ - %@",
            "nearby_search_failed": "附近搜索失败: %@，继续使用坐标兜底…",
            "coordinate_fallback": "使用坐标兜底: %@ - %@ [分类: %@]",
            "user_location_obtained": "获取到用户位置: %f, %f",
            "location_permission_denied": "获取位置失败: %@",
            "location_authorization_changed": "位置授权状态变更: %d",
            "using_cached_country_region": "使用缓存的国家区域",
            "map_positioned_to": "地图定位到: %@ (%@)",
            "getting_user_location": "正在获取用户位置...",
            "preloaded_country_region": "已预加载国家区域: %@ (%@)",
            // 添加目的地视图相关
            "add_destination": "添加目的地",
            "basic_info": "基本信息",
            "place_name": "地点名称",
            "category": "分类",
            "country_region": "国家/地区",
            "visit_date": "访问日期",
            "mark_as_favorite": "标记为喜爱",
            "belongs_to_trip_optional": "所属旅程（可选）",
            "select_trip": "选择旅程",
            "none": "无",
            "location_search": "位置搜索",
            "search_place": "搜索地点...",
            "search": "搜索",
            "search_domestic_places": "🇨🇳 搜索国内地点:",
            "use_amap_data": "• 使用高德地图数据，搜索中国境内地点",
            "input_city_names": "• 直接输入城市名，如\"北京\"、\"上海\"、\"杭州\"",
            "input_attractions": "• 输入景点名，如\"故宫\"、\"西湖\"、\"外滩\"",
            "search_international_places": "🌍 搜索国外地点:",
            "use_apple_international": "• 使用 Apple 国际数据，搜索全球地点",
            "hot_cities_quick_search": "• ⭐ 热门城市快速搜索：London/伦敦、Paris/巴黎、Tokyo/东京等",
            "support_multilingual": "• 支持英文和中文输入，通过网络获取最新数据",
            "searching_places": "搜索%@地点中...",
            "no_results_found": "未找到结果",
            "suggestions": "建议：",
            "try_english_names": "1. 尝试使用英文地名搜索",
            "input_specific_address": "2. 输入更具体的地址，如\"London, UK\"",
            "check_spelling": "3. 检查拼写是否正确",
            "selected_location": "已选择位置",
            "photo": "照片",
            "select_photo": "选择照片",
            "notes": "笔记",
            "search_domestic_with_amap": "🇨🇳 使用高德地图数据搜索国内地点: %@",
            "amap_search_error": "❌ 高德地图搜索错误: %@",
            "fallback_to_clgeocoder": "🔄 备用搜索：使用 CLGeocoder 搜索国内地点",
            "amap_found_results": "✅ 高德地图找到 %d 个国内地点",
            "clgeocoder_found_results": "✅ CLGeocoder 找到 %d 个国内地点",
            "no_domestic_results": "❌ 未找到国内地点",
            "clgeocoder_search_failed": "❌ CLGeocoder 搜索失败",
            "search_international_with_apple": "🌍 使用 Apple 国际数据搜索国外地点: %@",
            "device_region": "📱 设备区域设置: %@",
            "device_language": "📱 设备语言: %@",
            "device_country": "📱 设备国家: %@",
            "found_in_preset_cities": "✅ 从预设城市库找到: %@, %@",
            "using_preset_coordinates": "✅ 使用预设坐标: (%.4f, %.4f)",
            "not_found_in_preset": "🔍 预设库中未找到，尝试使用 Apple 国际数据...",
            "apple_international_api_error": "❌ Apple 国际数据 API 错误: %@",
            "apple_api_returned_results": "📍 Apple 国际数据 API 返回 %d 个原始结果:",
            "raw_result_info": "  原始结果 %d:",
            "name_info": "    - 名称: %@",
            "country_info": "    - 国家: %@",
            "iso_code_info": "    - ISO代码: %@",
            "city_info": "    - 城市: %@",
            "filtered_international_count": "🔍 过滤后的国外地点数量: %d",
            "apple_final_results": "✅ Apple 国际数据最终显示 %d 个地点",
            "display_result_info": "显示结果 %d: %@ - %@",
            "apple_api_no_results": "⚠️ Apple 国际数据 API 未找到结果",
            "mksearch_error": "❌ MKLocalSearch 搜索错误: %@",
            "mksearch_found_results": "✅ MKLocalSearch 搜索到 %d 个结果",
            "location_selected": "✅ 已选择位置:",
            "selected_name": "   名称: %@",
            "selected_country": "   国家: %@",
            "selected_coordinates": "   坐标: (%.4f, %.4f)",
            // 旅程分享图片相关
            "trip_share_start": "开始",
            "trip_share_end": "结束", 
            "trip_share_duration": "时长",
            "trip_share_days": "天",
            "trip_share_route": "行程路线",
            "trip_share_locations_count": "个地点",
            "trip_share_no_destinations": "还没有添加目的地",
            "trip_share_signature": "✨ 来自 Footprint 旅程记录",
            "trip_share_subtitle": "记录美好旅程，分享精彩瞬间",
            // 旅行统计分享图片相关
            "stats_share_my_travel_footprint": "我的旅行足迹",
            "stats_share_destinations_count": "个旅行目的地",
            "stats_share_countries_count": "个国家",
            "stats_share_travel_timeline": "旅行时间线",
            "stats_share_footer": "✨ Footprint • 记录每一步旅程"
        ]
        
        // 英文字符串
        localizedStrings["en"] = [
            "settings": "Settings",
            "done": "Done",
            "account": "Account",
            "not_logged_in": "Not logged in",
            "login_sync_description": "Data will automatically sync to iCloud after logging in",
            "data_sync": "Data Sync",
            "icloud_sync": "iCloud Sync",
            "enabled": "Enabled",
            "not_enabled": "Not enabled",
            "data_storage": "Data Storage",
            "local": "Local",
            "icloud": "iCloud",
            "sync_description_logged_in": "Your travel data is automatically syncing to iCloud and accessible on all your devices.",
            "sync_description_not_logged_in": "After logging in with Apple ID, data will automatically sync to iCloud and remain synchronized across all your devices.",
            "about": "About",
            "version": "Version",
            "app_name": "App Name",
            "sign_out": "Sign Out",
            "language": "Language",
            "language_selection": "Language Selection",
            "edit_username": "Edit Username",
            "custom_username": "Custom Username",
            "username_description": "Set a display name you prefer",
            "enter_username": "Enter username",
            "cancel": "Cancel",
            "save": "Save",
            "iCloud_synced": "iCloud Synced",
            "footprint": "Footprint",
            // 我的视图相关
            "map": "Map",
            "destinations": "Footprints",
            "trips": "Trips",
            "profile": "Profile",
            "my_travel_footprint": "My Travel Footprint",
            "record_every_journey": "Record every wonderful journey",
            "sign_in_apple_id": "Sign in with Apple ID",
            "enable_icloud_sync": "Enable iCloud sync to protect your travel data",
            "travel_statistics": "Travel Statistics",
            "share": "Share",
            "total_destinations": "Total Destinations",
            "countries_visited": "Countries Visited",
            "domestic_travel": "Domestic Travel",
            "international_travel": "Overseas Travel",
            "my_favorites": "My Favorites",
            "travel_timeline": "Travel Timeline",
            "no_travel_records": "No travel records yet",
            "destinations_count": "destinations",
            "footprint_app": "Footprint - Travel Footprint",
            "record_journey_memories": "Record your wonderful journeys and create beautiful memories",
            "sign_in_with_apple": "Sign in with Apple",
            // 年份过滤视图相关
            "filter": "Filter",
            "all": "All",
            "domestic": "Domestic",
            "international": "Overseas",
            "edit": "Edit",
            "delete": "Delete",
            "search_places_countries_notes": "Search places, countries or notes",
            "total": "Total",
            "countries": "Countries",
            // 旅程相关
            "my_trips": "My Trips",
            "search_trips": "Search trips",
            "create_trip": "Create Trip",
            "import_trip": "Import Trip",
            "import_result": "Import Result",
            "ok": "OK",
            "import_success": "Successfully imported trip",
            "trip_exists": "Trip already exists",
            "import_failed": "Import failed",
            "days": "days",
            "locations": "locations",
            "trip_statistics": "Trip Statistics",
            "no_trip_records": "No trip records yet",
            "create_first_trip": "Create First Trip",
            "start": "Start",
            "end": "End",
            "duration": "Duration",
            "trip_route": "Trip Route",
            "no_destinations_added": "No destinations added yet",
            "share_trip": "Share Trip",
            "share_to_team": "Share to Team",
            "edit_trip": "Edit Trip",
            "delete_trip": "Delete Trip",
            "confirm_delete_trip": "Are you sure you want to delete this trip? Associated destinations will not be deleted.",
            "trip_info": "Trip Information",
            "trip_name": "Trip Name",
            "description_optional": "Description (Optional)",
            "time": "Time",
            "start_date": "Start Date",
            "end_date": "End Date",
            "cover_image_optional": "Cover Image (Optional)",
            "add_cover_image": "Add Cover Image",
            "change_cover_image": "Change Cover Image",
            "trip_duration": "Trip Duration",
            "destination_count": "Destination Count",
            // 目的地详情视图相关
            "no_photo": "No Photo",
            "belongs_to_trip": "Belongs to Trip",
            "location_coordinates": "Location Coordinates",
            "latitude": "Latitude",
            "longitude": "Longitude",
            "travel_notes": "Travel Notes",
            // 目的地列表视图相关
            "my_footprints": "My Footprints",
            "add_first_destination": "Add First Destination",
            "start_recording_footprints": "Tap the + button in the top right to start recording your travel footprints!",
            // 编辑目的地视图相关
            "edit_destination": "Edit Destination",
            "location_info": "Location Information",
            "current_location": "Current Location",
            "add_photo": "Add Photo",
            "change_photo": "Change Photo",
            "unknown_place": "Unknown Place",
            "latitude_longitude": "Latitude: %.4f, Longitude: %.4f",
            // Map view related
            "getting_location_info": "Getting location information...",
            "identifying_location": "Please wait, we are identifying your selected location",
            "unknown_city": "Unknown City",
            "unknown_country": "Unknown Country",
            "locations_count": "locations",
            "delete_destination": "Delete Destination",
            "confirm_delete_destination": "Are you sure you want to delete '%@'? This action cannot be undone.",
            "reverse_geocoding_failed": "Reverse geocoding failed: %@, trying fallback...",
            "nearby_search_success": "Nearby search successful, using nearby location inference: %@ - %@",
            "nearby_search_failed": "Nearby search failed: %@, continuing with coordinate fallback...",
            "coordinate_fallback": "Using coordinate fallback: %@ - %@ [Category: %@]",
            "user_location_obtained": "User location obtained: %f, %f",
            "location_permission_denied": "Failed to get location: %@",
            "location_authorization_changed": "Location authorization status changed: %d",
            "using_cached_country_region": "Using cached country region",
            "map_positioned_to": "Map positioned to: %@ (%@)",
            "getting_user_location": "Getting user location...",
            "preloaded_country_region": "Preloaded country region: %@ (%@)",
            // Add destination view related
            "add_destination": "Add Destination",
            "basic_info": "Basic Information",
            "place_name": "Place Name",
            "category": "Category",
            "country_region": "Country/Region",
            "visit_date": "Visit Date",
            "mark_as_favorite": "Mark as Favorite",
            "belongs_to_trip_optional": "Belongs to Trip (Optional)",
            "select_trip": "Select Trip",
            "none": "None",
            "location_search": "Location Search",
            "search_place": "Search place...",
            "search": "Search",
            "search_domestic_places": "🇨🇳 Search domestic places:",
            "use_amap_data": "• Use Amap data to search places in China",
            "input_city_names": "• Enter city names directly, such as \"Beijing\", \"Shanghai\", \"Hangzhou\"",
            "input_attractions": "• Enter attraction names, such as \"Forbidden City\", \"West Lake\", \"The Bund\"",
            "search_international_places": "🌍 Search overseas places:",
            "use_apple_international": "• Use Apple international data to search global places",
            "hot_cities_quick_search": "• ⭐ Hot cities quick search: London/伦敦、Paris/巴黎、Tokyo/东京 etc.",
            "support_multilingual": "• Support English and Chinese input, get latest data via network",
            "searching_places": "Searching %@ places...",
            "no_results_found": "No results found",
            "suggestions": "Suggestions:",
            "try_english_names": "1. Try searching with English place names",
            "input_specific_address": "2. Enter more specific address, such as \"London, UK\"",
            "check_spelling": "3. Check if spelling is correct",
            "selected_location": "Selected Location",
            "select_photo": "Select Photo",
            "search_domestic_with_amap": "🇨🇳 Using Amap data to search domestic places: %@",
            "amap_search_error": "❌ Amap search error: %@",
            "fallback_to_clgeocoder": "🔄 Fallback search: Using CLGeocoder to search domestic places",
            "amap_found_results": "✅ Amap found %d domestic places",
            "clgeocoder_found_results": "✅ CLGeocoder found %d domestic places",
            "no_domestic_results": "❌ No domestic places found",
            "clgeocoder_search_failed": "❌ CLGeocoder search failed",
            "search_international_with_apple": "🌍 Using Apple international data to search overseas places: %@",
            "device_region": "📱 Device region setting: %@",
            "device_language": "📱 Device language: %@",
            "device_country": "📱 Device country: %@",
            "found_in_preset_cities": "✅ Found in preset cities: %@, %@",
            "using_preset_coordinates": "✅ Using preset coordinates: (%.4f, %.4f)",
            "not_found_in_preset": "🔍 Not found in preset, trying Apple international data...",
            "apple_international_api_error": "❌ Apple international data API error: %@",
            "apple_api_returned_results": "📍 Apple international data API returned %d raw results:",
            "raw_result_info": "  Raw result %d:",
            "name_info": "    - Name: %@",
            "country_info": "    - Country: %@",
            "iso_code_info": "    - ISO Code: %@",
            "city_info": "    - City: %@",
            "filtered_international_count": "🔍 Filtered international places count: %d",
            "apple_final_results": "✅ Apple international data finally shows %d places",
            "display_result_info": "Display result %d: %@ - %@",
            "apple_api_no_results": "⚠️ Apple international data API found no results",
            "mksearch_error": "❌ MKLocalSearch error: %@",
            "mksearch_found_results": "✅ MKLocalSearch found %d results",
            "location_selected": "✅ Location selected:",
            "selected_name": "   Name: %@",
            "selected_country": "   Country: %@",
            "selected_coordinates": "   Coordinates: (%.4f, %.4f)",
            // Trip share image related
            "trip_share_start": "Start",
            "trip_share_end": "End",
            "trip_share_duration": "Duration", 
            "trip_share_days": "days",
            "trip_share_route": "Trip Route",
            "trip_share_locations_count": "locations",
            "trip_share_no_destinations": "No destinations added yet",
            "trip_share_signature": "✨ From Footprint Journey",
            "trip_share_subtitle": "Record wonderful journeys, share beautiful moments",
            // Travel stats share image related
            "stats_share_my_travel_footprint": "My Travel Footprint",
            "stats_share_destinations_count": "Travel Destinations",
            "stats_share_countries_count": "Countries",
            "stats_share_travel_timeline": "Travel Timeline",
            "stats_share_footer": "✨ Footprint • Record Every Journey"
        ]
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "SelectedLanguage")
        
        // 通知应用语言已更改
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    func localizedString(for key: String) -> String {
        return localizedStrings[currentLanguage.rawValue]?[key] ?? key
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
        case .chinese:
            return "yyyy年MM月dd日"
        case .english:
            return "MMM dd, yyyy"
        }
    }
    
    // 获取本地化的时间格式字符串
    func localizedTimeFormat() -> String {
        switch currentLanguage {
        case .chinese:
            return "HH:mm"
        case .english:
            return "h:mm a"
        }
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}

// 本地化字符串扩展
extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
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
