//
//  EntitlementManager.swift
//  Footprint
//
//  负责将交易状态映射为应用内权益，供各功能点检查。
//

import Foundation
import StoreKit
import Combine

@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()

    @Published private(set) var currentEntitlement: SubscriptionEntitlement = .free
    @Published private(set) var subscriptionExpiryDate: Date?
    @Published private(set) var isSubscriptionActive: Bool = false
    @Published private(set) var currentSubscriptionProductID: String?
    @Published private(set) var hasLifetimePurchase: Bool = false
    /// 2026-08-31 前购买的终身版，继续享有无限 AI
    @Published private(set) var hasLegacyLifetimeUnlimitedAI: Bool = false
    /// 本期开始于 2026-09-05 前的月/年订阅，本期结束前继续享有无限 AI
    @Published private(set) var hasGrandfatheredSubscriptionUnlimitedAI: Bool = false

    private let purchaseManager = PurchaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        purchaseManager.$purchasedProductIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateEntitlement()
            }
            .store(in: &cancellables)

        updateEntitlement()
    }

    // MARK: - 对外便捷方法

    func entitlement() -> SubscriptionEntitlement {
        currentEntitlement
    }

    func canAddDestination(currentCount: Int) -> Bool {
        if BetaInfo.isBetaBuild { return true }
        return currentEntitlement.canAddDestination(currentCount: currentCount)
    }

    func canAddTripCard(currentCount: Int) -> Bool {
        if BetaInfo.isBetaBuild { return true }
        return currentEntitlement.canAddTripCard(currentCount: currentCount)
    }

    var canUseBasicShareLayouts: Bool {
        currentEntitlement.canUseBasicShareLayouts
    }

    var canUseFullShareLayouts: Bool {
        currentEntitlement.canUseFullShareLayouts
    }

    var canImportTrips: Bool {
        currentEntitlement.canImportTrips
    }

    var canLinkToSystemMaps: Bool {
        currentEntitlement.canLinkToSystemMaps
    }

    var canUseLocalDataIO: Bool {
        currentEntitlement.canUseLocalDataIO
    }
    
    var canUseAIFeatures: Bool {
        if BetaInfo.isBetaBuild { return true }
        return hasLegacyLifetimeUnlimitedAI || hasGrandfatheredSubscriptionUnlimitedAI
    }

    var maxPhotosPerDestination: Int {
        if BetaInfo.isBetaBuild { return ProTierLimits.maxPhotosPerDestination }
        return currentEntitlement.maxPhotosPerDestination
    }

    var shouldApplyShareWatermark: Bool {
        if BetaInfo.isBetaBuild { return false }
        return currentEntitlement.shouldApplyShareWatermark
    }

    func allowedTripShareLayouts() -> [TripShareLayout] {
        if BetaInfo.isBetaBuild || canUseFullShareLayouts {
            return TripShareLayout.allCases
        }
        return [.list]
    }

    func allowedDestinationShareLayouts() -> [DestinationShareLayout] {
        if BetaInfo.isBetaBuild || canUseFullShareLayouts {
            return DestinationShareLayout.allCases
        }
        return [.classic]
    }

    // MARK: - 权益更新

    func updateEntitlement() {
        Task {
            let snapshot = await resolveEntitlement()
            apply(snapshot)
        }
    }
    
    /// 基于刚完成的交易直接更新权益（用于购买成功后立即更新）
    /// 这个方法优先使用，因为它可以立即更新权益，不依赖 currentEntitlements 的延迟更新
    func updateEntitlement(from transaction: Transaction) {
        Task {
            print("🔄 基于交易直接更新权益: \(transaction.productID)")
            var snapshot = EntitlementSnapshot()

            snapshot.hasLifetime = hasLifetimePurchase
            snapshot.legacyLifetimeAI = hasLegacyLifetimeUnlimitedAI
            snapshot.grandfatheredSubscriptionAI = hasGrandfatheredSubscriptionUnlimitedAI

            switch transaction.productType {
            case .autoRenewable:
                if transaction.productID == SubscriptionProductID.proMonthly ||
                    transaction.productID == SubscriptionProductID.proYearly {
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            snapshot.entitlement = .pro
                            snapshot.productID = transaction.productID
                            snapshot.expiry = expirationDate
                            snapshot.grandfatheredSubscriptionAI = SubscriptionAIPolicy.includesUnlimitedAI(
                                periodPurchaseDate: transaction.purchaseDate
                            )
                            print("✅ 订阅有效: \(transaction.productID), 到期: \(expirationDate)，本期无限 AI=\(snapshot.grandfatheredSubscriptionAI)")
                        } else {
                            let timeSincePurchase = Date().timeIntervalSince(transaction.purchaseDate)
                            if timeSincePurchase < 5 * 60 {
                                snapshot.entitlement = .pro
                                snapshot.productID = transaction.productID
                                snapshot.expiry = expirationDate
                                snapshot.grandfatheredSubscriptionAI = SubscriptionAIPolicy.includesUnlimitedAI(
                                    periodPurchaseDate: transaction.purchaseDate
                                )
                                print("⚠️ 订阅刚购买但已过期（可能是沙箱环境），仍认为有效: \(transaction.productID)，本期无限 AI=\(snapshot.grandfatheredSubscriptionAI)")
                            } else {
                                print("⚠️ 订阅已过期且购买时间超过5分钟: \(transaction.productID)")
                            }
                        }
                    } else {
                        snapshot.entitlement = .pro
                        snapshot.productID = transaction.productID
                        snapshot.grandfatheredSubscriptionAI = SubscriptionAIPolicy.includesUnlimitedAI(
                            periodPurchaseDate: transaction.purchaseDate
                        )
                        print("⚠️ 订阅没有过期时间: \(transaction.productID)，本期无限 AI=\(snapshot.grandfatheredSubscriptionAI)")
                    }
                }
            case .nonConsumable:
                if transaction.productID == SubscriptionProductID.proLifetime {
                    snapshot.hasLifetime = true
                    snapshot.legacyLifetimeAI = LifetimeAIPolicy.includesUnlimitedAI(
                        originalPurchaseDate: transaction.originalPurchaseDate
                    )
                    if currentEntitlement == .pro {
                        snapshot.entitlement = .pro
                        snapshot.productID = currentSubscriptionProductID
                        snapshot.expiry = subscriptionExpiryDate
                        snapshot.grandfatheredSubscriptionAI = hasGrandfatheredSubscriptionUnlimitedAI
                    } else {
                        snapshot.entitlement = .proLifetime
                        snapshot.productID = transaction.productID
                        snapshot.expiry = nil
                        snapshot.grandfatheredSubscriptionAI = false
                    }
                    print("✅ 终身买断: \(transaction.productID)，兼容无限 AI=\(snapshot.legacyLifetimeAI)，购买日=\(transaction.originalPurchaseDate)")
                }
            default:
                break
            }

            if snapshot.entitlement == .free && currentEntitlement.isPaid {
                snapshot.entitlement = currentEntitlement
                snapshot.productID = currentSubscriptionProductID
                snapshot.expiry = subscriptionExpiryDate
                snapshot.legacyLifetimeAI = hasLegacyLifetimeUnlimitedAI || snapshot.legacyLifetimeAI
                snapshot.grandfatheredSubscriptionAI = hasGrandfatheredSubscriptionUnlimitedAI || snapshot.grandfatheredSubscriptionAI
            }

            apply(snapshot)
            print("🔄 权益更新完成: entitlement=\(snapshot.entitlement), productID=\(snapshot.productID ?? "nil")")
        }
    }

    private struct EntitlementSnapshot {
        var entitlement: SubscriptionEntitlement = .free
        var productID: String?
        var expiry: Date?
        var hasLifetime: Bool = false
        var legacyLifetimeAI: Bool = false
        var grandfatheredSubscriptionAI: Bool = false
    }

    private func apply(_ snapshot: EntitlementSnapshot) {
        currentEntitlement = snapshot.entitlement
        isSubscriptionActive = snapshot.entitlement.isPaid
        subscriptionExpiryDate = snapshot.expiry
        currentSubscriptionProductID = snapshot.productID
        hasLifetimePurchase = snapshot.hasLifetime
        hasLegacyLifetimeUnlimitedAI = snapshot.legacyLifetimeAI
        hasGrandfatheredSubscriptionUnlimitedAI = snapshot.grandfatheredSubscriptionAI
        AppAlternateIconSync.applyHomeScreenIcon(isProActive: snapshot.entitlement.isPaid)
    }

    /// 订阅优先于终身：有有效月/年订阅则为 `.pro`；仅终身则为 `.proLifetime`。
    /// 无限 AI 不随 `.pro` 附带，仅兼容旧终身与本期开始于政策日前的订阅。
    private func resolveEntitlement() async -> EntitlementSnapshot {
        var snapshot = EntitlementSnapshot()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                switch transaction.productType {
                case .autoRenewable:
                    if transaction.productID == SubscriptionProductID.proMonthly ||
                        transaction.productID == SubscriptionProductID.proYearly {
                        let isValid: Bool
                        if let expirationDate = transaction.expirationDate {
                            isValid = expirationDate > Date()
                            if isValid {
                                snapshot.expiry = expirationDate
                            } else {
                                print("⚠️ 订阅已过期: \(transaction.productID), 到期时间: \(expirationDate)")
                            }
                        } else {
                            isValid = true
                            print("⚠️ 订阅没有过期时间: \(transaction.productID)")
                        }
                        if isValid {
                            snapshot.entitlement = .pro
                            snapshot.productID = transaction.productID
                            snapshot.grandfatheredSubscriptionAI = SubscriptionAIPolicy.includesUnlimitedAI(
                                periodPurchaseDate: transaction.purchaseDate
                            )
                            print("✅ 找到有效订阅: \(transaction.productID)，本期无限 AI=\(snapshot.grandfatheredSubscriptionAI)")
                        }
                    }
                case .nonConsumable:
                    if transaction.productID == SubscriptionProductID.proLifetime {
                        snapshot.hasLifetime = true
                        snapshot.legacyLifetimeAI = LifetimeAIPolicy.includesUnlimitedAI(
                            originalPurchaseDate: transaction.originalPurchaseDate
                        )
                        print("✅ 找到终身买断: \(transaction.productID)，兼容无限 AI=\(snapshot.legacyLifetimeAI)，购买日=\(transaction.originalPurchaseDate)")
                    }
                default:
                    break
                }
            } catch {
                print("❌ 交易验证失败: \(error)")
                continue
            }
        }

        if snapshot.entitlement == .pro {
            return snapshot
        }
        if snapshot.hasLifetime {
            snapshot.entitlement = .proLifetime
            snapshot.productID = SubscriptionProductID.proLifetime
            snapshot.expiry = nil
            snapshot.grandfatheredSubscriptionAI = false
            return snapshot
        }

        print("ℹ️ 未找到有效的 Pro 订阅")
        return snapshot
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "EntitlementManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "交易未验证"])
        case .verified(let safe):
            return safe
        }
    }
}

