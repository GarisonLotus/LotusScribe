# Tester baselines — LotusScribe (Phase 4)

> Last gate's counts + flake registry. Archives: docs/phase-0/1/2/3-tester-
> baselines.md (phase-3 holds the 3A–3D per-suite breakdowns and the full
> flake registry table).

## Baseline carried into Phase 4

**Commit:** 75822bc (post-3D debt sweep; Phase 3 close gate still OPEN —
see blocked queue below).
**Counts:** 126 tests in 16 suites, 0 failures, green ×2.
**Test command:** `make test` — run TWICE per gate.

**Carried concurrency surface:** serialized suites with dedicated
URLProtocol stubs — TranscriptionServiceTests, ConnectionProbeTests,
CleanupServiceTests; UUID-suffixed UserDefaults suites (CleanupServiceTests
pattern) — no bleed observed through 3D; remains a watch item. 4A note:
AppCategoryTests + CleanupLevelTests deltas are pure (no URLProtocol, no
defaults) — only the CleanupServiceTests delta rides the existing stub
surface. 4C note (R41): any new SettingsWindowControllerTests MUST stub
`warmUp:` — the default closure is real network.

**Environment facts carried:** macOS 26 Tahoe; stable personal-team
signing (5RC66Q82V9); Input Monitoring + Accessibility granted; tap mode
`defaultTap` at launch; mic prompt at first recording start.
**Endpoint status: vLLM host UNREACHABLE (2026-07-05)** — no live STT;
all dictation-dependent human verifies are BLOCKED-BATCH.

## Blocked HUMAN-AT-SCREEN queue (one batch when STT returns)

Phase-3 items (phase-3-team-handoff §3): 3B/D45 cleaned-text re-verify;
3D verify 2–4; 3C verify 2–5; D49 dead-tap (non-gating); then the Phase-3
close gate. Phase-4 additions as sub-phases land: 4B verify 3–4 (tone
effect Messages vs Mail; unmapped-app neutrality), 4C verify 3–4
(override effect live; D38 regression cleaned-text leg). NOT blocked
(at-screen only, no STT needed): 4B verify 2 (capture log), 4C verify 2
(UI fit/persist).

## Phase 4 gates

| gate | date | staged base | counts | runs | result |
|------|------|-------------|--------|------|--------|
| 4A | 2026-07-05 | a4d65b0 (staged, not committed) | 145 tests / 17 suites | ×2 | GREEN ×2, 0 failures, 0 flakes |

**4A per-suite delta (126/16 → 145/17, +19/+1):** AppCategoryTests
+10 (new suite), SettingsStoreTests +4 (7→11), CleanupLevelTests +3
(6→9), CleanupServiceTests +2 (11→13). Matches engineer claim exactly.

## Flake registry

Carried unchanged — see docs/phase-3-tester-baselines.md §Flake registry
(known-noise: linkd XPC 4097, WarnOnce layout, DetachedSignatures,
AX not-vending, appintentsmetadataprocessor, destination auto-pick,
task-name-port, NSCGS/CA during PillPanelTests, CursorUI ViewBridge).
New entries land here.
