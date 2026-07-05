# Reviewer observations — LotusScribe (Phase 2)

> D34 fix reviewed 2026-07-05: EXECUTION APPROVED. Staged diff is exactly
> the D34 shape: AudioRecorder init + D29a comment deleted (no relocation
> into start(); zero `prepare` references remain anywhere in Sources),
> nothing else touched in the file; construction verified TCC-free
> (AVAudioEngine alloc only — inputNode/HAL first touched in start(),
> D14 holds; SettingsStore init is UserDefaults-only). Regression test
> `constructionDoesNotRaise` constructs DictationController on MainActor
> in the existing hosted suite; the crash-on-NSException is the real
> guard (acceptable per D34 design) and would genuinely re-expose the
> launch abort. Doc amendments (D29 rescission note, D34 row, Q6 closed,
> spec §2C deliverables) match the ruling with no drift. Independent
> `make test`: 75 tests / 12 suites green. New lesson row R35.

> 2C gate reviewed 2026-07-05: EXECUTION APPROVED. All spec §2C
> transitions present and none extra; D23 generation guards verified on
> both success and error paths (insert-path semantics untouched); the
> late-level race is closed by set-ordering (isRecording=false before
> recorder.stop(), all on the serial main queue) — residual
> straggler-attribution window noted as R34 (not realistic); D33 holds
> (show/update/push/hide only); D29a prepare() touches no TCC surface;
> failure policy = log + flash, D24 untouched. Independent `make test`:
> 74 tests / 12 suites green. R30 picture unchanged in substance —
> status annotated. Remaining verification is the HUMAN-AT-SCREEN
> phase gate (spec §2C verify 1–6).

> 2B gate reviewed 2026-07-05: EXECUTION APPROVED (approved-with-notes).
> R29 fix verified correct (chordKeyDownPassedThrough, pair balance holds
> across the modifiers-after-key entry order; regression test present).
> R23 test landed (contentLayoutRect) — closed below. Independent
> `make test`: 74 tests / 12 suites green. D31 single-site holds. New
> non-blocking notes R32/R33; R33 carries a minor shape question for
> architect (PillController surface beyond the spec'd four methods).

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
| R23 | 1E (carried) | macOS 26: SwiftUI-hosted AppKit windows need explicit sizing; assert `contentLayoutRect`, not window frame | closed 2B (2026-07-05): PillPanelTests.contentLayoutRectMeetsPillMetrics asserts contentLayoutRect ≥ 260×52; explicit setContentSize in PillPanel init + re-assert in PillController after contentView lands |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R29 | 2A | Pair-balance hole, modifiers-after-key order: hold chord key bare (down passes through to the app), then add the chord modifiers while it autorepeats — the repeat down matches `!isCapturing` + superset, starts capture and sets `chordKeyDownSwallowed`, so the eventual keyUp is swallowed. App saw a down, never the up (stuck-repeat risk). Machine can't tell initial vs autorepeat downs (`HotkeyEvent` lacks kCGKeyboardEventAutorepeat). Fix options: track a chord-key-down-passed-through flag via the non-matching keyDown branch and refuse start/swallow until a clean keyUp, or carry the autorepeat field. Unusual entry order, not exercised by 2A human verify; architect mandated the flag fix under the ratified pair-balance invariant | closed 2B (2026-07-05): `chordKeyDownPassedThrough` landed, reviewer-verified with regression test; architect confirmed vs mandate |
| R30 | 2A | AudioLevel/AudioRecorder nits: (a) rms not clamped — an Int16.min-heavy buffer yields ≈1.00003 > the documented 0…1 (suggest `min(1, …)` or amend doc); (b) `onLevel` doc says "not called after stop()" — a block dispatched just before stop() can still land on main after it returns; wording only. Cosmetic; safe to fold into any 2A follow-up | open (non-blocking) — 2C note (2026-07-05): (a) unclamped rms now feeds the pill, but PillView.barHeight clamps to 0…1 downstream, so no visual defect; (b) the doc line "not called after stop()" is now demonstrably contradicted by DictationController.handleLevel's own guard comment ("Late main-queue dispatch can land after stop()") — consumer defends correctly; doc wording fix still owed |
| R31 | 2A | Pre-existing (phase 1, unchanged in kind): `handleTapEvent` re-enables on `.tapDisabledByTimeout` but not `.tapDisabledByUserInput`; under `.defaultTap` a dead tap still just means dead hotkey, same failure mode as before. Note only, per surgical-change rule | open (future phase) |
| R32 | 2B | PillView bar-geometry literals (bar width 3, spacing 3, 4 pt height floor, 24 pt interior inset in `barHeight`) are view-local, single-site each — D31 constants themselves have no second site, so no violation. But the interior-inset `24` numerically coincides with `PillMetrics.bottomMargin`; name it or comment it if it ever wants a second site (R21 trigger) | open (non-blocking) |
| R33 | 2B | PillController exposes read-only `state` accessor + internal `panel` beyond the spec'd surface (show/update/push/hide) — test observability per R24 precedent, no state ownership change, execution-OK. Shape question for architect: should the 2C-facing API be strictly the four methods, or is read-only observability part of the surface? | closed 2B (2026-07-05): architect ruled D33 — read-only observability ratified as part of the surface; spec §2B round-tripped |
| R34 | 2C | Straggler-attribution micro-window: a level block dispatched from the audio thread while `recorder.stop()` runs lands on main after `stopRecording()` returns; the practical race (flipping .processing back to .recording) is closed — `isRecording = false` precedes `recorder.stop()` and everything serializes on the main queue, so the straggler hits `guard isRecording` and drops. The only residual path is if a NEW `startCapture` executed before the already-queued straggler drained (stale level would prematurely flip the new capture's .warming → .recording, bending D29 warming-truth by one frame). Requires a human-timescale hotkey event to beat a millisecond-old queued main block — not realistic; cosmetic even if hit. Note only | open (non-blocking) |
| R35 | 2C (D34 fix) | GATE-TRIP LESSON — construction-smoke coverage for composition roots: the D29a launch abort passed a full 4-way gate because no test ever constructed DictationController (same class as R3's link-smoke gap). AppKit swallows init-time NSExceptions inside applicationDidFinishLaunching silently, so a hosted construction-smoke test is the only automated tripwire for this failure mode. Going forward: any TCC-free composition-root type constructed on the launch path gets a construction test at introduction, not after a regression. AppDelegate itself remains link-smoked only (R3 still open) | open (process lesson) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
