//
//  CityDataManager.swift
//  Footprint
//
//  Created by K.X on 2025/01/27.
//

import Foundation

/// 多语言城市数据结构
struct CityInfo {
    let englishName: String      // 英文名称
    let chineseName: String      // 中文名称
    let country: String          // 国家名称
    let latitude: Double         // 纬度
    let longitude: Double        // 经度
    
    /// 根据当前语言环境返回对应的城市名称
    var localizedName: String {
        let currentLanguage = Locale.current.languageCode ?? "en"
        return currentLanguage == "zh" ? chineseName : englishName
    }
    
    /// 根据当前语言环境返回对应的国家名称
    var localizedCountry: String {
        let currentLanguage = Locale.current.languageCode ?? "en"
        return getLocalizedCountry(for: country, language: currentLanguage)
    }
    
    /// 获取本地化的国家名称
    private func getLocalizedCountry(for country: String, language: String) -> String {
        let countryMappings: [String: [String: String]] = [
            "United Kingdom": ["zh": "英国", "en": "United Kingdom"],
            "France": ["zh": "法国", "en": "France"],
            "Italy": ["zh": "意大利", "en": "Italy"],
            "Spain": ["zh": "西班牙", "en": "Spain"],
            "Netherlands": ["zh": "荷兰", "en": "Netherlands"],
            "Russia": ["zh": "俄罗斯", "en": "Russia"],
            "Japan": ["zh": "日本", "en": "Japan"],
            "South Korea": ["zh": "韩国", "en": "South Korea"],
            "Singapore": ["zh": "新加坡", "en": "Singapore"],
            "Thailand": ["zh": "泰国", "en": "Thailand"],
            "United States": ["zh": "美国", "en": "United States"],
            "Australia": ["zh": "澳大利亚", "en": "Australia"],
            "United Arab Emirates": ["zh": "阿联酋", "en": "United Arab Emirates"],
            "Turkey": ["zh": "土耳其", "en": "Turkey"],
            "Germany": ["zh": "德国", "en": "Germany"],
            "Greece": ["zh": "希腊", "en": "Greece"],
            "Austria": ["zh": "奥地利", "en": "Austria"],
            "Iceland": ["zh": "冰岛", "en": "Iceland"],
            "Ireland": ["zh": "爱尔兰", "en": "Ireland"],
            "Mexico": ["zh": "墨西哥", "en": "Mexico"],
            "Canada": ["zh": "加拿大", "en": "Canada"],
            "Vietnam": ["zh": "越南", "en": "Vietnam"],
            "Egypt": ["zh": "埃及", "en": "Egypt"],
            "Brazil": ["zh": "巴西", "en": "Brazil"],
            "Portugal": ["zh": "葡萄牙", "en": "Portugal"],
            "New Zealand": ["zh": "新西兰", "en": "New Zealand"],
            "India": ["zh": "印度", "en": "India"],
            "Switzerland": ["zh": "瑞士", "en": "Switzerland"],
            "Belgium": ["zh": "比利时", "en": "Belgium"],
            "Czech Republic": ["zh": "捷克共和国", "en": "Czech Republic"],
            "Hungary": ["zh": "匈牙利", "en": "Hungary"],
            "Poland": ["zh": "波兰", "en": "Poland"],
            "Croatia": ["zh": "克罗地亚", "en": "Croatia"],
            "Argentina": ["zh": "阿根廷", "en": "Argentina"],
            "Chile": ["zh": "智利", "en": "Chile"],
            "Peru": ["zh": "秘鲁", "en": "Peru"],
            "Cuba": ["zh": "古巴", "en": "Cuba"],
            "Costa Rica": ["zh": "哥斯达黎加", "en": "Costa Rica"],
            "Morocco": ["zh": "摩洛哥", "en": "Morocco"],
            "South Africa": ["zh": "南非", "en": "South Africa"],
            "Kenya": ["zh": "肯尼亚", "en": "Kenya"],
            "Tanzania": ["zh": "坦桑尼亚", "en": "Tanzania"],
            "Israel": ["zh": "以色列", "en": "Israel"],
            "Jordan": ["zh": "约旦", "en": "Jordan"],
            "Qatar": ["zh": "卡塔尔", "en": "Qatar"],
            "Malaysia": ["zh": "马来西亚", "en": "Malaysia"],
            "Indonesia": ["zh": "印度尼西亚", "en": "Indonesia"],
            "Philippines": ["zh": "菲律宾", "en": "Philippines"],
            "Sri Lanka": ["zh": "斯里兰卡", "en": "Sri Lanka"],
            "Nepal": ["zh": "尼泊尔", "en": "Nepal"],
            "Norway": ["zh": "挪威", "en": "Norway"]
        ]
        
        return countryMappings[country]?[language] ?? country
    }
}

/// 城市数据管理器 - 集中管理预设城市数据，支持多语言
class CityDataManager {
    
    /// 单例实例
    static let shared = CityDataManager()
    
    /// 私有初始化，确保单例
    private init() {}
    
