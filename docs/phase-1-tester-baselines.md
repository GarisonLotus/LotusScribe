# Tester baselines — LotusScribe (Phase 1)

> Last gate's counts + flake registry. Phase-0 archive:
> docs/phase-0-tester-baselines.md.

## Last gate

**Sub-phase:** 0B (phase-0 close; carried as baseline)
**Test command:** `make test`
**Counts:** 12 tests in 2 suites + 1 standalone smoke, 0 failures, 0 warnings.
- KeychainStoreTests: 5 · SettingsStoreTests: 6 · smoke appDelegateInitializes: 1

## Flake registry (known-noise, carried from phase 0)

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-04 | (known-noise) | linkd XPC errors (NSCocoaErrorDomain 4097) at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `[WarnOnce] layoutSubtreeIfNeeded` log at hosted-app launch | cosmetic, intermittent |
| 2026-07-04 | (known-noise) | `[logging-persist] .../DetachedSignatures - No such file or directory` during Keychain tests | Security framework noise |
| 2026-07-04 | (known-noise) | `Accessibility: Not vending elements` at hosted-app launch | cosmetic |
