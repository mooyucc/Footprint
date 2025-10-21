//
//  FootprintApp.swift
//  Footprint
//
//  Created by 徐化军 on 2025/10/19.
//

import SwiftUI
import SwiftData

@main
struct FootprintApp: App {
    @StateObject private var appleSignInManager = AppleSignInManager.shared
    
    var sharedModelContainer: ModelContainer = {
        // 启用 iCloud CloudKit 同步
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // 启用 iCloud 同步
        )

        do {
            return try ModelContainer(
                for: TravelDestination.self, TravelTrip.self,
                configurations: modelConfiguration
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appleSignInManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