    /// 预设国际城市数据（多语言支持）
    /// 参考 iPhone 地图应用的国际城市数据，手动维护热门目的地
    /// 解决在中国无法搜索国外地点的问题
    private let internationalCities: [String: CityInfo] = [
        // 欧洲城市
        "london": CityInfo(englishName: "London", chineseName: "伦敦", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278),
        "伦敦": CityInfo(englishName: "London", chineseName: "伦敦", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278),
        
        "paris": CityInfo(englishName: "Paris", chineseName: "巴黎", country: "France", latitude: 48.8566, longitude: 2.3522),
        "巴黎": CityInfo(englishName: "Paris", chineseName: "巴黎", country: "France", latitude: 48.8566, longitude: 2.3522),
        
        "rome": CityInfo(englishName: "Rome", chineseName: "罗马", country: "Italy", latitude: 41.9028, longitude: 12.4964),
        "罗马": CityInfo(englishName: "Rome", chineseName: "罗马", country: "Italy", latitude: 41.9028, longitude: 12.4964),
        
        "barcelona": CityInfo(englishName: "Barcelona", chineseName: "巴塞罗那", country: "Spain", latitude: 41.3851, longitude: 2.1734),
        "巴塞罗那": CityInfo(englishName: "Barcelona", chineseName: "巴塞罗那", country: "Spain", latitude: 41.3851, longitude: 2.1734),
        
        "amsterdam": CityInfo(englishName: "Amsterdam", chineseName: "阿姆斯特丹", country: "Netherlands", latitude: 52.3676, longitude: 4.9041),
        "阿姆斯特丹": CityInfo(englishName: "Amsterdam", chineseName: "阿姆斯特丹", country: "Netherlands", latitude: 52.3676, longitude: 4.9041),
        
        "moscow": CityInfo(englishName: "Moscow", chineseName: "莫斯科", country: "Russia", latitude: 55.7558, longitude: 37.6173),
        "莫斯科": CityInfo(englishName: "Moscow", chineseName: "莫斯科", country: "Russia", latitude: 55.7558, longitude: 37.6173),
        
        // 亚洲城市
        "tokyo": CityInfo(englishName: "Tokyo", chineseName: "东京", country: "Japan", latitude: 35.6762, longitude: 139.6503),
        "东京": CityInfo(englishName: "Tokyo", chineseName: "东京", country: "Japan", latitude: 35.6762, longitude: 139.6503),
        
        "seoul": CityInfo(englishName: "Seoul", chineseName: "首尔", country: "South Korea", latitude: 37.5665, longitude: 126.9780),
        "首尔": CityInfo(englishName: "Seoul", chineseName: "首尔", country: "South Korea", latitude: 37.5665, longitude: 126.9780),
        
        "singapore": CityInfo(englishName: "Singapore", chineseName: "新加坡", country: "Singapore", latitude: 1.3521, longitude: 103.8198),
        "新加坡": CityInfo(englishName: "Singapore", chineseName: "新加坡", country: "Singapore", latitude: 1.3521, longitude: 103.8198),
        
        "bangkok": CityInfo(englishName: "Bangkok", chineseName: "曼谷", country: "Thailand", latitude: 13.7563, longitude: 100.5018),
        "曼谷": CityInfo(englishName: "Bangkok", chineseName: "曼谷", country: "Thailand", latitude: 13.7563, longitude: 100.5018),
        
        // 美洲城市
        "newyork": CityInfo(englishName: "New York", chineseName: "纽约", country: "United States", latitude: 40.7128, longitude: -74.0060),
        "纽约": CityInfo(englishName: "New York", chineseName: "纽约", country: "United States", latitude: 40.7128, longitude: -74.0060),
        
        "losangeles": CityInfo(englishName: "Los Angeles", chineseName: "洛杉矶", country: "United States", latitude: 34.0522, longitude: -118.2437),
        "洛杉矶": CityInfo(englishName: "Los Angeles", chineseName: "洛杉矶", country: "United States", latitude: 34.0522, longitude: -118.2437),
        
        // 大洋洲城市
        "sydney": CityInfo(englishName: "Sydney", chineseName: "悉尼", country: "Australia", latitude: -33.8688, longitude: 151.2093),
        "悉尼": CityInfo(englishName: "Sydney", chineseName: "悉尼", country: "Australia", latitude: -33.8688, longitude: 151.2093),
        
        // 中东城市
        "dubai": CityInfo(englishName: "Dubai", chineseName: "迪拜", country: "United Arab Emirates", latitude: 25.2048, longitude: 55.2708),
        "迪拜": CityInfo(englishName: "Dubai", chineseName: "迪拜", country: "United Arab Emirates", latitude: 25.2048, longitude: 55.2708),
        
        // 新增欧洲城市
        "madrid": CityInfo(englishName: "Madrid", chineseName: "马德里", country: "Spain", latitude: 40.4168, longitude: -3.7038),
        "马德里": CityInfo(englishName: "Madrid", chineseName: "马德里", country: "Spain", latitude: 40.4168, longitude: -3.7038),
        
        "seville": CityInfo(englishName: "Seville", chineseName: "塞维利亚", country: "Spain", latitude: 37.3891, longitude: -5.9845),
        "塞维利亚": CityInfo(englishName: "Seville", chineseName: "塞维利亚", country: "Spain", latitude: 37.3891, longitude: -5.9845),
        
        "valencia": CityInfo(englishName: "Valencia", chineseName: "瓦伦西亚", country: "Spain", latitude: 39.4699, longitude: -0.3763),
        "瓦伦西亚": CityInfo(englishName: "Valencia", chineseName: "瓦伦西亚", country: "Spain", latitude: 39.4699, longitude: -0.3763),
        
        "florence": CityInfo(englishName: "Florence", chineseName: "佛罗伦萨", country: "Italy", latitude: 43.7696, longitude: 11.2558),
        "佛罗伦萨": CityInfo(englishName: "Florence", chineseName: "佛罗伦萨", country: "Italy", latitude: 43.7696, longitude: 11.2558),
        
        "venice": CityInfo(englishName: "Venice", chineseName: "威尼斯", country: "Italy", latitude: 45.4408, longitude: 12.3155),
        "威尼斯": CityInfo(englishName: "Venice", chineseName: "威尼斯", country: "Italy", latitude: 45.4408, longitude: 12.3155),
        
        "milan": CityInfo(englishName: "Milan", chineseName: "米兰", country: "Italy", latitude: 45.4642, longitude: 9.1900),
        "米兰": CityInfo(englishName: "Milan", chineseName: "米兰", country: "Italy", latitude: 45.4642, longitude: 9.1900),
        
        "istanbul": CityInfo(englishName: "Istanbul", chineseName: "伊斯坦布尔", country: "Turkey", latitude: 41.0082, longitude: 28.9784),
        "伊斯坦布尔": CityInfo(englishName: "Istanbul", chineseName: "伊斯坦布尔", country: "Turkey", latitude: 41.0082, longitude: 28.9784),
        
        "ankara": CityInfo(englishName: "Ankara", chineseName: "安卡拉", country: "Turkey", latitude: 39.9334, longitude: 32.8597),
        "安卡拉": CityInfo(englishName: "Ankara", chineseName: "安卡拉", country: "Turkey", latitude: 39.9334, longitude: 32.8597),
        
        "antalya": CityInfo(englishName: "Antalya", chineseName: "安塔利亚", country: "Turkey", latitude: 36.8969, longitude: 30.7133),
        "安塔利亚": CityInfo(englishName: "Antalya", chineseName: "安塔利亚", country: "Turkey", latitude: 36.8969, longitude: 30.7133),
        
        "izmir": CityInfo(englishName: "Izmir", chineseName: "伊兹密尔", country: "Turkey", latitude: 38.4192, longitude: 27.1287),
        "伊兹密尔": CityInfo(englishName: "Izmir", chineseName: "伊兹密尔", country: "Turkey", latitude: 38.4192, longitude: 27.1287),
        
        "berlin": CityInfo(englishName: "Berlin", chineseName: "柏林", country: "Germany", latitude: 52.5200, longitude: 13.4050),
        "柏林": CityInfo(englishName: "Berlin", chineseName: "柏林", country: "Germany", latitude: 52.5200, longitude: 13.4050),
        
        "munich": CityInfo(englishName: "Munich", chineseName: "慕尼黑", country: "Germany", latitude: 48.1351, longitude: 11.5820),
        "慕尼黑": CityInfo(englishName: "Munich", chineseName: "慕尼黑", country: "Germany", latitude: 48.1351, longitude: 11.5820),
        
        "hamburg": CityInfo(englishName: "Hamburg", chineseName: "汉堡", country: "Germany", latitude: 53.5511, longitude: 9.9937),
        "汉堡": CityInfo(englishName: "Hamburg", chineseName: "汉堡", country: "Germany", latitude: 53.5511, longitude: 9.9937),
        
        "cologne": CityInfo(englishName: "Cologne", chineseName: "科隆", country: "Germany", latitude: 50.9375, longitude: 6.9603),
        "科隆": CityInfo(englishName: "Cologne", chineseName: "科隆", country: "Germany", latitude: 50.9375, longitude: 6.9603),
        
        "athens": CityInfo(englishName: "Athens", chineseName: "雅典", country: "Greece", latitude: 37.9755, longitude: 23.7348),
        "雅典": CityInfo(englishName: "Athens", chineseName: "雅典", country: "Greece", latitude: 37.9755, longitude: 23.7348),
        
        "santorini": CityInfo(englishName: "Santorini", chineseName: "圣托里尼", country: "Greece", latitude: 36.3932, longitude: 25.4615),
        "圣托里尼": CityInfo(englishName: "Santorini", chineseName: "圣托里尼", country: "Greece", latitude: 36.3932, longitude: 25.4615),
        
        "thessaloniki": CityInfo(englishName: "Thessaloniki", chineseName: "塞萨洛尼基", country: "Greece", latitude: 40.6401, longitude: 22.9444),
        "塞萨洛尼基": CityInfo(englishName: "Thessaloniki", chineseName: "塞萨洛尼基", country: "Greece", latitude: 40.6401, longitude: 22.9444),
        
        "rhodes": CityInfo(englishName: "Rhodes", chineseName: "罗德岛", country: "Greece", latitude: 36.4412, longitude: 28.2225),
        "罗德岛": CityInfo(englishName: "Rhodes", chineseName: "罗德岛", country: "Greece", latitude: 36.4412, longitude: 28.2225),
        
        "vienna": CityInfo(englishName: "Vienna", chineseName: "维也纳", country: "Austria", latitude: 48.2082, longitude: 16.3738),
        "维也纳": CityInfo(englishName: "Vienna", chineseName: "维也纳", country: "Austria", latitude: 48.2082, longitude: 16.3738),
        
        "salzburg": CityInfo(englishName: "Salzburg", chineseName: "萨尔茨堡", country: "Austria", latitude: 47.8095, longitude: 13.0550),
        "萨尔茨堡": CityInfo(englishName: "Salzburg", chineseName: "萨尔茨堡", country: "Austria", latitude: 47.8095, longitude: 13.0550),
        
        "innsbruck": CityInfo(englishName: "Innsbruck", chineseName: "因斯布鲁克", country: "Austria", latitude: 47.2692, longitude: 11.4041),
        "因斯布鲁克": CityInfo(englishName: "Innsbruck", chineseName: "因斯布鲁克", country: "Austria", latitude: 47.2692, longitude: 11.4041),
        
        "graz": CityInfo(englishName: "Graz", chineseName: "格拉茨", country: "Austria", latitude: 47.0707, longitude: 15.4395),
        "格拉茨": CityInfo(englishName: "Graz", chineseName: "格拉茨", country: "Austria", latitude: 47.0707, longitude: 15.4395),
        
        "rotterdam": CityInfo(englishName: "Rotterdam", chineseName: "鹿特丹", country: "Netherlands", latitude: 51.9244, longitude: 4.4777),
        "鹿特丹": CityInfo(englishName: "Rotterdam", chineseName: "鹿特丹", country: "Netherlands", latitude: 51.9244, longitude: 4.4777),
        
        "utrecht": CityInfo(englishName: "Utrecht", chineseName: "乌得勒支", country: "Netherlands", latitude: 52.0907, longitude: 5.1214),
        "乌得勒支": CityInfo(englishName: "Utrecht", chineseName: "乌得勒支", country: "Netherlands", latitude: 52.0907, longitude: 5.1214),
        
        "thehague": CityInfo(englishName: "The Hague", chineseName: "海牙", country: "Netherlands", latitude: 52.0705, longitude: 4.3007),
        "海牙": CityInfo(englishName: "The Hague", chineseName: "海牙", country: "Netherlands", latitude: 52.0705, longitude: 4.3007),
        
        "reykjavik": CityInfo(englishName: "Reykjavik", chineseName: "雷克雅未克", country: "Iceland", latitude: 64.1466, longitude: -21.9426),
        "雷克雅未克": CityInfo(englishName: "Reykjavik", chineseName: "雷克雅未克", country: "Iceland", latitude: 64.1466, longitude: -21.9426),
        
        "vik": CityInfo(englishName: "Vik", chineseName: "维克", country: "Iceland", latitude: 63.4194, longitude: -19.0078),
        "维克": CityInfo(englishName: "Vik", chineseName: "维克", country: "Iceland", latitude: 63.4194, longitude: -19.0078),
        
        "akureyri": CityInfo(englishName: "Akureyri", chineseName: "阿克雷里", country: "Iceland", latitude: 65.6850, longitude: -18.0906),
        "阿克雷里": CityInfo(englishName: "Akureyri", chineseName: "阿克雷里", country: "Iceland", latitude: 65.6850, longitude: -18.0906),
        
        "hofn": CityInfo(englishName: "Höfn", chineseName: "赫本", country: "Iceland", latitude: 64.2539, longitude: -15.2089),
        "赫本": CityInfo(englishName: "Höfn", chineseName: "赫本", country: "Iceland", latitude: 64.2539, longitude: -15.2089),
        
        "dublin": CityInfo(englishName: "Dublin", chineseName: "都柏林", country: "Ireland", latitude: 53.3498, longitude: -6.2603),
        "都柏林": CityInfo(englishName: "Dublin", chineseName: "都柏林", country: "Ireland", latitude: 53.3498, longitude: -6.2603),
        
        "galway": CityInfo(englishName: "Galway", chineseName: "戈尔韦", country: "Ireland", latitude: 53.2707, longitude: -9.0568),
        "戈尔韦": CityInfo(englishName: "Galway", chineseName: "戈尔韦", country: "Ireland", latitude: 53.2707, longitude: -9.0568),
        
        "cork": CityInfo(englishName: "Cork", chineseName: "科克", country: "Ireland", latitude: 51.8985, longitude: -8.4756),
        "科克": CityInfo(englishName: "Cork", chineseName: "科克", country: "Ireland", latitude: 51.8985, longitude: -8.4756),
        
        "killarney": CityInfo(englishName: "Killarney", chineseName: "基拉尼", country: "Ireland", latitude: 52.0599, longitude: -9.5044),
        "基拉尼": CityInfo(englishName: "Killarney", chineseName: "基拉尼", country: "Ireland", latitude: 52.0599, longitude: -9.5044),
        
        "edinburgh": CityInfo(englishName: "Edinburgh", chineseName: "爱丁堡", country: "United Kingdom", latitude: 55.9533, longitude: -3.1883),
        "爱丁堡": CityInfo(englishName: "Edinburgh", chineseName: "爱丁堡", country: "United Kingdom", latitude: 55.9533, longitude: -3.1883),
        
        "manchester": CityInfo(englishName: "Manchester", chineseName: "曼彻斯特", country: "United Kingdom", latitude: 53.4808, longitude: -2.2426),
        "曼彻斯特": CityInfo(englishName: "Manchester", chineseName: "曼彻斯特", country: "United Kingdom", latitude: 53.4808, longitude: -2.2426),
        
        "liverpool": CityInfo(englishName: "Liverpool", chineseName: "利物浦", country: "United Kingdom", latitude: 53.4084, longitude: -2.9916),
        "利物浦": CityInfo(englishName: "Liverpool", chineseName: "利物浦", country: "United Kingdom", latitude: 53.4084, longitude: -2.9916),
        
        "washington": CityInfo(englishName: "Washington D.C.", chineseName: "华盛顿哥伦比亚特区", country: "United States", latitude: 38.9072, longitude: -77.0369),
        "华盛顿哥伦比亚特区": CityInfo(englishName: "Washington D.C.", chineseName: "华盛顿哥伦比亚特区", country: "United States", latitude: 38.9072, longitude: -77.0369),
        
        "lasvegas": CityInfo(englishName: "Las Vegas", chineseName: "拉斯维加斯", country: "United States", latitude: 36.1699, longitude: -115.1398),
        "拉斯维加斯": CityInfo(englishName: "Las Vegas", chineseName: "拉斯维加斯", country: "United States", latitude: 36.1699, longitude: -115.1398),
        
        "cancun": CityInfo(englishName: "Cancun", chineseName: "坎昆", country: "Mexico", latitude: 21.1619, longitude: -86.8515),
        "坎昆": CityInfo(englishName: "Cancun", chineseName: "坎昆", country: "Mexico", latitude: 21.1619, longitude: -86.8515),
        
        "guadalajara": CityInfo(englishName: "Guadalajara", chineseName: "瓜达拉哈拉", country: "Mexico", latitude: 20.6597, longitude: -103.3496),
        "瓜达拉哈拉": CityInfo(englishName: "Guadalajara", chineseName: "瓜达拉哈拉", country: "Mexico", latitude: 20.6597, longitude: -103.3496),
        
        "monterrey": CityInfo(englishName: "Monterrey", chineseName: "蒙特雷", country: "Mexico", latitude: 25.6866, longitude: -100.3161),
        "蒙特雷": CityInfo(englishName: "Monterrey", chineseName: "蒙特雷", country: "Mexico", latitude: 25.6866, longitude: -100.3161),
        
        "mexicocity": CityInfo(englishName: "Mexico City", chineseName: "墨西哥城", country: "Mexico", latitude: 19.4326, longitude: -99.1332),
        "墨西哥城": CityInfo(englishName: "Mexico City", chineseName: "墨西哥城", country: "Mexico", latitude: 19.4326, longitude: -99.1332),
        
        "toronto": CityInfo(englishName: "Toronto", chineseName: "多伦多", country: "Canada", latitude: 43.6532, longitude: -79.3832),
        "多伦多": CityInfo(englishName: "Toronto", chineseName: "多伦多", country: "Canada", latitude: 43.6532, longitude: -79.3832),
        
        "vancouver": CityInfo(englishName: "Vancouver", chineseName: "温哥华", country: "Canada", latitude: 49.2827, longitude: -123.1207),
        "温哥华": CityInfo(englishName: "Vancouver", chineseName: "温哥华", country: "Canada", latitude: 49.2827, longitude: -123.1207),
        
        "montreal": CityInfo(englishName: "Montreal", chineseName: "蒙特利尔", country: "Canada", latitude: 45.5017, longitude: -73.5673),
        "蒙特利尔": CityInfo(englishName: "Montreal", chineseName: "蒙特利尔", country: "Canada", latitude: 45.5017, longitude: -73.5673),
        
        "ottawa": CityInfo(englishName: "Ottawa", chineseName: "渥太华", country: "Canada", latitude: 45.4215, longitude: -75.6972),
        "渥太华": CityInfo(englishName: "Ottawa", chineseName: "渥太华", country: "Canada", latitude: 45.4215, longitude: -75.6972),
        
        "hanoi": CityInfo(englishName: "Hanoi", chineseName: "河内", country: "Vietnam", latitude: 21.0285, longitude: 105.8542),
        "河内": CityInfo(englishName: "Hanoi", chineseName: "河内", country: "Vietnam", latitude: 21.0285, longitude: 105.8542),
        
        "hochiminhcity": CityInfo(englishName: "Ho Chi Minh City", chineseName: "胡志明市", country: "Vietnam", latitude: 10.8231, longitude: 106.6297),
        "胡志明市": CityInfo(englishName: "Ho Chi Minh City", chineseName: "胡志明市", country: "Vietnam", latitude: 10.8231, longitude: 106.6297),
        
        "danang": CityInfo(englishName: "Da Nang", chineseName: "岘港", country: "Vietnam", latitude: 16.0544, longitude: 108.2022),
        "岘港": CityInfo(englishName: "Da Nang", chineseName: "岘港", country: "Vietnam", latitude: 16.0544, longitude: 108.2022),
        
        "halongcity": CityInfo(englishName: "Ha Long City", chineseName: "下龙市", country: "Vietnam", latitude: 20.9101, longitude: 107.1839),
        "下龙市": CityInfo(englishName: "Ha Long City", chineseName: "下龙市", country: "Vietnam", latitude: 20.9101, longitude: 107.1839),
        
        "luxor": CityInfo(englishName: "Luxor", chineseName: "卢克索", country: "Egypt", latitude: 25.6872, longitude: 32.6396),
        "卢克索": CityInfo(englishName: "Luxor", chineseName: "卢克索", country: "Egypt", latitude: 25.6872, longitude: 32.6396),
        
        "alexandria": CityInfo(englishName: "Alexandria", chineseName: "亚历山大", country: "Egypt", latitude: 31.2001, longitude: 29.9187),
        "亚历山大": CityInfo(englishName: "Alexandria", chineseName: "亚历山大", country: "Egypt", latitude: 31.2001, longitude: 29.9187),
        
        "sharmelsheikh": CityInfo(englishName: "Sharm El Sheikh", chineseName: "沙姆沙伊赫", country: "Egypt", latitude: 27.9158, longitude: 34.3300),
        "沙姆沙伊赫": CityInfo(englishName: "Sharm El Sheikh", chineseName: "沙姆沙伊赫", country: "Egypt", latitude: 27.9158, longitude: 34.3300),
        
        "cairo": CityInfo(englishName: "Cairo", chineseName: "开罗", country: "Egypt", latitude: 30.0444, longitude: 31.2357),
        "开罗": CityInfo(englishName: "Cairo", chineseName: "开罗", country: "Egypt", latitude: 30.0444, longitude: 31.2357),
        
        "brasilia": CityInfo(englishName: "Brasília", chineseName: "巴西利亚", country: "Brazil", latitude: -15.7801, longitude: -47.9292),
        "巴西利亚": CityInfo(englishName: "Brasília", chineseName: "巴西利亚", country: "Brazil", latitude: -15.7801, longitude: -47.9292),
        
        "riodejaneiro": CityInfo(englishName: "Rio de Janeiro", chineseName: "里约热内卢", country: "Brazil", latitude: -22.9068, longitude: -43.1729),
        "里约热内卢": CityInfo(englishName: "Rio de Janeiro", chineseName: "里约热内卢", country: "Brazil", latitude: -22.9068, longitude: -43.1729),
        
        "saopaulo": CityInfo(englishName: "São Paulo", chineseName: "圣保罗", country: "Brazil", latitude: -23.5505, longitude: -46.6333),
        "圣保罗": CityInfo(englishName: "São Paulo", chineseName: "圣保罗", country: "Brazil", latitude: -23.5505, longitude: -46.6333),
        
        "salvador": CityInfo(englishName: "Salvador", chineseName: "萨尔瓦多", country: "Brazil", latitude: -12.9714, longitude: -38.5014),
        "萨尔瓦多": CityInfo(englishName: "Salvador", chineseName: "萨尔瓦多", country: "Brazil", latitude: -12.9714, longitude: -38.5014),
        
        "lisbon": CityInfo(englishName: "Lisbon", chineseName: "里斯本", country: "Portugal", latitude: 38.7223, longitude: -9.1393),
        "里斯本": CityInfo(englishName: "Lisbon", chineseName: "里斯本", country: "Portugal", latitude: 38.7223, longitude: -9.1393),
        
        "porto": CityInfo(englishName: "Porto", chineseName: "波尔图", country: "Portugal", latitude: 41.1579, longitude: -8.6291),
        "波尔图": CityInfo(englishName: "Porto", chineseName: "波尔图", country: "Portugal", latitude: 41.1579, longitude: -8.6291),
        
        "faro": CityInfo(englishName: "Faro", chineseName: "法鲁", country: "Portugal", latitude: 37.0194, longitude: -7.9322),
        "法鲁": CityInfo(englishName: "Faro", chineseName: "法鲁", country: "Portugal", latitude: 37.0194, longitude: -7.9322),
        
        "sintra": CityInfo(englishName: "Sintra", chineseName: "辛特拉", country: "Portugal", latitude: 38.8029, longitude: -9.3817),
        "辛特拉": CityInfo(englishName: "Sintra", chineseName: "辛特拉", country: "Portugal", latitude: 38.8029, longitude: -9.3817),
        
        "wellington": CityInfo(englishName: "Wellington", chineseName: "惠灵顿", country: "New Zealand", latitude: -41.2924, longitude: 174.7787),
        "惠灵顿": CityInfo(englishName: "Wellington", chineseName: "惠灵顿", country: "New Zealand", latitude: -41.2924, longitude: 174.7787),
        
        "auckland": CityInfo(englishName: "Auckland", chineseName: "奥克兰", country: "New Zealand", latitude: -36.8485, longitude: 174.7633),
        "奥克兰": CityInfo(englishName: "Auckland", chineseName: "奥克兰", country: "New Zealand", latitude: -36.8485, longitude: 174.7633),
        
        "queenstown": CityInfo(englishName: "Queenstown", chineseName: "皇后镇", country: "New Zealand", latitude: -45.0312, longitude: 168.6626),
        "皇后镇": CityInfo(englishName: "Queenstown", chineseName: "皇后镇", country: "New Zealand", latitude: -45.0312, longitude: 168.6626),
        
        "christchurch": CityInfo(englishName: "Christchurch", chineseName: "基督城", country: "New Zealand", latitude: -43.5321, longitude: 172.6362),
        "基督城": CityInfo(englishName: "Christchurch", chineseName: "基督城", country: "New Zealand", latitude: -43.5321, longitude: 172.6362),
        
        "canberra": CityInfo(englishName: "Canberra", chineseName: "堪培拉", country: "Australia", latitude: -35.2809, longitude: 149.1300),
        "堪培拉": CityInfo(englishName: "Canberra", chineseName: "堪培拉", country: "Australia", latitude: -35.2809, longitude: 149.1300),
        
        "melbourne": CityInfo(englishName: "Melbourne", chineseName: "墨尔本", country: "Australia", latitude: -37.8136, longitude: 144.9631),
        "墨尔本": CityInfo(englishName: "Melbourne", chineseName: "墨尔本", country: "Australia", latitude: -37.8136, longitude: 144.9631),
        
        "brisbane": CityInfo(englishName: "Brisbane", chineseName: "布里斯班", country: "Australia", latitude: -27.4698, longitude: 153.0251),
        "布里斯班": CityInfo(englishName: "Brisbane", chineseName: "布里斯班", country: "Australia", latitude: -27.4698, longitude: 153.0251),
        
        "abudhabi": CityInfo(englishName: "Abu Dhabi", chineseName: "阿布扎比", country: "United Arab Emirates", latitude: 24.2992, longitude: 54.6973),
        "阿布扎比": CityInfo(englishName: "Abu Dhabi", chineseName: "阿布扎比", country: "United Arab Emirates", latitude: 24.2992, longitude: 54.6973),
        
        "sharjah": CityInfo(englishName: "Sharjah", chineseName: "沙迦", country: "United Arab Emirates", latitude: 25.3573, longitude: 55.4033),
        "沙迦": CityInfo(englishName: "Sharjah", chineseName: "沙迦", country: "United Arab Emirates", latitude: 25.3573, longitude: 55.4033),
        
        "alain": CityInfo(englishName: "Al Ain", chineseName: "艾因", country: "United Arab Emirates", latitude: 24.2075, longitude: 55.7447),
        "艾因": CityInfo(englishName: "Al Ain", chineseName: "艾因", country: "United Arab Emirates", latitude: 24.2075, longitude: 55.7447),
        
        "newdelhi": CityInfo(englishName: "New Delhi", chineseName: "新德里", country: "India", latitude: 28.6139, longitude: 77.2090),
        "新德里": CityInfo(englishName: "New Delhi", chineseName: "新德里", country: "India", latitude: 28.6139, longitude: 77.2090),
        
        "mumbai": CityInfo(englishName: "Mumbai", chineseName: "孟买", country: "India", latitude: 19.0760, longitude: 72.8777),
        "孟买": CityInfo(englishName: "Mumbai", chineseName: "孟买", country: "India", latitude: 19.0760, longitude: 72.8777),
        
        "jaipur": CityInfo(englishName: "Jaipur", chineseName: "斋浦尔", country: "India", latitude: 26.9124, longitude: 75.7873),
        "斋浦尔": CityInfo(englishName: "Jaipur", chineseName: "斋浦尔", country: "India", latitude: 26.9124, longitude: 75.7873),
        
        "goa": CityInfo(englishName: "Goa", chineseName: "果阿", country: "India", latitude: 15.2993, longitude: 74.1240),
        "果阿": CityInfo(englishName: "Goa", chineseName: "果阿", country: "India", latitude: 15.2993, longitude: 74.1240),
        
        "kyoto": CityInfo(englishName: "Kyoto", chineseName: "京都", country: "Japan", latitude: 35.0116, longitude: 135.7681),
        "京都": CityInfo(englishName: "Kyoto", chineseName: "京都", country: "Japan", latitude: 35.0116, longitude: 135.7681),
        
        "osaka": CityInfo(englishName: "Osaka", chineseName: "大阪", country: "Japan", latitude: 34.6937, longitude: 135.5023),
        "大阪": CityInfo(englishName: "Osaka", chineseName: "大阪", country: "Japan", latitude: 34.6937, longitude: 135.5023),
        
        "sapporo": CityInfo(englishName: "Sapporo", chineseName: "札幌", country: "Japan", latitude: 43.0642, longitude: 141.3469),
        "札幌": CityInfo(englishName: "Sapporo", chineseName: "札幌", country: "Japan", latitude: 43.0642, longitude: 141.3469),
        
        "busan": CityInfo(englishName: "Busan", chineseName: "釜山", country: "South Korea", latitude: 35.1796, longitude: 129.0756),
        "釜山": CityInfo(englishName: "Busan", chineseName: "釜山", country: "South Korea", latitude: 35.1796, longitude: 129.0756),
        
        "jejuisland": CityInfo(englishName: "Jeju Island", chineseName: "济州岛", country: "South Korea", latitude: 33.4996, longitude: 126.5312),
        "济州岛": CityInfo(englishName: "Jeju Island", chineseName: "济州岛", country: "South Korea", latitude: 33.4996, longitude: 126.5312),
        
        "incheon": CityInfo(englishName: "Incheon", chineseName: "仁川", country: "South Korea", latitude: 37.4563, longitude: 126.7052),
        "仁川": CityInfo(englishName: "Incheon", chineseName: "仁川", country: "South Korea", latitude: 37.4563, longitude: 126.7052),
        
        "chiangmai": CityInfo(englishName: "Chiang Mai", chineseName: "清迈", country: "Thailand", latitude: 18.7883, longitude: 98.9853),
        "清迈": CityInfo(englishName: "Chiang Mai", chineseName: "清迈", country: "Thailand", latitude: 18.7883, longitude: 98.9853),
        
        "phuket": CityInfo(englishName: "Phuket", chineseName: "普吉岛", country: "Thailand", latitude: 7.8804, longitude: 98.3923),
        "普吉岛": CityInfo(englishName: "Phuket", chineseName: "普吉岛", country: "Thailand", latitude: 7.8804, longitude: 98.3923),
        
        "pattaya": CityInfo(englishName: "Pattaya", chineseName: "芭堤雅", country: "Thailand", latitude: 12.9236, longitude: 100.8825),
        "芭堤雅": CityInfo(englishName: "Pattaya", chineseName: "芭堤雅", country: "Thailand", latitude: 12.9236, longitude: 100.8825),
        
        // 第二张表格的更多国家城市
        // 瑞士
        "bern": CityInfo(englishName: "Bern", chineseName: "伯尔尼", country: "Switzerland", latitude: 46.9481, longitude: 7.4474),
        "伯尔尼": CityInfo(englishName: "Bern", chineseName: "伯尔尼", country: "Switzerland", latitude: 46.9481, longitude: 7.4474),
        
        "zurich": CityInfo(englishName: "Zurich", chineseName: "苏黎世", country: "Switzerland", latitude: 47.3769, longitude: 8.5417),
        "苏黎世": CityInfo(englishName: "Zurich", chineseName: "苏黎世", country: "Switzerland", latitude: 47.3769, longitude: 8.5417),
        
        "geneva": CityInfo(englishName: "Geneva", chineseName: "日内瓦", country: "Switzerland", latitude: 46.2044, longitude: 6.1432),
        "日内瓦": CityInfo(englishName: "Geneva", chineseName: "日内瓦", country: "Switzerland", latitude: 46.2044, longitude: 6.1432),
        
        "interlaken": CityInfo(englishName: "Interlaken", chineseName: "因特拉肯", country: "Switzerland", latitude: 46.6863, longitude: 7.8632),
        "因特拉肯": CityInfo(englishName: "Interlaken", chineseName: "因特拉肯", country: "Switzerland", latitude: 46.6863, longitude: 7.8632),
        
        // 比利时
        "brussels": CityInfo(englishName: "Brussels", chineseName: "布鲁塞尔", country: "Belgium", latitude: 50.8503, longitude: 4.3517),
        "布鲁塞尔": CityInfo(englishName: "Brussels", chineseName: "布鲁塞尔", country: "Belgium", latitude: 50.8503, longitude: 4.3517),
        
        "bruges": CityInfo(englishName: "Bruges", chineseName: "布鲁日", country: "Belgium", latitude: 51.2093, longitude: 3.2247),
        "布鲁日": CityInfo(englishName: "Bruges", chineseName: "布鲁日", country: "Belgium", latitude: 51.2093, longitude: 3.2247),
        
        "antwerp": CityInfo(englishName: "Antwerp", chineseName: "安特卫普", country: "Belgium", latitude: 51.2194, longitude: 4.4025),
        "安特卫普": CityInfo(englishName: "Antwerp", chineseName: "安特卫普", country: "Belgium", latitude: 51.2194, longitude: 4.4025),
        
        "ghent": CityInfo(englishName: "Ghent", chineseName: "根特", country: "Belgium", latitude: 51.0543, longitude: 3.7174),
        "根特": CityInfo(englishName: "Ghent", chineseName: "根特", country: "Belgium", latitude: 51.0543, longitude: 3.7174),
        
        // 捷克共和国
        "prague": CityInfo(englishName: "Prague", chineseName: "布拉格", country: "Czech Republic", latitude: 50.0755, longitude: 14.4378),
        "布拉格": CityInfo(englishName: "Prague", chineseName: "布拉格", country: "Czech Republic", latitude: 50.0755, longitude: 14.4378),
        
        "ceskykrumlov": CityInfo(englishName: "Český Krumlov", chineseName: "克鲁姆洛夫", country: "Czech Republic", latitude: 48.8106, longitude: 14.3152),
        "克鲁姆洛夫": CityInfo(englishName: "Český Krumlov", chineseName: "克鲁姆洛夫", country: "Czech Republic", latitude: 48.8106, longitude: 14.3152),
        
        "brno": CityInfo(englishName: "Brno", chineseName: "布尔诺", country: "Czech Republic", latitude: 49.1951, longitude: 16.6068),
        "布尔诺": CityInfo(englishName: "Brno", chineseName: "布尔诺", country: "Czech Republic", latitude: 49.1951, longitude: 16.6068),
        
        "karlovyvary": CityInfo(englishName: "Karlovy Vary", chineseName: "卡罗维发利", country: "Czech Republic", latitude: 50.2305, longitude: 12.8711),
        "卡罗维发利": CityInfo(englishName: "Karlovy Vary", chineseName: "卡罗维发利", country: "Czech Republic", latitude: 50.2305, longitude: 12.8711),
        
        // 匈牙利
        "budapest": CityInfo(englishName: "Budapest", chineseName: "布达佩斯", country: "Hungary", latitude: 47.4979, longitude: 19.0402),
        "布达佩斯": CityInfo(englishName: "Budapest", chineseName: "布达佩斯", country: "Hungary", latitude: 47.4979, longitude: 19.0402),
        
        "debrecen": CityInfo(englishName: "Debrecen", chineseName: "德布勒森", country: "Hungary", latitude: 47.5316, longitude: 21.6273),
        "德布勒森": CityInfo(englishName: "Debrecen", chineseName: "德布勒森", country: "Hungary", latitude: 47.5316, longitude: 21.6273),
        
        "szeged": CityInfo(englishName: "Szeged", chineseName: "塞格德", country: "Hungary", latitude: 46.2530, longitude: 20.1414),
        "塞格德": CityInfo(englishName: "Szeged", chineseName: "塞格德", country: "Hungary", latitude: 46.2530, longitude: 20.1414),
        
        "pecs": CityInfo(englishName: "Pécs", chineseName: "佩奇", country: "Hungary", latitude: 46.0727, longitude: 18.2328),
        "佩奇": CityInfo(englishName: "Pécs", chineseName: "佩奇", country: "Hungary", latitude: 46.0727, longitude: 18.2328),
        
        // 波兰
        "warsaw": CityInfo(englishName: "Warsaw", chineseName: "华沙", country: "Poland", latitude: 52.2297, longitude: 21.0122),
        "华沙": CityInfo(englishName: "Warsaw", chineseName: "华沙", country: "Poland", latitude: 52.2297, longitude: 21.0122),
        
        "krakow": CityInfo(englishName: "Kraków", chineseName: "克拉科夫", country: "Poland", latitude: 50.0647, longitude: 19.9450),
        "克拉科夫": CityInfo(englishName: "Kraków", chineseName: "克拉科夫", country: "Poland", latitude: 50.0647, longitude: 19.9450),
        
        "gdansk": CityInfo(englishName: "Gdańsk", chineseName: "格但斯克", country: "Poland", latitude: 54.3520, longitude: 18.6466),
        "格但斯克": CityInfo(englishName: "Gdańsk", chineseName: "格但斯克", country: "Poland", latitude: 54.3520, longitude: 18.6466),
        
        "wroclaw": CityInfo(englishName: "Wrocław", chineseName: "弗罗茨瓦夫", country: "Poland", latitude: 51.1079, longitude: 17.0385),
        "弗罗茨瓦夫": CityInfo(englishName: "Wrocław", chineseName: "弗罗茨瓦夫", country: "Poland", latitude: 51.1079, longitude: 17.0385),
        
        // 克罗地亚
        "zagreb": CityInfo(englishName: "Zagreb", chineseName: "萨格勒布", country: "Croatia", latitude: 45.8150, longitude: 15.9819),
        "萨格勒布": CityInfo(englishName: "Zagreb", chineseName: "萨格勒布", country: "Croatia", latitude: 45.8150, longitude: 15.9819),
        
        "dubrovnik": CityInfo(englishName: "Dubrovnik", chineseName: "杜布罗夫尼克", country: "Croatia", latitude: 42.6507, longitude: 18.0944),
        "杜布罗夫尼克": CityInfo(englishName: "Dubrovnik", chineseName: "杜布罗夫尼克", country: "Croatia", latitude: 42.6507, longitude: 18.0944),
        
        "split": CityInfo(englishName: "Split", chineseName: "斯普利特", country: "Croatia", latitude: 43.5081, longitude: 16.4402),
        "斯普利特": CityInfo(englishName: "Split", chineseName: "斯普利特", country: "Croatia", latitude: 43.5081, longitude: 16.4402),
        
        "zadar": CityInfo(englishName: "Zadar", chineseName: "扎达尔", country: "Croatia", latitude: 44.1194, longitude: 15.2314),
        "扎达尔": CityInfo(englishName: "Zadar", chineseName: "扎达尔", country: "Croatia", latitude: 44.1194, longitude: 15.2314),
        
        // 阿根廷
        "buenosaires": CityInfo(englishName: "Buenos Aires", chineseName: "布宜诺斯艾利斯", country: "Argentina", latitude: -34.6118, longitude: -58.3960),
        "布宜诺斯艾利斯": CityInfo(englishName: "Buenos Aires", chineseName: "布宜诺斯艾利斯", country: "Argentina", latitude: -34.6118, longitude: -58.3960),
        
        "bariloche": CityInfo(englishName: "Bariloche", chineseName: "巴里洛切", country: "Argentina", latitude: -41.1335, longitude: -71.3103),
        "巴里洛切": CityInfo(englishName: "Bariloche", chineseName: "巴里洛切", country: "Argentina", latitude: -41.1335, longitude: -71.3103),
        
        "ushuaia": CityInfo(englishName: "Ushuaia", chineseName: "乌斯怀亚", country: "Argentina", latitude: -54.8019, longitude: -68.3030),
        "乌斯怀亚": CityInfo(englishName: "Ushuaia", chineseName: "乌斯怀亚", country: "Argentina", latitude: -54.8019, longitude: -68.3030),
        
        "mendoza": CityInfo(englishName: "Mendoza", chineseName: "门多萨", country: "Argentina", latitude: -32.8908, longitude: -68.8272),
        "门多萨": CityInfo(englishName: "Mendoza", chineseName: "门多萨", country: "Argentina", latitude: -32.8908, longitude: -68.8272),
        
        // 智利
        "santiago": CityInfo(englishName: "Santiago", chineseName: "圣地亚哥", country: "Chile", latitude: -33.4489, longitude: -70.6693),
        "圣地亚哥": CityInfo(englishName: "Santiago", chineseName: "圣地亚哥", country: "Chile", latitude: -33.4489, longitude: -70.6693),
        
        "easterisland": CityInfo(englishName: "Easter Island", chineseName: "复活节岛", country: "Chile", latitude: -27.1127, longitude: -109.3497),
        "复活节岛": CityInfo(englishName: "Easter Island", chineseName: "复活节岛", country: "Chile", latitude: -27.1127, longitude: -109.3497),
        
        "valparaiso": CityInfo(englishName: "Valparaíso", chineseName: "瓦尔帕莱索", country: "Chile", latitude: -33.0458, longitude: -71.6197),
        "瓦尔帕莱索": CityInfo(englishName: "Valparaíso", chineseName: "瓦尔帕莱索", country: "Chile", latitude: -33.0458, longitude: -71.6197),
        
        "sanpedro": CityInfo(englishName: "San Pedro de Atacama", chineseName: "圣佩德罗-德阿塔卡马", country: "Chile", latitude: -22.9109, longitude: -68.2009),
        "圣佩德罗-德阿塔卡马": CityInfo(englishName: "San Pedro de Atacama", chineseName: "圣佩德罗-德阿塔卡马", country: "Chile", latitude: -22.9109, longitude: -68.2009),
        
        // 秘鲁
        "lima": CityInfo(englishName: "Lima", chineseName: "利马", country: "Peru", latitude: -12.0464, longitude: -77.0428),
        "利马": CityInfo(englishName: "Lima", chineseName: "利马", country: "Peru", latitude: -12.0464, longitude: -77.0428),
        
        "cusco": CityInfo(englishName: "Cusco", chineseName: "库斯科", country: "Peru", latitude: -13.5319, longitude: -71.9675),
        "库斯科": CityInfo(englishName: "Cusco", chineseName: "库斯科", country: "Peru", latitude: -13.5319, longitude: -71.9675),
        
        "arequipa": CityInfo(englishName: "Arequipa", chineseName: "阿雷基帕", country: "Peru", latitude: -16.4090, longitude: -71.5375),
        "阿雷基帕": CityInfo(englishName: "Arequipa", chineseName: "阿雷基帕", country: "Peru", latitude: -16.4090, longitude: -71.5375),
        
        "iquitos": CityInfo(englishName: "Iquitos", chineseName: "伊基托斯", country: "Peru", latitude: -3.7492, longitude: -73.2478),
        "伊基托斯": CityInfo(englishName: "Iquitos", chineseName: "伊基托斯", country: "Peru", latitude: -3.7492, longitude: -73.2478),
        
        // 古巴
        "havana": CityInfo(englishName: "Havana", chineseName: "哈瓦那", country: "Cuba", latitude: 23.1136, longitude: -82.3666),
        "哈瓦那": CityInfo(englishName: "Havana", chineseName: "哈瓦那", country: "Cuba", latitude: 23.1136, longitude: -82.3666),
        
        "trinidad": CityInfo(englishName: "Trinidad", chineseName: "特立尼达", country: "Cuba", latitude: 21.8019, longitude: -79.9842),
        "特立尼达": CityInfo(englishName: "Trinidad", chineseName: "特立尼达", country: "Cuba", latitude: 21.8019, longitude: -79.9842),
        
        "santiagodecuba": CityInfo(englishName: "Santiago de Cuba", chineseName: "圣地亚哥德古巴", country: "Cuba", latitude: 20.0217, longitude: -75.8294),
        "圣地亚哥德古巴": CityInfo(englishName: "Santiago de Cuba", chineseName: "圣地亚哥德古巴", country: "Cuba", latitude: 20.0217, longitude: -75.8294),
        
        "varadero": CityInfo(englishName: "Varadero", chineseName: "巴拉德罗", country: "Cuba", latitude: 23.1335, longitude: -81.2866),
        "巴拉德罗": CityInfo(englishName: "Varadero", chineseName: "巴拉德罗", country: "Cuba", latitude: 23.1335, longitude: -81.2866),
        
        // 哥斯达黎加
        "sanjose": CityInfo(englishName: "San José", chineseName: "圣何塞", country: "Costa Rica", latitude: 9.9281, longitude: -84.0907),
        "圣何塞": CityInfo(englishName: "San José", chineseName: "圣何塞", country: "Costa Rica", latitude: 9.9281, longitude: -84.0907),
        
        "limon": CityInfo(englishName: "Limón", chineseName: "利蒙", country: "Costa Rica", latitude: 9.9907, longitude: -83.0359),
        "利蒙": CityInfo(englishName: "Limón", chineseName: "利蒙", country: "Costa Rica", latitude: 9.9907, longitude: -83.0359),
        
        "puntarenas": CityInfo(englishName: "Puntarenas", chineseName: "蓬塔雷纳斯", country: "Costa Rica", latitude: 9.9769, longitude: -84.8384),
        "蓬塔雷纳斯": CityInfo(englishName: "Puntarenas", chineseName: "蓬塔雷纳斯", country: "Costa Rica", latitude: 9.9769, longitude: -84.8384),
        
        "fortuna": CityInfo(englishName: "La Fortuna", chineseName: "福图纳", country: "Costa Rica", latitude: 10.4706, longitude: -84.6453),
        "福图纳": CityInfo(englishName: "La Fortuna", chineseName: "福图纳", country: "Costa Rica", latitude: 10.4706, longitude: -84.6453),
        
        // 摩洛哥
        "rabat": CityInfo(englishName: "Rabat", chineseName: "拉巴特", country: "Morocco", latitude: 34.0209, longitude: -6.8416),
        "拉巴特": CityInfo(englishName: "Rabat", chineseName: "拉巴特", country: "Morocco", latitude: 34.0209, longitude: -6.8416),
        
        "marrakech": CityInfo(englishName: "Marrakech", chineseName: "马拉喀什", country: "Morocco", latitude: 31.6295, longitude: -7.9811),
        "马拉喀什": CityInfo(englishName: "Marrakech", chineseName: "马拉喀什", country: "Morocco", latitude: 31.6295, longitude: -7.9811),
        
        "casablanca": CityInfo(englishName: "Casablanca", chineseName: "卡萨布兰卡", country: "Morocco", latitude: 33.5731, longitude: -7.5898),
        "卡萨布兰卡": CityInfo(englishName: "Casablanca", chineseName: "卡萨布兰卡", country: "Morocco", latitude: 33.5731, longitude: -7.5898),
        
        "fes": CityInfo(englishName: "Fes", chineseName: "非斯", country: "Morocco", latitude: 34.0181, longitude: -5.0078),
        "非斯": CityInfo(englishName: "Fes", chineseName: "非斯", country: "Morocco", latitude: 34.0181, longitude: -5.0078),
        
        // 南非
        "pretoria": CityInfo(englishName: "Pretoria", chineseName: "比勒陀利亚", country: "South Africa", latitude: -25.7479, longitude: 28.2293),
        "比勒陀利亚": CityInfo(englishName: "Pretoria", chineseName: "比勒陀利亚", country: "South Africa", latitude: -25.7479, longitude: 28.2293),
        
        "capetown": CityInfo(englishName: "Cape Town", chineseName: "开普敦", country: "South Africa", latitude: -33.9249, longitude: 18.4241),
        "开普敦": CityInfo(englishName: "Cape Town", chineseName: "开普敦", country: "South Africa", latitude: -33.9249, longitude: 18.4241),
        
        "johannesburg": CityInfo(englishName: "Johannesburg", chineseName: "约翰内斯堡", country: "South Africa", latitude: -26.2041, longitude: 28.0473),
        "约翰内斯堡": CityInfo(englishName: "Johannesburg", chineseName: "约翰内斯堡", country: "South Africa", latitude: -26.2041, longitude: 28.0473),
        
        "durban": CityInfo(englishName: "Durban", chineseName: "德班", country: "South Africa", latitude: -29.8587, longitude: 31.0218),
        "德班": CityInfo(englishName: "Durban", chineseName: "德班", country: "South Africa", latitude: -29.8587, longitude: 31.0218),
        
        // 肯尼亚
        "nairobi": CityInfo(englishName: "Nairobi", chineseName: "内罗毕", country: "Kenya", latitude: -1.2921, longitude: 36.8219),
        "内罗毕": CityInfo(englishName: "Nairobi", chineseName: "内罗毕", country: "Kenya", latitude: -1.2921, longitude: 36.8219),
        
        "mombasa": CityInfo(englishName: "Mombasa", chineseName: "蒙巴萨", country: "Kenya", latitude: -4.0437, longitude: 39.6682),
        "蒙巴萨": CityInfo(englishName: "Mombasa", chineseName: "蒙巴萨", country: "Kenya", latitude: -4.0437, longitude: 39.6682),
        
        "masaimara": CityInfo(englishName: "Masai Mara", chineseName: "马赛马拉保护区", country: "Kenya", latitude: -1.4091, longitude: 35.1199),
        "马赛马拉保护区": CityInfo(englishName: "Masai Mara", chineseName: "马赛马拉保护区", country: "Kenya", latitude: -1.4091, longitude: 35.1199),
        
        "nakuru": CityInfo(englishName: "Nakuru", chineseName: "纳库鲁", country: "Kenya", latitude: -0.3031, longitude: 36.0800),
        "纳库鲁": CityInfo(englishName: "Nakuru", chineseName: "纳库鲁", country: "Kenya", latitude: -0.3031, longitude: 36.0800),
        
        // 坦桑尼亚
        "dodoma": CityInfo(englishName: "Dodoma", chineseName: "多多马", country: "Tanzania", latitude: -6.1630, longitude: 35.7516),
        "多多马": CityInfo(englishName: "Dodoma", chineseName: "多多马", country: "Tanzania", latitude: -6.1630, longitude: 35.7516),
        
        "darsalaam": CityInfo(englishName: "Dar es Salaam", chineseName: "达累斯萨拉姆", country: "Tanzania", latitude: -6.7924, longitude: 39.2083),
        "达累斯萨拉姆": CityInfo(englishName: "Dar es Salaam", chineseName: "达累斯萨拉姆", country: "Tanzania", latitude: -6.7924, longitude: 39.2083),
        
        "arusha": CityInfo(englishName: "Arusha", chineseName: "阿鲁沙", country: "Tanzania", latitude: -3.3869, longitude: 36.6830),
        "阿鲁沙": CityInfo(englishName: "Arusha", chineseName: "阿鲁沙", country: "Tanzania", latitude: -3.3869, longitude: 36.6830),
        
        "zanzibar": CityInfo(englishName: "Zanzibar", chineseName: "桑给巴尔", country: "Tanzania", latitude: -6.1659, longitude: 39.2026),
        "桑给巴尔": CityInfo(englishName: "Zanzibar", chineseName: "桑给巴尔", country: "Tanzania", latitude: -6.1659, longitude: 39.2026),
        
        // 以色列
        "jerusalem": CityInfo(englishName: "Jerusalem", chineseName: "耶路撒冷", country: "Israel", latitude: 31.7683, longitude: 35.2137),
        "耶路撒冷": CityInfo(englishName: "Jerusalem", chineseName: "耶路撒冷", country: "Israel", latitude: 31.7683, longitude: 35.2137),
        
        "telaviv": CityInfo(englishName: "Tel Aviv", chineseName: "特拉维夫", country: "Israel", latitude: 32.0853, longitude: 34.7818),
        "特拉维夫": CityInfo(englishName: "Tel Aviv", chineseName: "特拉维夫", country: "Israel", latitude: 32.0853, longitude: 34.7818),
        
        "haifa": CityInfo(englishName: "Haifa", chineseName: "海法", country: "Israel", latitude: 32.7940, longitude: 34.9896),
        "海法": CityInfo(englishName: "Haifa", chineseName: "海法", country: "Israel", latitude: 32.7940, longitude: 34.9896),
        
        "eilat": CityInfo(englishName: "Eilat", chineseName: "埃拉特", country: "Israel", latitude: 29.5581, longitude: 34.9482),
        "埃拉特": CityInfo(englishName: "Eilat", chineseName: "埃拉特", country: "Israel", latitude: 29.5581, longitude: 34.9482),
        
        // 约旦
        "amman": CityInfo(englishName: "Amman", chineseName: "安曼", country: "Jordan", latitude: 31.9454, longitude: 35.9284),
        "安曼": CityInfo(englishName: "Amman", chineseName: "安曼", country: "Jordan", latitude: 31.9454, longitude: 35.9284),
        
        "petra": CityInfo(englishName: "Petra", chineseName: "佩特拉", country: "Jordan", latitude: 30.3285, longitude: 35.4444),
        "佩特拉": CityInfo(englishName: "Petra", chineseName: "佩特拉", country: "Jordan", latitude: 30.3285, longitude: 35.4444),
        
        "deadsea": CityInfo(englishName: "Dead Sea", chineseName: "死海", country: "Jordan", latitude: 31.5590, longitude: 35.4732),
        "死海": CityInfo(englishName: "Dead Sea", chineseName: "死海", country: "Jordan", latitude: 31.5590, longitude: 35.4732),
        
        "wadirum": CityInfo(englishName: "Wadi Rum", chineseName: "瓦迪拉姆", country: "Jordan", latitude: 29.5908, longitude: 35.4208),
        "瓦迪拉姆": CityInfo(englishName: "Wadi Rum", chineseName: "瓦迪拉姆", country: "Jordan", latitude: 29.5908, longitude: 35.4208),
        
        // 卡塔尔
        "doha": CityInfo(englishName: "Doha", chineseName: "多哈", country: "Qatar", latitude: 25.2854, longitude: 51.5310),
        "多哈": CityInfo(englishName: "Doha", chineseName: "多哈", country: "Qatar", latitude: 25.2854, longitude: 51.5310),
        
        "wakra": CityInfo(englishName: "Al Wakrah", chineseName: "沃克拉", country: "Qatar", latitude: 25.1711, longitude: 51.6034),
        "沃克拉": CityInfo(englishName: "Al Wakrah", chineseName: "沃克拉", country: "Qatar", latitude: 25.1711, longitude: 51.6034),
        
        "alkhor": CityInfo(englishName: "Al Khor", chineseName: "阿尔科尔", country: "Qatar", latitude: 25.6804, longitude: 51.4969),
        "阿尔科尔": CityInfo(englishName: "Al Khor", chineseName: "阿尔科尔", country: "Qatar", latitude: 25.6804, longitude: 51.4969),
        
        "umsaid": CityInfo(englishName: "Umm Sa'id", chineseName: "乌姆赛义德", country: "Qatar", latitude: 24.8900, longitude: 51.5778),
        "乌姆赛义德": CityInfo(englishName: "Umm Sa'id", chineseName: "乌姆赛义德", country: "Qatar", latitude: 24.8900, longitude: 51.5778),
        
        // 马来西亚
        "kualalumpur": CityInfo(englishName: "Kuala Lumpur", chineseName: "吉隆坡", country: "Malaysia", latitude: 3.1390, longitude: 101.6869),
        "吉隆坡": CityInfo(englishName: "Kuala Lumpur", chineseName: "吉隆坡", country: "Malaysia", latitude: 3.1390, longitude: 101.6869),
        
        "penang": CityInfo(englishName: "Penang", chineseName: "槟城", country: "Malaysia", latitude: 5.4164, longitude: 100.3327),
        "槟城": CityInfo(englishName: "Penang", chineseName: "槟城", country: "Malaysia", latitude: 5.4164, longitude: 100.3327),
        
        "malacca": CityInfo(englishName: "Malacca", chineseName: "马六甲", country: "Malaysia", latitude: 2.1896, longitude: 102.2501),
        "马六甲": CityInfo(englishName: "Malacca", chineseName: "马六甲", country: "Malaysia", latitude: 2.1896, longitude: 102.2501),
        
        "johorbahru": CityInfo(englishName: "Johor Bahru", chineseName: "新山", country: "Malaysia", latitude: 1.4927, longitude: 103.7414),
        "新山": CityInfo(englishName: "Johor Bahru", chineseName: "新山", country: "Malaysia", latitude: 1.4927, longitude: 103.7414),
        
        // 印度尼西亚
        "jakarta": CityInfo(englishName: "Jakarta", chineseName: "雅加达", country: "Indonesia", latitude: -6.2088, longitude: 106.8456),
        "雅加达": CityInfo(englishName: "Jakarta", chineseName: "雅加达", country: "Indonesia", latitude: -6.2088, longitude: 106.8456),
        
        "bali": CityInfo(englishName: "Bali", chineseName: "巴厘岛", country: "Indonesia", latitude: -8.3405, longitude: 115.0920),
        "巴厘岛": CityInfo(englishName: "Bali", chineseName: "巴厘岛", country: "Indonesia", latitude: -8.3405, longitude: 115.0920),
        
        "yogyakarta": CityInfo(englishName: "Yogyakarta", chineseName: "日惹", country: "Indonesia", latitude: -7.7956, longitude: 110.3695),
        "日惹": CityInfo(englishName: "Yogyakarta", chineseName: "日惹", country: "Indonesia", latitude: -7.7956, longitude: 110.3695),
        
        "surabaya": CityInfo(englishName: "Surabaya", chineseName: "泗水", country: "Indonesia", latitude: -7.2575, longitude: 112.7521),
        "泗水": CityInfo(englishName: "Surabaya", chineseName: "泗水", country: "Indonesia", latitude: -7.2575, longitude: 112.7521),
        
        // 菲律宾
        "manila": CityInfo(englishName: "Manila", chineseName: "马尼拉", country: "Philippines", latitude: 14.5995, longitude: 120.9842),
        "马尼拉": CityInfo(englishName: "Manila", chineseName: "马尼拉", country: "Philippines", latitude: 14.5995, longitude: 120.9842),
        
        "cebu": CityInfo(englishName: "Cebu", chineseName: "宿务", country: "Philippines", latitude: 10.3157, longitude: 123.8854),
        "宿务": CityInfo(englishName: "Cebu", chineseName: "宿务", country: "Philippines", latitude: 10.3157, longitude: 123.8854),
        
        "boracay": CityInfo(englishName: "Boracay", chineseName: "长滩岛", country: "Philippines", latitude: 11.9674, longitude: 121.9248),
        "长滩岛": CityInfo(englishName: "Boracay", chineseName: "长滩岛", country: "Philippines", latitude: 11.9674, longitude: 121.9248),
        
        "palawan": CityInfo(englishName: "Palawan", chineseName: "巴拉望", country: "Philippines", latitude: 9.8349, longitude: 118.7384),
        "巴拉望": CityInfo(englishName: "Palawan", chineseName: "巴拉望", country: "Philippines", latitude: 9.8349, longitude: 118.7384),
        
        // 斯里兰卡
        "colombo": CityInfo(englishName: "Colombo", chineseName: "科伦坡", country: "Sri Lanka", latitude: 6.9271, longitude: 79.8612),
        "科伦坡": CityInfo(englishName: "Colombo", chineseName: "科伦坡", country: "Sri Lanka", latitude: 6.9271, longitude: 79.8612),
        
        "kandy": CityInfo(englishName: "Kandy", chineseName: "康提", country: "Sri Lanka", latitude: 7.2906, longitude: 80.6337),
        "康提": CityInfo(englishName: "Kandy", chineseName: "康提", country: "Sri Lanka", latitude: 7.2906, longitude: 80.6337),
        
        "galle": CityInfo(englishName: "Galle", chineseName: "加勒", country: "Sri Lanka", latitude: 6.0329, longitude: 80.2170),
        "加勒": CityInfo(englishName: "Galle", chineseName: "加勒", country: "Sri Lanka", latitude: 6.0329, longitude: 80.2170),
        
        "nuwaraeliya": CityInfo(englishName: "Nuwara Eliya", chineseName: "努沃勒埃利耶", country: "Sri Lanka", latitude: 6.9497, longitude: 80.7891),
        "努沃勒埃利耶": CityInfo(englishName: "Nuwara Eliya", chineseName: "努沃勒埃利耶", country: "Sri Lanka", latitude: 6.9497, longitude: 80.7891),
        
        // 尼泊尔
        "kathmandu": CityInfo(englishName: "Kathmandu", chineseName: "加德满都", country: "Nepal", latitude: 27.7172, longitude: 85.3240),
        "加德满都": CityInfo(englishName: "Kathmandu", chineseName: "加德满都", country: "Nepal", latitude: 27.7172, longitude: 85.3240),
        
        "pokhara": CityInfo(englishName: "Pokhara", chineseName: "博卡拉", country: "Nepal", latitude: 28.2096, longitude: 83.9856),
        "博卡拉": CityInfo(englishName: "Pokhara", chineseName: "博卡拉", country: "Nepal", latitude: 28.2096, longitude: 83.9856),
        
        "patan": CityInfo(englishName: "Patan", chineseName: "帕坦", country: "Nepal", latitude: 27.6784, longitude: 85.3240),
        "帕坦": CityInfo(englishName: "Patan", chineseName: "帕坦", country: "Nepal", latitude: 27.6784, longitude: 85.3240),
        
        "bhaktapur": CityInfo(englishName: "Bhaktapur", chineseName: "巴德岗", country: "Nepal", latitude: 27.6710, longitude: 85.4298),
        "巴德岗": CityInfo(englishName: "Bhaktapur", chineseName: "巴德岗", country: "Nepal", latitude: 27.6710, longitude: 85.4298),
        
        // 挪威
        "oslo": CityInfo(englishName: "Oslo", chineseName: "奥斯陆", country: "Norway", latitude: 59.9139, longitude: 10.7522),
        "奥斯陆": CityInfo(englishName: "Oslo", chineseName: "奥斯陆", country: "Norway", latitude: 59.9139, longitude: 10.7522),
        
        "bergen": CityInfo(englishName: "Bergen", chineseName: "卑尔根", country: "Norway", latitude: 60.3913, longitude: 5.3221),
        "卑尔根": CityInfo(englishName: "Bergen", chineseName: "卑尔根", country: "Norway", latitude: 60.3913, longitude: 5.3221),
        
        "tromso": CityInfo(englishName: "Tromsø", chineseName: "特罗姆瑟", country: "Norway", latitude: 69.6492, longitude: 18.9553),
        "特罗姆瑟": CityInfo(englishName: "Tromsø", chineseName: "特罗姆瑟", country: "Norway", latitude: 69.6492, longitude: 18.9553),
        
        "stavanger": CityInfo(englishName: "Stavanger", chineseName: "斯塔万格", country: "Norway", latitude: 58.9700, longitude: 5.7331),
        "斯塔万格": CityInfo(englishName: "Stavanger", chineseName: "斯塔万格", country: "Norway", latitude: 58.9700, longitude: 5.7331)
    ]
    
