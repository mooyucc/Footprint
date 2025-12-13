//
//  FirstLaunchManager.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import Foundation

/// 首次启动管理器，用于检测和管理应用的首次启动状态
class FirstLaunchManager {
    static let shared = FirstLaunchManager()
    
    /// UserDefaults 键名，用于存储首次启动标记
    private let hasCompletedOnboardingKey = "HasCompletedOnboarding"
    
    /// 是否已完成引导流程
    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey)
        }
    }
    
    private init() {
        // 单例模式，防止外部实例化
    }
    
    /// 标记引导流程已完成
    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
    }
    
    /// 重置引导流程（用于测试或重新显示引导）
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}

