import Foundation
import Observation
import os
import StoreKit

@MainActor
@Observable
final class StoreKitService {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var purchaseError: String?

    var hasActiveSubscription: Bool { !purchasedProductIDs.isEmpty }

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    static let monthlyProductID = "com.grubshelf.premium.monthly"
    static let yearlyProductID = "com.grubshelf.premium.yearly"
    private static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]
    private static let logger = Logger(subsystem: "com.grubshelf", category: "StoreKit")

    @ObservationIgnored private var subscriptionService: SubscriptionService?
    @ObservationIgnored private var householdId: UUID?
    @ObservationIgnored private var userId: UUID?
    @ObservationIgnored private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {}

    deinit {
        transactionListener?.cancel()
    }

    /// Call after SubscriptionService is ready to wire backend sync.
    func configure(subscriptionService: SubscriptionService, householdId: UUID, userId: UUID) {
        self.subscriptionService = subscriptionService
        self.householdId = householdId
        self.userId = userId
        startTransactionListener()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
            await updatePurchasedProducts()
        } catch {
            Self.logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        purchaseError = nil
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await syncWithBackend(transaction: transaction)
            await updatePurchasedProducts()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            purchaseError = "Purchase is pending approval."
            return nil

        @unknown default:
            purchaseError = "An unknown purchase result occurred."
            return nil
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            Self.logger.error("Restore failed: \(error.localizedDescription)")
            purchaseError = "Failed to restore purchases."
        }
    }

    // MARK: - Entitlements

    func updatePurchasedProducts() async {
        var activeIDs: Set<String> = []

        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.revocationDate == nil {
                    activeIDs.insert(transaction.productID)
                }
            }
        }

        purchasedProductIDs = activeIDs

        // Reconcile with backend
        if let sub = subscriptionService, let hid = householdId {
            if !activeIDs.isEmpty && sub.isFree {
                // Apple says premium but backend says free — re-sync
                if let firstActive = activeIDs.first {
                    Self.logger.info("Reconciling: Apple active but backend free")
                    try? await sub.activatePremium(
                        userId: userId ?? UUID(),
                        householdId: hid,
                        externalSubscriptionId: firstActive
                    )
                }
            }
        }
    }

    // MARK: - Transaction listener

    private func startTransactionListener() {
        transactionListener?.cancel()
        transactionListener = Task(priority: .background) { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.syncWithBackend(transaction: transaction)
                    await self.updatePurchasedProducts()
                }
            }
        }
    }

    // MARK: - Backend sync

    private func syncWithBackend(transaction: StoreKit.Transaction) async {
        guard let sub = subscriptionService,
              let hid = householdId,
              let uid = userId else { return }

        do {
            try await withRetry(maxAttempts: 3, initialDelay: .seconds(1)) {
                try await sub.activatePremium(
                    userId: uid,
                    householdId: hid,
                    externalSubscriptionId: String(transaction.originalID)
                )
            }
            Self.logger.info("Backend synced for transaction \(transaction.originalID)")
        } catch {
            Self.logger.error("Backend sync failed after retries: \(error.localizedDescription)")
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
