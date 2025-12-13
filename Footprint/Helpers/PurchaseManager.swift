//
//  PurchaseManager.swift
//  Footprint
//
//  使用 StoreKit 2 管理订阅产品的加载、购买与恢复。
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        // 启动交易监听
        updateListenerTask = listenForTransactions()

        // 预加载产品与权益
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - 产品加载

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: SubscriptionProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "加载产品失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 购买与恢复

    func purchase(_ product: Product) async -> Transaction? {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                return transaction
            case .userCancelled:
                return nil
            case .pending:
                return nil
            @unknown default:
                return nil
            }
        } catch {
            errorMessage = "购买失败：\(error.localizedDescription)"
            return nil
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "恢复购买失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 交易监听

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(transactionResult)
            await transaction.finish()
            await updatePurchasedProducts()
        } catch {
            await MainActor.run {
                self.errorMessage = "交易验证失败：\(error.localizedDescription)"
            }
        }
    }

    // MARK: - 权益更新

    private func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                switch transaction.productType {
                case .autoRenewable, .nonConsumable:
                    purchasedIDs.insert(transaction.productID)
                default:
                    break
                }
            } catch {
                continue
            }
        }

        await MainActor.run {
            self.purchasedProductIDs = purchasedIDs
        }
    }

    // MARK: - 验证封装

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "PurchaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "交易未验证"])
        case .verified(let safe):
            return safe
        }
    }
}

