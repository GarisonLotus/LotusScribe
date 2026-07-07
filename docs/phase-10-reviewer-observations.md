# Reviewer Observations — LotusScribe (Phase 10)

Numbered forward-looking items. id | item | status | sub-phase first raised.

| ID | Item | Status | Raised |
|----|------|--------|--------|
| R10A-1 | `HotkeyPicker` menu row (line 90) still prints the literal `"Custom"` for `.custom` options, so the new spelled label surfaces only on function-key rows + the onboarding copy/HUD — not inside the Settings picker dropdown for a custom chord. If a future request wants the spelling visible there too, that call site needs its own change. | Open | 10A |
| R10A-2 | `keyName(for:)` does a linear `.first(where:)` scan of both maps per call. Fine for label rendering; revisit only if `spelledLabel` ever lands in a per-frame path (e.g. live HUD redraw). | Open | 10A |
