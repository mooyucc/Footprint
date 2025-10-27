//
//  CountryManager.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import Foundation
import SwiftUI
import Combine

class CountryManager: ObservableObject {
    static let shared = CountryManager()
    
    @Published var currentCountry: Country = .china
    
    enum Country: String, CaseIterable {
        case china = "CN"
        case unitedStates = "US"
        case japan = "JP"
        case southKorea = "KR"
        case singapore = "SG"
        case thailand = "TH"
        case malaysia = "MY"
        case indonesia = "ID"
        case philippines = "PH"
        case vietnam = "VN"
        case india = "IN"
        case australia = "AU"
        case newZealand = "NZ"
        case canada = "CA"
        case unitedKingdom = "GB"
        case france = "FR"
        case germany = "DE"
        case italy = "IT"
        case spain = "ES"
        case netherlands = "NL"
        case switzerland = "CH"
        case austria = "AT"
        case belgium = "BE"
        case denmark = "DK"
        case finland = "FI"
        case norway = "NO"
        case sweden = "SE"
        case poland = "PL"
        case czechRepublic = "CZ"
        case hungary = "HU"
        case greece = "GR"
        case portugal = "PT"
        case ireland = "IE"
        case luxembourg = "LU"
        case russia = "RU"
        case ukraine = "UA"
        case turkey = "TR"
        case israel = "IL"
        case unitedArabEmirates = "AE"
        case saudiArabia = "SA"
        case qatar = "QA"
        case kuwait = "KW"
        case bahrain = "BH"
        case oman = "OM"
        case jordan = "JO"
        case lebanon = "LB"
        case egypt = "EG"
        case southAfrica = "ZA"
        case nigeria = "NG"
        case kenya = "KE"
        case morocco = "MA"
        case tunisia = "TN"
        case algeria = "DZ"
        case ethiopia = "ET"
        case ghana = "GH"
        case uganda = "UG"
        case tanzania = "TZ"
        case zimbabwe = "ZW"
        case botswana = "BW"
        case namibia = "NA"
        case zambia = "ZM"
        case malawi = "MW"
        case mozambique = "MZ"
        case madagascar = "MG"
        case mauritius = "MU"
        case seychelles = "SC"
        case brazil = "BR"
        case argentina = "AR"
        case chile = "CL"
        case colombia = "CO"
        case peru = "PE"
        case venezuela = "VE"
        case uruguay = "UY"
        case paraguay = "PY"
        case bolivia = "BO"
        case ecuador = "EC"
        case guyana = "GY"
        case suriname = "SR"
        case frenchGuiana = "GF"
        case mexico = "MX"
        case guatemala = "GT"
        case belize = "BZ"
        case elSalvador = "SV"
        case honduras = "HN"
        case nicaragua = "NI"
        case costaRica = "CR"
        case panama = "PA"
        case cuba = "CU"
        case jamaica = "JM"
        case haiti = "HT"
        case dominicanRepublic = "DO"
        case puertoRico = "PR"
        case trinidadAndTobago = "TT"
        case barbados = "BB"
        case bahamas = "BS"
        case bermuda = "BM"
        case caymanIslands = "KY"
        case virginIslands = "VI"
        case aruba = "AW"
        case netherlandsAntilles = "AN"
        case antiguaAndBarbuda = "AG"
        case dominica = "DM"
        case grenada = "GD"
        case saintKittsAndNevis = "KN"
        case saintLucia = "LC"
        case saintVincentAndTheGrenadines = "VC"
        case anguilla = "AI"
        case montserrat = "MS"
        case turksAndCaicosIslands = "TC"
        case britishVirginIslands = "VG"
        case saintBarthelemy = "BL"
        case saintMartin = "MF"
        case guadeloupe = "GP"
        case martinique = "MQ"
        case saintPierreAndMiquelon = "PM"
        case greenland = "GL"
        case faroeIslands = "FO"
        case iceland = "IS"
        
