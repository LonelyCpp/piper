# Piper — Implementation Plan

Menu-bar app for macOS that fires **arbitrary user-defined reminders** on an
interval, escalating to a full-screen overlay until acknowledged.

The gap this fills: existing apps hardcode wellness presets (eye breaks,
posture, water) with one shared interval, **or** let you set an arbitrary
interval but only ever show a notification banner. Piper does both — a list of
*your* rules, each with its own schedule, any of which can take over the screen.

## Status

| Phase | Scope                                            | Status      |
| ----- | ------------------------------------------------ | ----------- |
| 0     | Repo scaffold, AI-readiness, docs                | ✅ complete |
| 1     | Data model + persistence                         | ⬜ not started |
| 2     | Scheduler (next-fire computation, timer)         | ⬜ not started |
| 3     | Overlay window (NSPanel takeover)                | ⬜ not started |
| 4     | UI (dashboard, editor, quick-add)                | ⬜ not started |
| 5     | System integration (login item, sound)           | ⬜ not started |
| 6     | Build, bundle, ship, docs                        | ⬜ not started |

Phases run **in order**. Do not begin a phase until the previous one is done and
the user has asked for it.

---

## Phase 0 — Scaffold ✅

Establish the repo, toolchain, and documentation so that Phases 1–6 have
somewhere to land.

- [x] SwiftPM package, macOS 14+, no `.xcodeproj`
- [x] `MenuBarExtra` shell that builds and launches
- [x] `Info.plist` with `LSUIElement`, anti-auto-termination keys
- [x] `Scripts/bundle.sh` + `Scripts/dev.sh` + `Makefile`
- [x] `AGENTS.md`, README, lint/format configs, CI workflow
- [x] `docs/` — this plan, architecture, decisions, todo, worklog

---

## Phase 1 — Data model & persistence

Pure data. No AppKit anywhere in this phase.

**`Reminder`** (`Models/Reminder.swift`)

| Field                    | Type              | Notes                                              |
| ------------------------ | ----------------- | -------------------------------------------------- |
| `id`                     | `UUID`            |                                                      |
| `title`                  | `String`          | e.g. "Drink water"                                   |
| `detail`                 | `String`          | optional subtext                                     |
| `intervalMinutes`        | `Int`             | ≥ 1                                                  |
| `anchor`                 | `Date`            | schedules phase from a known origin                  |
| `weekdays`               | `Set<Int>`        | 1 = Sunday … 7 = Saturday; **empty = every day**     |
| `windowStartMinute`      | `Int?`           | minutes from midnight; `nil` = no window            |
| `windowEndMinute`        | `Int?`           | supports overnight ranges (`22:00`–`06:00`)         |
| `style`                  | `ReminderStyle`   | `.fullscreen` / `.card` / `.notification`            |
| `strict`                 | `Bool`            | modal — cannot be dismissed by clicking away        |
| `soundEnabled`           | `Bool`            |                                                      |
| `snoozeMinutes`          | `Int`             |                                                      |
| `escalateAfterMinutes`   | `Int?`            | `nil` = never escalate                               |
| `enabled`                | `Bool`            |                                                      |

**`ReminderStore`** (`Models/ReminderStore.swift`)

- `@Observable` class, single source of truth for the whole app.
- Codable → JSON at `~/Library/Application Support/Piper/reminders.json`
  (inject the directory rather than hardcoding it — it is not sandbox-safe).
- Write atomically, debounce to ~0.5 s, flush on `NSApplication.willTerminate`.
- Seed one "Drink water / every 60 min" reminder on first launch so the app is
  never an empty void.
- Expose `Settings` (global: pause-all, default style, target screen).

**Done when:** model round-trips through JSON, store survives a relaunch,
unit tests pass for the date/window arithmetic introduced in Phase 2.

---

## Phase 2 — Scheduler

Answers *when*. Knows nothing about *how* anything is displayed.

**`nextFire(after:)`** on `Reminder`

- Walk `anchor + k · interval` forward and return the first candidate that
  satisfies both the weekday set and the active window.
- If `anchor` is still in the future and is itself active, return it.
- **Cap the walk** (suggest 100 000 steps) and return `nil` on overflow so a
  pathological rule (1-minute interval inside a 1-minute window on a weekday
  filter) degrades to "never fires" instead of hanging the main thread.
- Overnight windows must compare correctly (`start > end` means wrap).

**`Scheduler`** (`Scheduler/`)

- Exactly **one** `DispatchSourceTimer`, re-armed to the earliest next fire
  across all enabled reminders, then re-armed after each pop. Not one timer per
  reminder — they drift and multiply wakeups.
- **Pending queue.** Two rules falling due in the same tick must queue, not race
  for a single overlay. Show one at a time, then the next.
- On fire, hand the reminder to `OverlayController`, then re-arm from
  `now` (not from the missed timestamp).
- Honour pause-all and per-reminder `enabled`.
- Configurable `leeway` (suggest 1 s) — exactness is not worth the wakeups.

**`SystemEvents`** (`Scheduler/SystemEvents.swift`)

Re-arm on all of:

| Notification                                | Why                                        |
| ------------------------------------------- | ------------------------------------------ |
| `NSWorkspace.didWakeNotification`           | post-sleep drift, often by hours            |
| `NSNotification.Name.NSSystemClockDidChange`| timezone / DST changes                      |
| `NSApplication.didChangeScreenParametersNotification` | displays added/removed           |
| `NSWorkspace.sessionDidResignActiveNotification` | optionally skip while locked        |

