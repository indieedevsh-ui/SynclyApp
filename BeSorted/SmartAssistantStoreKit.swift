//
//  SmartAssistantStoreKit.swift
//  BeSorted
//
//  StoreKit 2 — produkty, zakup i synchronizacja uprawnień Smart Assistant.
//
//  ZASADA: źródłem prawdy o zakupie jest wyłącznie App Store, a konkretnie
//  podpisany JWS z `Transaction.currentEntitlements`. Wszystko inne
//  (UserDefaults, Keychain) jest cache, który nigdy nie przyznaje uprawnień
//  sam z siebie. Dzięki temu zakup przeżywa usunięcie aplikacji, utratę
//  danych i reinstalację — App Store trzyma go powiązanego z Apple ID.
//

import Foundation
import StoreKit

/// Identyfikatory IAP.
///
/// Product ID są **ustawione ręcznie w App Store Connect** i nie muszą być
/// prefiksem bundle ID. Jedynym wymogiem jest, żeby identyfikatory w kodzie
/// odpowiadały co do znaku produktom przypisanym do `com.michaelproduct.syncly`
/// — przy niezgodności `Product.products(for:)` zwraca pustą listę i zakup
/// jest niemożliwy. Ta sama wartość musi być w `Products.storekit`, żeby
/// testy lokalne odwzorowywały produkcję.
enum SmartAssistantProductID {
    /// Plan bazowy — sprzedawany jako `SA_Basic.syncly`.
    static let standard = "SA_Basic.syncly"
    /// Plan średni — sprzedawany jako `SA_PLUS.syncly`.
    static let plus = "SA_PLUS.syncly"
    /// Plan najwyższy — sprzedawany jako `SA_PRO.syncly`.
    static let pro = "SA_PRO.syncly"

    /// Prefiks pierwszego wydania. Zakupy zrobione na tych ID NADAL istnieją
    /// w `Transaction.currentEntitlements`, więc muszą być rozpoznane — inaczej
    /// użytkownik po aktualizacji straciłby wykupiony plan.
    static let legacyPrefix = "jujug.BeSorted.smartAssistant."

    /// Prefiks użyty w wydaniach po zmianie bundle ID, ale przed podaniem
    /// identyfikatorów z App Store Connect. Rozpoznawany wyłącznie przy
    /// odtwarzaniu; nigdy pod nim nie sprzedajemy.
    static let previousPrefix = "com.michaelproduct.syncly.smartAssistant."

    /// Identyfikatory, o które prosimy sklep. Tylko te trzy istnieją
    /// w App Store Connect — proszenie o nieistniejące warianty upgrade'u
    /// niczego nie zmienia, a dokładna lista ułatwia diagnostykę.
    static var all: [String] { [standard, plus, pro] }

    /// Identyfikatory, pod którymi da się kupić plan — pierwszy istniejący
    /// w sklepie wygrywa. Warianty `fromStandard`/`fromPlus` zostały usunięte
    /// z App Store Connect, więc zakupy są realizowane zwykłym planem bazowym,
    /// a posiadanie niższego planu nie blokuje kupna wyższego.
    static func purchaseIDVariants(for tier: SmartAssistantTier, owned: (SmartAssistantTier) -> Bool) -> [String] {
        _ = owned
        switch tier {
        case .standard: return [standard]
        case .plus: return [plus]
        case .pro: return [pro]
        }
    }

    /// Preferowany identyfikator zakupu.
    static func purchaseID(for tier: SmartAssistantTier, owned: (SmartAssistantTier) -> Bool) -> String {
        purchaseIDVariants(for: tier, owned: owned)[0]
    }

    /// Czy productID pochodzi z wcześniejszych prefiksów (kupiony przed obecnymi
    /// identyfikatorami). Taki plan jest nadal ważny, więc nie zgłaszamy tego
    /// jako problemu — służy wyłącznie do informacji w logu.
    static func isLegacy(_ productID: String) -> Bool {
        productID.hasPrefix(legacyPrefix) || productID.hasPrefix(previousPrefix)
    }

