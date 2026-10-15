//
//  AppAppearance.swift
//  BeSorted
//

import SwiftUI
import UIKit

enum AppColorTheme: String, CaseIterable, Identifiable {
    case black
    case white
    case orange
    case darkBlue
    case silver
    case lightBlue
    case cherry

    var id: String { rawValue }

    var title: String {
        switch (AppLanguage.stored, self) {
        case (.polish, .black): "Czarny"
        case (.english, .black): "Black"
        case (.polish, .white): "Biały"
        case (.english, .white): "White"
        case (.polish, .orange): "Pomarańczowy"
        case (.english, .orange): "Orange"
        case (.polish, .darkBlue): "Ciemnoniebieski"
        case (.english, .darkBlue): "Dark Blue"
        case (.polish, .silver): "Srebrny"
        case (.english, .silver): "Silver"
        case (.polish, .lightBlue): "Jasnoniebieski"
        case (.english, .lightBlue): "Light Blue"
        case (.polish, .cherry): "Wiśniowy"
        case (.english, .cherry): "Cherry"
        }
    }

    /// Podgląd koloru w ustawieniach (jak finish iPhone Pro).
    var swatchColor: Color {
        switch self {
        case .black: Color(white: 0.08)
        case .white: Color(red: 0.97, green: 0.95, blue: 0.91)
        case .orange: Color(red: 0.93, green: 0.45, blue: 0.18)
        case .darkBlue: Color(red: 0.12, green: 0.24, blue: 0.52)
        case .silver: Color(red: 0.78, green: 0.80, blue: 0.84)
        case .lightBlue: Color(red: 0.55, green: 0.72, blue: 0.88)
        case .cherry: Color(red: 0.62, green: 0.12, blue: 0.22)
        }
    }

    var usesLightContent: Bool {
        switch self {
        case .white, .silver, .lightBlue:
            return true
        case .black, .orange, .darkBlue, .cherry:
            return false
        }
    }
}

/// Styl powierzchni aplikacji względem Liquid Glass.
enum AppGlassStyle: String, CaseIterable, Identifiable {
    case full
    case balanced
    case zero
    case neomorphic

    var id: String { rawValue }

    var title: String {
        switch (AppLanguage.stored, self) {
        case (.polish, .full): "Pełny Liquid Glass"
        case (.english, .full): "Full Liquid Glass"
        case (.polish, .balanced): "Wyważony"
        case (.english, .balanced): "Balanced"
        case (.polish, .zero): "Zero Liquid Glass"
        case (.english, .zero): "Zero Liquid Glass"
        case (.polish, .neomorphic): "Neumorfizm"
        case (.english, .neomorphic): "Neumorphic"
        }
    }

    var subtitle: String {
        switch (AppLanguage.stored, self) {
        case (.polish, .full):
            "Aktualny wygląd — glass na całym UI."
        case (.english, .full):
            "Current look — glass across the whole UI."
        case (.polish, .balanced):
            "Glass na zakładkach, przyciskach i menu. Kafelki, wyniki AI i opcje ustawień są normalne."
        case (.english, .balanced):
            "Glass on tabs, buttons and menus. Tiles, AI results and settings options stay solid."
        case (.polish, .zero):
            "Bez Liquid Glass — solidne powierzchnie wszędzie. Zakładki jako napisy na dole."
        case (.english, .zero):
            "No Liquid Glass — solid surfaces everywhere. Tabs become bottom text labels."
        case (.polish, .neomorphic):
            "Miękkie wypukłe karty, dok zakładek i wklęsły suwak wybranej zakładki — bez twardych krawędzi."
        case (.english, .neomorphic):
            "Soft raised cards, a tab dock and a recessed selected-tab thumb — no hard edges."
        }
    }
}

/// Rola powierzchni: chrome zawsze może mieć glass; content tylko w trybie pełnym.
enum BesortedGlassRole {
    case chrome
    case content
    /// Kafelki list — zawsze solid (bez glassEffect), żeby pastylka/scroll nie „rozlewały” szerokości.
    case listTile
}

/// Lekkie trzęsienie kafelków (tryb usuń / pick): wspólny zegar, żeby LazyVStack
/// nie gubił animacji przy scrollu. Offset w `.overlay` — bez owijania layoutu
/// (TimelineView jako rodzic rozciągał kafelki edge-to-edge).
struct SoftWiggleModifier: ViewModifier {
    var isActive: Bool
    var amplitude: CGFloat = 2.2
    /// Pełny cykl lewo↔prawo.
    var period: TimeInterval = 0.28

    @State private var offsetX: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: isActive ? offsetX : 0)
            .background {
                TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: !isActive)) { context in
                    Color.clear
                        .frame(width: 0, height: 0)
                        .onChange(of: context.date) { _, date in
                            guard isActive else { return }
                            let t = date.timeIntervalSinceReferenceDate
                            offsetX = CGFloat(sin(t * 2 * Double.pi / period)) * amplitude
                        }
                        .onAppear {
                            guard isActive else { return }
                            let t = context.date.timeIntervalSinceReferenceDate
                            offsetX = CGFloat(sin(t * 2 * Double.pi / period)) * amplitude
                        }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onChange(of: isActive) { _, active in
                if !active { offsetX = 0 }
            }
    }
}

extension View {
    func softWiggle(isActive: Bool, amplitude: CGFloat = 2.2) -> some View {
        modifier(SoftWiggleModifier(isActive: isActive, amplitude: amplitude))
    }
}

/// Czerwona „wash” na zaznaczeniu do usunięcia — bez zmiany tintu glass (unika białego flasha).
enum BesortedDeletionMark {
    static let color = Color(red: 0.78, green: 0.12, blue: 0.14)
    static let opacity: Double = 0.72
}

private struct BesortedDeletionMarkOverlay: ViewModifier {
    var isMarked: Bool
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BesortedDeletionMark.color.opacity(isMarked ? BesortedDeletionMark.opacity : 0))
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.28), value: isMarked)
    }
}

extension View {
    func besortedDeletionMark(_ isMarked: Bool, cornerRadius: CGFloat = 18) -> some View {
        modifier(BesortedDeletionMarkOverlay(isMarked: isMarked, cornerRadius: cornerRadius))
    }
}

private struct ThemePalette {
    var background: Color
    var primaryText: Color
    var secondaryText: Color
    var tertiaryText: Color
    var quaternaryText: Color
    var iconPrimary: Color
    var starEmpty: Color
    var glassTint: Color
    var tileTint: Color
    var priorityTileTint: Color
    var selectedTabTint: Color
    var selectedTabForeground: Color
    var unselectedTabForeground: Color
    var overlayScrim: Color
    var softOverlayScrim: Color
    var fieldFill: Color
    var fieldStroke: Color
    var promptText: Color
    var prominentButtonTint: Color
    var accent: Color
    var preferredScheme: ColorScheme
}

@Observable
final class AppAppearance {
    var glassFrost: Double {
        didSet { scheduleGlassFrostPersist() }
    }

    var theme: AppColorTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// Jedna pastylka zamiast zakładek i przycisków opcji.
    var smartMode: Bool {
        didSet { UserDefaults.standard.set(smartMode, forKey: Keys.smartMode) }
    }

    /// Pastylka menu kurczy się przy scrollu w dół (mini bez ikon); scroll w górę przywraca.
    var collapsingMenuPill: Bool {
        didSet { UserDefaults.standard.set(collapsingMenuPill, forKey: Keys.collapsingMenuPill) }
    }

    /// Zamiast pełnego glass headera — pastylka za tytułem zakładki.
    var minimalistHeader: Bool {
        didSet { UserDefaults.standard.set(minimalistHeader, forKey: Keys.minimalistHeader) }
    }

    /// Język interfejsu (niezależny od języka systemu).
    var language: AppLanguage {
        didSet { AppLanguage.stored = language }
    }

    /// Pełny Liquid Glass vs wyważony (glass tylko na chrome).
    var glassStyle: AppGlassStyle {
        didSet { UserDefaults.standard.set(glassStyle.rawValue, forKey: Keys.glassStyle) }
    }

    /// Maks. liczba zadań w Aktualnym Planie (1…10).
    var planMaxTasks: Int {
        didSet {
            let clamped = CurrentPlanStore.clampedMax(planMaxTasks)
            if planMaxTasks != clamped {
                planMaxTasks = clamped
                return
            }
            CurrentPlanStore.maxActiveTasks = clamped
        }
    }

    /// Kolor lekkiego cienia przy górnej krawędzi paska (Zero Liquid Glass).
    var zeroTabBarEdgeShadow: Color {
        switch theme {
        case .black:
            return Color.white.opacity(0.12)
        case .white:
            return Color(red: 0.90, green: 0.82, blue: 0.68).opacity(0.28)
        case .orange:
            return Color(red: 0.95, green: 0.48, blue: 0.16).opacity(0.18)
        case .darkBlue:
            return Color(red: 0.42, green: 0.62, blue: 1.0).opacity(0.28)
        case .silver:
            return Color(red: 0.72, green: 0.74, blue: 0.78).opacity(0.26)
        case .lightBlue:
            return Color(red: 0.42, green: 0.62, blue: 0.86).opacity(0.20)
        case .cherry:
            return Color(red: 0.72, green: 0.22, blue: 0.32).opacity(0.20)
        }
    }

    var usesFullLiquidGlass: Bool { glassStyle == .full }
    var usesZeroLiquidGlass: Bool { glassStyle == .zero }
    /// Neumorfizm jest solidny (zero glassEffect), więc liczony jako „nie-glass”.
    var usesAnyLiquidGlass: Bool { glassStyle == .full || glassStyle == .balanced }
    var isNeomorphic: Bool { glassStyle == .neomorphic }
    /// „Flat design”: Zero Liquid Glass i Wyważony — elementy bez glass i bez neumorfizmu
    /// są płaskie: bez ramek, bez drop-shadowów i bez inner-shadowów.
    var isFlatDesign: Bool { glassStyle == .zero || glassStyle == .balanced }

    /// W pełni nieprzezroczyste tło paneli / kafli (Zero i Wyważony content).
    var opaqueModalFill: Color {
        theme.usesLightContent ? background : tileTint
    }

