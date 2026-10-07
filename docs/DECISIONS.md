# Architecture Decision Records

Append-only. Newest last. Do not edit the substance of an accepted ADR — supersede
it instead, so the history stays honest.

Format:

```
### ADR-000N: Title
**Status:** accepted | superseded by ADR-000M
**Date:** YYYY-MM-DD
**Context:** the forces
**Decision:** what we chose
**Consequences:** what this costs us
```

---

### ADR-0001: SwiftPM package instead of an Xcode project

**Status:** accepted
**Date:** 2026-10-07

**Context:** The app is a single executable target with no dependencies, no test
target yet, and no need for storyboards or asset compilation beyond what a
bundle script can do. Both SwiftPM and Xcode can build it.

**Decision:** SwiftPM (`Package.swift`), no `.xcodeproj` committed. `Scripts/bundle.sh`
assembles `Piper.app` and ad-hoc signs it.

**Consequences:** `swift build` works from a clean checkout with no Xcode
project file to drift, and CI is a one-liner. In exchange we hand-assemble the
bundle, so `Info.plist` correctness is our problem — which is why
`NSSupportsAutomaticTermination` and `LSUIElement` are asserted in the Phase 0
verification. Opening the folder in Xcode still works for GUI debugging, since
Xcode understands `Package.swift`.

---

### ADR-0002: Swift 5 language mode under a `swift-tools-version: 6.0` manifest

**Status:** accepted
**Date:** 2026-10-07

**Context:** The toolchain is Swift 6.3, and the idiomatic modern choice is Swift 6
language mode with full strict-concurrency checking. But Phase 2/3 mix
`DispatchSourceTimer` callbacks, `NSWorkspace` notification handlers, and
`NSApp.runModal(for:)` nested event loops — the exact territory where strict
concurrency generates long fights with frameworks that predate `Sendable`.
Making the concurrency story a Phase 2/3 concern rather than a Phase 0 one keeps
the phase reviewable.

**Decision:** `swift-tools-version: 6.0` (for the modern manifest) with
`.swiftLanguageMode(.v5)` on the target.

**Consequences:** No strict-concurrency errors today, and the build stays quiet
while the AppKit plumbing lands. The cost is that strict concurrency is
*deferred, not solved* — the migration will be real work. Revisit once Phase 3
is stable: grep for the `DispatchQueue.main.async` hops the AppKit APIs force, and
decide whether `@MainActor` annotations on `Scheduler` and `OverlayController`
close the gap cleanly.

---

### ADR-0003: Codable + JSON instead of SwiftData

**Status:** accepted
**Date:** 2026-10-07

**Context:** `Reminder` is a flat struct; the store is a list of them plus a
small `Settings` value. Everything in `Application Support` is a few kilobytes.

**Decision:** Codable → `~/Library/Application Support/Piper/reminders.json`,
written atomically and debounced. No `ModelContainer`.

**Consequences:** No schema, no migrations, trivially diffable and hand-editable,
and a test can point the store at a temp directory. The trade-off is real: when
the model grows queryable history (acknowledgement logs, streak stats), hand-rolled
JSON gets painful. That growth is the signal to revisit, not a vague feeling that
"SwiftData would be more modern."

---

### ADR-0004: Never drive the overlay via `UNUserNotificationCenter`

**Status:** accepted
**Date:** 2026-10-07

**Context:** It is the obvious API for scheduling recurring local notifications,
and it survives the app being terminated. It also cannot present custom UI when
the app isn't running, cannot be tuned per-fire, and gives no control over window
level or Space behaviour.

**Decision:** The overlay is driven by an in-process `DispatchSourceTimer`.
`UNUserNotificationCenter` is used **only** for the `.notification` style, where a
banner is exactly what's wanted.

**Consequences:** Piper must be running to take over the screen, so launch-at-login
moves from a nice-to-have (Phase 5) to effectively required. The upside is total
control over presentation, escalation, and acknowledgement.

---

### ADR-0005: Non-modal by default; `strict` is per-reminder opt-in

**Status:** accepted
**Date:** 2026-10-07

**Context:** The user has to choose between an overlay you can click away from and
one that genuinely cannot be dismissed (`NSApp.runModal(for:)`). A modal that is
wrong at the wrong moment is an app the user force-quits.

**Decision:** Default to a non-modal overlay. `strict` is a per-reminder flag for
the cases where compulsion is the point.

**Consequences:** Respects the user by default, and the aggressive case is still
available where it's justified. The cost is that "did the user actually see it"
is genuinely ambiguous — which is what `escalateAfterMinutes` and the
auto-dismiss cap exist to bound. `strict` also runs a nested event loop that
interacts awkwardly with SwiftUI sheets, so it is sequenced last in Phase 3.

---

### ADR-0006: `.card` is the default style, `.fullscreen` is opt-in

**Status:** accepted
**Date:** 2026-10-07

**Context:** The original ask was a "full screen reminder." Taken literally as the
default, every reminder hides the user's entire desktop — including the document
they are trying to act on.

**Decision:** Default to `.card` (dimmed, blurred backdrop, centred card).
`.fullscreen` — opaque, edge-to-edge — stays available per reminder for
genuine hard-focus blocks.

**Consequences:** The common case is far less hostile while the dramatic version
is still one tap away. Worth revisiting if testing shows users find the card too
easy to ignore; escalation is the intended pressure valve, not opacity.
