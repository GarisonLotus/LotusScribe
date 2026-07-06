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

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
