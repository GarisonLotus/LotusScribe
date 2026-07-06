# Reviewer observations — LotusScribe (Phase 7)

> Forward-looking items for Phase 7. Archives: phase-0 (R1–R4), phase-1
> (R5–R28), phase-2 (R29–R35), phase-3 (R36–R42), phase-4 (R43–R45),
> phase-5 (R46–R53), phase-6 (R54–R61). Numbering continues at R62.
> Only still-open rows carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R7 | 1A (carried) | ANSI-positional keycode map; AZERTY/Dvorak diverge. PLAN §7 ships no hotkey-config UI, so stays open past Phase 7 unless scope changes | open (note only) |
| R34 | 2C (carried) | Straggler-attribution micro-window; cosmetic | open (note only) |
| R35 | 2C (carried) | STANDING RULE — construction-smoke test for TCC-free composition-root types on the launch path, at introduction. LIVE: onboarding window controller is a new composition root | open (process rule, 7-live) |
| R41 | 3C (carried) | Controller tests MUST stub `warmUp:` | open (watch) |
| R44 | 4C (carried) | 3 of 4 4C tests ride R41 carve-out | open (note only) |
| R45 | 4C (carried) | Probe-trigger wording care for new settings keys — LIVE: presets write endpoint fields, which DO trigger probes (D37/D44) | open (watch, 7-live) |
| R46 | 5A (carried) | Non-ASCII STT budget check at batch | open (batch time) |
| R48 | 5B (carried) | Truncation-log recovery ↔ strict-prefix contract | open (note only) |
| R49 | 5B (carried) | Button row outside Form's disabled scope — sole-guard watch on SettingsForm edits (presets touch SettingsForm) | open (watch, 7-live) |
| R51 | 5C (carried) | Unicode fold mismatch nit | open (note only) |
| R59 | 6C (carried) | Snapshot type-order nit (batch-matrix observation item) | open (note only) |
| R60 | 6C (carried) | Batch-matrix nit (see phase-6 log) | open (note only) |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R62 | 7A | Test-success leaves a persistent green "Connected" that survives subsequent field edits (only reopen/next probe/Try Again resets it) — spec-consistent (D70 sets phase only), cosmetic; AT-SCREEN 7A item already exercises the flow | open (note only) |
| R63 | 7A | Test pressed during Save's 2 s success flash cancels autoCloseTask, so a PERSISTED save leaves the window open pending the new probe — intended R36 mirror (persist already happened, nothing lost); recording so nobody "fixes" it into a close | open (note only) |
| R64 | 7B | LoC-ceiling counting convention is de facto comment-excluded: OnboardingWindowController is 112 raw lines vs the ≤90 ceiling but 73 code-only; 7A precedent (SettingsWindowController +36 raw vs +≤30, non-objected) already set this. Architect should state the convention in the next spec so ceilings stop being ambiguous | open (note only) |
| R65 | 7B | `openOnboarding` omits the `logger.info` that `openSettings` has — cosmetic asymmetry, driven by StatusItemController's +≤14 ceiling (code-only added is exactly 14). Fine to leave; if the phase-1 debug log ever gets removed the asymmetry disappears the other way | open (note only) |
| R66 | 7B | Titlebar close (red X) sets NO flag — onboarding reappears next launch. Spec is silent (only Skip/Finish set `onboardingCompleted`); "close ≠ skip → show again" is defensible, but AT-SCREEN 7B should confirm it feels intended rather than nagging | open (AT-SCREEN judges) |
| R67 | 7B | AppDelegate and StatusItemController each cache their OWN OnboardingWindowController — launch-shown window still open + "Rerun Onboarding…" = two independent onboarding windows, both polling. Spec-conformant shape ("self-contained, mirrors SettingsWindowController") and both close/complete safely, but a one-window guarantee would need a shared instance | CLOSED at 7C gate — 5335d98 makes StatusItemController the sole owner; ordering verified (statusItemController constructed before the XCTest guard), @objc menu path intact, 218/22 green |
| R68 | 7C | `make notarize` submits `dist/LotusScribe-*.dmg` via glob and there is no dist-clean recipe — once a second version's DMG accumulates in dist/, the glob expands to multiple args and `notarytool submit` (single-path command) fails or picks ambiguously. Harmless at v1.0 (one DMG); becomes real at the first version bump | open (note only) |
| R69 | 7C | make-dmg.sh re-signs with `codesign --deep`, which Apple discourages; harmless today (flat bundle, no nested code), but if Sparkle is adopted (Q7-1) its embedded XPC services/frameworks must NOT be --deep-signed — revisit the flag at Sparkle adoption | open (note only, Q7-1-linked) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
