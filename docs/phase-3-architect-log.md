# Architect log — LotusScribe (Phase 3)

> Locked decisions + open questions for Phase 3. D1–D11 live in
> docs/phase-0-architect-log.md, D12–D28 in phase-1, D29–D35 in phase-2;
> all remain binding. Numbering continues at D36. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D36 | 2026-07-05 | Connection-test probe = real round-trip: multipart POST of a ~0.2 s silent WAV (WavEncoder, 16 kHz mono zeros) + DRAFTED model to the DRAFTED STT endpoint URL, same request shape as TranscriptionService; success = HTTP 200 + decodable `{"text": …}`, content ignored (D28: silence may hallucinate — irrelevant); 10 s timeout; probe reads drafts only, never SettingsStore; empty drafted STT URL → skip probe, save+close unchanged (clearing settings must not be blocked by a guaranteed-fail test); un-parseable URL → immediate failure, no network. 3A probes STT only; per-endpoint generalization lands with 3B's LLM setting | The user's "settings are accurate" is only proven by the real request (URL path + model + reachability); GET/HEAD validates none of that. 10 s: watched interaction, half the dictation timeout, ample for a 0.2 s clip on warm vLLM | 3A |
| D37 | 2026-07-05 | Save flow (amends D26's "Save writes and closes" — the write-then-close step is now probe-gated; all other D26 semantics stand): Save → in-flight (fields+buttons disabled, spinner "Testing connection…"); success → `draft.save()` immediately + green checkmark, auto-close ~2 s later; failure → NSAlert sheet ("There's a problem with the connection." + brief reason), Save Anyway = `draft.save()` then close — failure-path save DOES persist (user clicked Save), Try Again = back to editing, drafts intact, nothing written (sheet labels renamed from Close Anyway/Cancel per user directive 2026-07-05; behavior unchanged); titlebar close / Esc mid-test cancels the probe and writes nothing; reopen resets probe state to idle | Persist-at-success (not at window close) means a force-close during the 2 s flash cannot lose the save; failure-path persistence honors the explicit Save click while the sheet keeps the user informed; Cancel preserves D26 buffered editing exactly | 3A |
| D38 | 2026-07-05 | Alert-policy scope annotation: the cross-cutting "never alerts" rule (phase-1/2 specs) governs the AUTONOMOUS dictation loop — hotkey→record→transcribe→insert must never interrupt the user with UI. A modal sheet in the settings window, in direct response to the user's own Save click, is outside that scope and was explicitly user-requested. Restated rule: no alert may ever originate from the dictation loop; settings-window direct-response dialogs are permitted | The policy's purpose is protecting flow during dictation, not banning dialogs the user asked for in a window they are actively operating; scoping it prevents both future misreadings | 3A |
| D39 | 2026-07-05 | CleanupService shape: mirrors TranscriptionService (init(settings:session:), reads SettingsStore); JSON POST to llmEndpointURL (full URL) with body exactly {model, messages:[system, user(transcript)], temperature: 0} — strictly OpenAI-standard on the hot path; timeoutInterval 4 (PLAN item 4); success = 200 + decodable choices[0].message.content, trimmed; trimmed-empty output → throw (raw fallback — never insert emptiness for spoken words); error enum mirrors TranscriptionError | Symmetry with the proven STT client keeps the surface learnable and the tests pattern-identical; temperature 0 = deterministic cleanup; strict-standard body works on vLLM, Ollama, and any /v1/chat/completions server | 3B |
| D40 | 2026-07-05 | Cleanup levels: `CleanupLevel: String, CaseIterable` = off/light/standard; new SettingsStore key `cleanupLevel` (string, same pattern as D9 keys); nil/unrecognized resolves to `.standard`; prompts per RESEARCH.md §4 fixed verbatim in the spec (test fixtures). Effective-enabled = llmEndpointURL AND llmModel set (D25 empty→nil) AND level ≠ off; otherwise transcript inserts untouched, no request, no error | User who saved an LLM endpoint wants cleanup — standard is the right unset default; empty-URL-means-off reuses the D25/D36 empty-skip idiom instead of a second on/off switch | 3B |
| D41 | 2026-07-05 | History / "undo cleanup" mirror (PLAN §Phase 3 item 2): DEFERRED to the Phase-5+ history feature. 3B ships the raw-transcript fallback only; no per-utterance raw storage. PLAN.md annotation owed (orchestrator applies) | Undo needs a history surface to live in (menu/window) — building storage now with no UI is speculative (CLAUDE.md §2); the fallback already guarantees words are never lost, which is the safety half of the feature | 3B |
| D42 | 2026-07-05 | Warm-up: fire-and-forget `warmUp()` — body {model, messages:[user("ok")], max_tokens: 1, keep_alive: -1}, timeout 30 s, log-only, never touches pill or blocks anything; non-2xx → retry ONCE without keep_alive (strict OpenAI-compat validators may 400 on unknown fields; vLLM must still warm). No keep_alive on cleanup or probe requests. Triggers: app launch (AppDelegate, inside the existing XCTestSessionIdentifier guard — tests never fire network warm-ups) and, from 3C, any save that changed llmEndpointURL/llmModel while effective-enabled | Defeats Ollama's 3–10 s idle unload (RESEARCH §4) while degrading gracefully on servers that reject the field; keeping non-standard fields off the hot path means one weird server behavior can only ever cost the warm-up, not a dictation | 3B |
| D43 | 2026-07-05 | Pipeline semantics (extends D23/D38 across the cleanup hop): any cleanup failure (4 s timeout, HTTP/transport, undecodable/empty output) → insert RAW transcript, log, pill flashes `.success` — the words landed, that is the success; `.error` stays transcription-failure-only; no new pill state (cleanup runs under `.processing`, D31 untouched); generation re-checked after the cleanup await — stale → drop, no insert, no pill touch; no alert ever (D38) | "Never eat the user's words" is the contract; a cleanup miss with a successful raw insert is not an error from the user's seat; the second generation check closes the widened stale window the extra hop creates | 3B |
| D44 | 2026-07-05 | Settings/probe generalization (per R37 plan): `ConnectionProbe.testLLM(endpoint:model:)` = minimal chat completion ({model, messages:[user("ping")], max_tokens: 1}, no keep_alive, 10 s, success = 200 + decodable choices[0].message); Save probes each endpoint whose DRAFTED URL is non-empty — level-independent, one rule, mirrors D36's empty-skip — sequentially STT then LLM, stop at first failure; sheet reason prefixed "Speech to Text: …" / "Cleanup LLM: …". Folds R36 (save() cancels stale probeTask/autoCloseTask) and R37 (SettingsForm extracted to SettingsForm.swift + level Picker) | Probing any URL the user typed validates it before it can break a dictation, even while level is Off (the URL outlives the level); sequential-stop keeps one sheet, one reason; R36/R37 land here because 3B/3C is the surface's planned rework moment | 3C |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| — | carried | R4 (phase 0): close by exercising a Keychain read under the 5RC66Q82V9 identity. Note: 3A's probe hits the no-key D13 endpoint, so it does not exercise this — still owed at first authed-endpoint work | open | any authed-endpoint work |

## Notes

2026-07-05: PLACEMENT RULING. The Save connection test is user-directed
scope arriving between phases. Ruled: first sub-phase (3A) of Phase 3, not
a standalone mini-phase. Grounds: Phase 3 introduces the LLM endpoint
setting and PLAN.md Phase 7.3 already plans a connection-test button — one
probe surface serves both endpoints when 3B lands; integer `phase-N` doc
naming (CLAUDE.md §5) stays clean. Docs consequence: phase-3 docs set
created now; phase-3-spec.md is authored incrementally (§3A now, §3B+ when
LLM-cleanup work starts). PLAN.md paper trail: architect cannot edit
PLAN.md — orchestrator to apply the annotation under §Phase 3 (text in the
architect's return): 3A user-directed addition, pulled forward from Phase
7.3's connection-test button, spec in docs/phase-3-spec.md.

2026-07-05: docs/phase-3-spec.md §3A authored (D36–D38). Single sub-phase —
feature is small (~140 source / ~95 test LoC ceilings); slicing further
would gate nothing meaningful. Injection seam: probe passed to the
controller as a closure so Save-path logic tests headlessly (D14);
ConnectionProbe itself tested via the established StubURLProtocol pattern
(serialized suite, global handler — same concurrency surface as
TranscriptionServiceTests, carried in tester baselines).

2026-07-05: 3A SHAPE NON-OBJECTION. All four engineer proceed-on-lean items
accepted at shape level — each is the minimal realization of spec'd
behavior, not new surface: (a) `.onExitCommand` is the only route for the
spec's own Esc-mid-test requirement once Cancel is disabled; (b) `ProbeState:
ObservableObject` is forced by NSWindowController being unable to publish;
(c) `private(set) probeTask` is the D14 headless-test seam; (d) dedicated
ProbeStubURLProtocol isolates the global-handler stub from parallel suites.
Recorded as a 5-line execution-notes block in phase-3-spec.md §3A; no D-number
warranted. ConnectionProbe placement/API confirmed against D36: struct in
Sources/, reads only its arguments (never SettingsStore), injectable
URLSession, signature matches the spec deliverable verbatim; the shared
SettingsValidation gate for the no-network invalid-URL path is the right
reuse. R37 disposition: ACCEPT split-at-3B — 3B's per-endpoint
generalization reworks this controller anyway; splitting now churns a
just-reviewed surface for zero behavior. R36 stale-flash: cosmetic, no
ruling needed.

2026-07-05: phase-3-spec.md §3B/§3C authored (D39–D44). Slicing: 3B =
CleanupLevel + CleanupService + DictationController pipeline + launch
warm-up (headless-heavy per D14: prompts/request/response/isEnabled/warm-up
retry all stubbed; live loop + kill-server HUMAN-AT-SCREEN); 3C = level
picker + testLLM per-endpoint probe + endpoint-change warm-up, folding R36
(save() cancels stale tasks) and R37 (SettingsForm.swift extraction).
Code-verified: SettingsStore already carries llmEndpointURL/llmModel and
SettingsForm already renders the Cleanup LLM fields — 3B adds only the
cleanupLevel key. HUMAN GATE DEPENDENCY: user must supply their LLM
endpoint URL + model (vLLM infra) at 3B/3C verify time; spec hardcodes
none. PLAN.md paper trail (orchestrator applies, architect cannot edit):
annotate §Phase 3 item 2 — history/"undo cleanup" mirror deferred to the
Phase-5+ history feature per D41; 3B ships raw-transcript fallback only.
