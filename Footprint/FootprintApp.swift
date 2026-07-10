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
    @StateObject private var appleSignInManager = AppleSignInManager.shared
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
                        .environmentObject(appleSignInManager)
                        .environmentObject(purchaseManager)
                        .environmentObject(entitlementManager)
                        .environmentObject(aiCreditManager)
                        .environmentObject(languageManager)
                        .environmentObject(countryManager)
                        .environmentObject(brandColorManager)
                        .environmentObject(appearanceManager)
                        .preferredColorScheme(appearanceManager.preferredColorScheme)
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
                        .environmentObject(appleSignInManager)
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
        }
        .modelContainer(sharedModelContainer)
    }
}

// 环境键：用于控制 MapView 是否应该延迟初始化定位和地理编码
private struct IsAppReadyKey: EnvironmentKey {
    static let defaultValue: Bool = true  // 默认值：已就绪（向后兼容）
}

extension EnvironmentValues {
    var isAppReady: Bool {
        get { self[IsAppReadyKey.self] }
        set { self[IsAppReadyKey.self] = newValue }
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
    
    private func startBackgroundInitialization() {
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
        }
        
        // 在后台队列执行其他初始化工作
        DispatchQueue.global(qos: .userInitiated).async {
            // 3. 其他后台初始化工作
            // 注意：iCloud/CloudKit 同步已暂时禁用
            
            // 本地数据库初始化很快，不需要额外等待时间
            // 如果后续需要添加其他初始化工作，可以在这里添加
            
            // 给定位服务一些时间进行初始化（定位获取需要时间）
            // 同时确保开机动画有足够时间完整播放（色块→墨鱼→文字约 1s），
            // 再发送「初始化完成」，避免动画未播完就被关闭导致卡顿、直接进 app 的体验问题
            Thread.sleep(forTimeInterval: 1.2)
            
            print("✅ 后台初始化工作完成（定位服务已启动）")
            
            // 通知启动画面初始化完成（不等待定位完成，让定位在后台继续进行）
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .appInitializationCompleted, object: nil)
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