    /// Zamienia kolor (nawet z alpha, np. `tileTint.opacity(0.85)`) na w pełni kryjący.
    func fullyOpaque(_ color: Color) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: 1)
        }
        var w: CGFloat = 0
        if ui.getWhite(&w, alpha: &a) {
            return Color(white: Double(w), opacity: 1)
        }
        #endif
        return opaqueModalFill
    }

    init() {
        let storedFrost = UserDefaults.standard.object(forKey: Keys.glassFrost) as? Double
        glassFrost = min(max(storedFrost ?? 0.55, 0), 1)
        let raw = UserDefaults.standard.string(forKey: Keys.theme) ?? AppColorTheme.black.rawValue
        theme = AppColorTheme(rawValue: raw) ?? .black
        smartMode = UserDefaults.standard.bool(forKey: Keys.smartMode)
        collapsingMenuPill = UserDefaults.standard.bool(forKey: Keys.collapsingMenuPill)
        minimalistHeader = UserDefaults.standard.bool(forKey: Keys.minimalistHeader)
        language = AppLanguage.stored
        let styleRaw = UserDefaults.standard.string(forKey: Keys.glassStyle) ?? AppGlassStyle.full.rawValue
        glassStyle = AppGlassStyle(rawValue: styleRaw) ?? .full
        planMaxTasks = CurrentPlanStore.maxActiveTasks
    }

    /// Przywraca motyw, glass, język i Smart Mode — bez modeli Smart Assistant.
    func resetToDefaults() {
        glassFrost = 0.55
        theme = .black
        smartMode = false
        collapsingMenuPill = false
        minimalistHeader = false
        language = .polish
        glassStyle = .full
        planMaxTasks = CurrentPlanStore.defaultMaxActiveTasks
    }

    /// Debounce zapisu frost — suwak nie walcuje UserDefaults przy każdym ticku.
    @ObservationIgnored private var glassFrostPersistWork: DispatchWorkItem?

    private func scheduleGlassFrostPersist() {
        glassFrostPersistWork?.cancel()
        let value = glassFrost
        let work = DispatchWorkItem {
            UserDefaults.standard.set(value, forKey: Keys.glassFrost)
        }
        glassFrostPersistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private enum Keys {
        static let glassFrost = "besorted.glassFrost"
        static let theme = "besorted.colorTheme"
        static let smartMode = "besorted.smartMode"
        static let collapsingMenuPill = "besorted.collapsingMenuPill"
        static let minimalistHeader = "besorted.minimalistHeader"
        static let glassStyle = "besorted.glassStyle"
    }

    // MARK: - Palette

    private var palette: ThemePalette {
        switch theme {
        case .black:
            return ThemePalette(
                background: .black,
                primaryText: .white,
                secondaryText: .white.opacity(0.7),
                tertiaryText: .white.opacity(0.55),
                quaternaryText: .white.opacity(0.45),
                iconPrimary: .white.opacity(0.9),
                starEmpty: .white.opacity(0.3),
                glassTint: Color(white: 0.20),
                tileTint: Color(white: 0.22),
                priorityTileTint: Color(white: 0.42),
                selectedTabTint: .white,
                selectedTabForeground: .black,
                unselectedTabForeground: .white.opacity(0.85),
                overlayScrim: Color.black.opacity(0.65),
                softOverlayScrim: Color.black.opacity(0.45),
                fieldFill: Color.white.opacity(0.08),
                fieldStroke: Color.white.opacity(0.14),
                promptText: .white.opacity(0.45),
                prominentButtonTint: .white.opacity(0.4),
                accent: .white,
                preferredScheme: .dark
            )
        case .white:
            let beige = Color(red: 0.90, green: 0.82, blue: 0.68)
            let beigeSoft = Color(red: 0.93, green: 0.87, blue: 0.76)
            let beigeDeep = Color(red: 0.82, green: 0.72, blue: 0.55)
            return ThemePalette(
                background: Color.white,
                primaryText: .black,
                secondaryText: .black.opacity(0.65),
                tertiaryText: .black.opacity(0.45),
                quaternaryText: .black.opacity(0.38),
                iconPrimary: .black.opacity(0.88),
                starEmpty: .black.opacity(0.25),
                glassTint: beigeSoft,
                tileTint: beigeSoft,
                priorityTileTint: beigeDeep,
                selectedTabTint: beige,
                selectedTabForeground: .black,
                unselectedTabForeground: .black.opacity(0.72),
                overlayScrim: Color.black.opacity(0.28),
                softOverlayScrim: Color.black.opacity(0.18),
                fieldFill: Color.black.opacity(0.06),
                fieldStroke: Color.black.opacity(0.12),
                promptText: .black.opacity(0.4),
                prominentButtonTint: beige,
                accent: beige,
                preferredScheme: .light
            )
        case .orange:
            // Apricot gradient (Pro) — baza #FF9549.
            let accent = Color(red: 0.95, green: 0.48, blue: 0.16)
            return coloredDarkPalette(
                background: Color(red: 1.0, green: 0.584, blue: 0.286),   // #FF9549
                accent: accent,
                tile: Color(red: 0.28, green: 0.12, blue: 0.05),
                priority: Color(red: 0.55, green: 0.28, blue: 0.10)
            )
        case .darkBlue:
            // Deep Blue (Pro) — wyraźniej niebieski, mniej „szary”.
            let accent = Color(red: 0.40, green: 0.58, blue: 1.0)
            return coloredDarkPalette(
                background: Color(red: 0.03, green: 0.08, blue: 0.24),
                accent: accent,
                tile: Color(red: 0.07, green: 0.16, blue: 0.38),
                priority: Color(red: 0.14, green: 0.30, blue: 0.58)
            )
        case .silver:
            // Silver (Pro) — baza gradientu #C3C3C3.
            let accent = Color(red: 0.72, green: 0.74, blue: 0.78)
            return ThemePalette(
                background: Color(red: 0.765, green: 0.765, blue: 0.765),   // #C3C3C3
                primaryText: Color(red: 0.12, green: 0.13, blue: 0.16),
                secondaryText: Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.68),
                tertiaryText: Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.48),
                quaternaryText: Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.38),
                iconPrimary: Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.9),
                starEmpty: Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.28),
                glassTint: Color(red: 0.82, green: 0.84, blue: 0.88),
                tileTint: Color(red: 0.82, green: 0.84, blue: 0.88),
                priorityTileTint: Color(red: 0.68, green: 0.70, blue: 0.76),
                selectedTabTint: accent,
                selectedTabForeground: .black,
                unselectedTabForeground: Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.72),
                overlayScrim: Color.black.opacity(0.25),
                softOverlayScrim: Color.black.opacity(0.16),
                fieldFill: Color.black.opacity(0.05),
                fieldStroke: Color.black.opacity(0.12),
                promptText: Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.4),
                prominentButtonTint: accent,
                accent: accent,
                preferredScheme: .light
            )
        case .lightBlue:
            // Soft / Sky Blue (Pro)
            let accent = Color(red: 0.42, green: 0.62, blue: 0.86)
            return ThemePalette(
                background: Color(red: 0.70, green: 0.82, blue: 0.94),
                primaryText: Color(red: 0.08, green: 0.16, blue: 0.28),
                secondaryText: Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.68),
                tertiaryText: Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.48),
                quaternaryText: Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.38),
                iconPrimary: Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.9),
                starEmpty: Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.28),
                glassTint: Color(red: 0.72, green: 0.84, blue: 0.94),
                tileTint: Color(red: 0.72, green: 0.84, blue: 0.94),
                priorityTileTint: Color(red: 0.52, green: 0.70, blue: 0.88),
                selectedTabTint: accent,
                selectedTabForeground: .white,
                unselectedTabForeground: Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.72),
                overlayScrim: Color.black.opacity(0.24),
                softOverlayScrim: Color.black.opacity(0.15),
                fieldFill: Color.black.opacity(0.05),
                fieldStroke: Color.black.opacity(0.12),
                promptText: Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.4),
                prominentButtonTint: accent,
                accent: accent,
                preferredScheme: .light
            )
        case .cherry:
            // Cosmic Cherry (Pro)
            let accent = Color(red: 0.86, green: 0.28, blue: 0.42)
            return coloredDarkPalette(
                background: Color(red: 0.12, green: 0.03, blue: 0.06),
                accent: accent,
                tile: Color(red: 0.28, green: 0.08, blue: 0.14),
                priority: Color(red: 0.48, green: 0.16, blue: 0.24)
            )
        }
    }

    private func coloredDarkPalette(
        background: Color,
        accent: Color,
        tile: Color,
        priority: Color
    ) -> ThemePalette {
        ThemePalette(
            background: background,
            primaryText: .white,
            secondaryText: .white.opacity(0.72),
            tertiaryText: .white.opacity(0.55),
            quaternaryText: .white.opacity(0.42),
            iconPrimary: .white.opacity(0.92),
            starEmpty: .white.opacity(0.3),
            glassTint: tile,
            tileTint: tile,
            priorityTileTint: priority,
            selectedTabTint: accent,
            selectedTabForeground: .white,
            unselectedTabForeground: .white.opacity(0.82),
            overlayScrim: Color.black.opacity(0.58),
            softOverlayScrim: Color.black.opacity(0.4),
            fieldFill: Color.white.opacity(0.08),
            fieldStroke: Color.white.opacity(0.14),
            promptText: .white.opacity(0.45),
            prominentButtonTint: accent,
            accent: accent,
            preferredScheme: .dark
        )
    }

    // MARK: - Colors

    var background: Color { palette.background }

    /// Jaśniejszy odcień motywu pod headerem (góra bazowego gradientu).
    var backgroundHeader: Color {
        switch theme {
        case .black:
            return Color(white: 0.30)
        case .white:
            // Lekki beżowy u góry → biały u dołu.
            return Color(red: 0.94, green: 0.88, blue: 0.78)
        case .orange:
            return Color(red: 1.0, green: 0.655, blue: 0.506)   // #FFA781
        case .darkBlue:
            return Color(red: 0.10, green: 0.20, blue: 0.46)
        case .silver:
            // Biały u góry → jasnoszary u dołu.
            return Color.white
        case .lightBlue:
            // Jasny błękit u góry → trochę ciemniejszy u dołu.
            return Color(red: 0.82, green: 0.90, blue: 0.98)
        case .cherry:
            return Color(red: 0.34, green: 0.10, blue: 0.16)
        }
    }

    /// Środek przejścia — miękki most między headerem a bazą.
    var backgroundMid: Color {
        switch theme {
        case .black:
            return Color(white: 0.12)
        case .white:
            return Color(red: 0.98, green: 0.95, blue: 0.90)
        case .orange:
            return Color(red: 1.0, green: 0.62, blue: 0.40)
        case .darkBlue:
            return Color(red: 0.05, green: 0.12, blue: 0.32)
        case .silver:
            // Biały u góry → jasnoszary #C3C3C3 u dołu.
            return Color(red: 0.80, green: 0.80, blue: 0.80)
        case .lightBlue:
            return Color(red: 0.76, green: 0.86, blue: 0.96)
        case .cherry:
            return Color(red: 0.20, green: 0.05, blue: 0.09)
        }
    }

    /// Bazowe tło ekranu: jasny odcień motywu u góry → domyślny kolor u dołu.
    var screenBackgroundGradient: LinearGradient {
        let midLocation: CGFloat = theme.usesLightContent ? 0.45 : 0.38
        return LinearGradient(
            stops: [
                .init(color: backgroundHeader, location: 0),
                .init(color: backgroundMid, location: midLocation),
                .init(color: background, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Kolor ikon i podpisów pod suwakiem zakładek — tylko pastylka; na jasnych motywach ciemniejszy.
    var tabSliderAccent: Color {
        switch theme {
        case .white:
            return Color(red: 0.72, green: 0.55, blue: 0.32)
        case .silver:
            return Color(red: 0.42, green: 0.45, blue: 0.52)
        case .lightBlue:
            return Color(red: 0.22, green: 0.42, blue: 0.68)
        default:
            return selectedTabTint
        }
    }

    var primaryText: Color { palette.primaryText }
    var secondaryText: Color { palette.secondaryText }
    var tertiaryText: Color { palette.tertiaryText }
    var quaternaryText: Color { palette.quaternaryText }
    var iconPrimary: Color { palette.iconPrimary }
    var starEmpty: Color { palette.starEmpty }

    /// Zachowane dla kompatybilności (motyw biały / akcenty).
    var beige: Color { palette.accent }
    /// Zero Liquid Glass: pastylka Minimalistycznego Nagłówka — jaśniejszy odcień motywu (nie szary material).
    var minimalistHeaderZeroFill: Color {
        fullyOpaque(backgroundHeader)
    }

    var beigeSoft: Color { palette.tileTint }
    var beigeDeep: Color { palette.priorityTileTint }

    var glassTint: Color { palette.glassTint }
    var tileTint: Color { palette.tileTint }
    var priorityTileTint: Color { palette.priorityTileTint }
    var selectedTabTint: Color { palette.selectedTabTint }
    var selectedTabForeground: Color { palette.selectedTabForeground }
    var unselectedTabForeground: Color { palette.unselectedTabForeground }
    var overlayScrim: Color { palette.overlayScrim }
    var softOverlayScrim: Color { palette.softOverlayScrim }
    var fieldFill: Color { palette.fieldFill }
    var fieldStroke: Color {
        // Flat design: pola są bez ramek.
        guard !isFlatDesign else { return .clear }
        return palette.fieldStroke
    }
    var promptText: Color { palette.promptText }
    var prominentButtonTint: Color { palette.prominentButtonTint }
    var preferredScheme: ColorScheme { palette.preferredScheme }

    // MARK: - Neumorphism

    /// Paleta miękkich cieni dla stylu Neumorfizm (bez twardych krawędzi).
    struct NeoPalette {
        /// Jasny cień „światła” (lewy górny róg wypukłości / dolna wewnętrzna krawędź wklęsłości).
        let highlight: Color
        /// Ciemny cień rzucany (prawy dolny róg wypukłości / górna wewnętrzna krawędź wklęsłości).
        let shadow: Color
        /// Mocniejsza wersja cienia — do wnętrza wklęsłości.
        let shadowStrong: Color
        /// Kolor „studni” wklęsłej pastylki / wciśniętych powierzchni.
        let track: Color
    }

    var neoPalette: NeoPalette {
        // Kolory SoftEmbossed (referencja): surface = wypełnienie kafli,
        // highlight = jasne światło lewa-góra, shadow = ciemny cień prawa-dół.
        switch theme {
        case .black:
            return NeoPalette(
                highlight: Color(red: 0.18, green: 0.19, blue: 0.21).opacity(0.70),
                shadow: Color.black.opacity(0.85),
                shadowStrong: Color.black.opacity(0.92),
                track: Color(white: 0.16)
            )
        case .white:
            return NeoPalette(
                highlight: Color.white.opacity(0.85),
                shadow: Color(red: 0.72, green: 0.68, blue: 0.63).opacity(0.60),
                shadowStrong: Color(red: 0.72, green: 0.68, blue: 0.63).opacity(0.80),
                track: Color(red: 0.86, green: 0.78, blue: 0.62)
            )
case .orange:
            return NeoPalette(
                highlight: Color(red: 0.66, green: 0.40, blue: 0.22).opacity(0.22),
                shadow: Color(red: 0.28, green: 0.15, blue: 0.07).opacity(0.28),
                shadowStrong: Color(red: 0.28, green: 0.15, blue: 0.07).opacity(0.38),
                track: Color(red: 0.25, green: 0.10, blue: 0.03)
            )
        case .darkBlue:
            return NeoPalette(
                highlight: Color(red: 0.11, green: 0.24, blue: 0.47).opacity(0.60),
                shadow: Color.black.opacity(0.75),
                shadowStrong: Color.black.opacity(0.90),
                track: Color(red: 0.05, green: 0.13, blue: 0.34)
            )
        case .silver:
            return NeoPalette(
                highlight: Color.white.opacity(0.90),
                shadow: Color(red: 0.64, green: 0.67, blue: 0.72).opacity(0.60),
                shadowStrong: Color(red: 0.64, green: 0.67, blue: 0.72).opacity(0.80),
                track: Color(red: 0.77, green: 0.79, blue: 0.84)
            )
        case .lightBlue:
            return NeoPalette(
                highlight: Color.white.opacity(0.80),
                shadow: Color(red: 0.36, green: 0.56, blue: 0.75).opacity(0.55),
                shadowStrong: Color(red: 0.36, green: 0.56, blue: 0.75).opacity(0.75),
                track: Color(red: 0.62, green: 0.75, blue: 0.88)
            )
        case .cherry:
            return NeoPalette(
                highlight: Color(red: 0.43, green: 0.13, blue: 0.21).opacity(0.65),
                shadow: Color.black.opacity(0.65),
                shadowStrong: Color.black.opacity(0.85),
                track: Color(red: 0.20, green: 0.055, blue: 0.11)
            )
        }
    }

    var neoHighlight: Color { neoPalette.highlight }
    var neoShadow: Color { neoPalette.shadow }
    var neoShadowStrong: Color { neoPalette.shadowStrong }
    /// Powierzchnia wypukłych kafli (referencja SoftEmbossed `surfaceColor`):
    /// wiśnia → głęboki burgund, jasnoniebieski → nasycony błękit itd.
    /// Elementy rozróżnia miękka poświata: światło z lewej-góry
    /// i ciemny cień z prawej-dołu, nie barwa wypełnienia.
    var neoSurface: Color {
        switch theme {
        case .black:
            return Color(red: 0.10, green: 0.11, blue: 0.12)
        case .white:
            return Color(red: 0.933, green: 0.910, blue: 0.871)
        case .orange:
            return Color(red: 0.76, green: 0.36, blue: 0.16)
        case .darkBlue:
            return Color(red: 0.067, green: 0.153, blue: 0.298)
        case .silver:
            return Color(red: 0.890, green: 0.906, blue: 0.933)
        case .lightBlue:
            return Color(red: 0.608, green: 0.816, blue: 1.0)
        case .cherry:
            return Color(red: 0.282, green: 0.078, blue: 0.129)
        }
    }
    /// Wklęsły chip (referencja `chipBackground`): suwak pastylki, pigułki wartości,
    /// przyciski wyboru — ciemniejszy odcień surface z własnym embossingiem.
    var neoChip: Color {
        switch theme {
        case .black:
            return Color(red: 0.063, green: 0.067, blue: 0.075).opacity(0.90)
        case .white:
            return Color(red: 0.871, green: 0.839, blue: 0.780).opacity(0.85)
        case .orange:
            return Color(red: 0.56, green: 0.26, blue: 0.11).opacity(0.85)
        case .darkBlue:
            return Color(red: 0.039, green: 0.086, blue: 0.169).opacity(0.85)
        case .silver:
            return Color(red: 0.784, green: 0.816, blue: 0.863).opacity(0.80)
        case .lightBlue:
            return Color(red: 0.482, green: 0.698, blue: 0.898).opacity(0.80)
        case .cherry:
            return Color(red: 0.188, green: 0.051, blue: 0.082).opacity(0.85)
        }
    }
    /// Akcent przycisków akcji (referencja `accentRed`): „Aktywuj”, „Resetuj”.
    var neoAccentRed: Color {
        switch theme {
        case .black:
            return Color(red: 0.871, green: 0.216, blue: 0.216)
        case .white:
            return Color(red: 0.722, green: 0.227, blue: 0.227)
        case .orange:
            return Color(red: 0.659, green: 0.145, blue: 0.0)
        case .darkBlue:
            return Color(red: 0.310, green: 0.502, blue: 0.882)
        case .silver:
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        case .lightBlue:
            return Color(red: 0.149, green: 0.388, blue: 0.922)
        case .cherry:
            return Color(red: 0.549, green: 0.114, blue: 0.184)
        }
    }
    var neoRaisedFill: Color { neoSurface }

    /// Tekst wybranego kafelka wyboru w ustawieniach (Neumorfizm): wybrany kafelek
    /// to wklęsły, ciemny chip, więc na motywach ciemnych (czarny/pomarańczowy/
    /// ciemnoniebieski/wiśniowy) tekst musi być biały; na jasnych chipach
    /// (biały/srebrny/błękitny) — tekst motywu. Poza Neumorfizmem wybrany kafelek
    /// ma jasną pastylkę `selectedTabTint`, więc zostaje `selectedTabForeground`.
    var choiceSelectedForeground: Color {
        guard isNeomorphic else { return selectedTabForeground }
        return theme.usesLightContent ? primaryText : Color.white
    }

    /// Ikona neumorfizmu: jaśniejszy odcień wybranego motywu, żeby była czytelna
    /// na pastylce (czarny → jasny szary, pomarańczowy → jasny pomarańcz, jasne → beż).
    var neoIconColor: Color {
        switch theme {
        case .black:
            return Color(white: 0.63)
        case .white:
            return Color(red: 0.54, green: 0.46, blue: 0.32)
        case .orange:
            return Color(red: 0.88, green: 0.48, blue: 0.26)
        case .darkBlue:
            return Color(red: 0.48, green: 0.58, blue: 0.92)
        case .silver:
            return Color(red: 0.55, green: 0.58, blue: 0.66)
        case .lightBlue:
            return Color(red: 0.42, green: 0.62, blue: 0.88)
        case .cherry:
            return Color(red: 0.90, green: 0.22, blue: 0.30)
        }
    }

    /// Powierzchnia toru pastylki zakładek (Neumorfizm): barwa motywu.
    /// Suwak ma ten sam kolor — wyróżnia go embossing + świecąca ikona.
    var neoPillSurface: Color {
        switch theme {
        case .black:
            return Color.black
        case .white:
            // Beż
            return Color(red: 0.93, green: 0.87, blue: 0.76)
        case .orange:
            // Jasny brąz
            return Color(red: 0.72, green: 0.48, blue: 0.28)
        case .darkBlue:
            return Color(red: 0.07, green: 0.16, blue: 0.38)
        case .silver:
            // Jasny szary
            return Color(red: 0.82, green: 0.84, blue: 0.88)
        case .lightBlue:
            return Color(red: 0.72, green: 0.84, blue: 0.94)
        case .cherry:
            // Wiśniowy
            return Color(red: 0.42, green: 0.10, blue: 0.18)
        }
    }

    /// Suwak = dokładnie ten sam kolor co tor pastylki.
    var neoPillThumbFill: Color {
        fullyOpaque(neoPillSurface)
    }

    /// Świecąca ikona aktywnej zakładki (Neumorfizm).
    /// Czarny → biel; biały → jasny beż; pomarańczowy → jasny pomarańcz;
    /// ciemnoniebieski → jasny błękit; srebrny → lekki jasny szary;
    /// jasnoniebieski → jaśniejszy błękit; wiśniowy → intensywna wiśniowa.
    var neoSliderAccent: Color {
        switch theme {
        case .black:
            return .white
        case .white:
            return Color(red: 1.0, green: 0.95, blue: 0.86)
        case .orange:
            return Color(red: 1.0, green: 0.72, blue: 0.50)
        case .darkBlue:
            return Color(red: 0.72, green: 0.82, blue: 1.0)
        case .silver:
            return Color(red: 0.96, green: 0.96, blue: 0.98)
        case .lightBlue:
            return Color(red: 0.92, green: 0.97, blue: 1.0)
        case .cherry:
            return Color(red: 1.0, green: 0.40, blue: 0.48)
        }
    }

    /// Kolor „analizowania” AI dla tekstu / ikon (motyw czarny → jasny szary).
    var aiScanAccent: Color {
        switch theme {
        case .black:
            return Color(white: 0.72)
        default:
            return selectedTabTint
        }
    }

    /// Poświata kafli podczas skanu AI (motyw czarny → biała).
    var aiTileGlowTint: Color {
        switch theme {
        case .black:
            return .white
        default:
            return selectedTabTint
        }
    }

    var glassPercentLabel: String {
        "\(Int((glassFrost * 100).rounded()))%"
    }

    // MARK: - Liquid Glass

    /// Duże okna (pliki kontekstowe, streszczenia itd.) nie schodzą poniżej tego frostu.
    static let panelGlassMinimumFrost: Double = 0.5

    /// Rozwinięty kafelek zadania (focus) — clear/regular wg suwaka, minimum 40%.
    static let focusTileGlassMinimumFrost: Double = 0.40

    /// Pastylka minimalistycznego nagłówka — frost ≥ 40% suwaka.
    static let minimalistHeaderGlassMinimumFrost: Double = 0.40

    /// Mini-menu przycisków (AI / sortowanie / Smart Mode) — frost ≥ 25% suwaka.
    static let menuGlassMinimumFrost: Double = 0.25

    /// Punkty zatrzymania suwaka Liquid Glass.
    static let glassFrostSnapStops: [Double] = [0.25, 0.5, 0.75]

    /// Efektywny frost: suwak, z opcjonalnym minimum (duże panele ≥ 50%).
    func effectiveGlassFrost(minimumFrost: Double = 0) -> Double {
        let slider = min(max(glassFrost, 0), 1)
        let floor = min(max(minimumFrost, 0), 1)
        return max(slider, floor)
    }

    /// 0 = czysty clear, 1 = pełny regular — płynnie w całym zakresie suwaka.
    func glassBlend(minimumFrost: Double = 0) -> Double {
        effectiveGlassFrost(minimumFrost: minimumFrost)
    }

    /// Jedna warstwa `glassEffect` na widoku (kliknięcia / GlassEffectContainer działają).
    /// Tint i materiał zmieniają się płynnie wraz z blendem 0…1.
    func blendedGlass(interactive: Bool, tint: Color?, blend: Double) -> Glass {
        let frost = min(max(blend, 0), 1)
        let baseTint = tint ?? glassTint
        let allowMotion = interactive && frost < 0.78

        if frost <= 0.02 {
            return Glass.clear.interactive(interactive)
        }
        if frost >= 0.98 {
            return Glass.regular.tint(baseTint).interactive(false)
        }

        // Płynne narastanie „mrozu”: najpierw clear z tintem, potem regular z gęstszym tintem.
        if frost < 0.5 {
            let t = frost / 0.5
            return Glass.clear
                .tint(baseTint.opacity(0.04 + 0.42 * t))
                .interactive(allowMotion)
        } else {
            let t = (frost - 0.5) / 0.5
            return Glass.regular
                .tint(baseTint.opacity(0.28 + 0.72 * t))
                .interactive(allowMotion && t < 0.45)
        }
    }
}

extension View {
    /// Glass lub solid — content w balanced/zero.
    func besortedGlass(
        _ appearance: AppAppearance,
        interactive: Bool = false,
        tint: Color? = nil,
        in shape: some Shape,
        minimumFrost: Double = 0,
        role: BesortedGlassRole = .chrome,
        refreshIdentity _: Bool = true,
        cushion: Bool = false
    ) -> some View {
        modifier(
            BesortedGlassSurfaceModifier(
                appearance: appearance,
                interactive: interactive,
                tint: tint,
                shape: shape,
                minimumFrost: minimumFrost,
                role: role,
                cushion: cushion
            )
        )
    }

    /// Wklęsła ramka „wygrawerowanego" tekstu / sekcji (Neumorfizm): ciemny cień w środku
    /// u góry-lewej i światło u dołu-prawej. Poza neumorfizmem — brak zmian (no-op).
    @ViewBuilder
    func besortedNeoCarvedTextFrame(
        _ appearance: AppAppearance,
        cornerRadius: CGFloat = 10
    ) -> some View {
        if appearance.isNeomorphic {
            self
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background {
                    BeSortedNeoCarved(
                        shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                        appearance: appearance,
                        radius: cornerRadius * 0.7,
                        depth: 2
                    )
                }
        } else {
            self
        }
    }

    /// Pigułka wartości w wierszu (referencja: płaski `chipBackground`, bez embossingu).
    /// Poza neumorfizmem — brak zmian (no-op).
    @ViewBuilder
    func besortedNeoRaisedPill(
        _ appearance: AppAppearance,
        cornerRadius: CGFloat = 12
    ) -> some View {
        if appearance.isNeomorphic {
            self
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule(style: .continuous)
                        .fill(appearance.neoChip)
                }
        } else {
            self
        }
    }

    /// Panele modalne / wyniki AI / Smart Assistant: w Wyważonym i Zero — pełne krycie.
    @ViewBuilder
    func besortedSmartAssistantModalPanel(
        _ appearance: AppAppearance,
        cornerRadius: CGFloat = 22
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if appearance.usesFullLiquidGlass {
            self.besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.9),
                in: shape,
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
                role: .content
            )
        } else {
            self
                .background {
                    shape.fill(appearance.opaqueModalFill)
                }
                .overlay {
                    // Flat design: panele bez ramek; neumorfizm zostaje z delikatnym rąbkiem.
                    if !appearance.isFlatDesign {
                        shape.stroke(appearance.primaryText.opacity(0.10), lineWidth: 1)
                    }
                }
                .compositingGroup()
        }
    }

    /// Tło sheetów formularzy: solid zawsze łapie hit-test (Color.clear + lista w tle psuje TextFieldy).
    @ViewBuilder
    func besortedFormSheetChrome(_ appearance: AppAppearance) -> some View {
        let solid = appearance.opaqueModalFill
        self
            .scrollContentBackground(.hidden)
            .background(solid)
            .presentationBackground(solid)
            .contentShape(Rectangle())
            .animation(.smooth(duration: 0.36), value: appearance.glassStyle)
    }

    /// Primary w formularzach: glass tylko w pełnym Liquid Glass.
    @ViewBuilder
    func besortedFormPrimaryButton(_ appearance: AppAppearance) -> some View {
        if appearance.usesFullLiquidGlass {
            self
                .buttonStyle(.glassProminent)
                .besortedClick(.regular)
                .tint(appearance.prominentButtonTint)
        } else if appearance.isNeomorphic {
            self
                .buttonStyle(BeSortedNeoButtonStyle(appearance: appearance, fill: appearance.fullyOpaque(appearance.prominentButtonTint)))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            self
                .buttonStyle(BeSortedPlainButtonStyle())
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(appearance.prominentButtonTint)
                }
        }
    }

    /// Prominent glass → solid w Zero (w balanced/full zostaje glass).
    @ViewBuilder
    func besortedAdaptiveProminentButton(
        _ appearance: AppAppearance,
        tint: Color? = nil
    ) -> some View {
        let buttonTint = tint ?? appearance.prominentButtonTint
        if appearance.usesAnyLiquidGlass {
            self
                .buttonStyle(.glassProminent)
                .besortedClick(.regular)
                .tint(buttonTint)
        } else if appearance.isNeomorphic {
            self
                .buttonStyle(BeSortedNeoButtonStyle(appearance: appearance, fill: appearance.fullyOpaque(buttonTint)))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            self
                .buttonStyle(BeSortedPlainButtonStyle())
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(buttonTint)
                }
                .overlay {
                    flatBeSortedButtonRim(
                        appearance,
                        shape: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// `.glass` / solid zależnie od stylu (zero = zawsze solid).
    func besortedAdaptiveGlassButton(_ appearance: AppAppearance) -> some View {
        modifier(BesortedAdaptiveGlassButtonModifier(appearance: appearance))
    }

    /// Rozszerzanie circle → pastylka: animuje szerokość powierzchni (nie scale treści).
    func liquidGlassExpandingCapsule(
        _ appearance: AppAppearance,
        isExpanded: Bool,
        collapsedWidth: CGFloat = 40,
        expandedWidth: CGFloat,
        height: CGFloat = 40,
        expandedPadding: CGFloat = 6,
        forceSolid: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassExpandingCapsuleModifier(
                appearance: appearance,
                isExpanded: isExpanded,
                collapsedWidth: collapsedWidth,
                expandedWidth: expandedWidth,
                height: height,
                expandedPadding: expandedPadding,
                forceSolid: forceSolid
            )
        )
    }
}

/// Spring jak gęsta ciecz — delikatny start, przyspieszenie, miękkie wyhamowanie.
enum LiquidCapsuleExpansion {
    static let spring = Animation.spring(response: 0.46, dampingFraction: 0.78, blendDuration: 0.12)
    static let settle = Animation.spring(response: 0.40, dampingFraction: 0.88)
    static let jellyKick = Animation.spring(response: 0.26, dampingFraction: 0.55)
}

/// Glass / solid tylko jako tło Capsule; treść zachowuje proporcje podczas rozlewania w poziomie.
private struct LiquidGlassExpandingCapsuleModifier: ViewModifier {
    var appearance: AppAppearance
    var isExpanded: Bool
    var collapsedWidth: CGFloat
    var expandedWidth: CGFloat
    var height: CGFloat
    var expandedPadding: CGFloat
    var forceSolid: Bool

    @State private var jelly: CGFloat = 0

    private var surfaceWidth: CGFloat {
        isExpanded ? expandedWidth : collapsedWidth
    }

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .padding(.horizontal, isExpanded ? expandedPadding : 0)
            .frame(width: surfaceWidth, height: height, alignment: .center)
            .contentShape(Capsule(style: .continuous))
            .background {
                expandingSurface
                    .frame(width: surfaceWidth, height: height)
                    // Lekkie „galaretkowe” rozciągnięcie TYLKO powierzchni, nie ikon/tekstu.
                    .scaleEffect(
                        x: 1 + jelly * 0.07,
                        y: 1 - jelly * 0.035,
                        anchor: .center
                    )
                    .allowsHitTesting(false)
            }
            .animation(LiquidCapsuleExpansion.spring, value: isExpanded)
            .animation(LiquidCapsuleExpansion.spring, value: expandedWidth)
            .onChange(of: isExpanded) { _, _ in
                pulseJelly()
            }
            .onChange(of: expandedWidth) { oldWidth, newWidth in
                guard isExpanded, abs(oldWidth - newWidth) > 0.5 else { return }
                pulseJelly()
            }
    }

    @ViewBuilder
    private var expandingSurface: some View {
        let shape = Capsule(style: .continuous)
        if forceSolid || appearance.usesZeroLiquidGlass {
            shape
                .fill(appearance.fullyOpaque(appearance.tileTint))
                .overlay {
                    flatBeSortedButtonRim(appearance, shape: shape)
                }
        } else if appearance.isNeomorphic {
            BeSortedNeoRaised(shape: shape, appearance: appearance)
        } else {
            shape
                .fill(Color.clear)
                .glassEffect(
                    appearance.blendedGlass(
                        interactive: true,
                        tint: appearance.tileTint.opacity(0.55),
                        blend: appearance.glassBlend(minimumFrost: AppAppearance.menuGlassMinimumFrost)
                    ),
                    in: shape
                )
        }
    }

    private func pulseJelly() {
        withAnimation(LiquidCapsuleExpansion.jellyKick) {
            jelly = 1
        }
        withAnimation(LiquidCapsuleExpansion.settle.delay(0.05)) {
            jelly = 0
        }
    }
}

