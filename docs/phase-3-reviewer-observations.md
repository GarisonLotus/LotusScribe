# Reviewer observations — LotusScribe (Phase 3)

> Forward-looking items for Phase 3. Archives: phase-0 (R1–R4), phase-1
> (R5–R28), phase-2 (R29–R35). Numbering continues at R36. Only still-open
> rows carried.

> 3A gate reviewed 2026-07-05: EXECUTION APPROVED. D36 verified: probe
> reads only its arguments (endpoint/model captured from DRAFTS in
> `save()`; ConnectionProbe has no SettingsStore access); silent WAV is
> exactly 0.2 s (6400 zero bytes = 3200 Int16 @ 16 kHz mono); success =
> 200 + decodable `{"text":}`; `timeoutInterval == 10` asserted in the
> request-shape test; empty drafted URL short-circuits to save+close
> (probe never invoked, test-guarded); un-parseable URL fails before the
> session. D37 verified: `draft.save()` precedes autoCloseTask creation
> (crash mid-flash cannot lose the save); Close Anyway = save-then-close;
> sheet-Cancel resets phase to idle, drafts intact; mid-test close is
> race-free — NSWindowController is MainActor, so windowWillClose's
> cancel and the post-await `Task.isCancelled` guard serialize: a probe
> completion landing after close always sees the cancel and writes
> nothing (real probe also cancels cooperatively via URLSession).
> Retain audit clean: probeTask/autoCloseTask/sheet handler all
> `[weak self]`, window.delegate weak, autoCloseTask cancelled in
> windowWillClose if the user closes first. D38: staged diff touches
> only ConnectionProbe/SettingsWindowController + their tests — zero
> dictation-path changes; failure sheet is settings-window-only.
> Request shape matches TranscriptionService (model field + file part,
> byte-equal multipart assertion). Independent `make test`: 89 tests /
> 13 suites green (expected 89/13). LoC: ConnectionProbe 45 code lines
> (under ~55); controller delta +95 vs ~85 and ConnectionProbeTests 112
> vs ~60 — overage is the dedicated ProbeStubURLProtocol (cross-suite
> race is load-bearing; R13 precedent: stub infra under-scoped in the
> estimate) plus spec-listed request-shape/timeout tests, not logic
> creep — accepted per R6. New rows R36–R37. Remaining verification is
> HUMAN-AT-SCREEN (spec §3A verify 2–5).

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
| R36 | 3A | `save()` doesn't cancel a prior probeTask/autoCloseTask: during the 2 s success flash the buttons re-enable (disabled only on `.testing`), so a second Save spawns a fresh probe while the first flash's auto-close still fires at T+2 s — window closes mid-second-probe, probe cancelled, nothing extra written (first save already persisted). Outcome correct by accident; have `save()` cancel stale tasks if this surface is touched in 3B | open (non-blocking) |
| R37 | 3A | SettingsWindowController.swift is now 214 code lines vs the ~200 target (code-norms): file hosts validation + draft + probe state + controller + form. Natural split point is 3B's per-endpoint probe generalization (e.g. SettingsForm or ProbePhase/ProbeState to their own file) | open (fold into 3B) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
