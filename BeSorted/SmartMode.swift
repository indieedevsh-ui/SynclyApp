//
//  SmartMode.swift
//  BeSorted
//

import SwiftUI
import UIKit

enum SmartScrollDirection {
    case up
    case down
}

enum SmartPillPanel: Equatable {
    case none
    case options
    case ai
    case sort
    case search
    case delete
}

/// Most między pastylką Smart Mode a widokami zakładek (akcje chrome / scroll).
@Observable
final class SmartChrome {
    var scrollToken = 0
    var scrollDirection: SmartScrollDirection = .down
    /// 0 = pełna pastylka, 1 = mini bez ikon (gdy włączone chowanie przy scrollu).
    var menuPillCollapseProgress: CGFloat = 0

    /// Zapytanie wyszukiwania (Moje projekty) — pastylka ↔ lista.
    var searchQuery = ""
    /// Dolna lupa (Moje projekty) — rozwinięta pastylka wyszukiwania.
    var isProjectsSearchExpanded = false
    var projectsDeleteActive = false
    var detailDeleteActive = false
    var deleteSelectionCount = 0

    var projectsAddToken = 0
    var projectsAIAnalyzeToken = 0
    var projectsForgottenToken = 0
    var projectsSortDateToken = 0
    var projectsSortImportanceToken = 0
    var projectsConfirmDeleteToken = 0
    var detailConfirmDeleteToken = 0

    /// Loader AI / pełny cover — chowa pastylkę Smart Mode.
    var blocksSmartPill = false
    /// Overlay projektu (rdzeń / pliki) — chowa pasek zakładek i pastylkę.
    var blocksBottomChrome = false

    /// Okienko Smart Assistant (nad paskiem zakładek w ContentView).
    var showSmartAssistantActivate = false
    /// Wymusza świeżą instancję overlayu przy każdym otwarciu (naprawa „nie da się otworzyć drugi raz”).
    var smartAssistantActivateEpoch = 0
    /// Sesja prezentacji — opóźnione onClose ze starego okienka nie zamyka nowego.
    var smartAssistantActivatePresentID = 0
    /// Inkrementowane po odblokowaniu Pro — Settings odpala animację reveal.
    var smartAssistantProUnlockToken = 0
    /// Okienko „ulepsz model” po kliknięciu niedostępnej operacji AI.
    var smartAssistantUpgradeSkill: SmartAssistantSkill?

    var planAIToken = 0
    var planAddToken = 0

    var projectDetailContextToken = 0
    var projectDetailCoreToken = 0
    var projectDetailAddNoteToken = 0
    var projectDetailSortDateToken = 0
    var projectDetailSortImportanceToken = 0
    var projectDetailAISummarizeToken = 0
    var projectDetailAIProposeToken = 0
    var projectDetailAIRemindToken = 0
    var projectDetailAIWhatNowToken = 0
    var projectDetailAIEvaluateToken = 0

    func scroll(_ direction: SmartScrollDirection) {
        scrollDirection = direction
        scrollToken += 1
        BeSortedSound.play(.regular)
        SmartScrollRegistry.shared.scroll(direction)
    }

    func projectsAdd() { projectsAddToken += 1; BeSortedSound.play(.regular) }
    func projectsAIAnalyze() { projectsAIAnalyzeToken += 1; BeSortedSound.play(.ai) }
    func projectsForgotten() { projectsForgottenToken += 1; BeSortedSound.play(.ai) }

    func applyProjectsSortDate() { projectsSortDateToken += 1; BeSortedSound.play(.regular) }
    func applyProjectsSortImportance() { projectsSortImportanceToken += 1; BeSortedSound.play(.regular) }

    func beginProjectsDelete() {
        detailDeleteActive = false
        projectsDeleteActive = true
        deleteSelectionCount = 0
        BeSortedSound.play(.regular)
    }

    func cancelProjectsDelete() {
        projectsDeleteActive = false
        deleteSelectionCount = 0
        BeSortedSound.play(.regular)
    }

