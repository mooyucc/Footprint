//
//  SampleData.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import Foundation
import SwiftData

/// 示例数据生成器 - 用于测试和演示
@MainActor
class SampleData {
    
    /// 创建示例旅行目的地数据
    static func createSampleDestinations(in modelContext: ModelContext) {
        
        // 检查是否已有数据
        let descriptor = FetchDescriptor<TravelDestination>()
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            print("已有数据，跳过示例数据创建")
            return
        }
        
        let sampleDestinations = [
            // 国外目的地
            TravelDestination(
                name: "雷克雅未克",
                country: "冰岛",
                latitude: 64.1466,
                longitude: -21.9426,
                visitDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
                notes: "在冰岛看到了梦幻般的北极光，蓝湖温泉让人难忘。黄金圈的风景太美了！",
                category: "international",
                isFavorite: true
            ),
            
            TravelDestination(
                name: "巴黎",
                country: "法国",
                latitude: 48.8566,
                longitude: 2.3522,
                visitDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
                notes: "浪漫之都，埃菲尔铁塔的夜景太美了。卢浮宫值得花一整天时间参观。",
                category: "international",
                isFavorite: true
            ),
            
            TravelDestination(
                name: "皇后镇",
                country: "新西兰",
                latitude: -45.0312,
                longitude: 168.6626,
                visitDate: Calendar.current.date(byAdding: .month, value: -8, to: Date())!,
                notes: "极限运动天堂！蹦极、跳伞都体验了。米尔福德峡湾的景色震撼人心。",
                category: "international",
                isFavorite: true
            ),
            
            TravelDestination(
                name: "奥克兰",
                country: "新西兰",
                latitude: -36.8485,
                longitude: 174.7633,
                visitDate: Calendar.current.date(byAdding: .month, value: -9, to: Date())!,
                notes: "千帆之都，天空塔的观景台视野极佳。当地的海鲜很新鲜。",
                category: "international",
                isFavorite: false
            ),
            
            TravelDestination(
                name: "东京",
                country: "日本",
                latitude: 35.6762,
                longitude: 139.6503,
                visitDate: Calendar.current.date(byAdding: .month, value: -3, to: Date())!,
                notes: "现代化与传统文化的完美融合。浅草寺、涩谷、秋叶原都很有特色。",
                category: "international",
                isFavorite: false
            ),
            
            // 国内目的地
            TravelDestination(
                name: "乌鲁木齐",
                country: "中国",
                latitude: 43.8256,
                longitude: 87.6168,
                visitDate: Calendar.current.date(byAdding: .month, value: -4, to: Date())!,
                notes: "新疆之旅的起点，天山天池美不胜收。大巴扎的美食太丰富了！",
                category: "domestic",
                isFavorite: true
            ),
            
            TravelDestination(
                name: "喀纳斯",
                country: "中国",
                latitude: 48.7061,
                longitude: 87.0362,
                visitDate: Calendar.current.date(byAdding: .month, value: -4, to: Date())!,
                notes: "人间仙境！湖水的颜色随着光线变化。禾木村的晨雾美如画。",
                category: "domestic",
                isFavorite: true
            ),
            
            TravelDestination(
                name: "西宁",
                country: "中国",
                latitude: 36.6171,
                longitude: 101.7782,
                visitDate: Calendar.current.date(byAdding: .month, value: -5, to: Date())!,
                notes: "高原明珠，青海湖的起点。塔尔寺让人感受到藏传佛教的魅力。",
                category: "domestic",
                isFavorite: false
            ),
            
            TravelDestination(
                name: "青海湖",
                country: "中国",
                latitude: 36.5300,
                longitude: 100.2050,
                visitDate: Calendar.current.date(byAdding: .month, value: -5, to: Date())!,
                notes: "中国最大的内陆湖，油菜花季节美极了。骑行环湖是难忘的体验。",
                category: "domestic",
                isFavorite: true
            ),
            
            TravelDestination(
                name: "丽江古城",
                country: "中国",
                latitude: 26.8560,
                longitude: 100.2270,
                visitDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!,
                notes: "纳西古城韵味十足，四方街很热闹。玉龙雪山壮观，蓝月谷的水真蓝。",
                category: "domestic",
                isFavorite: false
            ),
            
            TravelDestination(
                name: "桂林",
                country: "中国",
                latitude: 25.2741,
                longitude: 110.2900,
                visitDate: Calendar.current.date(byAdding: .month, value: -10, to: Date())!,
                notes: "桂林山水甲天下，漓江游船太美了。阳朔的田园风光令人陶醉。",
                category: "domestic",
                isFavorite: false
            ),
            
            TravelDestination(
                name: "张家界",
                country: "中国",
                latitude: 29.1167,
                longitude: 110.4783,
                visitDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
                notes: "阿凡达的取景地，武陵源的奇峰异石太震撼了。玻璃栈道很刺激！",
                category: "domestic",
                isFavorite: true
            )
        ]
        
        // 插入数据
        for destination in sampleDestinations {
            modelContext.insert(destination)
        }
        
        // 保存数据
        do {
            try modelContext.save()
            print("✅ 成功创建 \(sampleDestinations.count) 个示例目的地")
        } catch {
            print("❌ 保存示例数据失败: \(error)")
        }
    }
    
    /// 清除所有数据
    static func clearAllData(in modelContext: ModelContext) {
        do {
            try modelContext.delete(model: TravelDestination.self)
            print("✅ 已清除所有数据")
        } catch {
            print("❌ 清除数据失败: \(error)")
        }
    }
}

