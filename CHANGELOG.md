# Changelog

All notable changes to this fork. The project focuses on **layout, aesthetics
and usability** (margins, padding, alignment, typography, motion, dark-mode
parity, touch targets, empty states) on top of the wger workout-manager
codebase. Releases are built by GitHub Actions and published as signed APKs
(GitHub Releases + Nextcloud).

## [v0.10.0] — 2026-08-08 — Empty states & micro-detail
- New shared `EmptyState` widget (icon + title + subtitle + optional action).
- Applied to every emptyable surface: routines, exercises search, nutrition
  plan/diary, weight history, measurements, logs, gallery, dashboard.
- 14 new l10n keys across all 39 shipped locales.
- New `empty_state_test.dart`.

## [v0.9.0] — 2026-08-08 — Usability audit
- 48dp touch targets enforced (invisible hit-area growth where controls were
  shrunk below the Material minimum; glyphs unchanged).
- Accessibility tooltips on icon-only gym-mode navigation buttons.
- Readability constraints on long text lines; safe-area/ergonomics verified.

## [v0.8.0] — 2026-08-08 — Typography & dark-mode consistency
- Theme-usage pass: ad-hoc font styles → theme text styles; hardcoded color
  literals → theme lookups.
- Fixed dark-mode breakage: image-carousel page dots, muscle legend,
  search-field border, dietary chips, more.
- Extended ingredient-typeahead test with dark-mode contrast assertions.

## [v0.7.0] — 2026-08-08 — Motion & feel
- Theme-level page transitions (fade-up, respects reduced-motion).
- `PressableScale` press feedback on primary actions + hero card.
- Quick tab-switch fades; haptic on workout-impression toggles.
- Gym-mode start-page swipe easing (kept the proven page-turn curve — the
  M3 easing was CI-bisected to break the summary page turn).

## [v0.6.0] — 2026-08-07 — Polish pass 2
- 8dp-grid normalization across auth, exercises, nutrition, routine forms,
  weight, dashboard.
- Cross-screen consistency: list insets, section rhythm, tabular figures.

## [v0.5.1] — 2026-08-07 — Bugfix: infinite spinner on routine open
- Bounded waits for reference-data streams + REST fetch in routine hydration
  (was unbounded → hung forever when the server was unreachable).
- Offline fallback to cached routines in gym mode + routine list, with a
  clear SnackBar ("Offline — showing saved data") instead of a spinner.

## [v0.5.0] — 2026-08-06 — Visual polish (pass 1) + rest timer
- M3 8dp spacing grid; 16dp screen margins (24dp hero); 48dp touch targets;
  left labels / right tabular-figure numbers; 24dp section rhythm; 16dp card
  padding / 12dp radius; theme-only type hierarchy.
- Rest-timer overlay after logging a set (dismissible, reuses timer
  machinery).

## [v0.3.0] — 2026-08-05 — Gym-mode logging UX
- One-tap Log quick-set with previous weight/reps auto-fill (user edits win).
- X/Y set-progress indicator; 56dp primary action; compact past-log rows.

## [v0.2.0] — 2026-08-04 — Dashboard & navigation restyle
- Hero card, 5-tab bottom navigation, dashboard restyle.
- Fixed RenderFlex overflow on the exercise-summary row.

## [v0.1.0] — 2026-08-02 — Baseline
- Phase 0: GitHub Actions CI pipeline (analyze, 1100+ tests, signed arm64
  release APK); tap-and-slide weight/reps adjuster (`SlideAdjustNumberField`).

[Unreleased]: device sign-off; optional further polish iterations.
