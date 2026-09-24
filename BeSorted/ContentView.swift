//
//  ContentView.swift
//  BeSorted
//
//  Created by Michał Wołtosz on 11/09/2026.
//

import SwiftUI
import SwiftData
import UIKit

@MainActor
enum BeSortedScreen {
    static var bounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return active.screen.bounds
        }
        return scenes.first?.screen.bounds ?? CGRect(x: 0, y: 0, width: 390, height: 844)
    }

    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }
}

enum AppTab: String, CaseIterable, Identifiable {
    case projects
    case plan
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: "Moje projekty".l10n
        case .plan: "Aktualny Plan".l10n
        case .settings: "Ustawienia".l10n
        }
    }

    var systemImage: String {
        switch self {
        case .projects: "folder.fill"
        case .plan: "calendar"
        case .settings: "gearshape.fill"
        }
    }

    /// Zakładki główne używają SF Symboli (2D); assety zostawione pod Smart Mode / inne miejsca.
    var assetImageName: String? { nil }
}

enum ProjectDetailTab: String, CaseIterable, Identifiable {
    case tasks
    case bugs
    case futureNote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: "Zadania".l10n
        case .bugs: "Aktualne błędy".l10n
        case .futureNote: "Notatka przyszłości".l10n
        }
    }

    var systemImage: String {
        switch self {
        case .tasks: "checklist"
        case .bugs: "exclamationmark.triangle.fill"
        case .futureNote: "lightbulb.fill"
        }
    }
}

/// Kolaps pastylki w osobnym widoku — odczyt `menuPillCollapseProgress` nie przebudowuje list kafelków.
private struct CollapsingPillChrome<Pill: View, Search: View>: View {
    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var smartChrome

    var showsProjectsSearch: Bool
    var itemSpacing: CGFloat = 14
    var searchButtonSize: CGFloat = 70
    @ViewBuilder var pill: (_ collapse: CGFloat) -> Pill
    @ViewBuilder var searchButton: () -> Search

    private var collapse: CGFloat {
        appearance.collapsingMenuPill ? smartChrome.menuPillCollapseProgress : 0
    }

    var body: some View {
        // Pastylka: lekko spłaszczony scale (jak dotychczas).
        let pillScaleX = 1 - 0.38 * collapse
        let pillScaleY = 1 - 0.28 * collapse
        // Lupa = wysokość pastylki; dopina się do zera przed pełnym kolapsem (bez mikro-kropki).
        let endKill: CGFloat = collapse < 0.72
            ? 1
            : max(0, 1 - (collapse - 0.72) / 0.22)
        let lupaScale = showsProjectsSearch ? max(0, pillScaleY * endKill) : 0
        let showLupa = showsProjectsSearch && lupaScale > 0.06
        let pairSpacing = itemSpacing * (showLupa ? 1 : (showsProjectsSearch ? 0 : 1))

        HStack(alignment: .center, spacing: pairSpacing) {
            pill(collapse)
                .scaleEffect(x: pillScaleX, y: pillScaleY, anchor: .center)

            if showLupa {
                Color.clear
                    .frame(
                        width: searchButtonSize * lupaScale,
                        height: searchButtonSize * lupaScale
                    )
                    .overlay {
                        searchButton()
                            .frame(width: searchButtonSize, height: searchButtonSize)
                            .scaleEffect(lupaScale, anchor: .center)
                    }
                    .allowsHitTesting(lupaScale > 0.35)
                    .transition(.identity)
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.58), value: collapse)
    }
}

struct ContentView: View {
    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var smartChrome
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Tryb poziomy (telefon obrócony) — na prawą krawędź wjeżdża pionowy dock zakładek.
    private var isLandscape: Bool { verticalSizeClass == .compact }

    @State private var selectedTab: AppTab = .projects
    @State private var selectedProject: Project?
    @State private var selectedPlanTask: ProjectTask?
    @State private var projectDetailTab: ProjectDetailTab = .tasks
    @State private var isEditingProjectDetails = false
    @State private var isPlanTaskAIAssistPresented = false
    /// `true` = przejście w prawo (nowa z prawej, stara w lewo).
    @State private var mainTabSlideForward = true

    @State private var showAIAssistant = false
    @State private var isAIDragActive = false
    @State private var aiDragTranslation: CGSize = .zero
    /// 0 = schowany za „Aktualny Plan”, 1 = osobna kuleczka.
    @State private var aiDetachProgress: CGFloat = 0
    @State private var suppressPlanTap = false
    @State private var planTabFrame: CGRect = .zero
    @State private var isMainTabScrubbing = false
    @State private var mainTabScrubProgress: CGFloat = 0
    /// -1…1 — rozciąganie / gibanie suwaka przy szybkim ruchu w bok.
    @State private var mainTabSliderStretch: CGFloat = 0
    @State private var mainTabLastDragX: CGFloat?
    @State private var mainTabLastDragTime: Date?
    /// Przeciągnięcie lupy w stronę pastylki (0 = osobno, >0 = zbliżenie).
    @State private var lupaPullTowardPill: CGFloat = 0

    private let mainTabSlotWidth: CGFloat = 96
    private let mainTabPillHeight: CGFloat = 70
    private let mainTabPillPadding: CGFloat = 4
    /// Lupa = ta sama wysokość co pastylka zakładek (okrągła capsule).
    private var mainTabSearchButtonSize: CGFloat { mainTabPillHeight }
    /// Domyślny odstęp pastylka↔lupa.
    private let mainTabBarItemSpacing: CGFloat = 14
    private let lupaPullMax: CGFloat = 12
    /// Lekkie powiększenie pastylki tylko podczas trzymania suwaka.
    private let mainTabScrubPillScale: CGFloat = 1.01
    /// Jak Fitness: suwak wyraźnie wystaje ponad / poniżej pastylki.
    private let mainTabScrubSliderScale: CGFloat = 1.14
    private let mainTabScrubSliderOutset: CGFloat = 9
    /// Suwak 2D trochę szerszy niż sam slot ikony.
    private let mainTabRestingThumbExtraWidth: CGFloat = 8
    private let mainTabThumbMorphAnimation: Animation = .spring(response: 0.40, dampingFraction: 0.84)
    /// Płynny ślizg suwaka po zwykłym kliknięciu w zakładkę (bez trzymania).
    private let mainTabTapSlideAnimation: Animation = .spring(response: 0.46, dampingFraction: 0.72)
    /// Minimalny ruch palca, po którym dotyk uznajemy za trzymanie suwaka —
    /// samo kliknięcie nie przestawia suwaka, tylko animuje ślizg w onEnded.
    private let mainTabTapThreshold: CGFloat = 8
    private static let mainTabSlideAnimation = Animation.smooth(duration: 0.34)
    /// Subtelny dystans przesunięcia treści zakładek (pt).
    private static let mainTabSlideDistance: CGFloat = 32

    /// Keep-alive komórek głównych — wszystkie zakładki pozostają w drzewie,
    /// slajd realizowany jaw-ie przez offset/opacity (1:1 z wcześniejszym przejściem).
    @ViewBuilder
    private func mainTabView(for tab: AppTab) -> some View {
        switch tab {
        case .projects:
            ProjectsTabView(selectedProject: $selectedProject)
        case .plan:
            CurrentPlanTabView(
                selectedPlanTask: $selectedPlanTask,
                isAIAssistPresented: $isPlanTaskAIAssistPresented
            )
        case .settings:
            SettingsTabView()
        }
    }

    /// Faza slajdu każdej zakładki przy `selectedTab`: aktywna (0,1);
    /// opuszczana jedzie w przeciwnym kierunku; pozostałe stoją na pozycji startu nowej.
    private func mainTabPose(for tab: AppTab) -> (offset: CGFloat, opacity: Double) {
        guard tab != selectedTab else { return (0, 1) }
        let selectedIndex = AppTab.allCases.firstIndex(of: selectedTab) ?? 0
        let tabIndex = AppTab.allCases.firstIndex(of: tab) ?? 0
        let dir: CGFloat = mainTabSlideForward ? 1 : -1
        if tabIndex == selectedIndex + (mainTabSlideForward ? 1 : -1) {
            return (-Self.mainTabSlideDistance * dir, 0)
        }
        return (Self.mainTabSlideDistance * dir, 0)
    }

    /// Binding, który ustawia kierunek slajdu zanim zmieni zakładkę (animacja we właściwą stronę).
    private var selectedTabSlideBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                let oldIndex = AppTab.allCases.firstIndex(of: selectedTab) ?? 0
                let newIndex = AppTab.allCases.firstIndex(of: newValue) ?? 0
                if oldIndex != newIndex {
                    mainTabSlideForward = newIndex > oldIndex
                }
                selectedTab = newValue
            }
        )
    }

    /// Jak mocno w górę trzeba przeciągnąć, zanim AI zacznie się odrywać.
    private let aiStrongPullDistance: CGFloat = 64

    private var showsSmartPill: Bool {
        appearance.smartMode
            && !showAIAssistant
            && !isPlanTaskAIAssistPresented
            && !isEditingProjectDetails
            && !smartChrome.blocksSmartPill
            && !smartChrome.blocksBottomChrome
    }

    var body: some View {
        ZStack {
            appearance.screenBackgroundGradient
                .ignoresSafeArea()

            Group {
                if let selectedPlanTask {
                    PlanTaskDetailView(
                        task: selectedPlanTask,
                        onBack: {
                            withAnimation(.smooth(duration: 0.25)) {
                                self.selectedPlanTask = nil
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if let selectedProject {
                    ProjectDetailView(
                        project: selectedProject,
                        selectedTab: $projectDetailTab,
                        isEditingDetails: $isEditingProjectDetails,
                        onBack: {
                            withAnimation(.smooth(duration: 0.25)) {
                                self.selectedProject = nil
                                projectDetailTab = .tasks
                                isEditingProjectDetails = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    // Zakładki „keep-alive": wszystkie 3 w drzewie, ukryte przez offset/opacity —
                    // powrót do Zakładki (np. duży Aktualny Plan) nie przebudowuje kafelków.
                    ZStack {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            mainTabView(for: tab)
                                .offset(x: mainTabPose(for: tab).offset)
                                .opacity(mainTabPose(for: tab).opacity)
                                .allowsHitTesting(tab == selectedTab)
                                .accessibilityHidden(tab != selectedTab)
                        }
                    }
                    // Płynne przejście pion ↔ poziom: szerokości kafelków/treści animują się
                    // razem z obrotem zamiast skakać na statycznych wymiarach.
                    .animation(.smooth(duration: 0.30), value: verticalSizeClass)
                    // Bez .clipped() — ucinało tło headera w status barze (musi sięgać do góry ekranu).
                    .animation(Self.mainTabSlideAnimation, value: selectedTab)
                }
            }
            .animation(.smooth(duration: 0.28), value: selectedProject?.persistentModelID)
            .animation(.smooth(duration: 0.28), value: selectedPlanTask?.persistentModelID)

            // Header tabs: regular liquid glass (rozciąga się w safe area).
            // TopSafeArea osobno niepotrzebne — dublowałoby frosty i wyglądało jak 2D.
            Group {
                if isLandscape {
                    // Tryb poziomy: pionowy dock po prawej (z dala od Dynamic Island).
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        if selectedPlanTask != nil || showAIAssistant || isPlanTaskAIAssistPresented {
                            EmptyView()
                        } else if appearance.smartMode {
                            EmptyView()
                        } else if selectedProject != nil {
                            if !isEditingProjectDetails && !smartChrome.blocksBottomChrome {
                                projectDetailVerticalDock
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        } else if !smartChrome.blocksBottomChrome {
                            appVerticalDock
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .padding(.trailing, BeSortedContentInsets.landscapeDockTrailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Spacer()
                        if selectedPlanTask != nil || showAIAssistant || isPlanTaskAIAssistPresented {
                            EmptyView()
                        } else if appearance.smartMode {
                            EmptyView()
                        } else if selectedProject != nil {
                            if !isEditingProjectDetails && !smartChrome.blocksBottomChrome {
                                projectDetailTabBar
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        } else if !smartChrome.blocksBottomChrome {
                            appTabBar
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
            }
            .zIndex(40)
            .animation(.smooth(duration: 0.32), value: isEditingProjectDetails)
            .animation(.smooth(duration: 0.28), value: isPlanTaskAIAssistPresented)
            .animation(.smooth(duration: 0.28), value: appearance.smartMode)
            .animation(.smooth(duration: 0.28), value: smartChrome.blocksBottomChrome)
            .animation(.smooth(duration: 0.28), value: isLandscape)
            .onAppear {
                bindMenuPillCollapseObserver()
            }

            if showsSmartPill {
                SmartModePillBar(
                    selectedTab: selectedTabSlideBinding,
                    projectDetailTab: $projectDetailTab,
                    isInProjectDetail: selectedProject != nil && selectedPlanTask == nil,
                    canGoBack: selectedProject != nil || selectedPlanTask != nil,
                    onGoBack: {
                        BeSortedSound.play(.tab)
                        withAnimation(.smooth(duration: 0.28)) {
                            if selectedPlanTask != nil {
                                selectedPlanTask = nil
                            } else if selectedProject != nil {
                                selectedProject = nil
                                projectDetailTab = .tasks
                                isEditingProjectDetails = false
                            }
                        }
                    }
                )
                .zIndex(45)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // AI nad/pod paskiem — osobna warstwa, żeby nie sklejać zakładek.
            if isAIDragActive {
                aiMorphBubble
                    .animation(
                        .interactiveSpring(response: 0.32, dampingFraction: 0.88),
                        value: aiDetachProgress
                    )
                    .zIndex(aiDetachProgress < 0.38 ? 30 : 55)
                    .allowsHitTesting(false)
            }

            if showAIAssistant {
                AIAssistantView(isPresented: $showAIAssistant)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                    .zIndex(100)
            }

            if smartChrome.showSmartAssistantActivate {
                let presentID = smartChrome.smartAssistantActivatePresentID
                SmartAssistantActivateOverlay(
                    isPresented: Binding(
                        get: { smartChrome.showSmartAssistantActivate },
                        set: { newValue in
                            if newValue {
                                smartChrome.presentSmartAssistantActivate()
                            } else {
                                smartChrome.dismissSmartAssistantActivate(onlyIfPresentID: presentID)
                            }
                        }
                    ),
                    onProUnlocked: {
                        smartChrome.smartAssistantProUnlockToken += 1
                    }
                )
                .id(smartChrome.smartAssistantActivateEpoch)
                .environment(appearance)
                .transition(.opacity)
                .zIndex(110)
            }

            if let upgradeSkill = smartChrome.smartAssistantUpgradeSkill {
                SmartAssistantUpgradeOverlay(
                    skill: upgradeSkill,
                    onClose: {
                        smartChrome.dismissSmartAssistantUpgrade()
                    },
                    onOpenPlans: {
                        smartChrome.dismissSmartAssistantUpgrade()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                            smartChrome.presentSmartAssistantActivate()
                        }
                    }
                )
                .environment(appearance)
                .transition(.opacity)
                .zIndex(112)
            }
        }
        .coordinateSpace(name: "rootAI")
        .id(appearance.language)
        .preferredColorScheme(appearance.preferredScheme)
        // Animacje tylko na nakładkach — nie na całym drzewie zakładek (scroll/glass).
        .animation(.smooth(duration: 0.30), value: showAIAssistant)
        .animation(.smooth(duration: 0.30), value: smartChrome.showSmartAssistantActivate)
        .animation(.smooth(duration: 0.30), value: smartChrome.smartAssistantUpgradeSkill)
        .animation(.smooth(duration: 0.30), value: appearance.smartMode)
        .onChange(of: selectedTab) { oldTab, newTab in
            let oldIndex = AppTab.allCases.firstIndex(of: oldTab) ?? 0
            let newIndex = AppTab.allCases.firstIndex(of: newTab) ?? 0
            if oldIndex != newIndex {
                mainTabSlideForward = newIndex > oldIndex
            }
            guard appearance.collapsingMenuPill else { return }
            MenuPillCollapseBridge.expandSmoothly()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                syncMenuPillCollapseToActiveScroll(allowCollapse: false)
            }
        }
        .onChange(of: selectedProject) { _, _ in
            guard appearance.collapsingMenuPill else { return }
            MenuPillCollapseBridge.expandSmoothly()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                syncMenuPillCollapseToActiveScroll(allowCollapse: false)
            }
        }
        .onChange(of: selectedPlanTask) { _, _ in
            guard appearance.collapsingMenuPill else { return }
            MenuPillCollapseBridge.expandSmoothly()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                syncMenuPillCollapseToActiveScroll(allowCollapse: false)
            }
        }
    }

    private var aiDetachEase: CGFloat {
        let t = min(max(aiDetachProgress, 0), 1)
        return 1 - pow(1 - t, 2.4)
    }

    private var aiMorphSize: CGSize {
        // Start: prawie dokładnie kafelek planu (lekko mniejszy = nie wystaje).
        let attached = CGSize(
            width: max(planTabFrame.width * 0.92, 40),
            height: max(planTabFrame.height * 0.88, 32)
        )
        let free = CGSize(width: 56, height: 56)
        let t = aiDetachEase
        return CGSize(
            width: attached.width + (free.width - attached.width) * t,
            height: attached.height + (free.height - attached.height) * t
        )
    }

    private var aiMorphCornerRadius: CGFloat {
        let attached = aiMorphSize.height / 2
        let free: CGFloat = 28
        return attached + (free - attached) * aiDetachEase
    }

    private var aiBubblePosition: CGPoint {
        let screenHeight = BeSortedScreen.height
        let maxLift = screenHeight * 0.30
        let attached = CGPoint(x: planTabFrame.midX, y: planTabFrame.midY)
        let lift = max(min(aiDragTranslation.height, 0), -maxLift)
        let free = CGPoint(
            x: planTabFrame.midX + aiDragTranslation.width * aiDetachEase,
            y: planTabFrame.midY + lift
        )
        let t = aiDetachEase
        return CGPoint(
            x: attached.x + (free.x - attached.x) * t,
            y: attached.y + (free.y - attached.y) * t
        )
    }

    private var aiMorphBubble: some View {
        let size = aiMorphSize
        let iconOpacity = max(0, Double((aiDetachProgress - 0.22) / 0.4))

        return Image("SmartAiIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 14 + 12 * aiDetachEase, height: 14 + 12 * aiDetachEase)
            .opacity(iconOpacity)
            .frame(width: size.width, height: size.height)
            .background {
                RoundedRectangle(cornerRadius: aiMorphCornerRadius, style: .continuous)
                    .fill(appearance.selectedTabTint.opacity(0.25 + 0.7 * Double(aiDetachEase)))
            }
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.selectedTabTint,
                in: .rect(cornerRadius: aiMorphCornerRadius)
            )
            .shadow(
                color: appearance.selectedTabTint.opacity(0.4 * Double(aiDetachEase)),
                radius: 12 * aiDetachEase
            )
            .position(aiBubblePosition)
    }

    private var mainTabPillContentWidth: CGFloat {
        mainTabSlotWidth * CGFloat(AppTab.allCases.count) + mainTabPillPadding * 2
    }

    private var mainTabInactiveForeground: Color {
        // Neumorfizm: czarny tekst na kafelek czarny (surface = 0.10,0.11,0.12).
        if appearance.isNeomorphic {
            return Color(red: 0.10, green: 0.11, blue: 0.12)
        }
        // Jak w Fitness: nieaktywne = biel / czerń wg motywu; kolor motywu dopiero pod suwakiem.
        return appearance.theme.usesLightContent
            ? Color.black.opacity(0.88)
            : Color.white.opacity(0.92)
    }

    /// Aktywna zakładka w Neumorfizmie: dla czarnego motywu tekst czarny na kafelku,
    /// dla pozostałych motywów wzorzec referencyjny (biały/srebrny → primaryText, reszta → subtelny blask).
    private var mainTabActiveForeground: Color {
        if appearance.isNeomorphic {
            switch appearance.theme {
            case .black:
                return Color(red: 0.10, green: 0.11, blue: 0.12) // czarny tekst na czarnym kafełku
            case .white, .silver:
                return appearance.primaryText
            default:
                return Color.white.opacity(0.95) // subtelny blask / wyróżnienie
            }
        }
        // fallback
        return .white
    }

    /// Wypełnienie suwaka 2D (spoczynek) — jak Fitness: ciemniejsza „soczewka”, nie kolor motywu.
    private var mainTabThumbRestFill: Color {
        appearance.theme.usesLightContent
            ? Color.black.opacity(0.14)
            : Color.black.opacity(0.50)
    }

    private var appTabBar: some View {
        // Kolaps pastylki czytany TYLKO w CollapsingPillChrome — nie invaliduje listy kafelków.
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            CollapsingPillChrome(showsProjectsSearch: selectedTab == .projects) { collapse in
                mainTabOptionsPill(collapseProgress: collapse)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)),
                            removal: .opacity.combined(with: .scale(scale: 0.92))
                        )
                    )
            } searchButton: {
                projectsSearchToggleButton
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.34), value: selectedTab)
        .animation(.smooth(duration: 0.34), value: smartChrome.isProjectsSearchExpanded)
        .animation(.smooth(duration: 0.36), value: appearance.glassStyle)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: lupaPullTowardPill)
        .onChange(of: selectedTab) { _, tab in
            let index = CGFloat(AppTab.allCases.firstIndex(of: tab) ?? 0)
            if !isMainTabScrubbing, abs(mainTabScrubProgress - index) > 0.02 {
                withAnimation(.smooth(duration: 0.38)) {
                    mainTabScrubProgress = index
                }
            }
            if appearance.collapsingMenuPill {
                MenuPillCollapseBridge.expandSmoothly()
            }
            if tab != .projects {
                collapseProjectsSearch(animated: true, clearQuery: true)
                withAnimation(.smooth(duration: 0.28)) {
                    lupaPullTowardPill = 0
                }
            }
            if tab != .plan {
                withAnimation(.smooth(duration: 0.2)) {
                    resetAIPull()
                }
            }
        }
        .onChange(of: appearance.smartMode) { _, enabled in
            if enabled {
                collapseProjectsSearch(animated: false, clearQuery: true)
            }
        }
        .onChange(of: appearance.collapsingMenuPill) { _, enabled in
            if !enabled {
                smartChrome.menuPillCollapseProgress = 0
            }
        }
        .onAppear {
            mainTabScrubProgress = CGFloat(AppTab.allCases.firstIndex(of: selectedTab) ?? 0)
            bindMenuPillCollapseObserver()
        }
    }

    private func bindMenuPillCollapseObserver() {
        MenuPillCollapseBridge.bind(chrome: smartChrome, appearance: appearance)
        // Kolaps pastylki idzie wyłącznie z `trackTabHeaderSolidProgress` (bez podwójnego KVO).
        SmartScrollRegistry.shared.onContentOffsetYChange = nil
    }

    /// Po zmianie kontekstu: jeśli lista jest na górze / nie da się scrollować → pełna pastylka.
    /// `allowCollapse: false` — nie przywracaj skurczenia ze starego offsetu tuż po zmianie zakładki.
    private func syncMenuPillCollapseToActiveScroll(allowCollapse: Bool = true) {
        guard appearance.collapsingMenuPill else { return }
        let registry = SmartScrollRegistry.shared
        if !registry.activeScrollCanScroll() {
            MenuPillCollapseBridge.expandSmoothly()
            return
        }
        let y = max(0, registry.currentContentOffsetY() ?? 0)
        if !allowCollapse, y > 8 {
            // Nowa zakładka jeszcze nie zgłosiła swojego offsetu / wisi stary scroll — zostań rozwinięty.
            MenuPillCollapseBridge.expandSmoothly()
            return
        }
        MenuPillCollapseBridge.update(offsetY: y)
    }

    /// Jedna pastylka jak Fitness: tor bez zniekształcania ikon; tylko trzymany suwak je zniekształca.
    private func mainTabOptionsPill(collapseProgress collapse: CGFloat) -> some View {
        let tabs = AppTab.allCases
        let slotCount = CGFloat(tabs.count)

        return GeometryReader { geo in
            let innerWidth = max(geo.size.width - mainTabPillPadding * 2, 1)
            let slotWidth = innerWidth / max(slotCount, 1)
            let sliderHeight = max(geo.size.height - mainTabPillPadding * 2, 1)
            let progress = min(max(mainTabScrubProgress, 0), max(slotCount - 1, 0))
            let stretch = mainTabSliderStretch
            let stretchScaleX = 1 + abs(stretch) * 0.22
            let stretchScaleY = 1 - abs(stretch) * 0.1
            let glassLift: CGFloat = isMainTabScrubbing ? 1 : 0
            let restingThumbWidth = min(
                slotWidth + mainTabRestingThumbExtraWidth,
                innerWidth
            )
            let holdOutset = mainTabScrubSliderOutset * glassLift
            let thumbWidth = restingThumbWidth + 8 * glassLift
            let thumbHeight = sliderHeight + holdOutset
            let thumbY = mainTabPillPadding - holdOutset / 2
            let thumbLead = stretch * min(slotWidth * 0.10, 8)
            let restingThumbX = mainTabPillPadding
                + progress * slotWidth
                - (restingThumbWidth - slotWidth) / 2
            let thumbNudge = 1.5 * glassLift
            let thumbOffsetX = restingThumbX - thumbNudge + thumbLead - (3 * glassLift)
            let glassScale = 1 + (mainTabScrubSliderScale - 1) * glassLift
            let rootFrame = geo.frame(in: .named("rootAI"))
            let planSlotIndex = CGFloat(AppTab.allCases.firstIndex(of: .plan) ?? 1)
            let accentMaskX =
                progress * slotWidth
                - (restingThumbWidth - slotWidth) / 2
                - thumbNudge
                - (3 * glassLift)
                + thumbLead

            // Glass pastylki = osobny widok tylko z tłem; ikony i suwak są siblingami NAD nim.
            ZStack(alignment: .topLeading) {
                Color.clear
                    .background {
                        pillChromeBackground
                    }

                mainTabRestingThumb(width: restingThumbWidth, height: sliderHeight)
                    .offset(x: restingThumbX + thumbLead * (1 - glassLift), y: mainTabPillPadding)
                    .opacity(1 - glassLift)
                    .animation(mainTabThumbMorphAnimation, value: isMainTabScrubbing)
                    .allowsHitTesting(false)

                if isMainTabScrubbing {
                    mainTabHeldGlassThumb(width: thumbWidth, height: thumbHeight)
                        .scaleEffect(x: glassScale * stretchScaleX, y: glassScale * stretchScaleY)
                        .offset(x: thumbOffsetX, y: thumbY)
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.92))
                                    .animation(mainTabThumbMorphAnimation),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.96))
                                    .animation(mainTabThumbMorphAnimation)
                            )
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                ZStack {
                    mainTabLabelsRow(
                        tabs: tabs,
                        slotWidth: slotWidth,
                        height: sliderHeight,
                        style: .inactive,
                        scrubProgress: progress,
                        collapse: collapse
                    )
                    mainTabLabelsRow(
                        tabs: tabs,
                        slotWidth: slotWidth,
                        height: sliderHeight,
                        style: .accent,
                        scrubProgress: progress,
                        collapse: collapse
                    )
                    .mask(alignment: .leading) {
                        Capsule(style: .continuous)
                            .frame(width: thumbWidth, height: sliderHeight)
                            .scaleEffect(x: stretchScaleX, y: 1, anchor: .center)
                            .offset(x: accentMaskX)
                    }
                }
                .padding(.horizontal, mainTabPillPadding)
                .padding(.vertical, mainTabPillPadding)
                .allowsHitTesting(false)
                .animation(
                    isMainTabScrubbing ? nil : mainTabThumbMorphAnimation,
                    value: mainTabScrubProgress
                )
            }
            .animation(mainTabThumbMorphAnimation, value: isMainTabScrubbing)
            .contentShape(Capsule())
            .highPriorityGesture(mainTabScrubGesture(slotWidth: slotWidth, slotCount: tabs.count))
            .simultaneousGesture(planAIPullGesture)
            .preference(
                key: PlanTabFrameKey.self,
                value: CGRect(
                    x: rootFrame.minX + mainTabPillPadding + planSlotIndex * slotWidth,
                    y: rootFrame.minY + mainTabPillPadding,
                    width: slotWidth,
                    height: sliderHeight
                )
            )
            .onPreferenceChange(PlanTabFrameKey.self) { newFrame in
                guard !isMainTabScrubbing else { return }
                if abs(newFrame.midX - planTabFrame.midX) > 0.5
                    || abs(newFrame.midY - planTabFrame.midY) > 0.5
                    || abs(newFrame.width - planTabFrame.width) > 0.5 {
                    planTabFrame = newFrame
                }
            }
        }
        .frame(width: mainTabPillContentWidth, height: mainTabPillHeight)
        .padding(.vertical, mainTabScrubSliderOutset)
        .scaleEffect(isMainTabScrubbing ? mainTabScrubPillScale : 1.0)
        .shadow(
            color: appearance.isNeomorphic
                ? .black.opacity(appearance.theme.usesLightContent ? 0.16 : 0.30)
                : (appearance.isFlatDesign ? .clear : .black.opacity(isMainTabScrubbing ? 0.14 : 0.10)),
            radius: appearance.isNeomorphic ? 10 : (appearance.isFlatDesign ? 0 : (isMainTabScrubbing ? 11 : 8)),
            y: appearance.isNeomorphic ? 1 : (appearance.isFlatDesign ? 0 : (isMainTabScrubbing ? 2 : 2))
        )
        .animation(mainTabThumbMorphAnimation, value: isMainTabScrubbing)
        .accessibilityElement(children: .contain)
    }

    private func mainTabRestingThumb(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)

        return Group {
            if appearance.isNeomorphic {
                // Suwak referencyjny: wklęsły chip + para embossingu (światło / cień).
                shape
                    .fill(appearance.neoChip)
                    .shadow(color: appearance.neoHighlight.opacity(0.40), radius: 6, x: -2, y: -2)
                    .shadow(color: appearance.neoShadow.opacity(0.50), radius: 6, x: 2, y: 2)
                    .frame(width: width, height: height)
            } else if appearance.isFlatDesign {
                // Flat design: płaski suwak bez ramek i cieni.
                shape
                    .fill(mainTabThumbRestFill)
                    .frame(width: width, height: height)
            } else {
                shape
                    .fill(mainTabThumbRestFill)
                    .overlay {
                        shape.strokeBorder(
                            Color.white.opacity(appearance.theme.usesLightContent ? 0.28 : 0.18),
                            lineWidth: 0.85
                        )
                    }
                    .shadow(color: .black.opacity(0.14), radius: 3.5, y: 1)
                    .frame(width: width, height: height)
            }
        }
    }

    private func mainTabHeldGlassThumb(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)

        return Group {
            if appearance.usesZeroLiquidGlass {
                shape
                    .fill(Color.white.opacity(0.12))
                    .frame(width: width, height: height)
            } else if appearance.isNeomorphic {
                // Trzymany suwak: ten sam chip, lekko mocniejszy emboss.
                let shape = Capsule(style: .continuous)
                shape
                    .fill(appearance.neoChip)
                    .shadow(color: appearance.neoHighlight.opacity(0.45), radius: 6, x: -2, y: -2)
                    .shadow(color: appearance.neoShadow.opacity(0.55), radius: 6, x: 2, y: 2)
                    .frame(width: width, height: height)
            } else {
                // Clear refractive lens suwaka (osobno od toru pastylki).
                shape
                    .fill(Color.clear)
                    .frame(width: width, height: height)
                    .glassEffect(
                        Glass.clear.interactive(true),
                        in: shape
                    )
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.cyan.opacity(0.18),
                                    Color.white.opacity(0.12),
                                    Color.orange.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                        .blendMode(.plusLighter)
                    }
            }
        }
    }

    private enum MainTabLabelStyle {
        case inactive
        case accent
    }

    private func mainTabLabelsRow(
        tabs: [AppTab],
        slotWidth: CGFloat,
        height: CGFloat,
        style: MainTabLabelStyle,
        scrubProgress: CGFloat,
        collapse: CGFloat = 0
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                mainTabSlotLabel(tab, style: style, scrubProgress: scrubProgress, collapse: collapse)
                    .frame(width: slotWidth, height: height)
            }
        }
    }

    /// Tor pastylki: liquid glass wyłącznie jako tło (siła jak w reszcie UI).
    /// Nie wolno kłaść tego jako sibling ZStack obok ikon — tylko `.background { … }`.
    @ViewBuilder
    private var pillChromeBackground: some View {
        let shape = Capsule(style: .continuous)
        if appearance.usesZeroLiquidGlass {
            shape
                .fill(appearance.fullyOpaque(appearance.tileTint))
        } else if appearance.isNeomorphic {
            // Dock referencyjny: surface 0.85 na ultraThinMaterial + miękki cień w dół.
            // Material musi kompozować na żywo — bez drawingGroup.
            shape
                .fill(appearance.neoSurface.opacity(0.85))
                .background {
                    shape.fill(.ultraThinMaterial)
                }
                .shadow(color: appearance.neoShadow, radius: 20, x: 0, y: 10)
        } else {
            let blend = appearance.glassBlend()
            shape
                .fill(Color.clear)
                .glassEffect(
                    appearance.blendedGlass(
                        interactive: false,
                        tint: appearance.tileTint.opacity(0.55),
                        blend: blend
                    ),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        Color.white.opacity(appearance.theme.usesLightContent ? 0.28 : 0.16),
                        lineWidth: 0.8
                    )
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
        }
    }

    private func mainTabScrubGesture(slotWidth: CGFloat, slotCount: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard slotCount > 0, slotWidth > 0, !isAIDragActive else { return }

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let dragDistance = hypot(value.translation.width, value.translation.height)

                // Pociągnięcie w górę zostawiamy gestowi AI (Aktualny Plan).
                if vertical > 14, vertical > horizontal * 1.1 {
                    if isMainTabScrubbing {
                        withAnimation(mainTabThumbMorphAnimation) {
                            isMainTabScrubbing = false
                            mainTabSliderStretch = 0
                            mainTabScrubProgress = CGFloat(AppTab.allCases.firstIndex(of: selectedTab) ?? 0)
                        }
                        mainTabLastDragX = nil
                        mainTabLastDragTime = nil
                    }
                    return
                }

                // Powiększenie / wystawanie tylko przy realnym trzymaniu suwaka.
                // Mały ruch (kliknięcie) nie jest trzymaniem — suwak zostaje na miejscu
                // i animuje płynny ślizg do wybranej zakładki dopiero w onEnded.
                if dragDistance > mainTabTapThreshold, !isMainTabScrubbing {
                    withAnimation(mainTabThumbMorphAnimation) {
                        isMainTabScrubbing = true
                    }
                    suppressPlanTap = true
                }

                let x = value.location.x - mainTabPillPadding
                let raw = x / slotWidth - 0.5

                guard isMainTabScrubbing else {
                    if abs(mainTabSliderStretch) > 0.001 {
                        mainTabSliderStretch *= 0.82
                    }
                    return
                }

                let now = Date()
                if let lastX = mainTabLastDragX, let lastTime = mainTabLastDragTime {
                    let dt = now.timeIntervalSince(lastTime)
                    if dt > 0.002, dt < 0.12 {
                        let velocity = (value.location.x - lastX) / dt
                        // Szybki ruch w bok → naturalne rozciągnięcie / gibanie.
                        // Przy krawędziach pastylki tłumimy stretch (mniej migotania morphu glass).
                        let maxIndex = max(CGFloat(slotCount - 1), 1)
                        let clampedRaw = min(max(raw, 0), maxIndex)
                        let edgeT = min(min(clampedRaw / 0.45, (maxIndex - clampedRaw) / 0.45), 1)
                        let edgeScale = max(0.15, edgeT)
                        let targetStretch = max(-1.0, min(1.0, (velocity / 820) * edgeScale))
                        var stretchTx = Transaction()
                        stretchTx.disablesAnimations = true
                        withTransaction(stretchTx) {
                            mainTabSliderStretch += (targetStretch - mainTabSliderStretch) * 0.38
                        }
                    }
                } else {
                    var stretchTx = Transaction()
                    stretchTx.disablesAnimations = true
                    withTransaction(stretchTx) {
                        mainTabSliderStretch *= 0.82
                    }
                }
                mainTabLastDragX = value.location.x
                mainTabLastDragTime = now

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    mainTabScrubProgress = min(max(raw, 0), CGFloat(slotCount - 1))
                }
            }
            .onEnded { value in
                defer {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        suppressPlanTap = false
                    }
                }

                mainTabLastDragX = nil
                mainTabLastDragTime = nil

                guard !isAIDragActive else {
                    withAnimation(mainTabThumbMorphAnimation) {
                        isMainTabScrubbing = false
                        mainTabSliderStretch = 0
                        mainTabScrubProgress = CGFloat(AppTab.allCases.firstIndex(of: selectedTab) ?? 0)
                    }
                    return
                }

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let maxIndex = max(slotCount - 1, 0)

                if vertical > 18, vertical > horizontal * 1.2 {
                    withAnimation(mainTabThumbMorphAnimation) {
                        isMainTabScrubbing = false
                        mainTabSliderStretch = 0
                        mainTabScrubProgress = CGFloat(AppTab.allCases.firstIndex(of: selectedTab) ?? 0)
                    }
                    return
                }

                let commitIndex: Int
                if horizontal < 8 && vertical < 8 {
                    let x = value.location.x - mainTabPillPadding
                    commitIndex = min(max(Int((x / max(slotWidth, 1)).rounded(.down)), 0), maxIndex)
                } else {
                    commitIndex = min(max(Int(mainTabScrubProgress.rounded()), 0), maxIndex)
                }

                let tab = AppTab.allCases[commitIndex]
                let changed = tab != selectedTab
                let oldIndex = AppTab.allCases.firstIndex(of: selectedTab) ?? 0
                if changed {
                    mainTabSlideForward = commitIndex > oldIndex
                }

                // Puszczenie: płynny powrót liquid glass → 2D + dociągnięcie do slotu.
                // Kliknięcie (bez ruchu) dostaje dłuższy ślizg, żeby suwak płynnie przejechał
                // ze starej zakładki do wybranej; po trzymaniu — szybki morph powrotu.
                let dockAnimation: Animation =
                    (horizontal < 8 && vertical < 8)
                    ? mainTabTapSlideAnimation
                    : mainTabThumbMorphAnimation
                withAnimation(dockAnimation) {
                    isMainTabScrubbing = false
                    mainTabSliderStretch = 0
                    mainTabScrubProgress = CGFloat(commitIndex)
                    selectedTab = tab
                }

                if changed {
                    BeSortedSound.play(.tab)
                }
            }
    }

    private func mainTabSlotLabel(
        _ tab: AppTab,
        style: MainTabLabelStyle,
        scrubProgress: CGFloat,
        collapse: CGFloat = 0
    ) -> some View {
        let isAccent = style == .accent
        // Neumorfizm (referencja TabBarButton): aktywna = biel (biały/srebrny: primaryText),
        // nieaktywne = textSecondary. Bez poświat — płaskie kolory na chipie.
        let color = appearance.isNeomorphic
            ? (isAccent ? mainTabActiveForeground : appearance.secondaryText)
            : (isAccent ? appearance.tabSliderAccent : mainTabInactiveForeground)
        let focusScale = mainTabIconFocusScale(for: tab, scrubProgress: scrubProgress)
        // Napisy znikają w mini formie; ikonki zostają.
        let labelOpacity = max(0, 1 - collapse * 1.55)

        return VStack(spacing: labelOpacity > 0.08 ? 4 : 0) {
            tabPillIcon(tab, style: style)
            if labelOpacity > 0.05 {
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(maxWidth: .infinity)
                    .opacity(labelOpacity)
            }
        }
        .scaleEffect(focusScale)
        .padding(.horizontal, 2)
        .accessibilityHidden(style == .accent)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(tab == selectedTab ? .isSelected : [])
        .accessibilityHint(
            tab == .plan
                ? "Na zakładce Aktualny Plan mocno przeciągnij w górę, aby otworzyć AI".l10n
                : ""
        )
    }

    /// Lekkie powiększenie, gdy suwak w pełni najedzie na ikonkę.
    private func mainTabIconFocusScale(for tab: AppTab, scrubProgress: CGFloat) -> CGFloat {
        guard let index = AppTab.allCases.firstIndex(of: tab) else { return 1 }
        let distance = abs(scrubProgress - CGFloat(index))
        let raw = max(0, 1 - distance / 0.38)
        let eased = raw * raw * (3 - 2 * raw)
        return 1 + 0.11 * eased
    }

    @ViewBuilder
    private func tabPillIcon(_ tab: AppTab, style: MainTabLabelStyle) -> some View {
        let isAccent = style == .accent
        let color = appearance.isNeomorphic
            ? (isAccent ? mainTabActiveForeground : appearance.secondaryText)
            : (style == .accent ? appearance.tabSliderAccent : mainTabInactiveForeground)
        Image(systemName: tab.systemImage)
            .font(.system(size: 17, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .frame(width: 22, height: 22)
    }

    private var projectsSearchToggleButton: some View {
        let isExpanded = smartChrome.isProjectsSearchExpanded
        let shape = Capsule(style: .continuous)

        return Image(systemName: isExpanded ? "xmark" : "magnifyingglass")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(appearance.primaryText)
            .frame(width: mainTabSearchButtonSize, height: mainTabSearchButtonSize)
            .contentTransition(.symbolEffect(.replace))
            .background {
                if appearance.usesZeroLiquidGlass {
                    shape
                        .fill(appearance.fullyOpaque(appearance.tileTint))
                } else if appearance.isNeomorphic {
                    BeSortedNeoRaised(shape: shape, appearance: appearance)
                } else {
                    shape
                        .fill(Color.clear)
                        .glassEffect(
                            appearance.blendedGlass(
                                interactive: true,
                                tint: appearance.tileTint,
                                blend: appearance.glassBlend()
                            ),
                            in: shape
                        )
                }
            }
            .shadow(
                color: appearance.isFlatDesign ? .clear : .black.opacity(0.12),
                radius: appearance.isFlatDesign ? 0 : 7,
                y: appearance.isFlatDesign ? 0 : 2
            )
            .offset(x: -lupaPullTowardPill)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let pull = max(0, -value.translation.width)
                        lupaPullTowardPill = min(pull, lupaPullMax)
                    }
                    .onEnded { value in
                        let pull = max(0, -value.translation.width)
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)

                        withAnimation(.smooth(duration: 0.28)) {
                            lupaPullTowardPill = 0
                        }

                        // Lekki tap → otwórz / zamknij wyszukiwanie.
                        if horizontal < 8, vertical < 8 {
                            BeSortedSound.play(.regular)
                            if isExpanded {
                                collapseProjectsSearch(animated: true, clearQuery: true)
                            } else {
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                    smartChrome.isProjectsSearchExpanded = true
                                }
                            }
                        } else if pull > 2 {
                            BeSortedSound.play(.regular)
                        }
                    }
            )
            .accessibilityLabel(isExpanded ? "Zamknij wyszukiwanie".l10n : "Szukaj".l10n)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                BeSortedSound.play(.regular)
                if isExpanded {
                    collapseProjectsSearch(animated: true, clearQuery: true)
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        smartChrome.isProjectsSearchExpanded = true
                    }
                }
            }
    }

    private func collapseProjectsSearch(animated: Bool, clearQuery: Bool = false) {
        let work = {
            smartChrome.isProjectsSearchExpanded = false
            if clearQuery {
                smartChrome.searchQuery = ""
            }
        }
        if animated {
            withAnimation(.smooth(duration: 0.36), work)
        } else {
            work()
        }
    }

    private var projectDetailTabBar: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            CollapsingPillChrome(showsProjectsSearch: false) { collapse in
                ProjectDetailPill(
                    selection: projectDetailTab,
                    collapse: collapse,
                    onSelect: { tab in
                        withAnimation(.smooth(duration: 0.26)) {
                            projectDetailTab = tab
                        }
                    }
                )
            } searchButton: {
                EmptyView()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.36), value: appearance.glassStyle)
    }

    /// Tryb poziomy: pionowy dock głównych zakładek przy prawej krawędzi.
    private var appVerticalDock: some View {
        let titles = AppTab.allCases.map(\.title)
        let images = AppTab.allCases.map(\.systemImage)
        // Grupa pionowa: pastylka + lupa poniżej — centrowana jako całość względem osi Y,
        // więc w zakładkach z lupą pastylka podnosi się odrobinę, a bez lupy
        // automatycznie wraca na idealny środek osi Y (jak przy dynamicznym X w poziomej pastylce).
        let lupaHeight = mainTabSearchButtonSize
        let lupaGap: CGFloat = 69
        // Kurczenie lupy razem z pastylką (jak w pionie): skala = skala docku × wygaszenie
        // przed pełnym kolapsem (bez zostawiania „mikro-kropki").
        let collapse = appearance.collapsingMenuPill ? smartChrome.menuPillCollapseProgress : 0
        let shrinkY = 1 - 0.18 * collapse
        let endKill: CGFloat = collapse < 0.72
            ? 1
            : max(0, 1 - (collapse - 0.72) / 0.22)
        let lupaScale = max(0, shrinkY * endKill)

        return VStack(spacing: 0) {
            LandscapeVerticalDock(
                titles: titles,
                images: images,
                selection: AppTab.allCases.firstIndex(of: selectedTab) ?? 0,
                onSelect: { index in
                    let tab = AppTab.allCases[index]
                    let oldIndex = AppTab.allCases.firstIndex(of: selectedTab) ?? 0
                    if oldIndex != index {
                        mainTabSlideForward = index > oldIndex
                    }
                    withAnimation(Self.mainTabSlideAnimation) {
                        selectedTab = tab
                    }
                    collapseProjectsSearch(animated: true, clearQuery: true)
                },
                collapse: appearance.collapsingMenuPill ? smartChrome.menuPillCollapseProgress : 0
            ) {
                EmptyView()
            }

            if selectedTab == .projects {
                projectsSearchToggleButton
                    .padding(.top, lupaGap)
                    .frame(height: lupaHeight)
                    .scaleEffect(lupaScale, anchor: .center)
                    .opacity(lupaScale)
                    .allowsHitTesting(lupaScale > 0.35)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.34), value: selectedTab)
        .animation(.smooth(duration: 0.36), value: appearance.glassStyle)
        .animation(.spring(response: 0.46, dampingFraction: 0.58), value: smartChrome.menuPillCollapseProgress)
    }

    /// Tryb poziomy: pionowy dock zakładek projektu przy prawej krawędzi.
    private var projectDetailVerticalDock: some View {
        VStack(spacing: 12) {
            LandscapeVerticalDock(
                titles: ProjectDetailTab.allCases.map(\.title),
                images: ProjectDetailTab.allCases.map(\.systemImage),
                selection: ProjectDetailTab.allCases.firstIndex(of: projectDetailTab) ?? 0,
                onSelect: { index in
                    withAnimation(.smooth(duration: 0.26)) {
                        projectDetailTab = ProjectDetailTab.allCases[index]
                    }
                },
                collapse: appearance.collapsingMenuPill ? smartChrome.menuPillCollapseProgress : 0
            ) {
                EmptyView()
            }
        }
        .animation(.smooth(duration: 0.36), value: appearance.glassStyle)
    }

    private var planAIPullGesture: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .named("rootAI"))
            .onChanged { value in
                guard selectedTab == .plan else { return }

                let screenHeight = UIScreen.main.bounds.height
                let maxPull = screenHeight * 0.30
                let rawPullUp = max(0, -value.translation.height)
                let pullUp = min(rawPullUp, maxPull)
                let mostlyVertical = abs(value.translation.height) > abs(value.translation.width) * 0.7

                guard mostlyVertical else { return }

                guard pullUp >= aiStrongPullDistance else {
                    if isAIDragActive {
                        withAnimation(.smooth(duration: 0.28)) {
                            aiDetachProgress = 0
                            isAIDragActive = false
                            aiDragTranslation = .zero
                        }
                    }
                    return
                }

                let travel = max(maxPull - aiStrongPullDistance, 1)
                let progress = min(1, (pullUp - aiStrongPullDistance) / travel)
                aiDragTranslation = CGSize(
                    width: value.translation.width,
                    height: max(value.translation.height, -maxPull)
                )

                if !isAIDragActive {
                    isAIDragActive = true
                    aiDetachProgress = 0
                    withAnimation(.smooth(duration: 0.22)) {
                        aiDetachProgress = max(progress, 0.02)
                    }
                } else {
                    aiDetachProgress = progress
                }
            }
            .onEnded { value in
                guard selectedTab == .plan, isAIDragActive else {
                    resetAIPull()
                    return
                }

                suppressPlanTap = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    suppressPlanTap = false
                }

                let dropPoint = value.location
                let cancelZone = planTabFrame.insetBy(dx: -20, dy: -30)
                let shouldCancel = cancelZone.contains(dropPoint) || aiDetachProgress < 0.42

                withAnimation(.smooth(duration: 0.32)) {
                    resetAIPull()
                }

                if !shouldCancel {
                    withAnimation(.smooth(duration: 0.32)) {
                        showAIAssistant = true
                    }
                }
            }
    }

    private func resetAIPull() {
        aiDetachProgress = 0
        isAIDragActive = false
        aiDragTranslation = .zero
    }
}

