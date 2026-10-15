import Foundation
import Observation
import StoreKit

/// Owns the "Renewly Pro" lifetime unlock: loads the product, buys and restores it, and tracks entitlement.
@MainActor
@Observable
final class ProStore {
    nonisolated static let productID = "com.rokdobravec.renewly.pro"
    /// How many subscriptions the free plan can track.
    nonisolated static let freeLimit = 5
    private static let cacheKey = "isProUnlocked"

    enum PurchaseState: Equatable {
        case idle, purchasing, pending, failed(String)
    }

    private(set) var product: Product?
    /// Cached so Pro features don't flash locked at launch; confirmed against StoreKit in `refreshEntitlement()`.
    private(set) var isPro: Bool {
        didSet { UserDefaults.standard.set(isPro, forKey: Self.cacheKey) }
    }
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var isRestoring = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: Self.cacheKey)
        // Finish purchases made outside the app (Ask to Buy, other devices, refunds) as they arrive.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    /// Whether another subscription can be added on the current plan.
    func canAdd(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeLimit
    }

    func loadProduct() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refreshEntitlement() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isPro = unlocked
    }

    /// Returns true once Pro is unlocked.
    @discardableResult
    func purchase() async -> Bool {
        if product == nil { await loadProduct() }
        guard let product else {
            purchaseState = .failed("The App Store isn't reachable right now. Please try again.")
            return false
        }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                isPro = true
                purchaseState = .idle
                return true
            case .success(.unverified):
                purchaseState = .failed("The purchase couldn't be verified.")
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
        return false
    }

    /// Syncs with the App Store and re-reads entitlements. Returns whether Pro is unlocked afterwards.
    @discardableResult
    func restore() async -> Bool {
        isRestoring = true
        defer { isRestoring = false }
        try? await AppStore.sync()
        await refreshEntitlement()
        if !isPro { purchaseState = .failed("No previous purchase of Renewly Pro was found for this Apple Account.") }
        return isPro
    }

    func clearError() {
        if case .failed = purchaseState { purchaseState = .idle }
    }
}