/// Flat design: elementy bez liquid glass i bez neumorfizmu są płaskie — bez ramek.
func flatBeSortedButtonRim<S: Shape>(_ appearance: AppAppearance, shape: S) -> some View {
    EmptyView()
}

/// Solidny odpowiednik `.glass` w Zero — ta sama ramka co prominent (zaokrąglony prostokąt).
/// Extra padding tylko przy `controlSize` ≠ regular, żeby pary przycisków z własnym paddingiem miały równy rozmiar.
private struct BesortedAdaptiveGlassButtonModifier: ViewModifier {
    var appearance: AppAppearance
    @Environment(\.controlSize) private var controlSize

    func body(content: Content) -> some View {
        if appearance.usesAnyLiquidGlass {
            content
                .buttonStyle(.glass)
                .besortedClick(.regular)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if appearance.isNeomorphic {
            content
                .buttonStyle(BeSortedNeoButtonStyle(appearance: appearance))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            content
                .buttonStyle(BeSortedPlainButtonStyle())
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(appearance.tileTint)
                }
                .overlay {
                    flatBeSortedButtonRim(
                        appearance,
                        shape: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var horizontalPadding: CGFloat {
        switch controlSize {
        case .mini, .small: return 12
        case .large: return 24
        default: return 0
        }
    }

    private var verticalPadding: CGFloat {
        switch controlSize {
        case .mini, .small: return 6
        case .large: return 14
        default: return 0
        }
    }
}

private struct BesortedGlassSurfaceModifier<S: Shape>: ViewModifier {
    var appearance: AppAppearance
    var interactive: Bool
    var tint: Color?
    var shape: S
    var minimumFrost: Double
    var role: BesortedGlassRole
    var cushion: Bool

    private var coverWithSolid: Bool {
        // listTile: Zero/Neo = solid (bez glassEffect), żeby pastylka/scroll nie „rozlewały” szerokości.
        if role == .listTile {
            return appearance.usesZeroLiquidGlass || appearance.isNeomorphic
        }
        switch appearance.glassStyle {
        case .zero, .neomorphic:
            return true
        case .balanced:
            return role == .content
        case .full:
            return false
        }
    }

    private var solidFill: Color {
        // Neumorfizm: każda powierzchnia = dokładnie kolor tła widoczny na kafelkach
        // (neoRaisedFill), niezależnie od tint — różnicują tylko miękkie cienie.
        if appearance.isNeomorphic {
            return appearance.neoRaisedFill
        }
        // Zero / content: pełne krycie. Jawny tint (np. białe kafelki priorytetu) ma pierwszeństwo.
        if let tint {
            return appearance.fullyOpaque(tint)
        }
        if appearance.usesZeroLiquidGlass {
            return appearance.opaqueModalFill
        }
        return appearance.fullyOpaque(appearance.tileTint)
    }

    private var blend: Double {
        appearance.glassBlend(minimumFrost: minimumFrost)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if appearance.isNeomorphic {
            // Neumorfizm: kafelki i powierzchnie — wypukłe, w kolorze tła motywu,
            // rozróżnione wyłącznie poświatą (biała lewo-góra / ciemna prawo-dół).
            let surfaceFill = solidFill
            content
                .background {
                    BeSortedNeoRaised(
                        shape: shape,
                        appearance: appearance,
                        fill: surfaceFill,
                        cushion: cushion
                    )
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
                .animation(.smooth(duration: 0.38), value: appearance.glassFrost)
        } else if coverWithSolid {
            // Zero / content w balanced: zero glassEffect w hierarchii.
            content
                .background {
                    shape.fill(solidFill)
                }
                .overlay {
                    flatBeSortedButtonRim(appearance, shape: shape)
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
                .animation(.smooth(duration: 0.38), value: appearance.glassFrost)
        } else {
            // compositingGroup: ikony/tekst = ostra warstwa NAD glass.
            // glassEffect tylko w tle → deformuje wyłącznie to, co za kafelkiem/przyciskiem.
            // blend = pełny suwak Liquid Glass z ustawień.
            content
                .compositingGroup()
                .background {
                    shape
                        .fill(Color.clear)
                        .glassEffect(
                            appearance.blendedGlass(interactive: interactive, tint: tint, blend: blend),
                            in: shape
                        )
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
                .animation(.smooth(duration: 0.38), value: appearance.glassFrost)
        }
    }
}

/// Suwak Liquid Glass z punktami 25% / 50% / 75%, magnetycznym zatrzymaniem i lekką haptyką.
struct GlassFrostSlider: View {
    @Binding var value: Double
    var tint: Color
    var tickColor: Color

    private let snaps = AppAppearance.glassFrostSnapStops
    private let snapRadius = 0.03

    @State private var isEditing = false
    @State private var lastHapticSnap: Double?

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let trackInset: CGFloat = 14
                let usable = max(geo.size.width - trackInset * 2, 1)

                ForEach(snaps, id: \.self) { stop in
                    Circle()
                        .fill(tickColor)
                        .frame(width: 6, height: 6)
                        .position(
                            x: trackInset + usable * stop,
                            y: geo.size.height * 0.5
                        )
                        .accessibilityHidden(true)
                }
            }
            .allowsHitTesting(false)

            Slider(
                value: $value,
                in: 0...1,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        if let snap = nearestSnap(value, radius: snapRadius * 1.35) {
                            withAnimation(.smooth(duration: 0.14)) {
                                value = snap
                            }
                        }
                        lastHapticSnap = nil
                    }
                }
            )
            .tint(tint)
        }
        .frame(height: 32)
        .onChange(of: value) { _, newValue in
            guard isEditing else { return }

            if let snap = nearestSnap(newValue, radius: snapRadius) {
                if lastHapticSnap != snap {
                    lastHapticSnap = snap
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.75)
                }
                if abs(newValue - snap) > 0.001 {
                    value = snap
                }
            } else if let armed = lastHapticSnap, abs(newValue - armed) > snapRadius * 1.25 {
                lastHapticSnap = nil
            }
        }
    }

    private func nearestSnap(_ candidate: Double, radius: Double) -> Double? {
        snaps
            .map { stop in (stop, abs(stop - candidate)) }
            .filter { $0.1 <= radius }
            .min(by: { $0.1 < $1.1 })?
            .0
    }
}

/// Górny margines (safe area): jedna warstwa glass + miękka maska (bez poziomych „pasków”).
struct TopSafeAreaLiquidGlass: View {
    @Environment(AppAppearance.self) private var appearance

