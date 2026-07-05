# Reviewer observations — LotusScribe (Phase 2)

> 2A gate reviewed 2026-07-04: PASS WITH OBSERVATIONS (R29 routed to
> architect; R30/R31 non-blocking). Independent `make test`: 66/10 green.
> LoC overages accepted per R6 precedent — overage is doc comments /
> why-comments; code-norms budget counts code lines only.

> Forward-looking items for Phase 2. Archives: phase-0 (R1–R4), phase-1
> (R5–R28). Numbering continues at R29. Only still-open rows carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R3 | 0B (carried) | 0A smoke test is still link-smoke (`appDelegateInitializes`, with the pre-existing "'is' test is always true" warning); repoint at real behavior when convenient | open |
| R4 | 0B (carried) | Legacy-keychain ACLs vs re-signing may break later-phase API-key reads. Precondition resolved (R27: stable team signing); close by exercising a Keychain read under the 5RC66Q82V9 identity | open |
| R7 | 1A (carried) | Combo keycode map is ANSI-positional (kVK_ANSI_*): "z" means the physical ANSI-Z key, not the layout character (AZERTY/Dvorak diverge). Revisit when hotkey-config UI lands (Phase 7+) | open (future phase) |
| R23 | 1E (carried) | macOS 26: SwiftUI-hosted AppKit windows need explicit sizing; assert `contentLayoutRect`, not window frame | absorbed into phase-2 spec (§2B, D31); close at 2B review once the test lands |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R29 | 2A | Pair-balance hole, modifiers-after-key order: hold chord key bare (down passes through to the app), then add the chord modifiers while it autorepeats — the repeat down matches `!isCapturing` + superset, starts capture and sets `chordKeyDownSwallowed`, so the eventual keyUp is swallowed. App saw a down, never the up (stuck-repeat risk). Machine can't tell initial vs autorepeat downs (`HotkeyEvent` lacks kCGKeyboardEventAutorepeat). Fix options: track a chord-key-down-passed-through flag via the non-matching keyDown branch and refuse start/swallow until a clean keyUp, or carry the autorepeat field. Unusual entry order, not exercised by 2A human verify; needs architect disposition (fix in 2A vs narrow the invariant wording) | open — routed to architect |
| R30 | 2A | AudioLevel/AudioRecorder nits: (a) rms not clamped — an Int16.min-heavy buffer yields ≈1.00003 > the documented 0…1 (suggest `min(1, …)` or amend doc); (b) `onLevel` doc says "not called after stop()" — a block dispatched just before stop() can still land on main after it returns; wording only. Cosmetic; safe to fold into any 2A follow-up | open (non-blocking) |
| R31 | 2A | Pre-existing (phase 1, unchanged in kind): `handleTapEvent` re-enables on `.tapDisabledByTimeout` but not `.tapDisabledByUserInput`; under `.defaultTap` a dead tap still just means dead hotkey, same failure mode as before. Note only, per surgical-change rule | open (future phase) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