/// Pastylka detalu projektu — ta sama „Fitness-like” pastylka co w głównym tabbarze,
/// tylko z zakładkami projektu (Zadania / Aktualne błędy / Notatka przyszłości).
private struct ProjectDetailPill: View {
    @Environment(AppAppearance.self) private var appearance

    let selection: ProjectDetailTab
    var collapse: CGFloat = 0
    let onSelect: (ProjectDetailTab) -> Void

    private let tabs = ProjectDetailTab.allCases
    private let trackPadding: CGFloat = 4
    private let slotHeight: CGFloat = 50
    private let thumbExtra: CGFloat = 8

    @State private var isScrubbing = false
    @State private var scrubProgress: CGFloat = 0
    @State private var sliderStretch: CGFloat = 0
    @State private var lastDragX: CGFloat?
    @State private var lastDragTime: Date?

    private let scrubPillScale: CGFloat = 1.01
    private let scrubSliderOutset: CGFloat = 9
    private let thumbMorphAnimation: Animation = .spring(response: 0.40, dampingFraction: 0.84)
    private let tapSlideAnimation: Animation = .spring(response: 0.46, dampingFraction: 0.72)
    private let tapThreshold: CGFloat = 8

    private func index(of tab: ProjectDetailTab) -> CGFloat {
        CGFloat(tabs.firstIndex(of: tab) ?? 0)
    }

    private func progress(slotCount: Int) -> CGFloat {
        min(max(scrubProgress, 0), max(CGFloat(slotCount - 1), 0))
    }

    private var restThumbFill: Color {
        appearance.theme.usesLightContent
            ? Color.black.opacity(0.14)
            : Color.black.opacity(0.50)
    }

    var body: some View {
        GeometryReader { geo in
            let innerWidth = max(geo.size.width - trackPadding * 2, 1)
            let slotWidth = innerWidth / CGFloat(max(tabs.count, 1))
            let slotCount = tabs.count
            let sliderHeight = max(geo.size.height - trackPadding * 2, 1)
            let progress = progress(slotCount: slotCount)
            let stretch = sliderStretch
            let stretchScaleX = 1 + abs(stretch) * 0.22
            let stretchScaleY = 1 - abs(stretch) * 0.1
            let glassLift: CGFloat = isScrubbing ? 1 : 0
            let restingThumbWidth = min(slotWidth + thumbExtra, innerWidth)
            let holdOutset = scrubSliderOutset * glassLift
            let thumbWidth = restingThumbWidth + 8 * glassLift
            let thumbHeight = sliderHeight + holdOutset
            let thumbY = trackPadding - holdOutset / 2
            let thumbLead = stretch * min(slotWidth * 0.10, 8)
            let restingThumbX = trackPadding
                + progress * slotWidth
                - (restingThumbWidth - slotWidth) / 2
            let thumbNudge = 1.5 * glassLift
            let thumbOffsetX = restingThumbX - thumbNudge + thumbLead - (3 * glassLift)
            let glassScale = 1 + 0.18 * glassLift
            let accentMaskX =
                progress * slotWidth
                - (restingThumbWidth - slotWidth) / 2
                - thumbNudge
                - (3 * glassLift)
                + thumbLead
            let shape = Capsule(style: .continuous)

            ZStack(alignment: .topLeading) {
                Color.clear
                    .background { projectTrack }

                thumb(width: restingThumbWidth, height: sliderHeight)
                    .offset(x: restingThumbX + thumbLead * (1 - glassLift), y: trackPadding)
                    .opacity(1 - glassLift)
                    .animation(thumbMorphAnimation, value: isScrubbing)
                    .allowsHitTesting(false)

                if isScrubbing {
                    heldThumb(width: thumbWidth, height: thumbHeight)
                        .scaleEffect(x: glassScale * stretchScaleX, y: glassScale * stretchScaleY)
                        .offset(x: thumbOffsetX, y: thumbY)
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.92))
                                    .animation(thumbMorphAnimation),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.96))
                                    .animation(thumbMorphAnimation)
                            )
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                ZStack {
                    projectLabelsRow(
                        slotWidth: slotWidth,
                        height: sliderHeight,
                        active: false,
                        progress: progress,
                        collapse: collapse
                    )
                    projectLabelsRow(
                        slotWidth: slotWidth,
                        height: sliderHeight,
                        active: true,
                        progress: progress,
                        collapse: collapse
                    )
                    .mask(alignment: .leading) {
                        Capsule(style: .continuous)
                            .frame(width: thumbWidth, height: sliderHeight)
                            .scaleEffect(x: stretchScaleX, y: 1, anchor: .center)
                            .offset(x: accentMaskX)
                    }
                }
                .padding(.horizontal, trackPadding)
                .padding(.vertical, trackPadding)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .animation(
                    isScrubbing ? nil : thumbMorphAnimation,
                    value: scrubProgress
                )

                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        Button {
                            onSelect(tab)
                        } label: {
                            Color.clear
                                .frame(width: slotWidth, height: sliderHeight)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(BeSortedPlainButtonStyle(sound: .tab))
                        .accessibilityLabel(tab.title)
                        .accessibilityAddTraits(tab == selection ? .isSelected : [])
                    }
                }
                .frame(width: innerWidth, height: sliderHeight, alignment: .leading)
                .padding(.horizontal, trackPadding)
                .padding(.vertical, trackPadding)
                .allowsHitTesting(false)
            }
            .animation(thumbMorphAnimation, value: isScrubbing)
            .contentShape(shape)
            .highPriorityGesture(scrubGesture(slotWidth: slotWidth, slotCount: slotCount))
        }
        .frame(height: slotHeight + trackPadding * 2)
        .padding(.vertical, scrubSliderOutset)
        .scaleEffect(isScrubbing ? scrubPillScale : 1.0)
        .shadow(
            color: appearance.isNeomorphic
                ? .black.opacity(appearance.theme.usesLightContent ? 0.16 : 0.30)
                : (appearance.isFlatDesign ? .clear : .black.opacity(isScrubbing ? 0.14 : 0.10)),
            radius: appearance.isNeomorphic ? 10 : (appearance.isFlatDesign ? 0 : (isScrubbing ? 11 : 8)),
            y: appearance.isNeomorphic ? 1 : (appearance.isFlatDesign ? 0 : (isScrubbing ? 2 : 2))
        )
        .animation(thumbMorphAnimation, value: isScrubbing)
        .accessibilityElement(children: .contain)
        .onAppear {
            scrubProgress = index(of: selection)
            lastDragX = nil
            lastDragTime = nil
        }
        .onChange(of: selection) { _, newValue in
            guard !isScrubbing else { return }
            let index = index(of: newValue)
            if abs(scrubProgress - index) > 0.02 {
                withAnimation(.smooth(duration: 0.38)) {
                    scrubProgress = index
                }
            }
        }
    }

    @ViewBuilder
    private var projectTrack: some View {
        let shape = Capsule(style: .continuous)
        if appearance.isFlatDesign {
            shape
                .fill(appearance.fullyOpaque(appearance.tileTint))
        } else if appearance.isNeomorphic {
            shape
                .fill(appearance.neoSurface.opacity(0.85))
                .background { shape.fill(.ultraThinMaterial) }
                .shadow(color: appearance.neoShadow, radius: 20, x: 0, y: 10)
        } else {
            shape
                .fill(Color.clear)
                .glassEffect(
                    appearance.blendedGlass(
                        interactive: false,
                        tint: appearance.tileTint.opacity(0.55),
                        blend: appearance.glassBlend()
                    ),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        Color.white.opacity(appearance.theme.usesLightContent ? 0.28 : 0.16),
                        lineWidth: 0.8
                    )
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
        }
    }

    @ViewBuilder
    private func thumb(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)
        if appearance.isNeomorphic {
            shape
                .fill(appearance.neoChip)
                .shadow(color: appearance.neoHighlight.opacity(0.40), radius: 6, x: -2, y: -2)
                .shadow(color: appearance.neoShadow.opacity(0.50), radius: 6, x: 2, y: 2)
                .frame(width: width, height: height)
        } else if appearance.isFlatDesign {
            shape
                .fill(restThumbFill)
                .frame(width: width, height: height)
        } else {
            shape
                .fill(restThumbFill)
                .overlay {
                    shape.strokeBorder(
                        Color.white.opacity(appearance.theme.usesLightContent ? 0.28 : 0.18),
                        lineWidth: 0.85
                    )
                }
                .shadow(color: .black.opacity(0.14), radius: 3.5, y: 1)
                .frame(width: width, height: height)
        }
    }

    @ViewBuilder
    private func heldThumb(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)
        if appearance.usesZeroLiquidGlass {
            shape
                .fill(restThumbFill)
                .frame(width: width, height: height)
        } else if appearance.isNeomorphic {
            // Trzymany suwak: ten sam chip, lekko mocniejszy emboss.
            let shape = Capsule(style: .continuous)
            shape
                .fill(appearance.neoChip)
                .shadow(color: appearance.neoHighlight.opacity(0.45), radius: 6, x: -2, y: -2)
                .shadow(color: appearance.neoShadow.opacity(0.55), radius: 6, x: 2, y: 2)
                .frame(width: width, height: height)
        } else {
            // Full / Balanced: czysty refrakcyjny lens Live Glass (identyczny z główną pastylką).
            // Zero mrozu — deformuje to, co za nim, zamiast mglić; tylko obwódka plusLighter.
            shape
                .fill(Color.clear)
                .frame(width: width, height: height)
                .glassEffect(Glass.clear.interactive(true), in: shape)
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.cyan.opacity(0.18),
                                Color.white.opacity(0.12),
                                Color.orange.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                    .blendMode(.plusLighter)
                }
        }
    }

    private func projectLabelsRow(slotWidth: CGFloat, height: CGFloat, active: Bool, progress: CGFloat, collapse: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let focusScale = projectIconFocusScale(for: tab, progress: progress)
                // Kolaps jak w głównej pastylce: napisy znikają, ikony zostają.
                let labelOpacity = max(0, 1 - collapse * 1.55)
                VStack(spacing: labelOpacity > 0.08 ? 3 : 0) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 20, height: 20)
                    if labelOpacity > 0.05 {
                        Text(tab.title)
                            .font(.system(size: 10.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .opacity(labelOpacity)
                    }
                }
                .foregroundStyle(labelColor(active: active))
                .scaleEffect(focusScale)
                .frame(width: slotWidth, height: height)
            }
        }
    }

    private func projectIconFocusScale(for tab: ProjectDetailTab, progress: CGFloat) -> CGFloat {
        guard let index = tabs.firstIndex(of: tab) else { return 1 }
        let distance = abs(progress - CGFloat(index))
        let raw = max(0, 1 - distance / 0.38)
        let eased = raw * raw * (3 - 2 * raw)
        return 1 + 0.10 * eased
    }

    private func labelColor(active: Bool) -> Color {
        if active {
            if appearance.isNeomorphic {
                return appearance.theme.usesLightContent ? appearance.primaryText : Color.white
            }
            return appearance.tabSliderAccent
        }
        return appearance.secondaryText
    }

    /// Suwak identyczny jak w głównej pastylce: przeciąganie trzyma suwak, kliknięcie ślizga do slotu.
    private func scrubGesture(slotWidth: CGFloat, slotCount: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard slotCount > 0, slotWidth > 0 else { return }

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let dragDistance = hypot(value.translation.width, value.translation.height)

                if vertical > 14, vertical > horizontal * 1.1 {
                    if isScrubbing {
                        withAnimation(thumbMorphAnimation) {
                            isScrubbing = false
                            sliderStretch = 0
                            scrubProgress = index(of: selection)
                        }
                        lastDragX = nil
                        lastDragTime = nil
                    }
                    return
                }

                if dragDistance > tapThreshold, !isScrubbing {
                    withAnimation(thumbMorphAnimation) {
                        isScrubbing = true
                    }
                }

                let x = value.location.x - trackPadding
                let raw = x / slotWidth - 0.5

                guard isScrubbing else {
                    if abs(sliderStretch) > 0.001 {
                        sliderStretch *= 0.82
                    }
                    return
                }

                let now = Date()
                if let lastX = lastDragX, let lastTime = lastDragTime {
                    let dt = now.timeIntervalSince(lastTime)
                    if dt > 0.002, dt < 0.12 {
                        let velocity = (value.location.x - lastX) / dt
                        let maxIndex = max(CGFloat(slotCount - 1), 1)
                        let clampedRaw = min(max(raw, 0), maxIndex)
                        let edgeT = min(min(clampedRaw / 0.45, (maxIndex - clampedRaw) / 0.45), 1)
                        let edgeScale = max(0.15, edgeT)
                        let targetStretch = max(-1.0, min(1.0, (velocity / 820) * edgeScale))
                        var stretchTx = Transaction()
                        stretchTx.disablesAnimations = true
                        withTransaction(stretchTx) {
                            sliderStretch += (targetStretch - sliderStretch) * 0.38
                        }
                    }
                } else {
                    var stretchTx = Transaction()
                    stretchTx.disablesAnimations = true
                    withTransaction(stretchTx) {
                        sliderStretch *= 0.82
                    }
                }
                lastDragX = value.location.x
                lastDragTime = now

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrubProgress = min(max(raw, 0), CGFloat(slotCount - 1))
                }
            }
            .onEnded { value in
                lastDragX = nil
                lastDragTime = nil

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let maxIndex = max(slotCount - 1, 0)

                if vertical > 18, vertical > horizontal * 1.2 {
                    withAnimation(thumbMorphAnimation) {
                        isScrubbing = false
                        sliderStretch = 0
                        scrubProgress = index(of: selection)
                    }
                    return
                }

                let commitIndex: Int
                if horizontal < 8 && vertical < 8 {
                    let x = value.location.x - trackPadding
                    commitIndex = min(max(Int((x / max(slotWidth, 1)).rounded(.down)), 0), maxIndex)
                } else {
                    commitIndex = min(max(Int(scrubProgress.rounded()), 0), maxIndex)
                }

                let tab = tabs[commitIndex]
                let changed = tab != selection
                // Kliknięcie (bez ruchu): dłuższy ślizg ze starej zakładki do wybranej.
                // Trzymanie: szybki morph powrotu suwaka.
                let dockAnimation: Animation =
                    (horizontal < 8 && vertical < 8)
                    ? tapSlideAnimation
                    : thumbMorphAnimation
                withAnimation(dockAnimation) {
                    isScrubbing = false
                    sliderStretch = 0
                    scrubProgress = CGFloat(commitIndex)
                }
                onSelect(tab)
                if changed {
                    BeSortedSound.play(.tab)
                }
            }
    }
}

/// Pionowy dock na prawą krawędź ekranu (tylko tryb poziomy) — jak iPadOS dock:
/// ta sama „Fitness” pastylka, ale suwak jeździ w pionie. Zero mrozu na suwaku —
/// czysty refrakcyjny glass (Full / Balanced), płaski w Zero, emboss w neumorfizmie.
private struct LandscapeVerticalDock<Accessory: View>: View {
    @Environment(AppAppearance.self) private var appearance

    let titles: [String]
    let images: [String]
    let selection: Int
    let onSelect: (Int) -> Void
    var collapse: CGFloat = 0
    /// Akcesorium pod dockiem (np. lupa) — renderowane wewnątrz, więc skaluje się
    /// i przesuwa razem z pastylką (nie zachodzi na nią podczas kolapsu).
    @ViewBuilder var accessory: () -> Accessory

    private let dockWidth: CGFloat = 80
    private let horizontalPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 6
    private let slotHeight: CGFloat = 58
    private let thumbExtra: CGFloat = 8
    private let scrubSliderOutset: CGFloat = 9
    private let scrubPillScale: CGFloat = 1.01
    private let thumbMorphAnimation: Animation = .spring(response: 0.40, dampingFraction: 0.84)
    private let tapSlideAnimation: Animation = .spring(response: 0.46, dampingFraction: 0.72)
    private let tapThreshold: CGFloat = 8
    /// Odstęp akcesorium poniżej dolnej krawędzi docku (wysokość lupy/2 + przerwa).
    private let bottomAccessoryOffset: CGFloat = 104

    @State private var isScrubbing = false
    @State private var scrubProgress: CGFloat = 0
    @State private var sliderStretch: CGFloat = 0
    @State private var lastDragY: CGFloat?
    @State private var lastDragTime: Date?

    private var restThumbFill: Color {
        appearance.theme.usesLightContent
            ? Color.black.opacity(0.14)
            : Color.black.opacity(0.50)
    }

