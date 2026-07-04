# Tester baselines — LotusScribe

> Last gate's exact counts + flake registry. Updated by tester at end of
> each dispatch. Read by tester on every spawn for cross-checking.

## Last gate

**Sub-phase:** 0B
**Date:** 2026-07-04
**Test command:** `make test` (xcodegen generate → xcodebuild test, scheme LotusScribe, platform=macOS)
**Counts:** TEST SUCCEEDED — "Test run with 12 tests in 2 suites passed" (12 tests total: 11 in 2 suites + 1 standalone smoke), 0 failures. xcresult: errorCount 0, warningCount 0, analyzerWarningCount 0.
**Per-file breakdown:**
- `Tests/LotusScribeTests/KeychainStoreTests.swift` — suite KeychainStoreTests, 5 tests, all passed (0.055s): `getMissingAccountReturnsNil`, `setThenGetRoundTrips`, `setOverwritesExistingSecret`, `deleteRemovesSecret`, `deleteOfMissingAccountDoesNotThrow`
- `Tests/LotusScribeTests/SettingsStoreTests.swift` — suite SettingsStoreTests, 6 tests, all passed (0.004s): `sttEndpointURLRoundTrips`, `sttModelRoundTrips`, `llmEndpointURLRoundTrips`, `llmModelRoundTrips`, `unsetKeysDefaultToNil`, `valuesPersistAcrossStoreInstances`
- `Tests/LotusScribeTests/SmokeTests.swift` — 1 standalone test: `appDelegateInitializes()` — passed (0.001s)

**Warnings triaged:** none — zero compiler/analyzer warnings (verified via
`xcrun xcresulttool get build-results` on the test xcresult). Runtime log
noise during hosted test run matched the known-noise registry entries below,
plus two new benign `[logging-persist]` lines during Keychain tests (see
registry). No new warnings.

Runtime/artifact checks (0B verify steps 2–3 + Keychain hygiene), 2026-07-04:
- Spec verify #3: after the test run, `security find-generic-password -s com.garisonlotus.LotusScribe.tests` finds nothing (exit 44) — teardown cleaned up.
- Real service untouched: `security find-generic-password -s com.garisonlotus.LotusScribe` finds nothing (exit 44).
- Spec verify #2 (phase-0 exit criterion, storage layer): `defaults write com.garisonlotus.LotusScribe sttModel whisper-1` → launched built .app (make build succeeded; pgrep confirmed running) → quit via AppleScript (pgrep confirmed exited) → `defaults read com.garisonlotus.LotusScribe sttModel` returned `whisper-1`. Throwaway key deleted afterward and confirmed gone.
- Human-visual remainder: none new for 0B (no UI in this sub-phase — D3). 0A's remain: status item visible in menu bar; Quit works from UI; absence from Cmd-Tab. The "fresh SettingsStore reads it back" half of verify #2 is covered by `valuesPersistAcrossStoreInstances` at the suite level, not against .standard (tests must not touch .standard — invariant).

## Flake registry

| date | test name | failure mode | other tests in same file affected |
|------|-----------|--------------|-----------------------------------|
| 2026-07-04 | (known-noise, not a flake) | `com.apple.linkd.autoShortcut` XPC errors (NSCocoaErrorDomain 4097) logged at hosted-app launch during `make test`; cosmetic, tests unaffected | none |
| 2026-07-04 | (known-noise, not a flake) | one `[WarnOnce] It's not legal to call -layoutSubtreeIfNeeded on a view which is already being laid out` runtime log at hosted-app launch; cosmetic, tests unaffected | none |
| 2026-07-04 | (known-noise, not a flake) | two `[logging-persist] ... open(/private/var/db/DetachedSignatures) - No such file or directory` runtime logs during first Keychain test (`setThenGetRoundTrips`); OS-level Security framework noise, tests unaffected | none |
| 2026-07-04 | (known-noise, not a flake) | one `[General] Accessibility: Not vending elements because elementWindow(25) is lower than shield(2001)` runtime log at hosted-app launch; cosmetic, tests unaffected | none |
