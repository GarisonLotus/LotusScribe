# Reviewer observations — LotusScribe (Phase 6)

> Forward-looking items for Phase 6. Archives: phase-0 (R1–R4), phase-1
> (R5–R28), phase-2 (R29–R35), phase-3 (R36–R42), phase-4 (R43–R45),
> phase-5 (R46–R53). Numbering continues at R54. Only still-open rows
> carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R7 | 1A (carried) | ANSI-positional keycode map; AZERTY/Dvorak diverge. Hotkey-config UI (Phase 7+) | open (note only) |
| R34 | 2C (carried) | Straggler-attribution micro-window; cosmetic | open (note only) |
| R35 | 2C (carried) | STANDING RULE — construction-smoke test for TCC-free composition-root types on the launch path, at introduction. LIVE for Phase 6 if an inserter/detector type joins the launch path | open (process rule) |
| R41 | 3C (carried) | Controller tests MUST stub `warmUp:` (real network default) | open (watch) |
| R42 | 3D (carried) | Slot-1 truthfulness on stale-drop path; accepted per D47 | open (note only) |
| R44 | 4C (carried) | 3 of 4 4C tests ride R41 carve-out | open (note only) |
| R45 | 4C (carried) | Probe-trigger wording care for new settings keys | open (note only) |
| R46 | 5A (carried) | 600-char STT budget assumes ~3 chars/token; non-Latin lists could exceed 224 tokens — batch-time check | open (batch time) |
| R48 | 5B (carried) | Truncation-log recovery coupled to strict-prefix builder contract (pinned in D59 note) | open (note only) |
| R49 | 5B (carried) | Button row outside Form's disabled scope — sole-guard watch on SettingsForm edits (verified intact at 5C) | open (watch) |
| R51 | 5C (carried) | Unicode fold mismatch: store dedup lowercased() vs add-guard caseInsensitiveCompare (ß/SS) — can't dup IDs; consistency nit | open (note only) |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R54 | 6A | DictationController delta +9 vs spec ceiling ~8; overage is the 3-line why-comment pinning the D63 order invariant (guard before generation bump). Comment is load-bearing documentation of exactly the invariant a future edit would break — accepted per R6 judgment, not a pattern to repeat silently | closed (accepted) |
| R55 | 6A | Blocked arm uses `.foregroundStyle(.orange)` rather than D64's literal "systemOrange"; matches the file's existing D48 idiom (PillView.swift:77 already `.orange`). Architect ruled acceptable, no pinning | closed (accepted) |
| R56 | 6B | TextInserter gross delta +65 vs spec ceiling ~55; overage is doc/why comments (rewritten header invariant block, probe semantics, D43-chain and D65 log-contract inline comments). Code additions ~41, within ceiling. Comments pin exactly the invariants a future edit would break — accepted per R6 judgment, mirrors R54; not a pattern to repeat silently | closed (accepted) |
| R57 | 6B | Spec 6B verify 2 ("no AX symbol outside TextInserter.swift") hits two comment-only strings: `kAXSelectedText` in InsertionPolicy.swift:16 doc comment (engineer-flagged) AND InsertionPolicyTests.swift:5 doc comment (unflagged). Zero AX API usage outside TextInserter — grep is clean when read as symbol-usage. For 6C's grep-enforced D62 boundary, word the check as API-call patterns (e.g. `data(forType:`) not bare identifiers, or comment mentions will false-positive again | open (note for 6C) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