        var displayName: String {
            switch self {
            case .china:
                return "中国"
            case .unitedStates:
                return "美国"
            case .japan:
                return "日本"
            case .southKorea:
                return "韩国"
            case .singapore:
                return "新加坡"
            case .thailand:
                return "泰国"
            case .malaysia:
                return "马来西亚"
            case .indonesia:
                return "印度尼西亚"
            case .philippines:
                return "菲律宾"
            case .vietnam:
                return "越南"
            case .india:
                return "印度"
            case .australia:
                return "澳大利亚"
            case .newZealand:
                return "新西兰"
            case .canada:
                return "加拿大"
            case .unitedKingdom:
                return "英国"
            case .france:
                return "法国"
            case .germany:
                return "德国"
            case .italy:
                return "意大利"
            case .spain:
                return "西班牙"
            case .netherlands:
                return "荷兰"
            case .switzerland:
                return "瑞士"
            case .austria:
                return "奥地利"
            case .belgium:
                return "比利时"
            case .denmark:
                return "丹麦"
            case .finland:
                return "芬兰"
            case .norway:
                return "挪威"
            case .sweden:
                return "瑞典"
            case .poland:
                return "波兰"
            case .czechRepublic:
                return "捷克"
            case .hungary:
                return "匈牙利"
            case .greece:
                return "希腊"
            case .portugal:
                return "葡萄牙"
            case .ireland:
                return "爱尔兰"
            case .luxembourg:
                return "卢森堡"
            case .russia:
                return "俄罗斯"
            case .ukraine:
                return "乌克兰"
            case .turkey:
                return "土耳其"
            case .israel:
                return "以色列"
            case .unitedArabEmirates:
                return "阿联酋"
            case .saudiArabia:
                return "沙特阿拉伯"
            case .qatar:
                return "卡塔尔"
            case .kuwait:
                return "科威特"
            case .bahrain:
                return "巴林"
            case .oman:
                return "阿曼"
            case .jordan:
                return "约旦"
            case .lebanon:
                return "黎巴嫩"
            case .egypt:
                return "埃及"
            case .southAfrica:
                return "南非"
            case .nigeria:
                return "尼日利亚"
            case .kenya:
                return "肯尼亚"
            case .morocco:
                return "摩洛哥"
            case .tunisia:
                return "突尼斯"
            case .algeria:
                return "阿尔及利亚"
            case .ethiopia:
                return "埃塞俄比亚"
            case .ghana:
                return "加纳"
            case .uganda:
                return "乌干达"
            case .tanzania:
                return "坦桑尼亚"
            case .zimbabwe:
                return "津巴布韦"
            case .botswana:
                return "博茨瓦纳"
            case .namibia:
                return "纳米比亚"
            case .zambia:
                return "赞比亚"
            case .malawi:
                return "马拉维"
            case .mozambique:
                return "莫桑比克"
            case .madagascar:
                return "马达加斯加"
            case .mauritius:
                return "毛里求斯"
            case .seychelles:
                return "塞舌尔"
            case .brazil:
                return "巴西"
            case .argentina:
                return "阿根廷"
            case .chile:
                return "智利"
            case .colombia:
                return "哥伦比亚"
            case .peru:
                return "秘鲁"
            case .venezuela:
                return "委内瑞拉"
            case .uruguay:
                return "乌拉圭"
            case .paraguay:
                return "巴拉圭"
            case .bolivia:
                return "玻利维亚"
            case .ecuador:
                return "厄瓜多尔"
            case .guyana:
                return "圭亚那"
            case .suriname:
                return "苏里南"
            case .frenchGuiana:
                return "法属圭亚那"
            case .mexico:
                return "墨西哥"
            case .guatemala:
                return "危地马拉"
            case .belize:
                return "伯利兹"
            case .elSalvador:
                return "萨尔瓦多"
            case .honduras:
                return "洪都拉斯"
            case .nicaragua:
                return "尼加拉瓜"
            case .costaRica:
                return "哥斯达黎加"
            case .panama:
                return "巴拿马"
            case .cuba:
                return "古巴"
            case .jamaica:
                return "牙买加"
            case .haiti:
                return "海地"
            case .dominicanRepublic:
                return "多米尼加"
            case .puertoRico:
                return "波多黎各"
            case .trinidadAndTobago:
                return "特立尼达和多巴哥"
            case .barbados:
                return "巴巴多斯"
            case .bahamas:
                return "巴哈马"
            case .bermuda:
                return "百慕大"
            case .caymanIslands:
                return "开曼群岛"
            case .virginIslands:
                return "维尔京群岛"
            case .aruba:
                return "阿鲁巴"
            case .netherlandsAntilles:
                return "荷属安的列斯"
            case .antiguaAndBarbuda:
                return "安提瓜和巴布达"
            case .dominica:
                return "多米尼克"
            case .grenada:
                return "格林纳达"
            case .saintKittsAndNevis:
                return "圣基茨和尼维斯"
            case .saintLucia:
                return "圣卢西亚"
            case .saintVincentAndTheGrenadines:
                return "圣文森特和格林纳丁斯"
            case .anguilla:
                return "安圭拉"
            case .montserrat:
                return "蒙特塞拉特"
            case .turksAndCaicosIslands:
                return "特克斯和凯科斯群岛"
            case .britishVirginIslands:
                return "英属维尔京群岛"
            case .saintBarthelemy:
                return "圣巴泰勒米"
            case .saintMartin:
                return "圣马丁"
            case .guadeloupe:
                return "瓜德罗普"
            case .martinique:
                return "马提尼克"
            case .saintPierreAndMiquelon:
                return "圣皮埃尔和密克隆"
            case .greenland:
                return "格陵兰"
            case .faroeIslands:
                return "法罗群岛"
            case .iceland:
                return "冰岛"
            }
        }
        
