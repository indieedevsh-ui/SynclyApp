//
//  SmartAssistant.swift
//  BeSorted
//

import Foundation
import FoundationModels
import StoreKit
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tier

enum SmartAssistantTier: String, CaseIterable, Identifiable {
    case pro
    case plus
    case standard

    var id: String { rawValue }

    /// Kolejność w okienku: Pro → + → Smart Assistant.
    static var storeOrder: [SmartAssistantTier] { [.pro, .plus, .standard] }

    var title: String {
        switch self {
        case .pro: "Smart Assistant Pro"
        case .plus: "Smart Assistant +"
        case .standard: "Smart Assistant"
        }
    }

    /// Hierarchia upgrade: standard < plus < pro.
    var rank: Int {
        switch self {
        case .standard: return 0
        case .plus: return 1
        case .pro: return 2
        }
    }

    /// Cena katalogowa (PLN) — **tylko awaryjnie**, gdy sklep nie zwrócił ceny.
    /// Wartość pokazywana użytkownikowi pochodzi z `Product.displayPrice`
    /// (`SmartAssistantStore.storeDisplayPrice`), więc po załadowaniu sklepu
    /// ta tabela służy wyłącznie do przekreślonej ceny „było”.
    /// Musi odpowiadać `Products.storekit` i App Store Connect.
    var listPrice: Double {
        switch self {
        case .pro: return 9.99
        case .plus: return 4.99
        case .standard: return 2.99
        }
    }

    var priceLabel: String {
        Self.formatPLN(listPrice)
    }

    /// Ten tier + wszystkie niższe (przy zakupie Pro → Pro, +, SA).
    var unlockedBundle: [SmartAssistantTier] {
        Self.allCases.filter { $0.rank <= rank }.sorted { $0.rank > $1.rank }
    }

    static func formatPLN(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
        return "\(formatted) zł"
    }

    var shortSubtitle: String {
        switch (AppLanguage.stored, self) {
        case (.polish, .pro):
            "Foundation Model · Apple Intelligence"
        case (.english, .pro):
            "Foundation Model · Apple Intelligence"
        case (.polish, .plus):
            "Model dla iPhone 15 Pro i nowszych (bez Apple Intelligence)"
        case (.english, .plus):
            "Model for iPhone 15 Pro and newer (no Apple Intelligence)"
        case (.polish, .standard):
            "Heurystyka + NaturalLanguage · od iPhone 14 (6 GB)"
        case (.english, .standard):
            "Heuristics + NaturalLanguage · iPhone 14+ (6 GB)"
        }
    }

    /// Wymagania sprzętowe (dłuższy opis do okienka ulepszenia).
    var hardwareRequirement: String {
        switch (AppLanguage.stored, self) {
        case (.polish, .standard):
            "Wymaga co najmniej iPhone’a 14 (6 GB RAM). Działa też na 14 Pro / 15 / 15 Plus. Modele 15 Pro+ → Smart Assistant + / Pro."
        case (.english, .standard):
            "Requires at least iPhone 14 (6 GB RAM). Also runs on 14 Pro / 15 / 15 Plus. 15 Pro+ → Smart Assistant + / Pro."
        case (.polish, .plus):
            "Wymaga iPhone’a 15 Pro / 15 Pro Max lub nowszego."
        case (.english, .plus):
            "Requires iPhone 15 Pro / 15 Pro Max or newer."
        case (.polish, .pro):
            "Wymaga iPhone’a 15 Pro+ (lub nowszego) z Apple Intelligence."
        case (.english, .pro):
            "Requires iPhone 15 Pro+ (or newer) with Apple Intelligence."
        }
    }

    func supports(_ skill: SmartAssistantSkill) -> Bool {
        switch self {
        case .pro:
            return true
        case .plus:
            switch skill {
            case .freeformChat, .summarizeProject, .breakDownTask:
                return false
            case .proposeTasks, .summarizeDescription, .fillCurrentPlan, .remindProject, .whatCanIDoNow, .evaluateProject, .forgottenProject:
                return true
            }
        case .standard:
            switch skill {
            case .freeformChat, .summarizeProject, .summarizeDescription, .breakDownTask, .evaluateProject:
                return false
            case .proposeTasks, .fillCurrentPlan, .remindProject, .whatCanIDoNow, .forgottenProject:
                return true
            }
        }
    }
}

// MARK: - Skills (istniejące operacje AI)

enum SmartAssistantSkill: String, CaseIterable, Identifiable {
    case freeformChat
    case summarizeProject
    case summarizeDescription
    case proposeTasks
    case fillCurrentPlan
    case breakDownTask
    case remindProject
    case whatCanIDoNow
    case evaluateProject
    case forgottenProject

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeformChat: "Asystent Q&A".l10n
        case .summarizeProject: "Streść projekt".l10n
        case .summarizeDescription: "Streść opis".l10n
        case .proposeTasks: "Zaproponuj zadania".l10n
        case .fillCurrentPlan: "Ułóż Aktualny Plan".l10n
        case .breakDownTask: "Rozbij zadanie".l10n
        case .remindProject: "Przypomnij projekt".l10n
        case .whatCanIDoNow: "Co mogę zrobić teraz".l10n
        case .evaluateProject: "Oceń projekt".l10n
        case .forgottenProject: "Zapomniany projekt".l10n
        }
    }

    /// Tytuł w menu AI — na + „Luki w projekcie”, na Pro „Oceń projekt”.
    var menuTitle: String {
        switch self {
        case .evaluateProject:
            if SmartAssistantStore.shared.activeTier == .plus {
                return "Luki w projekcie".l10n
            }
            return title
        default:
            return title
        }
    }

    var systemImage: String {
        switch self {
        case .freeformChat: "bubble.left.and.bubble.right.fill"
        case .summarizeProject: "sparkles"
        case .summarizeDescription: "text.alignleft"
        case .proposeTasks: "checklist"
        case .fillCurrentPlan: "calendar.badge.plus"
        case .breakDownTask: "list.bullet.indent"
        case .remindProject: "brain.head.profile"
        case .whatCanIDoNow: "bolt.fill"
        case .evaluateProject: "eyeglasses"
        case .forgottenProject: "clock.arrow.circlepath"
        }
    }

    /// Najtańszy model, w którym ta umiejętność jest dostępna.
    var cheapestSupportingTier: SmartAssistantTier {
        SmartAssistantTier.allCases
            .sorted { $0.rank < $1.rank }
            .first { $0.supports(self) } ?? .pro
    }

    /// Krótki opis do przewodnika „Zapoznaj się”.
    var tourDescription: String {
        switch self {
        case .freeformChat:
            return "Odłącz pastylkę AI i zadawaj pytania o projekty — asystent odpowiada w kontekście Twoich danych.".l10n
        case .summarizeProject:
            return "Wskaż projekt, a AI przygotuje zwięzłe streszczenie: postęp, zadania i to, co warto wiedzieć.".l10n
        case .summarizeDescription:
            return "Jednym tapnięciem skróć długi opis projektu do czytelnego podsumowania, bez utraty sensu.".l10n
        case .proposeTasks:
            return "Lokalnie lub na Pro: 7 konkretnych zadań dopasowanych do opisu, typu projektu i rdzenia.".l10n
        case .fillCurrentPlan:
            return "Uzupełnij Aktualny Plan zadaniami z priorytetowych projektów — AI dobiera to, co najważniejsze.".l10n
        case .breakDownTask:
            return "Gdy plan jest pełny, AI rozbija wybrane zadanie na mniejsze, wykonalne kroki.".l10n
        case .remindProject:
            return "Szybkie przypomnienie całego projektu: nazwa, typ, ocena, postęp, błędy i plany na przyszłość.".l10n
        case .whatCanIDoNow:
            return "Jedna konkretna rekomendacja: co zrobić teraz, na podstawie otwartych zadań i notatek.".l10n
        case .evaluateProject:
            return "Na Pro: krytyczna ocena sensu, oryginalności i przeładowania. Na +: „Luki w projekcie” — audyt kompletności.".l10n
        case .forgottenProject:
            return "Wskaż projekt, który został zaniedbany mimo potencjału — i zaproponuj oznaczenie go jako priorytetowy.".l10n
        }
    }
}

// MARK: - Device eligibility

enum SmartAssistantDevice {
    /// Identyfikator maszyny (np. `iPhone15,2` = iPhone 14 Pro).
    /// Na symulatorze czyta `SIMULATOR_MODEL_IDENTIFIER`, nie hosta Maca.
    static var machineIdentifier: String {
        #if targetEnvironment(simulator)
        if let simID = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simID.isEmpty {
            return simID
        }
        #endif
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }

    /// iPhone 15 Pro / 15 Pro Max oraz cała linia 16+ (Apple Intelligence class).
    /// Świadomie bez iPhone 15 / 15 Plus (`iPhone15,4` / `iPhone15,5`).
    static var isPlusHardware: Bool {
        switch machineIdentifier {
        case
            // iPhone 15 Pro / 15 Pro Max
            "iPhone16,1", "iPhone16,2",
            // iPhone 16 family
            "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4",
            // iPhone 17 family (szacunek identyfikatorów)
            "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4":
            return true
        default:
            // Przyszłe generacje: iPhone18,x+ — ale NIE iPhone15,x (to 14 Pro / 15 non-Pro).
            if let major = iphoneMajorRevision, major >= 17 {
                return true
            }
            return false
        }
    }

    /// Smart Assistant Pro: tylko sprzęt z Apple Intelligence (ta sama klasa co Plus na iPhonie).
    /// Nie ufamy samym Foundation Models na symulatorze — host Mac mógłby odblokować Pro na „14”.
    static var isProHardware: Bool {
        guard isPlusHardware else { return false }

        let model = SystemLanguageModel.default
        switch model.availability {
        case .available, .unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady):
            return true
        case .unavailable(.deviceNotEligible):
            // Na symulatorze 15 Pro+ i tak pozwalamy kupić Pro (testy), bo FM bywa niespójne.
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        case .unavailable:
            return true
        @unknown default:
            return true
        }
    }

    static func canPurchase(_ tier: SmartAssistantTier) -> Bool {
        switch tier {
        case .standard:
            // Najtańszy plan uruchamia się na każdym iPhonie
            // (`canActivateOnThisDevice(.standard)` to zawsze `true`), więc nie może
            // być niedostępny do zakupu na mocniejszym sprzęcie. Wcześniej
            // `isStandardHardware` zwracało `false` dla całej klasy 15 Pro+/16/17/18,
            // przez co na nowoczesnym iPhonie karta pokazywała „Niedostępne do
            // zakupu” i planu nie dało się kupić wcale.
            return isAnyiPhone
        case .plus:
            return isPlusHardware
        case .pro:
            return isProHardware
        }
    }

    /// Dowolny iPhone, niezależnie od klasy sprzętu.
    static var isAnyiPhone: Bool {
        isPlusHardware || machineIdentifier.hasPrefix("iPhone")
    }

    /// Liczba z `iPhoneNN,…` (np. 15 z `iPhone15,2`).
    private static var iphoneMajorRevision: Int? {
        guard machineIdentifier.hasPrefix("iPhone") else { return nil }
        let rest = machineIdentifier.dropFirst("iPhone".count)
        let digits = rest.prefix(while: { $0.isNumber })
        return Int(digits)
    }
}

// MARK: - Store

@Observable
final class SmartAssistantStore {
    static let shared = SmartAssistantStore()

    private enum Keys {
        static let owned = "besorted.smartAssistant.owned"
        static let active = "besorted.smartAssistant.active"
    }