    var body: some View {
        let count = titles.count
        let slotCount = CGFloat(count)
        let dockHeight = CGFloat(count) * slotHeight + verticalPadding * 2
        let sliderWidth = dockWidth - horizontalPadding * 2
        let progress = min(max(scrubProgress, 0), max(slotCount - 1, 0))
        let stretch = sliderStretch
        let stretchScaleX = 1 - abs(stretch) * 0.1
        let stretchScaleY = 1 + abs(stretch) * 0.22
        let glassLift: CGFloat = isScrubbing ? 1 : 0
        let restingThumbHeight = slotHeight + thumbExtra
        let holdOutset = scrubSliderOutset * glassLift
        let heldThumbHeight = restingThumbHeight + 8 * glassLift
        let heldThumbWidth = sliderWidth + holdOutset
        let heldX = horizontalPadding - holdOutset / 2
        let thumbLead = stretch * min(slotHeight * 0.10, 8)
        let restingThumbY = verticalPadding
            + progress * slotHeight
            - (restingThumbHeight - slotHeight) / 2
        let thumbNudge = 1.5 * glassLift
        let heldOffsetY = restingThumbY - thumbNudge + thumbLead - (3 * glassLift)
        let glassScale = 1 + 0.18 * glassLift
        let accentMaskY =
            progress * slotHeight
            - (restingThumbHeight - slotHeight) / 2
            - thumbNudge
            - (3 * glassLift)
            + thumbLead
        let shape = Capsule(style: .continuous)

        ZStack(alignment: .topLeading) {
            Color.clear
                .background { dockTrack }

            restThumb(width: sliderWidth + thumbExtra, height: restingThumbHeight)
                .offset(x: horizontalPadding - thumbExtra / 2, y: restingThumbY + thumbLead * (1 - glassLift))
                .opacity(1 - glassLift)
                .animation(thumbMorphAnimation, value: isScrubbing)
                .allowsHitTesting(false)

            if isScrubbing {
                heldThumb(width: heldThumbWidth, height: heldThumbHeight)
                    .scaleEffect(x: glassScale * stretchScaleX, y: glassScale * stretchScaleY)
                    .offset(x: heldX, y: heldOffsetY)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.92))
                                .animation(thumbMorphAnimation),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.96))
                                .animation(thumbMorphAnimation)
                        )
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            ZStack {
                dockLabels(active: false, width: sliderWidth, progress: progress)
                dockLabels(active: true, width: sliderWidth, progress: progress)
                    .mask(alignment: .top) {
                        Capsule(style: .continuous)
                            .frame(width: sliderWidth + thumbExtra, height: restingThumbHeight + 8 * glassLift)
                            .scaleEffect(x: 1, y: stretchScaleY, anchor: .center)
                            .offset(y: accentMaskY)
                    }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(
                isScrubbing ? nil : thumbMorphAnimation,
                value: scrubProgress
            )

            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    Button {
                        onSelect(index)
                    } label: {
                        Color.clear
                            .frame(width: sliderWidth, height: slotHeight)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle(sound: .tab))
                    .accessibilityLabel(titles[index])
                    .accessibilityAddTraits(index == selection ? .isSelected : [])
                }
            }
            .frame(width: sliderWidth, height: dockHeight - verticalPadding * 2, alignment: .top)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .allowsHitTesting(false)
        }
        .frame(width: dockWidth, height: dockHeight)
        .contentShape(Rectangle())
        .highPriorityGesture(scrubGesture(slotHeight: slotHeight, slotCount: count))
        .overlay(alignment: .bottom) {
            accessory()
                .offset(y: bottomAccessoryOffset)
        }
        .scaleEffect(isScrubbing ? scrubPillScale : 1.0)
        .scaleEffect(
            x: 1 - 0.18 * collapse,
            y: 1 - 0.18 * collapse,
            anchor: .trailing
        )
        .shadow(
            color: appearance.isNeomorphic
                ? .black.opacity(appearance.theme.usesLightContent ? 0.16 : 0.30)
                : (appearance.isFlatDesign ? .clear : .black.opacity(isScrubbing ? 0.14 : 0.10)),
            radius: appearance.isNeomorphic ? 10 : (appearance.isFlatDesign ? 0 : (isScrubbing ? 11 : 8)),
            y: appearance.isNeomorphic ? 1 : (appearance.isFlatDesign ? 0 : (isScrubbing ? 2 : 2))
        )
        .animation(thumbMorphAnimation, value: isScrubbing)
        .animation(.spring(response: 0.46, dampingFraction: 0.58), value: collapse)
        .accessibilityElement(children: .contain)
        .onAppear {
            scrubProgress = CGFloat(selection)
            lastDragY = nil
            lastDragTime = nil
        }
        .onChange(of: selection) { _, newValue in
            guard !isScrubbing else { return }
            let index = CGFloat(newValue)
            if abs(scrubProgress - index) > 0.02 {
                withAnimation(.smooth(duration: 0.38)) {
                    scrubProgress = index
                }
            }
        }
    }

    @ViewBuilder
    private var dockTrack: some View {
        let shape = Capsule(style: .continuous)
        if appearance.isFlatDesign {
            shape
                .fill(appearance.fullyOpaque(appearance.tileTint))
        } else if appearance.isNeomorphic {
            shape
                .fill(appearance.neoSurface.opacity(0.85))
                .background { shape.fill(.ultraThinMaterial) }
                .shadow(color: appearance.neoShadow, radius: 20, x: 0, y: 10)
        } else {
            shape
                .fill(Color.clear)
                .glassEffect(
                    appearance.blendedGlass(
                        interactive: false,
                        tint: appearance.tileTint.opacity(0.55),
                        blend: appearance.glassBlend()
                    ),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        Color.white.opacity(appearance.theme.usesLightContent ? 0.28 : 0.16),
                        lineWidth: 0.8
                    )
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
        }
    }

    @ViewBuilder
    private func restThumb(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)
        if appearance.isNeomorphic {
            shape
                .fill(appearance.neoChip)
                .shadow(color: appearance.neoHighlight.opacity(0.40), radius: 6, x: -2, y: -2)
                .shadow(color: appearance.neoShadow.opacity(0.50), radius: 6, x: 2, y: 2)
                .frame(width: width, height: height)
        } else if appearance.isFlatDesign {
            shape
                .fill(restThumbFill)
                .frame(width: width, height: height)
        } else {
            shape
                .fill(restThumbFill)
                .overlay {
                    shape.strokeBorder(
                        Color.white.opacity(appearance.theme.usesLightContent ? 0.28 : 0.18),
                        lineWidth: 0.85
                    )
                }
                .shadow(color: .black.opacity(0.14), radius: 3.5, y: 1)
                .frame(width: width, height: height)
        }
    }

    @ViewBuilder
    private func heldThumb(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)
        if appearance.usesZeroLiquidGlass {
            shape
                .fill(restThumbFill)
                .frame(width: width, height: height)
        } else if appearance.isNeomorphic {
            let shape = Capsule(style: .continuous)
            shape
                .fill(appearance.neoChip)
                .shadow(color: appearance.neoHighlight.opacity(0.45), radius: 6, x: -2, y: -2)
                .shadow(color: appearance.neoShadow.opacity(0.55), radius: 6, x: 2, y: 2)
                .frame(width: width, height: height)
        } else {
            // Full / Balanced: czysty refrakcyjny Lens — deformuje, nie mgli.
            shape
                .fill(Color.clear)
                .frame(width: width, height: height)
                .glassEffect(Glass.clear.interactive(true), in: shape)
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.cyan.opacity(0.18),
                                Color.white.opacity(0.12),
                                Color.orange.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                    .blendMode(.plusLighter)
                }
        }
    }

    private func dockLabels(active: Bool, width: CGFloat, progress: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<titles.count, id: \.self) { index in
                let focusScale = iconFocusScale(index: index, progress: progress)
                let labelOpacity = max(0, 1 - collapse * 1.55)
                VStack(spacing: labelOpacity > 0.08 ? 3 : 0) {
                    Image(systemName: images[index])
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 24, height: 24)
                    if labelOpacity > 0.05 {
                        Text(titles[index])
                            .font(.system(size: 9.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .opacity(labelOpacity)
                    }
                }
                .foregroundStyle(labelColor(active: active))
                .scaleEffect(focusScale)
                .frame(width: width, height: slotHeight)
            }
        }
    }

    private func iconFocusScale(index: Int, progress: CGFloat) -> CGFloat {
        let distance = abs(progress - CGFloat(index))
        let raw = max(0, 1 - distance / 0.38)
        let eased = raw * raw * (3 - 2 * raw)
        return 1 + 0.10 * eased
    }

    private func labelColor(active: Bool) -> Color {
        if active {
            if appearance.isNeomorphic {
                return appearance.theme.usesLightContent ? appearance.primaryText : Color.white
            }
            return appearance.tabSliderAccent
        }
        return appearance.secondaryText
    }

    private func scrubGesture(slotHeight: CGFloat, slotCount: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard slotCount > 0, slotHeight > 0 else { return }

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let dragDistance = hypot(value.translation.width, value.translation.height)

                if horizontal > 14, horizontal > vertical * 1.1 {
                    if isScrubbing {
                        withAnimation(thumbMorphAnimation) {
                            isScrubbing = false
                            sliderStretch = 0
                            scrubProgress = CGFloat(selection)
                        }
                        lastDragY = nil
                        lastDragTime = nil
                    }
                    return
                }

                if dragDistance > tapThreshold, !isScrubbing {
                    withAnimation(thumbMorphAnimation) {
                        isScrubbing = true
                    }
                }

                let y = value.location.y - verticalPadding
                let raw = y / slotHeight - 0.5

                guard isScrubbing else {
                    if abs(sliderStretch) > 0.001 {
                        sliderStretch *= 0.82
                    }
                    return
                }

                let now = Date()
                if let lastY = lastDragY, let lastTime = lastDragTime {
                    let dt = now.timeIntervalSince(lastTime)
                    if dt > 0.002, dt < 0.12 {
                        let velocity = (value.location.y - lastY) / dt
                        let maxIndex = max(CGFloat(slotCount - 1), 1)
                        let clampedRaw = min(max(raw, 0), maxIndex)
                        let edgeT = min(min(clampedRaw / 0.45, (maxIndex - clampedRaw) / 0.45), 1)
                        let edgeScale = max(0.15, edgeT)
                        let targetStretch = max(-1.0, min(1.0, (velocity / 820) * edgeScale))
                        var stretchTx = Transaction()
                        stretchTx.disablesAnimations = true
                        withTransaction(stretchTx) {
                            sliderStretch += (targetStretch - sliderStretch) * 0.38
                        }
                    }
                } else {
                    var stretchTx = Transaction()
                    stretchTx.disablesAnimations = true
                    withTransaction(stretchTx) {
                        sliderStretch *= 0.82
                    }
                }
                lastDragY = value.location.y
                lastDragTime = now

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrubProgress = min(max(raw, 0), CGFloat(slotCount - 1))
                }
            }
            .onEnded { value in
                lastDragY = nil
                lastDragTime = nil

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let maxIndex = max(slotCount - 1, 0)

                if horizontal > 18, horizontal > vertical * 1.2 {
                    withAnimation(thumbMorphAnimation) {
                        isScrubbing = false
                        sliderStretch = 0
                        scrubProgress = CGFloat(selection)
                    }
                    return
                }

                let commitIndex: Int
                if horizontal < 8 && vertical < 8 {
                    let y = value.location.y - verticalPadding
                    commitIndex = min(max(Int((y / max(slotHeight, 1)).rounded(.down)), 0), maxIndex)
                } else {
                    commitIndex = min(max(Int(scrubProgress.rounded()), 0), maxIndex)
                }

                let changed = commitIndex != selection
                let dockAnimation: Animation =
                    (horizontal < 8 && vertical < 8)
                    ? tapSlideAnimation
                    : thumbMorphAnimation
                withAnimation(dockAnimation) {
                    isScrubbing = false
                    sliderStretch = 0
                    scrubProgress = CGFloat(commitIndex)
                }
                onSelect(commitIndex)
                if changed {
                    BeSortedSound.play(.tab)
                }
            }
    }
}

private struct PlanTabFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct AIAssistantView: View {
    @Binding var isPresented: Bool
    @Environment(AppAppearance.self) private var appearance
    @Environment(\.modelContext) private var modelContext

    private enum PillState: Equatable {
        case input
        case loading
        case answer(String)
    }

