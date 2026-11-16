//
//  FootprintApp.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData

@main
struct FootprintApp: App {
    @StateObject private var userProfileManager = UserProfileManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var entitlementManager = EntitlementManager.shared
    @StateObject private var aiCreditManager = AICreditManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var countryManager = CountryManager.shared
    @StateObject private var brandColorManager = BrandColorManager.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
    @State private var showSplash: Bool = BetaInfo.isBetaBuild ? false : true
    @State private var showOnboarding = !FirstLaunchManager.shared.hasCompletedOnboarding
    #if BETA
    @State private var showBetaReminder = !BetaInfo.isExpired
    @State private var showBetaExpiredReminder = BetaInfo.isExpired
    #endif
    
    var sharedModelContainer: ModelContainer = {
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(
                for: TravelDestination.self,
                    TravelTrip.self,
                    TravelRecommendation.self,
                    TravelRouteSegment.self,
                configurations: modelConfiguration
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Splash 期间不挂主界面，保证品牌动画不抢帧；关掉后再出骨架→内容
                if showSplash {
                    Color.white
                        .ignoresSafeArea()
                } else {
                    ContentView()
                        .environmentObject(userProfileManager)
                        .environmentObject(purchaseManager)
                        .environmentObject(entitlementManager)
                        .environmentObject(aiCreditManager)
                        .environmentObject(languageManager)
                        .environmentObject(countryManager)
                        .environmentObject(brandColorManager)
                        .environmentObject(appearanceManager)
                        .preferredColorScheme(appearanceManager.preferredColorScheme)
                        .onAppear { appearanceManager.syncInterfaceStyle() }
                        .onChange(of: appearanceManager.currentMode) { _, _ in
                            appearanceManager.syncInterfaceStyle()
                        }
                        .environment(\.isAppReady, isAppReady)
                }
                
                if showSplash {
                    SplashScreenView(isPresented: $showSplash)
                        .environmentObject(brandColorManager)
                        .zIndex(999)
                        .transition(.opacity)
                        .onAppear {
                            startBackgroundInitialization()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .splashScreenDismissed)) { _ in
                            startDeferredStorageMigration()
                            if !FirstLaunchManager.shared.hasCompletedOnboarding {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showOnboarding = true
                                }
                            }
                        }
                }
                
                if showOnboarding {
                    OnboardingCoordinatorView(isPresented: $showOnboarding)
                        .environmentObject(languageManager)
                        .environmentObject(countryManager)
                        .environmentObject(brandColorManager)
                        .environmentObject(appearanceManager)
                        .environmentObject(purchaseManager)
                        .environmentObject(entitlementManager)
                        .environmentObject(userProfileManager)
                        .zIndex(998)
                        .transition(.opacity)
                }
                
                #if BETA
                if showBetaReminder {
                    BetaReminderView(
                        daysRemaining: BetaInfo.displayRemainingDays,
                        expiryDate: BetaInfo.expiryDate,
                        onContinue: {
                            proceedFromBetaReminder()
                        },
                        onGoToStore: {
                            openAppStoreForRelease()
                        }
                    )
                    .zIndex(1000)
                    .transition(.opacity)
                }
                
                if showBetaExpiredReminder {
                    BetaExpiredView(
                        expiryDate: BetaInfo.expiryDate,
                        onGoToStore: openAppStoreForRelease
                    )
                    .zIndex(1001)
                    .transition(.opacity)
                }
                #endif
            }
            .onAppear {
                if !showSplash {
                    startBackgroundInitialization()
                    startDeferredStorageMigration()
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct IsAppReadyKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

private struct IsMapTabActiveKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isAppReady: Bool {
        get { self[IsAppReadyKey.self] }
        set { self[IsAppReadyKey.self] = newValue }
    }
    
    var isMapTabActive: Bool {
        get { self[IsMapTabActiveKey.self] }
        set { self[IsMapTabActiveKey.self] = newValue }
    }
}

extension FootprintApp {
    #if BETA
    private var isAppReady: Bool {
        !showSplash && !showOnboarding && !showBetaReminder && !showBetaExpiredReminder
    }
    #else
    private var isAppReady: Bool {
        !showSplash && !showOnboarding
    }
    #endif
    
    private static var didStartInitialization = false
    private static var didStartStorageMigration = false

    /// Splash 期间只做轻量工作，不建 Map、不打库
    private func startBackgroundInitialization() {
        guard !Self.didStartInitialization else { return }
        Self.didStartInitialization = true
        print("🚀 开始轻量初始化（与启动动画并行）...")
        
        DispatchQueue.main.async {
            aiCreditManager.grantFreeTrialIfNeeded()
            LocationManager.shared.requestLocation()
            print("📍 启动画面期间仅请求一次性定位")
            _ = ProfileCacheStore.shared
        }
    }
    
    private func startDeferredStorageMigration() {
        guard !Self.didStartStorageMigration else { return }
        Self.didStartStorageMigration = true
        
        let container = sharedModelContainer
        Task(priority: .utility) { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await PhotoExternalStorageMigrator.migrateIfNeeded(in: container.mainContext)
        }
    }
    
    #if BETA
    private func proceedFromBetaReminder() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showBetaReminder = false
            showSplash = true
        }
    }
    
    private func openAppStoreForRelease() {
        if let url = URL(string: "https://apps.apple.com/cn/app/墨鱼足迹/id6754274652") {
            UIApplication.shared.open(url)
        }
    }
    #endif
}