    private(set) var ownedTierIDs: Set<String>
    var activeTier: SmartAssistantTier? {
        didSet {
            if let activeTier {
                UserDefaults.standard.set(activeTier.rawValue, forKey: Keys.active)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.active)
            }
            // Keychron przeżywa usunięcie aplikacji — `UserDefaults` nie.
            persistEntitlementVault()
        }
    }

    // MARK: StoreKit state (patrz SmartAssistantStoreKit.swift)

    /// Identyfikator, pod którym plan faktycznie da się kupić: nowy prefiks, a gdy
    /// w sklepie istnieje tylko stary, ten stary. Bez tego płatność nie działa
    /// w dopóki nowe produkty nie pojawią się w App Store Connect.
    func resolvedPurchaseID(for tier: SmartAssistantTier) -> String {
        for candidate in SmartAssistantProductID.purchaseIDVariants(for: tier, owned: owns)
        where storeProducts[candidate] != nil {
            return candidate
        }
        return SmartAssistantProductID.purchaseID(for: tier, owned: owns)
    }

    /// Produkt, który faktycznie kupuje użytkownik dla danego planu — czyli
    /// wariant „z upgrade'u”, jeśli niższy plan już ma. `nil` = sklep nie zwrócił
    /// jeszcze oferty, więc ceny nie wolno udawać. Ten sam identyfikator, którego
    /// używa `purchase(_:)`, więc pokazana cena zawsze dotyczy tego, co zostanie
    /// kupione.
    func purchaseProduct(for tier: SmartAssistantTier) -> Product? {
        storeProducts[resolvedPurchaseID(for: tier)]
    }

    /// Czy sklep potwierdził cenę tego planu (a nie fallback z tabeli).
    func hasStoreKitPrice(for tier: SmartAssistantTier) -> Bool {
        purchaseProduct(for: tier)?.displayPrice.isEmpty == false
    }

    /// Rabat przy upgrade liczymy z PRAWDYWEJ ceny sklepu, nie z arytmetyki
    /// klienta. Dzięki temu przekreślona cena znika, gdy App Store wyceni
    /// upgrade inaczej niż „różnica cen katalogowych”.
    func hasStoreKitDiscount(for tier: SmartAssistantTier) -> Bool {
        upgradeSavingPLN(for: tier) != nil
    }

    /// Realna oszczędność przy upgrade w PLN policzona z cen sklepu.
    /// `nil` = brak oferty albo różnica poniżej grosza (brak realnego rabatu).
    func upgradeSavingPLN(for tier: SmartAssistantTier) -> Double? {
        guard !owns(tier) else { return nil }
        guard let product = purchaseProduct(for: tier) else { return nil }
        let list = NSDecimalNumber(value: tier.listPrice).doubleValue
        let difference = (list - NSDecimalNumber(decimal: product.price).doubleValue) * 100
        guard difference >= 1 else { return nil }
        return (difference).rounded() / 100
    }

    private(set) var storeProducts: [String: Product] = [:]
    private(set) var productsAvailable = false
    private(set) var isLoadingProducts = false
    private(set) var isRestoringPurchases = false
    private(set) var purchasingTierID: String?
    /// Ostatni udany odczyt uprawnień z App Store — `nil` znaczy „jeszcze nigdy”.
    private(set) var lastEntitlementSyncAt: Date?
    /// Współdzielone pobieranie produktów — scala równoległe wywołania.
    var loadProductsTask: Task<Void, Never>?
    var lastStoreError: String?
    var transactionListener: Task<Void, Never>?

    private init() {
        // 1) UserDefaults — szybka ścieżka, ale giną przy usunięciu aplikacji.
        var owned = Set(UserDefaults.standard.stringArray(forKey: Keys.owned) ?? [])
        var active = Self.storedActiveTier()

        // 2) Keychain — przetrwał usunięcie aplikacji, więc zakupione plany są
        //    widoczne natychmiast po instalacji, zanim StoreKit zdąży odpowiedzieć.
        if owned.isEmpty {
            let cached = SmartAssistantEntitlementVault.ownedTiers()
                .filter { SmartAssistantTier(rawValue: $0) != nil }
            if !cached.isEmpty {
                owned = cached
                active = Self.storedActiveTier() ?? SmartAssistantEntitlementVault.activeTier()
            }
        }

        ownedTierIDs = owned
        if let active, ownedTierIDs.contains(active.rawValue) {
            activeTier = active
        } else {
            activeTier = nil
        }
        if !ownedTierIDs.isEmpty {
            persistOwned()
        }
        #if DEBUG
        if SmartAssistantEntitlementVault.hasCachedEntitlements {
            print("[StoreKit] Sejf Keychain: tiery=\(ownedTierIDs.sorted()) aktywny=\(activeTier?.rawValue ?? "brak") producty=\(SmartAssistantEntitlementVault.productIDs().sorted())")
        }
        #endif
        startStoreKitListenersIfNeeded()
    }

    private static func storedActiveTier() -> SmartAssistantTier? {
        guard let raw = UserDefaults.standard.string(forKey: Keys.active) else { return nil }
        return SmartAssistantTier(rawValue: raw)
    }

    var hasActiveAssistant: Bool { activeTier != nil }

    var activeStatusLabel: String {
        if let activeTier {
            return L10n.format("Aktywny: %@", activeTier.title)
        }
        return "Nieaktywny".l10n
    }

    func owns(_ tier: SmartAssistantTier) -> Bool {
        ownedTierIDs.contains(tier.rawValue)
    }

    /// Kredyt upgrade = najwyższa cena katalogowa wśród już posiadanych niższych planów.
    func upgradeCredit(toward tier: SmartAssistantTier) -> Double {
        SmartAssistantTier.allCases
            .filter { owns($0) && $0.rank < tier.rank }
            .map(\.listPrice)
            .max() ?? 0
    }

    /// Kwota do zapłaty za upgrade (nieujemna).
    func priceToPay(for tier: SmartAssistantTier) -> Double {
        let raw = tier.listPrice - upgradeCredit(toward: tier)
        return max(0, (raw * 100).rounded() / 100)
    }

    /// Etykieta ceny z uwzględnieniem kredytu (np. „10,99 zł”).
    func displayPriceLabel(for tier: SmartAssistantTier) -> String {
        SmartAssistantTier.formatPLN(priceToPay(for: tier))
    }

    var hasUpgradeCredit: Bool {
        SmartAssistantTier.allCases.contains { owns($0) }
    }

    /// Aktywacja posiadanego modelu (także niższego odkupionego w pakiecie z wyższym).
    func activateOwned(_ tier: SmartAssistantTier) {
        guard owns(tier) else { return }
        // Pro / + wymagają kompatybilnego sprzętu do działania FM / plus-runtime.
        guard canActivateOnThisDevice(tier) else {
            lastStoreError = "Ten plan wymaga mocniejszego iPhone’a. Twój zakup jest bezpieczny i wróci na sprzęcie, który go obsługuje.".l10n
            BeSortedSound.play(.skillNo)
            return
        }
        lastStoreError = nil
        activeTier = tier
        BeSortedSound.play(.regular)
    }

    /// Sprzęt, na którym dany tier da się uruchomić.
    /// Osobno od `SmartAssistantDevice.canPurchase`, bo to dotyczy **posiadanego**
    /// zakupu, a nie oferty sklepowej.
    func canActivateOnThisDevice(_ tier: SmartAssistantTier) -> Bool {
        switch tier {
        case .pro: return SmartAssistantDevice.isProHardware
        case .plus: return SmartAssistantDevice.isPlusHardware
        case .standard: return true
        }
    }

    /// Zakup istnieje, ale ten sprzęt go nie uruchomi (np. Pro kupione na 15 Pro,
    /// otwarte na 14). Zakupu NIE kasujemy — wróci na sprzęcie, który go obsłuży.
    func isOwnedButUnsupportedHere(_ tier: SmartAssistantTier) -> Bool {
        owns(tier) && !canActivateOnThisDevice(tier)
    }

    /// Koryguje TYLKO aktywację dla aktualnego sprzętu. Świadomie nie usuwa
    /// `ownedTierIDs`: zapis w App Store jest jedynym źródłem prawdy o zakupie,
    /// a kasowanie lokalnego rekordu przy błędnej detekcji sprzętu wyglądałoby
    /// dla użytkownika jak utrata zakupu (i znikało po reinstalacji).
    /// Niższych odblokowanych w pakiecie nie wyrzucamy — służą do przełączania.
    func sanitizeOwnedForCurrentDevice() {
        guard let active = activeTier else { return }
        guard !canActivateOnThisDevice(active) else { return }

        // Nie kasujemy zakupu — schodzimy na najwyższy plan, który ten sprzęt obsługuje.
        activeTier = SmartAssistantTier.allCases
            .filter { owns($0) && canActivateOnThisDevice($0) }
            .max(by: { $0.rank < $1.rank })
    }

    func supports(_ skill: SmartAssistantSkill) -> Bool {
        activeTier?.supports(skill) ?? false
    }

    /// `true` jeśli skill jest dostępny; inaczej pokazuje okienko ulepszenia.
    @discardableResult
    func requireSkillOrPromptUpgrade(
        _ skill: SmartAssistantSkill,
        chrome: SmartChrome
    ) -> Bool {
        if supports(skill) { return true }
        chrome.presentSmartAssistantUpgrade(for: skill)
        return false
    }

    func blockedMessage(for skill: SmartAssistantSkill) -> String {
        guard let active = activeTier else {
            return "Aktywuj Smart Assistant w Ustawieniach.".l10n
        }
        if active.supports(skill) {
            return "AI jest teraz niedostępne.".l10n
        }
        switch skill {
        case .summarizeProject, .breakDownTask, .freeformChat:
            return L10n.format(
                "„%@” wymaga Smart Assistant Pro.",
                skill.title
            )
        case .summarizeDescription, .evaluateProject:
            return L10n.format(
                "„%@” wymaga Smart Assistant + lub Pro.",
                skill.title
            )
        default:
            return L10n.format(
                "„%@” jest niedostępne w %@.",
                skill.title,
                active.title
            )
        }
    }

    func persistOwned() {
        let sorted = Array(ownedTierIDs).sorted()
        UserDefaults.standard.set(sorted, forKey: Keys.owned)
        persistEntitlementVault()
    }

    /// Lustro w Keychain — jedyne miejsce, które przetrwa usunięcie aplikacji.
    /// Źródłem prawdy pozostaje App Store; ten zapis istnieje tylko po to, by
    /// zakupy były widoczne od pierwszego uruchomienia, także bez sieci.
    private func persistEntitlementVault() {
        SmartAssistantEntitlementVault.save(
            ownedTiers: ownedTierIDs,
            activeTier: activeTier
        )
    }

    func replaceOwnedTier(_ ids: Set<String>) {
        ownedTierIDs = ids
        persistOwned()
    }

    func insertOwnedBundle(for tier: SmartAssistantTier) {
        for unlocked in tier.unlockedBundle {
            ownedTierIDs.insert(unlocked.rawValue)
        }
        persistOwned()
    }

    func setPurchasingTierID(_ id: String?) {
        purchasingTierID = id
    }

    func setStoreProducts(_ map: [String: Product], available: Bool) {
        storeProducts = map
        productsAvailable = available
    }

    func setLoadingProducts(_ value: Bool) {
        isLoadingProducts = value
    }

    func setRestoringPurchases(_ value: Bool) {
        isRestoringPurchases = value
    }

    func setLastEntitlementSyncAt(_ date: Date?) {
        lastEntitlementSyncAt = date
    }

    func setLoadProductsTask(_ task: Task<Void, Never>?) {
        loadProductsTask = task
    }

    func clearLoadProductsTask() {
        loadProductsTask = nil
    }
}

// MARK: - Safe local runtimes (Plus / Standard — bez Foundation Models)