        var flag: String {
            switch self {
            case .china:
                return "🇨🇳"
            case .unitedStates:
                return "🇺🇸"
            case .japan:
                return "🇯🇵"
            case .southKorea:
                return "🇰🇷"
            case .singapore:
                return "🇸🇬"
            case .thailand:
                return "🇹🇭"
            case .malaysia:
                return "🇲🇾"
            case .indonesia:
                return "🇮🇩"
            case .philippines:
                return "🇵🇭"
            case .vietnam:
                return "🇻🇳"
            case .india:
                return "🇮🇳"
            case .australia:
                return "🇦🇺"
            case .newZealand:
                return "🇳🇿"
            case .canada:
                return "🇨🇦"
            case .unitedKingdom:
                return "🇬🇧"
            case .france:
                return "🇫🇷"
            case .germany:
                return "🇩🇪"
            case .italy:
                return "🇮🇹"
            case .spain:
                return "🇪🇸"
            case .netherlands:
                return "🇳🇱"
            case .switzerland:
                return "🇨🇭"
            case .austria:
                return "🇦🇹"
            case .belgium:
                return "🇧🇪"
            case .denmark:
                return "🇩🇰"
            case .finland:
                return "🇫🇮"
            case .norway:
                return "🇳🇴"
            case .sweden:
                return "🇸🇪"
            case .poland:
                return "🇵🇱"
            case .czechRepublic:
                return "🇨🇿"
            case .hungary:
                return "🇭🇺"
            case .greece:
                return "🇬🇷"
            case .portugal:
                return "🇵🇹"
            case .ireland:
                return "🇮🇪"
            case .luxembourg:
                return "🇱🇺"
            case .russia:
                return "🇷🇺"
            case .ukraine:
                return "🇺🇦"
            case .turkey:
                return "🇹🇷"
            case .israel:
                return "🇮🇱"
            case .unitedArabEmirates:
                return "🇦🇪"
            case .saudiArabia:
                return "🇸🇦"
            case .qatar:
                return "🇶🇦"
            case .kuwait:
                return "🇰🇼"
            case .bahrain:
                return "🇧🇭"
            case .oman:
                return "🇴🇲"
            case .jordan:
                return "🇯🇴"
            case .lebanon:
                return "🇱🇧"
            case .egypt:
                return "🇪🇬"
            case .southAfrica:
                return "🇿🇦"
            case .nigeria:
                return "🇳🇬"
            case .kenya:
                return "🇰🇪"
            case .morocco:
                return "🇲🇦"
            case .tunisia:
                return "🇹🇳"
            case .algeria:
                return "🇩🇿"
            case .ethiopia:
                return "🇪🇹"
            case .ghana:
                return "🇬🇭"
            case .uganda:
                return "🇺🇬"
            case .tanzania:
                return "🇹🇿"
            case .zimbabwe:
                return "🇿🇼"
            case .botswana:
                return "🇧🇼"
            case .namibia:
                return "🇳🇦"
            case .zambia:
                return "🇿🇲"
            case .malawi:
                return "🇲🇼"
            case .mozambique:
                return "🇲🇿"
            case .madagascar:
                return "🇲🇬"
            case .mauritius:
                return "🇲🇺"
            case .seychelles:
                return "🇸🇨"
            case .brazil:
                return "🇧🇷"
            case .argentina:
                return "🇦🇷"
            case .chile:
                return "🇨🇱"
            case .colombia:
                return "🇨🇴"
            case .peru:
                return "🇵🇪"
            case .venezuela:
                return "🇻🇪"
            case .uruguay:
                return "🇺🇾"
            case .paraguay:
                return "🇵🇾"
            case .bolivia:
                return "🇧🇴"
            case .ecuador:
                return "🇪🇨"
            case .guyana:
                return "🇬🇾"
            case .suriname:
                return "🇸🇷"
            case .frenchGuiana:
                return "🇬🇫"
            case .mexico:
                return "🇲🇽"
            case .guatemala:
                return "🇬🇹"
            case .belize:
                return "🇧🇿"
            case .elSalvador:
                return "🇸🇻"
            case .honduras:
                return "🇭🇳"
            case .nicaragua:
                return "🇳🇮"
            case .costaRica:
                return "🇨🇷"
            case .panama:
                return "🇵🇦"
            case .cuba:
                return "🇨🇺"
            case .jamaica:
                return "🇯🇲"
            case .haiti:
                return "🇭🇹"
            case .dominicanRepublic:
                return "🇩🇴"
            case .puertoRico:
                return "🇵🇷"
            case .trinidadAndTobago:
                return "🇹🇹"
            case .barbados:
                return "🇧🇧"
            case .bahamas:
                return "🇧🇸"
            case .bermuda:
                return "🇧🇲"
            case .caymanIslands:
                return "🇰🇾"
            case .virginIslands:
                return "🇻🇮"
            case .aruba:
                return "🇦🇼"
            case .netherlandsAntilles:
                return "🇦🇳"
            case .antiguaAndBarbuda:
                return "🇦🇬"
            case .dominica:
                return "🇩🇲"
            case .grenada:
                return "🇬🇩"
            case .saintKittsAndNevis:
                return "🇰🇳"
            case .saintLucia:
                return "🇱🇨"
            case .saintVincentAndTheGrenadines:
                return "🇻🇨"
            case .anguilla:
                return "🇦🇮"
            case .montserrat:
                return "🇲🇸"
            case .turksAndCaicosIslands:
                return "🇹🇨"
            case .britishVirginIslands:
                return "🇻🇬"
            case .saintBarthelemy:
                return "🇧🇱"
            case .saintMartin:
                return "🇲🇫"
            case .guadeloupe:
                return "🇬🇵"
            case .martinique:
                return "🇲🇶"
            case .saintPierreAndMiquelon:
                return "🇵🇲"
            case .greenland:
                return "🇬🇱"
            case .faroeIslands:
                return "🇫🇴"
            case .iceland:
                return "🇮🇸"
            }
        }
        
