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

> 3B gate reviewed 2026-07-05: EXECUTION APPROVED. D43 verified: cleanup
> call sits in an inner do/catch whose catch only logs — control falls
> through to the raw insert; the outer catch (only reachable from
> `transcription.transcribe`) is the sole `.error` route, so `.error` is
> structurally unreachable from the cleanup leg; no path discards the
> transcript (failure → raw, empty output → throws → raw). D23 across the
> hop: pre-cleanup generation guard unchanged; second guard sits after the
> cleanup await (and after the catch, so it runs on failure too) — stale →
> return before insert/pill. D39: temperature 0 + 4 s timeoutInterval
> asserted; trimmed-empty throws `.emptyOutput`; hot-path body key-set
> asserted exactly {model, messages, temperature}. D40: `isEnabled` is a
> computed var over SettingsStore (live defaults reads at call time — no
> snapshot staleness); nil/garbage level → .standard, fixture-tested; both
> prompts byte-equal to spec. D42: warm-up 30 s timeout, keep_alive -1,
> max_tokens 1 asserted as exact key-set; non-2xx → exactly one retry with
> keep_alive dropped (retry key-set asserted); transport failure (nil
> status) → no retry — UPHELD as the spec's plain reading ("non-2xx →
> retry ONCE"; the rationale, unknown-field 400s, only exists on HTTP
> responses); log-only throughout; launch site inside the
> XCTestSessionIdentifier guard. Key-set tripwires cover both leak
> directions (an always-retry regression would also trip the warm-up
> key-set, since the retry body lacks keep_alive). Stub isolation:
> dedicated CleanupStubURLProtocol, `.serialized`, UUID-suffixed
> UserDefaults suite removed in deinit — no bleed. TranscriptionService,
> pill states, alert policy untouched (staged diff = exactly the 7 listed
> files). Independent `make test`: 106 tests / 15 suites green (expected
> 106/15). LoC: CleanupService 120 vs ~90 and CleanupServiceTests 194 vs
> ~120 — overage is the error enum + Codable scaffolding + retry leg and
> the dedicated stub + exact-body assertions, not logic creep; accepted
> per R6/3A precedent (R13: stub infra chronically under-scoped). No-DI
> seam in DictationController accepted: matches the existing
> transcription wiring and the D14 split (live loop HUMAN-AT-SCREEN);
> code-norms disfavor test-only seams. New rows R38–R39. Remaining
> verification is HUMAN-AT-SCREEN (spec §3B verify 2–5, user supplies LLM
> endpoint/model).

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
| R38 | 3B | Warm-up log cosmetics: (a) the skip log says "not effective-enabled" even when the actual cause is an unparseable `llmEndpointURL` (isEnabled true, `URL(string:)` nil — same guard); (b) retry-outcome log prints `Optional(200)` via `String(describing:)`. Log-only path, behavior correct; fold into 3C when the endpoint-change warm-up trigger touches this surface | open (non-blocking) |
| R39 | 3B | Empty-string LLM keys written via raw `defaults write` (bypassing draft.save's D25 empty→nil) make `isEnabled` true with unusable config; every downstream path degrades safely (cleanup → `.notConfigured` → D43 raw fallback; warmUp → URL-parse guard → skip log). Note only — 3C's picker/save path is the sole intended writer | open (non-blocking) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