    func confirmProjectsDelete() {
        projectsConfirmDeleteToken += 1
        BeSortedSound.play(.regular)
    }

    func beginDetailDelete() {
        projectsDeleteActive = false
        detailDeleteActive = true
        deleteSelectionCount = 0
        BeSortedSound.play(.regular)
    }

    func cancelDetailDelete() {
        detailDeleteActive = false
        deleteSelectionCount = 0
        BeSortedSound.play(.regular)
    }

    func confirmDetailDelete() {
        detailConfirmDeleteToken += 1
        BeSortedSound.play(.regular)
    }

    func planAI() { planAIToken += 1; BeSortedSound.play(.ai) }
    func planAdd() { planAddToken += 1; BeSortedSound.play(.regular) }

    func projectDetailContext() { projectDetailContextToken += 1; BeSortedSound.play(.regular) }
    func projectDetailCore() { projectDetailCoreToken += 1; BeSortedSound.play(.regular) }
    func projectDetailAddNote() { projectDetailAddNoteToken += 1; BeSortedSound.play(.regular) }
    func applyDetailSortDate() { projectDetailSortDateToken += 1; BeSortedSound.play(.regular) }
    func applyDetailSortImportance() { projectDetailSortImportanceToken += 1; BeSortedSound.play(.regular) }
    func projectDetailAISummarize() { projectDetailAISummarizeToken += 1; BeSortedSound.play(.ai) }
    func projectDetailAIPropose() { projectDetailAIProposeToken += 1; BeSortedSound.play(.ai) }
    func projectDetailAIRemind() { projectDetailAIRemindToken += 1; BeSortedSound.play(.ai) }
    func projectDetailAIWhatNow() { projectDetailAIWhatNowToken += 1; BeSortedSound.play(.ai) }
    func projectDetailAIEvaluate() { projectDetailAIEvaluateToken += 1; BeSortedSound.play(.ai) }

    func presentSmartAssistantUpgrade(for skill: SmartAssistantSkill) {
        withAnimation(.smooth(duration: 0.32)) {
            smartAssistantUpgradeSkill = skill
        }
        BeSortedSound.play(.regular)
    }

    func dismissSmartAssistantUpgrade() {
        withAnimation(.smooth(duration: 0.28)) {
            smartAssistantUpgradeSkill = nil
        }
    }

    func presentSmartAssistantActivate() {
        smartAssistantActivatePresentID += 1
        smartAssistantActivateEpoch += 1
        // Jeśli flaga została „zawieszona” na true (niewidoczne / zablokowane okienko),
        // wymuś remount: false → true, żeby Binding i `.id(epoch)` zawsze zadziałały.
        if showSmartAssistantActivate {
            showSmartAssistantActivate = false
            DispatchQueue.main.async {
                withAnimation(.smooth(duration: 0.32)) {
                    self.showSmartAssistantActivate = true
                }
            }
        } else {
            withAnimation(.smooth(duration: 0.32)) {
                showSmartAssistantActivate = true
            }
        }
    }

    func dismissSmartAssistantActivate(onlyIfPresentID: Int? = nil) {
        if let onlyIfPresentID, onlyIfPresentID != smartAssistantActivatePresentID {
            return
        }
        withAnimation(.smooth(duration: 0.28)) {
            showSmartAssistantActivate = false
        }
    }
}

/// Rejestr widocznych UIScrollView — strzałki Smart Mode przewijają aktywny scroll.
@MainActor
final class SmartScrollRegistry {
    static let shared = SmartScrollRegistry()

    private var views = NSHashTable<UIScrollView>.weakObjects()
    private var offsetObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    /// Aktualizacja kolapsu pastylki (contentOffset.y) — backup; główne źródło to `trackTabHeaderSolidProgress`.
    var onContentOffsetYChange: ((CGFloat) -> Void)?

