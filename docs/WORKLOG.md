# Work Log

Append-only, newest last. One entry per meaningful session or phase. Keep it
factual: what changed, what was verified, what was deliberately skipped.

If something is broken, unverified, or half-finished, say so here rather than
only in the commit message.

---

## 2026-10-07 — Phase 0: scaffold

**Context.** Surveyed the existing landscape before writing any code. Conclusion:
no macOS built-in does arbitrary interval reminders (Clock alarms are one-time,
Reminders repeats by day/week/month at a fixed time, Screen Time caps app usage,
Health uses fixed schedules). Two viable native workarounds exist — a Calendar
event with a custom minute-level repeat, or a Shortcuts `Wait`/`Show Notification`
loop — neither of which can take over the screen.

The OSS space is split in two. **Clocktower** has the arbitrary-rule model but
only sends notification banners. **Twenty**, **Screeny**, **Pausa**, **remindful**
and **Stretchly** have real full-screen overlays but a hardcoded model (20-20-20
eye breaks, Pomodoro, or a fixed wellness preset list). Nobody lets you keep your
own list of rules with per-rule schedules *and* have any of them take over the
screen. That gap is what Piper fills.

**Decided.**

- Named the project **Piper** (renamed from a placeholder directory).
- Native Swift/SwiftUI/AppKit, menu-bar only. Not cross-platform — the overlay
  *is* the product and it is a native-API problem.
- Default to a **non-modal card**, with `.fullscreen` opt-in per reminder. An
  always-opaque default would hide the document the user is trying to act on.
- SwiftPM package, no `.xcodeproj` (ADR-0001).
- Swift 5 language mode under a `swift-tools-version: 6.0` manifest (ADR-0002).
  Strict concurrency is deferred, not solved — the AppKit timer/modal plumbing in
  Phases 2–3 is the wrong time to fight it.
- Codable + JSON, no SwiftData (ADR-0003).
- `UNUserNotificationCenter` reserved for the `.notification` style only
  (ADR-0004).

**Built.**

- `Package.swift` — macOS 14+, single executable target, `.swiftLanguageMode(.v5)`.
- `Sources/Piper/PiperApp.swift` — `@main`, `MenuBarExtra` shell.
- `Sources/Piper/Views/PlaceholderMenu.swift` — Phase 0 placeholder menu.
- `Resources/Info.plist` — `LSUIElement`, `LSMinimumSystemVersion` 14.0,
  `NSSupportsAutomaticTermination = false` and `NSSupportsSuddenTermination = false`
  (a menu-bar app with no windows is otherwise a candidate for auto-termination),
  bundle id `dev.kanive.piper`.
- `Scripts/bundle.sh` — release/debug assemble + ad-hoc sign, copies any extra
  resources in `Resources/`, prints the bundle path.
- `Scripts/dev.sh` — bundles then launches. Deliberately not `swift run`: a bare
  SwiftPM executable has no `Info.plist`, so no `LSUIElement` (stray dock icon)
  and no bundle identifier for launch-at-login.
- `Makefile` — `build`, `release`, `bundle`, `run`, `install`, `uninstall`,
  `check`, `lint`, `format`, `format-check`, `clean`, `help`.
- AI-readiness: `AGENTS.md`, `README.md`, `.gitignore`, `.editorconfig`,
  `.gitattributes`, `.swiftlint.yml`, `.swiftformat`,
  `.github/workflows/ci.yml`, `docs/{PLAN,ARCHITECTURE,DECISIONS,TODO,WORKLOG}.md`.
- Six ADRs recorded (see `docs/DECISIONS.md`).
- `git init -b main`. **No commits made** — not requested.

**Verified** (all against the real bundle, not `swift run`):

| Check                                        | Result                            |
| -------------------------------------------- | --------------------------------- |
| `swift build`                                | Build complete, 4.69s, no warnings |
| `make bundle`                                | produced `build/Piper.app`        |
| `plutil -lint` on the bundled `Info.plist`  | OK                                |
| `LSUIElement` present                        | `true`                            |
| `codesign -dv`                               | adhoc, identifier `dev.kanive.piper` |
| `open build/Piper.app`                       | process alive (pid 10871)         |
| Unified log, last 30s, pid `Piper`           | no errors or faults               |
| Quit                                          | clean                             |

**Bug found during verification, and fixed.** The first cut of the `lint` /
`format` / `format-check` guards in the `Makefile` used a two-line form:

```make
@if [ -z "$(SWIFTLINT)" ]; then echo "..."; exit 1; fi
@$(SWIFTLINT) lint --strict
```

Make runs each recipe line in its **own shell**, so `exit 1` terminated only the
guard — the second line still executed with an empty variable, and make then
tried to run `lint` as a command (`make: lint: No such file or directory`, exit
127 masking the real exit 1). Caught by `make -n format-check`, which printed
the expanded recipe as `if [ -z "" ]; ... fi` followed by a bare `lint .`.

All three guards are now single-line `if …; then …; else …; fi`, so the early
exit genuinely prevents the command. Re-verified: `make lint` and `make format`
fail with exit 1 and an install hint; `make format-check` skips with exit 0;
`make check` builds then stops at `lint`.

Worth remembering as a general rule: a guard and the thing it guards belong on
the same recipe line.

**Deliberately not done.**

- No Phase 1 code. The `Models/`, `Scheduler/`, `Overlay/`, `Support/`
  directories exist with `.gitkeep` only — created so the committed tree matches
  `docs/ARCHITECTURE.md` and agents have a place to land.
- No tests. There is no test target yet; Phase 1 introduces the date arithmetic
  that first needs one.
- No app icon / `Assets.xcassets`. `bundle.sh` already copies it if present.
- No commit.

**Environment notes.**

- Toolchain: Swift 6.3.1, Xcode 26.4.1 (17E202), macOS 26.7.1, arm64.
- `swiftlint` and `swiftformat` are **not installed**. Configs are committed and
  `make lint` / `make format` exit non-zero with an install hint rather than
  failing obscurely.

**Open questions for the user.**

1. **Auto-dismiss cap** — should a reminder eventually give up on its own, or
   wait forever? Planning assumption: on by default with a generous timeout, so a
   forgotten rule can never wedge the machine during a presentation.
2. **Escalation sound** — default to sound or silence? Planning assumption:
   sound, since unmissability is the product. Note macOS will respect the system
   volume either way.
3. **Bundle identifier** — ~~placeholder, change before Phase 6~~
   **Resolved 2026-10-07: `in.kanive.piper`.** See the entry below.

**Next.** Phase 1 — data model and persistence. Awaiting go-ahead.

---

## 2026-10-07 — Bundle identifier settled

**Decision.** Bundle identifier is `in.kanive.piper`, replacing the
`dev.kanive.piper` placeholder from Phase 0.

**Changed.** `Resources/Info.plist`. Also corrected the two Phase 0 worklog
references above, which recorded the old value as fact at the time — the
`codesign -dv` result line is left as a historical record, but the open
question is now closed.

**Note.** Reverse-DNS convention is reversed here (`in.kanive.piper` rather than
the more typical `com.kanive.piper`). It only has to be unique and stable on
your machine for local ad-hoc signing, so either is fine — but if you ever ship
this outside the App Store, the identifier needs to match a domain you control.
Worth a second look in Phase 6.

**Verified.** Rebundled and confirmed `codesign -dv` reports `in.kanive.piper`.

**Next.** Phase 1 — data model and persistence. Still awaiting go-ahead, along
with open questions 1 (auto-dismiss cap) and 2 (escalation sound).
