//
//  SmartAssistantViews.swift
//  BeSorted
//

import SwiftUI

/// Kafelek w ustawieniach + okienko wersji / informacji.
struct SmartAssistantSettingsCard: View {
    @Environment(AppAppearance.self) private var appearance
    /// Zawsze wywołuj present — nie Binding bool (gdy true→true set może się nie odpalić).
    var onActivate: () -> Void
    @Bindable private var store = SmartAssistantStore.shared

    var body: some View {
        let active = store.activeTier

        HStack(alignment: .center, spacing: 12) {
            SmartAssistantBrandedTitle(
                tier: active,
                baseColor: appearance.primaryText,
                font: .headline.weight(.semibold)
            )

            Spacer(minLength: 8)

            if appearance.isNeomorphic {
                // Referencja: płaski kapsułowy accentRed + miękki cień, biały tekst.
                Button {
                    onActivate()
                } label: {
                    Text((active != nil ? "Zmień" : "Aktywuj").l10n)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(appearance.neoAccentRed)
                                .shadow(color: appearance.neoShadow.opacity(0.4), radius: 5, x: 2, y: 3)
                        )
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            } else {
                Button {
                    onActivate()
                } label: {
                    Text((active != nil ? "Zmień" : "Aktywuj").l10n)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(appearance.selectedTabForeground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .besortedGlass(
            appearance,
            interactive: false,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 16),
            role: .content
        )
    }
}

/// „Smart Assistant” + opcjonalnie złote „Pro” / limonkowe „+”.
struct SmartAssistantBrandedTitle: View {
    let tier: SmartAssistantTier?
    let baseColor: Color
    var font: Font = .headline.weight(.semibold)

    var body: some View {
        HStack(spacing: 0) {
            Text("Smart Assistant")
                .font(font)
                .foregroundStyle(baseColor)

            switch tier {
            case .pro:
                Text(" ")
                    .font(font)
                    .foregroundStyle(baseColor)
                Text("Pro")
                    .font(font)
                    .foregroundStyle(SmartAssistantBrandGradients.pro)
            case .plus:
                Text(" ")
                    .font(font)
                    .foregroundStyle(baseColor)
                Text("+")
                    .font(font)
                    .foregroundStyle(SmartAssistantBrandGradients.plus)
            case .standard, .none:
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityTitle)
    }

    private var accessibilityTitle: String {
        switch tier {
        case .pro: "Smart Assistant Pro"
        case .plus: "Smart Assistant +"
        case .standard, .none: "Smart Assistant"
        }
    }
}

/// Opis z podświetleniem „Pro” / „+” tylko jako suffix Smart Assistant
/// (np. „Smart Assistant Pro”) — nie w nazwach sprzętu typu „15 Pro”.
struct SmartAssistantBrandedText: View {
    let text: String
    let baseColor: Color
    var font: Font = .subheadline.weight(.medium)

    private static let productPrefix = "Smart Assistant "

    var body: some View {
        combinedText
            .font(font)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var combinedText: Text {
        segments.reduce(Text("")) { partial, segment in
            switch segment {
            case .plain(let value):
                return partial + Text(value).foregroundStyle(baseColor)
            case .pro:
                return partial + Text("Pro").foregroundStyle(SmartAssistantBrandGradients.pro)
            case .plus:
                return partial + Text("+").foregroundStyle(SmartAssistantBrandGradients.plus)
            }
        }
    }

    private enum Segment {
        case plain(String)
        case pro
        case plus
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var remaining = text
        while !remaining.isEmpty {
            guard let match = nextProductSuffix(in: remaining) else {
                result.append(.plain(remaining))
                break
            }
            let prefix = String(remaining[..<match.range.lowerBound])
            if !prefix.isEmpty {
                result.append(.plain(prefix))
            }
            result.append(match.kind)
            remaining = String(remaining[match.range.upperBound...])
        }
        return result
    }

    private func nextProductSuffix(in text: String) -> (range: Range<String.Index>, kind: Segment)? {
        let prefix = Self.productPrefix
        var searchStart = text.startIndex
        while searchStart < text.endIndex {
            guard let prefixRange = text.range(of: prefix, range: searchStart..<text.endIndex) else {
                return nil
            }
            let after = prefixRange.upperBound
            if text[after...].hasPrefix("Pro") {
                let end = text.index(after, offsetBy: 3)
                return (after..<end, .pro)
            }
            if text[after...].hasPrefix("+") {
                let end = text.index(after, offsetBy: 1)
                return (after..<end, .plus)
            }
            searchStart = prefixRange.upperBound
        }
        return nil
    }
}

enum SmartAssistantBrandGradients {
    static let proGold: [Color] = [
        Color(red: 1.00, green: 0.92, blue: 0.45),
        Color(red: 0.98, green: 0.78, blue: 0.18),
        Color(red: 0.82, green: 0.58, blue: 0.08)
    ]

    static let plusLime: [Color] = [
        Color(red: 0.82, green: 1.00, blue: 0.38),
        Color(red: 0.58, green: 0.92, blue: 0.18),
        Color(red: 0.38, green: 0.78, blue: 0.10)
    ]

    static var pro: LinearGradient {
        LinearGradient(colors: proGold, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var plus: LinearGradient {
        LinearGradient(colors: plusLime, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct SmartAssistantActivateOverlay: View {
    @Binding var isPresented: Bool
    var onProUnlocked: () -> Void = {}
    @Environment(AppAppearance.self) private var appearance

    @State private var infoTier: SmartAssistantTier?
    @State private var showFeatureTour = false
    /// Tier pokazywany w przewodniku (aktywny / najwyższy albo konkretny z Informacji).
    @State private var featureTourTier: SmartAssistantTier?
    /// Intro pastylki Liquid Glass po aktywacji / zakupie dowolnego modelu.
    @State private var celebrationTier: SmartAssistantTier?
    /// Odświeżanie UI po zakupie / aktywacji.
    @State private var refreshTick = 0

    private var tourTier: SmartAssistantTier {
        let store = SmartAssistantStore.shared
        if let active = store.activeTier { return active }
        return SmartAssistantTier.allCases
            .filter(store.owns)
            .max(by: { $0.rank < $1.rank }) ?? .standard
    }

    private var activeFeatureTourTier: SmartAssistantTier {
        featureTourTier ?? tourTier
    }

    var body: some View {
        ZStack {
            if let celebrationTier {
                SmartAssistantActivationIntroView(
                    tier: celebrationTier,
                    onFinished: {
                        let wasPro = celebrationTier == .pro
                        withAnimation(.smooth(duration: 0.28)) {
                            self.celebrationTier = nil
                        }
                        isPresented = false
                        if wasPro {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                onProUnlocked()
                            }
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(3)
            } else if showFeatureTour {
                SmartAssistantFeatureTourView(
                    tier: activeFeatureTourTier,
                    onClose: {
                        withAnimation(.smooth(duration: 0.34)) {
                            showFeatureTour = false
                            featureTourTier = nil
                        }
                    }
                )
                .transition(
                    .opacity.combined(with: .scale(scale: 0.97, anchor: .center))
                )
                .zIndex(2)
            } else {
                DropInModalChrome(onClose: { isPresented = false }) { requestClose in
                    Group {
                        if let infoTier {
                            infoPanel(for: infoTier, requestClose: requestClose)
                        } else {
                            plansPanel(requestClose: requestClose)
                        }
                    }
                    .id(refreshTick)
                    .onAppear {
                        SmartAssistantStore.shared.sanitizeOwnedForCurrentDevice()
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.34), value: showFeatureTour)
        .animation(.smooth(duration: 0.34), value: celebrationTier)
    }

    /// Po aktywacji / zakupie — intro pastylki; poświata ustawień tylko dla Pro.
    private func finishActivation(_ tier: SmartAssistantTier) {
        BeSortedSound.play(.ai)
        withAnimation(.smooth(duration: 0.36)) {
            celebrationTier = tier
        }
    }

    private func plansPanel(requestClose: @escaping () -> Void) -> some View {
        let store = SmartAssistantStore.shared

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Smart Assistant".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                Spacer()
                Button(action: requestClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .besortedGlass(appearance, interactive: true, in: .circle)
            }

            Text("Wybierz wersję dopasowaną do Twojego iPhone’a.".l10n)
                .font(.subheadline)
                .foregroundStyle(appearance.secondaryText)

            if let error = store.lastStoreError, !error.isEmpty {
                Text(error)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 0.92, green: 0.28, blue: 0.28))
                    .fixedSize(horizontal: false, vertical: true)
            }

ScrollView {
                    VStack(spacing: 12) {
                        featureTourTile

                        ForEach(SmartAssistantTier.storeOrder) { tier in
                            tierCard(tier, store: store, requestClose: requestClose)
                        }
                    }
                }
                .frame(maxHeight: BeSortedScreen.height * 0.58)

                restorePurchasesRow(store: store)
            }
            .padding(18)
        .frame(maxWidth: 420)
        .besortedSmartAssistantModalPanel(appearance)
        .padding(.horizontal, 20)
        .task {
            await store.loadStoreProducts()
        }
    }

    private var featureTourTile: some View {
        Button {
            BeSortedSound.play(.regular)
            withAnimation(.smooth(duration: 0.36)) {
                featureTourTier = tourTier
                showFeatureTour = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(appearance.iconPrimary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Zapoznaj się z Twoją wersją Smart Assistant".l10n)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    SmartAssistantBrandedTitle(
                        tier: tourTier,
                        baseColor: appearance.tertiaryText,
                        font: .caption.weight(.medium)
                    )
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(appearance.quaternaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(appearance.fieldFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(appearance.fieldStroke, lineWidth: 1)
            }
        }
        .buttonStyle(BeSortedPlainButtonStyle())
    }

    private func tierCard(
        _ tier: SmartAssistantTier,
        store: SmartAssistantStore,
        requestClose: @escaping () -> Void
    ) -> some View {
        let canBuy = SmartAssistantDevice.canPurchase(tier)
        let accountOK = SynclyCloudAccount.shared.canPurchaseSmartAssistant
        let owned = store.owns(tier)
        let isActive = store.activeTier == tier
        let credit = store.upgradeCredit(toward: tier)
        let payPrice = store.priceToPay(for: tier)
        let hasDiscount = !owned && credit > 0 && payPrice < tier.listPrice
        let isPurchasing = store.purchasingTierID == tier.rawValue
        let priceLabel = store.storeDisplayPrice(for: tier)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SmartAssistantBrandedTitle(
                    tier: tier,
                    baseColor: appearance.primaryText,
                    font: .headline.weight(.bold)
                )
                Spacer(minLength: 8)
                if !owned {
                    VStack(alignment: .trailing, spacing: 2) {
                        if hasDiscount {
                            Text(tier.priceLabel)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(appearance.quaternaryText)
                                .strikethrough()
                            Text(priceLabel)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(appearance.primaryText)
                        } else {
                            Text(priceLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appearance.secondaryText)
                        }
                    }
                }
            }

            SmartAssistantBrandedText(
                text: tier.shortSubtitle,
                baseColor: appearance.tertiaryText,
                font: .caption
            )

            if hasDiscount {
                Text(L10n.format("Zaliczenie poprzedniego planu: −%@", SmartAssistantTier.formatPLN(credit)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(appearance.secondaryText)
            }

            if tier == .plus || tier == .pro {
                SmartAssistantBrandedText(
                    text: includedModelsNote(for: tier),
                    baseColor: appearance.tertiaryText,
                    font: .caption2.weight(.medium)
                )
            }

            if !accountOK && !owned {
                Text(SynclyCloudAccount.shared.smartAssistantPurchaseBlockedMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.18))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if !accountOK && !owned {
                    Text("Wymagane konto Apple".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.quaternaryText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(appearance.tileTint.opacity(0.55))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    appearance.isFlatDesign ? .clear : appearance.primaryText.opacity(0.10),
                                    lineWidth: 1
                                )
                        }
                } else if !canBuy && !owned {
                    Text("Niedostępne do zakupu".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.quaternaryText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(appearance.tileTint.opacity(0.55))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    appearance.isFlatDesign ? .clear : appearance.primaryText.opacity(0.10),
                                    lineWidth: 1
                                )
                        }
                } else if owned {
                    Button {
                        store.activateOwned(tier)
                        refreshTick += 1
                        if store.activeTier == tier {
                            finishActivation(tier)
                        }
                    } label: {
                        Text(isActive ? "Aktywny".l10n : "Użyj".l10n)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(
                                isActive
                                    ? appearance.selectedTabForeground
                                    : appearance.primaryText
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .besortedAdaptiveProminentButton(
                        appearance,
                        tint: isActive ? appearance.selectedTabTint : appearance.tileTint
                    )
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                    .disabled(isActive || !canActivate(tier))
                } else if canBuy {
                    Button {
                        Task {
                            let ok = await store.purchase(tier)
                            refreshTick += 1
                            if ok, store.activeTier == tier {
                                finishActivation(tier)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(appearance.selectedTabForeground)
                            }
                            Text(hasDiscount
                                 ? L10n.format("Kup · %@", priceLabel)
                                 : "Kup".l10n)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(appearance.selectedTabForeground)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                    .disabled(isPurchasing || store.purchasingTierID != nil)
                } else {
                    Text("Niedostępne do zakupu".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.quaternaryText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(appearance.tileTint.opacity(0.55))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    appearance.isFlatDesign ? .clear : appearance.primaryText.opacity(0.10),
                                    lineWidth: 1
                                )
                        }
                }

                Button {
                    withAnimation(.smooth(duration: 0.28)) {
                        infoTier = tier
                    }
                } label: {
                    Text("Informacje".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .besortedAdaptiveGlassButton(appearance)
                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(appearance.fieldFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(appearance.fieldStroke, lineWidth: 1)
        }
    }

    private func restorePurchasesRow(store: SmartAssistantStore) -> some View {
        Button {
            Task {
                await store.restorePurchases()
                refreshTick += 1
            }
        } label: {
            HStack(spacing: 8) {
                if store.isRestoringPurchases {
                    ProgressView()
                        .controlSize(.small)
                        .tint(appearance.secondaryText)
                }
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                Text("Przywróć zakupy".l10n)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(appearance.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.85),
                in: .rect(cornerRadius: 16),
                role: .content
            )
        }
        .buttonStyle(BeSortedPlainButtonStyle())
        .disabled(store.isRestoringPurchases)
    }

    private func canActivate(_ tier: SmartAssistantTier) -> Bool {
        switch tier {
        case .pro: return SmartAssistantDevice.isProHardware
        case .plus: return SmartAssistantDevice.isPlusHardware
        case .standard: return true
        }
    }

    private func includedModelsNote(for tier: SmartAssistantTier) -> String {
        switch tier {
        case .pro:
            return "Odblokowuje też Smart Assistant + oraz Smart Assistant.".l10n
        case .plus:
            return "Odblokowuje też Smart Assistant.".l10n
        case .standard:
            return ""
        }
    }

    private func infoPanel(for tier: SmartAssistantTier, requestClose: @escaping () -> Void) -> some View {
        SmartAssistantInfoSkillsPanel(
            tier: tier,
            appearance: appearance,
            onBack: {
                withAnimation(.smooth(duration: 0.28)) {
                    infoTier = nil
                }
            },
            onClose: requestClose,
            onOpenFeatureTour: {
                BeSortedSound.play(.regular)
                withAnimation(.smooth(duration: 0.36)) {
                    featureTourTier = tier
                    showFeatureTour = true
                }
            }
        )
        .id(tier.id)
    }
}

/// Panel Informacje: najpierw kafelki od góry, potem ✓ / ✗ z dźwiękiem.
private struct SmartAssistantInfoSkillsPanel: View {
    let tier: SmartAssistantTier
    let appearance: AppAppearance
    var onBack: () -> Void
    var onClose: () -> Void
    var onOpenFeatureTour: () -> Void

    @State private var revealedCount = 0
    @State private var markedIndices: Set<Int> = []
    @State private var didStart = false
    @State private var revealTask: Task<Void, Never>?

    private var skills: [SmartAssistantSkill] { SmartAssistantSkill.allCases }

    private var skillYesColor: Color {
        // Jasne motywy → ciemniejsza zieleń; ciemne → jaśniejsza (obecna).
        if appearance.theme.usesLightContent {
            switch appearance.theme {
            case .white, .silver:
                return Color(red: 0.10, green: 0.48, blue: 0.26)
            case .lightBlue:
                return Color(red: 0.08, green: 0.42, blue: 0.30)
            default:
                return Color(red: 0.12, green: 0.52, blue: 0.28)
            }
        }
        return Color(red: 0.22, green: 0.78, blue: 0.40)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .besortedGlass(appearance, interactive: true, in: .circle)

                SmartAssistantBrandedTitle(
                    tier: tier,
                    baseColor: appearance.primaryText,
                    font: .title3.weight(.bold)
                )
                .lineLimit(2)
                .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .besortedGlass(appearance, interactive: true, in: .circle)
            }

            SmartAssistantBrandedText(
                text: tier.shortSubtitle,
                baseColor: appearance.secondaryText,
                font: .subheadline
            )

            Button(action: onOpenFeatureTour) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(appearance.iconPrimary)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zapoznaj się z funkcjami tego modelu".l10n)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(appearance.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        SmartAssistantBrandedTitle(
                            tier: tier,
                            baseColor: appearance.tertiaryText,
                            font: .caption.weight(.medium)
                        )
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(appearance.quaternaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(appearance.fieldFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(appearance.fieldStroke, lineWidth: 1)
                }
            }
            .buttonStyle(BeSortedPlainButtonStyle())

            Text("Umiejętności".l10n)
                .font(.headline.weight(.semibold))
                .foregroundStyle(appearance.secondaryText)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                        skillRow(
                            skill,
                            enabled: tier.supports(skill),
                            tileVisible: index < revealedCount,
                            markVisible: markedIndices.contains(index)
                        )
                    }
                }
            }
            .frame(maxHeight: BeSortedScreen.height * 0.42)
        }
        .padding(18)
        .frame(maxWidth: 420)
        .besortedSmartAssistantModalPanel(appearance)
        .padding(.horizontal, 20)
        .onAppear {
            startRevealSequence()
        }
        .onDisappear {
            cancelRevealSequence()
        }
    }

    private func skillRow(
        _ skill: SmartAssistantSkill,
        enabled: Bool,
        tileVisible: Bool,
        markVisible: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: skill.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(appearance.iconPrimary)
                .frame(width: 28)

            Text(skill.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(enabled ? skillYesColor : Color(red: 0.92, green: 0.28, blue: 0.28))
                    .opacity(markVisible ? 1 : 0)
                    .scaleEffect(markVisible ? 1 : 0.28)
                    .animation(
                        markVisible
                            ? .spring(response: 0.42, dampingFraction: 0.62)
                            : .linear(duration: 0),
                        value: markVisible
                    )
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(appearance.fieldFill)
        }
        .opacity(tileVisible ? 1 : 0)
        .offset(y: tileVisible ? 0 : -18)
        .scaleEffect(tileVisible ? 1 : 0.96, anchor: .top)
    }

    private func startRevealSequence() {
        guard !didStart else { return }
        didStart = true
        revealedCount = 0
        markedIndices = []

        let tileStep = 0.075
        let skillCount = skills.count
        let markStartGap = 0.38
        let markStep = 0.28
        let supported = skills.map { tier.supports($0) }

        revealTask?.cancel()
        revealTask = Task { @MainActor in
            for index in 0..<skillCount {
                let delay = index == 0 ? 0.05 : tileStep
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.34)) {
                    revealedCount = index + 1
                }
            }

            try? await Task.sleep(nanoseconds: UInt64(markStartGap * 1_000_000_000))
            guard !Task.isCancelled else { return }

            for index in 0..<skillCount {
                if index > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(markStep * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                }
                BeSortedSound.play(supported[index] ? .skillYes : .skillNo)
                markedIndices.insert(index)
            }
        }
    }

    private func cancelRevealSequence() {
        revealTask?.cancel()
        revealTask = nil
        BeSortedSound.stop(.skillYes, .skillNo)
    }
}
// MARK: - Activation intro (liquid glass pill)

/// Pastylka: bounce na środek → bouncy expand → tekst → poświata po literach → wylot w górę.
struct SmartAssistantActivationIntroView: View {
    let tier: SmartAssistantTier
    var onFinished: () -> Void

    @Environment(AppAppearance.self) private var appearance

    @State private var pillScale: CGFloat = 0.28
    @State private var pillOffsetY: CGFloat = 140
    @State private var pillOpacity: Double = 0
    @State private var expand: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.94
    @State private var glowIndex: Int = -1
    @State private var maxSweptIndex: Int = -1
    @State private var exitOffsetY: CGFloat = 0
    @State private var scrimOpacity: Double = 0
    @State private var chromeOpacity: Double = 1

    private var message: String {
        switch tier {
        case .pro:
            return "Smart Assistant Pro"
        case .plus:
            return "Smart Assistant +"
        case .standard:
            return "Smart Assistant"
        }
    }

    private var characters: [Character] { Array(message) }

    /// „Pro” = złoty, „+” = limonkowy — malowane falą sweepu (nie od razu).
    private var badgeHighlight: (kind: ActivationBadgeHighlight, range: Range<Int>)? {
        switch tier {
        case .pro:
            let start = max(0, message.count - 3)
            return (.pro, start..<message.count)
        case .plus:
            let start = max(0, message.count - 1)
            return (.plus, start..<message.count)
        case .standard:
            return nil
        }
    }

    private var pillWidth: CGFloat {
        let minW: CGFloat = 128
        let maxW = BeSortedScreen.width - 18
        return minW + (maxW - minW) * expand
    }

    private var pillHeight: CGFloat {
        let minH: CGFloat = 56
        let maxH = (BeSortedScreen.height - 52) * 0.38
        return minH + (maxH - minH) * expand
    }

    private var cornerRadius: CGFloat {
        let capsule = pillHeight / 2
        let panel: CGFloat = 36
        return capsule + (panel - capsule) * expand
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.44 * scrimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ZStack {
                ActivationLetterSweepText(
                    characters: characters,
                    sweepIndex: glowIndex,
                    maxSweptIndex: maxSweptIndex,
                    badgeHighlight: badgeHighlight,
                    baseColor: appearance.primaryText,
                    themeAccent: appearance.aiScanAccent,
                    themeTint: appearance.selectedTabTint
                )
                .opacity(textOpacity)
                .scaleEffect(textScale)
                .padding(.horizontal, 22)
            }
            .frame(width: pillWidth, height: pillHeight)
            .besortedGlass(
                appearance,
                interactive: false,
                tint: appearance.tileTint.opacity(0.92),
                in: .rect(cornerRadius: cornerRadius),
                minimumFrost: max(AppAppearance.panelGlassMinimumFrost, 0.62),
                role: .content
            )
            .opacity(pillOpacity * chromeOpacity)
            .scaleEffect(pillScale)
            .offset(y: pillOffsetY + exitOffsetY)
            .shadow(
                color: appearance.selectedTabTint.opacity(0.28 * Double(expand)),
                radius: 16 + 12 * expand,
                y: 6
            )
        }
        .allowsHitTesting(true)
        .onAppear {
            runIntro()
        }
    }

    private func runIntro() {
        pillScale = 0.28
        pillOffsetY = 140
        pillOpacity = 0
        expand = 0
        textOpacity = 0
        textScale = 0.94
        glowIndex = -1
        maxSweptIndex = -1
        exitOffsetY = 0
        scrimOpacity = 0
        chromeOpacity = 1

        let lightHaptic = UIImpactFeedbackGenerator(style: .light)
        let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
        lightHaptic.prepare()
        heavyHaptic.prepare()

        // 1) Pastylka bounce’uje na środek.
        withAnimation(.easeOut(duration: 0.28)) {
            scrimOpacity = 1
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.58, blendDuration: 0)) {
            pillScale = 1
            pillOffsetY = 0
            pillOpacity = 1
        }

        // 2) Lekko bouncy expand niemal na cały ekran.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            withAnimation(.spring(response: 0.68, dampingFraction: 0.74, blendDuration: 0)) {
                expand = 1
            }
        }

        // 3) Tekst.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.18) {
            withAnimation(.smooth(duration: 0.38)) {
                textOpacity = 1
                textScale = 1
            }
        }

        // 4) Gradient motywu + lekkie powiększenie literek po kolei.
        //    Pro / + malują się złotem / limonką dopiero gdy fala do nich dojdzie.
        let glowStart = 1.55
        let letterStep = 0.058
        let letterCount = characters.count
        let badge = badgeHighlight

        for index in 0..<letterCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + glowStart + Double(index) * letterStep) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.62, blendDuration: 0)) {
                    glowIndex = index
                    maxSweptIndex = max(maxSweptIndex, index)
                }
                if let badge, badge.range.contains(index) {
                    switch badge.kind {
                    case .plus:
                        lightHaptic.impactOccurred(intensity: 0.72)
                    case .pro:
                        heavyHaptic.impactOccurred(intensity: 1.0)
                    }
                }
            }
        }

