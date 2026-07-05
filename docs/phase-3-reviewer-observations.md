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

> 3C gate reviewed 2026-07-05: EXECUTION APPROVED. D44 verified: `save()`
> probes each endpoint whose DRAFTED URL is non-empty, sequentially STT
> then LLM, stopping at the first failure; sheet reason prefixed with the
> failing endpoint name ("Speech to Text: …" / "Cleanup LLM: …",
> test-asserted both ways); both-empty → save+close with no probe
> (Issue.record tripwire on both stubs). `testLLM` body key-set asserted
> exactly {model, messages, max_tokens} (no keep_alive), user("ping"),
> max_tokens 1, `timeoutInterval == 10`; success = 200 + decodable
> `choices[0].message`; invalid URL fails without touching the session
> (tripwire-stubbed). `send(_:)` extraction (second caller — R21-correct
> timing) is behavior-neutral for testSTT: identical timeout/transport/
> non-HTTP/non-200 mapping, decode stays endpoint-specific; all 3A probe
> tests unchanged and green. D26/D40: picker binds through the draft;
> level written ONLY in `draft.save()`; `reload()` reseeds via
> `CleanupLevel.resolve` (round-trip test). R36 FOLDED: `save()` entry
> cancels stale probeTask AND autoCloseTask; regression test holds the
> stale task handle and asserts `.isCancelled` + window survival;
> MainActor serialization keeps either interleaving safe (3A analysis
> holds). R37 FOLDED: SettingsForm.swift extraction is mechanical (diff =
> move + spec'd picker row + height comment; `.onExitCommand` Esc path
> preserved); controller now 196 code lines (< ~200). R38 FOLDED: skip
> log distinguishes unparseable URL from not-enabled; retry log maps nil
> → "transport failure", no `Optional()`. R39 FOLDED: empty→nil applied
> at read time uniformly across ALL SIX string keys (four D9 +
> sttLanguage + cleanupLevel — engineer flag said five, undercount only),
> regression test writes raw "" and reads nil. D42 warm-up: `persist()`
> verified as the SOLE store-write path (probe-success, Save Anyway, and
> the both-empty shortcut all route through it; `draft.save()` has no
> other production caller); warm-up fires iff (llmEndpointURL, llmModel)
> store-read tuple changed across the save AND effective-enabled after
> the write — injected-counter tests assert fired-once on change and
> zero on no-change; both-empty path can never fire it (nil URL →
> isEnabled false). Engineer flags all verified: probeFailure test
> expectation change is D44-prefix-only (no other drift); window height
> 350→390 in sync at both sites (now cross-file — R40); `autoCloseTask`
> `private(set)` widening matches the probeTask precedent, read-only.
> Cancellation preserved: windowWillClose cancels both tasks; the probe
> leg's post-await `Task.isCancelled` guard means a late completion
> writes nothing. Pre-existing behavior change is exactly the D44 prefix
> — intentional-only confirmed. Independent `make test`: 120 tests / 15
> suites green (expected 120/15). New rows R40–R41 (both non-blocking).
> Remaining verification is HUMAN-AT-SCREEN (spec §3C verify 2–5, user
> supplies LLM endpoint/model).

> Maintenance sweep reviewed 2026-07-05 (post-3C): APPROVED. Four items,
> staged diff = exactly the 7 expected files, nothing beyond scope. R3:
> smoke test now asserts `NSApp.delegate as? AppDelegate` composed
> `dictationController` post-launch (real behavior — fails if the cast or
> composition fails; the old always-true `is` check is gone);
> `private(set)` widening is read-only (getter internal, setter private).
> R30: doc-only — `rms` doc now says "~1, consumers clamp, see
> display(rms:)" (leg a) and `onLevel` doc drops "not called after
> stop()" for the late-dispatch/consumers-guard wording (leg b); zero
> code change in either file. R32: comment-only at the 24 pt inset
> naming the PillMetrics.bottomMargin coincidence. R40:
> `SettingsForm.contentSize` (420×390) defined once, consumed at both
> the root `.frame` and the controller's `setContentSize`; grep confirms
> no third code literal (remaining 390/420 hits are the constant itself
> and two comments, incl. the test-threshold comment). Independent
> `make test`: 120 tests / 15 suites green (expected 120/15).

