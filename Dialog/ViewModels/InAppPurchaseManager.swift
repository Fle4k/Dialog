import Foundation
import StoreKit
import Combine

@MainActor
final class InAppPurchaseManager: ObservableObject {
    static let shared = InAppPurchaseManager()
    
    @Published var hasUnlimitedScenes: Bool = false
    @Published var hasAdditionalSpeakers: Bool = false
    @Published var isLoading: Bool = false
    @Published var purchaseError: String?
    
    // Product identifier - must match what you set in App Store Connect
    private let unlimitedScenesProductID = "de.metame.Dialog.unlimited_scenes"
    
    private var updateListenerTask: Task<Void, Error>? = nil
    private let userDefaults = UserDefaults.standard
    private let hasUnlimitedScenesKey = "hasUnlimitedScenes"
    private let hasAdditionalSpeakersKey = "hasAdditionalSpeakers"
    
    init() {
        loadPurchaseStatus()
        startTransactionListener()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Purchase Status
    private func loadPurchaseStatus() {
        hasUnlimitedScenes = userDefaults.bool(forKey: hasUnlimitedScenesKey)
        hasAdditionalSpeakers = userDefaults.bool(forKey: hasAdditionalSpeakersKey)
    }
    
    private func savePurchaseStatus() {
        userDefaults.set(hasUnlimitedScenes, forKey: hasUnlimitedScenesKey)
        userDefaults.set(hasAdditionalSpeakers, forKey: hasAdditionalSpeakersKey)
    }
    
    // MARK: - StoreKit Integration
    func startTransactionListener() {
        updateListenerTask = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchaseStatus(for: transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    @discardableResult
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    func requestProducts() async {
        do {
            let _ = try await Product.products(for: [unlimitedScenesProductID])
            // Products loaded successfully
        } catch {
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    func purchase() async {
        guard !isLoading else { return }
        
        isLoading = true
        purchaseError = nil
        
        do {
            let products = try await Product.products(for: [unlimitedScenesProductID])
            
            guard let product = products.first else {
                purchaseError = "Product not found"
                isLoading = false
                return
            }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchaseStatus(for: transaction)
                await transaction.finish()
                
            case .userCancelled:
                break
                
            case .pending:
                // Handle pending transaction (family sharing, etc.)
                break
                
            default:
                break
            }
            
        } catch StoreError.failedVerification {
            purchaseError = "Your purchase could not be verified by the App Store."
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        
        do {
            try await AppStore.sync()
            
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)
                    await updatePurchaseStatus(for: transaction)
                } catch {
                    print("Failed to verify transaction: \(error)")
                }
            }
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func updatePurchaseStatus(for transaction: Transaction) async {
        if transaction.productID == unlimitedScenesProductID {
            hasUnlimitedScenes = true
            hasAdditionalSpeakers = true
            savePurchaseStatus()
        }
    }
    
    // MARK: - Helper Methods
    func canCreateNewScene(currentSceneCount: Int) -> Bool {
        return hasUnlimitedScenes || currentSceneCount < 5
    }
    
    func getRemainingFreeScenes(currentSceneCount: Int) -> Int {
        return hasUnlimitedScenes ? Int.max : max(0, 5 - currentSceneCount)
    }
    
    func canUseAdditionalSpeakers() -> Bool {
        return hasAdditionalSpeakers
    }
    
    func canAddSpeaker(beyondAB: Bool) -> Bool {
        if !beyondAB {
            return true  // A and B are always available
        }
        return hasAdditionalSpeakers  // C and D require premium
    }
}

enum StoreError: Error {
    case failedVerification
} 