    /// Tier odblokowany przez dany productID.
    ///
    /// Bieżące identyfikatory (`SA_*.syncly`) sprawdzamy wprost, bo nie są
    /// prefiksem z sufiksem. Prefiksy z poprzednich wydań rozpoznajemy po
    /// sufiksie, żeby zakupy zrobione przed zmianą identyfikatorów zostały
    /// odtworzone zamiast zignorowane.
    static func unlockedTier(for productID: String) -> SmartAssistantTier? {
        switch productID {
        case standard: return .standard
        case plus: return .plus
        case pro: return .pro
        default: break
        }

        for knownPrefix in [previousPrefix, legacyPrefix] {
            guard productID.hasPrefix(knownPrefix) else { continue }
            let suffix = String(productID.dropFirst(knownPrefix.count))
            switch suffix {
            case "standard":
                return .standard
            case "plus", "plus.fromStandard":
                return .plus
            case "pro", "pro.fromStandard", "pro.fromPlus":
                return .pro
            default:
                return nil
            }
        }
        return nil
    }
}

extension SmartAssistantStore {
    // MARK: - Produkty

    /// Wczytaj produkty StoreKit (wymaga `Products.storekit` w schemacie Run).
    ///
    /// Katalog wczytuje się dopiero przy otwarciu paywalla — nie przy starcie,
    /// żeby pobranie oferty (i jakiekolwiek działania sklepu) nie ruszało razem
    /// z aplikacją. Współbieżne wywołania mają się **scalić** w jedno pobranie,
    /// a nie zostać odrzucone: wcześniej `guard` zwracał natychmiast, więc
    /// naciśnięcie „Kup” w tej oknie kończyło się fałszywym
    /// „Produkty StoreKit są niedostępne.”
    @MainActor
    func loadStoreProducts() async {
        if let pending = loadProductsTask {
            await pending.value
            return
        }
        if !storeProducts.isEmpty { return }

        let task = Task { @MainActor in
            defer { clearLoadProductsTask() }
            await fetchStoreProducts()
        }
        setLoadProductsTask(task)
        await task.value
    }

    /// Pobrać katalog, a pustą odpowiedź potraktować jako „jeszcze nie”, nie
    /// jako „nie istnieje”.
    ///
    /// Świeżo zainstalowana aplikacja — szczególnie z TestFlight — startuje,
    /// zanim sklep zdąży pobrać katalog, więc pierwsze `products(for:)`
    /// potrafi zwrócić pustą listę **bez błędu** — dlatego odczyt powtarzamy
    /// z rosnącymi odstępami.
    ///
    /// NIGDY nie wołamy tutaj `AppStore.sync()`: przy starcie potrafił
    /// wyświetlić systemowe okno „Sign in to Apple Account”. Odświeżenie
    /// konta App Store zostaje wyłącznie przy jawnej akcji „Przywróć zakupy”.
    @MainActor
    private func fetchStoreProducts() async {
        setLoadingProducts(true)
        defer { setLoadingProducts(false) }

        let ids = Set(SmartAssistantProductID.all)
        // 0 s na pierwszym odczycie, potem krótkie odstępy — nie blokujemy UI.
        let delays: [UInt64] = [0, 1, 3, 8]
        var lastError: String?

        for attempt in delays.indices {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: delays[attempt] * 1_000_000_000)
            }

