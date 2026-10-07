# Piper

A macOS menu-bar app for **arbitrary interval reminders** that escalate to a
full-screen overlay until you deal with them.

> **Status: Phase 0 of 6 — scaffold only.** No reminders yet. The app builds,
> bundles, and shows a menu-bar icon with a placeholder menu.

## Why

Existing apps make you choose:

- **Preset wellness reminders** (eye breaks, posture, water) with one shared
  interval — [Twenty](https://github.com/AMSTAGU/Twenty),
  [Stretchly](https://github.com/hovancik/stretchly),
  [Pausa](https://github.com/yuseferi/pausa), [remindful](https://github.com/brettferdosi/remindful).
- **One arbitrary interval**, but only a notification banner —
  [Clocktower](https://github.com/tim0120/clocktower).

macOS itself offers neither: Clock alarms are one-time, Reminders repeats by
day/week/month at a fixed time, Screen Time caps app usage rather than
prompting you.

Piper does both — a list of *your* rules, each with its own schedule, any of
which can take over the screen.

## Requirements

macOS 14 or later. Built and verified on macOS 26.7.1 / arm64.

## Install

```sh
git clone <this-repo> && cd piper
make install
```

`make install` builds a release bundle and copies it to `/Applications`. The app
is ad-hoc signed, so Gatekeeper may require a right-click → Open on first
launch. See `docs/DECISIONS.md` for the Developer ID signing path.

## Development

```sh
make run      # debug bundle + launch
make build    # swift build
make bundle   # assemble build/Piper.app (release)
make check    # build + lint + format check
make help     # all targets
```

There are no tests yet — the first test target arrives with Phase 2's date
arithmetic.

**Always run the bundled app, not `swift run`.** A bare SwiftPM executable has no
`Info.plist`, which means no `LSUIElement` (you get a Dock icon) and no bundle
identifier for launch-at-login. Overlay behaviour in particular can only be
trusted from the bundle.

## Roadmap

| Phase | Scope                            | Status         |
| ----- | -------------------------------- | -------------- |
| 0     | Scaffold, AI-readiness, docs     | ✅ complete    |
| 1     | Data model + persistence         | not started    |
| 2     | Scheduler                        | not started    |
| 3     | Overlay window                   | not started    |
| 4     | UI                               | not started    |
| 5     | Login item, sound                 | not started    |
| 6     | Build, bundle, ship              | not started    |

See [`docs/PLAN.md`](docs/PLAN.md).

## Documentation

| File                                              | Purpose                                       |
| ------------------------------------------------- | --------------------------------------------- |
| [`AGENTS.md`](AGENTS.md)                          | House rules for AI agents working here         |
| [`docs/PLAN.md`](docs/PLAN.md)                   | Phases 0–6, with scope and done-when criteria  |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)     | Design rationale and the AppKit layering rules  |
| [`docs/DECISIONS.md`](docs/DECISIONS.md)          | ADRs — decisions and their costs               |
| [`docs/TODO.md`](docs/TODO.md)                    | Work in progress, by phase                     |
| [`docs/WORKLOG.md`](docs/WORKLOG.md)              | Session-by-session history                     |

## License

Undecided.
