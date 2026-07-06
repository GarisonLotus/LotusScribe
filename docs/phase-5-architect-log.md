# Architect log — LotusScribe (Phase 5)

> Locked decisions + open questions for Phase 5. Carry pointer: D1–D11
> phase-0, D12–D28 phase-1, D29–D35 phase-2 (D29a rescinded by D34),
> D36–D49 phase-3, D50–D55 phase-4; all remain binding. Numbering
> continues at D56. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D56 | 2026-07-05 | Dictionary storage: SettingsStore key `dictionaryTerms` as a UserDefaults string ARRAY `[String]` (list, not D53's dict — terms have no values, and ORDER is user-meaningful: first terms survive the D59 STT cap). Get normalizes: String values only, whitespace-trimmed, empties dropped, case-insensitive dedup keeping first occurrence; set writes the whole array; empty ⇄ absent key (D53 idiom). Normalization at READ time (R39 posture) so a raw `defaults write` of junk can never reach prompt composition un-normalized | An ordered array is the minimal shape for a prioritized list; read-time normalization gives both consuming services one canonical input regardless of write path; case-insensitive dedup because Whisper biasing and the cleanup clause both treat "garison"/"Garison" as one term | 5A |
| D57 | 2026-07-05 | Cleanup weave (amends D51's rule shape, not its content): `systemPrompt(for:)` → `systemPrompt(for category: AppCategory, dictionary: [String])` (replace, not overload — one composition path, D51 precedent); `.off` → nil regardless. Rule: `"/no_think " + levelBody + " " + (toneClause + " ")? + (dictionaryClause + " ")? + closer`, dictionary term omitted entirely when nil, closer stays FINAL. Clause fixture verbatim (uncapped, full list): `"These terms are spelled exactly as written: " + terms.joined(separator: ", ") + "."` — spelling guidance only, subordinate to the level body (its narrow license is respelling listed terms; it may never authorize rephrasing — light's "Change nothing else." stays authoritative). NEUTRALITY INVARIANT EXTENDED: EMPTY dictionary composes byte-identical to Phase-4 output for every category × level — byte-identity test-enforced (realized in 5A as: D45/D51 fixture literals pinned verbatim + splice test with `dictionary: []` per level × category — accepted at 5A gate as equivalent coverage; the invariant is the contract, the test shape incidental). Builder lives in new pure `DictionaryPrompt.swift` (Foundation-only enum, terms as argument — D14; shared with 5B's STT builder, the one thing that justifies a shared type) | Same segment-composition move that made D51 fixture-testable; empty-dict byte-identity makes the dictionary provably zero-risk for every user who never touches it — Phase-4 behavior is the floor, exactly as Phase-3 was D51's floor; clause-after-tone keeps the closer's output-only instruction in the strongest position | 5A |
| D58 | 2026-07-05 | Whisper injection: `TranscriptionService.transcribe(wav:)` adds the OpenAI `/v1/audio/transcriptions` multipart field `prompt` via `MultipartBody.addField(name: "prompt", value:)`, after the D18 language field; value = `DictionaryPrompt.sttPrompt(terms:)` = terms joined ", " (capped per D59); EMPTY list → field omitted entirely (D18 omit-when-nil idiom → empty-dictionary request bytes identical to Phase 4). NOT gated by cleanup level or effective-enabled — STT biasing applies whenever terms exist, including cleanup `.off` (it is an STT-stage feature; the cleanup clause's `.off` gating is automatic via systemPrompt → nil). ConnectionProbe.testSTT untouched (builds its own multipart, D36 — probes stay content-indifferent, D42/D44 posture) | The transcript should be right even for users who run cleanup Off — biasing costs nothing and PLAN names both stages independently; omit-when-empty reuses the proven D18 shape and makes the neutrality floor bytes-provable; probes/warm-ups never carry content per the D42 rationale (one weird server behavior must never cost more than the feature that risked it) | 5B |
| D59 | 2026-07-05 | STT prompt cap: Whisper truncates the initial prompt to its LAST ~224 tokens — an oversized prompt silently drops the user's FIRST (highest-priority) terms server-side. So cap app-side where we control which terms survive: `DictionaryPrompt.sttPromptCharacterBudget = 600` chars (~224 tokens × ~3 chars/token for proper nouns, conservative — no tokenizer in-app, D7); include terms in list order while the joined result fits; first term always included even if oversized (degrade to something, never nil). Cleanup clause UNCAPPED — chat context is ample, the full list always reaches the LLM stage. Builder stays pure (no logging); TranscriptionService logs dropped-term count when truncation occurred | First-N-in-order keeps truncation deterministic, testable, and under the user's control (list order = priority, D56); a character budget avoids shipping a tokenizer for a safety margin; capping only the stage that has a hard limit is the minimal rule | 5A (builder) / 5B (log) |
| D60 | 2026-07-05 | Dictionary UI is IN-PHASE as sub-phase 5C (last slice, D54 slicing precedent): "Dictionary" grouped-Form section in SettingsForm — one row per term IN LIST ORDER (order = D59 priority; Text + remove button, App Categories row vocabulary), add row = TextField + Add button (trim; no-op on empty or case-insensitive duplicate, mirroring 4C's duplicate-add guard; append + clear field). NO drag-reorder this phase (remove/re-add reorders; reorder UI is speculative until real friction). Draft-buffered per D26: `SettingsDraft.dictionaryTerms: [String]`, seeded in reload(), persisted only via draft.save() (3C single-write-path). Dictionary edits never trigger a probe or warm-up (R45 wording — D42's trigger is the (llmEndpointURL, llmModel) tuple, untouched). `SettingsForm.contentSize` 420×560 → 420×700, single R40 site; Form scrolls internally beyond ~4 terms | PLAN item 1 makes "user-managed" a Phase-5 deliverable, so the UI writer ships in-phase (D54 grounds); a plain text list needs no picker — TextField+Add is the cheapest honest editor; slicing UI last keeps 5A/5B committable during the blocked window | 5C |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| Q5-1 | 2026-07-05 | Clause/prompt EFFECTIVENESS is unproven (vLLM down — no empirical probe possible, unlike D45): does the D57 clause reliably enforce spellings on Qwen3.6, and does comma-joined vocab bias whisper-large-v3 well? Fixtures are locked as the build contract; batch-time tuning (wording only, composition rule intact) is an allowed D57 amendment if the BLOCKED-BATCH verifies show misses | open (batch time) | Q4-2 (vLLM) |
| Q5-2 | 2026-07-05 | Does vLLM's /v1/audio/transcriptions honor the multipart `prompt` field (initial-prompt biasing)? Standard OpenAI field, worst case ignored server-side (harmless — cleanup stage still enforces). Non-blocking for build; 5B BLOCKED-BATCH verify 3 closes it | open | Q4-2 (vLLM) |

(status: open / answered / deferred / closed-as-moot)

## Notes

2026-07-05: docs/phase-5-spec.md authored (D56–D60). Slicing: 5A = pure
core (storage + DictionaryPrompt builders + cleanup weave — all MACHINE,
byte-identity floor test-enforced per D57); 5B = TranscriptionService
`prompt` field (MACHINE body-bytes tests; live biasing BLOCKED-BATCH);
5C = Dictionary settings UI (MACHINE + AT-SCREEN; PLAN spelled-correctly
verify BLOCKED-BATCH). Code-verified against the live tree:
TranscriptionService.transcribe builds the multipart via
MultipartBody.addField (D18 language field is the omit-when-nil model);
CleanupLevel.systemPrompt(for:) has exactly one production call site
(CleanupService.cleanup line ~85), so the D57 signature change touches
one service + fixtures; ConnectionProbe builds its own multipart —
untouched; SettingsDraft/save() single-write-path confirmed for the 5C
plumbing. Expected gates: 5A ≈165/18, 5B ≈168/18, 5C ≈171/18 (tester
records exacts). D-rows touched, not amended: D14, D18, D25/R39, D26,
D36, D39/D45, D40, D42, D43, D52, D53 (pattern), D54 (pattern), R40,
R41, R45. D51 amended by D57 (rule shape + invariant extension only —
Phase-4 fixtures stay pinned verbatim).

2026-07-05: PHASE 5 BOOTSTRAP. Phase-3 and Phase-4 close gates both
remain OPEN (vLLM down, Q4-2). Phase 5 proceeds by explicit user
directive: machine-verifiable slices land now; every vLLM-dependent or
at-screen verify is recorded by the ORCHESTRATOR in when-vllm-is-back.md
(project root) instead of blocking. Spec must mark each verify item
MACHINE / AT-SCREEN (no vLLM) / BLOCKED-BATCH (vLLM).

2026-07-05: 5A NON-OBJECTION (architect, staged-diff shape gate).
Verified against D56/D57/D59 + spec §5A on the staged public surfaces:
one composition path (systemPrompt(for:dictionary:) REPLACES — no
overload survives); DictionaryPrompt is a pure Foundation-only enum,
terms-as-argument (D14), both builders nil-for-[]; composition rule and
clause fixture match D57 verbatim, closer FINAL, .off → nil regardless;
sttPrompt cap = first-N-in-order, 600, first-term-always (D59);
dictionaryTerms storage matches D56 exactly (read-normalize: String-only,
trim, drop-empty, case-insensitive dedup keep-first; empty ⇄ absent);
CleanupService reads fresh at request time, D52 signature intact.
Amendment: D57 row updated to record the accepted byte-identity
realization (pinned literals + []-splice, not one named test). R47 needs
no amendment — it restates D56's read-canonical design. R46 (600 chars
may exceed 224 tokens for non-Latin terms): no D59 change — the ~3
chars/token assumption is stated in the row; fold a non-Latin-terms
sanity check into the Q5-2 BLOCKED-BATCH verify. No objections; 5A
shape conforms.

2026-07-05: 5B NON-OBJECTION (architect, staged-diff shape gate).
Verified against D58/D59 + spec §5B on the staged TranscriptionService
diff: `prompt` field added after the D18 language block, before the
file part; injection gated only on non-empty normalized terms — no
cleanup-level / effective-enabled check (D58); builder stays pure, the
service owns the truncation log (Logger subsystem/category match the
CleanupService pattern); empty list → nil → field absent (D18 idiom).
D59 CONTRACT PIN (R48): the service-side dropped-count recovery assumes
sttPrompt returns EXACTLY a first-N ", "-joined strict prefix of terms;
any future change to the cap rule (separator, reordering, per-term
elision) must also change the recovery or return the count explicitly.
R49: no pre-5C amendment — carry as a gate check item at the 5C gate
(button row's own .disabled is the sole guard). No objections.
