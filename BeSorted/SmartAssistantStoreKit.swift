//
//  SmartAssistantStoreKit.swift
//  BeSorted
//
//  StoreKit 2 — produkty, zakup i synchronizacja uprawnień Smart Assistant.
//

import Foundation
import StoreKit

/// Identyfikatory IAP (musi zgadzać się z `Products.storekit` / App Store Connect).
enum SmartAssistantProductID {
    static let standard = "jujug.BeSorted.smartAssistant.standard"
    static let plus = "jujug.BeSorted.smartAssistant.plus"
    static let pro = "jujug.BeSorted.smartAssistant.pro"
    static let plusFromStandard = "jujug.BeSorted.smartAssistant.plus.fromStandard"
    static let proFromStandard = "jujug.BeSorted.smartAssistant.pro.fromStandard"
    static let proFromPlus = "jujug.BeSorted.smartAssistant.pro.fromPlus"

    static var all: [String] {
        [standard, plus, pro, plusFromStandard, proFromStandard, proFromPlus]
    }

    /// Produkt do kupienia w zależności od posiadanych niższych planów (upgrade SKU).
    static func purchaseID(for tier: SmartAssistantTier, owned: (SmartAssistantTier) -> Bool) -> String {
        switch tier {
        case .standard:
            return standard
        case .plus:
            return owned(.standard) ? plusFromStandard : plus
        case .pro:
            if owned(.plus) { return proFromPlus }
            if owned(.standard) { return proFromStandard }
            return pro
        }
    }

    /// Tier odblokowany przez dany productID.
    static func unlockedTier(for productID: String) -> SmartAssistantTier? {
        switch productID {
        case standard:
            return .standard
        case plus, plusFromStandard:
            return .plus
        case pro, proFromStandard, proFromPlus:
            return .pro
        default:
            return nil
        }
    }
}

extension SmartAssistantStore {
    /// Wczytaj produkty StoreKit (wymaga `Products.storekit` w schemacie Run).
    @MainActor
    func loadStoreProducts() async {
        guard !isLoadingProducts else { return }
        setLoadingProducts(true)
        defer { setLoadingProducts(false) }

        do {
            let products = try await Product.products(for: Set(SmartAssistantProductID.all))
            var map: [String: Product] = [:]
            for product in products {
                map[product.id] = product
            }
            setStoreProducts(map, available: !map.isEmpty)
            // Nie nadpisuj lokalnego stanu przy starcie — uprawnienia wracają
            // przez udany zakup, Transaction.updates albo „Przywróć zakupy”.
        } catch {
            setStoreProducts([:], available: false)
            lastStoreError = error.localizedDescription
        }
    }

    /// Cena z StoreKit (jeśli produkt jest dostępny), inaczej katalogowa.
    func storeDisplayPrice(for tier: SmartAssistantTier) -> String {
        let id = SmartAssistantProductID.purchaseID(for: tier, owned: owns)
        if let product = storeProducts[id] {
            return product.displayPrice
        }
        return displayPriceLabel(for: tier)
    }

    /// Zakup przez StoreKit 2 — pokazuje systemowy arkusz. Zwraca `true` po sukcesie.
    @MainActor
    @discardableResult
    func purchase(_ tier: SmartAssistantTier) async -> Bool {
        guard SynclyCloudAccount.shared.canPurchaseSmartAssistant else {
            lastStoreError = SynclyCloudAccount.shared.smartAssistantPurchaseBlockedMessage
            return false
        }
        guard SmartAssistantDevice.canPurchase(tier) else { return false }
        guard !owns(tier) else {
            activateOwned(tier)
            return true
        }

        lastStoreError = nil
        let productID = SmartAssistantProductID.purchaseID(for: tier, owned: owns)

        if let product = storeProducts[productID] {
            setPurchasingTierID(tier.rawValue)
            defer { setPurchasingTierID(nil) }

            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    let transaction = try Self.checkVerified(verification)
                    grantEntitlement(for: transaction.productID, activate: tier)
                    await transaction.finish()
                    BeSortedSound.play(.regular)
                    return true
                case .userCancelled:
                    return false
                case .pending:
                    lastStoreError = "Zakup oczekuje na zatwierdzenie.".l10n
                    return false
                @unknown default:
                    return false
                }
            } catch {
                lastStoreError = error.localizedDescription
                return false
            }
        }

        // Bez skonfigurowanego StoreKit (np. brak pliku w schemacie) — lokalny fallback do UI.
        #if DEBUG
        grantLocalPurchase(tier)
        return true
        #else
        lastStoreError = "Produkty StoreKit są niedostępne.".l10n
        return false
        #endif
    }

    /// Przywróć zakupy (App Store sync + entitlements).
    @MainActor
    func restorePurchases() async {
        lastStoreError = nil
        setRestoringPurchases(true)
        defer { setRestoringPurchases(false) }
        do {
            try await AppStore.sync()
            await syncEntitlementsFromStoreKit(replaceLocal: true)
            BeSortedSound.play(.regular)
        } catch {
            lastStoreError = error.localizedDescription
        }
    }

    func startStoreKitListenersIfNeeded() {
        guard transactionListener == nil else { return }
        transactionListener = Task.detached(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try Self.checkVerified(update)
                    await MainActor.run {
                        self.grantEntitlement(for: transaction.productID, activate: nil)
                    }
                    await transaction.finish()
                } catch {
                    await MainActor.run {
                        self.lastStoreError = error.localizedDescription
                    }
                }
            }
        }
        Task { @MainActor in
            await loadStoreProducts()
        }
        Task { @MainActor in
            // Przy starcie uzupełnij uprawnienia z App Store (Apple ID) — zakupy
            // „wracają” po reinstalacji / na nowym urządzeniu, bez ręcznego Restore.
            await syncEntitlementsFromStoreKit(replaceLocal: false)
        }
    }

    @MainActor
    func syncEntitlementsFromStoreKit(replaceLocal: Bool) async {
        var entitled: Set<String> = replaceLocal ? [] : ownedTierIDs

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                if let tier = SmartAssistantProductID.unlockedTier(for: transaction.productID) {
                    for unlocked in tier.unlockedBundle {
                        entitled.insert(unlocked.rawValue)
                    }
                }
            } catch {
                continue
            }
        }

        replaceOwnedTier(entitled)
        if let active = activeTier, !owns(active) {
            activeTier = SmartAssistantTier.allCases
                .filter(owns)
                .max(by: { $0.rank < $1.rank })
        }
    }

    // MARK: - Private helpers

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    private func grantEntitlement(for productID: String, activate: SmartAssistantTier?) {
        guard let tier = SmartAssistantProductID.unlockedTier(for: productID) else { return }
        insertOwnedBundle(for: tier)
        if let activate {
            activeTier = activate
        } else if activeTier == nil {
            activeTier = tier
        }
    }

    @MainActor
    private func grantLocalPurchase(_ tier: SmartAssistantTier) {
        insertOwnedBundle(for: tier)
        activeTier = tier
        BeSortedSound.play(.regular)
    }
}