        var englishName: String {
            switch self {
            case .china:
                return "China"
            case .unitedStates:
                return "United States"
            case .japan:
                return "Japan"
            case .southKorea:
                return "South Korea"
            case .singapore:
                return "Singapore"
            case .thailand:
                return "Thailand"
            case .malaysia:
                return "Malaysia"
            case .indonesia:
                return "Indonesia"
            case .philippines:
                return "Philippines"
            case .vietnam:
                return "Vietnam"
            case .india:
                return "India"
            case .australia:
                return "Australia"
            case .newZealand:
                return "New Zealand"
            case .canada:
                return "Canada"
            case .unitedKingdom:
                return "United Kingdom"
            case .france:
                return "France"
            case .germany:
                return "Germany"
            case .italy:
                return "Italy"
            case .spain:
                return "Spain"
            case .netherlands:
                return "Netherlands"
            case .switzerland:
                return "Switzerland"
            case .austria:
                return "Austria"
            case .belgium:
                return "Belgium"
            case .denmark:
                return "Denmark"
            case .finland:
                return "Finland"
            case .norway:
                return "Norway"
            case .sweden:
                return "Sweden"
            case .poland:
                return "Poland"
            case .czechRepublic:
                return "Czech Republic"
            case .hungary:
                return "Hungary"
            case .greece:
                return "Greece"
            case .portugal:
                return "Portugal"
            case .ireland:
                return "Ireland"
            case .luxembourg:
                return "Luxembourg"
            case .russia:
                return "Russia"
            case .ukraine:
                return "Ukraine"
            case .turkey:
                return "Turkey"
            case .israel:
                return "Israel"
            case .unitedArabEmirates:
                return "United Arab Emirates"
            case .saudiArabia:
                return "Saudi Arabia"
            case .qatar:
                return "Qatar"
            case .kuwait:
                return "Kuwait"
            case .bahrain:
                return "Bahrain"
            case .oman:
                return "Oman"
            case .jordan:
                return "Jordan"
            case .lebanon:
                return "Lebanon"
            case .egypt:
                return "Egypt"
            case .southAfrica:
                return "South Africa"
            case .nigeria:
                return "Nigeria"
            case .kenya:
                return "Kenya"
            case .morocco:
                return "Morocco"
            case .tunisia:
                return "Tunisia"
            case .algeria:
                return "Algeria"
            case .ethiopia:
                return "Ethiopia"
            case .ghana:
                return "Ghana"
            case .uganda:
                return "Uganda"
            case .tanzania:
                return "Tanzania"
            case .zimbabwe:
                return "Zimbabwe"
            case .botswana:
                return "Botswana"
            case .namibia:
                return "Namibia"
            case .zambia:
                return "Zambia"
            case .malawi:
                return "Malawi"
            case .mozambique:
                return "Mozambique"
            case .madagascar:
                return "Madagascar"
            case .mauritius:
                return "Mauritius"
            case .seychelles:
                return "Seychelles"
            case .brazil:
                return "Brazil"
            case .argentina:
                return "Argentina"
            case .chile:
                return "Chile"
            case .colombia:
                return "Colombia"
            case .peru:
                return "Peru"
            case .venezuela:
                return "Venezuela"
            case .uruguay:
                return "Uruguay"
            case .paraguay:
                return "Paraguay"
            case .bolivia:
                return "Bolivia"
            case .ecuador:
                return "Ecuador"
            case .guyana:
                return "Guyana"
            case .suriname:
                return "Suriname"
            case .frenchGuiana:
                return "French Guiana"
            case .mexico:
                return "Mexico"
            case .guatemala:
                return "Guatemala"
            case .belize:
                return "Belize"
            case .elSalvador:
                return "El Salvador"
            case .honduras:
                return "Honduras"
            case .nicaragua:
                return "Nicaragua"
            case .costaRica:
                return "Costa Rica"
            case .panama:
                return "Panama"
            case .cuba:
                return "Cuba"
            case .jamaica:
                return "Jamaica"
            case .haiti:
                return "Haiti"
            case .dominicanRepublic:
                return "Dominican Republic"
            case .puertoRico:
                return "Puerto Rico"
            case .trinidadAndTobago:
                return "Trinidad and Tobago"
            case .barbados:
                return "Barbados"
            case .bahamas:
                return "Bahamas"
            case .bermuda:
                return "Bermuda"
            case .caymanIslands:
                return "Cayman Islands"
            case .virginIslands:
                return "Virgin Islands"
            case .aruba:
                return "Aruba"
            case .netherlandsAntilles:
                return "Netherlands Antilles"
            case .antiguaAndBarbuda:
                return "Antigua and Barbuda"
            case .dominica:
                return "Dominica"
            case .grenada:
                return "Grenada"
            case .saintKittsAndNevis:
                return "Saint Kitts and Nevis"
            case .saintLucia:
                return "Saint Lucia"
            case .saintVincentAndTheGrenadines:
                return "Saint Vincent and the Grenadines"
            case .anguilla:
                return "Anguilla"
            case .montserrat:
                return "Montserrat"
            case .turksAndCaicosIslands:
                return "Turks and Caicos Islands"
            case .britishVirginIslands:
                return "British Virgin Islands"
            case .saintBarthelemy:
                return "Saint Barthélemy"
            case .saintMartin:
                return "Saint Martin"
            case .guadeloupe:
                return "Guadeloupe"
            case .martinique:
                return "Martinique"
            case .saintPierreAndMiquelon:
                return "Saint Pierre and Miquelon"
            case .greenland:
                return "Greenland"
            case .faroeIslands:
                return "Faroe Islands"
            case .iceland:
                return "Iceland"
            }
        }
    }
    
