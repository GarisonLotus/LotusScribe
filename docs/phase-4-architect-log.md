# Architect log — LotusScribe (Phase 4)

> Locked decisions + open questions for Phase 4. Carry pointer: D1–D11 in
> docs/phase-0-architect-log.md, D12–D28 in phase-1, D29–D35 in phase-2
> (D29a rescinded by D34), D36–D49 in phase-3; all remain binding.
> Numbering continues at D50. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D50 | 2026-07-05 | App taxonomy: `AppCategory: String, CaseIterable` = email / workMessaging / personalMessaging / code / other (Wispr taxonomy per PLAN §Phase 4). Pure Foundation-only type in AppCategory.swift: displayName, toneClause, built-in bundle-ID map (exact IDs listed in spec §4A), `category(forBundleID:overrides:)` taking overrides as an ARGUMENT (no SettingsStore access — headless per D14). Resolution: nil id → .other; override (valid rawValue only) beats built-in; unmatched → .other. EXACT bundle-ID match only — no prefix/wildcard (com.jetbrains.* etc. left to overrides); browsers unmapped → .other (D55) | Mirrors CleanupLevel's proven shape (pure enum + resolve, D40); exact match keeps resolution a dictionary lookup with zero rule-ordering ambiguity; the override map is the extension mechanism, so built-ins only need to be representative, not exhaustive | 4A |
| D51 | 2026-07-05 | Prompt composition (amends D40/D45 fixture shape, not content): `CleanupLevel.systemPrompt` → `systemPrompt(for: AppCategory)` (replace, not overload — one composition path); `.off` → nil for every category. Rule: `"/no_think " + levelBody + " " + (toneClause + " ")? + closer`, tone term omitted entirely when nil; closer = "Output only the cleaned text, with no commentary." stays FINAL. NEUTRALITY INVARIANT: `.other` composes byte-identical to the D45 fixtures — enforced by a dedicated byte-identity test, not convention. Tone fixtures verbatim in spec §4A; tone weaves into BOTH light and standard, but tone text is register/formatting guidance only, subordinate to the level body (may never instruct rephrasing — light's "Change nothing else." stays authoritative). Tone text NOT user-editable this phase | Segment composition makes "woven into the cleanup prompt" (PLAN item 2) a pure, fixture-testable function; tone-before-closer keeps the output-only instruction in the strongest (final) position; byte-identity for .other means app-awareness is provably zero-risk for every unrecognized app — Phase-3 behavior is the floor | 4A |
| D52 | 2026-07-05 | Capture + plumbing: frontmost bundle ID captured at KEY-DOWN in `DictationController.startRecording()` via direct `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` — no DI seam (3B no-seam ruling; adapter side of D14, D49 posture: under tests it is the test runner → .other → byte-identical prompt). Stored in an instance var, snapshotted into a local beside `capturedGeneration` in stopRecording so an in-flight Task carries its own dictation's value (D23 discipline). Controller passes the RAW bundle ID; `cleanup(transcript:frontmostBundleID:)` resolves category at request time using `settings.appCategoryOverrides` (fresh read, same live-read posture as isEnabled/D40). Parameter is explicit with NO default value; 4A passes literal nil at the sole production call site, 4B replaces it with the captured var. Rejected: a separate ContextProvider type (PLAN's architecture box) — the capture is one line, resolution is one pure function; a wrapper type is single-use abstraction (CLAUDE.md §2). PLAN divergence noted, no annotation owed (component realized, name not) | Key-down is when the user's intent is bound to the target app (PLAN item 1 verbatim); resolving in the service puts the whole bundleID→prompt chain behind the service's existing headless test surface (stub URLProtocol asserts the composed prompt end-to-end); no-default-param makes a forgotten pass-through a compile error instead of a silent .other | 4A+4B |
| D53 | 2026-07-05 | Override storage: SettingsStore key `appCategoryOverrides` as a UserDefaults DICTIONARY `[String: String]` (bundleID → AppCategory rawValue); get filters to String values, set writes the whole dict; empty ⇄ absent. Invalid category rawValue in an override is IGNORED at resolution — falls through to built-in map (safe-resolution mirror of D40's resolve; a stale/corrupt override can never break dictation). Overrides are draft-buffered per D26 and written only via `draft.save()` (3C single-write-path); an overrides-only save fires NO probe and NO warm-up (D42's (llmEndpointURL, llmModel) tuple compare unchanged) | A native defaults dictionary is the minimal shape for a keyed map — no JSON blob to hand-parse, no schema versioning for a flat string→string map; ignore-and-fall-through beats throwing or .other-forcing because the built-in map is the better guess when an override is garbage | 4A (storage) / 4C (UI) |
| D54 | 2026-07-05 | Override UI is IN-PHASE, as sub-phase 4C (last slice): "App Categories" grouped-Form section — one row per override (bundle-ID text + category Picker over displayNames + remove), "Add app…" menu of running `.regular` apps (localizedName + bundle ID) seeding the row with the app's current effective category; `SettingsForm.contentSize` 420×390 → 420×560 (single site, R40 constant); list scrolls internally. Rejected: defaults-write-only override (fails PLAN's "user-overridable" — that is developer-overridable); full /Applications browser picker (scope); deferring UI to Phase 7 settings polish (leaves 4A's storage without any user-facing writer for multiple phases) | PLAN item 1 makes "user-overridable" a Phase-4 deliverable, so a UI writer belongs in-phase; running-apps enumeration is the cheapest honest picker (the app you want to override is almost always running — it is where you just dictated); slicing it LAST keeps 4A/4B committable during the blocked window even if 4C's HUMAN checks queue up | 4C |
| D55 | 2026-07-05 | Per-website browser detection (AX URL extraction) DEFERRED to v2, per PLAN §Phase 4 item 3 + §Deferred. Interim posture: browsers ship unmapped → .other (neutral prompt); a user who lives in one web app may override the browser's bundle wholesale via D53/D54 — documented, not a workaround discovered later. Reopen trigger: v2 browser-context work | PLAN rules the deferral explicitly; mapping browsers to any single category would be wrong more often than right (a browser is every category); .other = today's exact behavior, the safe floor | phase scope |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| Q4-1 | 2026-07-05 | Built-in bundle-ID map contents (spec §4A): does the user want apps added/moved before the human batch (e.g. Discord workMessaging vs personalMessaging; their actual mail/chat/editor set)? Defaults are representative, overrides cover drift — non-blocking for 4A/4B build | open (user input at batch time) | user availability |
| Q4-2 | 2026-07-05 | vLLM (or substitute Whisper endpoint) restoration — gates the entire BLOCKED-BATCH queue: Phase-3 items (3B/D45 re-verify, 3C 2–5, 3D 2–5, D49) + Phase-4 items (4B verify 3–4, 4C verify 3–4) | open | user infra |

## Notes

2026-07-05: PHASE 4 BOOTSTRAP. Phase 3 close gate remains OPEN — every
Phase-3 HUMAN-AT-SCREEN verify is blocked on vLLM access (phase-3 handoff
§3); the architect has NOT declared Phase 3 complete. Phase 4 build
proceeds by explicit user directive: machine-verifiable slices (4A fully,
4B/4C code+suite legs) land now; all dictation-dependent verifies are
marked HUMAN-AT-SCREEN (BLOCKED-BATCH) and join the Phase-3 queue for one
batched at-screen session when a live STT endpoint returns. Batch order
suggestion for that session: Phase-3 items first (they gate a phase
close), then 4B/4C.

2026-07-05: SLICING RULING (D14 split). 4A = everything pure/headless
(taxonomy, map, override storage, prompt composition, service plumbing
with nil at the call site) — zero behavior change by construction
(byte-identity test), committable and fully verifiable during the blocked
window. 4B = the one-line NSWorkspace adapter + controller plumbing — no
new tests owed (D49 precedent: adapter side, no seam), capture-log verify
is at-screen but NOT vLLM-dependent; only the tone-effect verifies are
BLOCKED-BATCH. 4C = settings UI, last, separable. Rejected: single
sub-phase (buries the pure core's clean machine gate under UI churn);
UI-before-adapter (storage has a defaults-write escape hatch for testing
4B live, UI gates nothing for 4B).

2026-07-05: PLAN naming divergence (recorded, no annotation owed):
PLAN's architecture box names a `ContextProvider` component; Phase 4
realizes it as the pure `AppCategory` type + one capture line in
DictationController (D52 rejection of a wrapper type). Function
delivered, box name not literal.

2026-07-05: D45 interaction checked: /no_think prefix is position 0 of
the composed prompt under D51's rule for every category — the Qwen3 soft
switch survives tone weaving. Warm-up ("ok") and probe ("ping") bodies
untouched (content-indifferent, max_tokens 1) — category never touches
them.
