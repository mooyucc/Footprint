//
//  RoutesView.swift
//  Footprint
//
//  Created by K.X on 2025/01/XX.
//

import SwiftUI
import SwiftData

struct RoutesView: View {
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()
    
    // 过滤出至少有2个地点的旅程
    private var validTrips: [TravelTrip] {
        trips.filter { trip in
            if let destinations = trip.destinations,
               !destinations.isEmpty,
               destinations.count >= 2 {
                return true
            }
            return false
        }
    }
    
    var body: some View {
        // 显示地图视图，并自动显示线路卡片
        MapView(autoShowRouteCards: true)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TravelTrip.self, TravelDestination.self,
        configurations: config
    )
    
    return RoutesView()
        .modelContainer(container)
        .environmentObject(LanguageManager.shared)
}