    /// Miękkie zejście poniżej safe area.
    private let bottomFadeExtra: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let inset = max(geo.safeAreaInsets.top, 0)
            if inset > 0, appearance.usesAnyLiquidGlass {
                let totalHeight = inset + bottomFadeExtra

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: geo.size.width, height: totalHeight, alignment: .top)
                    .glassEffect(
                        appearance.blendedGlass(
                            interactive: false,
                            tint: appearance.tileTint.opacity(0.32),
                            blend: 0.82
                        ),
                        in: Rectangle()
                    )
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: max(0.02, (inset * 0.55) / totalHeight)),
                                .init(color: .white.opacity(0.55), location: inset / totalHeight),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

/// Tło paska tytułu przy scrollu → glass/blur.
///
/// Na starcie listy **nic nie malujemy** — widać `screenBackgroundGradient`.
/// Przy scrollu wjeżdża **jedna** warstwa glass (max = regular 100% / Zero: blur).
struct TabHeaderRegularLiquidGlassModifier: ViewModifier {
    var appearance: AppAppearance
    /// Offset scrolla (contentOffset.y) — glass liczony osobno (2× wolniej niż tytuł).
    var scrollY: CGFloat

    func body(content: Content) -> some View {
        // Minimalistyczny nagłówek: zamiast pełnego paska — pastylka w collapsingu tytułu.
        if appearance.minimalistHeader {
            content
        } else {
            let t = TabHeaderScrollSolidify.glassProgress(scrollY: scrollY)

            content
                .background(alignment: .top) {
                    ZStack {
                        if t > 0.001 {
                            if appearance.usesZeroLiquidGlass {
                                Rectangle()
                                    .fill(.ultraThickMaterial)
                            } else if appearance.usesAnyLiquidGlass {
                                Rectangle()
                                    .fill(Color.clear)
                                    .glassEffect(
                                        Glass.regular.interactive(false),
                                        in: Rectangle()
                                    )
                            } else {
                                Rectangle()
                                    .fill(appearance.fullyOpaque(appearance.backgroundHeader))
                            }
                        }
                    }
                    .opacity(t)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }
                .animation(.smooth(duration: 0.38), value: appearance.glassStyle)
                .animation(nil, value: scrollY)
        }
    }
}

enum TabHeaderScrollSolidify {
    /// Glass: 2× wolniej niż wcześniejsze ~220 pt.
    static let glassDistance: CGFloat = 440

