//
//  TravelTrip.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
//

import Foundation
import SwiftData

@Model
final class TravelTrip {
    var id: UUID = UUID()
    var name: String = "" // 如：2025年10月青甘大环线
    var desc: String = "" // 行程描述
    var startDate: Date = Date()
    var endDate: Date = Date()
    var coverPhotoData: Data? // 封面图片
    
    @Relationship(deleteRule: .nullify)
    var destinations: [TravelDestination]?
    
    init(
        name: String,
        desc: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        coverPhotoData: Data? = nil
    ) {
        self.name = name
        self.desc = desc
        self.startDate = startDate
        self.endDate = endDate
        self.coverPhotoData = coverPhotoData
    }
    
    // 计算行程天数
    var durationDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return max((components.day ?? 0) + 1, 1)
    }
    
    // 计算目的地数量
    var destinationCount: Int {
        destinations?.count ?? 0
    }
}

