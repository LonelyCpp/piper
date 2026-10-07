# AGENTS.md

Instructions for AI agents working in this repository. Read this before
touching code. It is the short version — `docs/PLAN.md` has the full plan and
`docs/ARCHITECTURE.md` has the design detail.

## What this is

**Piper** — a macOS 14+ menu-bar app that fires arbitrary user-defined
reminders on an interval, escalating to a full-screen overlay until
acknowledged. SwiftPM package, SwiftUI for UI, AppKit for the overlay.
Menu-bar only (`LSUIElement`), no dock icon.

## Phase discipline — read this first

Work is split into numbered phases (0–6) in `docs/PLAN.md`.

**Only work on the phase you were asked for.** Do not run ahead into the next
phase, even when it looks like an obvious improvement. A scaffolded-but-unwired
scheduler in Phase 1 makes Phase 2 harder to review, not easier.

If you believe the plan is wrong, say so and stop. Do not silently redesign.

When a phase completes:

1. Update the status table in `docs/PLAN.md`.
2. Append an entry to `docs/WORKLOG.md` — what changed, what you verified, what
   you deliberately left out.
3. Tick items off in `docs/TODO.md`, and add anything newly discovered.

## Commands

```sh
make build          # swift build (debug)
make bundle         # assemble build/Piper.app (release)
make run            # debug bundle + launch
make install        # release bundle -> /Applications (sudo)
make check          # build + lint + format check
make clean
```

`make run` goes through `Scripts/dev.sh`, **not** `swift run`, and that is
deliberate: a bare SwiftPM executable has no `Info.plist`, so no `LSUIElement`
(stray dock icon) and no bundle identifier for launch-at-login. Any UI or
overlay behaviour must be verified against the bundled app.

`swiftformat` and `swiftlint` are **not currently installed**. `make lint` and
`make format` will tell you so and exit non-zero. Install with
`brew install swiftlint swiftformat` if you want them; the configs
(`.swiftlint.yml`, `.swiftformat`) are already committed.

There are no tests yet. The first test target arrives with Phase 2's date
arithmetic — until then, `make build` is the only automated gate, so verify
behaviour by running the app.

## Architecture rules

Layering is strict, and it exists to keep the overlay code from spreading:

```
Models/       pure data + date arithmetic.   NO AppKit. NO SwiftUI.
Scheduler/    when to fire.                   NO AppKit. NO SwiftUI.
Overlay/      how to take over the screen.     AppKit lives here.
Views/        SwiftUI only.
Support/      small system integrations (sound, login item).
```

- **`Models` and `Scheduler` must not import AppKit.** If you find yourself
  wanting `NSScreen` or `NSWorkspace` in the scheduler, you have a design
  problem — surface it as a protocol or a callback instead.
- `Overlay` is the only place that creates windows.
- One reused `NSPanel`, not a window per reminder. Swap the `NSHostingView`
  root view instead.
- Persistence is Codable → JSON in Application Support. No SwiftData; the data
  model is tiny and migration is not worth it.
- `@Observable` (Observation) for app state, not `ObservableObject`.

## Conventions

- Swift 5 language mode, despite a `swift-tools-version: 6.0` manifest — see
  `docs/DECISIONS.md` ADR-0002. Do not "upgrade" it as a drive-by change.
- 4-space indent, 120 column soft limit, no tabs except in the `Makefile`.
- No comments that restate the code. Comment the *why*, especially for AppKit
  behaviour that looks wrong but is not (see below).
- Prefer composition over subclassing. No singletons except where the framework
  forces one (`OverlayController` is a reasonable candidate — justify it if so).
- SwiftUI previews for every view that can reasonably have one.

## macOS traps — do not relearn these

These have each cost a real app its "the overlay doesn't work" bug:

- **Overlay must set `collectionBehavior`** to
  `[.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]`.
  Without `.fullScreenAuxiliary` + `.canJoinAllSpaces` it will not appear over
  another app's full-screen Space, and it fails silently.
- **`level = .screenSaver`** is what beats full-screen apps and the Dock.
- **Menu-bar apps with no windows get auto-terminated** unless
  `NSSupportsAutomaticTermination = false` in `Info.plist`.
- **Do not use `UNUserNotificationCenter` to drive the overlay.** It will not
  present custom UI when the app is not running. It is only for the
  `.notification` style.
- **Re-arm the timer on `didWake`** and on `NSSystemClockDidChange`, or
  post-sleep reminders are hours off.
- **`NSScreen.screens` can be empty.** Guard display selection.
- `NSApp.runModal(for:)` runs a nested event loop: timers keep firing, but
  `strict` mode interacts subtly with sheets. Deferred until the dashboard is
  solid.

## When you add a decision

Anything with a "why would you do it differently" flavour goes in
`docs/DECISIONS.md` as an ADR:

```
### ADR-000N: Title
**Status:** accepted | superseded by ADR-000M
**Context:** the forces
**Decision:** what we chose
**Consequences:** what this costs us
```

Keep them short. A decision that isn't recorded will be re-litigated by the next
agent — including a future you.

## Definition of done

A task is done when:

- `make build` is clean, no new warnings.
- Behaviour verified by **running the bundled app**, not by reading the code.
  If you could not verify it, say so explicitly in the worklog.
- `docs/TODO.md` and `docs/WORKLOG.md` updated.
- No new untracked exceptions in `.gitignore`.
- Commit messages describe *why*, not *what*.

## Repository conventions

- Conventional-ish commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
- One logical change per commit; do not mix a refactor with a behaviour change.
- `main` is always buildable.
- Never commit `build/`, `.build/`, or `dist/` — all gitignored.
