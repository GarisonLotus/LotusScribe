# Architect log — LotusScribe

> Locked decisions + open questions. Updated by architect at end of each
> dispatch. Read by architect on every spawn; read by engineers when spec
> is ambiguous; read by reviewer for spec-drift checks.
>
> Keep entries terse — bullets, not paragraphs. Rationale is one line.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D1 | 2026-07-04 | XcodeGen: project.yml committed, .xcodeproj gitignored | Reviewable diffs, CLI-friendly; user choice | 0 |
| D2 | 2026-07-04 | Bundle ID `com.garisonlotus.LotusScribe` | User choice | 0 |
| D3 | 2026-07-04 | Phase 0 settings = storage layer only + unit tests | Settings UI arrives Phase 1 per PLAN.md; user choice | 0 |
| D4 | 2026-07-04 | Swift Testing framework | Modern macros; Xcode 26 supports; user choice | 0 |
| D5 | 2026-07-04 | macOS 14+ deployment target | PLAN.md architecture line | 0 |
| D6 | 2026-07-04 | Ad-hoc signing for Phase 0 | No identities on machine; no TCC needed yet | 0 |
| D7 | 2026-07-04 | Own Keychain wrapper (Security framework), no third-party dep | ~60 lines; avoids dep for one concern | 0 |
| D8 | 2026-07-04 | Test bundle target + scheme + smoke test land in 0A, not 0B | `make test` green from first commit; no project.yml churn in 0B | 0A |
| D9 | 2026-07-04 | Settings keys: sttEndpointURL, sttModel, llmEndpointURL, llmModel (standard UserDefaults, nil defaults) | Matches PLAN.md Architecture; minimal set | 0B |
| D10 | 2026-07-04 | Keychain service = bundle ID; accounts stt-api-key / llm-api-key; tests use suffixed test service + teardown cleanup | Per-endpoint keys per PLAN.md; keeps real Keychain clean | 0B |
| D11 | 2026-07-04 | Info.plists are generated, never committed: app via xcodegen `info:` block (path gitignored); test target via `GENERATE_INFOPLIST_FILE: YES` | Extends D1 to plists; xcodegen emits no plist for test bundles yet signing needs one (R1/R2 round-trip) | 0A |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| Q1 | 2026-07-04 | Signing team ID before Phase 1 (TCC grant stability; also gates reliable Keychain reads — legacy-keychain ACLs key off code signature, and ad-hoc signing (D6) re-signs every build, so stored API keys may prompt/fail in later phases until Q1 closes; see reviewer R4) | open | user (Apple ID / dev account) |

## Notes

PLAN.md is the authoritative design doc; do not rewrite it — phase specs
live in docs/phase-N-spec.md.