    func register(_ scrollView: UIScrollView) {
        views.add(scrollView)
        let id = ObjectIdentifier(scrollView)
        guard offsetObservations[id] == nil else { return }
        offsetObservations[id] = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
            let y = scroll.contentOffset.y
            DispatchQueue.main.async {
                guard let self else { return }
                // Tylko aktywny / największy scroll — unikaj kolizji z ukrytymi listami.
                if let best = self.bestScrollView(), best !== scroll { return }
                self.onContentOffsetYChange?(y)
                // Kolaps pastylki: tylko `trackTabHeaderSolidProgress` (bez podwójnego update z KVO).
            }
        }
        // Posprzątaj martwe obserwacje.
        let liveIDs = Set(views.allObjects.map { ObjectIdentifier($0) })
        for key in offsetObservations.keys where !liveIDs.contains(key) {
            offsetObservations[key]?.invalidate()
            offsetObservations[key] = nil
        }
    }

    func scroll(_ direction: SmartScrollDirection) {
        guard let scrollView = bestScrollView() else { return }
        let page = max(scrollView.bounds.height * 0.72, 140)
        let delta: CGFloat = direction == .down ? page : -page
        let maxY = max(
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom,
            0
        )
        let minY: CGFloat = -scrollView.adjustedContentInset.top
        let nextY = min(max(scrollView.contentOffset.y + delta, minY), maxY)
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: nextY),
            animated: true
        )
    }

    /// Offset aktywnego scrolla (do synchronizacji pastylki po zmianie zakładki).
    func currentContentOffsetY() -> CGFloat? {
        bestScrollView()?.contentOffset.y
    }

    /// Czy aktywna lista w ogóle da się przewinąć (także lista z małą liczbą kafelków,
    /// która dzięki `alwaysBounce` nadal reaguje na gest — scroll nie jest „zablokowany").
    func activeScrollCanScroll() -> Bool {
        guard let scroll = bestScrollView() else { return false }
        return isScrollable(scroll)
    }

    private func isScrollable(_ scroll: UIScrollView) -> Bool {
        if scroll.contentSize.height > scroll.bounds.height + 8 { return true }
        return scroll.alwaysBounceVertical
    }

    private func bestScrollView() -> UIScrollView? {
        let candidates = views.allObjects.filter { scroll in
            guard scroll.window != nil, !scroll.isHidden, scroll.alpha > 0.05 else { return false }
            guard scroll.bounds.height > 80, scroll.bounds.width > 80 else { return false }
            return isScrollable(scroll)
        }

        if let preferred = candidates.max(by: {
            ($0.bounds.width * $0.bounds.height) < ($1.bounds.width * $1.bounds.height)
        }) {
            return preferred
        }

        guard let window = keyWindow else { return nil }
        var found: [UIScrollView] = []
        collectScrollViews(from: window, into: &found)
        return found
            .filter {
                $0.bounds.height > 120
                    && isScrollable($0)
                    && !($0 is UITextView)
            }
            .max(by: { ($0.bounds.width * $0.bounds.height) < ($1.bounds.width * $1.bounds.height) })
    }

    private func collectScrollViews(from view: UIView, into result: inout [UIScrollView]) {
        if let scroll = view as? UIScrollView {
            result.append(scroll)
        }
        for child in view.subviews {
            collectScrollViews(from: child, into: &result)
        }
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

/// Ukryty sensor w treści ScrollView — rejestruje UIScrollView do Smart Mode.
struct SmartScrollSensor: UIViewRepresentable {
    var token: Int = 0
    var direction: SmartScrollDirection = .down

    func makeUIView(context: Context) -> UIView {
        let view = RegistrarView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? RegistrarView)?.registerIfPossible()
        _ = token
        _ = direction
    }

    final class RegistrarView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            registerIfPossible()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            registerIfPossible()
        }

        func registerIfPossible() {
            if let scroll = enclosingScrollView() {
                SmartScrollRegistry.shared.register(scroll)
            }
        }

        private func enclosingScrollView() -> UIScrollView? {
            var node: UIView? = self
            while let current = node {
                if let scroll = current as? UIScrollView { return scroll }
                node = current.superview
            }
            return nil
        }
    }
}

