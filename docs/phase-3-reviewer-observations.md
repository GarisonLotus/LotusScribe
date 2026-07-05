# Reviewer observations — LotusScribe (Phase 3)

> Forward-looking items for Phase 3. Archives: phase-0 (R1–R4), phase-1
> (R5–R28), phase-2 (R29–R35). Numbering continues at R36. Only still-open
> rows carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R3 | 0B (carried) | 0A smoke test is still link-smoke (`appDelegateInitializes`, with the pre-existing "'is' test is always true" warning); repoint at real behavior when convenient | open |
| R4 | 0B (carried) | Legacy-keychain ACLs vs re-signing may break later-phase API-key reads. Precondition resolved (R27: stable team signing); close by exercising a Keychain read under the 5RC66Q82V9 identity. 3A's probe hits the no-key D13 endpoint — does not exercise this | open |
| R7 | 1A (carried) | Combo keycode map is ANSI-positional (kVK_ANSI_*): "z" means the physical ANSI-Z key, not the layout character (AZERTY/Dvorak diverge). Revisit when hotkey-config UI lands (Phase 7+) | open (future phase) |
| R30 | 2A (carried) | AudioLevel/AudioRecorder nits: (a) `AudioLevel.rms` unclamped vs its 0…1 doc (Int16.min-heavy buffer ≈ 1.00003); downstream protection lives in `AudioLevel.display(rms:)`'s min/max since the D35 fix; (b) `onLevel` doc line "not called after stop()" contradicted by consumer's own late-dispatch guard — doc wording fix owed. Cosmetic; fold into any AudioLevel follow-up | open (non-blocking) |
| R31 | 2A (carried) | Pre-existing (phase 1, unchanged in kind): `handleTapEvent` re-enables on `.tapDisabledByTimeout` but not `.tapDisabledByUserInput`; under `.defaultTap` a dead tap still just means dead hotkey. Note only, per surgical-change rule | open (future phase) |
| R32 | 2B (carried) | PillView bar-geometry literals (4 pt floor, 24 pt interior inset) view-local, single-site; interior-inset 24 numerically coincides with `PillMetrics.bottomMargin` — name or comment it if it ever wants a second site (R21 trigger). dB window bounds (-50, 20, 50) in AudioLevel.display: same posture, documented in doc comment | open (non-blocking) |
| R34 | 2C (carried) | Straggler-attribution micro-window: a queued level block from a just-stopped capture could flip a NEW capture's `.warming` → `.recording` one frame early iff a human-timescale hotkey press beats a millisecond-old main-queue block — not realistic; cosmetic even if hit. Note only | open (non-blocking) |
| R35 | 2C (carried) | GATE-TRIP LESSON — construction-smoke coverage for composition roots: any TCC-free composition-root type constructed on the launch path gets a construction test at introduction, not after a regression (D34 launch abort passed a full gate with zero construction coverage; AppKit swallows init-time NSExceptions silently). AppDelegate itself remains link-smoked only (R3) | open (process lesson) |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
|    | (none yet)   |      |        |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