> D45 fix reviewed 2026-07-05 (post-sweep): APPROVED. Staged Sources/Tests
> diff = exactly 4 files (CleanupLevel, CleanupService, CleanupLevelTests,
> CleanupServiceTests), nothing beyond scope. Both cleanup prompts now
> begin with the literal `/no_think ` prefix (token + exactly one trailing
> space, verified in "/no_think You…"), byte-for-byte against the spec §3B
> fixtures; the test fixtures guard both prompts including the prefix.
> Timeout change is hot-path only: `cleanup()` makeRequest 4→8 s (comment
> updated D39→D45); grep confirms warm-up 30 s, probe 10 s (D36/D44), and
> STT 20 s all untouched. No `chat_template_kwargs` or other body drift —
> request stays strictly OpenAI-standard per D42/D45. Doc comments on the
> two timeout-referencing tests (`cleanupRequestMatchesSpec`,
> `timedOutMapsToTransport`) updated consistently. Independent
> `make test`: 120 tests / 15 suites green (expected 120/15).

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R3 | 0B (carried) | 0A smoke test is still link-smoke (`appDelegateInitializes`, with the pre-existing "'is' test is always true" warning); repoint at real behavior when convenient. CLOSED in maintenance sweep (post-3C): test asserts the launched delegate's `dictationController != nil` via read-only `private(set)` | closed (sweep) |
| R4 | 0B (carried) | Legacy-keychain ACLs vs re-signing may break later-phase API-key reads. Precondition resolved (R27: stable team signing); close by exercising a Keychain read under the 5RC66Q82V9 identity. 3A's probe hits the no-key D13 endpoint — does not exercise this | open |
| R7 | 1A (carried) | Combo keycode map is ANSI-positional (kVK_ANSI_*): "z" means the physical ANSI-Z key, not the layout character (AZERTY/Dvorak diverge). Revisit when hotkey-config UI lands (Phase 7+) | open (future phase) |
| R30 | 2A (carried) | AudioLevel/AudioRecorder nits: (a) `AudioLevel.rms` unclamped vs its 0…1 doc (Int16.min-heavy buffer ≈ 1.00003); downstream protection lives in `AudioLevel.display(rms:)`'s min/max since the D35 fix; (b) `onLevel` doc line "not called after stop()" contradicted by consumer's own late-dispatch guard — doc wording fix owed. Cosmetic; fold into any AudioLevel follow-up. CLOSED in maintenance sweep (post-3C): doc-only fixes at both legs (rms "~1, consumers clamp"; onLevel late-dispatch wording); phase-2 archive row left as-is | closed (sweep) |
| R31 | 2A (carried) | Pre-existing (phase 1, unchanged in kind): `handleTapEvent` re-enables on `.tapDisabledByTimeout` but not `.tapDisabledByUserInput`; under `.defaultTap` a dead tap still just means dead hotkey. Note only, per surgical-change rule | open (future phase) |
| R32 | 2B (carried) | PillView bar-geometry literals (4 pt floor, 24 pt interior inset) view-local, single-site; interior-inset 24 numerically coincides with `PillMetrics.bottomMargin` — name or comment it if it ever wants a second site (R21 trigger). dB window bounds (-50, 20, 50) in AudioLevel.display: same posture, documented in doc comment. CLOSED in maintenance sweep (post-3C): comment at the 24 pt inset names the coincidence; comment-only; phase-2 archive row left as-is | closed (sweep) |
| R34 | 2C (carried) | Straggler-attribution micro-window: a queued level block from a just-stopped capture could flip a NEW capture's `.warming` → `.recording` one frame early iff a human-timescale hotkey press beats a millisecond-old main-queue block — not realistic; cosmetic even if hit. Note only | open (non-blocking) |
| R35 | 2C (carried) | GATE-TRIP LESSON — construction-smoke coverage for composition roots: any TCC-free composition-root type constructed on the launch path gets a construction test at introduction, not after a regression (D34 launch abort passed a full gate with zero construction coverage; AppKit swallows init-time NSExceptions silently). AppDelegate itself remains link-smoked only (R3) | open (process lesson) |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R36 | 3A | `save()` doesn't cancel a prior probeTask/autoCloseTask: during the 2 s success flash the buttons re-enable (disabled only on `.testing`), so a second Save spawns a fresh probe while the first flash's auto-close still fires at T+2 s — window closes mid-second-probe. FOLDED in 3C: `save()` entry cancels both stale tasks; regression test `reentrantSaveCancelsStaleAutoClose` asserts cancellation + window survival | closed (3C) |
| R37 | 3A | SettingsWindowController.swift was 214 code lines vs the ~200 target. FOLDED in 3C: SettingsForm extracted to SettingsForm.swift (mechanical move + picker row); controller now 196 code lines | closed (3C) |
| R38 | 3B | Warm-up log cosmetics: (a) skip log blamed "not effective-enabled" for an unparseable URL; (b) retry log printed `Optional(200)`. FOLDED in 3C: dedicated unparseable-URL skip log; retry outcome maps nil → "transport failure" | closed (3C) |
| R39 | 3B | Empty-string keys written via raw `defaults write` (bypassing draft.save's D25 empty→nil) made `isEnabled` true with unusable config. FOLDED in 3C: SettingsStore applies empty→nil at read time across all six string keys; regression test `emptyStringValuesReadAsNil` | closed (3C) |
| R40 | 3C | Settings window size literals (420×390) now live at two sites in two FILES: `SettingsForm.body`'s `.frame` and the controller's `setContentSize` (macOS 26 fitting-size collapse forces both). Cross-referenced by comments and currently in sync, but the R23/R21 second-site trigger is met — name a shared constant next time either file is touched. CLOSED in maintenance sweep (post-3C): `SettingsForm.contentSize` consumed at both sites; no third literal | closed (sweep) |
| R41 | 3C | Latent test-hygiene hazard: the controller's default warm-up closure runs a REAL `CleanupService.warmUp()` network Task; the XCTestSessionIdentifier guard covers only the AppDelegate launch trigger, not this seam. Every current test either stubs `warmUp:` or never persists a changed LLM config — but a future controller test that saves a changed llmEndpointURL/llmModel without stubbing fires a real request from the test process. Note for tester baselines | open (non-blocking) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
