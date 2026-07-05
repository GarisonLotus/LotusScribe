# Reviewer observations — LotusScribe (Phase 4)

> Forward-looking items for Phase 4. Archives: phase-0 (R1–R4), phase-1
> (R5–R28), phase-2 (R29–R35), phase-3 (R36–R42). Numbering continues at
> R43. Only still-open rows carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R7 | 1A (carried) | Combo keycode map is ANSI-positional (kVK_ANSI_*): "z" means the physical ANSI-Z key, not the layout character (AZERTY/Dvorak diverge). Revisit when hotkey-config UI lands (Phase 7+) | open (future phase, note only) |
| R34 | 2C (carried) | Straggler-attribution micro-window: a queued level block from a just-stopped capture could flip a NEW capture's `.warming` → `.recording` one frame early — not realistic; cosmetic even if hit. Blocked-window ruling (phase-3 log): stays note-only, no speculative fix | open (note only) |
| R35 | 2C (carried) | STANDING RULE — construction-smoke coverage for composition roots: any TCC-free composition-root type constructed on the launch path gets a construction test at introduction, not after a regression (D34 lesson; AppKit swallows init-time NSExceptions silently) | open (process rule) |
| R41 | 3C (carried) | Latent test-hygiene hazard: SettingsWindowController's default warm-up closure runs a REAL `CleanupService.warmUp()` network Task; XCTestSessionIdentifier guard covers only the AppDelegate launch trigger. Every current test stubs `warmUp:` or never persists a changed LLM config. Blocked-window ruling: stays backlog; revisit only if a test ever constructs the controller without a stub. **Phase-4 relevance: 4C touches SettingsWindowControllerTests — new tests there MUST keep stubbing `warmUp:`** | open (note only, 4C watch) |
| R42 | 3D (carried) | Slot-1 truthfulness wrinkle on the stale-drop path: staged slot 1 shows "STT succeeded" at transcript-accept, pre-insert; a deliberate overlapping dictation drops gen N after that display. Accepted as D47's framing (slot 1 = STT proof, not insert proof); note only | open (note only) |

## Gate notes

### 4A gate — staged review (2026-07-05)

**VERDICT: PASS — approve for commit.** Independent `make test`: green,
145 tests / 17 suites (baseline 126/16; matches expected delta).

- D51 byte-identity floor: `otherStandardPromptIsByteIdenticalToPhase3Fixture`
  and `otherLightPromptIsByteIdenticalToPhase3Fixture` pin LITERAL strings
  (compile-time literal concatenation, identical to the pre-4A fixture
  literals per the removed diff lines) against `systemPrompt(for: .other)` —
  not composition-vs-composition. Invariant is genuinely test-enforced.
- D50: taxonomy + displayNames exact per spec; built-in map is an
  exact-match dictionary (all 20 spec bundle IDs verified, no
  prefix/wildcard); overrides consulted before built-in; garbage rawValue
  falls through — both mapped→built-in and unmapped→`.other` tested.
- D53: getter = `defaults.dictionary` + `compactMapValues { $0 as? String }`;
  empty⇄absent tested in both directions; non-string junk filtered (tested);
  diff never touches SettingsWindowController/draft — no probe/warm-up
  coupling introduced.
- D52: `cleanup(transcript:frontmostBundleID:)` has NO default value;
  DictationController passes literal `nil` at the sole production call
  site; no NSWorkspace import or API use anywhere in the diff (two
  doc-comment mentions only — R43).
- Tone splice: structural test `tonedPromptsSpliceToneBeforeFinalCloser`
  derives toned = neutral-with-tone-before-closer for 4 toned categories ×
  2 levels; `.off` → nil for ALL categories via `allCases` loop.
- Hot path unchanged: temperature 0 asserted; key-set tripwire
  `Set(json.keys) == ["model", "messages", "temperature"]` intact;
  `warmUp()` untouched (it never used `systemPrompt`).
- LoC overages (AppCategory.swift 90 vs ~85; test deltas +52/+45/+36 raw
  vs ceilings, engineer-flagged): ACCEPTED per R6 precedent — overage is
  verbatim fixture strings plus mechanical call-site signature churn, no
  logic bloat.
- Minor, no action owed: the `cleanup category:` log line fires before the
  notConfigured guard, so a category is logged even when cleanup then
  throws `.notConfigured` — log-only, matches D52's "logged at resolution
  time" wording.

### 4B gate — staged review (2026-07-05)

**VERDICT: PASS — approve for commit.** Independent `make test`: green,
145 tests / 17 suites (unchanged vs 4A gate, per spec — no new tests owed,
D49 precedent).

- Diff scope: UNSTAGED working-tree diff touches ONLY
  `DictationController.swift` (+15/−3): AppKit import, `capturedBundleID`
  instance var, capture + log in `startRecording`, per-Task local snapshot
  in `stopRecording`, snapshot passed to `cleanup(transcript:
  frontmostBundleID:)`. Removed lines are only the 4A placeholder comment
  ("4B replaces this") plus the literal `nil` — exactly what 4B owes.
- D52 capture point: `NSWorkspace.shared.frontmostApplication?
  .bundleIdentifier` read in `startRecording` (key-down), not at cleanup
  time. Capture sits BEFORE the recorder `do/catch` — spec-conformant
  ("before/alongside `recorder.start()` — exact line order engineer's
  choice"). Recorder-start-FAILURE leg is safe: `isRecording` stays false,
  `stopRecording` guards on it, so the orphaned capture is never consumed
  and is overwritten at the next key-down.
- D23 no-bleed: `let capturedBundleID = capturedBundleID` shadows the
  instance var directly alongside `capturedGeneration`, before the Task —
  a newer dictation's capture cannot reach an older in-flight Task.
- Log line at capture present (`frontmost at key-down:`, nil-coalesced,
  `.public`); category resolution/logging stays in CleanupService (single
  map-read site, per spec).
- No DI seam (direct NSWorkspace call — 3B no-seam ruling / D49 adapter
  posture); nil frontmost degrades via the existing nil→`.other` path;
  no pill/UI change; D43 failure policy untouched.
- Orchestrator-direct edit (engineer dispatch skipped): ACCEPTABLE for
  this diff — ~18 lines, single file, spec §4B prescribes the exact code
  nearly line-for-line, D49-precedent trivial-change path. No flag.
- Remaining before gate closes fully: 4B verify #2 (HUMAN-AT-SCREEN log
  check, not vLLM-dependent) and #3/#4 (BLOCKED-BATCH tone checks) are
  still owed per spec; my PASS covers the machine-verifiable surface.

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
| R43 | 4A | Spec §4A verify #3 says "no NSWorkspace reference anywhere in 4A's diff"; a literal grep hits two DOC-COMMENT mentions (AppCategory.swift header, AppCategoryTests.swift header) explaining the D52/D14 adapter split. No import or API use — ruled pass-as-intended (the check's target is framework coupling). Noted so 4B's verify grep isn't misread as a 4A regression | closed (note only) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