    private init() {
        // 从UserDefaults读取保存的国家设置
        if let savedCountry = UserDefaults.standard.string(forKey: "SelectedCountry"),
           let country = Country(rawValue: savedCountry) {
            currentCountry = country
        } else {
            // 如果没有保存的设置，根据系统区域自动选择
            let systemRegion = Locale.current.region?.identifier ?? "CN"
            if let country = Country(rawValue: systemRegion) {
                currentCountry = country
            } else {
                // 如果系统区域不在支持列表中，默认为中国
                currentCountry = .china
            }
        }
    }
    
    func setCountry(_ country: Country) {
        currentCountry = country
        UserDefaults.standard.set(country.rawValue, forKey: "SelectedCountry")
        
        // 通知应用国家设置已更改
        NotificationCenter.default.post(name: .countryChanged, object: nil)
    }
    
    // 判断是否为国内旅行（相对于用户所在国家）
    func isDomestic(country: String) -> Bool {
        // 匹配 ISO 国家代码
        if country == currentCountry.rawValue {
            return true
        }
        
        // 匹配中文名称
        if country == currentCountry.displayName {
            return true
        }
        
        // 匹配英文名称
        if country == currentCountry.englishName {
            return true
        }
        
        return false
    }
    
    // 获取当前国家的显示名称
    var currentCountryDisplayName: String {
        return currentCountry.displayName
    }
    
    // 获取当前国家的英文名称
    var currentCountryEnglishName: String {
        return currentCountry.englishName
    }
    
    // 根据当前语言设置获取国家显示名称
    func getLocalizedCountryName(for country: Country) -> String {
        // 获取当前语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") {
            if savedLanguage == "en" {
                return country.englishName
            } else {
                return country.displayName
            }
        } else {
            // 如果没有保存的语言设置，根据系统语言判断
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            if systemLanguage.hasPrefix("zh") {
                return country.displayName
            } else {
                return country.englishName
            }
        }
    }
    
    // 获取当前国家的本地化显示名称
    var currentCountryLocalizedName: String {
        return getLocalizedCountryName(for: currentCountry)
    }
}

extension Notification.Name {
    static let countryChanged = Notification.Name("CountryChanged")
}