        let glowDone = glowStart + Double(max(letterCount, 1)) * letterStep + 0.32
        DispatchQueue.main.asyncAfter(deadline: .now() + glowDone) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0)) {
                glowIndex = -1
            }
        }

        // 5) Okienko wylatuje w górę.
        DispatchQueue.main.asyncAfter(deadline: .now() + glowDone + 0.32) {
            withAnimation(.smooth(duration: 0.22)) {
                textOpacity = 0
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.88, blendDuration: 0)) {
                exitOffsetY = -BeSortedScreen.height * 0.92
                chromeOpacity = 0.55
            }
            withAnimation(.easeIn(duration: 0.36)) {
                scrimOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + glowDone + 0.95) {
            onFinished()
        }
    }
}

/// Pogrubiony napis: gradient motywu przechodzi po literach + lekki bounce skali.
/// „Pro” / „+” malują się złotem / limonką dopiero z falą (i zostają).
private enum ActivationBadgeHighlight {
    case pro
    case plus
}

private struct ActivationLetterSweepText: View {
    let characters: [Character]
    let sweepIndex: Int
    let maxSweptIndex: Int
    let badgeHighlight: (kind: ActivationBadgeHighlight, range: Range<Int>)?
    let baseColor: Color
    let themeAccent: Color
    let themeTint: Color