    /// 根据搜索词查找城市信息
    /// - Parameter searchText: 搜索文本（支持中英文）
    /// - Returns: 城市信息，如果未找到返回nil
    func findCity(by searchText: String) -> CityInfo? {
        // 标准化搜索词：转小写并移除空格
        let normalizedSearchText = searchText.lowercased().replacingOccurrences(of: " ", with: "")
        
        // 直接查找
        if let cityInfo = internationalCities[normalizedSearchText] {
            return cityInfo
        }
        
        // 如果直接查找失败，尝试模糊匹配
        return fuzzySearch(searchText: normalizedSearchText)
    }
    
    /// 模糊搜索城市
    /// - Parameter searchText: 搜索文本
    /// - Returns: 城市信息，如果未找到返回nil
    private func fuzzySearch(searchText: String) -> CityInfo? {
        // 遍历所有城市，查找包含搜索词的条目
        for (key, cityInfo) in internationalCities {
            if key.contains(searchText) || searchText.contains(key) {
                return cityInfo
            }
        }
        return nil
    }
    
    /// 获取所有预设城市列表
    /// - Returns: 城市信息数组
    func getAllCities() -> [CityInfo] {
        return Array(internationalCities.values)
    }
    
    /// 根据国家获取城市列表
    /// - Parameter country: 国家名称
    /// - Returns: 该国家的城市信息数组
    func getCities(by country: String) -> [CityInfo] {
        return internationalCities.values.filter { $0.country == country }
    }
    