    @State private var promptText = ""
    @State private var pillState: PillState = .input
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        ZStack {
            appearance.screenBackgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                aiPill
                    .padding(.horizontal, 28)
                    .animation(.smooth(duration: 0.32), value: pillState)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.smooth(duration: 0.28)) {
                        isPresented = false
                    }
                } label: {
                    Text("✕")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.2, blue: 0.2))
                        .frame(width: 56, height: 56)
                        .background {
                            Circle()
                                .fill(Color(red: 0.55, green: 0.08, blue: 0.08).opacity(0.85))
                        }
                        .overlay {
                            Circle()
                                .stroke(Color(red: 1.0, green: 0.25, blue: 0.25).opacity(0.7), lineWidth: 1.2)
                        }
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if case .input = pillState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isPromptFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var aiPill: some View {
        switch pillState {
        case .input:
            TextField(
                "",
                text: $promptText,
                prompt: Text("Zapytaj AI…".l10n).foregroundStyle(appearance.promptText)
            )
            .focused($isPromptFocused)
            .font(.body.weight(.medium))
            .foregroundStyle(appearance.primaryText)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .submitLabel(.send)
            .onSubmit {
                Task { await askAI() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 420)
            .besortedGlass(appearance, interactive: true, tint: appearance.tileTint.opacity(0.85), in: .capsule)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))

        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(appearance.primaryText)
                .scaleEffect(1.15)
                .frame(maxWidth: 420)
                .frame(minHeight: 56)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .besortedGlass(appearance, interactive: false, tint: appearance.tileTint.opacity(0.85), in: .capsule)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

        case .answer(let text):
            ScrollView {
                AIFormattedResultText(
                    text: text,
                    primary: appearance.primaryText,
                    secondary: appearance.secondaryText
                )
            }
            .frame(maxWidth: 420, maxHeight: 280, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .besortedGlass(appearance, interactive: true, tint: appearance.tileTint.opacity(0.85), in: .rect(cornerRadius: 28), role: .content)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture {
                withAnimation(.smooth(duration: 0.32)) {
                    promptText = ""
                    pillState = .input
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) {
                    isPromptFocused = true
                }
            }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private func askAI() async {
        let question = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isPromptFocused = false
        withAnimation(.smooth(duration: 0.28)) {
            pillState = .loading
        }

        let context = BeSortedAIService.buildContextSnapshot(from: modelContext)

        do {
            let answer = try await BeSortedAIService.answer(
                question: question,
                contextSnapshot: context
            )
            withAnimation(.smooth(duration: 0.32)) {
                pillState = .answer(answer.isEmpty ? "Nie mam odpowiedzi.".l10n : answer)
            }
        } catch {
            let message = error.localizedDescription.isEmpty
                ? "Nie udało się uzyskać odpowiedzi.".l10n
                : error.localizedDescription
            withAnimation(.smooth(duration: 0.32)) {
                pillState = .answer(message)
            }
        }
    }
}

struct SettingsTabView: View {
    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var smartChrome
    @Environment(\.modelContext) private var modelContext
    @State private var proRevealProgress: CGFloat = 1
    @State private var proRevealGlow: Double = 0
    @State private var showResetConfirm = false
    @State private var headerSolidProgress: CGFloat = 0
    @State private var showLanguagePicker = false
    @State private var showAppearance = false
    @State private var showExtraSettings = false

    var body: some View {
        @Bindable var appearance = appearance
        let glowColor = appearance.theme.usesLightContent
            ? appearance.selectedTabTint
            : Color.white

        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    SmartScrollSensor(
                        token: smartChrome.scrollToken,
                        direction: smartChrome.scrollDirection
                    )
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)

                    SmartAssistantSettingsCard(
                        onActivate: {
                            smartChrome.presentSmartAssistantActivate()
                        }
                    )
                    .smartAssistantProReveal(
                        progress: proRevealProgress,
                        glow: proRevealGlow,
                        index: 1,
                        glowColor: glowColor
                    )

                    SynclySettingsAccountCard()
                        .smartAssistantProReveal(
                            progress: proRevealProgress,
                            glow: proRevealGlow,
                            index: 2,
                            glowColor: glowColor
                        )

                    Button {
                        withAnimation(.smooth(duration: 0.28)) {
                            showAppearance = false
                            showExtraSettings = false
                            showLanguagePicker = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Zmień język".l10n)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appearance.primaryText)
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Text(appearance.language.settingsTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(appearance.tertiaryText)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(appearance.quaternaryText)
                            }
                            .besortedNeoRaisedPill(appearance)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .background {
                            settingsRowBackground
                        }
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .smartAssistantProReveal(
                        progress: proRevealProgress,
                        glow: proRevealGlow,
                        index: 3,
                        glowColor: glowColor
                    )

                    Button {
                        withAnimation(.smooth(duration: 0.32)) {
                            showLanguagePicker = false
                            showExtraSettings = false
                            showAppearance = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Wygląd".l10n)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appearance.primaryText)
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(appearance.secondaryText)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(appearance.quaternaryText)
                            }
                            .besortedNeoRaisedPill(appearance)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .background {
                            settingsRowBackground
                        }
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .smartAssistantProReveal(
                        progress: proRevealProgress,
                        glow: proRevealGlow,
                        index: 4,
                        glowColor: glowColor
                    )

                    Button {
                        withAnimation(.smooth(duration: 0.32)) {
                            showLanguagePicker = false
                            showAppearance = false
                            showExtraSettings = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Ustawienia dodatkowe".l10n)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appearance.primaryText)
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(appearance.secondaryText)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(appearance.quaternaryText)
                            }
                            .besortedNeoRaisedPill(appearance)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .background {
                            settingsRowBackground
                        }
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .smartAssistantProReveal(
                        progress: proRevealProgress,
                        glow: proRevealGlow,
                        index: 5,
                        glowColor: glowColor
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dane".l10n)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(appearance.secondaryText)

                        Text("Usuwa wszystkie projekty i ustawienia. Modele Smart Assistant pozostają bez zmian.".l10n)
                            .font(.caption)
                            .foregroundStyle(appearance.quaternaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            showResetConfirm = true
                        } label: {
                            Text("Resetuj".l10n)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    appearance.isNeomorphic
                                        ? appearance.neoAccentRed
                                        : Color(red: 0.95, green: 0.28, blue: 0.28)
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    if appearance.isNeomorphic {
                                        // Referencja: czerwony tekst na chipie z czerwoną obwódką.
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(appearance.neoChip)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(appearance.neoAccentRed.opacity(0.2), lineWidth: 1)
                                            }
                                    }
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(BeSortedPlainButtonStyle())
                    }
                    .padding(16)
                    .background {
                        Color.clear
                            .besortedGlass(
                                appearance,
                                interactive: false,
                                tint: appearance.tileTint.opacity(0.85),
                                in: .rect(cornerRadius: 18),
                                role: .content,
                                refreshIdentity: true,
                                cushion: true
                            )
                    }
                    .smartAssistantProReveal(
                        progress: proRevealProgress,
                        glow: proRevealGlow,
                        index: 6,
                        glowColor: glowColor
                    )
                }
                .padding(.leading, BeSortedContentInsets.isLandscape ? BeSortedContentInsets.tileListHorizontal : 16)
                    .padding(.trailing, BeSortedContentInsets.isLandscape ? BeSortedContentInsets.tileListTrailing : 16)
                .padding(.top, 64)
                .padding(.bottom, 72)
            }
            .besortedListScrollChrome(horizontalContentMargin: 0)
            .trackTabHeaderSolidProgress($headerSolidProgress)
            .opacity(showAppearance || showExtraSettings ? 0 : 1)
            .allowsHitTesting(!showAppearance && !showExtraSettings && !showLanguagePicker)

            BesortedCollapsingTabTitle(
                title: "Ustawienia".l10n,
                scrollY: headerSolidProgress
            )
            .padding(.top, 12)
            .padding(.bottom, 12)
            .tabHeaderRegularLiquidGlass(appearance, scrollY: headerSolidProgress)
            .smartAssistantProReveal(
                progress: proRevealProgress,
                glow: proRevealGlow,
                index: 0,
                glowColor: glowColor
            )
            .opacity(showAppearance || showExtraSettings ? 0 : 1)
            .allowsHitTesting(!showAppearance && !showExtraSettings)
            .zIndex(5)

            if showAppearance {
                SettingsAppearanceView {
                    withAnimation(.smooth(duration: 0.32)) {
                        showAppearance = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(20)
            }

            if showExtraSettings {
                SettingsExtraSettingsView {
                    withAnimation(.smooth(duration: 0.32)) {
                        showExtraSettings = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(21)
            }

            if showLanguagePicker {
                SettingsLanguagePickerOverlay {
                    withAnimation(.smooth(duration: 0.28)) {
                        showLanguagePicker = false
                    }
                }
                .zIndex(30)
            }
        }
        .id(appearance.language)
        .onChange(of: smartChrome.smartAssistantProUnlockToken) { _, _ in
            playProUnlockReveal()
        }
        .onChange(of: appearance.planMaxTasks) { _, _ in
            CurrentPlanStore.promoteQueuedTasks(in: modelContext)
            CurrentPlanStore.persistAndSync(modelContext)
        }
        .confirmationDialog(
            "Zresetować dane?".l10n,
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Resetuj".l10n, role: .destructive) {
                resetAllDataPreservingAIModels()
            }
            Button("Anuluj".l10n, role: .cancel) {}
        } message: {
            Text("Usuwa projekty, zadania i ustawienia. Wykupione modele Smart Assistant zostają.".l10n)
        }
    }

    private func resetAllDataPreservingAIModels() {
        do {
            let projects = try modelContext.fetch(FetchDescriptor<Project>())
            for project in projects {
                modelContext.delete(project)
            }
            try deleteAll(ProjectTask.self)
            try deleteAll(ProjectBug.self)
            try deleteAll(ProjectFutureNote.self)
            try deleteAll(ProjectContextFile.self)
            try modelContext.save()
        } catch {
            try? modelContext.save()
        }

        clearAIProposalCaches()
        appearance.resetToDefaults()
        smartChrome.searchQuery = ""
        smartChrome.projectsDeleteActive = false
        smartChrome.detailDeleteActive = false
        smartChrome.deleteSelectionCount = 0
        smartChrome.blocksSmartPill = false
        smartChrome.blocksBottomChrome = false

        PhoneWatchSyncService.shared.pushSnapshotNow()
        BeSortedSound.play(.regular)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let items = try modelContext.fetch(FetchDescriptor<T>())
        for item in items {
            modelContext.delete(item)
        }
    }

    private func clearAIProposalCaches() {
        let defaults = UserDefaults.standard
        let prefix = "besorted.previousProposedTasks."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func playProUnlockReveal() {
        proRevealProgress = 0
        proRevealGlow = 1
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.72)) {
                proRevealProgress = 1
            }
            withAnimation(.easeOut(duration: 1.35).delay(0.4)) {
                proRevealGlow = 0
            }
        }
    }

    /// Tło glass wiersza w Ustawieniach — ta sama karta co sekcja „Dane".
    private var settingsRowBackground: some View {
        Color.clear
            .besortedGlass(
                appearance,
                interactive: false,
                tint: appearance.tileTint.opacity(0.85),
                in: .rect(cornerRadius: 16),
                role: .content,
                refreshIdentity: true,
                cushion: true
            )
    }
}

// MARK: - Language picker

private struct SettingsLanguagePickerOverlay: View {
    var onClose: () -> Void

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        @Bindable var appearance = appearance

        DropInModalChrome(onClose: onClose) { requestClose in
            VStack(alignment: .leading, spacing: 14) {
                Text("Język".l10n)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(appearance.primaryText)

                VStack(spacing: 10) {
                    ForEach(AppLanguage.allCases) { language in
                        let isSelected = appearance.language == language
                        Button {
                            withAnimation(.smooth(duration: 0.25)) {
                                appearance.language = language
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                requestClose()
                            }
                        } label: {
                            HStack {
                                Text(language.settingsTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(
                                        isSelected
                                            ? appearance.choiceSelectedForeground
                                            : appearance.primaryText
                                    )
                                Spacer(minLength: 0)
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(appearance.choiceSelectedForeground)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .settingsChoiceButtonStyle(isSelected: isSelected, appearance: appearance)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 360)
            .besortedGlass(
                appearance,
                interactive: false,
                tint: appearance.tileTint.opacity(0.92),
                in: .rect(cornerRadius: 22),
                role: .content
            )
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Appearance tab

private struct SettingsAppearanceView: View {
    var onBack: () -> Void

    @Environment(AppAppearance.self) private var appearance
    @State private var headerSolidProgress: CGFloat = 0

    var body: some View {
        @Bindable var appearance = appearance

        ZStack(alignment: .top) {
            appearance.screenBackgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Motyw".l10n)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(appearance.secondaryText)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(AppColorTheme.allCases) { theme in
                                let isSelected = appearance.theme == theme
                                Button {
                                    withAnimation(.smooth(duration: 0.25)) {
                                        appearance.theme = theme
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(theme.swatchColor)
                                            .frame(width: 22, height: 22)
                                            .overlay {
                                                Circle()
                                                    .stroke(appearance.primaryText.opacity(0.25), lineWidth: 1)
                                            }

                                        Text(theme.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(
                                                isSelected
                                                    ? appearance.choiceSelectedForeground
                                                    : appearance.primaryText
                                            )
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .settingsChoiceButtonStyle(isSelected: isSelected, appearance: appearance)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Styl aplikacji".l10n)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(appearance.secondaryText)

                        VStack(spacing: 10) {
                            ForEach(AppGlassStyle.allCases) { style in
                                let isSelected = appearance.glassStyle == style
                                Button {
                                    withAnimation(.smooth(duration: 0.32)) {
                                        appearance.glassStyle = style
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(style.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(
                                                isSelected
                                                    ? appearance.choiceSelectedForeground
                                                    : appearance.primaryText
                                            )
                                        Text(style.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(
                                                isSelected
                                                    ? appearance.choiceSelectedForeground.opacity(0.78)
                                                    : appearance.quaternaryText
                                            )
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .settingsChoiceButtonStyle(isSelected: isSelected, appearance: appearance)
                            }
                        }
                    }

                    if appearance.usesAnyLiquidGlass {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Liquid Glass".l10n)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(appearance.secondaryText)

                                Spacer()

                                Text(appearance.glassPercentLabel)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(appearance.primaryText)
                                    .monospacedDigit()
                            }

                            GlassFrostSlider(
                                value: $appearance.glassFrost,
                                tint: appearance.selectedTabTint,
                                tickColor: appearance.primaryText.opacity(0.35)
                            )

                            HStack {
                                Text("0% clear".l10n)
                                    .font(.caption)
                                    .foregroundStyle(appearance.quaternaryText)
                                Spacer()
                                Text("100% regular".l10n)
                                    .font(.caption)
                                    .foregroundStyle(appearance.quaternaryText)
                            }
                        }
                        .padding(16)
                        .background {
                            Color.clear
                                .besortedGlass(
                                    appearance,
                                    interactive: false,
                                    tint: appearance.tileTint.opacity(0.85),
                                    in: .rect(cornerRadius: 18),
                                    role: .content,
                                    refreshIdentity: true
                                )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.leading, BeSortedContentInsets.isLandscape ? BeSortedContentInsets.tileListHorizontal : 16)
                    .padding(.trailing, BeSortedContentInsets.isLandscape ? BeSortedContentInsets.tileListTrailing : 16)
                .padding(.top, 64)
                .padding(.bottom, 72)
            }
            .besortedListScrollChrome(horizontalContentMargin: 0)
            .trackTabHeaderSolidProgress($headerSolidProgress)

            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 36, height: 36)
                        .besortedGlass(appearance, interactive: true, in: .circle)
                        .contentShape(Circle())
                }
                .buttonStyle(BeSortedPlainButtonStyle())

                Text("Wygląd".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .tabHeaderRegularLiquidGlass(appearance, scrollY: headerSolidProgress)
            .zIndex(5)
        }
    }
}

private struct SettingsExtraSettingsView: View {
    var onBack: () -> Void

    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var smartChrome
    @State private var headerSolidProgress: CGFloat = 0

    var body: some View {
        @Bindable var appearance = appearance

        ZStack(alignment: .top) {
            appearance.screenBackgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Smart Mode".l10n)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(appearance.secondaryText)

                        Toggle(isOn: $appearance.smartMode) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Uruchom Smart Mode".l10n)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(appearance.primaryText)
                                Text("Jedna pastylka zamiast zakładek i przycisków opcji. Przesuwaj, kliknij, dwuklik AI, przytrzymaj aby przewijać.".l10n)
                                    .font(.caption)
                                    .foregroundStyle(appearance.quaternaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(appearance.selectedTabTint)
                    }
                    .padding(16)
                    .background {
                        Color.clear
                            .besortedGlass(
                                appearance,
                                interactive: false,
                                tint: appearance.tileTint.opacity(0.85),
                                in: .rect(cornerRadius: 18),
                                role: .content,
                                refreshIdentity: true
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pastylka menu".l10n)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(appearance.secondaryText)

                        Toggle(isOn: $appearance.collapsingMenuPill) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chowająca się pastylka".l10n)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(appearance.primaryText)
                                Text("Przy scrollu w dół pastylka maleje do mini bez ikon. Scroll w górę przywraca pełny rozmiar.".l10n)
                                    .font(.caption)
                                    .foregroundStyle(appearance.quaternaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(appearance.selectedTabTint)
                        .onChange(of: appearance.collapsingMenuPill) { _, enabled in
                            if !enabled {
                                smartChrome.menuPillCollapseProgress = 0
                            }
                        }
                    }
                    .padding(16)
                    .background {
                        Color.clear
                            .besortedGlass(
                                appearance,
                                interactive: false,
                                tint: appearance.tileTint.opacity(0.85),
                                in: .rect(cornerRadius: 18),
                                role: .content,
                                refreshIdentity: true
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nagłówek".l10n)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(appearance.secondaryText)

                        Toggle(isOn: $appearance.minimalistHeader) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Minimalistyczny Nagłówek".l10n)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(appearance.primaryText)
                                Text("Zamiast pełnego paska glass — pastylka za tytułem zakładki (min. 40% Liquid Glass).".l10n)
                                    .font(.caption)
                                    .foregroundStyle(appearance.quaternaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(appearance.selectedTabTint)
                    }
                    .padding(16)
                    .background {
                        Color.clear
                            .besortedGlass(
                                appearance,
                                interactive: false,
                                tint: appearance.tileTint.opacity(0.85),
                                in: .rect(cornerRadius: 18),
                                role: .content,
                                refreshIdentity: true
                            )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Aktualny Plan".l10n)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(appearance.secondaryText)
                            Spacer()
                            Text("\(appearance.planMaxTasks)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(appearance.primaryText)
                                .monospacedDigit()
                        }

                        Text("Maksymalna liczba zadań w Aktualnym Planie.".l10n)
                            .font(.caption)
                            .foregroundStyle(appearance.quaternaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 14) {
                            Button {
                                withAnimation(.smooth(duration: 0.2)) {
                                    appearance.planMaxTasks = max(
                                        CurrentPlanStore.minActiveTasksLimit,
                                        appearance.planMaxTasks - 1
                                    )
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(appearance.primaryText)
                                    .frame(width: 40, height: 40)
                                    .besortedGlass(appearance, interactive: true, in: .capsule)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(BeSortedPlainButtonStyle())
                            .disabled(appearance.planMaxTasks <= CurrentPlanStore.minActiveTasksLimit)

                            Slider(
                                value: Binding(
                                    get: { Double(appearance.planMaxTasks) },
                                    set: { appearance.planMaxTasks = Int($0.rounded()) }
                                ),
                                in: Double(CurrentPlanStore.minActiveTasksLimit)...Double(CurrentPlanStore.maxActiveTasksLimit),
                                step: 1
                            )
                            .tint(appearance.selectedTabTint)

                            Button {
                                withAnimation(.smooth(duration: 0.2)) {
                                    appearance.planMaxTasks = min(
                                        CurrentPlanStore.maxActiveTasksLimit,
                                        appearance.planMaxTasks + 1
                                    )
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(appearance.primaryText)
                                    .frame(width: 40, height: 40)
                                    .besortedGlass(appearance, interactive: true, in: .capsule)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(BeSortedPlainButtonStyle())
                            .disabled(appearance.planMaxTasks >= CurrentPlanStore.maxActiveTasksLimit)
                        }

                        HStack {
                            Text("1")
                                .font(.caption)
                                .foregroundStyle(appearance.quaternaryText)
                            Spacer()
                            Text("10")
                                .font(.caption)
                                .foregroundStyle(appearance.quaternaryText)
                        }
                    }
                    .padding(16)
                    .background {
                        Color.clear
                            .besortedGlass(
                                appearance,
                                interactive: false,
                                tint: appearance.tileTint.opacity(0.85),
                                in: .rect(cornerRadius: 18),
                                role: .content,
                                refreshIdentity: true
                            )
                    }
                }
                .padding(.leading, BeSortedContentInsets.isLandscape ? BeSortedContentInsets.tileListHorizontal : 16)
                    .padding(.trailing, BeSortedContentInsets.isLandscape ? BeSortedContentInsets.tileListTrailing : 16)
                .padding(.top, 64)
                .padding(.bottom, 72)
            }
            .besortedListScrollChrome(horizontalContentMargin: 0)
            .trackTabHeaderSolidProgress($headerSolidProgress)

            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 36, height: 36)
                        .besortedGlass(appearance, interactive: true, in: .circle)
                        .contentShape(Circle())
                }
                .buttonStyle(BeSortedPlainButtonStyle())

                Text("Ustawienia dodatkowe".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .tabHeaderRegularLiquidGlass(appearance, scrollY: headerSolidProgress)
            .zIndex(5)
        }
    }
}

struct ProjectsTabView: View {
    @Binding var selectedProject: Project?

    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var smartChrome
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]

    @State private var showAddProject = false
    /// Typ ostatnio dodanego projektu — potwierdzenie „Dodano do listy”.
    @State private var addedConfirmationKind: ProjectKind?
    @State private var addedConfirmationOpacity: Double = 0
    @State private var addedConfirmationToken: UUID?
    @State private var isMoreExpanded = false
    @State private var searchText = ""
    @State private var actionsProjectID: PersistentIdentifier?
    @State private var suppressNextProjectTap = false
    @State private var sortMode: ProjectSortMode = .dateAdded
    @State private var showSortOptions = false
    @State private var isDeleteMode = false
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var flyingAwayIDs: Set<PersistentIdentifier> = []
    @FocusState private var isSearchFocused: Bool

    @State private var showProjectsAIMenu = false
    @State private var isProjectAIPickMode = false
    @State private var projectAIStatusMessage: String?
    @State private var flickeringProjectID: PersistentIdentifier?
    @State private var flickerOn = false
    @State private var summaryProject: Project?
    @State private var summaryBody: String?
    @State private var analyzingProject: Project?
    @State private var summarizeToken = UUID()
    @State private var isSummarizeReading = false
    @State private var summarizeReadingLineIndex = 0
    @State private var summarizeReadingLetterCount = 0
    @State private var forgottenProposal: SmartAssistantLocalRuntime.ForgottenProjectSuggestion?
    @State private var isFindingForgottenProject = false
    /// Faza 1: tytuł + przyciski headera unoszą się w górę.
    @State private var searchHeaderLifted = false
    /// Faza 2: pastylka wyszukiwania rozszerza się na środku.
    @State private var searchPillExpanded = false
    /// 0 = header 2D, 1 = przezroczysty glass przy scrollu (jak Plan / Ustawienia).
    @State private var headerSolidProgress: CGFloat = 0

    private var filteredProjects: [Project] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [Project]
        if query.isEmpty {
            base = projects
        } else {
            base = projects.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.details.localizedCaseInsensitiveContains(query)
                    || $0.kind.title.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortMode {
        case .dateAdded:
            return base.sorted { $0.createdAt > $1.createdAt }
        case .importance:
            return base.sorted {
                if $0.importance != $1.importance {
                    return $0.importance > $1.importance
                }
                return $0.createdAt > $1.createdAt
            }
        }
    }

    var body: some View {
        ZStack {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    projectsList
                }
            }
            .onChange(of: isDeleteMode) { _, enabled in
                if enabled {
                    showSortOptions = false
                } else {
                    selectedForDeletion.removeAll()
                    flyingAwayIDs.removeAll()
                }
            }

            if analyzingProject != nil {
                ProjectSummarizeDotsLoader()
                    .environment(appearance)
                    .zIndex(300)
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }

            if let summaryProject, let summaryBody {
                FutureNotesAIResultOverlay(
                    title: "Streszczenie projektu".l10n,
                    bodyText: summaryBody,
                    project: summaryProject,
                    onClose: {
                        withAnimation(.smooth(duration: 0.28)) {
                            self.summaryProject = nil
                            self.summaryBody = nil
                        }
                    }
                )
                .environment(appearance)
                .zIndex(310)
                .transition(.opacity)
            }

            if isFindingForgottenProject {
                ProjectSummarizeDotsLoader()
                    .environment(appearance)
                    .zIndex(300)
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }

            if let forgottenProposal {
                ForgottenProjectProposalOverlay(
                    suggestion: forgottenProposal,
                    onApprove: {
                        approveForgottenProject(forgottenProposal.project)
                    },
                    onReject: {
                        withAnimation(.smooth(duration: 0.28)) {
                            self.forgottenProposal = nil
                        }
                    }
                )
                .environment(appearance)
                .zIndex(312)
                .transition(.opacity)
            }

            if let addedConfirmationKind {
                AddedProjectConfirmation(
                    kind: addedConfirmationKind,
                    opacity: addedConfirmationOpacity
                )
                .environment(appearance)
                .zIndex(320)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Sheet na zewnątrz listy — żeby rebuildy kafelków / scrolla nie zabijały TextFieldów.
        .sheet(isPresented: $showAddProject) {
            AddProjectSheet(isPresented: $showAddProject) { draft in
                let project = Project(
                    name: draft.name,
                    details: draft.details,
                    kind: draft.kind,
                    importance: draft.importance
                )
                modelContext.insert(project)
                CurrentPlanStore.persistAndSync(modelContext)
                showAddedProjectConfirmation(draft.kind)
            }
            .presentationDetents([.fraction(0.96)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(appearance.preferredScheme)
            .environment(appearance)
        }
        .onChange(of: analyzingProject?.persistentModelID) { _, _ in
            updateProjectsChromeBlocking()
        }
        .onChange(of: summaryProject?.persistentModelID) { _, _ in
            updateProjectsChromeBlocking()
        }
        .onChange(of: forgottenProposal?.project.persistentModelID) { _, _ in
            updateProjectsChromeBlocking()
        }
        .onChange(of: isFindingForgottenProject) { _, _ in
            updateProjectsChromeBlocking()
        }
        .onDisappear {
            smartChrome.blocksSmartPill = false
            smartChrome.blocksBottomChrome = false
        }
    }

    private func updateProjectsChromeBlocking() {
        let blocking = analyzingProject != nil
            || summaryProject != nil
            || forgottenProposal != nil
            || isFindingForgottenProject
        smartChrome.blocksSmartPill = blocking
        smartChrome.blocksBottomChrome = blocking
    }

    private func showAddedProjectConfirmation(_ kind: ProjectKind) {
        let token = UUID()
        addedConfirmationToken = token
        addedConfirmationKind = kind
        addedConfirmationOpacity = 0
        Task {
            // Poczekaj, aż sheet zniknie, żeby animacja szła ponad listą.
            try? await Task.sleep(nanoseconds: 340_000_000)
            guard addedConfirmationToken == token else { return }
            withAnimation(.easeIn(duration: 0.28)) {
                addedConfirmationOpacity = 1
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard addedConfirmationToken == token else { return }
            withAnimation(.easeIn(duration: 0.5)) {
                addedConfirmationOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard addedConfirmationToken == token else { return }
            addedConfirmationKind = nil
        }
    }

    private var emptyState: some View {
        ZStack(alignment: .top) {
            Button("Dodaj projekt".l10n) {
                showAddProject = true
            }
            .font(.title3.weight(.semibold))
            .controlSize(.large)
            .besortedAdaptiveGlassButton(appearance)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)

            if !appearance.smartMode {
                projectsTabHeader(solidProgress: 0)
            } else {
                Text("Moje projekty".l10n)
                    .font(.title.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BeSortedContentInsets.tileListHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tabHeaderRegularLiquidGlass(appearance, scrollY: 0)
            }
        }
    }

    private var projectsList: some View {
        // Header = overlay poza ScrollView (soft edge nie zwęża chrome).
        // Kafelki: BesortedFixedWidthTileScroll (stały screenWidth + gutter 20).
        // Header: ten sam screenWidth + gutter 20 — pastylka menu ich nie rusza.
        ZStack(alignment: .top) {
            BesortedFixedWidthTileScroll(
                topPadding: 92,
                scrollDisabled: projects.count <= 3
            ) {
                SmartScrollSensor(
                    token: smartChrome.scrollToken,
                    direction: smartChrome.scrollDirection
                )
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)

                ForEach(filteredProjects) { project in
                    projectRow(project)
                }
            }
            .trackTabHeaderSolidProgress($headerSolidProgress)
            .allowsHitTesting(!showAddProject)
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard !isDeleteMode, !isProjectAIPickMode else { return }
                    if actionsProjectID != nil {
                        withAnimation(.smooth(duration: 0.2)) {
                            actionsProjectID = nil
                        }
                    }
                    if showProjectsAIMenu {
                        withAnimation(.smooth(duration: 0.2)) {
                            showProjectsAIMenu = false
                        }
                    }
                    if showSortOptions {
                        withAnimation(.smooth(duration: 0.2)) {
                            showSortOptions = false
                        }
                    }
                }
            )

            VStack(spacing: 0) {
                projectsTabHeader(solidProgress: headerSolidProgress)

                if let projectAIStatusMessage {
                    Button {
                        withAnimation(.smooth(duration: 0.25)) {
                            isProjectAIPickMode = false
                            self.projectAIStatusMessage = nil
                        }
                    } label: {
                        Text(projectAIStatusMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(appearance.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .besortedGlass(
                        appearance,
                        interactive: true,
                        tint: appearance.tileTint.opacity(0.9),
                        in: .capsule
                    )
                    .padding(.horizontal, BeSortedContentInsets.tileListHorizontal)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
            // Ta sama stała szerokość co kafelki — soft edge nie ściąga headera.
            .frame(width: BeSortedContentInsets.screenWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Pełnoekranowy dismiss: wyszukiwanie ORAZ otwarte „…” (§ more / sort / AI),
            // żeby kliknięcie gdziekolwiek zamykało menu. Menu AI/sort są wyżej (zIndex) — nadal klikalne.
            let tapDismissActive = !appearance.smartMode
                && (smartChrome.isProjectsSearchExpanded
                    || (isMoreExpanded && !isDeleteMode)
                    || showSortOptions
                    || showProjectsAIMenu)
            if tapDismissActive
                && !isDeleteMode
                && !showAddProject
            {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
                    .padding(.top, 72)
                    .onTapGesture {
                        collapseSearch()
                        collapseMore()
                        withAnimation(.smooth(duration: 0.2)) {
                            showSortOptions = false
                            showProjectsAIMenu = false
                        }
                    }
                    .zIndex(15)
            }

            if showProjectsAIMenu && !appearance.smartMode {
                HStack {
                    Spacer(minLength: 0)
                    projectsAIMenu
                }
                .padding(.trailing, 16)
                .padding(.top, 58)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                .zIndex(26)
            }

            if showSortOptions && !appearance.smartMode {
                HStack {
                    Spacer(minLength: 0)
                    projectSortMenu
                }
                .padding(.trailing, 16)
                .padding(.top, 58)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                .zIndex(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.28), value: showSortOptions)
        .animation(.smooth(duration: 0.28), value: showProjectsAIMenu)
        .onChange(of: smartChrome.searchQuery) { _, query in
            searchText = query
        }
        .onChange(of: searchText) { _, query in
            if smartChrome.searchQuery != query {
                smartChrome.searchQuery = query
            }
        }
        .onChange(of: selectedForDeletion) { _, selection in
            smartChrome.deleteSelectionCount = selection.count
        }
        .onChange(of: smartChrome.projectsDeleteActive) { _, active in
            if active {
                collapseSearch()
                withAnimation(.smooth(duration: 0.28)) {
                    showSortOptions = false
                    isDeleteMode = true
                    isMoreExpanded = true
                    actionsProjectID = nil
                    isProjectAIPickMode = false
                    projectAIStatusMessage = nil
                }
            } else if isDeleteMode {
                withAnimation(.smooth(duration: 0.28)) {
                    exitDeleteMode()
                }
            }
        }
        .onChange(of: smartChrome.projectsSortDateToken) { _, _ in
            withAnimation(.smooth(duration: 0.25)) {
                sortMode = .dateAdded
                showSortOptions = false
            }
        }
        .onChange(of: smartChrome.projectsSortImportanceToken) { _, _ in
            withAnimation(.smooth(duration: 0.25)) {
                sortMode = .importance
                showSortOptions = false
            }
        }
        .onChange(of: smartChrome.projectsConfirmDeleteToken) { _, _ in
            confirmBulkDelete()
        }
        .onChange(of: smartChrome.projectsAddToken) { _, _ in
            collapseSearch()
            collapseMore()
            if smartChrome.projectsDeleteActive {
                smartChrome.cancelProjectsDelete()
            } else {
                exitDeleteMode()
            }
            showAddProject = true
        }
        .onChange(of: smartChrome.projectsAIAnalyzeToken) { _, _ in
            collapseSearch()
            collapseMore()
            withAnimation(.smooth(duration: 0.2)) {
                showProjectsAIMenu = false
            }
            if smartChrome.projectsDeleteActive {
                smartChrome.cancelProjectsDelete()
            } else {
                exitDeleteMode()
            }
            beginSummarizeProjectPickMode()
        }
        .onChange(of: smartChrome.projectsForgottenToken) { _, _ in
            collapseSearch()
            collapseMore()
            withAnimation(.smooth(duration: 0.2)) {
                showProjectsAIMenu = false
            }
            if smartChrome.projectsDeleteActive {
                smartChrome.cancelProjectsDelete()
            } else {
                exitDeleteMode()
            }
            Task { await findForgottenProject() }
        }
        .onChange(of: smartChrome.isProjectsSearchExpanded) { _, expanded in
            if expanded {
                collapseMore()
                exitDeleteMode()
                withAnimation(.smooth(duration: 0.2)) {
                    showProjectsAIMenu = false
                    showSortOptions = false
                }
                // Faza 1 — header w górę.
                withAnimation(.smooth(duration: 0.34)) {
                    searchHeaderLifted = true
                    searchPillExpanded = false
                }
                // Faza 2 — pastylka na środku.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    guard smartChrome.isProjectsSearchExpanded else { return }
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                        searchPillExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        guard smartChrome.isProjectsSearchExpanded else { return }
                        isSearchFocused = true
                    }
                }
            } else {
                isSearchFocused = false
                // Najpierw zwiń pastylkę, potem wróć header.
                withAnimation(.smooth(duration: 0.26)) {
                    searchPillExpanded = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.smooth(duration: 0.34)) {
                        searchHeaderLifted = false
                    }
                }
            }
        }
        .onAppear {
            smartChrome.deleteSelectionCount = selectedForDeletion.count
            if smartChrome.projectsDeleteActive != isDeleteMode {
                smartChrome.projectsDeleteActive = isDeleteMode
            }
        }
        .onDisappear {
            isSearchFocused = false
        }
    }

    private func beginSummarizeProjectPickMode() {
        guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
            .summarizeProject,
            chrome: smartChrome
        ) else { return }
        guard !projects.isEmpty else {
            withAnimation(.smooth(duration: 0.25)) {
                projectAIStatusMessage = "Brak projektów do analizy.".l10n
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.smooth(duration: 0.25)) {
                    if projectAIStatusMessage == "Brak projektów do analizy.".l10n {
                        projectAIStatusMessage = nil
                    }
                }
            }
            return
        }
        withAnimation(.smooth(duration: 0.28)) {
            isProjectAIPickMode = true
            projectAIStatusMessage = "Wybierz projekt do streszczenia".l10n
            actionsProjectID = nil
            showProjectsAIMenu = false
        }
    }

    /// Wybór projektu do streszczenia — krótkie mignięcie, potem czytanie + loader.
    private func startSmartModeSummarize(_ project: Project) {
        let id = project.persistentModelID

        withAnimation(.smooth(duration: 0.22)) {
            isProjectAIPickMode = false
            projectAIStatusMessage = nil
            actionsProjectID = nil
        }

        flickeringProjectID = id
        flickerOn = false
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
            flickerOn = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.smooth(duration: 0.2)) {
                flickeringProjectID = nil
                flickerOn = false
            }
            beginProjectSummarize(project)
        }
    }

    private func beginProjectSummarize(_ project: Project) {
        guard analyzingProject == nil else { return }
        let token = UUID()
        summarizeToken = token
        summarizeReadingLineIndex = 0
        summarizeReadingLetterCount = 0
        isSummarizeReading = false

        withAnimation(.smooth(duration: 0.28)) {
            analyzingProject = project
        }

        Task { @MainActor in
            await runProjectSummarizeFlow(project, token: token)
        }
    }

    @MainActor
    private func runProjectSummarizeFlow(_ project: Project, token: UUID) async {
        async let summaryTask: String = fetchProjectSummarizeText(project)
        await playProjectSummarizeReading(project, token: token)
        guard summarizeToken == token else { return }

        let body = await summaryTask
        guard summarizeToken == token else { return }

        withAnimation(.smooth(duration: 0.22)) {
            analyzingProject = nil
            isSummarizeReading = false
            summarizeReadingLetterCount = 0
        }

        withAnimation(.smooth(duration: 0.3)) {
            summaryBody = body
            summaryProject = project
        }
    }

    @MainActor
    private func fetchProjectSummarizeText(_ project: Project) async -> String {
        do {
            return try await BeSortedAIService.summarizeProject(project)
        } catch {
            return BeSortedAIService.makeLocalProjectSummary(for: project)
        }
    }

    @MainActor
    private func playProjectSummarizeReading(_ project: Project, token: UUID) async {
        let details = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !details.isEmpty else { return }

        let lines = details.components(separatedBy: .newlines)
        let visibleDetailsCharBudget = 150
        let totalLetters = max(lines.reduce(0) { $0 + $1.count }, 1)
        let targetDuration = min(2.4, max(0.7, Double(totalLetters) * 0.022))
        let letterDelay = UInt64((targetDuration / Double(totalLetters)) * 1_000_000_000)

        isSummarizeReading = true
        summarizeReadingLineIndex = 0
        summarizeReadingLetterCount = 0

        var globalCharIndex = 0
        var stoppedUpdatingVisual = false

        for (lineIndex, line) in lines.enumerated() {
            guard summarizeToken == token else { return }
            summarizeReadingLineIndex = lineIndex
            summarizeReadingLetterCount = 0
            guard !line.isEmpty else { continue }

            for letters in 1...line.count {
                guard summarizeToken == token else { return }
                globalCharIndex += 1

                if !stoppedUpdatingVisual {
                    if globalCharIndex <= visibleDetailsCharBudget {
                        withAnimation(.easeInOut(duration: 0.06)) {
                            summarizeReadingLetterCount = letters
                        }
                        if letters % 2 == 1 {
                            BeSortedSound.play(.aiRead)
                        }
                    } else {
                        stoppedUpdatingVisual = true
                        if letters % 2 == 1 {
                            BeSortedSound.play(.aiRead)
                        }
                    }
                } else if globalCharIndex % 3 == 0 {
                    BeSortedSound.play(.aiRead)
                }

                try? await Task.sleep(nanoseconds: max(letterDelay, 10_000_000))
            }
            globalCharIndex += 1
        }

        guard summarizeToken == token else { return }
        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.smooth(duration: 0.2)) {
            isSummarizeReading = false
        }
    }

    private func projectRow(_ project: Project) -> some View {
        let id = project.persistentModelID
        let showActions = actionsProjectID == id && !isDeleteMode && !isProjectAIPickMode
        let isMarked = selectedForDeletion.contains(id)
        let isFlying = flyingAwayIDs.contains(id)

        let isAnalyzing = analyzingProject?.persistentModelID == id
        let isReadingThisTile = isAnalyzing && isSummarizeReading

        return VStack(spacing: 8) {
            Button {
                if suppressNextProjectTap {
                    suppressNextProjectTap = false
                    return
                }
                handleProjectTileTap(project)
            } label: {
                ProjectTileView(
                    project: project,
                    isMarkedForDeletion: isMarked,
                    isBrushFlickering: flickeringProjectID == id && flickerOn,
                    aiReadingLineIndex: isReadingThisTile ? summarizeReadingLineIndex : nil,
                    aiReadingLetterCount: summarizeReadingLetterCount
                )
            }
            .buttonStyle(BeSortedPlainButtonStyle(sound: .tile))
            .offset(x: isFlying ? -BeSortedScreen.width : 0)
            .softWiggle(isActive: !isFlying && (isDeleteMode || isProjectAIPickMode))
            .opacity(isFlying ? 0 : 1)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        guard !isDeleteMode, !isProjectAIPickMode else { return }
                        suppressNextProjectTap = true
                        withAnimation(.smooth(duration: 0.25)) {
                            actionsProjectID = id
                            showProjectsAIMenu = false
                        }
                    }
            )

            if showActions {
                TileActionPills(
                    onDelete: {
                        withAnimation(.smooth(duration: 0.25)) {
                            if selectedProject?.persistentModelID == id {
                                selectedProject = nil
                            }
                            let uuid = project.syncUUID
                            modelContext.delete(project)
                            actionsProjectID = nil
                            try? modelContext.save()
                            PhoneWatchSyncService.shared.pushProjectDeleted(syncUUID: uuid)
                        }
                    },
                    onPriority: {
                        withAnimation(.smooth(duration: 0.25)) {
                            project.isPriorityHighlighted.toggle()
                            project.touch()
                            CurrentPlanStore.persistAndSync(modelContext)
                            actionsProjectID = nil
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func handleProjectTileTap(_ project: Project) {
        let id = project.persistentModelID

        if isProjectAIPickMode {
            startSmartModeSummarize(project)
            return
        }

        if isDeleteMode {
            if selectedForDeletion.contains(id) {
                selectedForDeletion.remove(id)
            } else {
                selectedForDeletion.insert(id)
            }
            smartChrome.deleteSelectionCount = selectedForDeletion.count
            return
        }

        if actionsProjectID == id {
            withAnimation(.smooth(duration: 0.2)) {
                actionsProjectID = nil
            }
        } else {
            withAnimation(.smooth(duration: 0.25)) {
                project.recordOpen()
                selectedProject = project
            }
            try? modelContext.save()
        }
    }

    /// Header „Moje projekty”: gutter 20 jak kafelki; collapsingu nie ruszamy.
    @ViewBuilder
    private func projectsTabHeader(solidProgress scrollY: CGFloat) -> some View {
        let gutter = BeSortedContentInsets.tileListHorizontal

        ZStack {
            projectsTabHeaderRestingContent(scrollY: scrollY)
                .opacity(searchHeaderLifted ? 0 : 1)
                .offset(y: searchHeaderLifted ? -36 : 0)
                .allowsHitTesting(!searchHeaderLifted)

            topSearchExpandedPill
                .padding(.horizontal, gutter)
                .scaleEffect(
                    x: searchPillExpanded ? 1 : 0.22,
                    y: searchPillExpanded ? 1 : 0.72,
                    anchor: .center
                )
                .opacity(searchPillExpanded ? 1 : 0)
                .offset(y: searchPillExpanded ? 0 : 6)
                .allowsHitTesting(searchPillExpanded)
                .accessibilityHidden(!searchPillExpanded)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(width: BeSortedContentInsets.screenWidth, alignment: .leading)
        .tabHeaderRegularLiquidGlass(appearance, scrollY: scrollY)
    }

    @ViewBuilder
    private func projectsTabHeaderRestingContent(scrollY: CGFloat) -> some View {
        let gutter = BeSortedContentInsets.tileListHorizontal

        // Jawny HStack jak na obrazku referencyjnym — padding na zewnątrz collapsingu,
        // żeby tytuł / przyciski zawsze miały gutter niezależnie od travel offsetu.
        BesortedCollapsingTabHeader(
            title: "Moje projekty".l10n,
            scrollY: scrollY,
            leadingPadding: gutter,
            trailingPadding: gutter
        ) {
            if !appearance.smartMode {
                HStack(alignment: .center, spacing: 8) {
                    expandableMoreMenu

                    Button {
                        collapseSearch()
                        collapseMore()
                        exitDeleteMode()
                        withAnimation(.smooth(duration: 0.2)) {
                            showProjectsAIMenu = false
                        }
                        showAddProject = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .besortedGlass(appearance, interactive: true, in: .capsule)

                    Button {
                        collapseSearch()
                        collapseMore()
                        exitDeleteMode()
                        withAnimation(.smooth(duration: 0.25)) {
                            showSortOptions = false
                            showProjectsAIMenu.toggle()
                            actionsProjectID = nil
                        }
                    } label: {
                        Image("SmartAiIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .opacity(showProjectsAIMenu || isProjectAIPickMode ? 1 : 0.92)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle(sound: .ai))
                    .besortedGlass(appearance, interactive: true, in: .capsule)
                }
                .fixedSize(horizontal: true, vertical: false)
                .allowsHitTesting(true)
            }
        }
        .frame(width: BeSortedContentInsets.screenWidth)
    }

    private var topSearchExpandedPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(appearance.secondaryText)

            TextField(
                "",
                text: $searchText,
                prompt: Text("Szukaj projektu".l10n).foregroundStyle(appearance.promptText)
            )
            .focused($isSearchFocused)
            .foregroundStyle(appearance.primaryText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    smartChrome.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(appearance.tertiaryText)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .besortedGlass(appearance, interactive: true, in: .capsule)
    }

    private var projectsAIMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            lockedProjectsAIMenuButton(
                title: "Streść projekt".l10n,
                systemImage: "sparkles",
                skill: .summarizeProject
            ) {
                beginSummarizeProjectPickMode()
            }

            lockedProjectsAIMenuButton(
                title: "Zapomniany projekt".l10n,
                systemImage: "clock.arrow.circlepath",
                skill: .forgottenProject
            ) {
                Task { await findForgottenProject() }
            }
        }
        .frame(width: 230)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 16),
            minimumFrost: AppAppearance.menuGlassMinimumFrost
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.2),
            radius: appearance.isFlatDesign ? 0 : 12,
            y: appearance.isFlatDesign ? 0 : 4
        )
    }

    private func lockedProjectsAIMenuButton(
        title: String,
        systemImage: String,
        skill: SmartAssistantSkill,
        action: @escaping () -> Void
    ) -> some View {
        let locked = !SmartAssistantStore.shared.supports(skill)
        let tint = locked ? appearance.quaternaryText : appearance.primaryText

        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                showProjectsAIMenu = false
            }
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                skill,
                chrome: smartChrome
            ) else { return }
            action()
        } label: {
            HStack(spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(appearance.quaternaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(BeSortedPlainButtonStyle())
    }

    @MainActor
    private func findForgottenProject() async {
        guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
            .forgottenProject,
            chrome: smartChrome
        ) else { return }

        withAnimation(.smooth(duration: 0.25)) {
            isFindingForgottenProject = true
            projectAIStatusMessage = nil
        }

        // Krótki loader — analiza jest lokalna, ale UX jak przy innych AI.
        try? await Task.sleep(nanoseconds: 550_000_000)

        do {
            let suggestion = try BeSortedAIService.suggestForgottenProject(from: Array(projects))
            withAnimation(.smooth(duration: 0.28)) {
                isFindingForgottenProject = false
                forgottenProposal = suggestion
            }
        } catch {
            withAnimation(.smooth(duration: 0.28)) {
                isFindingForgottenProject = false
                projectAIStatusMessage = error.localizedDescription
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.smooth(duration: 0.25)) {
                    if projectAIStatusMessage == error.localizedDescription {
                        projectAIStatusMessage = nil
                    }
                }
            }
        }
    }

    private func approveForgottenProject(_ project: Project) {
        withAnimation(.smooth(duration: 0.28)) {
            project.isPriorityHighlighted = true
            project.touch()
            forgottenProposal = nil
        }
        CurrentPlanStore.persistAndSync(modelContext)
        BeSortedSound.play(.regular)
    }

    private var expandableMoreMenu: some View {
        let hasSelection = !selectedForDeletion.isEmpty
        let expandedWidth: CGFloat = (isDeleteMode && hasSelection) ? 156 : 112

        return HStack(spacing: 4) {
            if isMoreExpanded {
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        showSortOptions.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            showSortOptions
                                ? appearance.selectedTabTint
                                : appearance.primaryText
                        )
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BeSortedPlainButtonStyle())

                if isDeleteMode && hasSelection {
                    Button {
                        confirmBulkDelete()
                    } label: {
                        Text("Usuń".l10n)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.25))
                            .padding(.horizontal, 10)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                } else {
                    Button {
                        withAnimation(LiquidCapsuleExpansion.spring) {
                            showSortOptions = false
                            if isDeleteMode {
                                exitDeleteMode()
                            } else {
                                isDeleteMode = true
                                isMoreExpanded = true
                                actionsProjectID = nil
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                isDeleteMode
                                    ? Color(red: 1.0, green: 0.3, blue: 0.3)
                                    : appearance.primaryText
                            )
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                }
            } else {
                Button {
                    collapseSearch()
                    withAnimation(LiquidCapsuleExpansion.spring) {
                        showSortOptions = false
                        isMoreExpanded = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            }
        }
        .contentShape(Capsule())
        .liquidGlassExpandingCapsule(
            appearance,
            isExpanded: isMoreExpanded,
            expandedWidth: expandedWidth,
            expandedPadding: 8
        )
        .zIndex(40)
    }

    private var projectSortMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    sortMode = .dateAdded
                    showSortOptions = false
                }
            } label: {
                Label("Data dodania".l10n, systemImage: sortMode == .dateAdded ? "checkmark" : "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .buttonStyle(BeSortedPlainButtonStyle())

            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    sortMode = .importance
                    showSortOptions = false
                }
            } label: {
                Label(
                    "Gwiazdki (od najwyższych)".l10n,
                    systemImage: sortMode == .importance ? "checkmark" : "star.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
        }
        .frame(width: 230)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 16),
            minimumFrost: AppAppearance.menuGlassMinimumFrost
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.2),
            radius: appearance.isFlatDesign ? 0 : 12,
            y: appearance.isFlatDesign ? 0 : 4
        )
    }

    private func collapseSearch() {
        guard smartChrome.isProjectsSearchExpanded || !searchText.isEmpty || !smartChrome.searchQuery.isEmpty else { return }
        withAnimation(.smooth(duration: 0.35)) {
            smartChrome.isProjectsSearchExpanded = false
            searchText = ""
            smartChrome.searchQuery = ""
        }
    }

    private func collapseMore() {
        guard isMoreExpanded || showSortOptions else { return }
        withAnimation(LiquidCapsuleExpansion.spring) {
            isMoreExpanded = false
            showSortOptions = false
        }
        if isDeleteMode {
            exitDeleteMode()
        }
    }

    private func exitDeleteMode() {
        withAnimation(.smooth(duration: 0.25)) {
            isDeleteMode = false
            selectedForDeletion.removeAll()
            flyingAwayIDs.removeAll()
        }
        if smartChrome.projectsDeleteActive {
            smartChrome.projectsDeleteActive = false
            smartChrome.deleteSelectionCount = 0
        }
    }

    private func confirmBulkDelete() {
        let targets = projects.filter { selectedForDeletion.contains($0.persistentModelID) }
        guard !targets.isEmpty else { return }

        withAnimation(.easeIn(duration: 0.38)) {
            flyingAwayIDs = selectedForDeletion
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            for project in targets {
                if selectedProject?.persistentModelID == project.persistentModelID {
                    selectedProject = nil
                }
                let uuid = project.syncUUID
                modelContext.delete(project)
                PhoneWatchSyncService.shared.pushProjectDeleted(syncUUID: uuid)
            }
            try? modelContext.save()
            withAnimation(.smooth(duration: 0.25)) {
                isDeleteMode = false
                selectedForDeletion.removeAll()
                flyingAwayIDs.removeAll()
                isMoreExpanded = false
            }
            smartChrome.projectsDeleteActive = false
            smartChrome.deleteSelectionCount = 0
        }
    }
}

private enum ProjectSortMode {
    case dateAdded
    case importance
}

private enum TaskSortMode {
    case dateAdded
    case importance
}

private enum AIExportFocus: Equatable {
    case none
    case contextFiles
    case projectCore
}

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Binding var selectedTab: ProjectDetailTab
    @Binding var isEditingDetails: Bool
    var onBack: () -> Void

    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var smartChrome
    @Environment(\.modelContext) private var modelContext
    @State private var showAddTask = false
    @State private var showAddBug = false
    @State private var showAddFutureNote = false
    @State private var actionsTaskID: PersistentIdentifier?
    @State private var focusedExpandTask: ProjectTask?
    @State private var suppressNextTaskTap = false
    @State private var showAIMenu = false
    @State private var showMoreMenu = false
    @State private var showTaskSortMenu = false
    @State private var taskSortMode: TaskSortMode = .dateAdded
    @State private var isTaskDeleteMode = false
    @State private var selectedTasksForDeletion: Set<PersistentIdentifier> = []
    @State private var flyingAwayTaskIDs: Set<PersistentIdentifier> = []
    @State private var showContextFiles = false
    @State private var contextFilesDismissSignal = 0
    @State private var showContextFileImporter = false
    @State private var contextFilesMessage: String?
    @State private var isExportExpanded = false
    @State private var showProjectCore = false
    @State private var headerSolidProgress: CGFloat = 0
    @State private var isAIBusy = false
    @State private var aiStatusMessage: String?
    @State private var proposedTasks: [ProposedTaskDraft]?
    @State private var descriptionSummary: String?
    @State private var futureAIResultTitle: String?
    @State private var futureAIResultBody: String?
    @State private var futureAIResultShowsProjectCard = false
    @State private var futureAIResultNearFullScreen = false
    @State private var isRevealingDetails = false
    @State private var detailsFadeOpacity: Double = 1
    @State private var detailsRevealToken = UUID()
    @State private var revealedDetailsWordCount = 0
    @State private var revealDetailsWords: [String] = []
    @State private var isAIReadingDetails = false
    @State private var aiReadingToken = UUID()
    @State private var aiReadingLineIndex = 0
    @State private var aiReadingLetterCount = 0
    /// Kaskadowa poświata AI (poza czytanym opisem): -1 = wyłączona.
    @State private var aiAmbientGlowBand = -1
    @State private var aiAmbientGlowIntensity: Double = 0
    @State private var aiAmbientToken = UUID()
    /// Animacja eksportu gdy AI czyta pliki kontekstu / rdzeń.
    @State private var aiExportFocus: AIExportFocus = .none
    @State private var aiExportForceExpanded = false
    @State private var aiExportToken = UUID()
    @State private var showDetailsEditPill = false
    @State private var detailsEditPillPoint: CGPoint = .zero
    @State private var detailsEditPillIgnoreDismissUntil: Date = .distantPast
    @State private var detailsDraft = ""
    @FocusState private var isDetailsEditorFocused: Bool

    private var sortedTasks: [ProjectTask] {
        let open = project.taskList.filter { !$0.isCompleted }
        switch taskSortMode {
        case .dateAdded:
            return open.sorted { $0.createdAt > $1.createdAt }
        case .importance:
            return open.sorted {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.createdAt > $1.createdAt
            }
        }
    }

    private var sortedFutureNotes: [ProjectFutureNote] {
        switch taskSortMode {
        case .dateAdded:
            return project.futureNoteList.sorted { $0.createdAt > $1.createdAt }
        case .importance:
            // Notatki nie mają gwiazdek — sort A→Z jak drugi tryb „jak w zadaniach”.
            return project.futureNoteList.sorted {
                let left = $0.text.localizedCaseInsensitiveCompare($1.text)
                if left != .orderedSame { return left == .orderedAscending }
                return $0.createdAt > $1.createdAt
            }
        }
    }

    private var hasFutureNotes: Bool {
        !project.futureNoteList.isEmpty
    }

    private var hasTaskDeleteSelection: Bool {
        !selectedTasksForDeletion.isEmpty
    }

    var body: some View {
        projectDetailBody
    }

    private var projectDetailBody: some View {
        projectDetailWithSheets
    }

    private var projectDetailCanvas: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack {
                    if !appearance.smartMode {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(appearance.primaryText)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(BeSortedPlainButtonStyle())
                        .besortedGlass(appearance, interactive: true, in: .capsule)
                    }

                    Spacer()

                    if appearance.smartMode {
                        if aiExportForceExpanded || aiExportFocus != .none {
                            projectExportControl
                        } else if isTaskDeleteMode {
                            EmptyView()
                        } else {
                            EmptyView()
                        }
                    } else {
                        HStack(spacing: 10) {
                            if selectedTab == .futureNote && hasFutureNotes {
                                Button {
                                    showAddFutureNote = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(appearance.primaryText)
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(BeSortedPlainButtonStyle())
                                .besortedGlass(appearance, interactive: true, in: .capsule)
                            }

                            if selectedTab == .bugs {
                                bugsDeleteControl
                            } else {
                                projectTasksMoreControl
                            }

                            projectExportControl

                            if selectedTab != .bugs {
                                Button {
                                    withAnimation(.smooth(duration: 0.25)) {
                                        showContextFiles = false
                                        showProjectCore = false
                                        isExportExpanded = false
                                        showTaskSortMenu = false
                                        if isTaskDeleteMode {
                                            exitTaskDeleteMode()
                                        }
                                        showMoreMenu = false
                                        showAIMenu.toggle()
                                        aiStatusMessage = nil
                                    }
                                } label: {
                                    Group {
                                        if isAIBusy {
                                            ProgressView()
                                                .tint(appearance.primaryText)
                                        } else {
                                            Image("SmartAiIcon")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 22, height: 22)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                }
                                .buttonStyle(BeSortedPlainButtonStyle(sound: .ai))
                                .besortedGlass(appearance, interactive: true, in: .capsule)
                                .disabled(isAIBusy)
                            }
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .tabHeaderRegularLiquidGlass(appearance, scrollY: headerSolidProgress)
            .onChange(of: isTaskDeleteMode) { _, enabled in
                if !enabled {
                    selectedTasksForDeletion.removeAll()
                    flyingAwayTaskIDs.removeAll()
                }
            }

                if isEditingDetails {
                    projectDetailsEditWorkspace
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            SmartScrollSensor(
                                token: smartChrome.scrollToken,
                                direction: smartChrome.scrollDirection
                            )
                            .frame(width: 1, height: 1)
                            .accessibilityHidden(true)

                            Text(project.name)
                                .font(.largeTitle.weight(.bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .aiThemeTextPulse(
                                    intensity: aiAmbientGlowBand == 0 ? aiAmbientGlowIntensity : 0,
                                    themeColor: appearance.aiScanAccent,
                                    fontColor: appearance.primaryText
                                )

                            Group {
                                switch selectedTab {
                                case .tasks:
                                    projectDetailsBlock

                                    if project.hasOriginalDetailsBackup
                                        && !isRevealingDetails
                                        && !isAIReadingDetails
                                    {
                                        Button("Przywróć oryginalny tekst".l10n) {
                                            Task { await restoreOriginalDetails() }
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(appearance.tertiaryText)
                                        .buttonStyle(BeSortedPlainButtonStyle())
                                    }

                                    if let aiStatusMessage {
                                        Text(aiStatusMessage)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(appearance.tertiaryText)
                                    }

                                    tasksSection

                                case .bugs:
                                    if let aiStatusMessage {
                                        Text(aiStatusMessage)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(appearance.tertiaryText)
                                    }
                                    bugsSection

                                case .futureNote:
                                    if let aiStatusMessage {
                                        Text(aiStatusMessage)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(appearance.tertiaryText)
                                    }
                                    futureNotesSection
                                }
                            }
                            .id(selectedTab)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .center)),
                                    removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .center))
                                )
                            )
                        }
                        .animation(.smooth(duration: 0.26), value: selectedTab)
                        .padding(.top, 12)
                        .padding(.bottom, 110)
                        .padding(.leading, BeSortedContentInsets.tileListHorizontal)
                        .padding(.trailing, BeSortedContentInsets.tileListTrailing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .besortedListScrollChrome()
                    .trackTabHeaderSolidProgress($headerSolidProgress)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            if showDetailsEditPill, Date() >= detailsEditPillIgnoreDismissUntil {
                                withAnimation(.smooth(duration: 0.2)) {
                                    showDetailsEditPill = false
                                }
                            }
                            if actionsTaskID != nil {
                                withAnimation(.smooth(duration: 0.2)) {
                                    actionsTaskID = nil
                                }
                            }
                            if showAIMenu {
                                withAnimation(.smooth(duration: 0.2)) {
                                    showAIMenu = false
                                }
                            }
                            if showTaskSortMenu {
                                withAnimation(.smooth(duration: 0.2)) {
                                    showTaskSortMenu = false
                                }
                            } else if showMoreMenu && !isTaskDeleteMode {
                                withAnimation(.smooth(duration: 0.25)) {
                                    showMoreMenu = false
                                }
                            }
                        }
                    )
                }
            }

            if showAIMenu {
                Group {
                    if selectedTab == .futureNote {
                        futureNotesAIMenu
                    } else {
                        projectAIMenu
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 50)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                .zIndex(20)
            }

            if showTaskSortMenu && !appearance.smartMode {
                taskSortMenu
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                    .zIndex(21)
            }

            if showContextFiles {
                ProjectContextFilesOverlay(
                    isPresented: $showContextFiles,
                    dismissSignal: contextFilesDismissSignal,
                    project: project,
                    statusMessage: contextFilesMessage,
                    onAddFiles: {
                        showContextFileImporter = true
                    },
                    onDelete: { file in
                        modelContext.delete(file)
                        project.touch()
                        CurrentPlanStore.persistAndSync(modelContext)
                    }
                )
                .environment(appearance)
                .zIndex(120)
                .transition(.identity)
            }

            if showProjectCore {
                ProjectCoreOverlay(
                    project: project,
                    onClose: {
                        withAnimation(.smooth(duration: 0.28)) {
                            showProjectCore = false
                        }
                        CurrentPlanStore.persistAndSync(modelContext)
                    }
                )
                .environment(appearance)
                .zIndex(120)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if let proposedTasks {
                ProposedTasksReviewOverlay(
                    tasks: proposedTasks,
                    onApprove: { approveProposedTasks(proposedTasks) },
                    onReject: {
                        self.proposedTasks = nil
                    }
                )
                .environment(appearance)
                .zIndex(40)
                .transition(.identity)
            }

            if let descriptionSummary {
                ProjectDescriptionSummaryOverlay(
                    summary: descriptionSummary,
                    onReplace: {
                        Task { await replaceDetailsWithSummary(descriptionSummary) }
                    },
                    onCopy: {
                        UIPasteboard.general.string = descriptionSummary
                        aiStatusMessage = "Skopiowano streszczenie.".l10n
                    },
                    onClose: {
                        self.descriptionSummary = nil
                    }
                )
                .environment(appearance)
                .zIndex(45)
                .transition(.identity)
            }

            if let title = futureAIResultTitle, let body = futureAIResultBody {
                FutureNotesAIResultOverlay(
                    title: title,
                    bodyText: body,
                    project: futureAIResultShowsProjectCard ? project : nil,
                    nearFullScreen: futureAIResultNearFullScreen,
                    onClose: {
                        futureAIResultTitle = nil
                        futureAIResultBody = nil
                        futureAIResultShowsProjectCard = false
                        futureAIResultNearFullScreen = false
                    }
                )
                .environment(appearance)
                .zIndex(200)
                .transition(.identity)
            }
        }
        .overlay {
            if let focusedExpandTask {
                TaskFocusOverlay(
                    task: focusedExpandTask,
                    mode: .projectTasks,
                    showsPlanBadge: false,
                    onClose: {
                        withAnimation(.smooth(duration: 0.3)) {
                            self.focusedExpandTask = nil
                        }
                    }
                )
                .environment(appearance)
                .transition(.opacity)
            }
        }
    }

    private var projectDetailWithChrome: some View {
        projectDetailTabSynced
        .onDisappear {
            smartChrome.blocksBottomChrome = false
            if smartChrome.detailDeleteActive {
                smartChrome.cancelDetailDelete()
            }
        }
        .animation(.smooth(duration: 0.32), value: isEditingDetails)
        .animation(.smooth(duration: 0.2), value: showDetailsEditPill)
        .onChange(of: smartChrome.projectDetailSortDateToken) { _, _ in
            withAnimation(.smooth(duration: 0.25)) {
                taskSortMode = .dateAdded
                showTaskSortMenu = false
            }
        }
        .onChange(of: smartChrome.projectDetailSortImportanceToken) { _, _ in
            withAnimation(.smooth(duration: 0.25)) {
                taskSortMode = .importance
                showTaskSortMenu = false
            }
        }
        .onChange(of: smartChrome.projectDetailContextToken) { _, _ in
            if showContextFiles {
                contextFilesDismissSignal += 1
            } else {
                showAIMenu = false
                showTaskSortMenu = false
                showProjectCore = false
                isExportExpanded = false
                if isTaskDeleteMode { exitTaskDeleteMode() }
                showMoreMenu = false
                contextFilesMessage = nil
                showContextFiles = true
            }
        }
        .onChange(of: smartChrome.projectDetailCoreToken) { _, _ in
            withAnimation(.smooth(duration: 0.28)) {
                showAIMenu = false
                showTaskSortMenu = false
                showMoreMenu = false
                showContextFiles = false
                isExportExpanded = false
                if isTaskDeleteMode { exitTaskDeleteMode() }
                showProjectCore = true
            }
        }
        .onChange(of: smartChrome.projectDetailAddNoteToken) { _, _ in
            showAddFutureNote = true
        }
        .onChange(of: selectedTasksForDeletion) { _, selection in
            if smartChrome.detailDeleteActive || isTaskDeleteMode {
                smartChrome.deleteSelectionCount = selection.count
            }
        }
        .onChange(of: smartChrome.detailDeleteActive) { _, active in
            if active {
                withAnimation(.smooth(duration: 0.28)) {
                    showAIMenu = false
                    showTaskSortMenu = false
                    showMoreMenu = appearance.smartMode ? false : true
                    isExportExpanded = false
                    isTaskDeleteMode = true
                    actionsTaskID = nil
                    selectedTasksForDeletion.removeAll()
                }
            } else if isTaskDeleteMode {
                exitTaskDeleteMode()
            }
        }
        .onChange(of: smartChrome.detailConfirmDeleteToken) { _, _ in
            confirmBulkDetailDelete()
        }
        .onChange(of: smartChrome.projectDetailAISummarizeToken) { _, _ in
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                .summarizeDescription,
                chrome: smartChrome
            ) else { return }
            Task { await summarizeDescription() }
        }
        .onChange(of: smartChrome.projectDetailAIProposeToken) { _, _ in
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                .proposeTasks,
                chrome: smartChrome
            ) else { return }
            Task { await proposeTasks() }
        }
        .onChange(of: smartChrome.projectDetailAIRemindToken) { _, _ in
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                .remindProject,
                chrome: smartChrome
            ) else { return }
            Task { await remindProjectWithAI() }
        }
        .onChange(of: smartChrome.projectDetailAIWhatNowToken) { _, _ in
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                .whatCanIDoNow,
                chrome: smartChrome
            ) else { return }
            Task { await whatCanIDoNowWithAI() }
        }
        .onChange(of: smartChrome.projectDetailAIEvaluateToken) { _, _ in
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                .evaluateProject,
                chrome: smartChrome
            ) else { return }
            Task { await evaluateProjectWithAI() }
        }
    }

    private var projectDetailTabSynced: some View {
        projectDetailCanvas
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.28), value: showAIMenu)
        .animation(.smooth(duration: 0.28), value: showTaskSortMenu)
        .animation(.smooth(duration: 0.28), value: showMoreMenu)
        .animation(nil, value: showContextFiles)
        .animation(.smooth(duration: 0.28), value: showProjectCore)
        .animation(.smooth(duration: 0.28), value: isExportExpanded)
        .animation(nil, value: proposedTasks != nil)
        .animation(nil, value: descriptionSummary != nil)
        .animation(nil, value: futureAIResultBody != nil)
        .animation(.smooth(duration: 0.3), value: focusedExpandTask?.syncUUID)
        .onChange(of: showProjectCore) { _, _ in
            syncBottomChromeBlocking()
        }
        .onChange(of: showContextFiles) { _, _ in
            syncBottomChromeBlocking()
        }
        .onChange(of: futureAIResultTitle) { _, _ in
            syncBottomChromeBlocking()
        }
        .onChange(of: proposedTasks != nil) { _, _ in
            syncBottomChromeBlocking()
        }
        .onChange(of: descriptionSummary != nil) { _, _ in
            syncBottomChromeBlocking()
        }
        .onChange(of: focusedExpandTask?.syncUUID) { _, _ in
            syncBottomChromeBlocking()
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .tasks {
                withAnimation(.smooth(duration: 0.25)) {
                    isExportExpanded = false
                    focusedExpandTask = nil
                }
            }
            withAnimation(.smooth(duration: 0.25)) {
                showMoreMenu = false
                showTaskSortMenu = false
                if tab == .bugs {
                    showAIMenu = false
                }
            }
            if isTaskDeleteMode {
                exitTaskDeleteMode()
                if smartChrome.detailDeleteActive {
                    smartChrome.cancelDetailDelete()
                }
            }
        }
    }

    private var projectDetailWithSheets: some View {
        projectDetailWithChrome
        .fileImporter(
            isPresented: $showContextFileImporter,
            allowedContentTypes: ProjectContextFileImporter.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            importContextFiles(from: result)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(isPresented: $showAddTask, projectKind: project.kind) { draft in
                let task = ProjectTask(
                    name: draft.name,
                    details: draft.details,
                    kind: draft.kind,
                    importance: draft.importance,
                    project: project
                )
                modelContext.insert(task)
                CurrentPlanStore.persistAndSync(modelContext)
                BeSortedSound.play(.taskAdd)
            }
            .presentationDetents([.fraction(0.96)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(appearance.preferredScheme)
            .environment(appearance)
        }
        .sheet(isPresented: $showAddBug) {
            AddBugSheet(isPresented: $showAddBug) { draft in
                let bug = ProjectBug(
                    title: draft.title,
                    details: draft.details,
                    severity: draft.severity,
                    project: project
                )
                modelContext.insert(bug)
                project.touch()
                CurrentPlanStore.persistAndSync(modelContext, mutatedBug: bug)
            }
            .presentationDetents([.fraction(0.92)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(appearance.preferredScheme)
            .environment(appearance)
        }
        .sheet(isPresented: $showAddFutureNote) {
            AddFutureNoteSheet(isPresented: $showAddFutureNote) { text in
                let note = ProjectFutureNote(text: text, project: project)
                modelContext.insert(note)
                project.touch()
                CurrentPlanStore.persistAndSync(modelContext)
            }
            .presentationDetents([.fraction(0.72)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(appearance.preferredScheme)
            .environment(appearance)
        }
    }

    private var projectTasksMoreControl: some View {
        let expandedWidth: CGFloat = (isTaskDeleteMode && hasTaskDeleteSelection) ? 156 : 112
        let showsSort = selectedTab == .tasks || selectedTab == .futureNote

        return HStack(spacing: 4) {
            if showMoreMenu {
                if showsSort {
                    Button {
                        withAnimation(.smooth(duration: 0.25)) {
                            showAIMenu = false
                            showTaskSortMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                showTaskSortMenu
                                    ? appearance.selectedTabTint
                                    : appearance.primaryText
                            )
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                }

                if isTaskDeleteMode && hasTaskDeleteSelection {
                    Button {
                        confirmBulkDetailDelete()
                    } label: {
                        Text("Usuń".l10n)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.25))
                            .padding(.horizontal, 10)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                } else {
                    Button {
                        withAnimation(LiquidCapsuleExpansion.spring) {
                            showTaskSortMenu = false
                            if isTaskDeleteMode {
                                exitTaskDeleteMode()
                            } else {
                                isTaskDeleteMode = true
                                showMoreMenu = true
                                actionsTaskID = nil
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isTaskDeleteMode
                                    ? Color(red: 1.0, green: 0.3, blue: 0.3)
                                    : appearance.primaryText
                            )
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                }
            } else {
                Button {
                    withAnimation(LiquidCapsuleExpansion.spring) {
                        showAIMenu = false
                        showTaskSortMenu = false
                        isExportExpanded = false
                        showMoreMenu = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            }
        }
        .contentShape(Capsule())
        .liquidGlassExpandingCapsule(
            appearance,
            isExpanded: showMoreMenu,
            expandedWidth: expandedWidth,
            expandedPadding: 6
        )
    }

    /// Błędy (bez Smart Mode): sam kosz, bez menu „…”.
    private var bugsDeleteControl: some View {
        let expanded = isTaskDeleteMode && hasTaskDeleteSelection

        return HStack(spacing: 4) {
            if expanded {
                Button {
                    confirmBulkDetailDelete()
                } label: {
                    Text("Usuń".l10n)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.25))
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            }

            Button {
                withAnimation(LiquidCapsuleExpansion.spring) {
                    showAIMenu = false
                    showTaskSortMenu = false
                    isExportExpanded = false
                    showMoreMenu = false
                    if isTaskDeleteMode {
                        exitTaskDeleteMode()
                    } else {
                        isTaskDeleteMode = true
                        actionsTaskID = nil
                    }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        isTaskDeleteMode
                            ? Color(red: 1.0, green: 0.3, blue: 0.3)
                            : appearance.primaryText
                    )
                    .frame(width: expanded ? 36 : 40, height: expanded ? 36 : 40)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
        }
        .liquidGlassExpandingCapsule(
            appearance,
            isExpanded: expanded,
            expandedWidth: 100,
            expandedPadding: 6
        )
    }

    private var projectExportControl: some View {
        let expanded = isExportExpanded || aiExportForceExpanded

        return HStack(spacing: 4) {
            if expanded {
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        isExportExpanded = false
                        showAIMenu = false
                        showTaskSortMenu = false
                        showMoreMenu = false
                        showProjectCore = false
                        if isTaskDeleteMode { exitTaskDeleteMode() }
                        if showContextFiles {
                            contextFilesDismissSignal += 1
                        } else {
                            contextFilesMessage = nil
                            showContextFiles = true
                        }
                    }
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            aiExportFocus == .contextFiles
                                ? appearance.aiScanAccent
                                : appearance.primaryText
                        )
                        .frame(width: 36, height: 36)
                        .scaleEffect(aiExportFocus == .contextFiles ? 1.2 : 1.0)
                        .shadow(
                            color: appearance.aiScanAccent.opacity(aiExportFocus == .contextFiles ? 0.45 : 0),
                            radius: aiExportFocus == .contextFiles ? 8 : 0
                        )
                        .overlay(alignment: .topTrailing) {
                            if !project.contextFileList.isEmpty {
                                Text("\(min(project.contextFileList.count, 9))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(appearance.selectedTabForeground)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(appearance.selectedTabTint, in: Capsule())
                                    .offset(x: 4, y: -2)
                            }
                        }
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .disabled(aiExportForceExpanded)
                .animation(.smooth(duration: 0.32), value: aiExportFocus)

                Button {
                    withAnimation(.smooth(duration: 0.28)) {
                        isExportExpanded = false
                        showAIMenu = false
                        showTaskSortMenu = false
                        showMoreMenu = false
                        showContextFiles = false
                        if isTaskDeleteMode { exitTaskDeleteMode() }
                        showProjectCore = true
                    }
                } label: {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            aiExportFocus == .projectCore
                                ? appearance.aiScanAccent
                                : (showProjectCore ? appearance.selectedTabTint : appearance.primaryText)
                        )
                        .frame(width: 36, height: 36)
                        .scaleEffect(aiExportFocus == .projectCore ? 1.2 : 1.0)
                        .shadow(
                            color: appearance.aiScanAccent.opacity(aiExportFocus == .projectCore ? 0.45 : 0),
                            radius: aiExportFocus == .projectCore ? 8 : 0
                        )
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .disabled(aiExportForceExpanded)
                .animation(.smooth(duration: 0.32), value: aiExportFocus)
            } else {
                Button {
                    withAnimation(LiquidCapsuleExpansion.spring) {
                        showAIMenu = false
                        showTaskSortMenu = false
                        showMoreMenu = false
                        isExportExpanded = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            }
        }
        .liquidGlassExpandingCapsule(
            appearance,
            isExpanded: expanded,
            expandedWidth: 96,
            expandedPadding: 6
        )
    }

    private var taskSortMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    taskSortMode = .dateAdded
                    showTaskSortMenu = false
                }
            } label: {
                Label("Data dodania".l10n, systemImage: taskSortMode == .dateAdded ? "checkmark" : "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .buttonStyle(BeSortedPlainButtonStyle())

            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    taskSortMode = .importance
                    showTaskSortMenu = false
                }
            } label: {
                Label(
                    "Gwiazdki (od najwyższych)".l10n,
                    systemImage: taskSortMode == .importance ? "checkmark" : "star.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
        }
        .frame(width: 230)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 16),
            minimumFrost: AppAppearance.menuGlassMinimumFrost
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.2),
            radius: appearance.isFlatDesign ? 0 : 12,
            y: appearance.isFlatDesign ? 0 : 4
        )
    }

    private func exitTaskDeleteMode() {
        withAnimation(.smooth(duration: 0.25)) {
            isTaskDeleteMode = false
            selectedTasksForDeletion.removeAll()
            flyingAwayTaskIDs.removeAll()
        }
        if smartChrome.detailDeleteActive {
            smartChrome.detailDeleteActive = false
            smartChrome.deleteSelectionCount = 0
        }
    }

    private func confirmBulkDetailDelete() {
        switch selectedTab {
        case .tasks:
            confirmBulkTaskDelete()
        case .bugs:
            confirmBulkBugDelete()
        case .futureNote:
            confirmBulkNoteDelete()
        }
    }

    private func confirmBulkTaskDelete() {
        let targets = project.taskList.filter { selectedTasksForDeletion.contains($0.persistentModelID) }
        guard !targets.isEmpty else { return }

        withAnimation(.easeIn(duration: 0.38)) {
            flyingAwayTaskIDs = selectedTasksForDeletion
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            for task in targets {
                let uuid = task.syncUUID
                modelContext.delete(task)
                PhoneWatchSyncService.shared.pushTaskDeleted(syncUUID: uuid)
            }
            CurrentPlanStore.promoteQueuedTasks(in: modelContext)
            CurrentPlanStore.persistAndSync(modelContext)
            exitTaskDeleteMode()
            withAnimation(.smooth(duration: 0.25)) {
                showMoreMenu = false
            }
        }
    }

    private func confirmBulkBugDelete() {
        let targets = project.bugList.filter { selectedTasksForDeletion.contains($0.persistentModelID) }
        guard !targets.isEmpty else { return }

        withAnimation(.easeIn(duration: 0.38)) {
            flyingAwayTaskIDs = selectedTasksForDeletion
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            for bug in targets {
                modelContext.delete(bug)
            }
            project.touch()
            CurrentPlanStore.persistAndSync(modelContext)
            exitTaskDeleteMode()
            withAnimation(.smooth(duration: 0.25)) {
                showMoreMenu = false
            }
        }
    }

    private func confirmBulkNoteDelete() {
        let targets = project.futureNoteList.filter { selectedTasksForDeletion.contains($0.persistentModelID) }
        guard !targets.isEmpty else { return }

        withAnimation(.easeIn(duration: 0.38)) {
            flyingAwayTaskIDs = selectedTasksForDeletion
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            for note in targets {
                modelContext.delete(note)
            }
            project.touch()
            CurrentPlanStore.persistAndSync(modelContext)
            exitTaskDeleteMode()
            withAnimation(.smooth(duration: 0.25)) {
                showMoreMenu = false
            }
        }
    }

    private var projectAIMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            lockedAIMenuButton(
                title: "Streść projekt".l10n,
                systemImage: "text.alignleft",
                skill: .summarizeDescription
            ) {
                Task { await summarizeDescription() }
            }

            lockedAIMenuButton(
                title: "Zaproponuj zadania".l10n,
                systemImage: "checklist",
                skill: .proposeTasks
            ) {
                Task { await proposeTasks() }
            }

            lockedAIMenuButton(
                title: SmartAssistantSkill.evaluateProject.menuTitle,
                systemImage: "eyeglasses",
                skill: .evaluateProject
            ) {
                Task { await evaluateProjectWithAI() }
            }
        }
        .frame(width: 210)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 16),
            minimumFrost: AppAppearance.menuGlassMinimumFrost
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.2),
            radius: appearance.isFlatDesign ? 0 : 12,
            y: appearance.isFlatDesign ? 0 : 4
        )
    }

    private var futureNotesAIMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            lockedAIMenuButton(
                title: "Przypomnij projekt".l10n,
                systemImage: "brain.head.profile",
                skill: .remindProject
            ) {
                Task { await remindProjectWithAI() }
            }

            lockedAIMenuButton(
                title: "Co mogę zrobić teraz".l10n,
                systemImage: "bolt.fill",
                skill: .whatCanIDoNow
            ) {
                Task { await whatCanIDoNowWithAI() }
            }
        }
        .frame(width: 230)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 16),
            minimumFrost: AppAppearance.menuGlassMinimumFrost
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.2),
            radius: appearance.isFlatDesign ? 0 : 12,
            y: appearance.isFlatDesign ? 0 : 4
        )
    }

    private func lockedAIMenuButton(
        title: String,
        systemImage: String,
        skill: SmartAssistantSkill,
        action: @escaping () -> Void
    ) -> some View {
        let locked = !SmartAssistantStore.shared.supports(skill)
        let tint = locked ? appearance.quaternaryText : appearance.primaryText

        return Button {
            showAIMenu = false
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                skill,
                chrome: smartChrome
            ) else { return }
            action()
        } label: {
            HStack(spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(appearance.quaternaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(BeSortedPlainButtonStyle())
    }

    private var projectDetailsEditWorkspace: some View {
        VStack(spacing: 14) {
            Text(project.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(appearance.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            TextEditor(text: $detailsDraft)
                .focused($isDetailsEditorFocused)
                .font(.body)
                .foregroundStyle(appearance.primaryText)
                .scrollContentBackground(.hidden)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .besortedGlass(
                    appearance,
                    interactive: true,
                    tint: appearance.tileTint.opacity(0.8),
                    in: .rect(cornerRadius: 20),
                    minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
                )
                .padding(.horizontal, 12)

            HStack {
                Spacer(minLength: 0)
                Button {
                    confirmDetailsEdit()
                } label: {
                    Text("Zatwierdź modyfikację".l10n)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                }
                .besortedAdaptiveProminentButton(
                    appearance,
                    tint: Color(red: 0.18, green: 0.48, blue: 1.0)
                )
                Spacer(minLength: 0)
            }
            .padding(.bottom, 18)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var projectDetailsBlock: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if isRevealingDetails {
                    ProjectDetailsWordRevealView(
                        words: revealDetailsWords,
                        revealedCount: revealedDetailsWordCount,
                        textColor: appearance.secondaryText
                    )
                } else if isAIReadingDetails {
                    ProjectDetailsAIReadingView(
                        text: project.details,
                        activeLineIndex: aiReadingLineIndex,
                        activeLetterCount: aiReadingLetterCount,
                        textColor: appearance.secondaryText
                    )
                    .opacity(detailsFadeOpacity)
                } else if project.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Brak opisu — kliknij dwukrotnie, aby dodać".l10n)
                        .font(.body)
                        .foregroundStyle(appearance.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    Text(project.details)
                        .font(.body)
                        .foregroundStyle(appearance.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(detailsFadeOpacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2).onEnded { event in
                    guard !isEditingDetails,
                          !isRevealingDetails,
                          !isAIReadingDetails
                    else { return }
                    withAnimation(.smooth(duration: 0.22)) {
                        detailsEditPillPoint = event.location
                        showDetailsEditPill = true
                        detailsEditPillIgnoreDismissUntil = Date().addingTimeInterval(0.4)
                        showAIMenu = false
                    }
                }
            )

            if showDetailsEditPill && !isEditingDetails {
                Button {
                    beginDetailsEdit()
                } label: {
                    Text("Edytuj".l10n)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .besortedGlass(appearance, interactive: true, in: .capsule)
                .position(
                    x: min(max(detailsEditPillPoint.x, 36), BeSortedScreen.width - 68),
                    y: max(detailsEditPillPoint.y, 18)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .zIndex(5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func beginDetailsEdit() {
        detailsDraft = project.details
        withAnimation(.smooth(duration: 0.32)) {
            showDetailsEditPill = false
            isEditingDetails = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isDetailsEditorFocused = true
        }
    }

    private func confirmDetailsEdit() {
        project.details = detailsDraft
        project.touch()
        CurrentPlanStore.persistAndSync(modelContext)
        isDetailsEditorFocused = false
        withAnimation(.smooth(duration: 0.32)) {
            isEditingDetails = false
            showDetailsEditPill = false
        }
    }

    private func summarizeDescription() async {
        isAIBusy = true
        aiStatusMessage = "AI czyta opis…".l10n
        do {
            let summaryTask = Task { @MainActor in
                try await BeSortedAIService.summarizeProjectDescription(project)
            }
            await playAIVisualSequence(tileSource: .tasks)
            let summary = try await summaryTask.value
            aiStatusMessage = nil
            withAnimation(.smooth(duration: 0.3)) {
                descriptionSummary = summary
            }
        } catch {
            cancelAIReadingAnimation()
            cancelAIAmbientGlow()
            cancelAIContextAccessAnimation()
            aiStatusMessage = error.localizedDescription
        }
        isAIBusy = false
    }

    private func proposeTasks() async {
        isAIBusy = true
        aiStatusMessage = "AI czyta projekt…".l10n
        do {
            let draftsTask = Task { @MainActor in
                try await BeSortedAIService.proposeTasks(for: project)
            }
            await playAIVisualSequence(tileSource: .tasks)
            let drafts = try await draftsTask.value
            if drafts.isEmpty {
                aiStatusMessage = "AI nie zaproponowało zadań.".l10n
            } else {
                aiStatusMessage = nil
                withAnimation(.smooth(duration: 0.3)) {
                    proposedTasks = drafts
                }
            }
        } catch {
            cancelAIReadingAnimation()
            cancelAIAmbientGlow()
            cancelAIContextAccessAnimation()
            aiStatusMessage = error.localizedDescription
        }
        isAIBusy = false
    }

    /// Ukrywa pasek zakładek / Smart Pill, gdy modal AI zasłaniałby dolny chrome.
    private func syncBottomChromeBlocking() {
        smartChrome.blocksBottomChrome =
            showProjectCore
            || showContextFiles
            || futureAIResultTitle != nil
            || proposedTasks != nil
            || descriptionSummary != nil
            || focusedExpandTask != nil
    }

    private func remindProjectWithAI() async {
        isAIBusy = true
        aiStatusMessage = "AI przypomina projekt…".l10n
        do {
            let textTask = Task { @MainActor in
                try await BeSortedAIService.remindProject(project)
            }
            await playAIVisualSequence(tileSource: .futureNotes)
            let text = try await textTask.value
            aiStatusMessage = nil
            withAnimation(.smooth(duration: 0.3)) {
                futureAIResultShowsProjectCard = true
                futureAIResultNearFullScreen = false
                futureAIResultTitle = "Przypomnienie projektu".l10n
                futureAIResultBody = text
            }
        } catch {
            cancelAIAmbientGlow()
            cancelAIContextAccessAnimation()
            aiStatusMessage = error.localizedDescription
        }
        isAIBusy = false
    }

    private func whatCanIDoNowWithAI() async {
        isAIBusy = true
        aiStatusMessage = "AI analizuje, co możesz zrobić…".l10n
        do {
            let textTask = Task { @MainActor in
                try await BeSortedAIService.whatCanIDoNow(for: project)
            }
            await playAIVisualSequence(tileSource: .futureNotes)
            let text = try await textTask.value
            aiStatusMessage = nil
            withAnimation(.smooth(duration: 0.3)) {
                futureAIResultShowsProjectCard = false
                futureAIResultNearFullScreen = false
                futureAIResultTitle = "Co mogę zrobić teraz".l10n
                futureAIResultBody = text
            }
        } catch {
            cancelAIAmbientGlow()
            cancelAIContextAccessAnimation()
            aiStatusMessage = error.localizedDescription
        }
        isAIBusy = false
    }

    private func evaluateProjectWithAI() async {
        guard project.meetsEvaluateProjectBasics else {
            withAnimation(.smooth(duration: 0.25)) {
                aiStatusMessage = project.evaluateProjectBasicsMissingMessage
            }
            return
        }

        isAIBusy = true
        aiStatusMessage = "AI ocenia projekt…".l10n
        do {
            let textTask = Task { @MainActor in
                try await BeSortedAIService.evaluateProject(project)
            }
            await playAIVisualSequence(tileSource: .tasks)
            let text = try await textTask.value
            aiStatusMessage = nil
            withAnimation(.smooth(duration: 0.3)) {
                futureAIResultShowsProjectCard = true
                futureAIResultNearFullScreen = true
                futureAIResultTitle = SmartAssistantStore.shared.activeTier == .pro
                    ? "Krytyka projektu".l10n
                    : "Luki w projekcie".l10n
                futureAIResultBody = text
            }
        } catch {
            cancelAIReadingAnimation()
            cancelAIAmbientGlow()
            cancelAIContextAccessAnimation()
            aiStatusMessage = error.localizedDescription
        }
        isAIBusy = false
    }

    private enum AITileGlowSource {
        case tasks
        case futureNotes
    }

    /// Poświata tytułu → (opcjonalnie) czytanie opisu → poświata kafli.
    /// Pastylka eksportu otwiera się po tytule (gdy AI sięga do kontekstu/rdzenia).
    private func playAIVisualSequence(tileSource: AITileGlowSource) async {
        let token = UUID()
        aiAmbientToken = token

        await pulseAIAmbientGlow(band: 0)
        guard aiAmbientToken == token else { return }

        async let exportScan: Void = playAIContextAccessAnimation()

        let hasDescription = !project.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasDescription, tileSource == .tasks {
            await playAIReadingAnimation()
            guard aiAmbientToken == token else {
                await exportScan
                return
            }
        }

        let tileCount: Int
        switch tileSource {
        case .tasks:
            tileCount = min(sortedTasks.count, 10)
        case .futureNotes:
            tileCount = min(sortedFutureNotes.count, 10)
        }

        if tileCount > 0 {
            for index in 0..<tileCount {
                guard aiAmbientToken == token else { break }
                await pulseAIAmbientGlow(band: 1 + index)
            }
        }

        if aiAmbientToken == token {
            cancelAIAmbientGlow()
        }
        await exportScan
    }

    private func replaceDetailsWithSummary(_ summary: String) async {
        let current = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty, !project.hasOriginalDetailsBackup {
            project.originalDetailsBackup = project.details
        }
        withAnimation(.smooth(duration: 0.2)) {
            descriptionSummary = nil
        }
        await revealDetailsText(
            summary,
            finalize: { project.details = summary },
            statusMessage: "Zastąpiono opis streszczeniem.".l10n
        )
    }

    private func restoreOriginalDetails() async {
        let original = project.originalDetailsBackup
        guard !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await revealDetailsText(
            original,
            finalize: {
                project.details = original
                project.originalDetailsBackup = ""
            },
            statusMessage: "Przywrócono oryginalny opis.".l10n
        )
    }

    private func revealDetailsText(
        _ text: String,
        finalize: () -> Void,
        statusMessage: String
    ) async {
        let words = Self.splitWordsPreservingNewlines(text)
        guard !words.isEmpty else {
            finalize()
            project.touch()
            CurrentPlanStore.persistAndSync(modelContext)
            aiStatusMessage = statusMessage
            return
        }

        revealDetailsWords = words
        revealedDetailsWordCount = 0
        let token = UUID()
        detailsRevealToken = token
        cancelAIReadingAnimation()

        withAnimation(.easeOut(duration: 0.28)) {
            detailsFadeOpacity = 0
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard detailsRevealToken == token else { return }

        isRevealingDetails = true
        detailsFadeOpacity = 1
        project.details = ""
        project.touch()

        for count in 1...words.count {
            guard detailsRevealToken == token else { return }
            withAnimation(.smooth(duration: 0.22)) {
                revealedDetailsWordCount = count
            }
            BeSortedSound.play(.aiRead)
            try? await Task.sleep(nanoseconds: 55_000_000)
        }

        guard detailsRevealToken == token else { return }
        finalize()
        project.touch()
        CurrentPlanStore.persistAndSync(modelContext)
        withAnimation(.smooth(duration: 0.2)) {
            isRevealingDetails = false
            revealDetailsWords = []
            revealedDetailsWordCount = 0
            aiStatusMessage = statusMessage
        }
    }

    private func playAIReadingAnimation() async {
        let text = project.details
        let lines = Self.splitLinesPreservingContent(text)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !lines.isEmpty else { return }

        let token = UUID()
        aiReadingToken = token
        isAIReadingDetails = true
        aiReadingLineIndex = 0
        aiReadingLetterCount = 0

        let totalLetters = max(lines.reduce(0) { $0 + $1.count }, 1)
        let targetDuration = min(2.8, max(0.85, Double(totalLetters) * 0.022))
        let letterDelay = UInt64((targetDuration / Double(totalLetters)) * 1_000_000_000)

        for (lineIndex, line) in lines.enumerated() {
            guard aiReadingToken == token else { return }
            aiReadingLineIndex = lineIndex
            aiReadingLetterCount = 0

            let readableCount = line.count
            guard readableCount > 0 else { continue }

            for letters in 1...readableCount {
                guard aiReadingToken == token else { return }
                withAnimation(.easeInOut(duration: 0.06)) {
                    aiReadingLetterCount = letters
                }
                if letters % 2 == 1 {
                    BeSortedSound.play(.aiRead)
                }
                try? await Task.sleep(nanoseconds: max(letterDelay, 10_000_000))
            }
        }

        guard aiReadingToken == token else { return }
        withAnimation(.smooth(duration: 0.2)) {
            isAIReadingDetails = false
            aiReadingLineIndex = 0
            aiReadingLetterCount = 0
        }
    }

    private func cancelAIReadingAnimation() {
        aiReadingToken = UUID()
        isAIReadingDetails = false
        aiReadingLineIndex = 0
        aiReadingLetterCount = 0
    }

    /// Pojedynczy impuls poświaty na wskazanym paśmie (0 = tytuł, 1… = kafle).
    private func pulseAIAmbientGlow(band: Int) async {
        let token = aiAmbientToken
        guard aiAmbientToken == token else { return }
        aiAmbientGlowBand = band
        aiAmbientGlowIntensity = 0
        await Task.yield()
        withAnimation(.easeInOut(duration: 0.32)) {
            aiAmbientGlowIntensity = 1
        }
        try? await Task.sleep(nanoseconds: 520_000_000)
        guard aiAmbientToken == token else { return }
        withAnimation(.easeInOut(duration: 0.38)) {
            aiAmbientGlowIntensity = 0
        }
        try? await Task.sleep(nanoseconds: 160_000_000)
    }

    private func cancelAIAmbientGlow() {
        aiAmbientToken = UUID()
        withAnimation(.easeOut(duration: 0.2)) {
            aiAmbientGlowIntensity = 0
            aiAmbientGlowBand = -1
        }
    }

    /// Otwiera pastylkę eksportu, podświetla źródła używane przez AI, potem zamyka.
    private func playAIContextAccessAnimation() async {
        let hasContext = !project.contextFileList.isEmpty
        let hasCore = project.supportsProjectCore && project.hasProjectCoreContent
        guard hasContext || hasCore else { return }

        let token = UUID()
        aiExportToken = token
        let wasExpanded = isExportExpanded

        withAnimation(.smooth(duration: 0.36)) {
            aiExportForceExpanded = true
            isExportExpanded = true
        }
        try? await Task.sleep(nanoseconds: 360_000_000)

        if hasContext {
            guard aiExportToken == token else { return }
            withAnimation(.smooth(duration: 0.34)) {
                aiExportFocus = .contextFiles
            }
            try? await Task.sleep(nanoseconds: 780_000_000)
            guard aiExportToken == token else { return }
            withAnimation(.smooth(duration: 0.34)) {
                aiExportFocus = .none
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        if hasCore {
            guard aiExportToken == token else { return }
            withAnimation(.smooth(duration: 0.34)) {
                aiExportFocus = .projectCore
            }
            try? await Task.sleep(nanoseconds: 780_000_000)
            guard aiExportToken == token else { return }
            withAnimation(.smooth(duration: 0.34)) {
                aiExportFocus = .none
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
        }

        guard aiExportToken == token else { return }
        withAnimation(.smooth(duration: 0.36)) {
            aiExportFocus = .none
            aiExportForceExpanded = false
            if !wasExpanded {
                isExportExpanded = false
            }
        }
    }

    private func cancelAIContextAccessAnimation() {
        aiExportToken = UUID()
        withAnimation(.smooth(duration: 0.25)) {
            aiExportFocus = .none
            aiExportForceExpanded = false
            isExportExpanded = false
        }
    }

    private static func splitWordsPreservingNewlines(_ text: String) -> [String] {
        var words: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .localized]) { substring, _, _, _ in
            if let substring {
                words.append(substring)
            }
        }
        if words.isEmpty {
            return text
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
        }
        return words
    }

    private static func splitLinesPreservingContent(_ text: String) -> [String] {
        if text.isEmpty { return [] }
        return text.components(separatedBy: .newlines)
    }

    private func approveProposedTasks(_ drafts: [ProposedTaskDraft]) {
        Task { @MainActor in
            for draft in drafts {
                let task = ProjectTask(
                    name: draft.name,
                    details: draft.details,
                    kind: draft.kind,
                    importance: draft.importance,
                    project: project
                )
                modelContext.insert(task)
                BeSortedSound.play(.taskAdd)
                try? await Task.sleep(nanoseconds: 90_000_000)
            }
            CurrentPlanStore.persistAndSync(modelContext)
            withAnimation(.smooth(duration: 0.28)) {
                proposedTasks = nil
                selectedTab = .tasks
                aiStatusMessage = "Dodano \(drafts.count) zadań."
            }
        }
    }

    private func importContextFiles(from result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            contextFilesMessage = error.localizedDescription
        case .success(let urls):
            var added = 0
            var lastError: String?
            for url in urls {
                if project.contextFileList.count >= ProjectContextFileImporter.maxFilesPerProject {
                    lastError = ProjectContextFileImporter.ImportError.limitReached.localizedDescription
                    break
                }
                do {
                    let extracted = try ProjectContextFileImporter.extractText(from: url)
                    let file = ProjectContextFile(
                        fileName: extracted.fileName,
                        contentText: extracted.text,
                        byteSize: extracted.byteSize,
                        project: project
                    )
                    modelContext.insert(file)
                    added += 1
                } catch {
                    lastError = error.localizedDescription
                }
            }
            if added > 0 {
                project.touch()
                CurrentPlanStore.persistAndSync(modelContext)
                contextFilesMessage = added == 1
                    ? "Dodano 1 plik kontekstowy.".l10n
                    : "Dodano \(added) pliki kontekstowe."
            } else if let lastError {
                contextFilesMessage = lastError
            }
        }
    }

    private var tasksSection: some View {
        VStack(spacing: 16) {
            Button("Dodaj zadanie".l10n) {
                showAddTask = true
            }
            .font(.title3.weight(.semibold))
            .controlSize(.large)
            .besortedAdaptiveGlassButton(appearance)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)

            LazyVStack(spacing: appearance.isNeomorphic ? 18 : 12) {
                ForEach(sortedTasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    private func taskRow(_ task: ProjectTask) -> some View {
        let id = task.persistentModelID
        let isMarked = selectedTasksForDeletion.contains(id)
        let isFlying = flyingAwayTaskIDs.contains(id)
        let isFocused = focusedExpandTask?.persistentModelID == id

        return TaskTileView(task: task, isMarkedForDeletion: isMarked)
            .aiAmbientGlow(
                intensity: {
                    let band = 1 + (sortedTasks.firstIndex(where: { $0.persistentModelID == id }) ?? 0)
                    return aiAmbientGlowBand == band ? aiAmbientGlowIntensity : 0
                }(),
                tint: appearance.aiTileGlowTint
            )
            .offset(x: isFlying ? -BeSortedScreen.width : 0)
            .softWiggle(isActive: !isFlying && isTaskDeleteMode)
            .opacity(isFlying ? 0 : (isFocused ? 0.15 : 1))
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    if suppressNextTaskTap {
                        suppressNextTaskTap = false
                        return
                    }
                    BeSortedSound.play(.tile)

                    if isTaskDeleteMode {
                        if selectedTasksForDeletion.contains(id) {
                            selectedTasksForDeletion.remove(id)
                        } else {
                            selectedTasksForDeletion.insert(id)
                        }
                        return
                    }

                    withAnimation(.smooth(duration: 0.35)) {
                        actionsTaskID = nil
                        showAIMenu = false
                        showMoreMenu = false
                        showTaskSortMenu = false
                        if focusedExpandTask?.persistentModelID == id {
                            focusedExpandTask = nil
                        } else {
                            focusedExpandTask = task
                        }
                    }
                }
            )
    }

    private var sortedBugs: [ProjectBug] {
        project.bugList.sorted { $0.createdAt > $1.createdAt }
    }

    private var bugsSection: some View {
        Group {
            if sortedBugs.isEmpty {
                VStack(spacing: 16) {
                    placeholderSection(
                        title: "Brak błędów".l10n,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    Button("Dodaj błąd".l10n) {
                        showAddBug = true
                    }
                    .font(.title3.weight(.semibold))
                    .controlSize(.large)
                    .besortedAdaptiveGlassButton(appearance)
                }
            } else {
                VStack(spacing: 16) {
                    Button("Dodaj błąd".l10n) {
                        showAddBug = true
                    }
                    .font(.title3.weight(.semibold))
                    .controlSize(.large)
                    .besortedAdaptiveGlassButton(appearance)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)

                    LazyVStack(spacing: appearance.isNeomorphic ? 18 : 12) {
                        ForEach(sortedBugs) { bug in
                            bugRow(bug)
                        }
                    }
                }
            }
        }
    }

    private func bugRow(_ bug: ProjectBug) -> some View {
        let id = bug.persistentModelID
        let isMarked = selectedTasksForDeletion.contains(id)
        let isFlying = flyingAwayTaskIDs.contains(id)

        return BugTileView(bug: bug, isMarkedForDeletion: isMarked)
            .offset(x: isFlying ? -BeSortedScreen.width : 0)
            .softWiggle(isActive: !isFlying && isTaskDeleteMode)
            .opacity(isFlying ? 0 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isTaskDeleteMode else { return }
                BeSortedSound.play(.tile)
                if selectedTasksForDeletion.contains(id) {
                    selectedTasksForDeletion.remove(id)
                } else {
                    selectedTasksForDeletion.insert(id)
                }
            }
    }

    private var futureNotesSection: some View {
        Group {
            if !hasFutureNotes {
                VStack {
                    Spacer(minLength: 48)
                    Button("Dodaj notatkę".l10n) {
                        showAddFutureNote = true
                    }
                    .font(.title3.weight(.semibold))
                    .controlSize(.large)
                    .besortedAdaptiveGlassButton(appearance)
                    Spacer(minLength: 48)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                LazyVStack(spacing: appearance.isNeomorphic ? 18 : 12) {
                    ForEach(sortedFutureNotes) { note in
                        futureNoteRow(note)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private func futureNoteRow(_ note: ProjectFutureNote) -> some View {
        let id = note.persistentModelID
        let isMarked = selectedTasksForDeletion.contains(id)
        let isFlying = flyingAwayTaskIDs.contains(id)

        return FutureNoteTileView(
            note: note,
            isMarkedForDeletion: isMarked,
            showsInlineDelete: !isTaskDeleteMode
        ) {
            modelContext.delete(note)
            project.touch()
            CurrentPlanStore.persistAndSync(modelContext)
        }
        .aiAmbientGlow(
            intensity: {
                let band = 1 + (sortedFutureNotes.firstIndex(where: { $0.persistentModelID == id }) ?? 0)
                return aiAmbientGlowBand == band ? aiAmbientGlowIntensity : 0
            }(),
            tint: appearance.aiTileGlowTint
        )
        .offset(x: isFlying ? -BeSortedScreen.width : 0)
        .softWiggle(isActive: !isFlying && isTaskDeleteMode)
        .opacity(isFlying ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isTaskDeleteMode else { return }
            BeSortedSound.play(.tile)
            if selectedTasksForDeletion.contains(id) {
                selectedTasksForDeletion.remove(id)
            } else {
                selectedTasksForDeletion.insert(id)
            }
        }
    }

    private func placeholderSection(title: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(appearance.quaternaryText)
            Text(title)
                .font(.headline)
                .foregroundStyle(appearance.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

/// Ilustracja typu projektu w kafelku „Moje Projekty”.
extension ProjectKind {
    var tileImageName: String {
        switch self {
        case .game: "GameICO"
        case .story: "StoryICO"
        case .drawing: "DrawICO"
        case .app: "AppICO"
        case .school: "SchoolICO"
        }
    }
}

struct ProjectTileView: View {
    let project: Project
    var isMarkedForDeletion: Bool = false
    var isBrushFlickering: Bool = false
    var aiReadingLineIndex: Int? = nil
    var aiReadingLetterCount: Int = 0

    @Environment(AppAppearance.self) private var appearance

    private var isPriorityLook: Bool {
        // Tint glass zostaje stały przy zaznaczaniu — tylko tekst wraca do normalnego przy mark.
        project.isPriorityHighlighted
    }

    private var isAIReadingDetails: Bool {
        aiReadingLineIndex != nil
            && !project.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tileTint: Color {
        // Stały tint glass — czerwone zaznaczenie idzie przez overlay (bez białego flasha).
        return isPriorityLook
            ? Color.white.opacity(0.96)
            : appearance.tileTint.opacity(0.85)
    }

    private var titleColor: Color {
        isPriorityLook && !isMarkedForDeletion ? .black : appearance.primaryText
    }

    private var secondaryColor: Color {
        isPriorityLook && !isMarkedForDeletion ? Color.black.opacity(0.62) : appearance.secondaryText
    }

    private var tertiaryColor: Color {
        isPriorityLook && !isMarkedForDeletion ? Color.black.opacity(0.45) : appearance.tertiaryText
    }

    private var emptyStarColor: Color {
        isPriorityLook && !isMarkedForDeletion ? Color.black.opacity(0.22) : appearance.starEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(project.kind.tileImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= project.importance ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(star <= project.importance ? Color.yellow : emptyStarColor)
                    }
                }
            }

            Text(project.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(2)

            if !project.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if isAIReadingDetails, let lineIndex = aiReadingLineIndex {
                    ProjectDetailsAIReadingView(
                        text: project.details,
                        activeLineIndex: lineIndex,
                        activeLetterCount: aiReadingLetterCount,
                        textColor: secondaryColor,
                        font: .subheadline,
                        boldFont: .subheadline.weight(.black),
                        lineLimit: 3
                    )
                } else {
                    Text(project.details)
                        .font(.subheadline)
                        .foregroundStyle(secondaryColor)
                        .lineLimit(3)
                }
            }

            Text(project.kind.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tertiaryColor)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .besortedGlass(
            appearance,
            tint: isBrushFlickering ? tileTint.opacity(0.35) : tileTint,
            in: .rect(cornerRadius: 18),
            role: .listTile
        )
        .besortedDeletionMark(isMarkedForDeletion)
        .opacity(isBrushFlickering ? 0.55 : 1)
        .animation(.smooth(duration: 0.28), value: project.isPriorityHighlighted)
        .animation(.easeInOut(duration: 0.45), value: isBrushFlickering)
    }
}

struct TaskTileView: View {
    let task: ProjectTask
    var showsPlanBadge: Bool = false
    var isMarkedForDeletion: Bool = false
    /// Pełny opis bez limitu linii (rozwinięty kafelek na środku).
    var showsFullDetails: Bool = false
    /// W focus overlay — wymuś Liquid Glass (full), zamiast płaskiego wyglądu.
    var usesFocusLiquidGlass: Bool = false
    var aiReadingLineIndex: Int? = nil
    var aiReadingLetterCount: Int = 0

    @Environment(AppAppearance.self) private var appearance

    private var isAIReadingDetails: Bool {
        aiReadingLineIndex != nil
            && !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tileTint: Color {
        // Stały tint — czerwone zaznaczenie przez overlay (bez flasha przy odznaczaniu).
        appearance.tileTint.opacity(0.85)
    }

    /// Focus + full: nieużywane przy clear glass (treść bez zamglenia).
    private var focusGlassTint: Color {
        appearance.tileTint.opacity(0.10)
    }

    private var shouldUseFocusLiquidGlass: Bool {
        usesFocusLiquidGlass && appearance.usesFullLiquidGlass
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: task.kind.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(appearance.iconPrimary)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= task.importance ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(star <= task.importance ? Color.yellow : appearance.starEmpty)
                    }
                }
            }

            Text(task.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(appearance.primaryText)
                .lineLimit(showsFullDetails ? nil : 2)
                .fixedSize(horizontal: false, vertical: showsFullDetails)

            if !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if isAIReadingDetails, let lineIndex = aiReadingLineIndex {
                    ProjectDetailsAIReadingView(
                        text: task.details,
                        activeLineIndex: lineIndex,
                        activeLetterCount: aiReadingLetterCount,
                        textColor: appearance.secondaryText,
                        font: .subheadline,
                        boldFont: .subheadline.weight(.black),
                        lineLimit: showsFullDetails ? nil : 3
                    )
                } else {
                    Text(task.details)
                        .font(.subheadline)
                        .foregroundStyle(appearance.secondaryText)
                        .lineLimit(showsFullDetails ? nil : 3)
                        .fixedSize(horizontal: false, vertical: showsFullDetails)
                }
            }

            HStack {
                Text(task.kind.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(appearance.tertiaryText)

                Spacer(minLength: 0)

                if showsPlanBadge, let projectName = task.project?.name {
                    Text(projectName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(appearance.quaternaryText)
                        .lineLimit(1)
                } else if task.planQueuedAt != nil && !task.isInCurrentPlan {
                    Text("W kolejce do planu".l10n)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.9))
                } else if task.isInCurrentPlan {
                    Text("W aktualnym planie".l10n)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.cyan.opacity(0.9))
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .modifier(TaskTileGlassModifier(
            appearance: appearance,
            tint: shouldUseFocusLiquidGlass ? focusGlassTint : tileTint,
            forceFullLiquidGlass: shouldUseFocusLiquidGlass
        ))
        .besortedDeletionMark(isMarkedForDeletion)
    }
}

/// Kafelek listy: content glass.
/// Focus w Full: clear→regular wg suwaka (minimum 40%), glass tylko w tle — treść ostra.
private struct TaskTileGlassModifier: ViewModifier {
    var appearance: AppAppearance
    var tint: Color
    var forceFullLiquidGlass: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    func body(content: Content) -> some View {
        if forceFullLiquidGlass {
            let blend = appearance.glassBlend(
                minimumFrost: AppAppearance.focusTileGlassMinimumFrost
            )
            content
                .compositingGroup()
                .background {
                    shape
                        .fill(Color.clear)
                        .glassEffect(
                            appearance.blendedGlass(
                                interactive: false,
                                tint: appearance.tileTint,
                                blend: blend
                            ),
                            in: shape
                        )
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassFrost)
        } else {
            content
                .besortedGlass(appearance, tint: tint, in: shape, role: .listTile)
        }
    }
}

struct TileActionPills: View {
    var onDelete: () -> Void
    var onPriority: () -> Void
    var onEdit: (() -> Void)? = nil

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        HStack(spacing: 10) {
            Button("Usuń".l10n, action: onDelete)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(red: 1.0, green: 0.15, blue: 0.15))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color(red: 0.55, green: 0.08, blue: 0.08)))

            Button("Priorytet".l10n, action: onPriority)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.primaryText)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(appearance.fieldFill))
                .besortedGlass(appearance, interactive: true, in: .capsule)

            if let onEdit {
                Button("Edytuj".l10n, action: onEdit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(appearance.fieldFill))
                    .besortedGlass(appearance, interactive: true, in: .capsule)
            }

            Spacer(minLength: 0)
        }
    }
}

struct CurrentPlanTabView: View {
    @Binding var selectedPlanTask: ProjectTask?
    @Binding var isAIAssistPresented: Bool

    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var smartChrome
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @Query(
        filter: #Predicate<ProjectTask> { task in
            task.isInCurrentPlan && !task.isCompleted
        },
        sort: \ProjectTask.createdAt
    ) private var planTasks: [ProjectTask]

    @Query(
        filter: #Predicate<ProjectTask> { task in
            !task.isCompleted && !task.isInCurrentPlan && task.planQueuedAt != nil
        },
        sort: \ProjectTask.planQueuedAt
    ) private var queuedTasks: [ProjectTask]

    @State private var showTaskPicker = false
    @State private var isPlanAIBusy = false
    @State private var planAIStatusMessage: String?
    @State private var isPlanTaskPickMode = false
    @State private var focusedAssistTask: ProjectTask?
    @State private var focusedExpandTask: ProjectTask?
    @State private var showPlanAIMenu = false
    @State private var headerSolidProgress: CGFloat = 0

    private var priorityProjects: [Project] {
        projects.filter(\.isPriorityHighlighted)
    }

    private var isPlanFull: Bool {
        planTasks.count >= appearance.planMaxTasks
    }

    var body: some View {
        ZStack {
            Group {
                if showTaskPicker {
                    planTaskPicker
                } else {
                    planHome
                }
            }

            if let focusedAssistTask {
                PlanTaskAIAssistOverlay(
                    task: focusedAssistTask,
                    onClose: {
                        withAnimation(.smooth(duration: 0.3)) {
                            self.focusedAssistTask = nil
                            isPlanTaskPickMode = false
                            isAIAssistPresented = false
                        }
                    }
                )
                .environment(appearance)
                .transition(.opacity)
                .zIndex(80)
            }

            if let focusedExpandTask {
                TaskFocusOverlay(
                    task: focusedExpandTask,
                    mode: .plan,
                    showsPlanBadge: true,
                    onClose: {
                        withAnimation(.smooth(duration: 0.3)) {
                            self.focusedExpandTask = nil
                        }
                    }
                )
                .environment(appearance)
                .transition(.opacity)
                .zIndex(78)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.3), value: focusedAssistTask?.syncUUID)
        .animation(.smooth(duration: 0.3), value: focusedExpandTask?.syncUUID)
        .onChange(of: focusedAssistTask?.syncUUID) { _, _ in
            syncPlanFocusChrome()
        }
        .onChange(of: focusedExpandTask?.syncUUID) { _, _ in
            syncPlanFocusChrome()
        }
        .onChange(of: smartChrome.planAIToken) { _, _ in
            Task { await handlePlanAIButton() }
        }
        .onChange(of: smartChrome.planAddToken) { _, _ in
            withAnimation(.smooth(duration: 0.25)) {
                showTaskPicker = true
            }
        }
    }

    private var planHome: some View {
        ZStack(alignment: .topTrailing) {
            if planTasks.isEmpty && !isPlanAIBusy {
                ZStack {
                    Button("Dodaj zadanie".l10n) {
                        withAnimation(.smooth(duration: 0.25)) {
                            showPlanAIMenu = false
                            showTaskPicker = true
                        }
                    }
                    .font(.title3.weight(.semibold))
                    .controlSize(.large)
                    .besortedAdaptiveGlassButton(appearance)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 72)
            } else if planTasks.isEmpty && isPlanAIBusy {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(appearance.primaryText)
                    Text("AI układa Aktualny Plan…".l10n)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(appearance.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 72)
            } else {
                BesortedFixedWidthTileScroll(topPadding: 92) {
                    SmartScrollSensor(
                        token: smartChrome.scrollToken,
                        direction: smartChrome.scrollDirection
                    )
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)

                    ForEach(planTasks) { task in
                        Button {
                            handlePlanTaskTap(task)
                        } label: {
                            TaskTileView(task: task, showsPlanBadge: true)
                        }
                        .buttonStyle(BeSortedPlainButtonStyle(sound: .tile))
                        .softWiggle(isActive: isPlanTaskPickMode)
                        .opacity(
                            focusedAssistTask?.persistentModelID == task.persistentModelID
                                || focusedExpandTask?.persistentModelID == task.persistentModelID
                                ? 0.15
                                : 1
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }

                    if !queuedTasks.isEmpty {
                        Text("Kolejka (wejdą po zwolnieniu miejsca)".l10n)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appearance.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(queuedTasks) { task in
                            TaskTileView(task: task, showsPlanBadge: true)
                                .opacity(0.7)
                        }
                    }
                }
                .animation(.smooth(duration: 0.40), value: planTasks.count)
                .trackTabHeaderSolidProgress($headerSolidProgress)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if showPlanAIMenu {
                            withAnimation(.smooth(duration: 0.2)) {
                                showPlanAIMenu = false
                            }
                        }
                    }
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    BesortedCollapsingTabHeader(
                        title: "Aktualny Plan".l10n,
                        scrollY: headerSolidProgress
                    ) {
                        if !appearance.smartMode {
                            HStack(alignment: .center, spacing: 8) {
                                if !planTasks.isEmpty && !isPlanFull {
                                    Button {
                                        withAnimation(.smooth(duration: 0.25)) {
                                            showPlanAIMenu = false
                                            showTaskPicker = true
                                        }
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(appearance.primaryText)
                                            .frame(width: 40, height: 40)
                                    }
                                    .buttonStyle(BeSortedPlainButtonStyle())
                                    .besortedGlass(appearance, interactive: true, in: .capsule)
                                    .disabled(isPlanAIBusy || focusedAssistTask != nil || focusedExpandTask != nil)
                                }

                                Button {
                                    withAnimation(.smooth(duration: 0.25)) {
                                        if isPlanTaskPickMode {
                                            isPlanTaskPickMode = false
                                            planAIStatusMessage = nil
                                        }
                                        showPlanAIMenu.toggle()
                                    }
                                } label: {
                                    Group {
                                        if isPlanAIBusy {
                                            ProgressView()
                                                .tint(appearance.primaryText)
                                        } else {
                                            Image("SmartAiIcon")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 22, height: 22)
                                                .opacity(showPlanAIMenu || isPlanTaskPickMode ? 1 : 0.92)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                }
                                .buttonStyle(BeSortedPlainButtonStyle(sound: .ai))
                                .besortedGlass(appearance, interactive: true, in: .capsule)
                                .disabled(isPlanAIBusy || focusedAssistTask != nil || focusedExpandTask != nil)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    Text("\(planTasks.count)/\(appearance.planMaxTasks) zadań")
                        .font(.subheadline)
                        .foregroundStyle(appearance.tertiaryText)
                        .padding(.leading, BeSortedContentInsets.headerHorizontal)
                        .padding(.top, 40)
                        .opacity(TabHeaderScrollSolidify.buttonsOpacity(scrollY: headerSolidProgress))
                        .allowsHitTesting(false)
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                .tabHeaderRegularLiquidGlass(appearance, scrollY: headerSolidProgress)
                .zIndex(2)

                if let planAIStatusMessage {
                    Text(planAIStatusMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(appearance.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                if isPlanTaskPickMode {
                    Text("Wybierz zadanie, które AI ma rozbić na kroki".l10n)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }

            if showPlanAIMenu && !appearance.smartMode {
                planAIMenu
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
            }
        }
        .animation(.smooth(duration: 0.28), value: showPlanAIMenu)
    }

    private var planAIMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            planLockedAIMenuButton(
                title: "Dodaj zadania".l10n,
                systemImage: "calendar.badge.plus",
                skill: .fillCurrentPlan,
                disabledReason: isPlanFull ? "Plan jest pełny.".l10n : nil
            ) {
                Task { await fillPlanFromMenu() }
            }

            planLockedAIMenuButton(
                title: "Rozbij zadania".l10n,
                systemImage: "list.bullet.indent",
                skill: .breakDownTask,
                disabledReason: planTasks.isEmpty ? "Brak zadań w planie.".l10n : nil
            ) {
                beginBreakDownPickMode()
            }
        }
        .frame(width: 220)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 16),
            minimumFrost: AppAppearance.menuGlassMinimumFrost
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.2),
            radius: appearance.isFlatDesign ? 0 : 12,
            y: appearance.isFlatDesign ? 0 : 4
        )
    }

    private func planLockedAIMenuButton(
        title: String,
        systemImage: String,
        skill: SmartAssistantSkill,
        disabledReason: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let skillLocked = !SmartAssistantStore.shared.supports(skill)
        let locked = skillLocked || disabledReason != nil
        let tint = locked ? appearance.quaternaryText : appearance.primaryText

        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                showPlanAIMenu = false
            }
            if let disabledReason {
                planAIStatusMessage = disabledReason
                return
            }
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                skill,
                chrome: smartChrome
            ) else { return }
            action()
        } label: {
            HStack(spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if skillLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(appearance.quaternaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(BeSortedPlainButtonStyle())
    }

    private func fillPlanFromMenu() async {
        let freeSlots = max(0, appearance.planMaxTasks - planTasks.count)
        guard freeSlots > 0 else {
            planAIStatusMessage = "Plan jest pełny.".l10n
            return
        }
        await fillPlanWithAI(targetCount: freeSlots)
    }

    private func beginBreakDownPickMode() {
        guard !planTasks.isEmpty else {
            planAIStatusMessage = "Brak zadań w planie.".l10n
            return
        }
        withAnimation(.smooth(duration: 0.25)) {
            isPlanTaskPickMode = true
            planAIStatusMessage = nil
        }
    }

    private func syncPlanFocusChrome() {
        isAIAssistPresented = focusedAssistTask != nil || focusedExpandTask != nil
    }

    private func handlePlanTaskTap(_ task: ProjectTask) {
        if isPlanTaskPickMode {
            withAnimation(.smooth(duration: 0.35)) {
                focusedExpandTask = nil
                focusedAssistTask = task
                isAIAssistPresented = true
            }
            return
        }
        withAnimation(.smooth(duration: 0.35)) {
            showPlanAIMenu = false
            focusedAssistTask = nil
            if focusedExpandTask?.persistentModelID == task.persistentModelID {
                focusedExpandTask = nil
            } else {
                focusedExpandTask = task
            }
        }
    }

    private func handlePlanAIButton() async {
        if focusedAssistTask != nil || focusedExpandTask != nil { return }

        if isPlanTaskPickMode {
            withAnimation(.smooth(duration: 0.25)) {
                isPlanTaskPickMode = false
                planAIStatusMessage = nil
            }
            return
        }

        if isPlanFull {
            guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
                .breakDownTask,
                chrome: smartChrome
            ) else { return }
            withAnimation(.smooth(duration: 0.25)) {
                isPlanTaskPickMode = true
                planAIStatusMessage = nil
            }
            return
        }

        guard SmartAssistantStore.shared.requireSkillOrPromptUpgrade(
            .fillCurrentPlan,
            chrome: smartChrome
        ) else { return }

        let freeSlots = max(0, appearance.planMaxTasks - planTasks.count)
        guard freeSlots > 0 else { return }
        await fillPlanWithAI(targetCount: freeSlots)
    }

    private func fillPlanWithAI(targetCount: Int) async {
        guard !isPlanAIBusy else { return }
        guard targetCount > 0 else { return }

        if priorityProjects.isEmpty {
            planAIStatusMessage = "Oznacz projekty jako priorytetowe, żeby AI mogło dobrać zadania.".l10n
            return
        }

        isPlanAIBusy = true
        planAIStatusMessage = "AI dobiera najważniejsze zadania…".l10n
        do {
            let items = try await BeSortedAIService.selectTasksForCurrentPlan(
                priorityProjects: priorityProjects,
                targetCount: targetCount
            )
            guard !items.isEmpty else {
                planAIStatusMessage = "AI nie znalazło zadań do planu.".l10n
                isPlanAIBusy = false
                return
            }

            planAIStatusMessage = nil
            var addedCount = 0
            for item in items {
                guard addedCount < targetCount else { break }
                guard let task = item.existingTask else { continue }
                withAnimation(.smooth(duration: 0.45)) {
                    CurrentPlanStore.prioritize(task, in: modelContext)
                }
                BeSortedSound.play(.planAdd)
                addedCount += 1
                try? await Task.sleep(nanoseconds: 160_000_000)
            }

            CurrentPlanStore.persistAndSync(modelContext)
            if addedCount == 0 {
                planAIStatusMessage = "Brak istniejących zadań do dodania. Użyj „Zaproponuj zadania” w projekcie.".l10n
            } else {
                planAIStatusMessage = L10n.format("Dodano %d zadań do planu.", addedCount)
            }
        } catch {
            planAIStatusMessage = error.localizedDescription
        }
        isPlanAIBusy = false
    }

    private var planTaskPicker: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        showTaskPicker = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .besortedGlass(appearance, interactive: true, in: .capsule)

                Spacer()

                Text("Dodaj zadanie".l10n)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)

                Spacer()

                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if projectsWithAvailableTasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(appearance.quaternaryText)
                            Text("Brak dostępnych zadań".l10n)
                                .font(.headline)
                                .foregroundStyle(appearance.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        ForEach(projectsWithAvailableTasks, id: \.project.persistentModelID) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.project.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(appearance.primaryText)
                                    .padding(.horizontal, 16)

                                ForEach(group.tasks) { task in
                                    Button {
                                        withAnimation(.smooth(duration: 0.25)) {
                                            CurrentPlanStore.prioritize(task, in: modelContext)
                                            showTaskPicker = false
                                        }
                                        BeSortedSound.play(.planAdd)
                                    } label: {
                                        TaskTileView(task: task)
                                    }
                                    .buttonStyle(BeSortedPlainButtonStyle(sound: .tile))
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectsWithAvailableTasks: [(project: Project, tasks: [ProjectTask])] {
        projects.compactMap { project in
            let tasks = project.taskList
                .filter { !$0.isCompleted && !$0.isInCurrentPlan && $0.planQueuedAt == nil }
                .sorted { $0.createdAt > $1.createdAt }
            guard !tasks.isEmpty else { return nil }
            return (project, tasks)
        }
    }
}

struct PlanTaskDetailView: View {
    @Bindable var task: ProjectTask
    var onBack: () -> Void

    @Environment(AppAppearance.self) private var appearance
    @Environment(\.modelContext) private var modelContext

    @State private var showTrashAnimation = false
    @State private var showBugChoice = false
    @State private var showAddBug = false
    @State private var trashScale: CGFloat = 0.2
    @State private var trashOpacity: Double = 0

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    if !appearance.smartMode {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(appearance.primaryText)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(BeSortedPlainButtonStyle())
                        .besortedGlass(appearance, interactive: true, in: .capsule)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(task.name)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(task.details)
                                .font(.body)
                                .foregroundStyle(appearance.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: 12) {
                            Button("Usuń zadanie".l10n) {
                                playTrashAndRemoveFromPlan()
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.18, blue: 0.18))
                            .frame(width: 280, height: 52)
                            .background(Capsule().fill(Color(red: 0.45, green: 0.08, blue: 0.08)))

                            Button("Zadanie jest zrobione".l10n) {
                                withAnimation(.smooth(duration: 0.25)) {
                                    showBugChoice = true
                                }
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.15, green: 1.0, blue: 0.35))
                            .frame(width: 280, height: 52)
                            .background(Capsule().fill(Color(red: 0.06, green: 0.38, blue: 0.14)))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }

            if showBugChoice {
                bugChoiceOverlay
            }

            if showTrashAnimation {
                trashOverlay
            }
        }
        .sheet(isPresented: $showAddBug) {
            AddBugSheet(isPresented: $showAddBug) { draft in
                if let project = task.project {
                    let bug = ProjectBug(
                        title: draft.title,
                        details: draft.details,
                        severity: draft.severity,
                        project: project,
                        relatedTaskName: task.name
                    )
                    modelContext.insert(bug)
                    CurrentPlanStore.complete(task, in: modelContext)
                    CurrentPlanStore.persistAndSync(modelContext, mutatedTask: task, mutatedBug: bug)
                } else {
                    CurrentPlanStore.complete(task, in: modelContext)
                }
                onBack()
            }
            .presentationDetents([.fraction(0.92)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(appearance.preferredScheme)
            .environment(appearance)
        }
    }

    private var bugChoiceOverlay: some View {
        ZStack {
            appearance.overlayScrim
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.2)) {
                        showBugChoice = false
                    }
                }

            VStack(spacing: 18) {
                Text("Czy są jakieś błędy do poprawy?".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Tak".l10n) {
                        showBugChoice = false
                        showAddBug = true
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .besortedAdaptiveGlassButton(appearance)
                    .tint(appearance.prominentButtonTint)

                    Button("Nie".l10n) {
                        showBugChoice = false
                        CurrentPlanStore.complete(task, in: modelContext)
                        onBack()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .besortedAdaptiveGlassButton(appearance)
                    .tint(appearance.prominentButtonTint)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .foregroundStyle(appearance.primaryText)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(appearance.softOverlayScrim)
            )
            .besortedGlass(
                appearance,
                tint: appearance.tileTint.opacity(0.85),
                in: .rect(cornerRadius: 24),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
            )
        }
        .transition(.opacity)
    }

    private var trashOverlay: some View {
        ZStack {
            appearance.softOverlayScrim
                .ignoresSafeArea()

            Image(systemName: "trash.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.25))
                .scaleEffect(trashScale)
                .opacity(trashOpacity)
                .shadow(color: .red.opacity(0.5), radius: 24)
        }
        .allowsHitTesting(false)
    }

    private func playTrashAndRemoveFromPlan() {
        showBugChoice = false
        showTrashAnimation = true
        trashScale = 0.2
        trashOpacity = 0

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            trashScale = 1.15
            trashOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeIn(duration: 0.28)) {
                trashScale = 0.8
                trashOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            CurrentPlanStore.removeFromPlan(task, in: modelContext)
            showTrashAnimation = false
            onBack()
        }
    }
}

struct BugTileView: View {
    let bug: ProjectBug
    var isMarkedForDeletion: Bool = false

    @Environment(AppAppearance.self) private var appearance

    private var tileTint: Color {
        appearance.tileTint.opacity(0.85)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.orange)

                Spacer(minLength: 0)

                Text("Waga \(bug.severity)/5")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(appearance.secondaryText)
            }

            Text(bug.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(appearance.primaryText)
                .lineLimit(2)

            if !bug.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(bug.details)
                    .font(.subheadline)
                    .foregroundStyle(appearance.secondaryText)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .besortedGlass(appearance, tint: tileTint, in: .rect(cornerRadius: 18), role: .listTile)
        .besortedDeletionMark(isMarkedForDeletion)
    }
}

struct BugDraft {
    var title: String
    var details: String
    var severity: Int
}

struct AddBugSheet: View {
    @Binding var isPresented: Bool
    var onSave: (BugDraft) -> Void

    @Environment(AppAppearance.self) private var appearance

    @State private var title = ""
    @State private var details = ""
    @State private var severity = 3

    private var severityHints: [Int: String] {
        [
            1: "Mało istotny".l10n,
            2: "Czasami się pokazuje, ale nie przeszkadza w grze".l10n,
            3: "Błąd przeszkadza w niektórych zadaniach".l10n,
            4: "Błąd przeszkadza w całej rozgrywce".l10n,
            5: "Błąd nie pozwala na odpalenie gry".l10n
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Nowy błąd".l10n)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(appearance.primaryText)

                fieldBlock(title: "Tytuł błędu".l10n) {
                    TextField(
                        "",
                        text: $title,
                        prompt: Text("Wpisz tytuł".l10n).foregroundStyle(appearance.promptText)
                    )
                    .padding(14)
                    .foregroundStyle(appearance.primaryText)
                    .background(fieldBackground)
                }

                fieldBlock(title: "Opis błędu".l10n) {
                    TextEditor(text: $details)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110)
                        .padding(10)
                        .foregroundStyle(appearance.primaryText)
                        .background(fieldBackground)
                }

                fieldBlock(title: "Ocena wagi".l10n) {
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    withAnimation(.smooth(duration: 0.2)) {
                                        severity = value
                                    }
                                } label: {
                                    Text("\(value)")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(
                                            value <= severity
                                                ? Color.black
                                                : appearance.tertiaryText
                                        )
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle().fill(
                                                value <= severity
                                                    ? Color.orange
                                                    : appearance.fieldFill
                                            )
                                        )
                                }
                                .buttonStyle(BeSortedPlainButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(severityHints[severity] ?? "")
                            .font(.subheadline)
                            .foregroundStyle(appearance.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }
                    .padding(16)
                    .background(fieldBackground)
                }

                Button("Zapisz błąd".l10n) {
                    onSave(
                        BugDraft(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                            severity: severity
                        )
                    )
                    isPresented = false
                }
                .font(.headline)
                .foregroundStyle(appearance.selectedTabForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .besortedFormPrimaryButton(appearance)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .besortedFormSheetChrome(appearance)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(appearance.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(appearance.fieldStroke, lineWidth: 1)
            )
    }

    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.secondaryText)
            content()
        }
    }
}

struct ProjectDraft {
    var name: String
    var details: String
    var kind: ProjectKind
    var importance: Int
}

/// Wyśrodkowane potwierdzenie dodania projektu: napis (stały rozmiar) nad
/// obrazkiem typu, który po pojawieniu się powiększa się sprężyście z małego.
/// Bez kafelka — sam napis i obrazek na tle scrim.
private struct AddedProjectConfirmation: View {
    let kind: ProjectKind
    var opacity: Double

    @Environment(AppAppearance.self) private var appearance
    @State private var isScaledIn = false

    var body: some View {
        ZStack {
            appearance.overlayScrim.opacity(opacity)

            VStack(spacing: 14) {
                Text("Dodano do listy".l10n)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .multilineTextAlignment(.center)

                Image(kind.tileImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(isScaledIn ? 1 : 0.22)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            }
        }
        .ignoresSafeArea()
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.22)) {
                isScaledIn = true
            }
        }
    }
}

struct TaskDraft {
    var name: String
    var details: String
    var kind: TaskKind
    var importance: Int
}

struct AddFutureNoteSheet: View {
    @Binding var isPresented: Bool
    var onSave: (String) -> Void

    @Environment(AppAppearance.self) private var appearance
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nowa notatka".l10n)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(appearance.primaryText)

                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(.body)
                    .foregroundStyle(appearance.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .frame(minHeight: 220, maxHeight: .infinity)
                    .besortedGlass(
                        appearance,
                        interactive: true,
                        tint: appearance.tileTint.opacity(0.8),
                        in: .rect(cornerRadius: 18),
            role: .content
                    )
                    .overlay(alignment: .topLeading) {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Napisz tutaj notatkę, co chcesz dodać do projektu lub co chcesz zmienić w samym projekcie")
                                .font(.body)
                                .foregroundStyle(appearance.promptText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    isPresented = false
                } label: {
                    Text("Dodaj notatkę".l10n)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(appearance.selectedTabForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .besortedFormPrimaryButton(appearance)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                Group {
                    if appearance.usesFullLiquidGlass {
                        appearance.screenBackgroundGradient
                    } else {
                        Rectangle()
                            .fill(appearance.opaqueModalFill)
                    }
                }
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Anuluj".l10n) { isPresented = false }
                        .foregroundStyle(appearance.secondaryText)
                }
            }
        }
        .presentationBackground(
            appearance.usesFullLiquidGlass
                ? Color.clear
                : appearance.opaqueModalFill
        )
        .onAppear {
            isFocused = true
        }
    }
}

struct FutureNoteTileView: View {
    let note: ProjectFutureNote
    var isMarkedForDeletion: Bool = false
    var showsInlineDelete: Bool = true
    var onDelete: () -> Void

    @Environment(AppAppearance.self) private var appearance

    private var tileTint: Color {
        appearance.tileTint.opacity(0.85)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(appearance.iconPrimary)
                Spacer(minLength: 0)
                if showsInlineDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                }
            }

            Text(note.text)
                .font(.body)
                .foregroundStyle(appearance.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(appearance.tertiaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .besortedGlass(appearance, tint: tileTint, in: .rect(cornerRadius: 18), role: .listTile)
        .besortedDeletionMark(isMarkedForDeletion)
    }
}

/// Okienko zrzuca się z góry na środek, dopiero potem płynnie pojawia się przyciemnione tło.
struct DropInModalChrome<Content: View>: View {
    var onClose: () -> Void
    @ViewBuilder var content: (_ requestClose: @escaping () -> Void) -> Content

    @State private var panelOffsetY: CGFloat = -460
    @State private var panelOpacity: Double = 0
    @State private var scrimOpacity: Double = 0
    @State private var isDismissing = false
    /// Anuluje opóźnione onClose po remouncie / ponownym otwarciu.
    @State private var dismissToken = 0

    private let panelTravelDuration: Double = 0.48
    private let scrimFadeDuration: Double = 0.45
    private let targetScrimOpacity: Double = 0.45

    var body: some View {
        ZStack {
            Color.black.opacity(scrimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(scrimOpacity > 0.05 && !isDismissing)
                .onTapGesture { dismissAnimated() }

            content(dismissAnimated)
                .offset(y: panelOffsetY)
                .opacity(panelOpacity)
                .allowsHitTesting(!isDismissing && panelOpacity > 0.05)
        }
        .onAppear {
            // Zawsze świeży entrance — unikaj „martwego” okienka przy ponownym otwarciu.
            dismissToken += 1
            isDismissing = false
            runEntranceAnimation()
        }
    }

    private func runEntranceAnimation() {
        panelOpacity = 1
        panelOffsetY = -BeSortedScreen.height * 0.55
        scrimOpacity = 0

        withAnimation(.smooth(duration: panelTravelDuration)) {
            panelOffsetY = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + panelTravelDuration) {
            guard !isDismissing else { return }
            withAnimation(.easeInOut(duration: scrimFadeDuration)) {
                scrimOpacity = targetScrimOpacity
            }
        }
    }

    private func dismissAnimated() {
        guard !isDismissing else { return }
        isDismissing = true
        let token = dismissToken
        withAnimation(.easeOut(duration: 0.20)) {
            scrimOpacity = 0
        }
        withAnimation(.smooth(duration: 0.34)) {
            panelOffsetY = -BeSortedScreen.height * 0.42
            panelOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            guard token == dismissToken else { return }
            onClose()
        }
    }
}

struct FutureNotesAIResultOverlay: View {
    let title: String
    let bodyText: String
    /// Gdy ustawione — większe okienko + karta nazwa / typ / ocena.
    var project: Project? = nil
    /// Prawie pełny ekran (np. Ocena projektu).
    var nearFullScreen: Bool = false
    var onClose: () -> Void

    @Environment(AppAppearance.self) private var appearance

    private var isLargeReminder: Bool { project != nil || nearFullScreen }

    private var typeLabel: String {
        guard let project else { return "" }
        switch project.kind {
        case .game:
            let genres = project.gameGenres
                .sorted { $0.title < $1.title }
                .map(\.title)
            if !genres.isEmpty {
                return "\(project.kind.title) · \(genres.joined(separator: ", "))"
            }
        case .story:
            let genres = project.storyGenres
                .sorted { $0.title < $1.title }
                .map(\.title)
            if !genres.isEmpty {
                return "\(project.kind.title) · \(genres.joined(separator: ", "))"
            }
        case .drawing:
            let genres = project.drawingGenres
                .sorted { $0.title < $1.title }
                .map(\.title)
            if !genres.isEmpty {
                return "\(project.kind.title) · \(genres.joined(separator: ", "))"
            }
        case .app:
            if let category = project.appCategory {
                return "\(project.kind.title) · \(category.title)"
            }
        case .school:
            if let form = project.schoolForm {
                return "\(project.kind.title) · \(form.title)"
            }
        }
        return project.kind.title
    }

    var body: some View {
        DropInModalChrome(onClose: onClose) { requestClose in
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(isLargeReminder ? .title2.weight(.bold) : .title3.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: requestClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .besortedGlass(appearance, interactive: true, in: .circle)
                }

                if let project {
                    projectIdentityCard(project)
                }

                ScrollView {
                    AIFormattedResultText(
                        text: bodyText,
                        primary: appearance.primaryText,
                        secondary: appearance.secondaryText
                    )
                    .padding(.bottom, 4)
                }
                .frame(
                    maxHeight: nearFullScreen
                        ? BeSortedScreen.height * 0.72
                        : (isLargeReminder
                            ? BeSortedScreen.height * 0.58
                            : BeSortedScreen.height * 0.42)
                )

                Button(action: requestClose) {
                    Text("Zamknij".l10n)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(appearance.selectedTabForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
            }
            .padding(nearFullScreen ? 20 : (isLargeReminder ? 22 : 18))
            .frame(
                maxWidth: nearFullScreen
                    ? min(BeSortedScreen.width - 16, 640)
                    : (isLargeReminder ? min(BeSortedScreen.width - 20, 560) : 420)
            )
            .frame(
                minHeight: nearFullScreen
                    ? BeSortedScreen.height * 0.78
                    : (isLargeReminder ? BeSortedScreen.height * 0.62 : 0),
                alignment: .top
            )
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.9),
                in: .rect(cornerRadius: 22),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
                role: .content
            )
            .padding(.horizontal, nearFullScreen ? 8 : (isLargeReminder ? 10 : 20))
        }
    }

    private func projectIdentityCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            identityRow(
                label: "Nazwa projektu".l10n,
                value: project.name.isEmpty ? "—" : project.name,
                systemImage: "textformat"
            )
            identityRow(
                label: project.kind == .game ? "Typ gry".l10n : "Typ projektu".l10n,
                value: typeLabel,
                systemImage: project.kind.systemImage
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("Ocena projektu".l10n)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.tertiaryText)
                    .textCase(.uppercase)
                    .tracking(0.4)
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= project.importance ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                star <= project.importance
                                    ? Color.yellow
                                    : appearance.starEmpty
                            )
                    }
                    Text("\(project.importance)/5")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .padding(.leading, 4)
                }
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

    private func identityRow(label: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(appearance.iconPrimary)
                .frame(width: 22, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.tertiaryText)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AddProjectSheet: View {
    @Binding var isPresented: Bool
    var onSave: (ProjectDraft) -> Void

    @State private var name = ""
    @State private var details = ""
    @State private var kind: ProjectKind = .game
    @State private var importance = 3

    private var importanceHints: [Int: String] {
        [
            1: "Mało znaczący projekt".l10n,
            2: "Skromny projekt, ale robiony z chęciami".l10n,
            3: "Średni projekt".l10n,
            4: "W miarę duży projekt, w który angażuję się często".l10n,
            5: "Bardzo ważny projekt, który jest dla mnie głównym celem".l10n
        ]
    }

    var body: some View {
        FormSheetScaffold(
            title: "Nowy projekt".l10n,
            nameTitle: "Nazwa projektu".l10n,
            namePrompt: "Wpisz nazwę".l10n,
            detailsTitle: "Opis projektu".l10n,
            kindTitle: "Rodzaj projektu".l10n,
            importanceTitle: "Kluczowość projektu".l10n,
            saveTitle: "Zapisz projekt".l10n,
            name: $name,
            details: $details,
            importance: $importance,
            importanceHints: importanceHints,
            kindOptions: ProjectKind.allCases.map { ($0.id, $0.title, $0.systemImage) },
            selectedKindID: kind.id,
            onSelectKind: { id in
                if let match = ProjectKind(rawValue: id) {
                    kind = match
                }
            },
            onSave: {
                onSave(
                    ProjectDraft(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                        kind: kind,
                        importance: importance
                    )
                )
                isPresented = false
            }
        )
    }
}

struct AddTaskSheet: View {
    @Binding var isPresented: Bool
    let projectKind: ProjectKind
    var onSave: (TaskDraft) -> Void

    @State private var name = ""
    @State private var details = ""
    @State private var kind: TaskKind
    @State private var importance = 3

    private var availableKinds: [TaskKind] {
        TaskKind.kinds(for: projectKind)
    }

    private var importanceHints: [Int: String] {
        [
            1: "Mało znaczące zadanie".l10n,
            2: "Skromne zadanie, ale warte zrobienia".l10n,
            3: "Średnie zadanie".l10n,
            4: "Ważne zadanie, którym zajmuję się często".l10n,
            5: "Kluczowe zadanie, główny priorytet projektu".l10n
        ]
    }

    init(
        isPresented: Binding<Bool>,
        projectKind: ProjectKind,
        onSave: @escaping (TaskDraft) -> Void
    ) {
        self._isPresented = isPresented
        self.projectKind = projectKind
        self.onSave = onSave
        self._kind = State(initialValue: TaskKind.kinds(for: projectKind).first ?? .other)
    }

    var body: some View {
        FormSheetScaffold(
            title: "Nowe zadanie".l10n,
            nameTitle: "Nazwa zadania".l10n,
            namePrompt: "Wpisz nazwę zadania".l10n,
            detailsTitle: "Opis zadania".l10n,
            kindTitle: "Rodzaj zadania".l10n,
            importanceTitle: "Kluczowość zadania".l10n,
            saveTitle: "Zapisz zadanie".l10n,
            name: $name,
            details: $details,
            importance: $importance,
            importanceHints: importanceHints,
            kindOptions: availableKinds.map { ($0.id, $0.title, $0.systemImage) },
            selectedKindID: kind.id,
            onSelectKind: { id in
                if let match = TaskKind(rawValue: id) {
                    kind = match
                }
            },
            onSave: {
                onSave(
                    TaskDraft(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                        kind: kind,
                        importance: importance
                    )
                )
                isPresented = false
            }
        )
    }
}

struct EditTaskSheet: View {
    @Binding var isPresented: Bool
    @Bindable var task: ProjectTask

    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var details: String
    @State private var kind: TaskKind
    @State private var importance: Int

    private var availableKinds: [TaskKind] {
        let projectKind = task.project?.kind ?? .game
        return TaskKind.kinds(for: projectKind)
    }

    private var importanceHints: [Int: String] {
        [
            1: "Mało znaczące zadanie".l10n,
            2: "Skromne zadanie, ale warte zrobienia".l10n,
            3: "Średnie zadanie".l10n,
            4: "Ważne zadanie, którym zajmuję się często".l10n,
            5: "Kluczowe zadanie, główny priorytet projektu".l10n
        ]
    }

    init(isPresented: Binding<Bool>, task: ProjectTask) {
        self._isPresented = isPresented
        self.task = task
        self._name = State(initialValue: task.name)
        self._details = State(initialValue: task.details)
        self._kind = State(initialValue: task.kind)
        self._importance = State(initialValue: task.importance)
    }

    var body: some View {
        FormSheetScaffold(
            title: "Edytuj zadanie".l10n,
            nameTitle: "Nazwa zadania".l10n,
            namePrompt: "Wpisz nazwę zadania".l10n,
            detailsTitle: "Opis zadania".l10n,
            kindTitle: "Rodzaj zadania".l10n,
            importanceTitle: "Kluczowość zadania".l10n,
            saveTitle: "Zapisz zmiany".l10n,
            name: $name,
            details: $details,
            importance: $importance,
            importanceHints: importanceHints,
            kindOptions: availableKinds.map { ($0.id, $0.title, $0.systemImage) },
            selectedKindID: kind.id,
            onSelectKind: { id in
                if let match = TaskKind(rawValue: id) {
                    kind = match
                }
            },
            onSave: {
                task.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                task.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
                task.kindRaw = kind.rawValue
                task.importance = importance
                task.touch()
                CurrentPlanStore.persistAndSync(modelContext, mutatedTask: task)
                isPresented = false
            }
        )
    }
}

struct FormSheetScaffold: View {
    let title: String
    let nameTitle: String
    let namePrompt: String
    let detailsTitle: String
    let kindTitle: String
    let importanceTitle: String
    let saveTitle: String

    @Binding var name: String
    @Binding var details: String
    @Binding var importance: Int
    let importanceHints: [Int: String]
    let kindOptions: [(id: String, title: String, systemImage: String)]
    let selectedKindID: String
    let onSelectKind: (String) -> Void
    let onSave: () -> Void

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                fieldBlock(title: nameTitle) {
                    TextField(
                        "",
                        text: $name,
                        prompt: Text(namePrompt).foregroundStyle(appearance.promptText)
                    )
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .padding(14)
                    .foregroundStyle(appearance.primaryText)
                    .background(fieldBackground)
                    .contentShape(Rectangle())
                }

                fieldBlock(title: detailsTitle) {
                    TextEditor(text: $details)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110)
                        .padding(10)
                        .foregroundStyle(appearance.primaryText)
                        .background(fieldBackground)
                        .contentShape(Rectangle())
                }

                fieldBlock(title: kindTitle) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(kindOptions, id: \.id) { option in
                            kindChip(option)
                        }
                    }
                }

                fieldBlock(title: importanceTitle) {
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    withAnimation(.smooth(duration: 0.2)) {
                                        importance = star
                                    }
                                } label: {
                                    Image(systemName: star <= importance ? "star.fill" : "star")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(
                                            star <= importance ? Color.yellow : appearance.starEmpty
                                        )
                                        .shadow(
                                            color: star <= importance ? .yellow.opacity(0.55) : .clear,
                                            radius: star <= importance ? 8 : 0
                                        )
                                }
                                .buttonStyle(BeSortedPlainButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(importanceHints[importance] ?? "")
                            .font(.subheadline)
                            .foregroundStyle(appearance.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }
                    .padding(16)
                    .background(fieldBackground)
                }

                Button(saveTitle, action: onSave)
                    .font(.headline)
                    .foregroundStyle(appearance.selectedTabForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .besortedFormPrimaryButton(appearance)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.top, 8)
            }
            .padding(20)
            .padding(.bottom, 28)
            .foregroundStyle(appearance.primaryText)
        }
        .besortedFormSheetChrome(appearance)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(appearance.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(appearance.fieldStroke, lineWidth: 1)
            )
    }

    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.secondaryText)
            content()
        }
    }

    private func kindChip(_ option: (id: String, title: String, systemImage: String)) -> some View {
        let isSelected = selectedKindID == option.id

        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                onSelectKind(option.id)
            }
        } label: {
            HStack(spacing: 8) {
                if let projectKind = ProjectKind(rawValue: option.id) {
                    Image(projectKind.tileImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(
                isSelected
                    ? appearance.choiceSelectedForeground
                    : appearance.primaryText
            )
        }
        .settingsChoiceButtonStyle(isSelected: isSelected, appearance: appearance)
        .tint(isSelected ? appearance.prominentButtonTint : nil)
    }
}

private enum AnyGlassButtonStyle {
    case regular
    case prominent
}

extension View {
    @ViewBuilder
    fileprivate func buttonStyle(_ style: AnyGlassButtonStyle) -> some View {
        switch style {
        case .regular:
            self.buttonStyle(.glass).besortedClick(.regular)
        case .prominent:
            self.buttonStyle(.glassProminent).besortedClick(.regular)
        }
    }

    /// Przyciski wyboru w ustawieniach: glass tylko w pełnym Liquid Glass.
    @ViewBuilder
    fileprivate func settingsChoiceButtonStyle(isSelected: Bool, appearance: AppAppearance) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if appearance.usesFullLiquidGlass {
            self
                .buttonStyle(BeSortedPlainButtonStyle())
                .background {
                    if isSelected {
                        shape.fill(appearance.selectedTabTint)
                    } else {
                        Color.clear
                            .besortedGlass(
                                appearance,
                                interactive: true,
                                tint: appearance.tileTint.opacity(0.85),
                                in: shape,
                                role: .content
                            )
                    }
                }
                .contentShape(shape)
        } else if appearance.isNeomorphic {
            // Referencja (TabBarButton): wybrany = wklęsły chip, reszta = surface.
            self
                .buttonStyle(BeSortedPlainButtonStyle())
                .background {
                    shape.fill(
                        isSelected
                            ? appearance.neoChip
                            : appearance.neoRaisedFill
                    )
                }
                .contentShape(shape)
        } else {
            self
                .buttonStyle(BeSortedPlainButtonStyle())
                .background {
                    shape.fill(
                        isSelected
                            ? appearance.selectedTabTint
                            : (appearance.usesZeroLiquidGlass
                                ? appearance.tileTint
                                : appearance.tileTint.opacity(appearance.theme.usesLightContent ? 0.95 : 0.88))
                    )
                }
                .overlay {
                    flatBeSortedButtonRim(
                        appearance,
                        shape: shape
                    )
                }
                .contentShape(shape)
        }
    }
}

