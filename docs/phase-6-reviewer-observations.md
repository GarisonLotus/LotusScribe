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
| R57 | 6B | Spec 6B verify 2 ("no AX symbol outside TextInserter.swift") hits two comment-only strings: `kAXSelectedText` in InsertionPolicy.swift:16 doc comment (engineer-flagged) AND InsertionPolicyTests.swift:5 doc comment (unflagged). Zero AX API usage outside TextInserter — grep is clean when read as symbol-usage. For 6C's grep-enforced D62 boundary, word the check as API-call patterns (e.g. `data(forType:`) not bare identifiers, or comment mentions will false-positive again | closed (6C grep run as API-call patterns; clean) |
| R58 | 6C | TextInserter 6C code additions = 63 non-comment lines vs spec ceiling ~50 (measured: 63; engineer-flagged). Overage is structural: the 7-arm exhaustive `accessBehavior` switch incl. `@unknown default` (D62 gate mapping) plus the four D62/D38 log statements (saved / save-skipped / restore-skipped+reason / restored) — all spec-mandated, nothing speculative. Accepted per R6 judgment, mirrors R54/R56; third acceptance in Phase 6 — architect should size Phase-7 ceilings with exhaustive-switch+log overhead priced in rather than keep spending R6 judgment | closed (accepted) |
| R59 | 6C | Snapshot stores each item as `[PasteboardType: Data]` — a dictionary — so the writer's declared type ORDER (`item.types`, fidelity-ordered richest-first by convention) is lost on restore; rebuilt items re-declare types in dictionary-iteration order. Readers that honor declaration order could pick a lower-fidelity representation after a restore. Contents are complete (spec's stated bar); ordering is beyond the D62 contract. Note-only; batch verify 3 (image survives) would surface it if it ever bites | open (note only) |
| R60 | 6C | Back-to-back dictations inside `restoreDelay`: dictation 2's snapshot captures dictation 1's TEXT (still on the board), so the eventual restore restores dictated text, not the user's original clipboard. changeCount semantics hold exactly as D62 states — nothing NEWER is ever clobbered, restore 1 correctly skips — but "clipboard survives a dictation" degrades to Phase-1 clobber across rapid pairs. Within D62's written guarantee; note for the batch matrix only | open (note only) |
| R61 | 6C | Blocker fix re-verified (restore had been scheduled before synthesis → D43 clobber of last-resort text on the CGEvent-failure path): `scheduleRestore` now called after `keyUp.post`, `writtenChangeCount` still recorded immediately after the write, CGEvent-failure return schedules NO restore, both sites carry D43 why-comments. `make test` 191/19 green (reviewer ×1 post-fix) | closed (fix verified) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
