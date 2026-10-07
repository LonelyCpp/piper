# TODO

Work in progress, ordered by phase. Phases run in order — do not start one until
the previous is closed. See `docs/PLAN.md` for scope.

Legend: `[ ]` open · `[~]` in progress · `[x]` done · `[!]` blocked

---

## Phase 0 — Scaffold ✅

- [x] SwiftPM package, macOS 14+, executable target
- [x] `MenuBarExtra` shell that compiles and launches
- [x] `Info.plist` — `LSUIElement`, `NSSupportsAutomaticTermination`,
      `NSSupportsSuddenTermination`
- [x] `Scripts/bundle.sh` — assemble + ad-hoc sign `Piper.app`
- [x] `Scripts/dev.sh` — bundle then launch (not `swift run`)
- [x] `Makefile` — `build`/`bundle`/`run`/`install`/`check`/`clean`
- [x] `AGENTS.md`
- [x] `docs/` — `PLAN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `TODO.md`,
      `WORKLOG.md`
- [x] `README.md`
- [x] `.gitignore`, `.editorconfig`, `.gitattributes`, `.swiftlint.yml`,
      `.swiftformat`
- [x] `.github/workflows/ci.yml`
- [x] Verified: `swift build` clean, `make bundle` produces a signed bundle,
      app launches and quits with no errors in the unified log

## Phase 1 — Data model & persistence

- [ ] `Reminder` struct — all fields per `PLAN.md`
- [ ] `nextFire(after:)` — weekday set, active window, overnight wrap
- [ ] `ReminderStore` — `@Observable`, Codable, atomic + debounced writes
- [ ] Inject the Application Support directory (no hardcoded path)
- [ ] Seed "Drink water / every 60 min" on first launch
- [ ] Global `Settings` (pause-all, default style, target screen)
- [ ] Flush store on `NSApplication.willTerminate`
- [ ] **Tests**: JSON round-trip, weekday filtering, overnight window

## Phase 2 — Scheduler

- [ ] Single `DispatchSourceTimer` armed at the earliest next fire
- [ ] Re-arm after each pop, from `now` (not the missed timestamp)
- [ ] Pending queue for simultaneous fires
- [ ] Honour pause-all and per-reminder `enabled`
- [ ] `SystemEvents` — `didWake`, `NSSystemClockDidChange`,
      `didChangeScreenParameters`, `sessionDidResignActive`
- [ ] **Tests**: capped walk, unsatisfiable rule → `nil`, DST edge, sleep/wake

## Phase 3 — Overlay

- [ ] Reused `NSPanel` — borderless, `.nonactivatingPanel`, `.screenSaver` level
- [ ] `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
      .ignoresCycle, .stationary]`
- [ ] Screen selection — under cursor, optional all-displays, empty-safe
- [ ] `.card` / `.fullscreen` / `.notification` styles
- [ ] Escalation — `escalateAfterMinutes` → urgent styling + looped sound
- [ ] Auto-dismiss cap (default on, generous)
- [ ] `Done` / `Snooze` / `Skip`, mouse **and** keyboard
- [ ] `strict` → `NSApp.runModal(for:)` (sequence last)
- [ ] **Verify against a real full-screen app** — the whole point of the phase

## Phase 4 — UI

- [ ] Dashboard — `MenuBarExtra` `.window` style, next-up + countdown
- [ ] Reminder list with per-rule countdowns and toggles
- [ ] Editor sheet — full rule, validated
- [ ] Quick-add parser — `every 45m`, `daily 9am`, `weekdays 9:30`
- [ ] Editor fallback when the parser returns `nil`

## Phase 5 — System integration

- [ ] Launch at login — `SMAppService.mainApp`, graceful failure when unsigned
- [ ] Bundled alert sound + system sounds
- [ ] Notification authorisation, requested only when `.notification` is used

## Phase 6 — Ship

- [ ] Release bundle + Developer ID signing path documented
- [ ] README: install, first run, sleep/notification caveats
- [ ] Close or backlog every remaining TODO

---

## Backlog (unphased)

- [!] `swiftlint` / `swiftformat` not installed — configs are committed and
      `make lint`/`make format` report this. `brew install swiftlint swiftformat`
- [ ] App icon — no `Assets.xcassets` yet
- [ ] Acknowledgement history / streak stats — revisit ADR-0003 when this lands
- [ ] Notification centre integration — remind only if no overlay shown for N days
