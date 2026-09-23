//
//  SmartAssistantTourSnapshots.swift
//  BeSorted
//
//  Miniatury „Zapoznaj się” — wycinki prawdziwego UI (te same fonty,
//  paddingi, glass i układ co w ContentView / AIAssistantView).
//

import SwiftUI

/// Ramka wokół miniatury zakładki (tło jak w aplikacji).
struct TourMiniTabFrame<Content: View>: View {
    let appearance: AppAppearance
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(appearance.screenBackgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        appearance.isFlatDesign ? .clear : appearance.primaryText.opacity(0.10),
                        lineWidth: 1
                    )
            }
    }
}

/// Składanka zakładki budowana warstwami (`buildStep` 1…4).
struct TourMiniTabScreen: View {
    let skill: SmartAssistantSkill
    let buildStep: Int
    let appearance: AppAppearance

    var body: some View {
        Group {
            switch skill {
            case .fillCurrentPlan:
                TourPlanTabSnapshot(buildStep: buildStep, pickMode: false, appearance: appearance)
            case .breakDownTask:
                TourPlanTabSnapshot(buildStep: buildStep, pickMode: true, appearance: appearance)
            case .summarizeProject:
                TourProjectsTabSnapshot(buildStep: buildStep, appearance: appearance)
            case .forgottenProject:
                TourProjectsTabSnapshot(buildStep: buildStep, appearance: appearance)
            case .summarizeDescription:
                TourProjectDetailSnapshot(buildStep: buildStep, mode: .summarizeDescription, appearance: appearance)
            case .proposeTasks:
                TourProjectDetailSnapshot(buildStep: buildStep, mode: .proposeTasks, appearance: appearance)
            case .remindProject:
                TourProjectDetailSnapshot(buildStep: buildStep, mode: .remindProject, appearance: appearance)
            case .whatCanIDoNow:
                TourProjectDetailSnapshot(buildStep: buildStep, mode: .whatCanIDoNow, appearance: appearance)
            case .evaluateProject:
                TourProjectDetailSnapshot(buildStep: buildStep, mode: .evaluateProject, appearance: appearance)
            case .freeformChat:
                TourAIAssistantSnapshot(buildStep: buildStep, appearance: appearance)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Shared chrome

private struct TourChromeIconCapsule: View {
    let systemImage: String
    var tinted: Bool = false
    var size: CGFloat = 40
    let appearance: AppAppearance

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size >= 48 ? 18 : 16, weight: .semibold))
            .foregroundStyle(tinted ? appearance.selectedTabTint : appearance.primaryText)
            .frame(width: size, height: size)
            .besortedGlass(appearance, interactive: true, in: .capsule)
    }
}

private struct TourCloseCircle: View {
    let appearance: AppAppearance
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(appearance.primaryText)
            .frame(width: size, height: size)
            .besortedGlass(appearance, interactive: true, in: .circle)
    }
}

/// Panel wyniku AI jak w `DropInModalChrome` overlayach (glass + cornerRadius 22).
private struct TourAIResultPanel<Content: View>: View {
    let appearance: AppAppearance
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .besortedGlass(
                appearance,
                interactive: true,
                tint: appearance.tileTint.opacity(0.9),
                in: .rect(cornerRadius: 22),
                minimumFrost: AppAppearance.panelGlassMinimumFrost,
                role: .content
            )
    }
}

private struct TourMiniAppTabBar: View {
    var selected: AppTab = .projects
    let appearance: AppAppearance

