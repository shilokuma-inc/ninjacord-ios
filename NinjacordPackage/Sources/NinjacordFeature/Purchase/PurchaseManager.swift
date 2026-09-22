//
//  PurchaseManager.swift
//  NinjacordApp
//

import StoreKit

/// StoreKit 2 で Pro プラン（月額サブスクリプション）の購入・復元・トランザクション監視を行う。
/// 更新・返金・失効を取りこぼさないよう、起動直後に `shared` を生成して監視を始める
@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    enum ProductID {
        /// App Store Connect と StoreKit Configuration（NinjacordPro.storekit）に登録する ID と一致させる
        static let proMonthly = "ml.mrs1669.discord_bot_helper.pro.monthly"
        static let all: Set<String> = [proMonthly]
    }

    /// 購入の結果
    enum PurchaseOutcome {
        /// 購入が完了した
        case purchased
        /// 保護者の承認待ちなどで保留中。承認されると `Transaction.updates` で反映される
        case pending
        /// 利用者がキャンセルした
        case cancelled
    }

    /// App Store から取得した商品情報
    @Published private(set) var products: [Product] = []
    /// 現在有効な（購読中の）商品 ID
    @Published private(set) var purchasedProductIDs: Set<String> = []

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = observeTransactionUpdates()
        Task {
            await refreshPurchasedProducts()
        }
    }

    /// 商品情報を App Store から取得する
    func loadProducts() async throws {
        products = try await Product.products(for: ProductID.all)
    }

    /// 商品を購入する
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await refreshPurchasedProducts()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// 購入を復元する。App Store との同期でサインインを求められることがある
    func restore() async throws {
        try await AppStore.sync()
        await refreshPurchasedProducts()
    }

    /// 現在有効な購入を App Store の情報から集計し直す
    func refreshPurchasedProducts() async {
        var productIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            // 署名を検証できない購入は不正の可能性があるので有効として扱わない
            guard let transaction = try? Self.checkVerified(result),
                  transaction.revocationDate == nil else { continue }
            productIDs.insert(transaction.productID)
        }
        purchasedProductIDs = productIDs
    }

    /// アプリ外（別端末・自動更新・返金・保留中の承認など）で起きた購入の変化を反映する
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? Self.checkVerified(result) else { continue }
                await transaction.finish()
                await self?.refreshPurchasedProducts()
            }
        }
    }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
