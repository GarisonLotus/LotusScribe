# Tester baselines — LotusScribe (Phase 7)

> Last gate's counts + flake registry. Archives: docs/phase-0…6-tester-
> baselines.md (phase-3 holds the full flake registry table).

## Baseline carried into Phase 7

**Commit:** 4c779b1 (6C; Phase-3/4/5/6 human gates queued in
when-vllm-is-back.md).
**Counts:** 191 tests in 19 suites, 0 failures, green ×2 ×2 runners.
**Test command:** `make test` — run TWICE per gate.

**Carried concurrency surface:** dedicated URLProtocol stubs
(TranscriptionServiceTests, ConnectionProbeTests, CleanupServiceTests);
UUID-suffixed UserDefaults suites; R41/R44 warmUp: stubbing. Intentional
log `STT prompt truncated (D59 cap)` once per run = NOT noise. Phase-7
note: onboarding controller is a new composition root → R35
construction-smoke owed; preset writes touch endpoint fields → probe
stubs required in any preset test that saves.

**Environment facts carried:** macOS 26 Tahoe; personal-team signing
(5RC66Q82V9) — NO Developer ID cert on this machine yet (release recipes
must dry-run); Input Monitoring + Accessibility granted.
**Endpoint status: vLLM UP (2026-07-05 evening)** — human batch runs
tomorrow morning.

## Phase 7 gates

| gate | date | staged base | counts | runs | result |
|------|------|-------------|--------|------|--------|
| 7A | 2026-07-05 | staged on 4c779b1 | 201 tests / 20 suites, 0 failures | ×2 | GREEN |
| 7B | 2026-07-05 | staged on 9bd676e | 218 tests / 22 suites, 0 failures | ×2 | GREEN |
| 7C | 2026-07-05 | staged on 5335d98 | 218 tests / 22 suites, 0 failures; recipe legs all pass (see 7C notes) | ×2 (+dmg ×3) | GREEN |

**7A per-suite delta vs 6C baseline (191/19):** EndpointPresetTests NEW
(7 tests, incl. `parseRejectsGarbage(_:)` parameterized ×7 cases = 1
test); SettingsWindowControllerTests 23→26 (+3:
testSuccessSetsPhaseWithoutPersistingOrClosing,
testFailureSetsReasonWithoutClosing, testWithBothURLsEmptyIsNoOp). All
other 18 suites unchanged. 191 + 7 + 3 = 201; 19 + 1 = 20. ✓

**Bookkeeping note:** the dispatch figure "SettingsWindowControllerTests
25→28" counts the 2 suite-less top-level tests in
Tests/LotusScribeTests/SmokeTests.swift (appDelegateInitializes,
mainMenuRoutesPaste) with SWC because they interleave adjacently in log
order. Actual @Suite membership is 23→26; the +3 delta and totals match
exactly.

**7B per-suite delta vs 7A (201/20), per xcresult (log-order attribution
unreliable under interleaving):** OnboardingStateMachineTests NEW (9
tests); OnboardingWindowControllerTests NEW (6 tests); SettingsStoreTests
17→19 (+2). All other 20 suites unchanged (SmokeTests' 2 suite-less
top-level tests counted separately as in the 7A bookkeeping note).
201 + 9 + 6 + 2 = 218; 20 + 2 = 22. ✓ Matches dispatch expectation and
reviewer/engineer figure (218/22) exactly.

**7B warnings:** known-noise only, NO new-in-7B signatures — destination
auto-pick (phase-3 registry); `[WarnOnce] layoutSubtreeIfNeeded`,
`Accessibility: Not vending elements`, task-name-port, `[logging-persist]
DetachedSignatures` at hosted-app launch (all phase-3 registry);
NSURLErrorDomain task logs ×3 from deliberate failure-path tests
(phase-5/6 registry); `STT prompt truncated (D59 cap)` ×1 = intentional,
NOT noise. Hosted onboarding-window tests emitted NO new NSWindow/CA
noise. NSCGS/CA-commit and `[API] cannot add handler` (both registry,
intermittent) happened to be ABSENT this gate — cosmetic, no action.
`[Permissions] TCC at launch` + `[EventTapMonitor] event tap started`
app logs pre-exist at HEAD 9bd676e (intentional, not noise).

**7A warnings:** known-noise only — destination auto-pick (phase-3
registry); NSCGS/CA-commit during PillPanelTests + SWC (phase-3 registry,
phase-5 extension); `[API] cannot add handler` ×8 during SWC (phase-5
registry); `STT prompt truncated (D59 cap)` ×1 = intentional, NOT noise.
No new flakes.

**7C suite delta:** NONE expected, NONE observed — 218/22 identical to
7B ×2 (7C is app-code-free: Makefile, scripts/make-dmg.sh, .gitignore
only). Warnings both runs: known-registry signatures only (destination
auto-pick; WarnOnce layoutSubtreeIfNeeded; Accessibility not-vending;
task-name-port; DetachedSignatures; NSURLErrorDomain ×3 failure-path;
`STT prompt truncated (D59 cap)` ×1 intentional). No new flakes.

**7C recipe legs (no SIGN_IDENTITY / NOTARY_PROFILE, per spec §7C):**
- `make dmg` exit 0; prints `make-dmg: SIGN_IDENTITY not set — shipping
  the dev-signed app.`; creates dist/LotusScribe-1.0.dmg; `hdiutil
  verify` VALID; mounted volume contains LotusScribe.app + Applications
  symlink; `codesign -dv` succeeds (dev signature, universal x86_64+
  arm64); detach clean, no lingering mounts.
- `spctl --assess --type execute` on mounted app: `rejected`, exit 3 —
  recorded as pre-Developer-ID baseline (expected).
- `make notarize` exit 2 (recipe exit 1 wrapped by make): "make
  notarize: NOTARY_PROFILE is not set. Enroll in the paid Apple
  Developer Program, run 'xcrun notarytool store-credentials
  <profile>', then rerun with NOTARY_PROFILE=<profile>."
- `make staple` exit 2, same message with "make staple:" prefix.

**7C reproducibility:** `make dmg` rerun ×2 over existing dist/ — exit 0
both times, overwrites in place via `hdiutil -ov`, rewritten DMG
verifies VALID. Wrinkle (cosmetic, no action): output is functionally
idempotent but NOT byte-identical across runs (770952 → 770946 bytes —
codesign/UDZO timestamp nondeterminism); also `hdiutil detach
/Volumes/LotusScribe` reports the parent whole-disk device ("disk4")
while attach reported the slice (disk5s1) — same image, detach clean.
dist/ correctly gitignored (absent from `git status`).

## Flake registry

Carried unchanged — see docs/phase-3-tester-baselines.md §Flake registry
+ phase-5/6 additions. New entries land here.