enum SmartAssistantLocalRuntime {
    /// Ranking lokalny: gwiazdki → w planie → świeżość → dopasowanie tematyczne (NL).
    static func whatCanIDoNow(for project: Project) -> String {
        let english = AppLanguage.stored.isEnglish
        let projectBlob = project.details
            + " " + project.gameMechanics
            + " " + project.gameGameloop
            + " " + project.storyTheme
            + " " + project.storyTypicalAction
            + " " + project.storyHeroGoal
            + " " + project.storyFinale
            + " " + project.drawingMainMotif
            + " " + project.drawingGoalEmotion
            + " " + project.drawingCompletionDefinition
            + " " + project.appKeyFeatures
            + " " + project.appUserPath
            + " " + project.appMainProblem
            + " " + project.schoolProjectGoal
            + " " + project.schoolMainContent
            + " " + project.schoolSubject
            + " " + project.schoolCompletionCriteria
        let open = project.taskList
            .filter { !$0.isCompleted && !Project.isMeaninglessLabel($0.name) }
            .sorted {
                let ls = SmartAssistantStandardIntel.planTaskScore(task: $0, project: project)
                    + Double(SmartAssistantStandardIntel.topicalOverlapScore(
                        projectText: projectBlob,
                        candidate: $0.name + " " + $0.details
                    ))
                let rs = SmartAssistantStandardIntel.planTaskScore(task: $1, project: project)
                    + Double(SmartAssistantStandardIntel.topicalOverlapScore(
                        projectText: projectBlob,
                        candidate: $1.name + " " + $1.details
                    ))
                if ls != rs { return ls > rs }
                if $0.isInCurrentPlan != $1.isInCurrentPlan { return $0.isInCurrentPlan && !$1.isInCurrentPlan }
                return $0.createdAt > $1.createdAt
            }

        if let top = open.first {
            let reason: String
            if top.isInCurrentPlan {
                reason = english
                    ? "It's already on your Current Plan and has the highest priority among open tasks (\(top.importance)/5)."
                    : "Jest już w Aktualnym Planie i ma najwyższy priorytet wśród otwartych zadań (\(top.importance)/5)."
            } else {
                reason = english
                    ? "It has the highest importance among open tasks (\(top.importance)/5)."
                    : "Ma najwyższą wagę wśród otwartych zadań (\(top.importance)/5)."
            }
            return "## \(top.name)\n\(reason)"
        }

        if let note = project.futureNoteList.sorted(by: { $0.createdAt > $1.createdAt }).first {
            let body = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if body.count >= 12 {
                let clip = String(body.prefix(180))
                return english
                    ? "## Next from future notes\n\(clip)"
                    : "## Kolejny krok z notatek\n\(clip)"
            }
        }

        guard project.canInterpretProjectPlan else {
            return project.insufficientProjectPlanMessageMarkdown
        }

        if project.hasMeaningfulDescription {
            return english
                ? "## Review the project description\nAll meaningful tasks are done — revisit the description and decide what to build next."
                : "## Przejrzyj opis projektu\nSensowne zadania są zrobione — wróć do opisu i zdecyduj, co budować dalej."
        }

        return english
            ? "## Fill Project Core next\nTasks are clear, but the plan text is thin — add concrete core details before inventing new work."
            : "## Uzupełnij Rdzeń Projektowy\nZadania są domknięte, ale plan jest ubogi — dopisz konkretny rdzeń, zanim wymyślisz nową pracę."
    }

