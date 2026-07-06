# Tester baselines — LotusScribe (Phase 6)

> Last gate's counts + flake registry. Archives: docs/phase-0…5-tester-
> baselines.md (phase-3 holds the full flake registry table).

## Baseline carried into Phase 6

**Commit:** 94c4b5d (5C; Phase-3/4/5 close gates OPEN — BLOCKED-BATCH in
when-vllm-is-back.md).
**Counts:** 177 tests in 18 suites, 0 failures, green ×2 ×3 runners.
**Test command:** `make test` — run TWICE per gate.

**Carried concurrency surface:** dedicated URLProtocol stubs
(TranscriptionServiceTests, ConnectionProbeTests, CleanupServiceTests);
UUID-suffixed UserDefaults suites; R41/R44 warmUp: stubbing. Phase-6
note: pasteboard tests likely need serialization (NSPasteboard.general
is machine-global state) — watch for cross-suite bleed; expected
intentional log line `STT prompt truncated (D59 cap)` from
overBudgetDictionarySendsStrictPrefixOfTerms is NOT noise.

**Environment facts carried:** macOS 26 Tahoe; personal-team signing
(5RC66Q82V9); Input Monitoring + Accessibility granted; tap `defaultTap`;
mic prompt at first recording start.
**Endpoint status: vLLM UNREACHABLE (2026-07-05)** — human verifies →
when-vllm-is-back.md.

## Phase 6 gates

| gate | date | staged base | counts | runs | result |
|------|------|-------------|--------|------|--------|
| 6A | 2026-07-05 | 94c4b5d + staged 6A diff (PillState, PillView, DictationController, PillStateTests) | 179 tests / 18 suites, 0 failures | ×2 green | PASS |
| 6B | 2026-07-05 | 6575fe3 + staged 6B diff (InsertionPolicy, TextInserter, InsertionPolicyTests) | 183 tests / 19 suites, 0 failures | ×2 green | PASS |
| 6C | 2026-07-05 | 85df11d + staged 6C diff (InsertionPolicy +33, TextInserter +106/−8 incl. post-review D43 ordering fix, InsertionPolicyTests +55) | 191 tests / 19 suites, 0 failures | ×2 green | PASS |

6A per-suite delta vs 177/18 baseline (5C): PillStateTests 6→8 (new:
blockedFlashesAtBlockedFlashDuration, blockedIsNonSticky); all other 17
suites + 2 top-level AppDelegate tests unchanged from the 5C full
per-suite counts (docs/phase-5-tester-baselines.md).

**6A warnings:** known-noise only (destination auto-pick; NSCGS/CA +
`[API] cannot add handler` during SettingsWindowControllerTests;
NSURLErrorDomain -1001/-1004 task logs from deliberate failure-path
tests; task-name-port). Intentional `STT prompt truncated (D59 cap)`
line present once per run as expected (NOT noise). Zero compiler
warnings. No new flake entries.

**6A CROSS-CHECK:** reviewer reported 179/18 — MATCHED (tester
independent ×2: 179 tests / 18 suites, green both runs).

6B per-suite delta vs 179/18 (6A): NEW suite InsertionPolicyTests = 4
(foundAndSettableRoutesToAX, foundButNotSettableRoutesToPasteboard,
settableWithoutFocusedElementRoutesToPasteboard,
neitherFoundNorSettableRoutesToPasteboard); all other 18 suites + 2
top-level AppDelegate tests unchanged (PillStateTests still 8).

**6B warnings:** known-noise only, same set as 6A (destination
auto-pick; NSCGS/CA + `[API] cannot add handler` during
SettingsWindowControllerTests; NSURLErrorDomain -1001/-1004 task logs
from deliberate failure-path tests; task-name-port). Intentional
`STT prompt truncated (D59 cap)` line present once per run (NOT noise).
Zero compiler warnings. No new flake entries.

**6B CROSS-CHECK:** reviewer + orchestrator reported 183/19 (×2
combined) — MATCHED (tester independent ×2: 183 tests / 19 suites,
green both runs).

6C per-suite delta vs 183/19 (6B): InsertionPolicyTests 4→12 (new:
unavailableGateSavesClipboard, standardGateSavesClipboard,
askGateSkipsSave, alwaysAllowGateSavesClipboard,
alwaysDenyGateSkipsSave, noSnapshotNeverRestores,
movedChangeCountSkipsRestore, snapshotWithUnmovedChangeCountRestores);
all other 18 suites + 2 top-level AppDelegate tests
(constructionDoesNotRaise, appDelegateInitializes) unchanged.

**6C warnings:** known-noise only (destination auto-pick; NSCGS/CA +
`[API] cannot add handler` during SettingsWindowControllerTests;
NSURLErrorDomain -1001 ×2 / -1004 ×1 task logs from deliberate
failure-path tests; task-name-port; `[logging-persist] cannot open
file` Security noise; `[WarnOnce] layoutSubtreeIfNeeded` run 1 only —
registered intermittent, phase-3 registry). Intentional
`STT prompt truncated (D59 cap)` line present once per run (NOT noise).
Zero compiler warnings. No new flake entries.

**6C CROSS-CHECK:** reviewer reported 191/19 (post-fix, ×1) — MATCHED
(tester independent ×2: 191 tests / 19 suites, green both runs).

## Flake registry

Carried unchanged — see docs/phase-3-tester-baselines.md §Flake registry
+ phase-5 additions. New entries land here.
