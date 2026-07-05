# Tester baselines — LotusScribe (Phase 3)

> Last gate's counts + flake registry. Archives: docs/phase-0/1/2-tester-
> baselines.md (full phase-1 empirical record in phase-1; phase-2 gate
> history in phase-2).

## Baseline carried into Phase 3

**Commit:** e6b6fe6 (Phase 2 close — human gate passed 2026-07-05).
**Counts:** 80 tests in 12 suites, 0 failures, green ×2 (phase-2
waveform-fix gate; per-suite breakdown in phase-2 baselines).
**Test command:** `make test` — run TWICE per gate; carried concurrency
surface: serialized TranscriptionServiceTests + URLProtocol global handler.
3A note: ConnectionProbeTests will join that same serialized/global-handler
surface — watch for cross-suite handler bleed at the 3A gate.

**Environment facts carried:** macOS 26 Tahoe; stable personal-team signing
(5RC66Q82V9) — TCC grants persist across rebuilds (Q1/Q2 closed); Input
Monitoring + Accessibility granted; tap mode `defaultTap` at launch under
existing grants (Q5 record); mic prompt fires at first recording start, not
launch. STT endpoint live: https://vllm.garison.com/v1/audio/transcriptions,
model whisper-large-v3, no key (D13).

## Phase 3 gates

(none yet — first gate will be 3A: expect ≈ +9 tests / +1 suite vs 80/12,
plus HUMAN-AT-SCREEN spec §3A verify 2–5.)

## Flake registry (known-noise, carried from phase 2)

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-04 | (known-noise) | linkd XPC errors (NSCocoaErrorDomain 4097) at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `[WarnOnce] layoutSubtreeIfNeeded` log at hosted-app launch | cosmetic, intermittent |
| 2026-07-04 | (known-noise) | `[logging-persist] .../DetachedSignatures - No such file or directory` during Keychain tests | Security framework noise |
| 2026-07-04 | (known-noise) | `Accessibility: Not vending elements` at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `appintentsmetadataprocessor … Metadata extraction skipped. No AppIntents.framework dependency found.` (×2) on builds that relink | link-time tool noise; xcresult warnings block stays empty |
| 2026-07-04 | (known-noise) | `xcodebuild: WARNING: Using the first of multiple matching destinations` | tool notice; benign destination auto-pick |
| 2026-07-04 | (known-noise) | `[Common] Unable to obtain a task name port right for pid NNN: (os/kern) failure (0x5)` at hosted-app launch | cosmetic, intermittent |
| 2026-07-05 | (known-noise) | `[NSCGS] Warning: Invalid attempt to open a new transaction during CA commit` + `[NSCGS] Ignoring request to entangle context after pre-commit` during PillPanelTests | cosmetic AppKit/CA panel-ordering logs |
| 2026-07-05 | (known-noise) | `[CursorUI] ViewBridge to RemoteViewService Terminated: ... NSViewBridgeErrorCanceled` at hosted-app run | cosmetic; message self-describes as benign |