    /// Audyt kompletności (Smart Assistant +) — bez oceny sensu / oryginalności.
    static func evaluateProjectHoles(_ project: Project) -> String {
        guard project.canInterpretProjectPlan else {
            return project.insufficientProjectPlanMessageMarkdown
        }

        let english = AppLanguage.stored.isEnglish
        var holes: [String] = []

        let details = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !project.hasMeaningfulDescription || details.count < 80 {
            holes.append(
                english
                    ? "The **description** is very short — a finished-looking project usually needs a clearer written intent."
                    : "Opis jest bardzo krótki — projekt wyglądający na domknięty zwykle ma jaśniej zapisaną intencję."
            )
        }

        if project.kind == .game {
            if project.gameMechanics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Core mechanics** are empty."
                        : "W rdzeniu brakuje **głównych mechanik**."
                )
            }
            if project.gameGameloop.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Gameloop** is empty."
                        : "W rdzeniu brakuje **gameloopu**."
                )
            }
            if project.gamePlayerGoals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Player goals** are empty."
                        : "W rdzeniu brakuje **celów gracza**."
                )
            }
            if project.gameWinConditions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Win / end conditions** are empty."
                        : "W rdzeniu brakuje **warunków zakończenia / wygranej**."
                )
            }
            if project.gameGenres.isEmpty {
                holes.append(
                    english
                        ? "**Genres** are not set."
                        : "Nie ustawiono **gatunków**."
                )
            }
            if project.gameStructure == nil {
                holes.append(
                    english
                        ? "**Structure** is not set."
                        : "Nie ustawiono **struktury**."
                )
            }
        } else if project.kind == .story {
            if project.storyTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Central theme** (what’s unique) is empty."
                        : "W rdzeniu brakuje **motywu przewodniego**."
                )
            }
            if project.storyTypicalAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Typical action** is empty."
                        : "W rdzeniu brakuje **typowej akcji**."
                )
            }
            if project.storyHeroGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Hero’s goal** is empty."
                        : "W rdzeniu brakuje **celu bohatera**."
                )
            }
            if project.storyFinale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Finale** is empty."
                        : "W rdzeniu brakuje **finału**."
                )
            }
            if project.storyGenres.isEmpty {
                holes.append(
                    english
                        ? "**Genres** are not set."
                        : "Nie ustawiono **gatunków**."
                )
            }
            if project.storyNarration == nil {
                holes.append(
                    english
                        ? "**Narration style** is not set."
                        : "Nie ustawiono **sposobu opowiadania**."
                )
            }
        } else if project.kind == .drawing {
            if project.drawingTechniques.isEmpty {
                holes.append(
                    english
                        ? "**Technique & tools** are not set."
                        : "Nie ustawiono **techniki i narzędzi**."
                )
            }
            if project.drawingMainMotif.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Main motif** is empty."
                        : "W rdzeniu brakuje **głównego motywu**."
                )
            }
            if project.drawingGoalEmotion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Goal & emotion** are empty."
                        : "W rdzeniu brakuje **celu i emocji**."
                )
            }
            if project.drawingCompletionDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                holes.append(
                    english
                        ? "**Completion definition** is empty."
                        : "W rdzeniu brakuje **definicji ukończenia**."
                )
            }
            if project.drawingGenres.isEmpty {
                holes.append(
                    english
                        ? "**Genres** are not set."
                        : "Nie ustawiono **gatunków**."
                )
            }
            if project.drawingScale == nil {
                holes.append(
                    english
                        ? "**Scale & space** is not set."
                        : "Nie ustawiono **skali i przestrzeni**."
                )
            }
        }

        if project.taskList.isEmpty {
            holes.append(
                english
                    ? "There are **no tasks** — hard to look complete without concrete work items."
                    : "Brak **zadań** — bez konkretnej pracy projekt rzadko wygląda na kompletny."
            )
        }

        if project.futureNoteList.isEmpty {
            holes.append(
                english
                    ? "No **future notes** — optional, but often signals missing horizon."
                    : "Brak **notatek przyszłości** — opcjonalne, ale często oznacza brak horyzontu."
            )
        }

        if project.contextFileList.isEmpty {
            holes.append(
                english
                    ? "No **context files** attached."
                    : "Brak dołączonych **plików kontekstowych**."
            )
        }

        let upgradeNote = english
            ? """
            ## Smart Assistant Pro
            As the current model I **cannot fully evaluate** this project. To unlock the full critique \
            (**project sense**, **originality**, and **unnecessary elements**), activate **Smart Assistant Pro**.
            """
            : """
            ## Smart Assistant Pro
            Jako aktualny model **nie mogę w pełni ocenić** projektu. Aby mieć pełne możliwości oceny \
            (**sens projektu**, jego **oryginalność** oraz **zbędne elementy**), aktywuj **Smart Assistant Pro**.
            """

        if holes.isEmpty {
            return english
                ? """
                ## Completeness check
                Structurally the project **does not show obvious holes** — description and core look filled, and supporting lists are present.

                ## Recommended actions
                Keep executing and filling only what you still need for delivery.

                \(upgradeNote)
                """
                : """
                ## Luki w projekcie
                Strukturalnie projekt **nie ma oczywistych dziur** — opis i rdzeń wyglądają na uzupełnione, a listy pomocnicze są obecne.

                ## Zalecane działania
                Kontynuuj egzekucję i domykaj tylko to, czego jeszcze brakuje do realizacji.

                \(upgradeNote)
                """
        }

        let list = holes.map { "- \($0)" }.joined(separator: "\n")
        return english
            ? """
            ## Project gaps
            These gaps make the project look unfinished:

            \(list)

            ## Recommended actions
            Fill the gaps above first.

            \(upgradeNote)
            """
            : """
            ## Luki w projekcie
            Te braki sprawiają, że projekt wygląda na niedomknięty:

            \(list)

            ## Zalecane działania
            Najpierw domknij powyższe luki.

            \(upgradeNote)
            """
    }

    struct ForgottenProjectSuggestion {
        let project: Project
        let rationaleMarkdown: String
        let score: Double
    }

    /// Lokalna analiza zaniedbania — działa tak samo na SA / + / Pro.
    static func suggestForgottenProject(from projects: [Project]) -> ForgottenProjectSuggestion? {
        let english = AppLanguage.stored.isEnglish
        let now = Date()
        let epoch = Date(timeIntervalSince1970: 0)

        func daysSince(_ date: Date) -> Double {
            max(0, now.timeIntervalSince(date) / 86_400)
        }

        var best: ForgottenProjectSuggestion?

        for project in projects {
            guard !project.isPriorityHighlighted else { continue }

            let tasks = project.taskList
            let openTasks = tasks.filter { !$0.isCompleted }
            let doneTasks = tasks.filter(\.isCompleted)

            // Puste skorupy / placeholdery pomijamy — nie ma sensu stawiać priorytetu.
            let hasSubstance = project.canInterpretProjectPlan
                || project.hasMeaningfulWorkArtifacts
            guard hasSubstance else { continue }

            let lastOpened = project.lastOpenedAt > epoch ? project.lastOpenedAt : epoch
            let lastTaskAdded = tasks.map(\.createdAt).max() ?? epoch
            let lastTaskCompleted = doneTasks.map(\.updatedAt).max() ?? epoch
            let lastEdit = project.updatedAt

            let daysSinceOpen = lastOpened > epoch ? daysSince(lastOpened) : 400
            let daysSinceAdd = lastTaskAdded > epoch ? daysSince(lastTaskAdded) : 400
            let daysSinceDone = lastTaskCompleted > epoch ? daysSince(lastTaskCompleted) : 400
            let daysSinceEdit = daysSince(lastEdit)

            let neglect = (daysSinceOpen * 1.35)
                + (daysSinceAdd * 1.1)
                + (daysSinceDone * 1.25)
                + (daysSinceEdit * 0.55)

            let openCount = max(project.openCount, 0)
            let ageWeeks = max(daysSince(project.createdAt) / 7, 0.35)
            let opensPerWeek = Double(openCount) / ageWeeks
            let visitPenalty = opensPerWeek < 0.35 ? 1.35 : (opensPerWeek < 1 ? 1.15 : 1)

            let topicalDensity = Double(
                SmartAssistantStandardIntel.keyLemmas(
                    from: project.details + " " + openTasks.prefix(5).map(\.name).joined(separator: " "),
                    limit: 12
                ).count
            )
            let value = Double(openTasks.count) * (0.65 + Double(project.importance) / 12)
                + Double(min(doneTasks.count, 8)) * 0.15
                + (project.hasMeaningfulDescription ? 1.55 : (project.details.count > 40 ? 0.6 : 0))
                + (project.supportsProjectCore && project.hasProjectCoreContent ? 0.9 : 0)
                + min(topicalDensity, 8) * 0.12
                + Double(project.importance) * 0.2

            let score = neglect * value * visitPenalty
            guard score > 8 else { continue }

            var reasons: [String] = []
            reasons.append(
                english
                    ? "Tasks: **\(tasks.count)** total (**\(openTasks.count)** open, **\(doneTasks.count)** done)."
                    : "Zadania: **\(tasks.count)** łącznie (**\(openTasks.count)** otwartych, **\(doneTasks.count)** ukończonych)."
            )
            if lastOpened > epoch {
                reasons.append(
                    english
                        ? "Last opened: **\(Int(daysSinceOpen))** days ago (\(openCount) visits)."
                        : "Ostatnie wejście: **\(Int(daysSinceOpen))** dni temu (\(openCount) wizyt)."
                )
            } else {
                reasons.append(
                    english
                        ? "Almost **no recorded visits** to this project."
                        : "Prawie **brak zapisanych wejść** w ten projekt."
                )
            }
            if lastTaskAdded > epoch {
                reasons.append(
                    english
                        ? "Last new task: **\(Int(daysSinceAdd))** days ago."
                        : "Ostatnie nowe zadanie: **\(Int(daysSinceAdd))** dni temu."
                )
            } else {
                reasons.append(
                    english
                        ? "No tasks have been added recently (or ever)."
                        : "Dawno (albo wcale) nie dodawano zadań."
                )
            }
            if lastTaskCompleted > epoch {
                reasons.append(
                    english
                        ? "Last completed task: **\(Int(daysSinceDone))** days ago."
                        : "Ostatnie ukończone zadanie: **\(Int(daysSinceDone))** dni temu."
                )
            } else if !tasks.isEmpty {
                reasons.append(
                    english
                        ? "No completed tasks yet — progress looks stalled."
                        : "Brak ukończonych zadań — postęp wygląda na zatrzymany."
                )
            }

            let rationale: String
            if english {
                rationale = """
                ## Why this project
                **\(project.name)** looks forgotten relative to its remaining work.

                \(reasons.map { "- \($0)" }.joined(separator: "\n"))

                ## Suggestion
                Mark it as **priority** so it resurfaces in plan filling and daily focus.
                """
            } else {
                rationale = """
                ## Dlaczego ten projekt
                **\(project.name)** wygląda na zapomniany względem pozostałej pracy.

                \(reasons.map { "- \($0)" }.joined(separator: "\n"))

                ## Propozycja
                Oznacz go jako **priorytetowy**, żeby wrócił w układaniu planu i codziennym fokusie.
                """
            }

            let suggestion = ForgottenProjectSuggestion(
                project: project,
                rationaleMarkdown: rationale,
                score: score
            )
            if best == nil || suggestion.score > best!.score {
                best = suggestion
            }
        }

        return best
    }

    /// Przypomnienie zbudowane wyłącznie z danych — bez generowania faktów.
    static func remindProject(_ project: Project, rich: Bool) -> String {
        guard project.canInterpretProjectPlan || project.hasMeaningfulWorkArtifacts else {
            return project.insufficientProjectPlanMessageMarkdown
        }

        let english = AppLanguage.stored.isEnglish
        var lines: [String] = []

        lines.append(english ? "## Project overview" : "## Przegląd projektu")
        if project.hasMeaningfulDescription {
            let details = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
            let limit = rich ? 600 : 280
            lines.append(details.count > limit ? String(details.prefix(limit)) + "…" : details)
            if rich {
                let themes = SmartAssistantStandardIntel.keyLemmas(from: details, limit: 8)
                if themes.count >= 3 {
                    let joined = themes.joined(separator: " · ")
                    lines.append(
                        english
                            ? "Focus themes: \(joined)"
                            : "Tematy wiodące: \(joined)"
                    )
                }
            }
        } else if project.supportsProjectCore && project.hasProjectCoreContent {
            lines.append(
                english
                    ? "(description thin — see core fields reflected in tasks/bugs below)"
                    : "(opis ubogi — patrz dane rdzenia / zadania / błędy poniżej)"
            )
        } else {
            lines.append(
                english
                    ? "(not enough description for an overview — listing known artifacts only)"
                    : "(za mało opisu do przeglądu — poniżej tylko znane artefakty)"
            )
        }

        if rich, !project.contextFileList.isEmpty {
            let names = project.contextFileList.map(\.fileName).joined(separator: ", ")
            lines.append(english ? "Context files: \(names)" : "Pliki kontekstowe: \(names)")
        }

        lines.append(english ? "## What's already done" : "## Co już zostało zrobione")
        let done = project.taskList.filter(\.isCompleted)
        if done.isEmpty {
            lines.append(english ? "(none)" : "(brak)")
        } else {
            for task in done.prefix(rich ? 20 : 8) {
                lines.append("- \(task.name)")
            }
        }

        lines.append(english ? "## Bugs" : "## Błędy")
        let bugs = project.bugList.sorted { $0.severity > $1.severity }
        if bugs.isEmpty {
            lines.append(english ? "(none)" : "(brak)")
        } else {
            for bug in bugs.prefix(rich ? 15 : 6) {
                lines.append("- \(bug.title) (\(bug.severity)/5)")
            }
        }

        lines.append(english ? "## Future plans" : "## Przyszłe plany")
        let notes = project.futureNoteList.sorted { $0.createdAt > $1.createdAt }
        if notes.isEmpty {
            lines.append(
                english
                    ? "(no future notes — nothing to summarize here)"
                    : "(brak notatek przyszłości — brak treści do podsumowania)"
            )
        } else {
            for note in notes.prefix(rich ? 12 : 5) {
                let text = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let clip = rich ? 160 : 90
                lines.append("- " + (text.count > clip ? String(text.prefix(clip)) + "…" : text))
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Ekstraktywne streszczenie opisu (Plus) — pierwsze zdania, bez dopisywania treści.
    static func summarizeDescription(from details: String) throws -> String {
        let source = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Project.isMeaninglessLabel(source) else {
            throw BeSortedAIService.ServiceError.unavailable(
                AppLanguage.stored.isEnglish
                    ? "Not enough information in the description to summarize."
                    : "Za mało informacji w opisie, żeby go streścić."
            )
        }
        let alnumCount = source.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
        guard alnumCount >= 12 else {
            throw BeSortedAIService.ServiceError.unavailable(
                AppLanguage.stored.isEnglish
                    ? "Not enough information in the description to summarize."
                    : "Za mało informacji w opisie, żeby go streścić."
            )
        }

        let parts = source
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let picked = Array(parts.prefix(4))
        let body: String
        if picked.isEmpty {
            body = String(source.prefix(320))
        } else {
            body = picked.map { $0.hasSuffix(".") ? $0 : $0 + "." }.joined(separator: " ")
        }

        let heading = AppLanguage.stored.isEnglish ? "## Summary" : "## Streszczenie"
        return "\(heading)\n\(body)"
    }

    /// Poziom lokalnego „Zaproponuj zadania” (bez Foundation Models).
    enum ProposeQuality {
        /// Smart Assistant — konkretne akcje, zero kopiowania zdań z opisu.
        case standard
        /// Smart Assistant + — bogatszy kontekst produktowy (błędy, notatki, wypełniony rdzeń).
        case plus
    }

    /// 7 zadań bez Foundation Models — szablony wg typu + tematy z opisu (nie cytaty) / rdzeń / luki.
    static func proposeTasks(
        for project: Project,
        avoidNames: [String],
        quality: ProposeQuality
    ) throws -> [ProposedTaskDraft] {
        guard project.canProposeProjectWorkTasks else {
            throw BeSortedAIService.ServiceError.unavailable(project.proposeTasksInsufficientMessageShort)
        }

        let english = AppLanguage.stored.isEnglish
        let allowedKinds = TaskKind.kinds(for: project.kind)
        guard let fallbackKind = allowedKinds.first else {
            throw BeSortedAIService.ServiceError.unavailable(
                "Brak dostępnych rodzajów zadań dla tego typu projektu.".l10n
            )
        }

        var pool = baseTaskPool(for: project, english: english)
        // Tematy z opisu → konkretne akcje (tylko mocne rzeczowniki/frazy, bez „prototyp «której»”).
        pool.append(contentsOf: themeActionTasks(for: project, english: english, quality: quality))
        // Wypełniony rdzeń → praca NAD treścią (nie „uzupełnij rdzeń”).
        pool.append(contentsOf: filledCoreWorkTasks(for: project, english: english))
        pool.append(contentsOf: projectProgressTasks(for: project, english: english, quality: quality))

        // SA (heurystyka+NL) i +: praca produktowa z bugów / future notes — bez meta Syncly.
        if quality == .plus || quality == .standard {
            pool.append(contentsOf: plusProductWorkTasks(for: project, english: english))
        }

        pool.removeAll { isMetaSynclyChore(name: $0.name, details: $0.details) }
        pool.removeAll { looksLikeAwkwardThemeTask($0.name) }

        let avoided = Set(
            avoidNames
                .map { normalizeTaskName($0) }
                .filter { !$0.isEmpty }
        )

        func isAvoided(_ name: String) -> Bool {
            let key = normalizeTaskName(name)
            guard !key.isEmpty else { return true }
            if avoided.contains(key) { return true }
            return avoided.contains { existing in
                existing == key
                    || (existing.count >= 8 && (existing.contains(key) || key.contains(existing)))
            }
        }

        var rotation = UInt64(Date().timeIntervalSince1970.rounded())
        rotation &+= UInt64(avoided.count &<< 3)
        rotation &+= UInt64(project.taskList.count &<< 1)
        rotation &+= quality == .plus ? 97 : 41
        var rng = SplitMix64(seed: rotation == 0 ? 1 : rotation)
        pool.shuffle(using: &rng)

        let tokens = SmartAssistantStandardIntel.actionableThemes(from: project.details, limit: 12)
        let projectBlob = [
            project.details,
            project.gameMechanics,
            project.gameGameloop,
            project.gamePlayerGoals,
            project.gameWinConditions,
            project.storyTheme,
            project.storyTypicalAction,
            project.storyHeroGoal,
            project.storyFinale,
            project.drawingMainMotif,
            project.drawingGoalEmotion,
            project.drawingCompletionDefinition,
            project.appKeyFeatures,
            project.appUserPath,
            project.appMainProblem,
            project.schoolProjectGoal,
            project.schoolMainContent,
            project.schoolSubject,
            project.schoolCompletionCriteria
        ].joined(separator: " ")
        pool.sort { lhs, rhs in
            let lTopical = SmartAssistantStandardIntel.topicalOverlapScore(
                projectText: projectBlob,
                candidate: lhs.name + " " + lhs.details
            )
            let rTopical = SmartAssistantStandardIntel.topicalOverlapScore(
                projectText: projectBlob,
                candidate: rhs.name + " " + rhs.details
            )
            // SA: premiuj konkret (fix/bug/rdzeń) nad ogólnymi szablonami.
            let lConcrete = concretenessBonus(lhs, quality: quality)
            let rConcrete = concretenessBonus(rhs, quality: quality)
            let ls = matchScore(lhs.name + " " + lhs.details, tokens: tokens)
                + lhs.importance
                + lTopical
                + lConcrete
            let rs = matchScore(rhs.name + " " + rhs.details, tokens: tokens)
                + rhs.importance
                + rTopical
                + rConcrete
            if ls != rs { return ls > rs }
            return lhs.importance > rhs.importance
        }

        // SA: ciaśniejszy top — mniej szumu z poola.
        if quality == .standard, pool.count > 14 {
            pool = Array(pool.prefix(14))
        }

        var picked: [ProposedTaskDraft] = []
        var usedNames = Set<String>()
        var usedKindCounts: [TaskKind: Int] = [:]

        for seed in pool {
            guard picked.count < 7 else { break }
            let name = seed.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !isAvoided(name) else { continue }
            // Odrzuć nazwy, które wyglądają na skopiowany opis lub meta-chore Syncly.
            if looksLikeDescriptionCopy(name, details: project.details) { continue }
            if isMetaSynclyChore(name: name, details: seed.details) { continue }
            if looksLikeAwkwardThemeTask(name) { continue }
            let key = normalizeTaskName(name)
            guard usedNames.insert(key).inserted else { continue }

            let kind = allowedKinds.contains(seed.kind) ? seed.kind : fallbackKind
            // Lekkie balansowanie rodzajów (zwłaszcza na +).
            let kindCount = usedKindCounts[kind, default: 0]
            if quality == .plus, kindCount >= 3, picked.count < 5 { continue }

            usedKindCounts[kind, default: 0] += 1
            picked.append(
                ProposedTaskDraft(
                    name: name,
                    details: seed.details.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: kind,
                    importance: min(max(seed.importance, 1), 5)
                )
            )
        }

        if picked.count < 7 {
            let fillers = fillerTasks(for: project, english: english, startIndex: picked.count)
            for seed in fillers where picked.count < 7 {
                let name = seed.name
                let key = normalizeTaskName(name)
                guard !isAvoided(name), usedNames.insert(key).inserted else { continue }
                let kind = allowedKinds.contains(seed.kind) ? seed.kind : fallbackKind
                picked.append(
                    ProposedTaskDraft(
                        name: name,
                        details: seed.details,
                        kind: kind,
                        importance: seed.importance
                    )
                )
            }
        }

        guard !picked.isEmpty else {
            throw BeSortedAIService.ServiceError.unavailable(
                "AI nie zaproponowało zadań.".l10n
            )
        }
        return Array(picked.prefix(7))
    }

    private struct LocalTaskSeed {
        var name: String
        var details: String
        var kind: TaskKind
        var importance: Int
    }

    private static func normalizeTaskName(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 }
    }

    private static let stopThemes: Set<String> = [
        "this", "that", "with", "from", "have", "will", "project", "about", "which",
        "projekt", "który", "która", "które", "oraz", "jest", "będzie", "może",
        "bardzo", "można", "przez", "jako", "tego", "tych", "tylko", "także",
        "also", "into", "your", "their", "should", "would", "could", "than"
    ]

    /// Tematy z opisu — tylko mocne rzeczowniki / frazy (nie zaimki).
    private static func meaningfulThemes(from text: String, limit: Int) -> [String] {
        SmartAssistantStandardIntel.actionableThemes(from: text, limit: limit)
    }

    private static func matchScore(_ text: String, tokens: [String]) -> Int {
        guard !tokens.isEmpty else { return 0 }
        let hay = normalizeTaskName(text)
        return tokens.reduce(0) { score, token in
            let key = normalizeTaskName(token)
            guard key.count >= 4 else { return score }
            return score + (hay.contains(key) ? 1 : 0)
        }
    }

    /// Nazwy typu „Zrób prototyp «Której» jako grywalny beat”.
    private static func looksLikeAwkwardThemeTask(_ name: String) -> Bool {
        let quoted = extractQuotedFragments(from: name)
        for q in quoted {
            let lemma = SmartAssistantStandardIntel.normalize(q)
            if !SmartAssistantStandardIntel.isLikelyContentToken(lemma) { return true }
            let parts = lemma.split(whereSeparator: \.isWhitespace)
            if parts.count == 1, lemma.count < 5 { return true }
        }
        let n = normalizeTaskName(name)
        if n.contains("prototyp") || n.contains("prototype") {
            if quoted.contains(where: {
                let p = $0.split(whereSeparator: \.isWhitespace)
                return p.count <= 1 && !SmartAssistantStandardIntel.isLikelyContentToken(SmartAssistantStandardIntel.normalize($0))
            }) {
                return true
            }
        }
        if n.contains("jako grywalny beat") || n.contains("as a playable beat") {
            return true
        }
        return false
    }

    private static func extractQuotedFragments(from text: String) -> [String] {
        var results: [String] = []
        let pairs: [(Character, Character)] = [("„", "”"), ("“", "”"), ("\"", "\""), ("'", "'")]
        for (open, close) in pairs {
            var remaining = text[...]
            while let start = remaining.firstIndex(of: open) {
                let after = remaining.index(after: start)
                guard let end = remaining[after...].firstIndex(of: close) else { break }
                let inner = String(remaining[after..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !inner.isEmpty { results.append(inner) }
                remaining = remaining[remaining.index(after: end)...]
            }
        }
        return results
    }

    private static func concretenessBonus(_ seed: LocalTaskSeed, quality: ProposeQuality) -> Int {
        let n = normalizeTaskName(seed.name)
        var bonus = 0
        if n.hasPrefix("napraw") || n.hasPrefix("fix") || n.hasPrefix("ustabilizuj") || n.hasPrefix("stabilize") {
            bonus += 3
        }
        if n.contains("odblokuj") || n.contains("unblock") { bonus += 2 }
        if seed.kind == .fix { bonus += 1 }
        if quality == .standard {
            // Premiuj stałe, konkretne deliverable bez wstawiania losowego lematu w cudzysłowie.
            if !seed.name.contains("„") && !seed.name.contains("\"") && !seed.name.contains("“") {
                bonus += 1
            }
            if n.contains("30") || n.contains("pierwsz") || n.contains("first") || n.contains("playtest")
                || n.hasPrefix("playable test") || n.hasPrefix("reguly") || n.hasPrefix("reguły")
                || n.hasPrefix("checklista") || n.hasPrefix("asset")
            {
                bonus += 1
            }
        }
        return bonus
    }

    /// Wykrywa nazwy typu „Z opisu: …” / długie cytaty z details.
    private static func looksLikeDescriptionCopy(_ name: String, details: String) -> Bool {
        let n = normalizeTaskName(name)
        if n.hasPrefix("z opisu") || n.hasPrefix("work from description") || n.hasPrefix("from description") {
            return true
        }
        let source = normalizeTaskName(details)
        guard source.count >= 24, n.count >= 24 else { return false }
        // Jeśli nazwa jest prawie w całości podszyta opisem — odrzuć.
        if source.contains(n) { return true }
        let nameTokens = Set(tokenize(name))
        guard nameTokens.count >= 4 else { return false }
        let overlap = nameTokens.filter { source.contains($0) }.count
        return Double(overlap) / Double(nameTokens.count) >= 0.85
    }

    /// Zamienia mocne tematy z opisu w konkretne AKCJE — bez wklejania zaimków / śmieci.
    private static func themeActionTasks(
        for project: Project,
        english: Bool,
        quality: ProposeQuality
    ) -> [LocalTaskSeed] {
        let limit = quality == .plus ? 4 : 3
        let themes = SmartAssistantStandardIntel.actionableThemes(
            from: project.details,
            limit: limit
        ).filter { SmartAssistantStandardIntel.isLikelyContentToken(SmartAssistantStandardIntel.normalize($0)) }
        guard !themes.isEmpty else { return [] }

        let kinds = TaskKind.kinds(for: project.kind)
        let title = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortTitle = title.isEmpty ? (english ? "the project" : "projekt") : title

        var seeds: [LocalTaskSeed] = []
        for (index, theme) in themes.enumerated() {
            let kind = kinds[index % kinds.count]
            let templates: [(String, String, Int)]
            switch project.kind {
            case .game:
                templates = english
                    ? [
                        (
                            "Playable test for \(theme)",
                            "Build a ~30s clickable/playable slice in \(shortTitle) that proves “\(theme)” feels good — one input, one feedback.",
                            5
                        ),
                        (
                            "Write player rules for \(theme)",
                            "3–5 clear rules: what the player does with \(theme), what success/fail looks like in \(shortTitle).",
                            4
                        ),
                        (
                            "Asset checklist for \(theme)",
                            "List only the art/audio/UI still blocking shipping \(theme) in \(shortTitle).",
                            3
                        )
                    ]
                    : [
                        (
                            "Playable test: \(theme)",
                            "Zrób ~30 s klikalny wycinek w „\(shortTitle)”, który udowodni, że „\(theme)” działa i daje feedback.",
                            5
                        ),
                        (
                            "Reguły gracza: \(theme)",
                            "3–5 jasnych reguł: co gracz robi z „\(theme)”, kiedy wygrywa/przegrywa w „\(shortTitle)”.",
                            4
                        ),
                        (
                            "Checklista assetów: \(theme)",
                            "Wypisz tylko grafikę/audio/UI, bez których „\(theme)” nie wejdzie do „\(shortTitle)”.",
                            3
                        )
                    ]
            case .drawing:
                templates = english
                    ? [
                        (
                            "Silhouette pass: \(theme)",
                            "Lock a readable shape for \(theme) in \(shortTitle) before detailing.",
                            5
                        ),
                        (
                            "Value study focused on \(theme)",
                            "Make \(theme) read clearly in light/dark masses inside \(shortTitle).",
                            4
                        ),
                        (
                            "Edge clean-up around \(theme)",
                            "Tighten contours so \(theme) doesn’t fight the composition.",
                            3
                        )
                    ]
                    : [
                        (
                            "Sylwetka: \(theme)",
                            "Ustal czytelny kształt „\(theme)” w „\(shortTitle)” zanim wejdą detale.",
                            5
                        ),
                        (
                            "Studium tonalne: \(theme)",
                            "Niech „\(theme)” czyta się w masach światła/cienia w „\(shortTitle)”.",
                            4
                        ),
                        (
                            "Czyste krawędzie: \(theme)",
                            "Dopnij kontury, by „\(theme)” nie walczył z kompozycją.",
                            3
                        )
                    ]
            case .story:
                templates = english
                    ? [
                        (
                            "One scene driven by \(theme)",
                            "Write a scene in \(shortTitle) where \(theme) creates conflict and a clear turn.",
                            5
                        ),
                        (
                            "Show \(theme) through action",
                            "Replace exposition about \(theme) with what a character does.",
                            4
                        ),
                        (
                            "Raise stakes around \(theme)",
                            "Decide what breaks in \(shortTitle) if \(theme) fails — one concrete consequence.",
                            3
                        )
                    ]
                    : [
                        (
                            "Scena napędzana przez: \(theme)",
                            "Napisz scenę w „\(shortTitle)”, gdzie „\(theme)” robi konflikt i wyraźny zwrot.",
                            5
                        ),
                        (
                            "Pokaż „\(theme)” działaniem",
                            "Zamiast wykładu — co postać ROBI wokół „\(theme)”.",
                            4
                        ),
                        (
                            "Stawka przy „\(theme)”",
                            "Co konkretnie pęka w „\(shortTitle)”, jeśli „\(theme)” się nie uda?",
                            3
                        )
                    ]
            case .app:
                templates = english
                    ? [
                        (
                            "Ship a vertical slice for \(theme)",
                            "Build one working end-to-end flow in \(shortTitle) that proves “\(theme)” — screen, action, feedback.",
                            5
                        ),
                        (
                            "Write the user path for \(theme)",
                            "Walk one user through the happy path that delivers \(theme) in \(shortTitle).",
                            4
                        ),
                        (
                            "De-risk the win feature: \(theme)",
                            "Test the riskiest assumption behind \(theme) with a tiny prototype or paper flow.",
                            3
                        )
                    ]
                    : [
                        (
                            "Dostarcz vertical slice dla: \(theme)",
                            "Zbuduj jeden działający flow end-to-end w „\(shortTitle)”, który udowadnia „\(theme)” — ekran, akcja, feedback.",
                            5
                        ),
                        (
                            "Ścieżka użytkownika: \(theme)",
                            "Przeprowadź jednego użytkownika ścieżką happy path, która dostarcza „\(theme)” w „\(shortTitle)”.",
                            4
                        ),
                        (
                            "Odważnik funkcji: \(theme)",
                            "Przetestuj najbardziej ryzykowną hipotezę „\(theme)” małym prototypem lub flow na papierze.",
                            3
                        )
                    ]
            case .school:
                templates = english
                    ? [
                        (
                            "Practice set: \(theme)",
                            "5–10 drills proving you can apply \(theme) for \(shortTitle).",
                            5
                        ),
                        (
                            "Outline the \(theme) section",
                            "Headings/bullets covering \(theme) in the deliverable.",
                            4
                        ),
                        (
                            "Rubric check for \(theme)",
                            "Map \(theme) to grading criteria and close the gaps.",
                            3
                        )
                    ]
                    : [
                        (
                            "Ćwiczenia: \(theme)",
                            "5–10 zadań sprawdzających „\(theme)” w kontekście „\(shortTitle)”.",
                            5
                        ),
                        (
                            "Zarys sekcji: \(theme)",
                            "Nagłówki/punkty pod część o „\(theme)” w oddaniu.",
                            4
                        ),
                        (
                            "Rubryka ↔ \(theme)",
                            "Zmapuj „\(theme)” na kryteria oceny i domknij braki.",
                            3
                        )
                    ]
            }

            let pick = templates[min(index, templates.count - 1)]
            guard !looksLikeAwkwardThemeTask(pick.0) else { continue }
            seeds.append(.init(name: pick.0, details: pick.1, kind: kind, importance: pick.2))
        }
        return seeds
    }

    /// Meta-zadania Syncly (rdzeń / pliki / opis w aplikacji) — odfiltrowywane z propozycji.
    static func isMetaSynclyChore(name: String, details: String) -> Bool {
        let hay = normalizeTaskName(name + " " + details)
        let banned = [
            "rdzen projektowy", "rdzeń projektowy", "project core", "core field",
            "uzupelnij glown", "uzupełnij główn", "uzupelnij gameloop", "uzupełnij gameloop",
            "fill core", "fill the gameloop", "fill core mechanics",
            "plikow kontekst", "plików kontekst", "context file", "context files",
            "dodaj plik", "add context", "attach context", "import context",
            "brief projektu", "project brief", "rozbuduj opis", "doprecyzuj brief",
            "write a sharper", "uzgodnij zrodla", "uzgodnij źródła", "reconcile context",
            "wypelnij rdzen", "wypełnij rdzeń",
            "wybierz gatunki w rdzeniu", "pick genres in project core",
            "wybierz strukture gry", "choose game structure",
            "zdefiniuj cele gracza w rdzeniu", "define player goals in core",
            "ustaw warunki wygranej / konca", "set win / end conditions",
            "uzupelnij opis", "uzupełnij opis projektu",
            "uzupelnij motyw", "uzupełnij motyw", "fill theme", "fill the theme",
            "uzupelnij typowa akcje", "uzupełnij typową akcję",
            "uzupelnij cel bohatera", "uzupełnij cel bohatera",
            "uzupelnij final", "uzupełnij finał", "fill finale",
            "wybierz sposob opowiadania", "wybierz sposób opowiadania", "pick narration style",
            "uzupelnij glowny motyw", "uzupełnij główny motyw",
            "uzupelnij cel i emocje", "uzupełnij cel i emocję",
            "uzupelnij definicje ukonczenia", "uzupełnij definicję ukończenia",
            "wybierz technike", "wybierz technikę", "pick technique",
            "wybierz skale i przestrzen", "wybierz skalę i przestrzeń"
        ]
        return banned.contains { hay.contains(normalizeTaskName($0)) }
    }

    /// Praca produktowa z już WYPEŁNIONEGO rdzenia (nie „uzupełnij pole”).
    /// Nazwy są konkretnymi deliverable — treść rdzenia trafia do details, nie w cudzysłów tytułu.
    private static func filledCoreWorkTasks(for project: Project, english: Bool) -> [LocalTaskSeed] {
        switch project.kind {
        case .game:
            return filledGameCoreWorkTasks(for: project, english: english)
        case .story:
            return filledStoryCoreWorkTasks(for: project, english: english)
        case .drawing:
            return filledDrawingCoreWorkTasks(for: project, english: english)
        case .app:
            return filledAppCoreWorkTasks(for: project, english: english)
        case .school:
            return filledSchoolCoreWorkTasks(for: project, english: english)
        }
    }

    private static func filledSchoolCoreWorkTasks(for project: Project, english: Bool) -> [LocalTaskSeed] {
        var seeds: [LocalTaskSeed] = []
        let title = project.name.isEmpty ? (english ? "the assignment" : "zadania") : project.name

        func clip(_ text: String, _ n: Int = 120) -> String {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return "" }
            return t.count > n ? String(t.prefix(n)) + "…" : t
        }

        let goal = clip(project.schoolProjectGoal)
        let content = clip(project.schoolMainContent)
        let subject = clip(project.schoolSubject)
        let implementation = project.schoolImplementation?.title ?? ""
        let criteria = clip(project.schoolCompletionCriteria)

        if let formTitle = project.schoolForm?.title {
            seeds.append(
                .init(
                    name: english
                        ? "Outline the \(formTitle.lowercased()) deliverable"
                        : "Zaplanuj formę oddania: \(formTitle)",
                    details: english
                        ? "Structure the \(formTitle) for \(title) — sections, beats, and what the teacher sees."
                        : "Zaplanuj strukturę \(formTitle.lowercased()) dla „\(title)” — sekcje, punkty i to, co widzi nauczyciel.",
                    kind: .schoolTask,
                    importance: 5
                )
            )
        }

        if !goal.isEmpty {
            seeds.append(
                .init(
                    name: english ? "Lock the core message" : "Ustal główne przesłanie",
                    details: english
                        ? "From core: \(goal). Pin the one message \(title) must convey — test it in one sentence."
                        : "Z rdzenia: \(goal). Ustal jedno przesłanie, które „\(title)” ma przekazać — sprawdź je w jednym zdaniu.",
                    kind: .schoolTask,
                    importance: 5
                )
            )
        }

        if !content.isEmpty {
            seeds.append(
                .init(
                    name: english ? "Gather material for the content" : "Zbierz materiał do zawartości",
                    details: english
                        ? "From core: \(content). Collect sources, facts and examples that cover it."
                        : "Z rdzenia: \(content). Zbierz źródła, fakty i przykłady pokrywające tę zawartość.",
                    kind: .materials,
                    importance: 4
                )
            )
        }

        if !subject.isEmpty {
            seeds.append(
                .init(
                    name: english ? "Understand the \(subject.lowercased()) requirements" : "Ogarnij wymagania z \(subject.lowercased())",
                    details: english
                        ? "Check the rubric and teacher expectations for \(title) in \(subject)."
                        : "Sprawdź kryteria i wymagania prowadzącego dla „\(title)” na \(subject).",
                    kind: .learning,
                    importance: 4
                )
            )
        }

        if !implementation.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Split work for \(implementation.lowercased()) mode"
                        : "Rozplanuj pracę w trybie: \(implementation)",
                    details: english
                        ? "Define roles and deadlines for \(title) given \(implementation.lowercased()) execution."
                        : "Ustal role i terminy dla „\(title)” przy realizacji \(implementation.lowercased()).",
                    kind: .schoolTask,
                    importance: 4
                )
            )
        }

        if !criteria.isEmpty {
            seeds.append(
                .init(
                    name: english ? "Build the completion checklist" : "Zbuduj checklistę ukończenia",
                    details: english
                        ? "From core: \(criteria). Turn it into a checklist you verify before submitting \(title)."
                        : "Z rdzenia: \(criteria). Zamień na checklistę, którą weryfikujesz przed oddaniem „\(title)”.",
                    kind: .schoolTask,
                    importance: 5
                )
            )
        }

        return seeds
    }

    private static func filledGameCoreWorkTasks(for project: Project, english: Bool) -> [LocalTaskSeed] {
        var seeds: [LocalTaskSeed] = []
        let title = project.name.isEmpty ? (english ? "the game" : "gry") : project.name

        func clip(_ text: String, _ n: Int = 120) -> String {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return "" }
            return t.count > n ? String(t.prefix(n)) + "…" : t
        }

        let mechanics = clip(project.gameMechanics)
        if !mechanics.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "30s playable test of the core mechanic"
                        : "30 s playable test głównej mechaniki",
                    details: english
                        ? "From core: \(mechanics). Prove it inside \(title) with one input and clear feedback."
                        : "Z rdzenia: \(mechanics). Udowodnij to w „\(title)” jednym inputem i czytelnym feedbackiem.",
                    kind: .mechanics,
                    importance: 5
                )
            )
        }
        let loop = clip(project.gameGameloop)
        if !loop.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Ship one full core-loop cycle"
                        : "Dostarcz jeden pełny cykl gameloopu",
                    details: english
                        ? "Known loop: \(loop). Build one repeatable cycle in \(title)."
                        : "Znany loop: \(loop). Zbuduj jeden powtarzalny cykl w „\(title)”.",
                    kind: .mechanics,
                    importance: 5
                )
            )
        }
        let goals = clip(project.gamePlayerGoals)
        if !goals.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Make the player goal obvious in minute one"
                        : "Niech cel gracza będzie oczywisty w 1. minucie",
                    details: english
                        ? "Known goal: \(goals). Tune onboarding/UI/feedback in \(title)."
                        : "Znany cel: \(goals). Dopracuj onboarding/UI/feedback w „\(title)”.",
                    kind: .other,
                    importance: 4
                )
            )
        }
        let win = clip(project.gameWinConditions)
        if !win.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Implement and test the win/end check"
                        : "Zaimplementuj i przetestuj warunek wygranej",
                    details: english
                        ? "Known condition: \(win). Code + verify end-to-end in \(title)."
                        : "Znany warunek: \(win). Kod + weryfikacja end-to-end w „\(title)”.",
                    kind: .mechanics,
                    importance: 4
                )
            )
        }
        return seeds
    }

    private static func filledStoryCoreWorkTasks(for project: Project, english: Bool) -> [LocalTaskSeed] {
        var seeds: [LocalTaskSeed] = []
        let title = project.name.isEmpty ? (english ? "the story" : "opowiadania") : project.name
        let kinds = TaskKind.kinds(for: .story)

        func clip(_ text: String, _ n: Int = 120) -> String {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return "" }
            return t.count > n ? String(t.prefix(n)) + "…" : t
        }

        let theme = clip(project.storyTheme)
        if !theme.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Write a scene that proves the unique theme"
                        : "Napisz scenę, która udowodni unikalny motyw",
                    details: english
                        ? "From core theme: \(theme). One scene in \(title) where only THIS story could happen."
                        : "Z motywu rdzenia: \(theme). Jedna scena w „\(title)”, która mogłaby zdarzyć się tylko w TEJ historii.",
                    kind: kinds.first ?? .other,
                    importance: 5
                )
            )
        }
        let action = clip(project.storyTypicalAction)
        if !action.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Draft a beat of the typical action"
                        : "Napisz beat typowej akcji",
                    details: english
                        ? "Known typical action: \(action). Show it on-page in \(title), not in summary."
                        : "Znana typowa akcja: \(action). Pokaż ją na stronie w „\(title)”, nie w streszczeniu.",
                    kind: kinds.count > 1 ? kinds[1] : (kinds.first ?? .other),
                    importance: 5
                )
            )
        }
        let goal = clip(project.storyHeroGoal)
        if !goal.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Put the hero’s goal under pressure"
                        : "Postaw cel bohatera pod presją",
                    details: english
                        ? "Known goal: \(goal). One obstacle that threatens it in \(title)."
                        : "Znany cel: \(goal). Jedna przeszkoda, która go zagrozi w „\(title)”.",
                    kind: kinds.first ?? .other,
                    importance: 4
                )
            )
        }
        let finale = clip(project.storyFinale)
        if !finale.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Outline the finale payoff beat"
                        : "Zarysuj beat wypłaty finału",
                    details: english
                        ? "Known finale: \(finale). Sketch the last turn so it lands as planned in \(title)."
                        : "Znany finał: \(finale). Zarysuj ostatni zwrot, by wypłata w „\(title)” wyszła jak w rdzeniu.",
                    kind: kinds.count > 1 ? kinds[1] : (kinds.first ?? .other),
                    importance: 4
                )
            )
        }
        return seeds
    }

    private static func filledDrawingCoreWorkTasks(for project: Project, english: Bool) -> [LocalTaskSeed] {
        var seeds: [LocalTaskSeed] = []
        let title = project.name.isEmpty ? (english ? "the drawing" : "rysunku") : project.name
        let kinds = TaskKind.kinds(for: .drawing)

        func clip(_ text: String, _ n: Int = 120) -> String {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return "" }
            return t.count > n ? String(t.prefix(n)) + "…" : t
        }

        if !project.drawingTechniques.isEmpty {
            let techniques = project.drawingTechniques.sorted { $0.title < $1.title }.map(\.title).joined(separator: ", ")
            seeds.append(
                .init(
                    name: english
                        ? "Commit to the chosen technique pass"
                        : "Domknij pass wybranej techniki",
                    details: english
                        ? "Techniques from core: \(techniques). Push one finishable pass on \(title)."
                        : "Techniki z rdzenia: \(techniques). Zrób jeden domykalny pass na „\(title)”.",
                    kind: kinds.first ?? .other,
                    importance: 5
                )
            )
        }
        let motif = clip(project.drawingMainMotif)
        if !motif.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Lock the silhouette of the main motif"
                        : "Domknij sylwetkę głównego motywu",
                    details: english
                        ? "Main motif: \(motif). Make it read first in \(title)."
                        : "Główny motyw: \(motif). Niech czyta się jako pierwszy w „\(title)”.",
                    kind: kinds.first ?? .other,
                    importance: 5
                )
            )
        }
        let emotion = clip(project.drawingGoalEmotion)
        if !emotion.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Push values/color toward the intended emotion"
                        : "Dopnij wartości/kolor pod zamierzoną emocję",
                    details: english
                        ? "Goal & emotion: \(emotion). Adjust light/color so \(title) carries it."
                        : "Cel i emocja: \(emotion). Ustaw światło/kolor, by „\(title)” to niosło.",
                    kind: kinds.count > 1 ? kinds[1] : (kinds.first ?? .other),
                    importance: 4
                )
            )
        }
        let done = clip(project.drawingCompletionDefinition)
        if !done.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Checklist against the completion definition"
                        : "Checklista względem definicji ukończenia",
                    details: english
                        ? "Done when: \(done). Mark what’s left on \(title) and close gaps."
                        : "Ukończone gdy: \(done). Oznacz braki w „\(title)” i domknij je.",
                    kind: kinds.count > 1 ? kinds[1] : (kinds.first ?? .other),
                    importance: 4
                )
            )
        }
        if project.drawingScale == .largeScene {
            seeds.append(
                .init(
                    name: english
                        ? "Block out the large scene layout"
                        : "Rozłóż layout rozbudowanej sceny",
                    details: english
                        ? "Core scale is a large detailed scene — place characters/elements before polishing \(title)."
                        : "Skala w rdzeniu to rozbudowana scena — ustaw postacie/elementy zanim dopracujesz „\(title)”.",
                    kind: kinds.first ?? .other,
                    importance: 4
                )
            )
        } else if project.drawingScale == .singleFocus {
            seeds.append(
                .init(
                    name: english
                        ? "Simplify background around the single focus"
                        : "Uprość tło wokół jednego fokusu",
                    details: english
                        ? "Core scale is single character / simple background — keep \(title) readable."
                        : "Skala w rdzeniu to jedna postać / proste tło — utrzymaj czytelność „\(title)”.",
                    kind: kinds.first ?? .other,
                    importance: 3
                )
            )
        }
        return seeds
    }

    private static func filledAppCoreWorkTasks(for project: Project, english: Bool) -> [LocalTaskSeed] {
        var seeds: [LocalTaskSeed] = []
        let title = project.name.isEmpty ? (english ? "the app" : "aplikacji") : project.name
        let kinds = TaskKind.kinds(for: .app)

        func clip(_ text: String, _ n: Int = 120) -> String {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return "" }
            return t.count > n ? String(t.prefix(n)) + "…" : t
        }

        let features = clip(project.appKeyFeatures)
        if !features.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Ship the win feature end-to-end"
                        : "Dostarcz funkcję-wyróżnik end-to-end",
                    details: english
                        ? "Key features from core: \(features). Build the DIFFERENTIATING flow of \(title) so it works end-to-end."
                        : "Kluczowe funkcjonalności z rdzenia: \(features). Zbuduj WYRÓŻNIAJĄCY flow „\(title)”, by działał end-to-end.",
                    kind: kinds.count > 1 ? kinds[1] : (kinds.first ?? .other),
                    importance: 5
                )
            )
        }
        let path = clip(project.appUserPath)
        if !path.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Map and de-friction the core user path"
                        : "Zmapuj i wygładź główną ścieżkę użytkownika",
                    details: english
                        ? "Known user path: \(path). Walk one user through the happy path of \(title) and remove friction."
                        : "Znana ścieżka: \(path). Przeprowadź użytkownika happy pathem „\(title)” i usuń tarcia.",
                    kind: kinds.first ?? .other,
                    importance: 5
                )
            )
        }
        let problem = clip(project.appMainProblem)
        if !problem.isEmpty {
            seeds.append(
                .init(
                    name: english
                        ? "Validate the app against its main problem"
                        : "Zweryfikuj aplikację względem głównego problemu",
                    details: english
                        ? "Core problem: \(problem). Check the current flow of \(title) actually solves it — fix the gap."
                        : "Główny problem: \(problem). Sprawdź, czy obecny flow „\(title)” faktycznie go rozwiązuje — załataj lukę.",
                    kind: kinds.first ?? .other,
                    importance: 4
                )
            )
        }
        if let category = project.appCategory {
            let cat = category.title
            seeds.append(
                .init(
                    name: english
                        ? "Fit \(title) to the \(cat) category conventions"
                        : "Dopasuj „\(title)” do konwencji kategorii \(cat)",
                    details: english
                        ? "Core category: \(cat). Check onboarding, IA and expected patterns feel native for this category."
                        : "Kategoria z rdzenia: \(cat). Sprawdź, czy onboarding, IA i oczekiwane wzorce są naturalne dla tej kategorii.",
                    kind: kinds.count > 1 ? kinds[1] : (kinds.first ?? .other),
                    importance: 3
                )
            )
        }
        return seeds
    }

    /// Postęp produktu: kamień milowy / odblokowanie istniejącego zadania / błędy.
    private static func projectProgressTasks(
        for project: Project,
        english: Bool,
        quality: ProposeQuality
    ) -> [LocalTaskSeed] {
        var seeds: [LocalTaskSeed] = []
        let kinds = TaskKind.kinds(for: project.kind)
        let title = project.name.isEmpty ? (english ? "the project" : "projekt") : project.name
        let open = project.taskList.filter { !$0.isCompleted && !Project.isMeaninglessLabel($0.name) }

        if open.isEmpty {
            seeds.append(
                .init(
                    name: english ? "Ship the first playable / visible slice" : "Dostarcz pierwszy grywalny / widoczny wycinek",
                    details: english
                        ? "One finishable slice of \(title) based on what you already know from the description/core."
                        : "Jeden domykalny wycinek „\(title)” na podstawie tego, co już wiadomo z opisu/rdzenia.",
                    kind: kinds.first ?? .other,
                    importance: 5
                )
            )
        } else if quality == .plus, let top = open.sorted(by: { $0.importance > $1.importance }).first {
            seeds.append(
                .init(
                    name: english ? "Unblock “\(top.name)”" : "Odblokuj „\(top.name)”",
                    details: english
                        ? "Resolve the dependency or decision stopping this high-priority open task."
                        : "Domknij zależność/decyzję blokującą to ważne otwarte zadanie.",
                    kind: .fix,
                    importance: min(5, top.importance + 1)
                )
            )
        }

        let bugLimit = quality == .plus ? 2 : 1
        for bug in project.bugList.sorted(by: { $0.severity > $1.severity }).prefix(bugLimit)
        where !Project.isMeaninglessLabel(bug.title) {
            seeds.append(
                .init(
                    name: english ? "Fix: \(bug.title)" : "Napraw: \(bug.title)",
                    details: english
                        ? "Land a focused fix for severity \(bug.severity)/5 in \(title)."
                        : "Domknij skupiony fix przy wadze \(bug.severity)/5 w „\(title)”.",
                    kind: .fix,
                    importance: min(5, max(3, bug.severity))
                )
            )
        }

        return seeds
    }

    private static func plusProductWorkTasks(for project: Project, english: Bool) -> [LocalTaskSeed] {
        var seeds: [LocalTaskSeed] = []
        let kinds = TaskKind.kinds(for: project.kind)

        let severeBugs = project.bugList.filter { $0.severity >= 4 && !Project.isMeaninglessLabel($0.title) }
        for bug in severeBugs.prefix(2) {
            seeds.append(
                .init(
                    name: english ? "Stabilize: \(bug.title)" : "Ustabilizuj: \(bug.title)",
                    details: english
                        ? "Reproduce, isolate, and land a fix for severity \(bug.severity)/5."
                        : "Odtwórz, wyizoluj i domknij fix przy wadze \(bug.severity)/5.",
                    kind: .fix,
                    importance: min(5, bug.severity)
                )
            )
        }

        if let note = project.futureNoteList.sorted(by: { $0.createdAt > $1.createdAt }).first {
            let body = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if body.count >= 12 {
                seeds.append(
                    .init(
                        name: english
                            ? "Turn newest future note into a deliverable"
                            : "Zamień najnowszą notatkę w deliverable",
                        details: english
                            ? "From your plans: \(String(body.prefix(160))). Make one finishable product step for \(project.name)."
                            : "Z planów: \(String(body.prefix(160))). Zrób jeden domykalny krok produktu dla „\(project.name)”.",
                        kind: kinds.count > 1 ? kinds[1] : (kinds.first ?? .other),
                        importance: 4
                    )
                )
            }
        }

        return seeds
    }

    private static func baseTaskPool(for project: Project, english: Bool) -> [LocalTaskSeed] {
        let title = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortTitle = title.isEmpty
            ? (english ? "the project" : "projektu")
            : title

        switch project.kind {
        case .game:
            return [
                .init(
                    name: english ? "Define the core loop" : "Zdefiniuj główny gameloop",
                    details: english
                        ? "Write what the player repeatedly does in \(shortTitle) and why it stays fun."
                        : "Opisz, co gracz cyklicznie robi w „\(shortTitle)” i dlaczego to ma trzymać uwagę.",
                    kind: .mechanics,
                    importance: 5
                ),
                .init(
                    name: english ? "List required materials / assets" : "Wypisz potrzebne materiały / assety",
                    details: english
                        ? "Inventory sprites, audio, UI and other resources still missing."
                        : "Zrób listę sprite’ów, dźwięków, UI i innych zasobów, których jeszcze brakuje.",
                    kind: .materials,
                    importance: 4
                ),
                .init(
                    name: english ? "Prototype the main mechanic" : "Zrób prototyp głównej mechaniki",
                    details: english
                        ? "Build a minimal playable slice that proves the key interaction."
                        : "Zbuduj minimalny playable slice, który udowodni kluczowe interakcje.",
                    kind: .mechanics,
                    importance: 5
                ),
                .init(
                    name: english ? "Fix the biggest playability blocker" : "Napraw największą blokadę grywalności",
                    details: english
                        ? "Prioritize the bug or friction that stops a short playtest."
                        : "Ustal i usuń błąd / tarcie, które blokuje krótki playtest.",
                    kind: .fix,
                    importance: 5
                ),
                .init(
                    name: english ? "Clarify win / fail conditions" : "Doprecyzuj warunki wygranej / porażki",
                    details: english
                        ? "Make success and failure rules explicit and testable."
                        : "Uczyń reguły sukcesu i porażki jasne oraz testowalne.",
                    kind: .mechanics,
                    importance: 4
                ),
                .init(
                    name: english ? "Prepare a first-level slice" : "Przygotuj wycinek pierwszego poziomu",
                    details: english
                        ? "One short scene/level good enough for feedback."
                        : "Jedna krótka scena / poziom wystarczająca do zebrania feedbacku.",
                    kind: .other,
                    importance: 3
                ),
                .init(
                    name: english ? "Balance early difficulty" : "Zbalansuj wczesną trudność",
                    details: english
                        ? "Tune the first minutes so new players understand and progress."
                        : "Ustaw pierwsze minuty tak, by nowy gracz rozumiał zasady i szedł do przodu.",
                    kind: .fix,
                    importance: 3
                ),
                .init(
                    name: english ? "Add temporary debug tools" : "Dodaj tymczasowe narzędzia debug",
                    details: english
                        ? "Cheats/skips that speed up iterating on \(shortTitle)."
                        : "Cheaty / skróty przyspieszające iterację nad „\(shortTitle)”.",
                    kind: .other,
                    importance: 2
                ),
                .init(
                    name: english ? "Collect placeholder art pack" : "Zbierz placeholderowy pakiet grafiki",
                    details: english
                        ? "Block out visuals so mechanics can be tested without final art."
                        : "Wstaw placeholdery, by testować mechaniki bez finalnej grafiki.",
                    kind: .materials,
                    importance: 3
                )
            ]
        case .drawing:
            return [
                .init(
                    name: english ? "Lock the composition sketch" : "Domknij szkic kompozycji",
                    details: english
                        ? "Decide framing, focal point and silhouette for \(shortTitle)."
                        : "Ustal kadrowanie, punkt fokusowy i sylwetkę dla „\(shortTitle)”.",
                    kind: .sketch,
                    importance: 5
                ),
                .init(
                    name: english ? "Block in main values" : "Rozłóż główne wartości tonalne",
                    details: english
                        ? "Establish light/dark masses before detail."
                        : "Ustal masy światła i cienia przed detalami.",
                    kind: .sketch,
                    importance: 4
                ),
                .init(
                    name: english ? "Refine the hero element" : "Dopracuj element wiodący",
                    details: english
                        ? "Polish the part the viewer should notice first."
                        : "Wypoleruj fragment, który odbiorca ma zauważyć jako pierwszy.",
                    kind: .element,
                    importance: 5
                ),
                .init(
                    name: english ? "Clean edge and shape errors" : "Wyczyść błędy krawędzi i kształtów",
                    details: english
                        ? "Fix proportions and awkward contours."
                        : "Popraw proporcje i niezręczne kontury.",
                    kind: .polish,
                    importance: 4
                ),
                .init(
                    name: english ? "Decide color / material pass" : "Ustal przejście koloru / materiału",
                    details: english
                        ? "Pick a limited palette and apply it consistently."
                        : "Wybierz ograniczoną paletę i zastosuj ją konsekwentnie.",
                    kind: .polish,
                    importance: 3
                ),
                .init(
                    name: english ? "Add supporting background detail" : "Dodaj wspierający detal tła",
                    details: english
                        ? "Support the subject without stealing focus."
                        : "Wspieraj temat, nie zabierając mu uwagi.",
                    kind: .element,
                    importance: 3
                ),
                .init(
                    name: english ? "Final contrast and clarity pass" : "Finalny pass kontrastu i czytelności",
                    details: english
                        ? "Check readability at thumbnail size."
                        : "Sprawdź czytelność w małym podglądzie (thumbnail).",
                    kind: .polish,
                    importance: 4
                ),
                .init(
                    name: english ? "Export review variants" : "Wyeksportuj warianty do przeglądu",
                    details: english
                        ? "Prepare 2–3 versions for feedback."
                        : "Przygotuj 2–3 wersje pod feedback.",
                    kind: .other,
                    importance: 2
                )
            ]
        case .story:
            return [
                .init(
                    name: english ? "Clarify protagonist goal" : "Doprecyzuj cel protagonisty",
                    details: english
                        ? "What does the main character want in \(shortTitle), and what blocks them?"
                        : "Czego chce główna postać w „\(shortTitle)” i co ją blokuje?",
                    kind: .character,
                    importance: 5
                ),
                .init(
                    name: english ? "Outline the next key scene" : "Zarysuj kolejną kluczową scenę",
                    details: english
                        ? "Conflict, turn, and outcome in one short beat."
                        : "Konflikt, zwrot i skutek w jednym krótkim bicie sceny.",
                    kind: .scene,
                    importance: 5
                ),
                .init(
                    name: english ? "Strengthen antagonist / obstacle" : "Wzmocnij antagonistę / przeszkodę",
                    details: english
                        ? "Make opposition concrete and active."
                        : "Uczyń opór konkretny i aktywny.",
                    kind: .character,
                    importance: 4
                ),
                .init(
                    name: english ? "Fix the weakest plot link" : "Napraw najsłabsze ogniwo fabuły",
                    details: english
                        ? "Repair the moment that currently feels unearned."
                        : "Popraw moment, który dziś wygląda na niezasłużony / dziurawy.",
                    kind: .fix,
                    importance: 4
                ),
                .init(
                    name: english ? "Write dialogue that advances plot" : "Napisz dialog pchanący fabułę",
                    details: english
                        ? "One exchange that reveals character and moves the story."
                        : "Jedna wymiana, która odkrywa postać i przesuwa historię.",
                    kind: .scene,
                    importance: 3
                ),
                .init(
                    name: english ? "Cut redundant exposition" : "Wytnij zbędną ekspozycję",
                    details: english
                        ? "Remove lines that only restate known facts."
                        : "Usuń fragmenty, które tylko powtarzają znane fakty.",
                    kind: .fix,
                    importance: 3
                ),
                .init(
                    name: english ? "Define stakes for the midpoint" : "Ustal stawki na midpoint",
                    details: english
                        ? "What changes forever if the hero fails here?"
                        : "Co zmienia się nieodwracalnie, jeśli bohater tu przegra?",
                    kind: .other,
                    importance: 4
                ),
                .init(
                    name: english ? "List open plot threads" : "Wypisz otwarte wątki fabularne",
                    details: english
                        ? "Track promises still unpaid to the reader."
                        : "Spisz obietnice wobec czytelnika, które jeszcze wiszą.",
                    kind: .other,
                    importance: 2
                )
            ]
        case .app:
            return [
                .init(
                    name: english ? "Define the key differentiator" : "Zdefiniuj kluczowy wyróżnik",
                    details: english
                        ? "What makes \(shortTitle) worth using — one clear win feature."
                        : "Co sprawia, że „\(shortTitle)” jest warta używania — jedna jasna funkcja-wyróżnik.",
                    kind: .other,
                    importance: 5
                ),
                .init(
                    name: english ? "Map the core user path" : "Zmapuj główną ścieżkę użytkownika",
                    details: english
                        ? "Sketch the happy path: launch → first value → habit in \(shortTitle)."
                        : "Naszkicuj happy path: start → pierwsza wartość → nawyk w „\(shortTitle)”.",
                    kind: .other,
                    importance: 5
                ),
                .init(
                    name: english ? "Write the main problem statement" : "Sformułuj główny problem",
                    details: english
                        ? "Pin down the pain \(shortTitle) solves and for whom."
                        : "Ustal, jaki ból rozwiązuje „\(shortTitle)” i dla kogo.",
                    kind: .other,
                    importance: 4
                ),
                .init(
                    name: english ? "Scrap the first blue-screen prototype" : "Ogarnij pierwszy prototyp szkieletu ekranów",
                    details: english
                        ? "Wireframe the screens that carry the core path of \(shortTitle)."
                        : "Naszkicuj (wireframe) ekrany niosące główną ścieżkę „\(shortTitle)”.",
                    kind: .other,
                    importance: 4
                ),
                .init(
                    name: english ? "Fix the biggest onboarding blocker" : "Napraw największą blokadę onboardingu",
                    details: english
                        ? "Prioritize the friction that stops a new user from reaching the first value."
                        : "Usuń tarcie, które blokuje nowego użytkownika przed dotarciem do pierwszej wartości.",
                    kind: .fix,
                    importance: 5
                ),
                .init(
                    name: english ? "List edge cases for the win feature" : "Wypisz edge case'y funkcji-wyróżnika",
                    details: english
                        ? "Enumerate error states and empty states around the key flow."
                        : "Wypisz stany błędów i puste stany wokół kluczowego flow.",
                    kind: .fix,
                    importance: 3
                ),
                .init(
                    name: english ? "Polish the first-run experience" : "Dopracuj doświadczenie pierwszego uruchomienia",
                    details: english
                        ? "Onboarding copy, empty states and one clear call to action in \(shortTitle)."
                        : "Copy onboardingu, puste stany i jedno jasne wezwanie do akcji w „\(shortTitle)”.",
                    kind: .polish,
                    importance: 4
                ),
                .init(
                    name: english ? "Audit accessibility of the core flow" : "Przejrzyj dostępność głównego flow",
                    details: english
                        ? "Check contrast, hit targets and VoiceOver on the core path."
                        : "Sprawdź kontrast, wielkość klikanych elementów i VoiceOver na głównej ścieżce.",
                    kind: .fix,
                    importance: 3
                ),
                .init(
                    name: english ? "Collect placeholder icon / art set" : "Zbierz placeholderowe ikony / grafikę",
                    details: english
                        ? "Block out visuals so the flow can be tested without final graphics."
                        : "Wstaw placeholdery, by testować flow bez finalnej grafiki.",
                    kind: .materials,
                    importance: 2
                )
            ]
        case .school:
            return [
                .init(
                    name: english ? "Break the assignment into steps" : "Rozbij zadanie na kroki",
                    details: english
                        ? "Turn \(shortTitle) into a checklist with deadlines."
                        : "Zamień „\(shortTitle)” na checklistę z terminami.",
                    kind: .schoolTask,
                    importance: 5
                ),
                .init(
                    name: english ? "Gather required materials" : "Zbierz wymagane materiały",
                    details: english
                        ? "Notes, sources, files and tools needed to start."
                        : "Notatki, źródła, pliki i narzędzia potrzebne do startu.",
                    kind: .schoolTask,
                    importance: 4
                ),
                .init(
                    name: english ? "Study the hardest topic first" : "Najpierw ogarnij najtrudniejszy temat",
                    details: english
                        ? "Focus learning time where the grade risk is highest."
                        : "Skup naukę tam, gdzie ryzyko oceny jest największe.",
                    kind: .learning,
                    importance: 5
                ),
                .init(
                    name: english ? "Make a short practice set" : "Zrób krótki zestaw ćwiczeń",
                    details: english
                        ? "5–10 drills that check understanding."
                        : "5–10 ćwiczeń sprawdzających zrozumienie.",
                    kind: .learning,
                    importance: 4
                ),
                .init(
                    name: english ? "Draft the deliverable outline" : "Zrób szkic struktury oddania",
                    details: english
                        ? "Headings / sections before writing the full piece."
                        : "Nagłówki / sekcje przed pisaniem pełnej wersji.",
                    kind: .schoolTask,
                    importance: 4
                ),
                .init(
                    name: english ? "Fix unclear requirements" : "Doprecyzuj niejasne wymagania",
                    details: english
                        ? "List questions for the teacher or rubric gaps."
                        : "Wypisz pytania do prowadzącego lub braki w kryteriach.",
                    kind: .fix,
                    importance: 3
                ),
                .init(
                    name: english ? "Review and polish the draft" : "Zrób przegląd i polish szkicu",
                    details: english
                        ? "Check completeness, citations and clarity."
                        : "Sprawdź kompletność, cytowania i czytelność.",
                    kind: .fix,
                    importance: 3
                ),
                .init(
                    name: english ? "Prepare a final checklist" : "Przygotuj checklistę końcową",
                    details: english
                        ? "What must be true before submission."
                        : "Co musi być prawdziwe przed oddaniem.",
                    kind: .other,
                    importance: 2
                )
            ]
        }
    }

    private static func fillerTasks(
        for project: Project,
        english: Bool,
        startIndex _: Int
    ) -> [LocalTaskSeed] {
        let kinds = TaskKind.kinds(for: project.kind)
        let labelsEN = [
            "Ship the next finishable slice",
            "Close the highest-friction gap",
            "Prove one interaction end-to-end",
            "Prepare assets blocking progress",
            "Tighten clarity for first-time users",
            "Resolve the top open dependency",
            "Land a focused quality pass"
        ]
        let labelsPL = [
            "Dostarcz kolejny domykalny wycinek",
            "Domknij największe tarcie",
            "Udowodnij jedną interakcję end-to-end",
            "Przygotuj assety blokujące postęp",
            "Doprecyzuj czytelność dla nowych osób",
            "Rozwiąż najważniejszą otwartą zależność",
            "Zrób skupiony pass jakości"
        ]
        return (0..<7).map { offset in
            let kind = kinds[offset % kinds.count]
            let label = english ? labelsEN[offset % labelsEN.count] : labelsPL[offset % labelsPL.count]
            return .init(
                name: "\(label) (\(kind.title))",
                details: english
                    ? "Concrete follow-up focused on \(kind.title.lowercased()) for \(project.name)."
                    : "Konkretne uzupełnienie pod kątem „\(kind.title)” w projekcie \(project.name).",
                kind: kind,
                importance: max(1, 4 - (offset / 2))
            )
        }
    }

    /// Mały PRNG do deterministycznego shuffle bez Foundation dependency poza stdlib.
    private struct SplitMix64: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
            return z ^ (z &>> 31)
        }
    }

    /// Dobór zadań do planu bez modelu — kwoty + gwiazdki (jak awaryjny fallback FM).
    static func selectTasksForCurrentPlan(
        priorityProjects: [Project],
        targetCount: Int
    ) throws -> [BeSortedAIService.PlanFillItem] {
        let projects = priorityProjects.filter(\.isPriorityHighlighted)
        guard !projects.isEmpty else {
            throw BeSortedAIService.ServiceError.unavailable(
                "Najpierw oznacz projekty jako priorytetowe.".l10n
            )
        }

        let ordered = projects.sorted {
            if $0.importance != $1.importance { return $0.importance > $1.importance }
            return $0.createdAt < $1.createdAt
        }

        func candidates(for project: Project) -> [ProjectTask] {
            project.taskList
                .filter { !$0.isCompleted && !$0.isInCurrentPlan && $0.planQueuedAt == nil }
                .sorted {
                    let ls = SmartAssistantStandardIntel.planTaskScore(task: $0, project: project)
                    let rs = SmartAssistantStandardIntel.planTaskScore(task: $1, project: project)
                    if ls != rs { return ls > rs }
                    if $0.importance != $1.importance { return $0.importance > $1.importance }
                    return $0.createdAt < $1.createdAt
                }
        }

        guard ordered.contains(where: { !candidates(for: $0).isEmpty }) else {
            throw BeSortedAIService.ServiceError.unavailable(
                "Brak istniejących zadań w projektach priorytetowych. Dodaj zadania w projekcie albo użyj „Zaproponuj zadania”.".l10n
            )
        }

        var selected: [BeSortedAIService.PlanFillItem] = []
        var used = Set<PersistentIdentifier>()
        var remaining = targetCount

        // Runda 1: preferuj ważniejsze projekty (więcej slotów na start).
        let primaryShare = ordered.count == 1 ? targetCount : min(4, max(1, targetCount - (ordered.count - 1)))
        for (index, project) in ordered.enumerated() {
            guard remaining > 0 else { break }
            let limit = index == 0 ? min(primaryShare, remaining) : min(max(1, remaining / max(1, ordered.count - index)), remaining)
            var taken = 0
            for task in candidates(for: project) {
                guard remaining > 0, taken < limit else { break }
                guard !used.contains(task.persistentModelID) else { continue }
                used.insert(task.persistentModelID)
                selected.append(.init(project: project, existingTask: task, draft: nil))
                remaining -= 1
                taken += 1
            }
        }

        // Runda 2: dobierz resztę od najważniejszego.
        for project in ordered where remaining > 0 {
            for task in candidates(for: project) {
                guard remaining > 0 else { break }
                guard !used.contains(task.persistentModelID) else { continue }
                used.insert(task.persistentModelID)
                selected.append(.init(project: project, existingTask: task, draft: nil))
                remaining -= 1
            }
        }

        guard !selected.isEmpty else {
            throw BeSortedAIService.ServiceError.unavailable(
                "Brak istniejących zadań w projektach priorytetowych. Dodaj zadania w projekcie albo użyj „Zaproponuj zadania”.".l10n
            )
        }
        return selected
    }
}
