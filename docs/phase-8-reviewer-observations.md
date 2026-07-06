# Reviewer observations — LotusScribe (Phase 8)

> Forward-looking items for Phase 8. Archives: phase-0…7 (R1–R69).
> Numbering continues at R70. Only still-open, phase-8-relevant rows
> carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R35 | 2C (carried) | STANDING RULE — construction-smoke test for TCC-free composition-root types on the launch path, at introduction | open (process rule) |
| R41 | 3C (carried) | SettingsWindowControllerTests MUST stub `warmUp:` (real network default) — LIVE: 8A adds controller tests, 8B changes warm-up triggering | open (watch, 8-live) |
| R45 | 4C (carried) | Probe-trigger wording care for new settings keys — 8A adds a settings key (reasoning toggle); confirm it does NOT feed the probe/warm-up tuple (D37/D42) | open (watch, 8-live) |
| R49 | 5B (carried) | Button row outside Form's disabled scope — 8A touches SettingsForm | open (watch, 8-live) |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R70 | 8A | NOTE-ONLY: `SettingsDraft.save()` doc comment enumerates D9/D40/D53 keys but not the D72 key (D56 terms were already unlisted pre-8A — same summary style). Fold into the comment on next touch of save(); no code action | note |
| R71 | 8A | The new `suppressReasoningRoundTripsThroughDraft` test leaves probe closures at real-network defaults, unfired only via the both-URLs-empty guard (established pattern, cf. cancel-path test). If a future amendment drafts a URL there, real probes fire silently — R41's warmUp watch extends to probe seams for this test | open (watch) |
| R72 | 8B | NOTE-ONLY: `Task { await cleanup.warmUp() }` implicitly retains `self` (the controller) for the warm-up's duration (bounded by the 30 s timeout). Harmless today — DictationController is app-lifetime — but if the controller ever becomes recreatable, capture `[cleanup]` explicitly. No code action | note |
| R73 | 8B | VERIFIED, recording rationale: the exact-30 s boundary test is deterministic, not a float flake — 30 is an integer multiple of Date's ulp (2⁻²³ s in the current binade), so `addingTimeInterval(-30)` and the subtraction are both exact. This exactness holds only for integer offsets; a future fractional-boundary test (e.g. 29.95) would not be exact at the boundary | note |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
