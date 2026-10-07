# Architecture

Companion to `docs/PLAN.md` (what to build, in what order) and `AGENTS.md`
(house rules). This file covers **why the design is shaped this way**.

## The core problem

The requirement is a window that (a) appears over *everything* including other
apps' full-screen Spaces, (b) survives Space switches and Cmd-Tab, and (c) can
compel action.

Most of the design follows from (a) and (b). Everything else is ordinary app
structure, and the temptation is to write it first. Don't.

## Layers

```
┌─────────────────────────────────────────────┐
│ Views/            SwiftUI surfaces          │
│                  (dashboard, editor, card)  │
├─────────────────────────────────────────────┤
│ Overlay/          NSPanel lifecycle,        │   ← the only AppKit
│                  screen selection, modal    │     window code
├─────────────────────────────────────────────┤
│ Scheduler/        when to fire, re-arm      │   ← pure logic
│                  wake/clock notifications   │
├─────────────────────────────────────────────┤
│ Models/           Reminder, Store,          │   ← pure data
│                  QuickAddParser             │
└─────────────────────────────────────────────┘
```

Dependencies point downward only. `Models` and `Scheduler` do not import AppKit
or SwiftUI.

**Why enforce that?** The scheduler is where the bugs hide — DST edges, overnight
windows, sleep drift, timers firing twice. That logic is only testable if it can
be exercised without booting a window server. Keeping it AppKit-free means
Phase 2 can ship unit tests that run in milliseconds.

`OverlayController` reaching down to `Scheduler` is the expected direction;
the reverse is not.

## Why one reused panel

Creating an `NSPanel` per reminder is tempting and wrong:

- Panels at `.screenSaver` level are not automatically cleaned up if the display
  configuration changes underneath them.
- Menu-bar apps that create windows can trigger the auto-termination heuristic
  (blocked via `NSSupportsAutomaticTermination = false`).
- Retaining and re-styling one panel keeps escalation logic — which mutates
  content mid-display — in one place.

The root view is swapped per reminder via `NSHostingView`.

## Screen selection

Default is the display under `NSEvent.mouseLocation`. The alternative
(always the "main" screen, or always screen 1) is wrong on every multi-monitor
setup, and the user is looking at the other display.

"Nudge the active window's screen" was considered and rejected: it depends on
the frontmost app, which may itself be the thing you want to break out of.

`NSScreen.screens` can legitimately return an empty array — all displays
disconnected or asleep. Selection falls back to `.main` and then to `nil`
(no overlay, log a warning). Never force-unwrap.

## Scheduling: rules, not intervals

The store holds `{interval, anchor, weekdays, window}`, never "repeat every N
minutes". Two reasons:

1. **Expressiveness.** "Every hour, but only 09:00–18:00 on weekdays" is a
   window plus a weekday set on top of an interval. As a native repeating
   trigger it is inexpressible.
2. **Recovery.** A missed fire (sleep, quit, crash) is recomputed from `now`
   against the rule. A stored "next fire date" would need repair logic and would
   drift.

`nextFire(after:)` therefore walks forward from the anchor. The walk is capped;
an unsatisfiable rule returns `nil` (never fires) rather than looping forever on
the main thread.

## One timer, not N

A timer per reminder multiplies wakeups and drifts independently. Instead a
single `DispatchSourceTimer` is armed at the earliest next fire across all
enabled rules, then re-armed after each pop.

Simultaneous fires go into a **pending queue** and are shown one at a time.
Two rules fighting over a single overlay is a bug; the second would either be
dropped or replace the first mid-read.

## Notifications are a style, not the transport

`UNUserNotificationCenter` is used only for the `.notification` style — a
banner, no overlay. It is never used to drive the real overlay, because it
cannot present custom UI when the app isn't running, and it does not survive the
process being terminated.

The trade-off is that Piper must be **running** to take over the screen. That
is why launch-at-login (Phase 5) matters more here than in a notification-only
app.

## Escalation

Meeting Bar's real insight is that a reminder you can ignore is not a reminder.
So the overlay escalates: after `escalateAfterMinutes` it re-renders with more
urgency and loops a sound.

The safety valve is an **auto-dismiss cap**. A tool whose entire purpose is to
interrupt you will, at some point, interrupt you at 2am in a presentation. The
cap is on by default with a generous timeout; the user can disable it.

`strict` (modal, `NSApp.runModal(for:)`) is opt-in per reminder. It runs a
nested event loop — timers keep firing — but interacts awkwardly with SwiftUI
sheets, so it is deferred until the dashboard is stable.

## Persistence

Codable → JSON in `~/Library/Application Support/Piper/`.

The data model is a flat list of small structs. SwiftData would add a schema,
migrations, and a persistent container for a payload measured in kilobytes. If
the model ever grows history or queryable events, revisit — that is the signal.

The directory is injected, not hardcoded: it is not
sandbox-safe to assume, and tests need to redirect it.

## Deliberate non-goals

- **No calendar integration.** Meetings are Meeting Bar's job. Piper is about
  intervals.
- **No natural language beyond a thin parser.** The quick-add regex handles
  common forms and hands anything else to the editor. A real NL layer is a
  different product.
- **No cross-platform.** The overlay is the product, and it is a native-API
  problem.