struct ProjectCoreOverlay: View {
    @Bindable var project: Project
    var onClose: () -> Void

    @Environment(AppAppearance.self) private var appearance
    @Environment(\.modelContext) private var modelContext

    // Gra
    @State private var mechanics: String = ""
    @State private var gameloop: String = ""
    @State private var playerGoals: String = ""
    @State private var winConditions: String = ""
    @State private var selectedGameGenres: Set<GameGenre> = []
    @State private var structure: GameStructure?

    // Opowiadanie
    @State private var storyTheme: String = ""
    @State private var storyTypicalAction: String = ""
    @State private var storyHeroGoal: String = ""
    @State private var storyFinale: String = ""
    @State private var selectedStoryGenres: Set<StoryGenre> = []
    @State private var narration: StoryNarrationStyle?

    // Rysunek
    @State private var selectedDrawingTechniques: Set<DrawingTechnique> = []
    @State private var drawingMainMotif: String = ""
    @State private var drawingGoalEmotion: String = ""
    @State private var drawingCompletion: String = ""
    @State private var selectedDrawingGenres: Set<DrawingGenre> = []
    @State private var drawingScale: DrawingScale?

    // Aplikacja
    @State private var appKeyFeatures: String = ""
    @State private var appUserPath: String = ""
    @State private var appMainProblem: String = ""
    @State private var appCategory: AppCategory?