    /// Tytuł: dojazd na środek (tylko X).
    static let titleTravelEnd: CGFloat = 64
    /// Po dojechaniu: szybkie zniknięcie (bez uciekania w górę).
    static let titleHideStart: CGFloat = 70
    static let titleHideEnd: CGFloat = 95
    /// Pauza, potem wolne pojawienie w headerze.
    static let titleRevealStart: CGFloat = 180
    static let titleRevealEnd: CGFloat = 380

    static func smoothstep(_ p: CGFloat) -> CGFloat {
        let x = min(max(p, 0), 1)
        return x * x * (3 - 2 * x)
    }

    static func glassProgress(scrollY: CGFloat) -> CGFloat {
        smoothstep(max(0, scrollY) / glassDistance)
    }

    /// 0 = tytuł z lewej, 1 = na środku.
    static func titleTravelProgress(scrollY: CGFloat) -> CGFloat {
        smoothstep(max(0, scrollY) / titleTravelEnd)
    }

    /// Jadący tytuł: widać do końca jazdy, potem zanika na miejscu (bez offsetu w Y).
    static func titleTravelOpacity(scrollY: CGFloat) -> CGFloat {
        let y = max(0, scrollY)
        if y < titleHideStart { return 1 }
        if y >= titleHideEnd { return 0 }
        return 1 - smoothstep((y - titleHideStart) / max(1, titleHideEnd - titleHideStart))
    }