struct SmartModeMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let keepsPanelOpen: Bool
    let isLocked: Bool
    let action: () -> Void

    init(
        id: String,
        title: String,
        systemImage: String,
        keepsPanelOpen: Bool = false,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.keepsPanelOpen = keepsPanelOpen
        self.isLocked = isLocked
        self.action = action
    }
}

/// Pastylka Liquid Glass: swipe zakładek, tap menu, double-tap AI, long-press scroll.
struct SmartModePillBar: View {
    @Binding var selectedTab: AppTab
    @Binding var projectDetailTab: ProjectDetailTab
    var isInProjectDetail: Bool
    var canGoBack: Bool
    var onGoBack: () -> Void

    @Environment(AppAppearance.self) private var appearance
    @Environment(SmartChrome.self) private var chrome

    @State private var panel: SmartPillPanel = .none
    @State private var isScrollMode = false
    @State private var dragOffset: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    @FocusState private var isSearchFocused: Bool

    private var pillGlassTint: Color {
        Color.white.opacity(0.22 + appearance.glassFrost * 0.38)
    }

    private var pillForeground: Color {
        if appearance.glassFrost < 0.22 {
            return appearance.primaryText
        }
        return Color.black.opacity(0.82)
    }

    private var stretchPadding: CGFloat {
        min(abs(dragOffset) * 0.32, 42)
    }

    private var verticalStretch: CGFloat {
        min(abs(min(dragOffsetY, 0)) * 0.22, 28)
    }

    private var menuPillCollapse: CGFloat {
        appearance.collapsingMenuPill ? chrome.menuPillCollapseProgress : 0
    }

    /// Widoczność napisu w pastylce Smart Mode (ikonka zostaje w mini formie).
    private var menuPillTitleOpacity: CGFloat {
        max(0, 1 - menuPillCollapse * 1.55)
    }

    /// W zadaniu planu nie przełączamy zakładek w bok — tylko swipe w górę.
    private var allowsHorizontalTabSwipe: Bool {
        !canGoBack || isInProjectDetail
    }

