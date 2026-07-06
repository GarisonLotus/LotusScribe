# Reviewer observations — LotusScribe (Phase 5)

> Forward-looking items for Phase 5. Archives: phase-0 (R1–R4), phase-1
> (R5–R28), phase-2 (R29–R35), phase-3 (R36–R42), phase-4 (R43–R45).
> Numbering continues at R46. Only still-open rows carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R7 | 1A (carried) | Combo keycode map is ANSI-positional; AZERTY/Dvorak diverge. Revisit at hotkey-config UI (Phase 7+) | open (future phase, note only) |
| R34 | 2C (carried) | Straggler-attribution micro-window (.warming → .recording one frame early); cosmetic | open (note only) |
| R35 | 2C (carried) | STANDING RULE — construction-smoke test for any TCC-free composition-root type on the launch path, at introduction | open (process rule) |
| R41 | 3C (carried) | SettingsWindowController default warm-up closure = REAL network Task; tests MUST stub `warmUp:` (see R44 for the 4C partial) | open (note only, watch on any new controller tests) |
| R42 | 3D (carried) | Slot-1 truthfulness wrinkle on stale-drop path; accepted per D47 framing | open (note only) |
| R44 | 4C (carried) | 3 of 4 4C controller tests ride R41's carve-out (no drafted LLM change) instead of stubbing warmUp:. Tighten if they ever draft LLM fields | open (note only) |
| R45 | 4C (carried) | Probe-trigger wording: invariant is "overrides never trigger a probe/warm-up," not "overrides-only save fires no probe" (D37/D44 every-Save probe). Same wording care applies to any Phase-5 settings keys | open (note only) |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R46 | 5A | D59's 600-char STT budget assumes ~3 chars/token (ASCII proper nouns). Non-Latin/CJK/emoji terms invert that ratio — a within-budget prompt could still exceed Whisper's 224-token window, silently dropping FIRST terms server-side (the exact failure D59 targets). Check at the Q5-1/Q5-2 BLOCKED-BATCH probes if the user's list is non-ASCII | open (note only, batch time) |
| R47 | 5A | `SettingsStore.dictionaryTerms` setter persists input un-normalized by design (D56 normalizes at READ). Fine for 5C (draft seeds from normalized reads, UI has its own dup guard), but any future write path (import/export, CLI seeding) must not treat stored bytes as canonical — only reads are | open (note only) |
| R48 | 5B | The D59 truncation-log recovery in `TranscriptionService.transcribe` (first N with `prefix(N).joined == prompt`) is correct TODAY because `sttPrompt` `break`s at the first non-fitting term (output is always one strict prefix join; normalized terms ⇒ strictly growing joins ⇒ unique match). If D59 ever changes to skip-and-continue (drop an oversized middle term, keep trying), no prefix matches and the `?? terms.count` fallback silently logs NOTHING — recheck this loop on any sttPrompt amendment (e.g. a Q5-1 batch-time tuning) | open (note only, coupling watch) |
| R49 | 5B (6a98dfb fold-in) | Post-hotfix, the Save/Cancel row rides `.safeAreaInset` OUTSIDE the Form's `.disabled(probeState.phase == .testing)` scope — the row's own `.disabled` (kept by the hotfix) is now the SOLE mid-test guard for those buttons. Anyone later "deduplicating" the row's modifier as redundant with the Form's re-enables Save mid-probe. VERIFIED at 5C gate: both guards intact; new Dictionary section sits INSIDE the Form and inherits its disabled scope | open (note only, standing watch on this file) |
| R50 | 5B | Test LoC overage (+44 vs ~40) bought two shared helpers (`capturedBody`/`expectedBody`); accepted. The two pre-5B body tests (`requestMatchesSpec`, `languageFieldSentWhenConfigured`) still hand-roll the same capture/rebuild pattern — fine now (surgical-change rule), a cheap consolidation if either is ever touched anyway | open (note only) |
| R51 | 5C | Two different Unicode case-foldings guard against dictionary duplicates: `addTerm` uses `caseInsensitiveCompare`, the D56 store read-dedup uses `lowercased()`. They disagree on edge pairs (e.g. "ß"/"SS": the store getter keeps both, the UI guard would refuse the add). NOT a `ForEach(id: \.self)` risk — EXACT duplicates are impossible on every path (store read dedups identical strings; `caseInsensitiveCompare == .orderedSame` is always true for an exact match, so addTerm can't append one; termRow's removeAll only removes), and case-variant-distinct strings get distinct `\.self` IDs. Only consequence: a `defaults write`-seeded pair the UI would never create. Align the two foldings if either is ever touched anyway | open (note only) |
| R52 | 5C | Controller-test LoC +76 vs ~35 ceiling — overage is per-test setup boilerplate (suite defaults, store, controller) + doc comments; the 4 tests are exactly the 4 spec-named behaviors, no speculative coverage, no new helpers. Accepted (R6 judgment, R50 precedent). All 4 stub `warmUp:` explicitly — the R44 carve-out is UNUSED this time; R41 discipline fully honored | open (note only) |
| R53 | 5C | Approved deviation: Add-row no-op on a case-insensitive duplicate KEEPS the typed field (spec D60 "clears the field" read as success-path-only; engineer flagged the lean). Keeping rejected text visible is the honest behavior — clearing would silently eat input with no feedback. AT-SCREEN verify item 2 (5C) should expect the field to retain the duplicate text | open (note only, at-screen expectation) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