    /// Po pauzie — wolno pojawia się w headerze.
    static func titleHeaderOpacity(scrollY: CGFloat) -> CGFloat {
        let y = max(0, scrollY)
        if y <= titleRevealStart { return 0 }
        if y >= titleRevealEnd { return 1 }
        return smoothstep((y - titleRevealStart) / max(1, titleRevealEnd - titleRevealStart))
    }

    /// Przyciski tylko blisko samej góry.
    static func buttonsOpacity(scrollY: CGFloat) -> CGFloat {
        let t = smoothstep(max(0, scrollY) / 90)
        return pow(1 - t, 1.6)
    }

    static func titleScale(scrollY: CGFloat) -> CGFloat {
        let travel = titleTravelProgress(scrollY: scrollY)
        let header = titleHeaderOpacity(scrollY: scrollY)
        if header > 0.01 {
            return 0.82
        }
        return 1.0 - (0.18 * travel)
    }

    /// Pastylka: w dół rośnie z tytułem; w górę kurczy się i znika,
    /// zanim tytuł zacznie wracać z środka (histereza + kierunek scrolla).
    static let minimalistPillShrinkStartExtra: CGFloat = 88
    static let minimalistPillShrinkEndExtra: CGFloat = 14

    static func minimalistPillProgress(scrollY: CGFloat, previousScrollY: CGFloat) -> CGFloat {
        let y = max(0, scrollY)
        let prev = max(0, previousScrollY)
        let goingUp = y < prev - 0.35
        let shrinkStart = titleTravelEnd + minimalistPillShrinkStartExtra
        let shrinkEnd = titleTravelEnd + minimalistPillShrinkEndExtra

        if goingUp {
            // Tytuł nadal na środku (y > titleTravelEnd), pastylka już znika — wolniej.
            if y >= shrinkStart { return 1 }
            if y <= shrinkEnd { return 0 }
            let t = smoothstep((y - shrinkEnd) / max(1, shrinkStart - shrinkEnd))
            // Krzywa „przytrzymuje” pastylkę dłużej, potem schodzi.
            return pow(t, 0.72)
        }

        // Scroll w dół / postój: rozszerzanie wraz z dojazdem tytułu.
        if y >= titleTravelEnd { return 1 }
        let travel = titleTravelProgress(scrollY: y)
        if travel < 0.35 { return 0 }
        return smoothstep((travel - 0.35) / 0.65)
    }
}

private struct BesortedTitleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct BesortedHeaderWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Tytuł: jedzie na środek **tylko w osi X**.
/// Layout rest = ten sam co Ustawienia / Aktualny Plan:
/// `HStack { tytuł; Spacer; przyciski }.padding(.horizontal, 16)`.
struct BesortedCollapsingTabHeader<Trailing: View>: View {
    var title: String
    var scrollY: CGFloat
    var leadingPadding: CGFloat = BeSortedContentInsets.headerHorizontal
    var trailingPadding: CGFloat = BeSortedContentInsets.headerHorizontal
    @ViewBuilder var trailing: () -> Trailing

    @Environment(AppAppearance.self) private var appearance
    @State private var titleWidth: CGFloat = 0
    @State private var headerWidth: CGFloat = 0
    @State private var previousScrollY: CGFloat = 0

    var body: some View {
        let minimal = appearance.minimalistHeader
        let travel = TabHeaderScrollSolidify.titleTravelProgress(scrollY: scrollY)
        let travelOpacity = minimal ? 1 : TabHeaderScrollSolidify.titleTravelOpacity(scrollY: scrollY)
        let headerOpacity = minimal ? 0 : TabHeaderScrollSolidify.titleHeaderOpacity(scrollY: scrollY)
        let buttonsOpacity = TabHeaderScrollSolidify.buttonsOpacity(scrollY: scrollY)
        let scale = minimal
            ? (1.0 - 0.18 * travel)
            : TabHeaderScrollSolidify.titleScale(scrollY: scrollY)
        let pillProgress = TabHeaderScrollSolidify.minimalistPillProgress(
            scrollY: scrollY,
            previousScrollY: previousScrollY
        )
        let pillSpringKey = (pillProgress * 20).rounded() / 20
        let titleSpringKey = minimal ? ((travel * 24).rounded() / 24) : travel
        let titleSpring = Animation.spring(response: 0.48, dampingFraction: 0.68)

        let layoutW = headerWidth > 1 ? headerWidth : BeSortedContentInsets.screenWidth
        let measured = titleWidth > 1 ? titleWidth : min(140, layoutW * 0.42)
        let visualHalf = measured * scale * 0.5
        // 0 przy rest — tytuł zostaje na leadingPadding; przy scrollu jedzie do środka.
        let travelOffsetX = max(0, layoutW * 0.5 - leadingPadding - visualHalf) * travel

        let pillWidth = max(measured * scale + 36, 88)
        let pillHeight: CGFloat = 38

        ZStack {
            if !minimal {
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(appearance.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .scaleEffect(0.82, anchor: .center)
                    .frame(maxWidth: .infinity)
                    .opacity(headerOpacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(headerOpacity < 0.4)
            }

            HStack(alignment: .center, spacing: 8) {
                ZStack(alignment: .leading) {
                    if minimal, pillProgress > 0.001 {
                        Group {
                            if appearance.usesZeroLiquidGlass {
                                Capsule()
                                    .fill(appearance.minimalistHeaderZeroFill)
                            } else if appearance.usesAnyLiquidGlass {
                                Capsule()
                                    .fill(Color.clear)
                                    .glassEffect(
                                        appearance.blendedGlass(
                                            interactive: false,
                                            tint: appearance.tileTint.opacity(0.5),
                                            blend: appearance.glassBlend(
                                                minimumFrost: AppAppearance.minimalistHeaderGlassMinimumFrost
                                            )
                                        ),
                                        in: Capsule()
                                    )
                            } else {
                                Capsule()
                                    .fill(appearance.fullyOpaque(appearance.tileTint).opacity(0.92))
                            }
                        }
                        .frame(width: pillWidth, height: pillHeight)
                        .scaleEffect(
                            x: 0.22 + 0.78 * pillProgress,
                            y: 0.35 + 0.65 * pillProgress,
                            anchor: .center
                        )
                        .opacity(Double(pillProgress))
                        .offset(x: travelOffsetX + visualHalf - pillWidth * 0.5)
                        .allowsHitTesting(false)
                        .animation(
                            .spring(response: 0.58, dampingFraction: 0.62),
                            value: pillSpringKey
                        )
                        .animation(titleSpring, value: titleSpringKey)
                    }

                    Text(title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: true, vertical: false)
                        .background {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: BesortedTitleWidthKey.self,
                                    value: geo.size.width
                                )
                            }
                        }
                        .scaleEffect(scale, anchor: .leading)
                        .offset(x: travelOffsetX)
                        .opacity(travelOpacity)
                        .allowsHitTesting(false)
                        .animation(minimal ? titleSpring : nil, value: titleSpringKey)
                }

                Spacer(minLength: 0)

                trailing()
                    .opacity(buttonsOpacity)
                    .scaleEffect(0.94 + 0.06 * buttonsOpacity, anchor: .trailing)
                    .allowsHitTesting(buttonsOpacity > 0.18)
                    .accessibilityHidden(buttonsOpacity <= 0.18)
            }
            // Jak ProjectDetail: gutter najpierw, potem pełna szerokość —
            // tytuł i przyciski w linii z kafelkami (`tileListHorizontal`).
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .frame(maxWidth: .infinity)
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: BesortedHeaderWidthKey.self,
                    value: geo.size.width
                )
            }
        }
        .onPreferenceChange(BesortedTitleWidthKey.self) { titleWidth = $0 }
        .onPreferenceChange(BesortedHeaderWidthKey.self) { headerWidth = $0 }
        .onChange(of: scrollY) { oldY, _ in
            previousScrollY = oldY
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
}

/// Wariant bez przycisków (np. Ustawienia).
struct BesortedCollapsingTabTitle: View {
    var title: String
    var scrollY: CGFloat
    var leadingPadding: CGFloat = BeSortedContentInsets.headerHorizontal

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        BesortedCollapsingTabHeader(
            title: title,
            scrollY: scrollY,
            leadingPadding: leadingPadding,
            trailingPadding: leadingPadding
        ) {
            EmptyView()
        }
    }
}

