//
//  ContentView.swift
//  Footprint
//
//  Created by K.X on 2025/10/19.
//

import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0
    /// 已实例化的 Tab 索引；默认仅加载地图 Tab，避免启动时多个 Tab 同时冷启动
    @State private var loadedTabs: Set<Int> = [0]
    @State private var tabPreloadTask: Task<Void, Never>?
    @State private var tabUIPreloadTask: Task<Void, Never>?
    @State private var reviewPromptTask: Task<Void, Never>?
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.isAppReady) private var isAppReady
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 足迹地图（个人）
            lazyTabContent(0) {
                // 仅选中时挂载；isMapTabActive 在挂载期间恒为 true，保留环境键供 MapView 内守卫复用
                MapView()
                    .environment(\.isMapTabActive, true)
            }
            .tabItem {
                Label {
                    Text("footprint_map".localized)
                } icon: {
                    Image(systemName: "map.fill")
                }
            }
            .tag(0)
            
            lazyTabContent(1) {
                JourneyCardsStackView()
            }
            .tabItem {
                Label {
                    Text("journey_cards_tab".localized)
                } icon: {
                    Image(systemName: "square.stack.3d.up.fill")
                }
            }
            .tag(1)

            lazyTabContent(2) {
                TimeCapsuleView()
            }
            .tabItem {
                Label {
                    Text("time_capsule_tab".localized)
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                }
            }
            .tag(2)
            
            lazyTabContent(3) {
                ProfileView()
            }
            .tabItem {
                Label {
                    Text("profile".localized)
                } icon: {
                    Image(systemName: "person.fill")
                }
            }
            .tag(3)
        }
        .tint(brandColorManager.currentBrandColor) // 使用品牌主题色，确保所有 tab 一致，并响应颜色变化
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            configureTabBarAppearance(for: colorScheme, brandColor: brandColorManager.currentBrandColor)
            // 默认选中足迹地图 tab 时不会触发 onChange(selectedTab)，定位改由此处与 scenePhase 统一启动（原 MapView.onAppear 已仅用于嵌入全屏地图）
            if selectedTab == 0 {
                LocationManager.shared.startUpdatingLocation(mode: .mapBrowsing)
            }
            // 只绑定上下文；数据/其它 Tab 等骨架期后再预热，避免抢开机动画与地图首帧
            TabListSnapshotStore.shared.attach(modelContext: modelContext)
            if isAppReady {
                scheduleDeferredTabPreloading()
            }
            AppReviewPromptManager.shared.seedDestinationCount(currentDestinationCount())
        }
        .onChange(of: isAppReady) { _, ready in
            // 主界面可见后再预热其它 Tab 数据与 UI（对齐骨架约 1s）
            if ready {
                scheduleDeferredTabPreloading()
            }
        }
        .onDisappear {
            tabPreloadTask?.cancel()
            tabUIPreloadTask?.cancel()
            reviewPromptTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .destinationUpdated)) { _ in
            scheduleReviewPromptIfNeeded()
        }
        .onChange(of: colorScheme) { newScheme in
            configureTabBarAppearance(for: newScheme, brandColor: brandColorManager.currentBrandColor)
        }
        .onChange(of: brandColorManager.currentBrandColor) { newColor in
            configureTabBarAppearance(for: colorScheme, brandColor: newColor)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Tab 切换不再重复 configureTabBarAppearance：全局 appearance 已在 onAppear / 主题与深浅色变化时设置；
            // 此前每次切换递归整窗 UIView + layoutIfNeeded 会加重首切 Tab 时的主线程卡顿。
            if newValue >= 0 {
                loadedTabs.insert(newValue)
            }
            let locationManager = LocationManager.shared
            if newValue == 0 {
                // 切换到地图 tab（足迹地图），启动实时定位
                locationManager.startUpdatingLocation(mode: .mapBrowsing)
                print("📍 切换到地图 tab，启动实时定位")
            } else if oldValue == 0 {
                // 错开一帧停止定位，避免与 Tab 首次挂载叠在同一帧
                Task { @MainActor in
                    locationManager.stopUpdatingLocation()
                }
                print("📍 离开地图 tab，停止实时定位")
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            let locationManager = LocationManager.shared
            // 仅在真正进后台时停定位；不要在 .inactive（控制中心/通知/回前台过渡）停，
            // 否则回前台会强制 stop→start，加重主线程突发负载。
            if newPhase == .background {
                locationManager.stopUpdatingLocation()
                print("📍 App 进入后台，停止实时定位")
            } else if newPhase == .active {
                TabListSnapshotStore.shared.refreshIfStaleOnForeground()
                if selectedTab == 0 {
                    locationManager.startUpdatingLocation(mode: .mapBrowsing)
                    print("📍 App 回到前台且在地图 tab，重新启动实时定位")
                }
            }
        }
    }

    @ViewBuilder
    private func lazyTabContent<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        if index == 0 {
            // 离屏卸载 MapView：切走即释放 MapKit，避免非地图 Tab 回前台时仍恢复离屏地图（卡 3～5s）
            if selectedTab == 0 {
                content()
            } else {
                Color.clear
            }
        } else if loadedTabs.contains(index) {
            content()
        } else {
            Color.clear
        }
    }

    private func currentDestinationCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<TravelDestination>())) ?? 0
    }

    /// 地点新增成功、相关 sheet 关闭后再请求系统评分弹窗
    private func scheduleReviewPromptIfNeeded() {
        let count = currentDestinationCount()
        guard AppReviewPromptManager.shared.consumeDestinationCount(count) else { return }

        reviewPromptTask?.cancel()
        reviewPromptTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            guard scenePhase == .active else { return }
            AppReviewPromptManager.shared.markRequested()
            requestReview()
        }
    }

    /// 主界面骨架约 1s 后再备其它 Tab 数据并预挂载，不抢开机动画与地图首帧
    private func scheduleDeferredTabPreloading() {
        guard isAppReady else { return }
        tabPreloadTask?.cancel()
        tabPreloadTask = Task(priority: .utility) { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            guard scenePhase == .active, isAppReady else { return }

            let snapshots = TabListSnapshotStore.shared
            snapshots.ensureJourneyTrips()
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }

            snapshots.ensureProfileData()
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }

            if let year = ProfileCacheStore.shared.timelineYearItems.first?.year {
                snapshots.loadYear(year)
            }

            scheduleOtherTabsUIPreload(delayNanoseconds: 120_000_000)
        }
    }

    /// 分批预挂载非地图 Tab，减轻首切卡顿（不取消数据预热任务）
    private func scheduleOtherTabsUIPreload(delayNanoseconds: UInt64 = 120_000_000) {
        tabUIPreloadTask?.cancel()
        tabUIPreloadTask = Task(priority: .userInitiated) { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            guard scenePhase == .active else { return }

            for index in 1...3 where !loadedTabs.contains(index) {
                loadedTabs.insert(index)
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled else { return }
                loadTabViewIfNeeded(at: index)
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled else { return }
            }
        }
    }

    /// 系统 Tab 懒加载未选中页；预挂载时强制 loadView，提前跑各 Tab onAppear
    private func loadTabViewIfNeeded(at index: Int) {
        guard let controllers = Self.tabBarControllerInKeyWindows()?.viewControllers,
              controllers.indices.contains(index) else { return }
        let controller = controllers[index]
        guard !controller.isViewLoaded else { return }
        controller.loadViewIfNeeded()
    }

    private static func tabBarControllerInKeyWindows() -> UITabBarController? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            let windows = windowScene.windows
            let ordered = windows.filter(\.isKeyWindow) + windows.filter { !$0.isKeyWindow }
            for window in ordered {
                if let tab = findTabBarController(from: window.rootViewController) {
                    return tab
                }
            }
        }
        return nil
    }

    private static func findTabBarController(from root: UIViewController?) -> UITabBarController? {
        guard let root else { return nil }
        var stack: [UIViewController] = [root]
        var index = 0
        while index < stack.count {
            let controller = stack[index]
            index += 1
            if let tab = controller as? UITabBarController {
                return tab
            }
            if let presented = controller.presentedViewController {
                stack.append(presented)
            }
            stack.append(contentsOf: controller.children)
        }
        return nil
    }

    private func configureTabBarAppearance(for scheme: ColorScheme, brandColor: Color) {
        // 使用品牌颜色作为选中颜色，确保所有 tab 一致
        let selectedColor: UIColor = UIColor(brandColor)
        let unselectedColor: UIColor = scheme == .dark ? UIColor.white.withAlphaComponent(0.6) : UIColor.secondaryLabel
        
        // 首先设置全局 tint 颜色，这是最关键的
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
        
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: scheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        appearance.backgroundColor = UIColor.clear
        
        // 配置所有布局样式（stacked 是主要使用的布局）
        let stackedLayout = appearance.stackedLayoutAppearance
        let inlineLayout = appearance.inlineLayoutAppearance
        let compactLayout = appearance.compactInlineLayoutAppearance
        
        // 选中状态：确保图标和文字颜色完全一致
        [stackedLayout, inlineLayout, compactLayout].forEach { layout in
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [
                .foregroundColor: selectedColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
        }
        
        // 未选中状态：确保图标和文字颜色完全一致
        [stackedLayout, inlineLayout, compactLayout].forEach { layout in
            layout.normal.iconColor = unselectedColor
            layout.normal.titleTextAttributes = [
                .foregroundColor: unselectedColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .regular)
            ]
        }
        
        // 应用外观配置
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // 使用 UITabBarItem.appearance 确保所有 TabBarItem 都应用颜色
        UITabBarItem.appearance().setTitleTextAttributes(
            [.foregroundColor: selectedColor],
            for: .selected
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.foregroundColor: unselectedColor],
            for: .normal
        )
        
        // 仅沿 UIViewController 树查找 UITabBarController，避免遍历 Map 等深层 UIView 子树
        DispatchQueue.main.async {
            Self.refreshTabBarsInKeyWindows(
                appearance: appearance,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor
            )
        }
    }
    
    /// 在窗口的根/子/模态 VC 链上查找 `UITabBarController`，更新其 `tabBar`（不做整树 `layoutIfNeeded`）。
    private static func refreshTabBarsInKeyWindows(
        appearance: UITabBarAppearance,
        selectedColor: UIColor,
        unselectedColor: UIColor
    ) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                guard let root = window.rootViewController else { continue }
                var stack: [UIViewController] = [root]
                var i = 0
                while i < stack.count {
                    let vc = stack[i]
                    i += 1
                    if let tab = vc as? UITabBarController {
                        let bar = tab.tabBar
                        bar.tintColor = selectedColor
                        bar.unselectedItemTintColor = unselectedColor
                        bar.standardAppearance = appearance
                        bar.scrollEdgeAppearance = appearance
                        bar.setNeedsLayout()
                    }
                    if let presented = vc.presentedViewController {
                        stack.append(presented)
                    }
                    stack.append(contentsOf: vc.children)
                }
            }
        }
    }
}
