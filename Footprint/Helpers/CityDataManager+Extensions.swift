//
//  CityDataManager+Extensions.swift
//  Footprint
//
//  Created by K.X on 2025/01/27.
//

import Foundation

// MARK: - 城市数据扩展示例
extension CityDataManager {
    
    /// 示例：如何添加新城市
    /// 这是一个示例方法，展示如何扩展城市数据
    func addMoreCitiesExample() {
        // 示例：添加更多热门城市
        // 注意：由于当前实现使用不可变字典，这里只是展示如何添加
        // 实际使用时需要修改为可变字典或使用其他存储方式
        
        let additionalCities: [String: CityInfo] = [
            // 欧洲更多城市
            "berlin": CityInfo(englishName: "Berlin", chineseName: "柏林", country: "Germany", latitude: 52.5200, longitude: 13.4050),
            "柏林": CityInfo(englishName: "Berlin", chineseName: "柏林", country: "Germany", latitude: 52.5200, longitude: 13.4050),
            
            "vienna": CityInfo(englishName: "Vienna", chineseName: "维也纳", country: "Austria", latitude: 48.2082, longitude: 16.3738),
            "维也纳": CityInfo(englishName: "Vienna", chineseName: "维也纳", country: "Austria", latitude: 48.2082, longitude: 16.3738),
            
            "prague": CityInfo(englishName: "Prague", chineseName: "布拉格", country: "Czech Republic", latitude: 50.0755, longitude: 14.4378),
            "布拉格": CityInfo(englishName: "Prague", chineseName: "布拉格", country: "Czech Republic", latitude: 50.0755, longitude: 14.4378),
            
            // 亚洲更多城市
            "hongkong": CityInfo(englishName: "Hong Kong", chineseName: "香港", country: "Hong Kong", latitude: 22.3193, longitude: 114.1694),
            "香港": CityInfo(englishName: "Hong Kong", chineseName: "香港", country: "Hong Kong", latitude: 22.3193, longitude: 114.1694),
            
            "taipei": CityInfo(englishName: "Taipei", chineseName: "台北", country: "Taiwan", latitude: 25.0330, longitude: 121.5654),
            "台北": CityInfo(englishName: "Taipei", chineseName: "台北", country: "Taiwan", latitude: 25.0330, longitude: 121.5654),
            
            "mumbai": CityInfo(englishName: "Mumbai", chineseName: "孟买", country: "India", latitude: 19.0760, longitude: 72.8777),
            "孟买": CityInfo(englishName: "Mumbai", chineseName: "孟买", country: "India", latitude: 19.0760, longitude: 72.8777),
            
            // 美洲更多城市
            "toronto": CityInfo(englishName: "Toronto", chineseName: "多伦多", country: "Canada", latitude: 43.6532, longitude: -79.3832),
            "多伦多": CityInfo(englishName: "Toronto", chineseName: "多伦多", country: "Canada", latitude: 43.6532, longitude: -79.3832),
            
            "mexicocity": CityInfo(englishName: "Mexico City", chineseName: "墨西哥城", country: "Mexico", latitude: 19.4326, longitude: -99.1332),
            "墨西哥城": CityInfo(englishName: "Mexico City", chineseName: "墨西哥城", country: "Mexico", latitude: 19.4326, longitude: -99.1332),
            
            // 非洲城市
            "cairo": CityInfo(englishName: "Cairo", chineseName: "开罗", country: "Egypt", latitude: 30.0444, longitude: 31.2357),
            "开罗": CityInfo(englishName: "Cairo", chineseName: "开罗", country: "Egypt", latitude: 30.0444, longitude: 31.2357),
            
            "capetown": CityInfo(englishName: "Cape Town", chineseName: "开普敦", country: "South Africa", latitude: -33.9249, longitude: 18.4241),
            "开普敦": CityInfo(englishName: "Cape Town", chineseName: "开普敦", country: "South Africa", latitude: -33.9249, longitude: 18.4241)
        ]
        
        print("示例：可以添加 \(additionalCities.count) 个新城市")
        print("包括：柏林、维也纳、布拉格、香港、台北、孟买、多伦多、墨西哥城、开罗、开普敦等")
    }
    
    /// 获取城市统计信息
    func getCityStatistics() -> (total: Int, byRegion: [String: Int]) {
        let allCities = getAllCities()
        let regions = getCitiesByRegion()
        
        var regionCounts: [String: Int] = [:]
        for (region, cities) in regions {
            regionCounts[region] = cities.count
        }
        
        return (total: allCities.count, byRegion: regionCounts)
    }
    
    /// 打印城市统计信息
    func printCityStatistics() {
        let stats = getCityStatistics()
        print("📊 城市数据统计:")
        print("   总城市数: \(stats.total)")
        print("   按地区分布:")
        for (region, count) in stats.byRegion {
            print("     \(region): \(count) 个城市")
        }
    }
}
