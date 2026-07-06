# Reviewer Observations — LotusScribe (Phase 9)

Numbered forward-looking items. Newest at bottom; drop resolved rows.

| ID | Sub-phase | Item | Status |
|----|-----------|------|--------|
| R9A-1 | 9A | Reviewed clean: `handleCombo` untouched (diff shows no edits; D30 pair-balance preserved), F1–F12 keycodes match HIToolbox kVK, `parse`/`resolved`/`HotkeyOption` logic + `persisted!` unwrap all correct. APPROVE. | Resolved |
| R9A-2 | 9A | Minor test nit: bare-digit rejection wasn't explicitly asserted. Fixed — added `"5"`/`"9"` to `parseRejectsGarbage` arguments. | Resolved |
| R9C-1 | 9C | Reviewed clean. Dictation wiring preserved: `HotkeyController { dictation.handle($0) }` → invoked via `MainActor.assumeIsolated { self?.onAction(action) }` in the tap closure (main run loop), identical main-thread, single-dispatch behavior to the old inline `assumeIsolated { dictation.handle(action) }`. `rebind()` stops the old monitor (EventTapMonitor.stop() disables tap + removes run-loop source) before building/starting a new one → no double-tap/leak; all on main, no race. Observer `[weak self]` + `deinit` removal is leak-safe for both app-lifetime and test-created controllers. R35 smoke + write-through tests assert construction/start and BOTH store write and notification post. APPROVE. | Resolved |
| R9C-2 | 9C | Non-blocking nit: `MainActor.assumeIsolated { self?.rebind() }` in the observer is belt-and-suspenders — `rebind()` is nonisolated and touches no MainActor state, so the wrapper isn't compiler-required (queue:.main already guarantees main-thread). Harmless; documents intent. Leave as-is. | Open |
