# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

- Single user: an individual organizing their own projects, tasks, bugs, and future notes. Personal, one-user product; data lives on the user's device.
- No confirmed multi-user or team audiences.

## Product Purpose

A native iOS organizer that keeps the user's own projects in one place - each project with its tasks, current bugs, and future notes - and builds a bounded daily "Aktualny Plan" from those tasks. AI acts as an optional in-context assistant inside that workflow. Success means the user finds, advances, and plans their projects without switching tools.

## Positioning

- The meaningful difference is AI as a hands-on assistant inside the user's own project workflow: it evaluates tasks/projects, summarizes details, decomposes tasks into steps, proposes and adds tasks, reads details aloud/progressively, and assembles the current plan - all from real user data, not a separate chat surface.
- A neighboring generic task app could copy tiles; it could not truthfully copy AI assistance bound to this project+plan structure.

## Operating Context

- Runs on iPhone and iPad (device family 1,2), portrait and landscape. In landscape the navigation dock moves to the right edge as a vertical pill; in portrait the horizontal menu pill sits at the bottom. Pills collapse on scroll (MenuPillCollapse with portrait/landscape distances).
- Core workflow: open a project -> work across Zadania (tasks), Aktualne błędy (bugs), Notatka przyszłości (future notes); long-press/pill actions per row; invoke AI menus per project/task/notes; assemble Aktualny Plan from task queue; optionally enable Smart Mode for a chrome-light focus view.

## Capabilities and Constraints

- SwiftUI app; iOS deployment 26.5-27.0; TARGETED_DEVICE_FAMILY = "1,2" (iPhone + iPad).
- Top-level sections: Moje projekty, Aktualny Plan, Ustawienia.
- Project detail subsections: Zadania / Aktualne błędy / Notatka przyszłości.
- Tasks: importance 1-5 stars, kind, details, plan status ("W kolejce do planu" / "W aktualnym planie").
- Aktualny Plan: task count limited by planMaxTasks (1-10, clamped; CurrentPlanStore.maxActiveTasks).
- AI: project-level AI menu, per-task AI (evaluate / summarize / decompose into steps), future-notes AI, plan AI (builds the current plan), progressive AI "reading" of details, proposed-tasks review, project context files, project core overlay. AI features are gated by skill/or pro-unlock prompts (SmartAssistantStore.requireSkillOrPromptUpgrade) and have a pro unlock path.
- Smart Mode: collapses the menu pill and header chrome to keep focus on content.
- Visual identity: configurable liquid-glass styles (Full / Balanced / Zero flat), neomorphic, and flat designs with a single tint accent; custom glass surfaces and capsule navigation chrome; deletion flows use wiggle + flying-away animations.
- Sync: PhoneWatchSyncService present (push project-deleted sync); no watch target in this repository.
- Navigation conventions: horizontal menu pill at the bottom in portrait; vertical dock at the right edge in landscape; pills collapse on scroll.

## Brand Commitments

- The glass + Smart Mode vision is the intended identity (user-confirmed).
- UI copy is Polish-first (".l10n" strings); English copy is secondary.
- Xcode scheme/target named "BeSorted"; on-device display name "Syncly" (INFOPLIST_KEY_CFBundleDisplayName = Syncly); bundle id com.michaelproduct.syncly.

## Evidence on Hand

- Full source under BeSorted/ (ContentView.swift ~10.6k lines, AppAppearance.swift ~2.3k lines, SmartMode.swift, SmartAssistantViews.swift, SmartAssistantTourSnapshots.swift, PRODUCT.md absent before this init).
- No README, marketing copy, testimonials, press mentions, or app-store assets exist in this repository; future work must not fabricate them.

## Product Principles

1. The user's own projects come first: projects, tasks, bugs, and future notes live together and are reachable in seconds.
2. AI assists but the user holds control: AI proposes, evaluates, summarizes, and builds; confirmations and decisions stay with the user.
3. Aktualny Plan is finite and derived from real project tasks - a bounded focus for the day, not an infinite list.
4. Smart Mode strips chrome when the user wants pure content; collapsing-pill navigation supports that focus without hiding structure.
5. Native-first across form factors: the experience is native SwiftUI tuned for iPhone and iPad, in both portrait and landscape.