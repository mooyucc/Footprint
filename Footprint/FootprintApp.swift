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
    @State private var showSplash: Bool = BetaInfo.isBetaBuild ? false : true  // 控制启动画面显示
    @State private var initializationCompleted = false  // 初始化是否完成
    @State private var showOnboarding = !FirstLaunchManager.shared.hasCompletedOnboarding  // 控制引导流程显示
    #if BETA
    // 首次启动日期会在访问 isExpired 时自动初始化（通过 expiryDate -> firstLaunchDate）
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
                // 主内容视图：仅在开机画面结束后构建，避免启动时 @Query 在主线程加载大量地点/行程导致动画卡顿
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
                        .environment(\.isAppReady, isAppReady)  // 传递应用就绪状态
                }
                
                // 启动画面（覆盖在主内容之上）
                if showSplash {
                    SplashScreenView(isPresented: $showSplash)
                        .environmentObject(brandColorManager)  // 传递 BrandColorManager 环境对象
                        .zIndex(999)  // 确保在最上层
                        .transition(.opacity)
                        .onAppear {
                            startBackgroundInitialization()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .splashScreenDismissed)) { _ in
                            // 启动画面关闭后，检查是否需要显示引导流程
                            if !FirstLaunchManager.shared.hasCompletedOnboarding {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showOnboarding = true
                                }
                            }
                        }
                }
                
                // 引导流程（覆盖在所有内容之上，但低于Beta提醒）
                if showOnboarding {
                    OnboardingCoordinatorView(isPresented: $showOnboarding)
                        .environmentObject(languageManager)
                        .environmentObject(countryManager)
                        .environmentObject(brandColorManager)
                        .environmentObject(appearanceManager)
                        .environmentObject(purchaseManager)
                        .environmentObject(entitlementManager)
                        .environmentObject(userProfileManager)
                        .zIndex(998)  // 低于启动画面和Beta提醒
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
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// 环境键：用于控制 MapView 是否应该延迟初始化定位和地理编码
private struct IsAppReadyKey: EnvironmentKey {
    static let defaultValue: Bool = true  // 默认值：已就绪（向后兼容）
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

// MARK: - 后台初始化逻辑
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

    private func startBackgroundInitialization() {
        guard !Self.didStartInitialization else { return }
        Self.didStartInitialization = true
        print("🚀 开始后台初始化工作...")
        
        // 在主线程启动定位服务（定位服务需要在主线程）
        DispatchQueue.main.async {
            // 1. 提前启动定位服务
            let locationManager = LocationManager.shared
            aiCreditManager.grantFreeTrialIfNeeded()
            locationManager.requestLocation()
            print("📍 启动画面期间仅请求一次性定位（持续定位在进入地图 Tab 后启动）")
            
            // 2. 提前创建 Geocoder（通过通知通知 MapView）
            // Geocoder 需要在 MapView 中创建，因为需要 @State 变量
            // 这里通过通知告知 MapView 可以提前创建
            NotificationCenter.default.post(name: .shouldPrepareGeocoder, object: nil)

            // 3. 触达 Profile 磁盘快照，Splash 结束前即可给「我的」首帧数字
            _ = ProfileCacheStore.shared
        }
        
        // 预热必须走视图主上下文；临时 context 的对象缓存不会留给各 Tab 的 @Query
        let container = sharedModelContainer
        Task { @MainActor in
            await MapDestinationFetcher.prewarmTabQueries(in: container.mainContext)
            NotificationCenter.default.post(name: .appInitializationCompleted, object: nil)
            // 旧内联多图/封面迁到外部存储：不阻塞 Splash，空闲时分批重写
            Task(priority: .utility) { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await PhotoExternalStorageMigrator.migrateIfNeeded(in: container.mainContext)
            }
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

// MARK: - 通知名称扩展
extension Notification.Name {
    static let shouldPrepareGeocoder = Notification.Name("shouldPrepareGeocoder")
}