    var body: some View {
        Group {
            if appearance.usesZeroLiquidGlass || appearance.isNeomorphic {
                HStack(spacing: 0) {
                    ForEach(AppTab.allCases) { tab in
                        Text(tab.title)
                            .font(.system(size: 11, weight: tab == selected ? .bold : .medium))
                            .scaleEffect(tab == selected ? 1.15 : 1)
                            .foregroundStyle(
                                tab == selected
                                    ? appearance.primaryText
                                    : appearance.secondaryText
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .background(appearance.background)
            } else {
                HStack(spacing: 6) {
                    ForEach(AppTab.allCases) { tab in
                        tourGlassTab(
                            title: tab.title,
                            systemImage: tab.systemImage,
                            isSelected: tab == selected
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }

    private func tourGlassTab(title: String, systemImage: String, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(tourTabLabelColor(isSelected: isSelected))
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .besortedGlass(
            appearance,
            interactive: !isSelected && appearance.glassFrost < 0.55,
            tint: isSelected ? appearance.selectedTabTint : appearance.tileTint.opacity(0.55),
            in: .capsule,
            minimumFrost: isSelected ? 0.72 : 0.35
        )
    }

    private func tourTabLabelColor(isSelected: Bool) -> Color {
        let pureBlack = Color(red: 0, green: 0, blue: 0)
        let pureWhite = Color(red: 1, green: 1, blue: 1)
        if isSelected {
            switch appearance.theme {
            case .lightBlue, .orange, .darkBlue, .cherry:
                return pureWhite
            case .black, .white, .silver:
                return pureBlack
            }
        }
        return appearance.theme.usesLightContent ? pureBlack : pureWhite
    }
}

private struct TourMiniProjectDetailTabBar: View {
    let selected: ProjectDetailTab
    let appearance: AppAppearance

    var body: some View {
        Group {
            if appearance.usesZeroLiquidGlass || appearance.isNeomorphic {
                HStack(spacing: 0) {
                    ForEach(ProjectDetailTab.allCases) { tab in
                        Text(tab.title)
                            .font(.system(size: 10, weight: tab == selected ? .bold : .medium))
                            .scaleEffect(tab == selected ? 1.2 : 1)
                            .foregroundStyle(
                                tab == selected
                                    ? appearance.primaryText
                                    : appearance.secondaryText
                            )
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .background(appearance.background)
            } else {
                HStack(spacing: 6) {
                    ForEach(ProjectDetailTab.allCases) { tab in
                        VStack(spacing: 3) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 8.5, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                        }
                        .foregroundStyle(tourDetailTabLabelColor(isSelected: tab == selected))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .besortedGlass(
                            appearance,
                            interactive: tab != selected && appearance.glassFrost < 0.55,
                            tint: tab == selected
                                ? appearance.selectedTabTint
                                : appearance.tileTint.opacity(0.55),
                            in: .capsule,
                            minimumFrost: tab == selected ? 0.72 : 0.35
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }

    private func tourDetailTabLabelColor(isSelected: Bool) -> Color {
        let pureBlack = Color(red: 0, green: 0, blue: 0)
        let pureWhite = Color(red: 1, green: 1, blue: 1)
        if isSelected {
            switch appearance.theme {
            case .lightBlue, .orange, .darkBlue, .cherry:
                return pureWhite
            case .black, .white, .silver:
                return pureBlack
            }
        }
        return appearance.theme.usesLightContent ? pureBlack : pureWhite
    }
}

// MARK: - Snapshot tiles (1:1 z ProjectTileView / TaskTileView / FutureNoteTileView)

private enum TourTaskPlanStatus {
    case none
    case inCurrentPlan
    case projectName(String)
}

/// Wycinek jak `ProjectTileView`.
private struct TourSnapshotProjectTile: View {
    let name: String
    let details: String
    let kindTitle: String
    let assetImageName: String
    let importance: Int
    var isPriority: Bool = false
    var highlighted: Bool = false
    let appearance: AppAppearance

    private var tileTint: Color {
        isPriority ? Color.white.opacity(0.96) : appearance.tileTint.opacity(0.85)
    }

    private var titleColor: Color { isPriority ? .black : appearance.primaryText }
    private var secondaryColor: Color { isPriority ? Color.black.opacity(0.62) : appearance.secondaryText }
    private var tertiaryColor: Color { isPriority ? Color.black.opacity(0.45) : appearance.tertiaryText }
    private var emptyStarColor: Color { isPriority ? Color.black.opacity(0.22) : appearance.starEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(assetImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= importance ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(star <= importance ? Color.yellow : emptyStarColor)
                    }
                }
            }

            Text(name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(2)

            if !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(secondaryColor)
                    .lineLimit(3)
            }

            Text(kindTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tertiaryColor)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .besortedGlass(appearance, tint: tileTint, in: .rect(cornerRadius: 18), role: .content)
        .offset(x: highlighted ? 2.5 : 0)
    }
}

/// Wycinek jak `TaskTileView`.
private struct TourSnapshotTaskTile: View {
    let name: String
    let details: String
    let kindTitle: String
    let kindImage: String
    let importance: Int
    var planStatus: TourTaskPlanStatus = .none
    var highlighted: Bool = false
    let appearance: AppAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: kindImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(appearance.iconPrimary)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= importance ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(star <= importance ? Color.yellow : appearance.starEmpty)
                    }
                }
            }

            Text(name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(appearance.primaryText)
                .lineLimit(2)

            if !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(appearance.secondaryText)
                    .lineLimit(3)
            }

            HStack {
                Text(kindTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(appearance.tertiaryText)
                Spacer(minLength: 0)
                switch planStatus {
                case .none:
                    EmptyView()
                case .inCurrentPlan:
                    Text("W aktualnym planie".l10n)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.cyan.opacity(0.9))
                case .projectName(let projectName):
                    Text(projectName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(appearance.quaternaryText)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .besortedGlass(
            appearance,
            tint: appearance.tileTint.opacity(0.85),
            in: .rect(cornerRadius: 18),
            role: .content
        )
        .offset(x: highlighted ? 2.5 : 0)
    }
}

/// Wycinek jak `FutureNoteTileView` (bez przycisku usuń).
private struct TourSnapshotFutureNoteTile: View {
    let text: String
    let dateLabel: String
    let appearance: AppAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(appearance.iconPrimary)
                Spacer(minLength: 0)
            }

            Text(text)
                .font(.body)
                .foregroundStyle(appearance.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)

            Text(dateLabel)
                .font(.caption)
                .foregroundStyle(appearance.tertiaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .besortedGlass(
            appearance,
            tint: appearance.tileTint.opacity(0.85),
            in: .rect(cornerRadius: 18),
            role: .content
        )
    }
}

// MARK: - Full tab snapshots

private struct TourPlanTabSnapshot: View {
    let buildStep: Int
    let pickMode: Bool
    let appearance: AppAppearance

    private func layer(_ step: Int) -> Bool { buildStep >= step }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                if layer(1) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aktualny Plan".l10n)
                                .font(.title.weight(.bold))
                                .foregroundStyle(appearance.primaryText)
                            Text("\(3)/\(CurrentPlanStore.maxActiveTasks) zadań")
                                .font(.subheadline)
                                .foregroundStyle(appearance.tertiaryText)
                        }
                        Spacer(minLength: 0)
                        TourChromeIconCapsule(
                            systemImage: "sparkles",
                            tinted: pickMode,
                            appearance: appearance
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .tourBuildTransition(layer(1))
                }

                if pickMode, layer(2) {
                    Text("Wybierz zadanie, które AI ma rozbić na kroki".l10n)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .tourBuildTransition(layer(2))
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if layer(pickMode ? 3 : 2) {
                            TourSnapshotTaskTile(
                                name: "Dopracuj ekran planu",
                                details: "Ujednolicić kafelki i odstępy jak w Moich projektach.",
                                kindTitle: TaskKind.polish.title,
                                kindImage: TaskKind.polish.systemImage,
                                importance: 5,
                                planStatus: .projectName("Syncly"),
                                highlighted: pickMode && !layer(4),
                                appearance: appearance
                            )
                            .tourBuildTransition(layer(pickMode ? 3 : 2))
                        }

                        if !pickMode, layer(3) {
                            TourSnapshotTaskTile(
                                name: "Dodaj powiadomienia",
                                details: "Przypomnienia o zadaniach z Aktualnego Planu.",
                                kindTitle: TaskKind.mechanics.title,
                                kindImage: TaskKind.mechanics.systemImage,
                                importance: 4,
                                planStatus: .projectName("Syncly"),
                                appearance: appearance
                            )
                            .tourBuildTransition(layer(3))
                        }

                        if !pickMode, layer(4) {
                            TourSnapshotTaskTile(
                                name: "Testy na urządzeniu",
                                details: "Sprawdzić synchronizację z Watch.",
                                kindTitle: TaskKind.fix.title,
                                kindImage: TaskKind.fix.systemImage,
                                importance: 3,
                                planStatus: .projectName("BeSorted Watch"),
                                appearance: appearance
                            )
                            .tourBuildTransition(layer(4))
                        }

                        if pickMode, layer(4) {
                            tourBreakdownPanel
                                .tourBuildTransition(layer(4))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 56)
                }
            }

            if layer(1), !pickMode || !layer(4) {
                TourMiniAppTabBar(selected: .plan, appearance: appearance)
                    .tourBuildTransition(layer(1))
            }
        }
        .scaleEffect(0.82, anchor: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Jak panel z `PlanTaskAIAssistOverlay.breakdownPanel`.
    private var tourBreakdownPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Jak wykonać to zadanie".l10n)
                .font(.title3.weight(.bold))
                .foregroundStyle(appearance.primaryText)

            Text("Do 3 punktów na podstawie opisu zadania, projektu i plików kontekstowych")
                .font(.footnote)
                .foregroundStyle(appearance.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                tourBreakdownRow(1, "Porównaj odstępy z listą Moje projekty.")
                tourBreakdownRow(2, "Ujednolić glass i cornerRadius kafelków.")
                tourBreakdownRow(3, "Sprawdź wygląd na jasnym i ciemnym motywie.")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .besortedGlass(
            appearance,
            interactive: true,
            tint: appearance.tileTint.opacity(0.9),
            in: .rect(cornerRadius: 22),
            minimumFrost: AppAppearance.panelGlassMinimumFrost,
            role: .content
        )
    }

    private func tourBreakdownRow(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index).")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(appearance.tertiaryText)
                .frame(width: 22, alignment: .leading)
            Text(text)
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

private struct TourProjectsTabSnapshot: View {
    let buildStep: Int
    let appearance: AppAppearance

    private func layer(_ step: Int) -> Bool { buildStep >= step }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if layer(1) {
                    // Jak `ProjectsTabView.topToolbar` — search / more / plus / AI.
                    HStack(spacing: 12) {
                        Spacer(minLength: 0)
                        TourChromeIconCapsule(systemImage: "magnifyingglass", size: 48, appearance: appearance)
                        TourChromeIconCapsule(systemImage: "ellipsis", size: 48, appearance: appearance)
                        TourChromeIconCapsule(systemImage: "plus", size: 48, appearance: appearance)
                        TourChromeIconCapsule(systemImage: "sparkles", size: 48, appearance: appearance)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .tourBuildTransition(layer(1))
                }

                if layer(2) {
                    Text("Wybierz projekt do streszczenia".l10n)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(appearance.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .besortedGlass(
                            appearance,
                            interactive: true,
                            tint: appearance.tileTint.opacity(0.9),
                            in: .capsule
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .tourBuildTransition(layer(2))
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if layer(3) {
                            TourSnapshotProjectTile(
                                name: "Syncly",
                                details: "Aplikacja do porządkowania projektów z AI i synchronizacją na Apple Watch.",
                                kindTitle: ProjectKind.app.title,
                                assetImageName: ProjectKind.app.tileImageName,
                                importance: 5,
                                isPriority: true,
                                highlighted: true,
                                appearance: appearance
                            )
                            .tourBuildTransition(layer(3))
                        }
                        if layer(4) {
                            TourSnapshotProjectTile(
                                name: "Notatnik",
                                details: "Zbiór krótkich historii i scen.",
                                kindTitle: ProjectKind.story.title,
                                assetImageName: ProjectKind.story.tileImageName,
                                importance: 3,
                                appearance: appearance
                            )
                            .tourBuildTransition(layer(4))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 56)
                }
            }

            if layer(1) {
                TourMiniAppTabBar(selected: .projects, appearance: appearance)
                    .tourBuildTransition(layer(1))
            }
        }
        .scaleEffect(0.82, anchor: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private enum TourProjectDetailMode {
    case summarizeDescription
    case proposeTasks
    case remindProject
    case whatCanIDoNow
    case evaluateProject
}

private struct TourProjectDetailSnapshot: View {
    let buildStep: Int
    let mode: TourProjectDetailMode
    let appearance: AppAppearance

    private func layer(_ step: Int) -> Bool { buildStep >= step }

    private var selectedTab: ProjectDetailTab {
        switch mode {
        case .remindProject, .whatCanIDoNow: return .futureNote
        default: return .tasks
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                if layer(1) {
                    // Jak `ProjectDetailView` — back + akcje; tytuł jest w treści.
                    HStack(spacing: 10) {
                        TourChromeIconCapsule(systemImage: "chevron.left", appearance: appearance)
                        Spacer(minLength: 0)
                        TourChromeIconCapsule(systemImage: "ellipsis", appearance: appearance)
                        TourChromeIconCapsule(systemImage: "square.and.arrow.up", appearance: appearance)
                        TourChromeIconCapsule(systemImage: "sparkles", appearance: appearance)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .tourBuildTransition(layer(1))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if layer(2) {
                            Text("Syncly")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(appearance.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .tourBuildTransition(layer(2))
                        }

                        switch mode {
                        case .summarizeDescription:
                            if layer(3) {
                                Text("Aplikacja do porządkowania projektów kreatywnych: zadania, błędy, notatki przyszłości i AI.")
                                    .font(.body)
                                    .foregroundStyle(appearance.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .tourBuildTransition(layer(3))
                            }
                            if layer(4) {
                                tourDescriptionSummaryOverlay
                                    .tourBuildTransition(layer(4))
                            }

                        case .proposeTasks:
                            if layer(3) {
                                TourSnapshotTaskTile(
                                    name: "Ułóż strukturę menu",
                                    details: "Zakładki projektu i przejścia między nimi.",
                                    kindTitle: TaskKind.mechanics.title,
                                    kindImage: TaskKind.mechanics.systemImage,
                                    importance: 4,
                                    planStatus: .none,
                                    appearance: appearance
                                )
                                .tourBuildTransition(layer(3))
                            }
                            if layer(4) {
                                tourProposedTasksOverlay
                                    .tourBuildTransition(layer(4))
                            }

                        case .remindProject, .whatCanIDoNow:
                            if layer(3) {
                                TourSnapshotFutureNoteTile(
                                    text: "Dodać tryb offline i synchronizację z zegarkiem.",
                                    dateLabel: "14 wrz 2026, 18:02",
                                    appearance: appearance
                                )
                                .tourBuildTransition(layer(3))
                            }
                            if layer(4) {
                                tourFutureNotesAIOverlay
                                    .tourBuildTransition(layer(4))
                            }

                        case .evaluateProject:
                            if layer(3) {
                                TourSnapshotTaskTile(
                                    name: "Dopracuj rdzeń gry",
                                    details: "Mechaniki i gameloop muszą mówić jednym głosem.",
                                    kindTitle: TaskKind.mechanics.title,
                                    kindImage: TaskKind.mechanics.systemImage,
                                    importance: 5,
                                    planStatus: .none,
                                    appearance: appearance
                                )
                                .tourBuildTransition(layer(3))
                            }
                            if layer(4) {
                                tourEvaluateProjectOverlay
                                    .tourBuildTransition(layer(4))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 58)
                }
            }

            if layer(1), !layer(4) {
                TourMiniProjectDetailTabBar(selected: selectedTab, appearance: appearance)
                    .tourBuildTransition(layer(1))
            }
        }
        .scaleEffect(0.82, anchor: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Jak `ProjectDescriptionSummaryOverlay`.
    private var tourDescriptionSummaryOverlay: some View {
        TourAIResultPanel(appearance: appearance) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Streszczenie AI".l10n)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                    Spacer()
                    TourCloseCircle(appearance: appearance)
                }

                Text("Oryginalny opis projektu pozostaje nietknięty, dopóki go nie zastąpisz.".l10n)
                    .font(.footnote)
                    .foregroundStyle(appearance.secondaryText)

                AIFormattedResultText(
                    text: AppLanguage.stored.isEnglish
                        ? "Syncly helps organize creative projects, Current Plan and tasks with Smart Assistant — on iPhone."
                        : "Syncly pomaga ogarniać projekty, Aktualny Plan i zadania z pomocą Smart Assistant — lokalnie na iPhonie.",
                    primary: appearance.primaryText,
                    secondary: appearance.secondaryText
                )

                Text("Zastąp oryginalny opis".l10n)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(appearance.selectedTabForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
            }
        }
    }

    /// Jak `ProposedTasksReviewOverlay`.
    private var tourProposedTasksOverlay: some View {
        TourAIResultPanel(appearance: appearance) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Propozycje AI".l10n)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(appearance.primaryText)

                Text("7 kluczowych elementów projektu".l10n)
                    .font(.footnote)
                    .foregroundStyle(appearance.secondaryText)

                VStack(alignment: .leading, spacing: 10) {
                    tourProposalRow(
                        index: 1,
                        name: "Dodaj ekran ustawień",
                        details: "Motyw, język i Smart Assistant.",
                        kind: TaskKind.element,
                        importance: 5
                    )
                    tourProposalRow(
                        index: 2,
                        name: "Powiadomienia planu",
                        details: "Przypomnienia o otwartych zadaniach.",
                        kind: TaskKind.mechanics,
                        importance: 4
                    )
                }

                HStack(spacing: 10) {
                    Text("Odrzuć".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .besortedAdaptiveGlassButton(appearance)

                    Text("Zatwierdź".l10n)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(appearance.selectedTabForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
                }
            }
        }
    }

    private func tourProposalRow(
        index: Int,
        name: String,
        details: String,
        kind: TaskKind,
        importance: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(index). \(name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                Spacer()
                Text(kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.tertiaryText)
            }
            Text(details)
                .font(.footnote)
                .foregroundStyle(appearance.secondaryText)
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= importance ? "star.fill" : "star")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(star <= importance ? Color.yellow : appearance.starEmpty)
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

    /// Jak `FutureNotesAIResultOverlay`.
    private var tourFutureNotesAIOverlay: some View {
        TourAIResultPanel(appearance: appearance) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(mode == .whatCanIDoNow ? "Co mogę zrobić teraz".l10n : "Przypomnienie projektu".l10n)
                        .font(mode == .remindProject ? .title2.weight(.bold) : .title3.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TourCloseCircle(appearance: appearance)
                }

                if mode == .remindProject {
                    tourIdentityCard
                }

                if mode == .whatCanIDoNow {
                    AIFormattedResultText(
                        text: AppLanguage.stored.isEnglish
                            ? "**Polish the plan screen**\nHighest priority among open tasks (5/5)."
                            : "**Dopracuj ekran planu**\nMa najwyższy priorytet wśród otwartych zadań (5/5).",
                        primary: appearance.primaryText,
                        secondary: appearance.secondaryText
                    )
                } else {
                    AIFormattedResultText(
                        text: AppLanguage.stored.isEnglish
                            ? "Syncly is a creative project hub with Current Plan, bugs and future notes — plus Smart Assistant."
                            : "Syncly to hub projektów kreatywnych z Aktualnym Planem, błędami i notatkami przyszłości — plus Smart Assistant.",
                        primary: appearance.primaryText,
                        secondary: appearance.secondaryText
                    )
                }

                Text("Zamknij".l10n)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(appearance.selectedTabForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
            }
        }
    }

    /// Jak `FutureNotesAIResultOverlay` dla Ocena projektu.
    private var tourEvaluateProjectOverlay: some View {
        TourAIResultPanel(appearance: appearance) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text("Krytyka projektu".l10n)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TourCloseCircle(appearance: appearance)
                }

                tourIdentityCard

                AIFormattedResultText(
                    text: AppLanguage.stored.isEnglish
                        ? """
                        ## Opinion on the idea
                        The concept **can stay**, but needs a sharper focus.

                        ## Standout or cheap copy
                        Close to a familiar productivity template — elevate the **Watch + Plan** angle.

                        ## Recommended actions
                        Cut secondary features and double down on the daily plan loop.
                        """
                        : """
                        ## Opinia o pomyśle
                        Koncepcję **można zostawić**, ale potrzebuje ostrzejszego fokusu.

                        ## Wyróżnik czy tania kopia
                        Blisko znanego szablonu produktywności — wzmocnij kąt **Watch + Plan**.

                        ## Zalecane działania
                        Odetnij poboczne funkcje i postaw na pętlę dziennego planu.
                        """,
                    primary: appearance.primaryText,
                    secondary: appearance.secondaryText
                )

                Text("Zamknij".l10n)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(appearance.selectedTabForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .besortedAdaptiveProminentButton(appearance, tint: appearance.selectedTabTint)
            }
        }
    }

    private var tourIdentityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            tourIdentityRow(label: "Nazwa projektu".l10n, value: "Syncly", image: "textformat")
            tourIdentityRow(
                label: "Typ gry".l10n,
                value: ProjectKind.game.title,
                image: ProjectKind.game.systemImage
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("Ocena projektu".l10n)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.tertiaryText)
                    .textCase(.uppercase)
                    .tracking(0.4)
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.yellow)
                    }
                    Text("5/5")
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

    private func tourIdentityRow(label: String, value: String, image: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: image)
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
            }
        }
    }
}

/// Wycinek jak `AIAssistantView` — pastylka na środku + czerwony przycisk zamknięcia.
private struct TourAIAssistantSnapshot: View {
    let buildStep: Int
    let appearance: AppAppearance

    private func layer(_ step: Int) -> Bool { buildStep >= step }

    var body: some View {
        ZStack {
            appearance.screenBackgroundGradient

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Group {
                    if layer(3) {
                        ScrollView {
                            AIFormattedResultText(
                                text: AppLanguage.stored.isEnglish
                                    ? "## Open tasks\nYou have **3** open tasks in Syncly. Highest priority: **Polish the plan screen**."
                                    : "## Otwarte zadania\nMasz **3** otwarte zadania w Syncly. Najwyższy priorytet: **Dopracuj ekran planu**.",
                                primary: appearance.primaryText,
                                secondary: appearance.secondaryText
                            )
                        }
                        .frame(maxWidth: 420, maxHeight: 160, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .besortedGlass(
                            appearance,
                            interactive: true,
                            tint: appearance.tileTint.opacity(0.85),
                            in: .rect(cornerRadius: 28),
                            role: .content
                        )
                        .tourBuildTransition(layer(3))
                    } else if layer(2) {
                        Text("Jakie mam otwarte zadania w Syncly?")
                            .font(.body.weight(.medium))
                            .foregroundStyle(appearance.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: 420)
                            .besortedGlass(
                                appearance,
                                interactive: true,
                                tint: appearance.tileTint.opacity(0.85),
                                in: .capsule
                            )
                            .tourBuildTransition(layer(2))
                    } else if layer(1) {
                        Text("Zapytaj AI…".l10n)
                            .font(.body.weight(.medium))
                            .foregroundStyle(appearance.promptText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: 420, alignment: .leading)
                            .besortedGlass(
                                appearance,
                                interactive: true,
                                tint: appearance.tileTint.opacity(0.85),
                                in: .capsule
                            )
                            .tourBuildTransition(layer(1))
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 0)

                if layer(4) {
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
                        .padding(.bottom, 28)
                        .tourBuildTransition(layer(4))
                }
            }
        }
        .scaleEffect(0.86, anchor: .center)
    }
}

private extension View {
    func tourBuildTransition(_ visible: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .scaleEffect(visible ? 1 : 0.97, anchor: .top)
    }
}