    private var showsScrim: Bool {
        // W trybie usuwania NIE blokuj listy — tapnięcia mają zaznaczać projekty.
        // Wyjście tylko przez X.
        isScrollMode
            || panel == .options
            || panel == .ai
            || panel == .sort
            || panel == .search
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsScrim {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture { dismissOverlay() }
            } else {
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 10) {
                panelChrome
                    .animation(.smooth(duration: 0.3), value: panel)
                    .opacity(menuPillCollapse > 0.55 ? 0 : 1)
                    .allowsHitTesting(menuPillCollapse < 0.55)

                Group {
                    // Podczas usuwania pastylka zostaje — nie zamieniaj na strzałki scroll.
                    if isScrollMode && panel != .delete {
                        scrollArrows
                    } else {
                        navigationPill
                    }
                }
                .scaleEffect(
                    x: 1 - 0.36 * menuPillCollapse,
                    y: 1 - 0.26 * menuPillCollapse,
                    anchor: .bottom
                )
                .animation(.spring(response: 0.46, dampingFraction: 0.58), value: menuPillCollapse)
                .animation(.smooth(duration: 0.32), value: isScrollMode)
            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.smooth(duration: 0.3), value: panel)
        .onChange(of: selectedTab) { _, _ in
            hardResetPanel()
        }
        .onChange(of: projectDetailTab) { _, _ in
            hardResetPanel()
        }
        .onChange(of: isInProjectDetail) { _, _ in
            hardResetPanel()
        }
        .onChange(of: chrome.projectsDeleteActive) { _, active in
            if !active, panel == .delete, !isInProjectDetail {
                withAnimation(.smooth(duration: 0.28)) {
                    panel = .none
                }
            }
        }
        .onChange(of: chrome.detailDeleteActive) { _, active in
            if !active, panel == .delete, isInProjectDetail {
                withAnimation(.smooth(duration: 0.28)) {
                    panel = .none
                }
            }
        }
        .onChange(of: panel) { _, newValue in
            if newValue == .search {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    isSearchFocused = true
                }
            } else {
                isSearchFocused = false
            }
        }
    }

    @ViewBuilder
    private var panelChrome: some View {
        switch panel {
        case .none:
            EmptyView()
        case .delete:
            deleteChrome
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom))
                ))
        case .options:
            smartMenu(items: optionsMenuItems)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
        case .ai:
            smartMenu(items: aiMenuItems)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
        case .sort:
            smartMenu(items: sortMenuItems)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
        case .search:
            searchPill(
                text: Binding(
                    get: { chrome.searchQuery },
                    set: { chrome.searchQuery = $0 }
                )
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
        }
    }

    private func dismissOverlay() {
        withAnimation(.smooth(duration: 0.28)) {
            switch panel {
            case .delete:
                // Tylko przycisk X kończy usuwanie — scrim tego nie robi.
                break
            case .search:
                panel = .none
            case .sort, .options, .ai:
                panel = .none
            case .none:
                break
            }
            isScrollMode = false
        }
    }

    private func hardResetPanel() {
        withAnimation(.smooth(duration: 0.2)) {
            if panel == .delete {
                if isInProjectDetail {
                    chrome.cancelDetailDelete()
                } else {
                    chrome.cancelProjectsDelete()
                }
            }
            panel = .none
            isScrollMode = false
            dragOffset = 0
            dragOffsetY = 0
            isSearchFocused = false
        }
    }

    private var navigationPill: some View {
        HStack(spacing: 8) {
            if let asset = currentAssetImageName {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 16)
            } else {
                Image(systemName: currentSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(pillForeground)
            }

            if menuPillTitleOpacity > 0.05 {
                Text(currentTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(pillForeground)
                    .lineLimit(1)
                    .opacity(menuPillTitleOpacity)
            }
        }
        .padding(.leading, menuPillCollapse > 0.65 ? 16 : (22 + (dragOffset < 0 ? stretchPadding : 0)))
        .padding(.trailing, menuPillCollapse > 0.65 ? 16 : (22 + (dragOffset > 0 ? stretchPadding : 0)))
        .frame(height: 52)
        .frame(minWidth: menuPillCollapse > 0.65 ? 72 : nil)
        .background(alignment: .bottom) {
            Color.clear
                .frame(height: 52 + verticalStretch)
                .frame(maxWidth: .infinity)
                .besortedGlass(
                    appearance,
                    interactive: true,
                    tint: pillGlassTint,
                    in: .capsule
                )
        }
        .offset(x: dragOffset * 0.1, y: min(dragOffsetY * 0.28, 0))
        // Bez animacji przy drag — spring tylko w onEnded (płynniej i taniej dla glass).
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.12),
            radius: appearance.isFlatDesign ? 0 : 8,
            y: appearance.isFlatDesign ? 0 : 2
        )
        .gesture(pillDragGesture)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.0)
                .onEnded { _ in
                    guard panel == .none || panel == .options else { return }
                    BeSortedSound.play(.regular)
                    withAnimation(.smooth(duration: 0.32)) {
                        panel = .none
                        isScrollMode = true
                    }
                }
        )
        .onTapGesture(count: 2) {
            handleDoubleTapAI()
        }
        .onTapGesture(count: 1) {
            handleSingleTap()
        }
    }

    private var scrollArrows: some View {
        HStack(spacing: 14) {
            Button {
                chrome.scroll(.up)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(pillForeground)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(BeSortedPlainButtonStyle())

            Button {
                chrome.scroll(.down)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(pillForeground)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: pillGlassTint,
            in: .capsule
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.12),
            radius: appearance.isFlatDesign ? 0 : 8,
            y: appearance.isFlatDesign ? 0 : 2
        )
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    private func searchPill(text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pillForeground)

            TextField(
                "",
                text: text,
                prompt: Text("Szukaj".l10n).foregroundStyle(pillForeground.opacity(0.45))
            )
            .focused($isSearchFocused)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(pillForeground)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(pillForeground.opacity(0.55))
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .frame(width: 260, height: 52)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: pillGlassTint,
            in: .capsule
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.12),
            radius: appearance.isFlatDesign ? 0 : 8,
            y: appearance.isFlatDesign ? 0 : 2
        )
    }

    private var deleteChrome: some View {
        HStack(spacing: 8) {
            if chrome.deleteSelectionCount > 0 {
                Button {
                    if isInProjectDetail {
                        chrome.confirmDetailDelete()
                    } else {
                        chrome.confirmProjectsDelete()
                    }
                } label: {
                    Text("Usuń".l10n)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.25))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Button {
                withAnimation(.smooth(duration: 0.28)) {
                    if isInProjectDetail {
                        chrome.cancelDetailDelete()
                    } else {
                        chrome.cancelProjectsDelete()
                    }
                    panel = .none
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(pillForeground)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: pillGlassTint,
            in: .capsule
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.12),
            radius: appearance.isFlatDesign ? 0 : 8,
            y: appearance.isFlatDesign ? 0 : 2
        )
        .animation(.smooth(duration: 0.28), value: chrome.deleteSelectionCount > 0)
    }

    private func smartMenu(items: [SmartModeMenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                Button {
                    if !item.keepsPanelOpen {
                        withAnimation(.smooth(duration: 0.22)) {
                            panel = .none
                        }
                    }
                    item.action()
                } label: {
                    HStack(spacing: 10) {
                        Label(item.title, systemImage: item.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                item.isLocked
                                    ? appearance.quaternaryText
                                    : appearance.primaryText
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if item.isLocked {
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
        }
        .frame(minWidth: 200, maxWidth: 260)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.92),
            in: .rect(cornerRadius: 16),
            minimumFrost: AppAppearance.menuGlassMinimumFrost
        )
        .shadow(
            color: appearance.isFlatDesign ? .clear : .black.opacity(0.22),
            radius: appearance.isFlatDesign ? 0 : 12,
            y: appearance.isFlatDesign ? 0 : 4
        )
    }

    private var pillDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard panel == .none || panel == .options else { return }
                let dx = value.translation.width
                let dy = value.translation.height

                if abs(dx) > abs(dy) * 0.65, allowsHorizontalTabSwipe {
                    dragOffset = dx
                    dragOffsetY = 0
                } else if dy < 0, canGoBack, abs(dy) > abs(dx) * 0.55 {
                    dragOffsetY = dy
                    dragOffset = 0
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                withAnimation(.smooth(duration: 0.34)) {
                    dragOffset = 0
                    dragOffsetY = 0
                }
                guard panel == .none || panel == .options else { return }

                if canGoBack, dy < -56, abs(dy) > abs(dx) {
                    panel = .none
                    onGoBack()
                    return
                }

                guard allowsHorizontalTabSwipe else { return }
                guard abs(dx) > 48, abs(dx) > abs(dy) else { return }
                BeSortedSound.play(.tab)
                withAnimation(.smooth(duration: 0.28)) {
                    panel = .none
                    if dx < 0 {
                        goSwipeLeft()
                    } else {
                        goSwipeRight()
                    }
                }
            }
    }

    private var currentTitle: String {
        if isInProjectDetail {
            return projectDetailTab.title
        }
        return selectedTab.title
    }

    private var currentSymbol: String {
        if isInProjectDetail {
            return projectDetailTab.systemImage
        }
        return selectedTab.systemImage
    }

    private var currentAssetImageName: String? {
        guard !isInProjectDetail else { return nil }
        return selectedTab.assetImageName
    }

    private func handleSingleTap() {
        guard !isScrollMode else { return }
        guard panel == .none || panel == .options || panel == .ai else { return }
        BeSortedSound.play(.regular)
        withAnimation(.smooth(duration: 0.28)) {
            if panel == .options {
                panel = .none
            } else if optionsMenuItems.isEmpty {
                panel = .none
            } else {
                panel = .options
            }
        }
    }

    private func handleDoubleTapAI() {
        guard !isScrollMode else { return }
        guard panel == .none || panel == .options || panel == .ai else { return }

        let items = aiMenuItems
        if items.isEmpty {
            if !isInProjectDetail {
                switch selectedTab {
                case .plan:
                    chrome.planAI()
                case .projects:
                    chrome.projectsAIAnalyze()
                case .settings:
                    break
                }
            }
            withAnimation(.smooth(duration: 0.22)) {
                panel = .none
            }
            return
        }

        BeSortedSound.play(.ai)
        withAnimation(.smooth(duration: 0.28)) {
            panel = .ai
        }
    }

    private var optionsMenuItems: [SmartModeMenuItem] {
        if isInProjectDetail {
            var items: [SmartModeMenuItem] = [
                SmartModeMenuItem(
                    id: "sort",
                    title: "Sortowanie".l10n,
                    systemImage: "arrow.up.arrow.down",
                    keepsPanelOpen: true
                ) {
                    withAnimation(.smooth(duration: 0.3)) {
                        panel = .sort
                    }
                }
            ]
            if projectDetailTab == .tasks {
                items.append(contentsOf: [
                    SmartModeMenuItem(id: "context", title: "Pliki kontekstu".l10n, systemImage: "doc.on.doc.fill") {
                        chrome.projectDetailContext()
                    },
                    SmartModeMenuItem(id: "core", title: "Rdzeń Projektowy".l10n, systemImage: "cube.transparent") {
                        chrome.projectDetailCore()
                    }
                ])
            }
            if projectDetailTab == .futureNote {
                items.insert(
                    SmartModeMenuItem(id: "addNote", title: "Dodaj notatkę".l10n, systemImage: "plus") {
                        chrome.projectDetailAddNote()
                    },
                    at: 0
                )
            }
            items.append(
                SmartModeMenuItem(
                    id: "delete",
                    title: "Usuwanie".l10n,
                    systemImage: "trash",
                    keepsPanelOpen: true
                ) {
                    chrome.beginDetailDelete()
                    withAnimation(.smooth(duration: 0.3)) {
                        isScrollMode = false
                        panel = .delete
                    }
                }
            )
            return items
        }

        switch selectedTab {
        case .projects:
            return [
                SmartModeMenuItem(
                    id: "search",
                    title: "Szukaj".l10n,
                    systemImage: "magnifyingglass",
                    keepsPanelOpen: true
                ) {
                    withAnimation(.smooth(duration: 0.3)) {
                        panel = .search
                    }
                },
                SmartModeMenuItem(
                    id: "sort",
                    title: "Sortowanie".l10n,
                    systemImage: "arrow.up.arrow.down",
                    keepsPanelOpen: true
                ) {
                    withAnimation(.smooth(duration: 0.3)) {
                        panel = .sort
                    }
                },
                SmartModeMenuItem(
                    id: "delete",
                    title: "Usuwanie".l10n,
                    systemImage: "trash",
                    keepsPanelOpen: true
                ) {
                    chrome.beginProjectsDelete()
                    withAnimation(.smooth(duration: 0.3)) {
                        isScrollMode = false
                        panel = .delete
                    }
                },
                SmartModeMenuItem(id: "add", title: "Dodaj projekt".l10n, systemImage: "plus") {
                    chrome.projectsAdd()
                }
            ]
        case .plan:
            return [
                SmartModeMenuItem(id: "add", title: "Dodaj zadanie".l10n, systemImage: "plus") {
                    chrome.planAdd()
                }
            ]
        case .settings:
            return []
        }
    }

    private var sortMenuItems: [SmartModeMenuItem] {
        if isInProjectDetail {
            return [
                SmartModeMenuItem(id: "date", title: "Data dodania".l10n, systemImage: "calendar") {
                    chrome.applyDetailSortDate()
                },
                SmartModeMenuItem(
                    id: "stars",
                    title: "Gwiazdki (od najwyższych)".l10n,
                    systemImage: "star.fill"
                ) {
                    chrome.applyDetailSortImportance()
                }
            ]
        }

        return [
            SmartModeMenuItem(id: "date", title: "Data dodania".l10n, systemImage: "calendar") {
                chrome.applyProjectsSortDate()
            },
            SmartModeMenuItem(
                id: "stars",
                title: "Gwiazdki (od najwyższych)".l10n,
                systemImage: "star.fill"
            ) {
                chrome.applyProjectsSortImportance()
            }
        ]
    }

    private var aiMenuItems: [SmartModeMenuItem] {
        let store = SmartAssistantStore.shared
        if isInProjectDetail {
            switch projectDetailTab {
            case .tasks, .bugs:
                return [
                    SmartModeMenuItem(
                        id: "summarize",
                        title: "Streść projekt".l10n,
                        systemImage: "text.alignleft",
                        isLocked: !store.supports(.summarizeDescription)
                    ) {
                        chrome.projectDetailAISummarize()
                    },
                    SmartModeMenuItem(
                        id: "propose",
                        title: "Zaproponuj zadania".l10n,
                        systemImage: "checklist",
                        isLocked: !store.supports(.proposeTasks)
                    ) {
                        chrome.projectDetailAIPropose()
                    },
                    SmartModeMenuItem(
                        id: "evaluate",
                        title: SmartAssistantSkill.evaluateProject.menuTitle,
                        systemImage: "eyeglasses",
                        isLocked: !store.supports(.evaluateProject)
                    ) {
                        chrome.projectDetailAIEvaluate()
                    }
                ]
            case .futureNote:
                return [
                    SmartModeMenuItem(
                        id: "remind",
                        title: "Przypomnij projekt".l10n,
                        systemImage: "brain.head.profile",
                        isLocked: !store.supports(.remindProject)
                    ) {
                        chrome.projectDetailAIRemind()
                    },
                    SmartModeMenuItem(
                        id: "now",
                        title: "Co mogę zrobić teraz".l10n,
                        systemImage: "bolt.fill",
                        isLocked: !store.supports(.whatCanIDoNow)
                    ) {
                        chrome.projectDetailAIWhatNow()
                    }
                ]
            }
        }

        if !isInProjectDetail, selectedTab == .projects {
            return [
                SmartModeMenuItem(
                    id: "analyze",
                    title: "Streść projekt".l10n,
                    systemImage: "sparkles",
                    isLocked: !store.supports(.summarizeProject)
                ) {
                    chrome.projectsAIAnalyze()
                },
                SmartModeMenuItem(
                    id: "forgotten",
                    title: "Zapomniany projekt".l10n,
                    systemImage: "clock.arrow.circlepath",
                    isLocked: !store.supports(.forgottenProject)
                ) {
                    chrome.projectsForgotten()
                }
            ]
        }

        return []
    }

    private func goSwipeLeft() {
        if isInProjectDetail {
            let all = ProjectDetailTab.allCases
            guard let idx = all.firstIndex(of: projectDetailTab) else { return }
            projectDetailTab = all[(idx - 1 + all.count) % all.count]
        } else {
            switch selectedTab {
            case .settings: selectedTab = .plan
            case .plan: selectedTab = .projects
            case .projects: selectedTab = .settings
            }
        }
    }

    private func goSwipeRight() {
        if isInProjectDetail {
            let all = ProjectDetailTab.allCases
            guard let idx = all.firstIndex(of: projectDetailTab) else { return }
            projectDetailTab = all[(idx + 1) % all.count]
        } else {
            switch selectedTab {
            case .projects: selectedTab = .plan
            case .plan: selectedTab = .settings
            case .settings: selectedTab = .projects
            }
        }
    }
}
