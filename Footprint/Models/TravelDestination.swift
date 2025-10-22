//
//  TravelDestination.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class TravelDestination {
    var id: UUID = UUID()
    var name: String = ""
    var country: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var visitDate: Date = Date()
    var notes: String = ""
    var photoData: Data?
    var category: String = "国外" // 国内 or 国外
    var isFavorite: Bool = false
    var trip: TravelTrip? // 所属的旅行组
    
    init(
        name: String,
        country: String,
        latitude: Double,
        longitude: Double,
        visitDate: Date = Date(),
        notes: String = "",
        photoData: Data? = nil,
        category: String = "国外",
        isFavorite: Bool = false
    ) {
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.visitDate = visitDate
        self.notes = notes
        self.photoData = photoData
        self.category = category
        self.isFavorite = isFavorite
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

