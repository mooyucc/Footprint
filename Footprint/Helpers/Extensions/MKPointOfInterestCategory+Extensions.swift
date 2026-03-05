//
//  MKPointOfInterestCategory+Extensions.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的 MKPointOfInterestCategory 扩展
//

import MapKit

// MARK: - POI类别显示名称扩展
extension MKPointOfInterestCategory {
    /// POI类别的本地化显示名称
    var displayName: String {
        switch self {
        case .restaurant:
            return "restaurant".localized
        case .cafe:
            return "cafe".localized
        case .hotel:
            return "hotel".localized
        case .gasStation:
            return "gas_station".localized
        case .airport:
            return "airport".localized
        case .park:
            return "park".localized
        case .museum:
            return "museum".localized
        case .theater:
            return "theater".localized
        case .store:
            return "store".localized
        case .school:
            return "school".localized
        case .hospital:
            return "hospital".localized
        case .bank:
            return "bank".localized
        default:
            return "point_of_interest".localized
        }
    }
}
