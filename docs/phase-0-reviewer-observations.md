# Reviewer observations — LotusScribe

> Numbered forward-looking observations from gate reviews. Updated by
> reviewer at end of each dispatch. Read by reviewer on every spawn;
> read by orchestrator when planning the next sub-phase brief.
>
> Forward-looking = "things nicer at a future extraction point, pattern
> duplications worth consolidating, convention violations to address
> symmetrically." NOT blocking issues — those stay in the gate verdict.

## Items

| id | first raised | item | status |
|----|--------------|------|--------|
| R1 | 2026-07-04 | `.gitignore` carries a 5th entry (`Sources/LotusScribe/Info.plist`) beyond spec §"Repo layout"'s four. Judged correct — project.yml's `info:` block makes xcodegen generate it, and committing generated files is a rail violation. Architect should fold it into the spec's gitignore list at next round-trip so spec and repo agree. | addressed-in-0A-roundtrip |
| R2 | 2026-07-04 | `GENERATE_INFOPLIST_FILE: YES` on the test target is a necessary workaround (xcodegen emits no plist for unit-test bundles; signing needs one) but is undocumented in spec §"project.yml essentials". Architect should record it there so 0B/future edits don't drop it. | addressed-in-0A-roundtrip |
| R3 | 2026-07-04 | `SmokeTests.swift`'s `#expect(AppDelegate() is NSApplicationDelegate)` is statically always-true; it earns its keep only as a link/load smoke (per its docstring). Once 0B lands behavioral suites (SettingsStore/KeychainStore), consider retiring or repointing it at real behavior. **0B ruling: keep as link-smoke.** The 0B suites `@testable import` the app target but touch only SettingsStore/KeychainStore; the smoke is the sole test constructing an AppKit-layer type (`AppDelegate`), so retiring it drops link coverage of the UI layer to zero for an 8-line saving. Repoint at real behavior when AppDelegate/StatusItemController gain testable behavior (Phase 1). | resolved-keep |
| R4 | 2026-07-04 | KeychainStore uses the file-based (legacy) keychain — no `kSecUseDataProtectionKeychain` — whose item ACLs key off the app's code signature. Under ad-hoc signing (D6) every rebuild produces a new signature, so in later phases production reads of previously stored API keys may prompt the user or fail until re-saved. Harmless in Phase 0 (tests create and delete items within one hosted run); resolves naturally with Q1 (real signing identity). Architect should note the linkage when Q1 closes. | open |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none yet) |                |                 |