    /// 添加新城市（用于扩展）
    /// - Parameters:
    ///   - key: 搜索键（支持多个键，如英文名、中文名等）
    ///   - cityInfo: 城市信息
    func addCity(key: String, cityInfo: CityInfo) {
        // 注意：由于字典是私有的，这个方法主要用于未来扩展
        // 如果需要动态添加，可以考虑使用可变字典
        print("添加城市功能需要修改为可变字典实现")
    }
    
    /// 获取城市总数
    /// - Returns: 预设城市总数
    func getCityCount() -> Int {
        return internationalCities.count
    }
    
    /// 检查是否包含某个城市
    /// - Parameter searchText: 搜索文本
    /// - Returns: 是否包含该城市
    func containsCity(_ searchText: String) -> Bool {
        return findCity(by: searchText) != nil
    }
}

// MARK: - 扩展方法
extension CityDataManager {
    
    /// 获取热门城市列表（按地区分组）
    /// - Returns: 按地区分组的城市字典
    func getCitiesByRegion() -> [String: [CityInfo]] {
        var regions: [String: [CityInfo]] = [:]
        
        for cityInfo in internationalCities.values {
            let region = getRegion(for: cityInfo.country)
            if regions[region] == nil {
                regions[region] = []
            }
            regions[region]?.append(cityInfo)
        }
        
        return regions
    }
    
    /// 根据国家获取地区
    /// - Parameter country: 国家名称
    /// - Returns: 地区名称
    private func getRegion(for country: String) -> String {
        switch country {
        case "United Kingdom", "France", "Italy", "Spain", "Netherlands", "Russia", "Germany", "Greece", "Austria", "Iceland", "Ireland", "Turkey", "Switzerland", "Belgium", "Czech Republic", "Hungary", "Poland", "Croatia", "Norway":
            return "欧洲"
        case "Japan", "South Korea", "Singapore", "Thailand", "India", "Vietnam", "Malaysia", "Indonesia", "Philippines", "Sri Lanka", "Nepal":
            return "亚洲"
        case "United States", "Mexico", "Canada", "Brazil", "Argentina", "Chile", "Peru", "Cuba", "Costa Rica":
            return "美洲"
        case "Australia", "New Zealand":
            return "大洋洲"
        case "United Arab Emirates", "Egypt", "Morocco", "South Africa", "Kenya", "Tanzania", "Israel", "Jordan", "Qatar":
            return "中东/非洲"
        case "Portugal":
            return "其他"
        default:
            return "其他"
        }
    }
}