enum MenuPillCollapse {
    /// Dystans scrolla do pełnego skurczenia (gdy bez Minimalistycznego Nagłówka).
    static let distance: CGFloat = 247
    /// W poziomie ekran jest dużo niższy, więc ta sama liczba pt to relatywnie więcej
    /// scrolla — przez to pastylka kurczyła się po „mini scrolu”. Dłuższy dystans
    /// w poziomie opóźnia kurczenie do realnie dłuższego przewijania.
    static let landscapeDistance: CGFloat = 400

    static func progress(
        contentOffsetY: CGFloat,
        syncWithMinimalistHeader: Bool = false
    ) -> CGFloat {
        // Razem z Minimalistycznym Nagłówkiem: ten sam timing co tytuł
        // (powrót tytułu na lewo = wolne rozszerzanie pastylki menu).
        if syncWithMinimalistHeader {
            return TabHeaderScrollSolidify.titleTravelProgress(scrollY: contentOffsetY)
        }
        let y = max(0, contentOffsetY)
        let maxDistance = BeSortedContentInsets.isLandscape ? landscapeDistance : distance
        let p = min(1, y / maxDistance)
        return p * p * (3 - 2 * p)
    }
}

/// Most scroll → kolaps pastylki (aktualizowany z każdego `trackTabHeaderSolidProgress`).
@MainActor
enum MenuPillCollapseBridge {
    static weak var chrome: SmartChrome?
    static weak var appearance: AppAppearance?

    private static let expandAnimation = Animation.spring(response: 0.52, dampingFraction: 0.72)
    /// Po zmianie zakładki ignoruj chwilowo „kurczenie” ze starego / stale scrolla.
    private static var suppressCollapseUntil: Date = .distantPast

    static func bind(chrome: SmartChrome, appearance: AppAppearance) {
        self.chrome = chrome
        self.appearance = appearance
    }

    /// Płynny powrót do pełnej pastylki (zmiana zakładki / brak scrolla).
    static func expandSmoothly() {
        guard let chrome else { return }
        // Blokada ~0.4s — stary UIScrollView / ostatni offset nie skurczy pastylki z powrotem.
        suppressCollapseUntil = Date().addingTimeInterval(0.40)
        guard appearance?.collapsingMenuPill == true else {
            chrome.menuPillCollapseProgress = 0
            return
        }
        withAnimation(expandAnimation) {
            chrome.menuPillCollapseProgress = 0
        }
    }

    static func update(offsetY: CGFloat) {
        guard let chrome else { return }
        guard appearance?.collapsingMenuPill == true else {
            if chrome.menuPillCollapseProgress != 0 {
                chrome.menuPillCollapseProgress = 0
            }
            return
        }
        let sync = appearance?.minimalistHeader == true
        let next = MenuPillCollapse.progress(
            contentOffsetY: offsetY,
            syncWithMinimalistHeader: sync
        )
        let current = chrome.menuPillCollapseProgress
        // Większy próg przy szybkim scrollu — mniej przebudów UI / zacięć przy flingu w górę.
        let threshold: CGFloat = sync ? 0.012 : 0.028
        guard abs(next - current) > threshold else { return }

        // Po zmianie kontekstu: pozwól tylko na rozwijanie, nie na ponowne kurczenie ze starego offsetu.
        if next > current, Date() < suppressCollapseUntil {
            return
        }

        // Bez withAnimation przy każdym ticku — animacja jest na widoku pastylki (spring).
        chrome.menuPillCollapseProgress = next
    }
}

/// Poziomy odstęp list kafelków od krawędzi ekranu (jak Aktualny Plan / Ustawienia).
enum BeSortedContentInsets {
    static var isLandscape: Bool {
        let size = BeSortedScreen.bounds.size
        return size.width > size.height
    }

    /// Fizyczny poziomy safe inset w trybie poziomym (Dynamic Island / zaokrąglone rogi).
    static var landscapeHorizontalSafeInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first else { return 0 }
        return max(window.safeAreaInsets.left, window.safeAreaInsets.right)
    }

    /// Fizyczny top safe area (Dynamic Island / notch) — do rozciągania tła headera.
    static var topSafeArea: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let inset = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top,
           inset > 0 {
            return inset
        }
        if let inset = scenes.first?.windows.first?.safeAreaInsets.top, inset > 0 {
            return inset
        }
        return 59
    }

    /// Gutter list kafelków: w poziomie powiększony, żeby kafelki miały odstęp
    /// od Dynamic Island / zaokrąglonych rogów (obecnie zachodziły pod cutout).
    /// Jednocześnie „węższe kafelki” = szerszy gutter — w poziomie odrobinę większy.
    static var tileListHorizontal: CGFloat {
        guard isLandscape else { return 20 }
        return max(20, landscapeHorizontalSafeInset + 16)
    }

    /// Trailing gutter list w poziomie: większy niż lewy, żeby kafelki i przyciski
    /// prawą stroną nie zachodziły pod pionowy dock (pastylka zakładek) i lupę.
    static var tileListTrailing: CGFloat {
        guard isLandscape else { return tileListHorizontal }
        // landscapeDockTrailing + szerokość docku (80) + przerwa (16).
        return max(tileListHorizontal, landscapeDockTrailing + 96)
    }

    /// Wspólny poziomy padding headerów — taka sama szerokość co kafelki
    /// (tytuły i przyciski headerów w linii z kafelkami).
    static var headerHorizontal: CGFloat {
        guard isLandscape else { return 20 }
        return max(20, landscapeHorizontalSafeInset + 16)
    }
    static var projectsHeaderLeading: CGFloat { headerHorizontal }
    static var projectsHeaderTrailing: CGFloat { headerHorizontal }

    /// Trailing pionowego docku w poziomie: bliżej prawej krawędzi niż header,
    /// ale zawsze z odstępem od krawędzi (nie „przyklejony”).
    static var landscapeDockTrailing: CGFloat {
        max(20, landscapeHorizontalSafeInset + 4)
    }

    /// W pionie dock w poziomie byłby idealnie na środku ekranu — przez Dynamic Island /
    /// wcięcie u góry wygląda na za wysoki. To delikatne przesunięcie w dół całej grupy
    /// (pastylka zakładek + lupa), żeby wyrównać ją w osi Y w trybie poziomym.
    static var landscapeDockVerticalAdjustment: CGFloat {
        12
    }

    /// Stała szerokość obszaru — window bounds (obraca się z interfejsem), nie `screen.bounds`
    /// (ten zawsze zwraca wymiary pionowe — kafelki w poziomie byłyby rozmiaru portretu).
    static var screenWidth: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
            if let window = active.windows.first {
                return window.bounds.width
            }
            return active.screen.bounds.width
        }
        return scenes.first?.screen.bounds.width ?? 390
    }

    static var tileWidth: CGFloat {
        max(0, screenWidth - tileListHorizontal - tileListTrailing)
    }
}

/// Blokuje UIScrollView: bez automatycznych insetów i z clipsToBounds — szerokość nie „pływa” przy scrollu.
struct BesortedScrollViewLock: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let probe = UIView(frame: .zero)
        probe.isUserInteractionEnabled = false
        DispatchQueue.main.async { Self.lock(from: probe) }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { Self.lock(from: uiView) }
    }

    private static func lock(from probe: UIView) {
        var node: UIView? = probe
        while let current = node {
            if let scroll = current as? UIScrollView {
                scroll.clipsToBounds = true
                scroll.contentInsetAdjustmentBehavior = .never
                scroll.automaticallyAdjustsScrollIndicatorInsets = false
                scroll.contentInset = .zero
                scroll.horizontalScrollIndicatorInsets = .zero
                scroll.verticalScrollIndicatorInsets = .zero
                return
            }
            node = current.superview
        }
    }
}