    private static let proGold: [Color] = SmartAssistantBrandGradients.proGold

    private static let plusLime: [Color] = SmartAssistantBrandGradients.plusLime

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                let intensity = sweepIntensity(for: index)
                let badge = badgeKind(for: index)
                let isPainted = badge != nil && index <= maxSweptIndex
                let scaleBoost: CGFloat = badge != nil ? 0.32 : 0.18
                Text(String(character))
                    .font(.title.weight(intensity > 0.15 || isPainted ? .black : .bold))
                    .foregroundStyle(letterStyle(intensity: intensity, badge: badge, isPainted: isPainted))
                    .scaleEffect(1 + scaleBoost * intensity)
            }
        }
        .minimumScaleFactor(0.55)
        .lineLimit(1)
        .multilineTextAlignment(.center)
        .animation(.spring(response: 0.30, dampingFraction: 0.62), value: sweepIndex)
        .animation(.easeOut(duration: 0.18), value: maxSweptIndex)
    }

    private func badgeKind(for index: Int) -> ActivationBadgeHighlight? {
        guard let badgeHighlight, badgeHighlight.range.contains(index) else { return nil }
        return badgeHighlight.kind
    }

    private func letterStyle(
        intensity: Double,
        badge: ActivationBadgeHighlight?,
        isPainted: Bool
    ) -> AnyShapeStyle {
        if let badge, isPainted {
            let colors: [Color]
            switch badge {
            case .pro: colors = Self.proGold
            case .plus: colors = Self.plusLime
            }
            let boosted = intensity > 0.04
                ? [colors[0], Color.white.opacity(0.92), colors[1], colors[2]]
                : colors
            return AnyShapeStyle(
                LinearGradient(
                    colors: boosted,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if intensity > 0.04 {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        themeAccent,
                        themeTint,
                        baseColor.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(baseColor)
    }

    private func sweepIntensity(for index: Int) -> Double {
        guard sweepIndex >= 0 else { return 0 }
        let distance = abs(index - sweepIndex)
        switch distance {
        case 0: return 1
        case 1: return 0.42
        default: return 0
        }
    }
}

// MARK: - Pro unlock reveal (settings)

extension View {
    /// Elementy ustawień wypływają od dołu z lekką poświatą po kupnie / aktywacji Pro.
    func smartAssistantProReveal(
        progress: CGFloat,
        glow: Double,
        index: Int,
        glowColor: Color
    ) -> some View {
        modifier(
            SmartAssistantProRevealModifier(
                progress: progress,
                glow: glow,
                index: index,
                glowColor: glowColor
            )
        )
    }
}

private struct SmartAssistantProRevealModifier: ViewModifier {
    var progress: CGFloat
    var glow: Double
    var index: Int
    var glowColor: Color

    func body(content: Content) -> some View {
        content
            .offset(y: (1 - progress) * (52 + CGFloat(index) * 20))
            .opacity(0.2 + 0.8 * Double(progress))
            .shadow(
                color: glowColor.opacity(0.58 * glow),
                radius: 12 + 14 * glow,
                y: -5 * glow
            )
            .shadow(
                color: glowColor.opacity(0.22 * glow),
                radius: 26 * glow,
                y: 0
            )
            .animation(.smooth(duration: 0.64).delay(Double(index) * 0.07), value: progress)
            .animation(.easeOut(duration: 1.25).delay(0.28 + Double(index) * 0.035), value: glow)
    }
}

/// Okienko po kliknięciu operacji AI niedostępnej w aktywnym modelu.
struct SmartAssistantUpgradeOverlay: View {
    let skill: SmartAssistantSkill
    var onClose: () -> Void
    var onOpenPlans: () -> Void

    @Environment(AppAppearance.self) private var appearance

    private var recommended: SmartAssistantTier { skill.cheapestSupportingTier }
    private var store: SmartAssistantStore { SmartAssistantStore.shared }
    private var ownsRecommended: Bool { store.owns(recommended) }
    private var deviceOK: Bool { SmartAssistantDevice.canPurchase(recommended) }

    var body: some View {
        DropInModalChrome(onClose: onClose) { requestClose in
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ulepsz Smart Assistant".l10n)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(appearance.primaryText)
                        Text(L10n.format("„%@” wymaga wyższego modelu.", skill.title))
                            .font(.subheadline)
                            .foregroundStyle(appearance.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button(action: requestClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .besortedGlass(appearance, interactive: true, in: .circle)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        SmartAssistantBrandedTitle(
                            tier: recommended,
                            baseColor: appearance.primaryText,
                            font: .headline.weight(.bold)
                        )
                        Spacer(minLength: 8)
                        if !ownsRecommended {
                            Text(store.storeDisplayPrice(for: recommended))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(appearance.secondaryText)
                        } else {
                            Text("Posiadasz".l10n)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(appearance.secondaryText)
                        }
                    }

                    Text(L10n.format("Najtańszy model z funkcją „%@”.", skill.title))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(appearance.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "iphone")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(appearance.iconPrimary)
                            .padding(.top, 1)
                        SmartAssistantBrandedText(
                            text: recommended.hardwareRequirement,
                            baseColor: appearance.primaryText,
                            font: .subheadline.weight(.medium)
                        )
                    }

                    if !deviceOK {
                        Text("Ten iPhone nie spełnia wymagań sprzętowych tego modelu.".l10n)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.92, green: 0.35, blue: 0.28))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(appearance.fieldFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(appearance.fieldStroke, lineWidth: 1)
                }

                HStack(spacing: 10) {
                    Button(action: requestClose) {
                        Text("Nie teraz".l10n)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .besortedAdaptiveGlassButton(appearance)

                    Button {
                        requestClose()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                            onOpenPlans()
                        }
                    } label: {
                        Text(primaryCTATitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(appearance.selectedTabForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
                }
            }
            .padding(20)
            .frame(maxWidth: 420)
            .besortedSmartAssistantModalPanel(appearance)
            .padding(.horizontal, 20)
        }
    }

    private var primaryCTATitle: String {
        if ownsRecommended {
            return "Przejdź do modeli".l10n
        }
        return L10n.format("Zobacz %@", recommended.title)
    }
}

// MARK: - Feature tour

/// Pełnoekranowy przewodnik po funkcjach aktywnej (lub najwyższej posiadanej) wersji.
struct SmartAssistantFeatureTourView: View {
    let tier: SmartAssistantTier
    var onClose: () -> Void

    @Environment(AppAppearance.self) private var appearance

    @State private var pageIndex = 0
    /// Kolejne warstwy miniatury zakładki (0 = pusto → pełny obrazek).
    @State private var buildStep = 0
    @State private var descriptionVisible = false
    @State private var animToken = UUID()

    private let maxBuildSteps = 4

    private var pages: [SmartAssistantSkill] {
        SmartAssistantSkill.allCases.filter { tier.supports($0) }
    }

    private var currentSkill: SmartAssistantSkill? {
        guard pages.indices.contains(pageIndex) else { return nil }
        return pages[pageIndex]
    }

    var body: some View {
        ZStack {
            appearance.opaqueModalFill
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 8)

                if let skill = currentSkill {
                    TourMiniTabFrame(appearance: appearance) {
                        TourMiniTabScreen(skill: skill, buildStep: buildStep, appearance: appearance)
                    }
                    .frame(maxWidth: 420)
                    .frame(height: min(BeSortedScreen.height * 0.46, 360))
                    .padding(.horizontal, 24)
                    .id(skill.id)

                    descriptionBlock(for: skill)
                        .padding(.horizontal, 28)
                        .padding(.top, 22)
                }

                Spacer(minLength: 8)

                pageDots
                    .padding(.bottom, 14)

                navigationBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            runIntroAnimation()
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -50 {
                        goNext()
                    } else if value.translation.width > 50 {
                        goPrevious()
                    }
                }
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Zapoznaj się".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                SmartAssistantBrandedTitle(
                    tier: tier,
                    baseColor: appearance.tertiaryText,
                    font: .caption.weight(.semibold)
                )
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
            .besortedGlass(appearance, interactive: true, in: .circle)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func descriptionBlock(for skill: SmartAssistantSkill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(skill.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(appearance.primaryText)
            Text(skill.tourDescription)
                .font(.body)
                .foregroundStyle(appearance.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 420, alignment: .leading)
        .opacity(descriptionVisible ? 1 : 0)
        .offset(y: descriptionVisible ? 0 : 14)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == pageIndex
                            ? appearance.primaryText
                            : appearance.quaternaryText.opacity(0.55)
                    )
                    .frame(width: index == pageIndex ? 18 : 7, height: 7)
                    .animation(.smooth(duration: 0.25), value: pageIndex)
            }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button {
                goPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
            .besortedGlass(appearance, interactive: true, in: .circle)
            .opacity(pageIndex > 0 ? 1 : 0.35)
            .disabled(pageIndex <= 0)

            Spacer()

            Text("\(pageIndex + 1)/\(max(pages.count, 1))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.tertiaryText)

            Spacer()

            Button {
                if pageIndex >= pages.count - 1 {
                    onClose()
                } else {
                    goNext()
                }
            } label: {
                Image(systemName: pageIndex >= pages.count - 1 ? "checkmark" : "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        pageIndex >= pages.count - 1
                            ? appearance.selectedTabForeground
                            : appearance.primaryText
                    )
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
            .background {
                if pageIndex >= pages.count - 1 {
                    Circle().fill(appearance.selectedTabTint)
                }
            }
            .besortedGlass(appearance, interactive: true, in: .circle)
        }
    }

    private func goNext() {
        guard pageIndex < pages.count - 1 else { return }
        BeSortedSound.play(.regular)
        withAnimation(.smooth(duration: 0.28)) {
            pageIndex += 1
        }
        runIntroAnimation()
    }

    private func goPrevious() {
        guard pageIndex > 0 else { return }
        BeSortedSound.play(.regular)
        withAnimation(.smooth(duration: 0.28)) {
            pageIndex -= 1
        }
        runIntroAnimation()
    }

    /// Intro = kolejne warstwy miniatury zakładki „dokładają się” do pełnego obrazka.
    private func runIntroAnimation() {
        let token = UUID()
        animToken = token
        buildStep = 0
        descriptionVisible = false

        for step in 1...maxBuildSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 + Double(step - 1) * 0.16) {
                guard animToken == token else { return }
                withAnimation(.smooth(duration: 0.32)) {
                    buildStep = step
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 + Double(maxBuildSteps) * 0.16 + 0.22) {
            guard animToken == token else { return }
            withAnimation(.smooth(duration: 0.40)) {
                descriptionVisible = true
            }
        }
    }
}