**Done when:** a rule created for "every 1 minute" fires roughly on schedule,
and survives sleep/wake and a timezone change without a restart.

---

## Phase 3 — Overlay

The part worth getting right. Everything above is bookkeeping; this is the
product.

**`OverlayController`** (`Overlay/`)

One reused `NSPanel`, not a window per reminder:

```swift
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.level = .screenSaver
panel.collectionBehavior = [
    .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary
]
panel.orderFrontRegardless()
```

- `.screenSaver` beats full-screen apps, the Dock, and menu-bar extras.
- `.fullScreenAuxiliary` + `.canJoinAllSpaces` is what makes it appear **inside**
  another app's full-screen Space and on every Space. Omit these and it silently
  fails half the time — this is the single most-missed detail in apps like this.
- `.nonactivatingPanel` so the overlay does not steal key focus from the
  frontmost app.
- Reuse `NSHostingView` and swap the root view per reminder.

**Target screen**

- Default: the screen containing `NSEvent.mouseLocation` — multi-monitor users
  notice instantly if this is wrong.
- Optional "all displays".
- Use `NSScreen.screens`, guard against an empty list (unplug everything while
  an overlay is up).

**Styles**

| Style           | Behaviour                                                        |
| --------------- | ---------------------------------------------------------------- |
| `.fullscreen`   | opaque, edge-to-edge — for genuinely hard-focus blocks            |
| `.card`         | dimmed + blurred backdrop with a centred card — **the default**    |
| `.notification` | plain `UNUserNotificationCenter` banner, no overlay               |

Defaulting to `.card` because a blackout screen is hostile; `.fullscreen` is
opt-in per reminder.

**Escalation**

- Timer armed at `escalateAfterMinutes`.
- Re-render to urgent styling, loop the alert sound, grow the dismiss target.
- Optional **auto-dismiss cap** so a forgotten reminder can never wedge the
  machine indefinitely. Default: on, generous (suggest 10 min).

**Actions**

- `Done` · `Snooze (n min)` · `Skip this once` — every path reachable by mouse
  **and** keyboard.
- `strict` → wrap in `NSApp.runModal(for: panel)`. Runs a nested event loop, so
  timers keep firing, but state gets subtle. Document the trap when you build it.

**Done when:** a reminder appears above a full-screen app, survives Cmd-Tab and
Space switches, and can always be dismissed.

---

## Phase 4 — UI

Functional first; visual polish deferred until Phase 3 is proven.

**Dashboard** (`Views/Dashboard.swift`, `MenuBarExtra`)

- Menu-bar label: next reminder name + live countdown, or a clock when idle.
- List of reminders, each with its own countdown and enable toggle.
- Quick-add field, `Pause all`, `Quit`.
- Use `.window` menu-bar style rather than `.menu` — the editor needs real
  layout. The overlay is `.screenSaver` level so it covers the popover anyway.

**Editor** (`Views/EditorView.swift`)

Title, detail, interval, style, strict/escalation/snooze, weekdays, active
window. Validate as you type (interval ≥ 1, end ≠ start).

**Quick-add parser** (`Models/QuickAddParser.swift`)

Understands a useful subset, and **falls back to opening the editor** when it
cannot parse — never silently drops the user's intent:

- `every 30m`, `every 2 hours`
- `daily at 9am`, `at 09:30`
- `weekdays 9:30`, `every weekday at 2pm`

Regex over a normalised string; extract `intervalMinutes`, an optional
time-of-day anchor, and an optional weekday set. Return `nil` on anything else.

**Done when:** `every 45m water` creates a working reminder from one field, and
a rule can be created entirely through the editor.

---

## Phase 5 — System integration

- **Launch at login** — `SMAppService.mainApp`. Throws when unsigned or the app
  is outside `/Applications`; catch and surface a real message rather than
  crashing. Requires the app bundle, so this cannot be tested via `swift run`.
- **Sound** — bundled audio asset, plus `NSSound` by name for system sounds.
  Loop for escalation; respect the user's volume, never force it.
- **Notifications** — request authorisation **only** if a rule uses
  `.notification` style. Ask at the point of use, not on launch.

---

## Phase 6 — Ship

- Release bundle, ad-hoc signature (document the Developer ID path for real
  distribution).
- `make install` → `/Applications`.
- README: install, first-run, the sleep/notification caveats.
- Worklog + decisions updated; TODOs closed or moved to a backlog.

---

## Risks & unknowns

| Risk                                                    | Mitigation                                             |
| ------------------------------------------------------- | ------------------------------------------------------ |
| Overlay doesn't cover a full-screen Space               | `.fullScreenAuxiliary` + `.canJoinAllSpaces`; test manually |
| Post-sleep timing drift                                 | `didWake` re-arm; verify against real sleep/wake        |
| Modal (`strict`) deadlocks on a modal sheet             | defer `strict` until the dashboard is solid             |
| Menu-bar app auto-terminated for having no windows      | `NSSupportsAutomaticTermination = false` in `Info.plist` |
| `UNUserNotificationCenter` silently not delivering       | don't rely on it for the overlay path at all             |
| Agents drifting into Phase 1+ unasked                    | this table, plus the phase rule in `AGENTS.md`          |
