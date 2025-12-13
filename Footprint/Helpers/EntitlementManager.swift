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
        currentEntitlement.canAddDestination(currentCount: currentCount)
    }

    func canAddTripCard(currentCount: Int) -> Bool {
        currentEntitlement.canAddTripCard(currentCount: currentCount)
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

    // MARK: - 权益更新

    func updateEntitlement() {
        Task {
            let hasPro = await hasActiveProSubscription()
            let expiry = await latestExpiryDate()

            await MainActor.run {
                currentEntitlement = hasPro ? .pro : .free
                isSubscriptionActive = hasPro
                subscriptionExpiryDate = expiry
            }
        }
    }

    private func hasActiveProSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                switch transaction.productType {
                case .autoRenewable:
                    if transaction.productID == SubscriptionProductID.proMonthly ||
                        transaction.productID == SubscriptionProductID.proYearly {
                        return true
                    }
                case .nonConsumable:
                    if transaction.productID == SubscriptionProductID.proLifetime {
                        return true
                    }
                default:
                    break
                }
            } catch {
                continue
            }
        }
        return false
    }

    private func latestExpiryDate() async -> Date? {
        var latest: Date?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                // 终身买断无过期时间，直接返回 nil
                if transaction.productType == .nonConsumable &&
                    transaction.productID == SubscriptionProductID.proLifetime {
                    return nil
                }
                if transaction.productType == .autoRenewable &&
                    (transaction.productID == SubscriptionProductID.proMonthly ||
                     transaction.productID == SubscriptionProductID.proYearly) {
                    if let expiry = transaction.expirationDate {
                        if latest == nil || expiry > latest! {
                            latest = expiry
                        }
                    }
                }
            } catch {
                continue
            }
        }
        return latest
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