/// Lista kafelków ze **stałym** gutterem ~20pt — soft edge / animacje nie mogą
/// rozciągać kafelków edge-to-edge. Stała szerokość = `screenWidth`.
struct BesortedFixedWidthTileScroll<Content: View>: View {
    var bottomPadding: CGFloat = 100
    var topPadding: CGFloat = 12
    /// Blokuje scroll (np. "Moje projekty": 0…3 projekty = brak przewijania, od 4 — działa).
    var scrollDisabled: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(AppAppearance.self) private var appearance

    var body: some View {
        let screenW = BeSortedContentInsets.screenWidth
        let leading = BeSortedContentInsets.tileListHorizontal
        let trailing = BeSortedContentInsets.tileListTrailing

        ScrollView(.vertical) {
            LazyVStack(spacing: appearance.isNeomorphic ? 18 : 12) {
                content()
            }
            .padding(.leading, leading)
            .padding(.trailing, trailing)
            .frame(width: screenW, alignment: .center)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .scrollDisabled(scrollDisabled)
        .scrollIndicators(.hidden)
        .scrollClipDisabled(false)
        .scrollEdgeEffectHidden(true, for: .all)
        .scrollEdgeEffectStyle(.hard, for: .all)
        .scrollBounceBehavior(.always, axes: [.vertical])
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.horizontal, 0, for: .automatic)
        .contentMargins(.horizontal, 0, for: .scrollIndicators)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 0, for: .scrollContent)
        .background { BesortedScrollViewLock() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Scroll chrome bez guttera (gutter = `BesortedFixedWidthTileScroll`).
    func besortedListScrollChrome(
        horizontalContentMargin _: CGFloat = BeSortedContentInsets.tileListHorizontal
    ) -> some View {
        self
            .scrollIndicators(.hidden)
            .scrollEdgeEffectHidden(true, for: .all)
            .scrollEdgeEffectStyle(nil, for: .all)
            .contentMargins(.horizontal, 0, for: .automatic)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .contentMargins(.horizontal, 0, for: .scrollIndicators)
    }

    /// Pełnoekranowe tło gradientowe motywu (jasny header → baza u dołu).
    func besortedScreenBackground(_ appearance: AppAppearance) -> some View {
        background {
            appearance.screenBackgroundGradient
                .ignoresSafeArea()
        }
    }

    /// Header: `scrollY` = contentOffset.y (glass 2× wolniej; tytuł ma własne fazy).
    func tabHeaderRegularLiquidGlass(
        _ appearance: AppAppearance,
        scrollY: CGFloat = 0
    ) -> some View {
        modifier(
            TabHeaderRegularLiquidGlassModifier(
                appearance: appearance,
                scrollY: scrollY
            )
        )
    }

    /// Śledzi offset scrolla (pt) → header glass / tytuł / pastylka menu.
    func trackTabHeaderSolidProgress(_ scrollY: Binding<CGFloat>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newOffset in
            let y = max(0, newOffset)
            if abs(y - scrollY.wrappedValue) > 0.5 {
                scrollY.wrappedValue = y
            }
            MenuPillCollapseBridge.update(offsetY: newOffset)
        }
    }
}

// MARK: - Neumorphic surfaces

extension Shape {
    /// Cień skupiony wewnątrz kształtu (np. wklęsłość): projects at the requested edge.
    func neoInnerShadow(_ color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        shadow(color: color, radius: radius, x: x, y: y)
            .mask(self)
    }
}

/// Wypukła (raised) powierzchnia (referencja SoftEmbossed): wypełnienie surface +
/// ciemny cień prawa-dół i jasne światło lewa-góra. Bez aur/glow — czysty emboss.
struct BeSortedNeoRaised<S: Shape>: View {
    let shape: S
    let appearance: AppAppearance
    var fill: Color? = nil
    var radius: CGFloat = 12
    var distance: CGFloat = 6
    var cushion: Bool = false

    var body: some View {
        let darkRadius = cushion ? radius + 2 : radius
        let lightRadius = max(darkRadius - 2, 4)
        Group {
            shape
                .fill(fill ?? appearance.neoRaisedFill)
                // Spłaszcz wypełnienie ZANIM nałożysz cienie — kompozyt nigdy nie
                // przycina poświaty do własnych ramek (lewy-górny/dolny-prawy cień widać cały).
                .compositingGroup()
                // Ciemny cień prawa-dół.
                .shadow(color: appearance.neoShadow, radius: darkRadius, x: distance, y: distance + 2)
                // Jasne światło lewa-góra.
                .shadow(color: appearance.neoHighlight, radius: lightRadius, x: -distance + 1, y: -distance + 1)
        }
        // UWAGA: brak drawingGroup — rasteryzacja do bitmapy ramek PRZYCINAŁABY
        // cienie wystające poza kształt (emboss stawał się niewidoczny / płaski).
        // Wydajność bierze się z samej geometrii referencyjnej (2 cienie zamiast 5–8).
        // Czyści dekoracja — nigdy nie przechwytuje dotyku (przyciski wyżej klikalne).
        .allowsHitTesting(false)
    }
}

/// Wciśnięty stan przycisku (Neumorfizm): lustrzane cienie (ciemny u góry-lewej,
/// jasny u dołu-prawej) skierowane do wewnątrz — subtelny innershadow bez dropshadowu.
struct BeSortedNeoInset<S: Shape>: View {
    let shape: S
    let appearance: AppAppearance
    var fill: Color? = nil
    var radius: CGFloat = 8
    var distance: CGFloat = 5

    var body: some View {
        ZStack {
            shape.fill(fill ?? appearance.neoRaisedFill)
            // Ciemny cień dociągany do krawędzi od góry-lewej (środek jaśniejszy).
            shape.neoInnerShadow(
                appearance.neoShadow.opacity(0.55),
                radius: radius,
                x: -distance,
                y: -distance
            )
            // Jasne odbite światło dociskane od dołu-prawej.
            shape.neoInnerShadow(
                appearance.neoHighlight.opacity(0.75),
                radius: radius,
                x: distance,
                y: distance
            )
        }
        .compositingGroup()
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// Wklęsły „kanał" Neumorfizmu (głęboko wyrzeźbiona studnia): ciemny wewnętrzny
/// cień u góry-lewej, jasne odbite światło u dołu-prawej i miękki zewnętrzny cień,
/// który „dociska" element w tło — dla wierszy ustawień i ramek tekstu/sekcji.
struct BeSortedNeoCarved<S: Shape>: View {
    let shape: S
    let appearance: AppAppearance
    var fill: Color? = nil
    var radius: CGFloat = 10
    var depth: CGFloat = 3

    var body: some View {
        ZStack {
            shape.fill(fill ?? appearance.neoRaisedFill)
            // Ciemny cień wewnątrz u góry-lewej — krawędź „zapada się" od światła.
            shape.neoInnerShadow(
                appearance.neoShadowStrong.opacity(0.55),
                radius: radius * 0.7,
                x: -depth * 0.7,
                y: -depth * 0.7
            )
            // Jasne odbite światło wewnątrz u dołu-prawej.
            shape.neoInnerShadow(
                appearance.neoHighlight.opacity(0.65),
                radius: radius * 0.5,
                x: depth * 0.6,
                y: depth * 0.6
            )
        }
        .compositingGroup()
        // Miękki zewnętrzny cień dociskający wgłębienie do tła.
        // Biała poświata na zewnątrz tylko mocno przyciemniona — na jasnych motywach
        // zbyt jasna tworzyła „białą kreskę" wokół napisów.
        .shadow(color: appearance.neoShadow.opacity(0.28), radius: 8, x: 2, y: 3)
        .shadow(color: appearance.neoHighlight.opacity(0.14), radius: 8, x: -3, y: -3)
        // UWAGA: brak drawingGroup — rasteryzacja przycinałaby zewnętrzne cienie.
        .allowsHitTesting(false)
    }
}

/// „Studnia" pastylki zakładek: lity kolor motywu + subtelny emboss.
/// Ciemne motywy: bez jasnego highlightu (mył tor na biały/szary).
struct BeSortedNeoWell<S: Shape>: View {
    let shape: S
    let appearance: AppAppearance
    var radius: CGFloat = 2
    var depth: CGFloat = 1

    var body: some View {
        let fill = appearance.fullyOpaque(appearance.neoPillSurface)
        ZStack {
            shape.fill(fill)
            shape.neoInnerShadow(
                appearance.neoShadowStrong.opacity(
                    appearance.theme.usesLightContent ? 0.32 : 0.48
                ),
                radius: min(radius, 2),
                x: 0,
                y: depth
            )
            if appearance.theme.usesLightContent {
                shape.neoInnerShadow(
                    appearance.neoHighlight.opacity(0.35),
                    radius: min(radius, 2),
                    x: 0,
                    y: -depth
                )
            }
        }
        .compositingGroup()
        .shadow(
            color: appearance.neoShadow.opacity(appearance.theme.usesLightContent ? 0.22 : 0.40),
            radius: 3,
            x: 0,
            y: 1
        )
        // UWAGA: brak drawingGroup — rasteryzacja przycinałaby zewnętrzny cień.
        .allowsHitTesting(false)
    }
}

/// ButtonStyle Neumorfizmu: płynne, „klikowe" przejście wypukły → wciśnięty przy pulsie —
/// dropshadow zanika, a dookoła pojawia się bardzo subtelny, ciemny wewnętrzny cień.
struct BeSortedNeoButtonStyle: ButtonStyle {
    let appearance: AppAppearance
    var fill: Color? = nil
    var cornerRadius: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let pressed = configuration.isPressed

        ZStack {
            configuration.label
                .background {
                    // Wypukły emboss w geometrii referencyjnej (bez glow/aur).
                    BeSortedNeoRaised(
                        shape: shape,
                        appearance: appearance,
                        fill: fill,
                        radius: 10,
                        distance: 6
                    )
                }
                .opacity(pressed ? 0 : 1)

            configuration.label
                .background {
                    BeSortedNeoInset(
                        shape: shape,
                        appearance: appearance,
                        fill: fill ?? appearance.neoRaisedFill,
                        radius: 6,
                        distance: 4
                    )
                }
                .opacity(pressed ? 1 : 0)
        }
        .scaleEffect(pressed ? 0.985 : 1)
        .contentShape(shape)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: pressed)
        .onChange(of: pressed) { _, isPressed in
            if isPressed {
                BeSortedSound.play(.regular)
            }
        }
    }
}