    // Szkoła
    @State private var schoolForm: SchoolProjectForm?
    @State private var schoolImplementation: SchoolImplementationMode?
    @State private var schoolSubject: String = ""
    @State private var schoolProjectGoal: String = ""
    @State private var schoolMainContent: String = ""
    @State private var schoolCompletion: String = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case mechanics, gameloop, goals, win
        case theme, typicalAction, heroGoal, finale
        case motif, goalEmotion, completion
        case keyFeatures, userPath, mainProblem
        case schoolSubject, schoolGoal, schoolContent, schoolCompletion
    }

    var body: some View {
        ZStack {
            appearance.overlayScrim
                .ignoresSafeArea()
                .onTapGesture {
                    saveAndClose()
                }

            VStack(spacing: 0) {
                HStack {
                    Text("Rdzeń Projektowy".l10n)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                    Spacer()
                    Button("Gotowe".l10n) {
                        saveAndClose()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .buttonStyle(BeSortedPlainButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Group {
                    switch project.kind {
                    case .game:
                        gameCoreForm
                    case .story:
                        storyCoreForm
                    case .drawing:
                        drawingCoreForm
                    case .app:
                        appCoreForm
                    case .school:
                        schoolCoreForm
                    }
                }
            }
            .frame(maxWidth: 520)
            .frame(maxHeight: BeSortedScreen.height * 0.82)
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.92),
                in: .rect(cornerRadius: 24),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
            )
            .padding(.horizontal, 16)
        }
        .onAppear {
            mechanics = project.gameMechanics
            gameloop = project.gameGameloop
            playerGoals = project.gamePlayerGoals
            winConditions = project.gameWinConditions
            selectedGameGenres = project.gameGenres
            structure = project.gameStructure

            storyTheme = project.storyTheme
            storyTypicalAction = project.storyTypicalAction
            storyHeroGoal = project.storyHeroGoal
            storyFinale = project.storyFinale
            selectedStoryGenres = project.storyGenres
            narration = project.storyNarration

            selectedDrawingTechniques = project.drawingTechniques
            drawingMainMotif = project.drawingMainMotif
            drawingGoalEmotion = project.drawingGoalEmotion
            drawingCompletion = project.drawingCompletionDefinition
            selectedDrawingGenres = project.drawingGenres
            drawingScale = project.drawingScale

            appKeyFeatures = project.appKeyFeatures
            appUserPath = project.appUserPath
            appMainProblem = project.appMainProblem
            appCategory = project.appCategory

            schoolForm = project.schoolForm
            schoolImplementation = project.schoolImplementation
            schoolSubject = project.schoolSubject
            schoolProjectGoal = project.schoolProjectGoal
            schoolMainContent = project.schoolMainContent
            schoolCompletion = project.schoolCompletionCriteria
        }
    }

    private var gameCoreForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                coreTextBlock(
                    title: "Główne Mechaniki".l10n,
                    prompt: "Opisz główne mechaniki gry…".l10n,
                    text: $mechanics,
                    field: .mechanics,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Gameloop",
                    prompt: "Opisz główny gameloop…".l10n,
                    text: $gameloop,
                    field: .gameloop,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Cele Gracza".l10n,
                    prompt: "Czego gracz chce dokonać…".l10n,
                    text: $playerGoals,
                    field: .goals,
                    minHeight: 80
                )

                coreTextBlock(
                    title: "Warunki Zakończenia Gry / Wygranej".l10n,
                    prompt: "Kiedy gra się kończy lub kiedy wygrywasz…".l10n,
                    text: $winConditions,
                    field: .win,
                    minHeight: 80
                )

                genreGrid(
                    title: "Gatunek".l10n,
                    items: GameGenre.allCases,
                    titleFor: { $0.title },
                    isOn: { selectedGameGenres.contains($0) },
                    toggle: { genre in
                        if selectedGameGenres.contains(genre) {
                            selectedGameGenres.remove(genre)
                        } else {
                            selectedGameGenres.insert(genre)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Struktura".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)

                    HStack(spacing: 8) {
                        ForEach(GameStructure.allCases) { option in
                            choiceChip(
                                title: option.title,
                                isOn: structure == option
                            ) {
                                structure = option
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    private var storyCoreForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                coreTextBlock(
                    title: "Motyw przewodni".l10n,
                    prompt: "Co jest unikalnego dla tego opowiadania…".l10n,
                    text: $storyTheme,
                    field: .theme,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Typowa Akcja".l10n,
                    prompt: "Co bohaterowie / bohater robi przez większość czasu…".l10n,
                    text: $storyTypicalAction,
                    field: .typicalAction,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Cel Bohatera".l10n,
                    prompt: "Główne pragnienie / plan bohaterów lub bohatera…".l10n,
                    text: $storyHeroGoal,
                    field: .heroGoal,
                    minHeight: 80
                )

                coreTextBlock(
                    title: "Finał".l10n,
                    prompt: "Co musi się wydarzyć i jak wygląda sam finał…".l10n,
                    text: $storyFinale,
                    field: .finale,
                    minHeight: 80
                )

                genreGrid(
                    title: "Gatunek".l10n,
                    items: StoryGenre.allCases,
                    titleFor: { $0.title },
                    isOn: { selectedStoryGenres.contains($0) },
                    toggle: { genre in
                        if selectedStoryGenres.contains(genre) {
                            selectedStoryGenres.remove(genre)
                        } else {
                            selectedStoryGenres.insert(genre)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Sposób opowiadania".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(StoryNarrationStyle.allCases) { option in
                            choiceChip(
                                title: option.title.l10n,
                                isOn: narration == option
                            ) {
                                narration = option
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    private var drawingCoreForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                genreGrid(
                    title: "Technika i Narzędzia".l10n,
                    items: DrawingTechnique.allCases,
                    titleFor: { $0.title.l10n },
                    isOn: { selectedDrawingTechniques.contains($0) },
                    toggle: { technique in
                        if selectedDrawingTechniques.contains(technique) {
                            selectedDrawingTechniques.remove(technique)
                        } else {
                            selectedDrawingTechniques.insert(technique)
                        }
                    }
                )

                coreTextBlock(
                    title: "Główny Motyw".l10n,
                    prompt: "Co na rysunku jest najważniejszym elementem projektu…".l10n,
                    text: $drawingMainMotif,
                    field: .motif,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Cel i Emocja".l10n,
                    prompt: "Co ma przedstawiać ten rysunek, jakie przesłanie lub emocje…".l10n,
                    text: $drawingGoalEmotion,
                    field: .goalEmotion,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Definicja Ukończenia".l10n,
                    prompt: "Kiedy projekt ma być uznany za zakończony…".l10n,
                    text: $drawingCompletion,
                    field: .completion,
                    minHeight: 80
                )

                genreGrid(
                    title: "Gatunek".l10n,
                    items: DrawingGenre.allCases,
                    titleFor: { $0.title.l10n },
                    isOn: { selectedDrawingGenres.contains($0) },
                    toggle: { genre in
                        if selectedDrawingGenres.contains(genre) {
                            selectedDrawingGenres.remove(genre)
                        } else {
                            selectedDrawingGenres.insert(genre)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Skala i przestrzeń".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)

                    VStack(spacing: 8) {
                        ForEach(DrawingScale.allCases) { option in
                            Button {
                                drawingScale = option
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.title.l10n)
                                        .font(.subheadline.weight(.semibold))
                                    Text(option.detail.l10n)
                                        .font(.caption)
                                        .foregroundStyle(
                                            drawingScale == option
                                                ? appearance.choiceSelectedForeground.opacity(0.85)
                                                : appearance.secondaryText
                                        )
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .foregroundStyle(
                                    drawingScale == option
                                        ? appearance.choiceSelectedForeground
                                        : appearance.primaryText
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                            .settingsChoiceButtonStyle(isSelected: drawingScale == option, appearance: appearance)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    private var appCoreForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                coreTextBlock(
                    title: "Kluczowe Funkcjonalności".l10n,
                    prompt: "Najważniejsze funkcje — czym aplikacja się wyróżnia…".l10n,
                    text: $appKeyFeatures,
                    field: .keyFeatures,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Ścieżka Użytkownika".l10n,
                    prompt: "Jak użytkownik ma używać aplikacji — jaka jest pętla użytkowania…".l10n,
                    text: $appUserPath,
                    field: .userPath,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Główny problem".l10n,
                    prompt: "Jaki problem lub problemy aplikacja ma rozwiązywać…".l10n,
                    text: $appMainProblem,
                    field: .mainProblem,
                    minHeight: 90
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Kategoria aplikacji".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(AppCategory.allCases) { option in
                            choiceChip(
                                title: option.title,
                                isOn: appCategory == option
                            ) {
                                appCategory = option
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    private var schoolCoreForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Forma projektu".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(SchoolProjectForm.allCases) { option in
                            choiceChip(
                                title: option.title,
                                isOn: schoolForm == option
                            ) {
                                schoolForm = option
                            }
                        }
                    }
                }

                coreTextBlock(
                    title: "Cel projektu".l10n,
                    prompt: "Co ma przekazać ten projekt…".l10n,
                    text: $schoolProjectGoal,
                    field: .schoolGoal,
                    minHeight: 90
                )

                coreTextBlock(
                    title: "Główna zawartość".l10n,
                    prompt: "Czego dotyczy projekt…".l10n,
                    text: $schoolMainContent,
                    field: .schoolContent,
                    minHeight: 90
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Przedmiot Szkolny".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)

                    TextField(
                        "",
                        text: $schoolSubject,
                        prompt: Text("Wpisz przedmiot…".l10n).foregroundStyle(appearance.promptText)
                    )
                    .focused($focusedField, equals: .schoolSubject)
                    .submitLabel(.done)
                    .font(.body)
                    .foregroundStyle(appearance.primaryText)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(appearance.fieldFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(appearance.fieldStroke, lineWidth: 1)
                            }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Sposób realizacji".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)

                    HStack(spacing: 8) {
                        ForEach(SchoolImplementationMode.allCases) { option in
                            choiceChip(
                                title: option.title,
                                isOn: schoolImplementation == option
                            ) {
                                schoolImplementation = option
                            }
                        }
                    }
                }

                coreTextBlock(
                    title: "Kryterium końcowe".l10n,
                    prompt: "Co musi mieć projekt, aby został uznany za skończony…".l10n,
                    text: $schoolCompletion,
                    field: .schoolCompletion,
                    minHeight: 90
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    private func genreGrid<T: Identifiable>(
        title: String,
        items: [T],
        titleFor: @escaping (T) -> String,
        isOn: @escaping (T) -> Bool,
        toggle: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.secondaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(items) { item in
                    choiceChip(title: titleFor(item), isOn: isOn(item)) {
                        toggle(item)
                    }
                }
            }
        }
    }

    private func choiceChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    isOn
                        ? appearance.choiceSelectedForeground
                        : appearance.primaryText
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .settingsChoiceButtonStyle(isSelected: isOn, appearance: appearance)
    }

    private func coreTextBlock(
        title: String,
        prompt: String,
        text: Binding<String>,
        field: Field,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appearance.secondaryText)

            TextField(
                "",
                text: text,
                prompt: Text(prompt).foregroundStyle(appearance.promptText),
                axis: .vertical
            )
            .focused($focusedField, equals: field)
            .font(.body)
            .foregroundStyle(appearance.primaryText)
            .lineLimit(3...8)
            .padding(14)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(appearance.fieldFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(appearance.fieldStroke, lineWidth: 1)
                    }
            }
        }
    }

    private func saveAndClose() {
        switch project.kind {
        case .game:
            project.gameMechanics = mechanics
            project.gameGameloop = gameloop
            project.gamePlayerGoals = playerGoals
            project.gameWinConditions = winConditions
            project.gameGenres = selectedGameGenres
            project.gameStructure = structure
            project.touch()
            try? modelContext.save()
        case .story:
            project.storyTheme = storyTheme
            project.storyTypicalAction = storyTypicalAction
            project.storyHeroGoal = storyHeroGoal
            project.storyFinale = storyFinale
            project.storyGenres = selectedStoryGenres
            project.storyNarration = narration
            project.touch()
            try? modelContext.save()
        case .drawing:
            project.drawingTechniques = selectedDrawingTechniques
            project.drawingMainMotif = drawingMainMotif
            project.drawingGoalEmotion = drawingGoalEmotion
            project.drawingCompletionDefinition = drawingCompletion
            project.drawingGenres = selectedDrawingGenres
            project.drawingScale = drawingScale
            project.touch()
            try? modelContext.save()
        case .app:
            project.appKeyFeatures = appKeyFeatures
            project.appUserPath = appUserPath
            project.appMainProblem = appMainProblem
            project.appCategory = appCategory
            project.touch()
            try? modelContext.save()
        case .school:
            project.schoolForm = schoolForm
            project.schoolImplementation = schoolImplementation
            project.schoolSubject = schoolSubject
            project.schoolProjectGoal = schoolProjectGoal
            project.schoolMainContent = schoolMainContent
            project.schoolCompletionCriteria = schoolCompletion
            project.touch()
            try? modelContext.save()
        }
        onClose()
    }
}

struct ProjectContextFilesOverlay: View {
    @Binding var isPresented: Bool
    var dismissSignal: Int
    @Bindable var project: Project
    var statusMessage: String?
    var onAddFiles: () -> Void
    var onDelete: (ProjectContextFile) -> Void

    @Environment(AppAppearance.self) private var appearance
    @State private var panelOffsetY: CGFloat = -460
    @State private var panelOpacity: Double = 0
    @State private var scrimOpacity: Double = 0
    @State private var hasStartedEntrance = false
    @State private var isDismissing = false

    private let panelTravelDuration: Double = 0.48
    private let scrimFadeDuration: Double = 0.5
    private let targetScrimOpacity: Double = 0.38

    private var hint: String {
        switch project.kind {
        case .game:
            return "Dodaj pliki kluczowe dla AI — np. dokumentację silnika, design doc albo notatki o mechanikach.".l10n
        case .story:
            return "Dodaj pliki kluczowe dla AI — np. aktualny tekst opowiadania z Notatek albo zarys świata.".l10n
        case .drawing:
            return "Dodaj pliki kluczowe dla AI — np. brief, listę elementów albo opis stylu.".l10n
        case .app:
            return "Dodaj pliki kluczowe dla AI — np. brief produktu, specyfikację funkcji albo plan ekranów.".l10n
        case .school:
            return "Dodaj pliki kluczowe dla AI — np. notatki, wytyczne lub materiały do projektu.".l10n
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(scrimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(scrimOpacity > 0.05)
                .onTapGesture { dismissAnimated() }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Pliki kontekstowe".l10n)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                    Spacer()
                    Button(action: dismissAnimated) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .besortedGlass(appearance, interactive: true, in: .circle)
                }

                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(appearance.secondaryText)

                Text("Te pliki służą głównie AI, żeby lepiej rozumiało środowisko projektu.".l10n)
                    .font(.caption)
                    .foregroundStyle(appearance.tertiaryText)

                if let statusMessage, !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(appearance.tertiaryText)
                }

                if project.contextFileList.isEmpty {
                    Text("Brak plików. Dodaj tekstowe dokumenty istotne dla projektu.".l10n)
                        .font(.subheadline)
                        .foregroundStyle(appearance.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(project.contextFileList) { file in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(appearance.primaryText)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(file.fileName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(appearance.primaryText)
                                            .lineLimit(2)
                                        Text(byteSizeLabel(file.byteSize) + " · \(file.contentText.count) znaków")
                                            .font(.caption)
                                            .foregroundStyle(appearance.tertiaryText)
                                    }

                                    Spacer(minLength: 0)

                                    Button {
                                        onDelete(file)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.red.opacity(0.9))
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(BeSortedPlainButtonStyle())
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .besortedGlass(
                                    appearance,
                                    tint: appearance.tileTint.opacity(0.75),
                                    in: .rect(cornerRadius: 14),
            role: .content
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }

                Button(action: onAddFiles) {
                    Label("Dodaj pliki".l10n, systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(appearance.selectedTabForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
                .disabled(project.contextFileList.count >= ProjectContextFileImporter.maxFilesPerProject)
            }
            .padding(18)
            .frame(maxWidth: 420)
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.9),
                in: .rect(cornerRadius: 22),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
            )
            .padding(.horizontal, 20)
            .offset(y: panelOffsetY)
            .opacity(panelOpacity)
        }
        .onAppear {
            guard !hasStartedEntrance else { return }
            hasStartedEntrance = true
            runEntranceAnimation()
        }
        .onChange(of: dismissSignal) { _, _ in
            dismissAnimated()
        }
    }

    private func runEntranceAnimation() {
        panelOpacity = 1
        panelOffsetY = -BeSortedScreen.height * 0.55
        scrimOpacity = 0

        withAnimation(.smooth(duration: panelTravelDuration)) {
            panelOffsetY = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + panelTravelDuration) {
            guard isPresented, !isDismissing else { return }
            withAnimation(.easeInOut(duration: scrimFadeDuration)) {
                scrimOpacity = targetScrimOpacity
            }
        }
    }

    private func dismissAnimated() {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(.easeOut(duration: 0.22)) {
            scrimOpacity = 0
        }
        withAnimation(.smooth(duration: 0.36)) {
            panelOffsetY = -BeSortedScreen.height * 0.45
            panelOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            isPresented = false
        }
    }

    private func byteSizeLabel(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

struct ProjectDescriptionSummaryOverlay: View {
    let summary: String
    var onReplace: () -> Void
    var onCopy: () -> Void
    var onClose: () -> Void

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        DropInModalChrome(onClose: onClose) { requestClose in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Streszczenie AI".l10n)
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

                Text("Oryginalny opis projektu pozostaje nietknięty, dopóki go nie zastąpisz.".l10n)
                    .font(.footnote)
                    .foregroundStyle(appearance.secondaryText)

                ScrollView {
                    AIFormattedResultText(
                        text: summary,
                        primary: appearance.primaryText,
                        secondary: appearance.secondaryText
                    )
                }
                .frame(maxHeight: 280)

                VStack(spacing: 10) {
                    Button(action: onReplace) {
                        Text("Zastąp oryginalny opis".l10n)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(appearance.selectedTabForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)

                    HStack(spacing: 10) {
                        Button(action: onCopy) {
                            Label("Kopiuj".l10n, systemImage: "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appearance.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .besortedAdaptiveGlassButton(appearance)

                        Button(action: requestClose) {
                            Text("Zamknij".l10n)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appearance.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .besortedAdaptiveGlassButton(appearance)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 420)
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.9),
                in: .rect(cornerRadius: 22),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
            )
            .padding(.horizontal, 20)
        }
    }
}

private struct TaskFocusTileHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TaskFocusOverlay: View {
    enum Mode {
        /// Sekcja Zadania: Usuń · Priorytet · Edytuj
        case projectTasks
        /// Aktualny Plan: Usuń · Zadanie zrobione
        case plan
    }

    @Bindable var task: ProjectTask
    var mode: Mode
    var showsPlanBadge: Bool = false
    var onClose: () -> Void

    @Environment(AppAppearance.self) private var appearance
    @Environment(\.modelContext) private var modelContext

    @State private var tileOffsetY: CGFloat = 80
    @State private var contentOpacity: Double = 0
    @State private var measuredTileHeight: CGFloat = 0
    @State private var showEditSheet = false
    @State private var showBugChoice = false
    @State private var showAddBug = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !showBugChoice else { return }
                    dismiss()
                }

            // Anuluj + kafelek + akcje w jednym bloku.
            // Nad kafelkiem: Anuluj (~46) + odstęp (34). Pod kafelkiem: akcje (~46) + balans (34).
            // Blok wyśrodkowany symetrycznie → sam kafelek ląduje dokładnie na środku osi X i Y.
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                HStack {
                    Button(action: dismiss) {
                        Text("Anuluj".l10n)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(appearance.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .background {
                        let shape = Capsule(style: .continuous)
                        if appearance.usesZeroLiquidGlass {
                            shape.fill(appearance.fullyOpaque(appearance.tileTint))
                        } else if appearance.isNeomorphic {
                            BeSortedNeoRaised(shape: shape, appearance: appearance)
                        } else {
                            // Zamglony liquid glass na tle — treść „Anuluj” zostaje ostra.
                            shape
                                .fill(Color.clear)
                                .glassEffect(
                                    Glass.regular
                                        .tint(appearance.tileTint.opacity(0.55))
                                        .interactive(true),
                                    in: shape
                                )
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                // Wyraźny odstęp Anuluj ↔ kafelek.
                Spacer()
                    .frame(height: 34)

                ScrollView {
                    TaskTileView(
                        task: task,
                        showsPlanBadge: showsPlanBadge,
                        showsFullDetails: true,
                        usesFocusLiquidGlass: true
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismiss)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TaskFocusTileHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    minHeight: max(110, measuredTileHeight),
                    maxHeight: BeSortedScreen.height * 0.5,
                    alignment: .top
                )
                .onPreferenceChange(TaskFocusTileHeightKey.self) { height in
                    measuredTileHeight = height
                }

                // Przyklejone do kafelka.
                Spacer()
                    .frame(height: 1)

                actionsRow
                    .frame(maxWidth: 420)

                // Balans symetrii — tyle samo powietrza pod kafelkiem, co nad nim.
                Color.clear
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 8)
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 20)
            .offset(y: tileOffsetY)
            .opacity(contentOpacity)

            if showBugChoice {
                bugChoiceOverlay
            }
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.45)) {
                contentOpacity = 1
                tileOffsetY = 0
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditTaskSheet(isPresented: $showEditSheet, task: task)
                .presentationDetents([.fraction(0.92)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .preferredColorScheme(appearance.preferredScheme)
                .environment(appearance)
        }
        .sheet(isPresented: $showAddBug) {
            AddBugSheet(isPresented: $showAddBug) { draft in
                if let project = task.project {
                    let bug = ProjectBug(
                        title: draft.title,
                        details: draft.details,
                        severity: draft.severity,
                        project: project,
                        relatedTaskName: task.name
                    )
                    modelContext.insert(bug)
                    CurrentPlanStore.complete(task, in: modelContext)
                    CurrentPlanStore.persistAndSync(modelContext, mutatedTask: task, mutatedBug: bug)
                } else {
                    CurrentPlanStore.complete(task, in: modelContext)
                }
                onClose()
            }
            .presentationDetents([.fraction(0.92)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(appearance.preferredScheme)
            .environment(appearance)
        }
    }

    @ViewBuilder
    private var actionsRow: some View {
        switch mode {
        case .projectTasks:
            HStack(spacing: 10) {
                focusActionButton(
                    title: "Usuń".l10n,
                    foreground: Color(red: 1.0, green: 0.22, blue: 0.22),
                    solidFallback: Color(red: 0.55, green: 0.08, blue: 0.08)
                ) {
                    let uuid = task.syncUUID
                    modelContext.delete(task)
                    CurrentPlanStore.promoteQueuedTasks(in: modelContext)
                    try? modelContext.save()
                    PhoneWatchSyncService.shared.pushTaskDeleted(syncUUID: uuid)
                    dismiss()
                }

                focusActionButton(
                    title: "Priorytet".l10n,
                    foreground: appearance.primaryText,
                    solidFallback: appearance.fieldFill
                ) {
                    CurrentPlanStore.prioritize(task, in: modelContext)
                    BeSortedSound.play(.planAdd)
                    dismiss()
                }

                focusActionButton(
                    title: "Edytuj".l10n,
                    foreground: appearance.primaryText,
                    solidFallback: appearance.fieldFill
                ) {
                    showEditSheet = true
                }
            }

        case .plan:
            HStack(spacing: 10) {
                focusActionButton(
                    title: "Usuń".l10n,
                    foreground: Color(red: 1.0, green: 0.22, blue: 0.22),
                    solidFallback: Color(red: 0.55, green: 0.08, blue: 0.08)
                ) {
                    CurrentPlanStore.removeFromPlan(task, in: modelContext)
                    dismiss()
                }

                focusActionButton(
                    title: "Zadanie jest zrobione".l10n,
                    foreground: Color(red: 0.2, green: 0.95, blue: 0.4),
                    solidFallback: Color(red: 0.06, green: 0.38, blue: 0.14)
                ) {
                    withAnimation(.smooth(duration: 0.25)) {
                        showBugChoice = true
                    }
                }
            }
        }
    }

    private func focusActionButton(
        title: String,
        foreground: Color,
        solidFallback: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
        }
        .buttonStyle(BeSortedPlainButtonStyle())
        .modifier(TaskFocusActionChrome(appearance: appearance, solidFallback: solidFallback))
    }

    private var bugChoiceOverlay: some View {
        ZStack {
            appearance.overlayScrim
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.2)) {
                        showBugChoice = false
                    }
                }

            VStack(spacing: 18) {
                Text("Czy są jakieś błędy do poprawy?".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Tak".l10n) {
                        showBugChoice = false
                        showAddBug = true
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .besortedAdaptiveGlassButton(appearance)

                    Button("Nie".l10n) {
                        showBugChoice = false
                        CurrentPlanStore.complete(task, in: modelContext)
                        onClose()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .besortedAdaptiveGlassButton(appearance)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .besortedGlass(
                appearance,
                tint: appearance.tileTint.opacity(0.85),
                in: .rect(cornerRadius: 24),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
                role: .content
            )
        }
        .transition(.opacity)
    }

    private func dismiss() {
        withAnimation(.smooth(duration: 0.28)) {
            contentOpacity = 0
            tileOffsetY = 36
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onClose()
        }
    }
}

/// Liquid glass na przyciskach focusu; w Zero — solidny fill.
private struct TaskFocusActionChrome: ViewModifier {
    var appearance: AppAppearance
    var solidFallback: Color

    func body(content: Content) -> some View {
        if appearance.usesZeroLiquidGlass {
            content
                .background(Capsule().fill(solidFallback))
        } else if appearance.isNeomorphic {
            content
                .background {
                    BeSortedNeoRaised(shape: Capsule(style: .continuous), appearance: appearance, fill: appearance.fullyOpaque(solidFallback))
                }
        } else {
            content
                .besortedGlass(appearance, interactive: true, in: .capsule)
        }
    }
}

struct PlanTaskAIAssistOverlay: View {
    let task: ProjectTask
    var onClose: () -> Void

    @Environment(AppAppearance.self) private var appearance

    @State private var tileScale: CGFloat = 0.86
    @State private var tileOffsetY: CGFloat = 120
    @State private var tileOpacity: Double = 0
    @State private var isReading = false
    @State private var readingLineIndex = 0
    @State private var readingLetterCount = 0
    @State private var readingToken = UUID()
    @State private var isGenerating = false
    @State private var points: [String]?
    @State private var errorMessage: String?
    @State private var showResults = false

    /// Przybliżony budżet znaków widocznych w kafelku (3 linie subheadline).
    private let visibleDetailsCharBudget = 150

    private var readingText: String {
        let details = task.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !details.isEmpty { return details }
        return task.name
    }

    private var hasDetailsToRead: Bool {
        !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if showResults || errorMessage != nil {
                        onClose()
                    }
                }

            VStack(spacing: 16) {
                TaskTileView(
                    task: task,
                    showsPlanBadge: true,
                    aiReadingLineIndex: isReading && hasDetailsToRead ? readingLineIndex : nil,
                    aiReadingLetterCount: readingLetterCount
                )
                .scaleEffect(tileScale)
                .offset(y: tileOffsetY)
                .opacity(tileOpacity)
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)

                if isGenerating && !showResults {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(appearance.primaryText)
                        Text("AI rozbija zadanie…".l10n)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(appearance.secondaryText)
                    }
                    .padding(.top, 4)
                }

                if showResults, let points {
                    breakdownPanel(points: points)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(appearance.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Zamknij".l10n, action: onClose)
                            .besortedAdaptiveGlassButton(appearance)
                    }
                    .padding(18)
                    .frame(maxWidth: 420)
                    .besortedGlass(
                        appearance,
                        interactive: true,
                        tint: appearance.tileTint.opacity(0.9),
                        in: .rect(cornerRadius: 22),
                        minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .task {
            await runAssistFlow()
        }
    }

    private func breakdownPanel(points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Jak wykonać to zadanie".l10n)
                .font(.title3.weight(.bold))
                .foregroundStyle(appearance.primaryText)

            Text("Do \(points.count) punktów na podstawie opisu zadania, projektu i plików kontekstowych")
                .font(.footnote)
                .foregroundStyle(appearance.secondaryText)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(appearance.tertiaryText)
                                .frame(width: 22, alignment: .leading)
                            Text(point)
                                .font(.subheadline)
                                .foregroundStyle(appearance.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .besortedGlass(
                            appearance,
                            tint: appearance.tileTint.opacity(0.75),
                            in: .rect(cornerRadius: 14),
            role: .content
                        )
                    }
                }
            }
            .frame(maxHeight: 320)

            HStack(spacing: 10) {
                Button {
                    Task { await regenerateBreakdown() }
                } label: {
                    Label(
                        isGenerating ? "Generuję…".l10n : "Nowa lista".l10n,
                        systemImage: "arrow.clockwise"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .besortedAdaptiveGlassButton(appearance)
                .disabled(isGenerating)

                Button(action: onClose) {
                    Text("Zamknij".l10n)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(appearance.selectedTabForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
            }
        }
        .padding(18)
        .frame(maxWidth: 420)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 22),
            minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
        )
        .padding(.horizontal, 20)
    }

    private func runAssistFlow() async {
        withAnimation(.smooth(duration: 0.45)) {
            tileOpacity = 1
            tileScale = 1
            tileOffsetY = 0
        }
        try? await Task.sleep(nanoseconds: 280_000_000)

        await playReadingAnimation()
        await generateBreakdown()
    }

    private func playReadingAnimation() async {
        let text = readingText
        let lines = text.components(separatedBy: .newlines)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let token = UUID()
        readingToken = token
        isReading = true
        readingLineIndex = 0
        readingLetterCount = 0

        let totalLetters = max(lines.reduce(0) { $0 + $1.count }, 1)
        let targetDuration = min(2.4, max(0.7, Double(totalLetters) * 0.022))
        let letterDelay = UInt64((targetDuration / Double(totalLetters)) * 1_000_000_000)

        var globalCharIndex = 0
        var stoppedUpdatingVisual = false

        for (lineIndex, line) in lines.enumerated() {
            guard readingToken == token else { return }
            readingLineIndex = lineIndex
            readingLetterCount = 0
            guard !line.isEmpty else { continue }

            for letters in 1...line.count {
                guard readingToken == token else { return }
                globalCharIndex += 1

                // Animacja wizualna tylko do miejsca, gdzie kafelek i tak urywa tekst („…”).
                if !stoppedUpdatingVisual {
                    if globalCharIndex <= visibleDetailsCharBudget {
                        withAnimation(.easeInOut(duration: 0.06)) {
                            readingLetterCount = letters
                        }
                        if letters % 2 == 1 {
                            BeSortedSound.play(.aiRead)
                        }
                    } else {
                        stoppedUpdatingVisual = true
                        if letters % 2 == 1 {
                            BeSortedSound.play(.aiRead)
                        }
                    }
                } else if globalCharIndex % 3 == 0 {
                    BeSortedSound.play(.aiRead)
                }

                // AI dalej „czyta” resztę w tle (timing), nawet bez widocznego pogrubienia.
                try? await Task.sleep(nanoseconds: max(letterDelay, 10_000_000))
            }

            // Newline też zużywa budżet widoczności.
            globalCharIndex += 1
        }

        guard readingToken == token else { return }
        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.smooth(duration: 0.2)) {
            isReading = false
        }
    }

    private func generateBreakdown() async {
        isGenerating = true
        errorMessage = nil
        do {
            let result = try await BeSortedAIService.breakDownTask(task)
            withAnimation(.smooth(duration: 0.3)) {
                points = result.isEmpty ? ["Brak konkretnych punktów — spróbuj wygenerować nową listę.".l10n] : result
                showResults = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private func regenerateBreakdown() async {
        showResults = true
        await generateBreakdown()
    }
}

struct ProjectDetailsWordRevealView: View {
    let words: [String]
    let revealedCount: Int
    let textColor: Color

    var body: some View {
        ProjectDetailsWordFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(words.prefix(revealedCount).enumerated()), id: \.offset) { _, word in
                Text(word)
                    .font(.body)
                    .foregroundStyle(textColor)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.22), value: revealedCount)
    }
}

/// Poświata / aura używana przy skanie AI po kafelkach (delikatniejsza).
private struct AIAmbientGlowModifier: ViewModifier {
    var intensity: Double
    var tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.22 * intensity))
                    .blur(radius: 12 + 6 * intensity)
                    .scaleEffect(1.04 + 0.02 * intensity)
                    .opacity(intensity)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.45 * intensity),
                                tint.opacity(0.55 * intensity),
                                Color.white.opacity(0.30 * intensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8 + 1.2 * intensity
                    )
                    .blur(radius: 0.3)
                    .opacity(intensity)
                    .allowsHitTesting(false)
            }
            .shadow(color: tint.opacity(0.48 * intensity), radius: 12 + 8 * intensity, y: 0)
            .shadow(color: Color.white.opacity(0.28 * intensity), radius: 8 + 5 * intensity, y: 0)
            .shadow(color: tint.opacity(0.28 * intensity), radius: 18 + 8 * intensity, y: 0)
    }
}

/// Tekst chwilowo przechodzi w gradient (kolor motywu → kolor czcionki).
private struct AIThemeTextPulseModifier: ViewModifier {
    var intensity: Double
    var themeColor: Color
    var fontColor: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(fontColor)
            .overlay {
                content
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeColor, fontColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(intensity)
                    .allowsHitTesting(false)
            }
    }
}

private extension View {
    func aiAmbientGlow(intensity: Double, tint: Color) -> some View {
        modifier(AIAmbientGlowModifier(intensity: intensity, tint: tint))
    }

    func aiThemeTextPulse(intensity: Double, themeColor: Color, fontColor: Color) -> some View {
        modifier(AIThemeTextPulseModifier(intensity: intensity, themeColor: themeColor, fontColor: fontColor))
    }
}

struct ProjectDetailsAIReadingView: View {
    let text: String
    let activeLineIndex: Int
    let activeLetterCount: Int
    let textColor: Color
    var font: Font = .body
    var boldFont: Font = .body.weight(.black)
    var lineLimit: Int? = nil

    var body: some View {
        Text(readingAttributed)
            .font(font)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.06), value: activeLineIndex)
            .animation(.easeInOut(duration: 0.06), value: activeLetterCount)
    }

    private var readingAttributed: AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = textColor
        attributed.font = font

        let lines = text.components(separatedBy: .newlines)
        guard activeLineIndex >= 0, activeLineIndex < lines.count else { return attributed }

        var utf16Offset = 0
        for (index, line) in lines.enumerated() {
            defer {
                utf16Offset += line.utf16.count
                if index < lines.count - 1 {
                    utf16Offset += 1 // newline
                }
            }
            guard index == activeLineIndex else { continue }

            let boldCount = min(max(activeLetterCount, 0), line.count)
            guard boldCount > 0 else { continue }

            let lineStart = String.Index(utf16Offset: utf16Offset, in: text)
            let boldEndStringIndex = text.index(lineStart, offsetBy: boldCount)
            guard let attrStart = AttributedString.Index(lineStart, within: attributed),
                  let attrEnd = AttributedString.Index(boldEndStringIndex, within: attributed)
            else { continue }

            attributed[attrStart..<attrEnd].font = boldFont
            attributed[attrStart..<attrEnd].foregroundColor = textColor
        }

        return attributed
    }
}

private struct ProjectDetailsWordFlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            maxX = max(maxX, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth.isFinite ? maxWidth : maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

struct ForgottenProjectProposalOverlay: View {
    let suggestion: SmartAssistantLocalRuntime.ForgottenProjectSuggestion
    var onApprove: () -> Void
    var onReject: () -> Void

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        DropInModalChrome(onClose: onReject) { requestClose in
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text("Zapomniany projekt".l10n)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: requestClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .besortedGlass(appearance, interactive: true, in: .circle)
                }

                ProjectTileView(project: suggestion.project)
                    .allowsHitTesting(false)
                    .shadow(
                        color: appearance.isFlatDesign ? .clear : Color.black.opacity(0.22),
                        radius: appearance.isFlatDesign ? 0 : 18,
                        x: 0,
                        y: appearance.isFlatDesign ? 0 : 8
                    )

                ScrollView {
                    AIFormattedResultText(
                        text: suggestion.rationaleMarkdown,
                        primary: appearance.primaryText,
                        secondary: appearance.secondaryText
                    )
                }
                .frame(maxHeight: BeSortedScreen.height * 0.36)

                HStack(spacing: 10) {
                    Button(action: requestClose) {
                        Text("Anuluj".l10n)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appearance.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .besortedAdaptiveGlassButton(appearance)
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)

                    Button(action: onApprove) {
                        Text("Priorytetyzuj".l10n)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appearance.selectedTabForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                }
            }
            .padding(20)
            .frame(maxWidth: min(BeSortedScreen.width - 20, 520))
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.9),
                in: .rect(cornerRadius: 22),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
                role: .content
            )
            .padding(.horizontal, 12)
        }
    }
}

struct ProposedTasksReviewOverlay: View {
    let tasks: [ProposedTaskDraft]
    var onApprove: () -> Void
    var onReject: () -> Void

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        DropInModalChrome(onClose: onReject) { requestClose in
            VStack(alignment: .leading, spacing: 14) {
                Text("Propozycje AI".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)

                Text("7 kluczowych elementów projektu".l10n)
                    .font(.footnote)
                    .foregroundStyle(appearance.secondaryText)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(index + 1). \(task.name)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(appearance.primaryText)
                                    Spacer()
                                    Text(task.kind.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(appearance.tertiaryText)
                                }
                                if !task.details.isEmpty {
                                    Text(task.details)
                                        .font(.footnote)
                                        .foregroundStyle(appearance.secondaryText)
                                }
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= task.importance ? "star.fill" : "star")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(star <= task.importance ? Color.yellow : appearance.starEmpty)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .besortedGlass(
                                appearance,
                                tint: appearance.tileTint.opacity(0.75),
                                in: .rect(cornerRadius: 14),
            role: .content
                            )
                        }
                    }
                }
                .frame(maxHeight: 360)

                HStack(spacing: 10) {
                    Button(action: requestClose) {
                        Text("Odrzuć".l10n)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .besortedAdaptiveGlassButton(appearance)

                    Button(action: onApprove) {
                        Text("Zatwierdź".l10n)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(appearance.selectedTabForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
                }
            }
            .padding(18)
            .frame(maxWidth: 420)
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.9),
                in: .rect(cornerRadius: 22),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
            )
            .padding(.horizontal, 20)
        }
    }
}

/// Środkowe kółko z trzema podskakującymi kropkami podczas streszczania projektu.
struct ProjectSummarizeDotsLoader: View {
    @Environment(AppAppearance.self) private var appearance

    @State private var bounceIndex = 0
    @State private var bounceTask: Task<Void, Never>?

    private let circleSize: CGFloat = 78
    private let dotSize: CGFloat = 8

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())

            circleChrome
                .frame(width: circleSize, height: circleSize)
                .overlay {
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(appearance.primaryText.opacity(0.92))
                                .frame(width: dotSize, height: dotSize)
                                .offset(y: bounceIndex == index ? -8 : 0)
                        }
                    }
                }
        }
        .onAppear { startBouncing() }
        .onDisappear {
            bounceTask?.cancel()
            bounceTask = nil
        }
    }

    @ViewBuilder
    private var circleChrome: some View {
        if appearance.usesFullLiquidGlass {
            Color.clear
                .besortedGlass(
                    appearance,
                    interactive: false,
                    tint: appearance.tileTint.opacity(0.92),
                    in: Circle(),
                    minimumFrost: AppAppearance.panelGlassMinimumFrost,
                    role: .content
                )
        } else {
            Circle()
                .fill(appearance.opaqueModalFill)
                .overlay {
                    if !appearance.isFlatDesign {
                        Circle()
                            .strokeBorder(appearance.primaryText.opacity(0.12), lineWidth: 1)
                    }
                }
                .shadow(
                    color: appearance.isFlatDesign ? .clear : .black.opacity(0.18),
                    radius: appearance.isFlatDesign ? 0 : 16,
                    y: appearance.isFlatDesign ? 0 : 6
                )
        }
    }

    private func startBouncing() {
        bounceTask?.cancel()
        bounceTask = Task { @MainActor in
            while !Task.isCancelled {
                for index in 0..<3 {
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.20)) {
                        bounceIndex = index
                    }
                    try? await Task.sleep(nanoseconds: 210_000_000)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppAppearance())
        .modelContainer(for: [Project.self, ProjectTask.self, ProjectBug.self], inMemory: true)
}
