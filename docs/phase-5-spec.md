# Phase 5 Spec — Custom dictionary (PLAN.md §Phase 5)

> Authored by architect, 2026-07-05. Rulings D56–D60 in
> docs/phase-5-architect-log.md; D1–D55 remain binding (carry pointer
> there). Baseline: 149 tests / 17 suites at 8f063c5. LoC budgets are
> ceilings. No third-party deps (D7).
>
> **Standing context:** vLLM is DOWN (Q4-2). Same posture as Phase 4:
> every sub-phase below is machine-verifiable-first and committable during
> the blocked window. Verify items are classified MACHINE / AT-SCREEN
> (no vLLM) / BLOCKED-BATCH (needs vLLM); the orchestrator copies the
> latter two classes into when-vllm-is-back.md.

## Requirement (PLAN.md §Phase 5, authoritative)

1. User-managed vocabulary list in settings.
2. Inject into both stages: Whisper `prompt` field (initial prompt
   biasing) and cleanup system prompt ("these terms are spelled
   exactly: …").

**PLAN verify:** dictate personal names/product terms; spelled correctly.

## Cross-cutting design

- **Storage (D56, D53 pattern):** SettingsStore gains
  `dictionaryTerms: [String]` (key `"dictionaryTerms"`, a defaults ARRAY —
  order is user-meaningful: first terms survive the STT cap, D59). Get
  normalizes (String values only, whitespace-trimmed, empties dropped,
  case-insensitive dedup keeping first occurrence); set writes the whole
  array; empty ⇄ absent key.
- **One shared pure builder (D57/D58/D59):** new `DictionaryPrompt.swift`
  (Foundation-only enum, D14 headless): `cleanupClause(terms:)` and
  `sttPrompt(terms:)`, both nil for `[]`. Both consuming services read
  `settings.dictionaryTerms` fresh at request time (D40 live-read posture).
- **Neutrality invariant (D57, extends D51):** an EMPTY dictionary
  composes byte-identical to Phase-4 output — every category × level, and
  the STT request byte-identical too (`prompt` field omitted entirely,
  D18 idiom). Test-guarded, not eyeballed, exactly like D51.
- **Independence from cleanup level (D58):** STT biasing applies whenever
  terms exist, even with cleanup `.off` or not effective-enabled — it is
  an STT-stage feature. The cleanup clause rides inside
  `systemPrompt(for:dictionary:)`, so `.off` → nil gating is automatic.
- **Untouched surfaces:** ConnectionProbe (testSTT builds its own
  multipart, D36 — probes stay content-indifferent), warm-up body (D42),
  cleanup request shape/timeout (D39/D45), failure policy (D43), pill
  (D46–D48), hotkey path, `cleanup(transcript:frontmostBundleID:)`
  signature (D52 — dictionary is read inside the service, like overrides).

## Sub-phase 5A — Dictionary core + cleanup weave (pure, headless)

**Storage (D56):** `SettingsStore.dictionaryTerms` as above, doc comment
citing D56. Read-time normalization mirrors R39's posture: a raw
`defaults write` of junk can never reach prompt composition un-normalized.

**Builders (D57/D59):** `DictionaryPrompt.swift`:

```swift
enum DictionaryPrompt {
    static let sttPromptCharacterBudget = 600  // D59
    static func cleanupClause(terms: [String]) -> String?  // nil for []
    static func sttPrompt(terms: [String]) -> String?      // nil for []; capped
}
```

- `cleanupClause` (verbatim fixture, uncapped):
  `"These terms are spelled exactly as written: " +
  terms.joined(separator: ", ") + "."`
- `sttPrompt`: `terms.joined(separator: ", ")`, including terms in list
  order while the joined result stays ≤ 600 characters; first term always
  included even if oversized (a single absurd term degrades to itself,
  never to nil). Dropped-terms case is pure — no logging in the builder;
  TranscriptionService logs when the built prompt used fewer terms than
  the list (5B).

**Cleanup composition (D57, amends D51's rule shape):**
`CleanupLevel.systemPrompt(for:)` →
`systemPrompt(for category: AppCategory, dictionary: [String]) -> String?`
(replace, not overload — one composition path, D51 precedent). `.off` →
nil regardless. Otherwise:

```
"/no_think " + levelBody + " " + (toneClause + " ")? + (dictionaryClause + " ")? + closer
```

Dictionary term omitted entirely when nil; closer stays FINAL (D45/D51
strongest-position rule). The clause is spelling guidance only,
subordinate to the level body — worded so it cannot authorize rephrasing
(light's "Change nothing else." remains authoritative; respelling a
listed term is the clause's explicit, narrow license).

**Service plumbing:** `CleanupService.cleanup` adds one line — read
`settings.dictionaryTerms` beside the overrides read, pass to
`systemPrompt(for:dictionary:)`. No signature change (D52 stands).

**Deliverables + LoC ceilings:**
- `DictionaryPrompt.swift` (~45, new): enum above. Pure — Foundation
  only, no SettingsStore access (terms arrive as an argument, D14).
- `SettingsStore.swift` delta (~16): `dictionaryTerms` key + normalization.
- `CleanupLevel.swift` delta (~8): signature + dictionary term.
- `CleanupService.swift` delta (~4): terms read + pass-through.
- `Tests/DictionaryPromptTests.swift` (~75, new, headless): clause
  fixture verbatim; `[]` → nil for both builders; sttPrompt join/order;
  cap boundary (term that fits, term that doesn't, oversized first term
  kept); normalization interplay covered at the store, not re-tested here.
- `Tests/CleanupLevelTests.swift` delta (~35): dictionary weave per level
  × representative categories; EMPTY-DICTIONARY BYTE-IDENTITY — every
  level × category with `dictionary: []` equals the Phase-4 composition
  (the existing D45/D51 fixture literals stay pinned verbatim); `.off` →
  nil with a non-empty dictionary.
- `Tests/CleanupServiceTests.swift` delta (~25): stubbed request body
  carries the clause when the store has terms; empty store → system
  prompt byte-identical to the 4A assertion; terms read at request time.
- `Tests/SettingsStoreTests.swift` delta (~18): round-trip; empty ⇄
  absent; non-string junk filtered; trim/empty-drop; case-insensitive
  dedup keeps first.

**Verify (5A) — all MACHINE, committable now:**
1. `make test` green ×2 (delta ≈ +16 tests, +1 suite vs 149/17; tester
   records exacts).
2. Empty-dictionary byte-identity test present and green (D57 invariant
   is test-enforced).
3. Grep: DictionaryPrompt.swift imports Foundation only; no
   `dictionaryTerms` reference in `warmUp()` or ConnectionProbe.

**Invariants (5A):** zero behavior change for an empty dictionary
(byte-identical prompts); no new network surface; warm-up/probe bodies
untouched; hot-path request shape untouched beyond system-prompt content.

## Sub-phase 5B — Whisper prompt injection (STT stage)

**Injection (D58/D59):** in `TranscriptionService.transcribe(wav:)`,
after the D18 language field:

```swift
let terms = settings.dictionaryTerms
if let prompt = DictionaryPrompt.sttPrompt(terms: terms) {
    body.addField(name: "prompt", value: prompt)
}
```

`prompt` is the OpenAI `/v1/audio/transcriptions` multipart field
(Whisper initial prompt). Empty list → field omitted entirely (D18
omit-when-nil idiom → empty-dictionary request bytes identical to
Phase 4). One log line when `terms` is non-empty and the built prompt
dropped terms to fit the D59 cap (count dropped) — TranscriptionService
gains a `Logger` matching CleanupService's pattern
(subsystem `"com.garisonlotus.LotusScribe"`, category
`"TranscriptionService"`).

**Deliverables + LoC ceilings:**
- `TranscriptionService.swift` delta (~12): logger + terms read + field +
  truncation log.
- `Tests/TranscriptionServiceTests.swift` delta (~40, stubbed
  URLProtocol, existing pattern): body carries the `prompt` field with
  the joined terms; empty store → no `prompt` part anywhere in the body
  bytes; over-budget list → field carries only the first-N terms.

**Verify (5B):**
1. MACHINE: `make test` green ×2 (delta ≈ +3 tests vs 5A gate).
2. MACHINE: the three body-bytes tests above green.
3. BLOCKED-BATCH: confirm the vLLM transcription endpoint accepts and
   honors the multipart `prompt` field — dictate an utterance containing
   a dictionary term with a distinctive spelling (e.g. "Garison"),
   cleanup Off; the raw transcript uses the dictionary spelling. (Also
   closes Q5-2; if vLLM ignores the field, record and re-rule.)
4. BLOCKED-BATCH: same dictation with the dictionary EMPTIED — output
   indistinguishable from Phase-4 behavior.

**Invariants (5B):** empty dictionary → byte-identical multipart body;
20 s STT timeout and error mapping untouched; ConnectionProbe untouched;
cleanup-level setting has no effect on STT injection (D58).

## Sub-phase 5C — Dictionary settings UI

**UI (D60, mirrors 4C/D54):** SettingsForm gains a "Dictionary"
grouped-Form section:
- One row per term, in list order (D56/D59 — order is truncation
  priority): term text + remove button (minus.circle.fill, same row
  vocabulary as App Categories).
- An add row: TextField ("Add term…") + Add button; Add trims, no-ops on
  empty or case-insensitive duplicate (mirrors 4C's duplicate-add guard),
  appends to the draft array, clears the field. No drag-reorder this
  phase (remove/re-add reorders; reorder UI is speculative until real
  friction).
- Draft-buffered (D26): `SettingsDraft` gains
  `@Published var dictionaryTerms: [String] = []`, seeded in `reload()`,
  written in `save()` — sole persist via `draft.save()` (3C
  single-write-path). Dictionary edits never trigger a probe or warm-up
  (R45 wording: D42's trigger is the (llmEndpointURL, llmModel) tuple,
  which dictionary edits never touch).
- Window: `SettingsForm.contentSize` 420×560 → 420×700 — single-site
  change (R40 constant); the grouped Form scrolls internally beyond ~4
  terms.

**Deliverables + LoC ceilings:**
- `SettingsForm.swift` delta (~45): section, term row, add row, size
  constant.
- `SettingsWindowController.swift` delta (~8): draft property +
  reload/save lines.
- `Tests/SettingsWindowControllerTests.swift` delta (~35, headless, R41:
  stub `warmUp:`): terms round-trip through draft save/reload; removing
  a row removes the term on save; Cancel writes nothing (D26); save with
  only a dictionary change fires NO warm-up (tuple unchanged).

**Verify (5C):**
1. MACHINE: `make test` green ×2 (delta ≈ +3 tests vs 5B gate).
2. AT-SCREEN (NOT vLLM-dependent): open Settings; Dictionary section
   renders in the 700 pt window without clipping; add three terms; a
   duplicate add (different case) no-ops; remove one; Save; reopen —
   list persists; edit then Cancel — edits discarded.
3. BLOCKED-BATCH (PLAN verify): populate the dictionary with 2–3
   personal/product terms; dictate each in Mail and in Messages with
   cleanup Standard — every term comes out spelled exactly as written,
   register still per app category (D51 tones intact).
4. BLOCKED-BATCH: dictate a dictionary term with cleanup Light — spelling
   enforced, everything else untouched (light's "Change nothing else."
   holds against the D57 clause).
5. BLOCKED-BATCH (D38 regression): one end-to-end dictation after the
   settings rework — loop untouched.

**Invariants (5C):** store writes only via `draft.save()` (D26/3C);
probe/warm-up triggers unchanged; window remains the only alert surface
(D38); term rows preserve list order.

## Out of scope (explicit)

- Per-term replacement pairs ("misheard → correct" mappings) — this
  phase ships biasing + spelling enforcement, not a substitution table.
- Phonetic hints, per-app or per-category dictionaries.
- Reorder UI (D60), import/export, and any cap on list LENGTH (only the
  STT prompt is capped, D59 — the cleanup clause carries the full list).
- History / "undo cleanup" (D41 — still deferred to the history feature).