            do {
                let products = try await Product.products(for: ids)
                var map: [String: Product] = [:]
                for product in products { map[product.id] = product }

                if !map.isEmpty {
                    setStoreProducts(map, available: true)
                    clearStaleCatalogError()
                    #if DEBUG
                    if !missingProductIDs.isEmpty {
                        print("[StoreKit] App Store nie zwrócił: \(missingProductIDs.sorted())")
                    }
                    #endif
                    return
                }

                #if DEBUG
                print("[StoreKit] Pusta oferta (próba \(attempt + 1)/\(delays.count)) dla \(SmartAssistantProductID.all).")
                #endif
            } catch {
                lastError = error.localizedDescription
                #if DEBUG
                print("[StoreKit] Błąd pobrania oferty: \(error)")
                #endif
            }
        }

        setStoreProducts([:], available: false)
        if let lastError {
            lastStoreError = lastError
        }
    }

    /// Product ID, których App Store nie zwrócił — sygnał niezgodności
    /// identyfikatorów z tymi z App Store Connect.
    var missingProductIDs: Set<String> {
        guard productsAvailable else { return [] }
        return Set(SmartAssistantProductID.all).subtracting(storeProducts.keys)
    }

    /// Cena z StoreKit (jeśli produkt jest dostępny), inaczej katalogowa.
    func storeDisplayPrice(for tier: SmartAssistantTier) -> String {
        let id = SmartAssistantProductID.purchaseID(for: tier, owned: owns)
        if let product = storeProducts[id] {
            return product.displayPrice
        }
        return displayPriceLabel(for: tier)
    }

    // MARK: - Zakup

    /// Zakup przez StoreKit 2 — pokazuje systemowy arkusz. Zwraca `true` po sukcesie.
    @MainActor
    @discardableResult
    func purchase(_ tier: SmartAssistantTier) async -> Bool {
        guard SynclyCloudAccount.shared.canPurchaseSmartAssistant else {
            lastStoreError = SynclyCloudAccount.shared.smartAssistantPurchaseBlockedMessage
            return false
        }
        guard SmartAssistantDevice.canPurchase(tier) else {
            lastStoreError = "Niedostępne do zakupu".l10n
            return false
        }
        guard !owns(tier) else {
            activateOwned(tier)
            return true
        }

        lastStoreError = nil
        let productID = resolvedPurchaseID(for: tier)

        // Brak produktu = twardy błąd. Nigdy nie przyznajemy planu bez
        // potwierdzonej transakcji — inaczej „zakup” ginąłby po usunięciu aplikacji.
        guard let product = storeProducts[productID] else {
            await loadStoreProducts()
            // Po ponownym wczytaniu trzeba sprawdzić identyfikator od nowa: przy
            // pierwszym sprawdzeniu oferta mogła nie być jeszcze wczytana.
            let retryID = resolvedPurchaseID(for: tier)
            guard let retryProduct = storeProducts[retryID] else {
                // Komunikat musi sam mówić, czego szukamy — w buildzie z
                // TestFlight nie ma konsoli, a przyczyną bywa różnica jednego
                // znaku między ID w kodzie a ID w App Store Connect.
                let returned = storeProducts.count
                let searched = SmartAssistantProductID.all.sorted().joined(separator: ", ")
                lastStoreError = "Produkty StoreKit są niedostępne — sklep zwrócił \(returned) z \(SmartAssistantProductID.all.count) dla \(Bundle.main.bundleIdentifier ?? "?"). Szukane ID: \(searched).".l10n
                #if DEBUG
                print("[StoreKit] Brak produktu dla \(SmartAssistantProductID.purchaseIDVariants(for: tier, owned: owns)) — brak ich w App Store Connect?")
                #endif
                return false
            }
            return await completePurchase(retryProduct, for: tier)
        }

        return await completePurchase(product, for: tier)
    }

    @MainActor
    private func completePurchase(_ product: Product, for tier: SmartAssistantTier) async -> Bool {
        setPurchasingTierID(tier.rawValue)
        defer { setPurchasingTierID(nil) }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                // JWS zweryfikowany kryptograficznie → zapis jest trwały.
                grantEntitlement(
                    for: transaction.productID,
                    activate: tier,
                    transaction: transaction
                )
                await transaction.finish()
                BeSortedSound.play(.regular)
                return true
            case .userCancelled:
                return false
            case .pending:
                // „Ask to Buy” — transakcja dojdzie przez Transaction.updates.
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

    // MARK: - Przywracanie

    /// Przywróć zakupy — jawne `AppStore.sync()` (może pokazać monit systemowy)
    /// i pełna rekonsyliacja z App Store.
    @MainActor
    func restorePurchases() async {
        lastStoreError = nil
        setRestoringPurchases(true)
        defer { setRestoringPurchases(false) }
        do {
            try await AppStore.sync()
        } catch {
            lastStoreError = error.localizedDescription
        }
        // Rekonsyliacja mimo błędu `AppStore.sync()`: obiekty transakcji
        // `currentEntitlements` i tak odczytujemy lokalnie z pliku `.storekit`
        // albo z konta App Store. Bez tego przy błędzie przycisku „Przywróć zakupy”
        // nie dałoby się skasować stanu, którego sklep nie potwierdza.
        let reachedStore = await syncEntitlementsFromStoreKit()
        if reachedStore {
            BeSortedSound.play(.regular)
        } else {
            lastStoreError = lastStoreError ?? "Nie udało się połączyć ze sklepem. Spróbuj ponownie przy połączeniu z internetem.".l10n
            BeSortedSound.play(.skillNo)
        }
    }

    /// Odśwież uprawnienia przy powrocie do aplikacji (foreground) — łapie
    /// zatwierdzenia „Ask to Buy”, zakupy z innego urządzenia i Family Sharing.
    /// Używa cichej ścieżki (bez `AppStore.sync()`).
    @MainActor
    func refreshEntitlementsFromStore() async {
        await syncEntitlementsFromStoreKitQuietly()
    }

    // MARK: - Nasłuch i start

    func startStoreKitListenersIfNeeded() {
        guard transactionListener == nil else { return }

        transactionListener = Task.detached(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try Self.checkVerified(update)

                    // Refund, zwrot rodzinny albo wygaśnięcie: NIE przyznajemy
                    // ponownie — użytkownik już tego nie posiada. Zamiast tego
                    // przepuszczamy transakcję i przebudowujemy stan z App Store.
                    let revoked = transaction.revocationDate != nil
                    let expired = transaction.expirationDate.map { $0 <= Date() } ?? false

                    if revoked || expired {
                        await transaction.finish()
                        await MainActor.run {
                            self.handleEntitlementRevocation(of: transaction.productID)
                        }
                        continue
                    }

                    await MainActor.run {
                        self.grantEntitlement(
                            for: transaction.productID,
                            activate: nil,
                            transaction: transaction
                        )
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
            // Jedna cicha rekonsyliacja przy starcie. Wcześniejszy retry (0/2/6/15/40 s)
            // przy braku konta App Store pokazywał „Sign in to Apple Account” wielokrotnie
            // w jednej sesji. Zakupy po reinstalacji wracają też z Keychain + przy
            // jawnym „Przywróć zakupy” (`AppStore.sync()`).
            await self.syncEntitlementsFromStoreKitQuietly()
        }
    }

    /// Cichy odczyt `Transaction.currentEntitlements` — bez `AppStore.sync()`
    /// i bez ponawiania, które odpalało systemowe logowanie Apple w kółko.
    @MainActor
    func syncEntitlementsFromStoreKitQuietly() async {
        _ = await syncEntitlementsFromStoreKit()
    }

    // MARK: - Synchronizacja

    /// Rekonsyliuje uprawnienia z `Transaction.currentEntitlements`.
    ///
    /// Sklep jest **autorytatywny**: gdy udało się do niego dostać, lokalny stan
    /// jest ZASTĘPOWANY, a nie doliczany. Bez tego stany, których App Store nie
    /// potwierdza (refund, zmiana Apple ID, dawne darmowe odblokowanie w DEBUG)
    /// zostałyby w aplikacji na zawsze — a Keychain czyni je trwałymi.
    ///
    /// Gdy sklepu NIE dało się odczytać (offline, błąd), lokalny stan zostaje
    /// nietknięty: brak sieci nie może odbierać zakupu.
    ///
    /// - Returns: czy udało się skontaktować ze sklepem.
    @MainActor
    @discardableResult
    func syncEntitlementsFromStoreKit() async -> Bool {
        var entitled: Set<String> = []
        var confirmedProductIDs: Set<String> = []

        do {
            for await result in Transaction.currentEntitlements {
                let transaction = try Self.checkVerified(result)
                guard let tier = SmartAssistantProductID.unlockedTier(for: transaction.productID) else {
                    continue
                }
                // Transakcja wycofana/wygasła nie daje uprawnień.
                let revoked = transaction.revocationDate != nil
                let expired = transaction.expirationDate.map { $0 <= Date() } ?? false
                guard !revoked, !expired else { continue }

                confirmedProductIDs.insert(transaction.productID)
                for unlocked in tier.unlockedBundle {
                    entitled.insert(unlocked.rawValue)
                }
            }
            // Sekwencja dobiegła końca bez rzutu — sklep odpowiedział. Pusta lista
            // znaczy „brak zakupów”, a nie „brak sieci”: dla użytkownika bez planu
            // to normalny wynik i nie wolno na nim krążyć w pętli retry.
        } catch {
            #if DEBUG
            print("[StoreKit] Błąd odczytu currentEntitlements: \(error)")
            #endif
            // Nie ruszamy lokalnego stanu — lepiej zachować potwierdzony zakup
            // niż go stracić z powodu chwilowego braku sieci.
            return false
        }

        setLastEntitlementSyncAt(Date())
        SmartAssistantEntitlementVault.remember(productIDs: confirmedProductIDs)
        let previousLocal = ownedTierIDs
        applyEntitlementSnapshot(entitled)

        #if DEBUG
        let legacy = confirmedProductIDs.filter(SmartAssistantProductID.isLegacy)
        if !legacy.isEmpty {
            print("[StoreKit] Rozpoznano zakupy ze starego prefiksu (zachowane): \(legacy.sorted())")
        }
        if previousLocal != entitled {
            // Dokładnie ten sytuacja, w której stan lokalny nie został potwierdzony
            // przez sklep (refund, zmiana Apple ID, dawne darmowe odblokowanie).
            print("[StoreKit] lokalne \(previousLocal.sorted()) → sklep potwierdził \(entitled.sorted())")
        }
        print("[StoreKit] Uprawnienia z App Store: \(entitled.sorted())")
        #endif

        // Sklep właśnie odpowiedział, więc każdy błąd „oferta niedostępna” z
        // początku sesji jest nieaktualny.
        clearStaleCatalogError()
        return true
    }

    // MARK: - Prywatne helpery

    /// Sklep właśnie zwrócił ofertę, więc komunikat „oferta niedostępna” z
    /// początku sesji jest nieaktualny i musi zniknąć z paywalla — inaczej
    /// użytkownik widzi czerwony komunikat mimo działających zakupów.
    /// Porównujemy prefiks, bo treść zawiera liczbę zwróconych produktów,
    /// która zmienia się między wczytaniami.
    private func clearStaleCatalogError() {
        if let error = lastStoreError,
           error.hasPrefix("Produkty StoreKit są niedostępne".l10n) {
            lastStoreError = nil
        }
    }

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    private func grantEntitlement(
        for productID: String,
        activate: SmartAssistantTier?,
        transaction: Transaction
    ) {
        guard let tier = SmartAssistantProductID.unlockedTier(for: productID) else { return }
        insertOwnedBundle(for: tier)
        // Zapisujemy productID potwierdzone przez App Store — nie tylko wyliczony tier.
        SmartAssistantEntitlementVault.remember(productIDs: [productID])
        if let activate {
            activeTier = activate
        } else if activeTier == nil {
            activeTier = tier
        }
    }

    /// Refund / wygaśnięcie: usuwamy tylko ten produkt, weryfikując ponownie
    /// cały stan w App Store (żeby nie uciąć planu z wyższego pakietu).
    @MainActor
    private func handleEntitlementRevocation(of productID: String) {
        #if DEBUG
        print("[StoreKit] Wycofanie/wygaśnięcie: \(productID) — pełna rekonsyliacja.")
        #endif
        Task { @MainActor in
            _ = await syncEntitlementsFromStoreKit()
        }
    }

    /// Nakłada zweryfikowany stan uprawnień: zapis, aktywacja, odświeżenie UI.
    @MainActor
    private func applyEntitlementSnapshot(_ entitled: Set<String>) {
        let before = ownedTierIDs
        replaceOwnedTier(entitled)

        if let active = activeTier, !owns(active) {
            activeTier = SmartAssistantTier.allCases
                .filter(owns)
                .max(by: { $0.rank < $1.rank })
        }
        if activeTier == nil, !entitled.isEmpty {
            activeTier = SmartAssistantTier.allCases
                .filter(owns)
                .max(by: { $0.rank < $1.rank })
        }

        if before != entitled {
            BeSortedSound.play(.regular)
        }
    }
}
