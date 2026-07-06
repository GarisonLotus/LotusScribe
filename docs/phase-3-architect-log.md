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
| D39 | 2026-07-05 | CleanupService shape: mirrors TranscriptionService (init(settings:session:), reads SettingsStore); JSON POST to llmEndpointURL (full URL) with body exactly {model, messages:[system, user(transcript)], temperature: 0} — strictly OpenAI-standard on the hot path; timeoutInterval 4 (PLAN item 4); success = 200 + decodable choices[0].message.content, trimmed; trimmed-empty output → throw (raw fallback — never insert emptiness for spoken words); error enum mirrors TranscriptionError. AMENDED 2026-07-05 by D45: timeoutInterval 4 → 8 (empirical; strict-OpenAI body unchanged) | Symmetry with the proven STT client keeps the surface learnable and the tests pattern-identical; temperature 0 = deterministic cleanup; strict-standard body works on vLLM, Ollama, and any /v1/chat/completions server | 3B |
| D40 | 2026-07-05 | Cleanup levels: `CleanupLevel: String, CaseIterable` = off/light/standard; new SettingsStore key `cleanupLevel` (string, same pattern as D9 keys); nil/unrecognized resolves to `.standard`; prompts per RESEARCH.md §4 fixed verbatim in the spec (test fixtures). AMENDED 2026-07-05 by D45: both system prompts gain the literal `/no_think ` prefix (fixtures updated in spec §3B). Effective-enabled = llmEndpointURL AND llmModel set (D25 empty→nil) AND level ≠ off; otherwise transcript inserts untouched, no request, no error | User who saved an LLM endpoint wants cleanup — standard is the right unset default; empty-URL-means-off reuses the D25/D36 empty-skip idiom instead of a second on/off switch | 3B |
| D41 | 2026-07-05 | History / "undo cleanup" mirror (PLAN §Phase 3 item 2): DEFERRED to the Phase-5+ history feature. 3B ships the raw-transcript fallback only; no per-utterance raw storage. PLAN.md annotation owed (orchestrator applies) | Undo needs a history surface to live in (menu/window) — building storage now with no UI is speculative (CLAUDE.md §2); the fallback already guarantees words are never lost, which is the safety half of the feature | 3B |
| D42 | 2026-07-05 | Warm-up: fire-and-forget `warmUp()` — body {model, messages:[user("ok")], max_tokens: 1, keep_alive: -1}, timeout 30 s, log-only, never touches pill or blocks anything; non-2xx → retry ONCE without keep_alive (strict OpenAI-compat validators may 400 on unknown fields; vLLM must still warm). AMENDED 2026-07-05 (3B non-objection): retry trigger is HTTP non-2xx ONLY — transport failures (timeout/refused) log and stop, no retry. No keep_alive on cleanup or probe requests. Triggers: app launch (AppDelegate, inside the existing XCTestSessionIdentifier guard — tests never fire network warm-ups) and, from 3C, any save that changed llmEndpointURL/llmModel while effective-enabled | Defeats Ollama's 3–10 s idle unload (RESEARCH §4) while degrading gracefully on servers that reject the field; keeping non-standard fields off the hot path means one weird server behavior can only ever cost the warm-up, not a dictation | 3B |
| D43 | 2026-07-05 | Pipeline semantics (extends D23/D38 across the cleanup hop): any cleanup failure (4 s timeout, HTTP/transport, undecodable/empty output) → insert RAW transcript, log, pill flashes `.success` — the words landed, that is the success; `.error` stays transcription-failure-only; no new pill state (cleanup runs under `.processing`, D31 untouched); generation re-checked after the cleanup await — stale → drop, no insert, no pill touch; no alert ever (D38) | "Never eat the user's words" is the contract; a cleanup miss with a successful raw insert is not an error from the user's seat; the second generation check closes the widened stale window the extra hop creates | 3B |
| D45 | 2026-07-05 | Reasoning-model compatibility (amends D39 timeout + D40 prompt fixtures; empirical — orchestrator probes 2026-07-05 vs user's vLLM, Qwen/Qwen3.6-35B-A3B-FP8): (1) cleanup `timeoutInterval` 4 → 8 s; (2) both cleanup system prompts (light + standard) gain the literal prefix `/no_think ` — Qwen3-family soft switch that suppresses the hidden reasoning block; inert prompt text on any other OpenAI-compatible backend. Hot-path body stays strictly OpenAI-standard per D39 — the vLLM-only `chat_template_kwargs: {enable_thinking: false}` body field REJECTED. Scope: cleanup requests only; warm-up ("ok") and probe ("ping") bodies unchanged — both are max_tokens 1, content-indifferent | In-app, every real dictation's cleanup timed out at 4 s (reasoning chat latency 4.7–11.8 s; Whisper answers 0.5 s on the same box — not model swapping), so the D43 raw fallback fired 100% and the user never got cleanup. With `/no_think`: 3.4 s consistently, correct output. 8 s = 3.4 s typical + headroom; the 11.8 s outlier still falls back to raw; user accepts a longer processing wait over missing cleanup. Prompt prefix over body field keeps one request shape working everywhere (D39's rationale) | 3B |
| D44 | 2026-07-05 | Settings/probe generalization (per R37 plan): `ConnectionProbe.testLLM(endpoint:model:)` = minimal chat completion ({model, messages:[user("ping")], max_tokens: 1}, no keep_alive, 10 s, success = 200 + decodable choices[0].message); Save probes each endpoint whose DRAFTED URL is non-empty — level-independent, one rule, mirrors D36's empty-skip — sequentially STT then LLM, stop at first failure; sheet reason prefixed "Speech to Text: …" / "Cleanup LLM: …". Folds R36 (save() cancels stale probeTask/autoCloseTask) and R37 (SettingsForm extracted to SettingsForm.swift + level Picker) | Probing any URL the user typed validates it before it can break a dictation, even while level is Off (the URL outlives the level); sequential-stop keeps one sheet, one reason; R36/R37 land here because 3B/3C is the surface's planned rework moment | 3C |
| D46 | 2026-07-05 | Two-stage pill state shape (user directive 2026-07-05): PillState gains ONE case `stagedSuccess(cleanup: CleanupStage)` with `CleanupStage = pending/done/missed`; `.success` retained verbatim for the STT-only path (D40 not effective-enabled → today's single check, unchanged). The associated value is a display instruction, not dictation state — pill holds no pipeline knowledge, DictationController stays sole driver (§2C invariant). Flash classification becomes a pure headless property `PillState.flashDuration: TimeInterval?` (nil = sticky, incl. `.stagedSuccess(.pending)`); PillController.update guards on it instead of the hardcoded success/error check. Rejected: three top-level cases (case-count bloat for one visual family), bool-pair payload (unrepresentable states) | One case + payload is the minimal shape that keeps `.success` untouched and makes the flash/sticky decision a pure testable mapping (D14) instead of controller branching | 3D |
| D47 | 2026-07-05 | Two-stage sequencing, ruled against DictationController's real flow (insertion happens AFTER cleanup — the cleaned text is what inserts, so stage 1 must display pre-insert): transcript accepted (post generation + non-empty guards) → cleanup disabled: insert + `.success` unchanged; enabled: `.stagedSuccess(.pending)` (check 1 green + slot 2 pending) BEFORE the cleanup await → cleanup returns (D43 do/catch, raw fallback) → second generation guard unchanged (stale → drop, no insert, no pill touch; no orphaned `.pending` — the newer generation's `show(.warming)` already repainted) → insert → `.stagedSuccess(.done)` (cleaned) or `.stagedSuccess(.missed)` (raw fallback, amber). `.pending` carries no timer of its own — CleanupService's 8 s timeout (D45) bounds it. D23/D43 intact: `.error` stays transcription-failure-only; a cleanup miss is never `.error` — amber-over-green, the words landed. AMENDS D43's pill face only ("flashes `.success` on miss" → flashes `.stagedSuccess(.missed)`); D43 fallback/logging/no-alert semantics untouched | Stage 1 = STT proof, and the only truthful pre-insert moment for it is transcript-accepted; the visible pending wait is the information during the cleanup hop; keeping both generation guards exactly where they are adds zero new stale surface | 3D |
| D48 | 2026-07-05 | Two-stage visuals + flash timing: `.stagedSuccess` renders HStack(spacing 16), centered in the existing 260×52 content, both slots `.title2` SF Symbols — slot 1 `checkmark.circle.fill` green (same symbol as `.success`); slot 2 pending = small ProgressView (reuses `.processing` vocabulary), done = `checkmark.circle.fill` green, missed = `exclamationmark.triangle.fill` systemOrange (triangle+amber = warning, distinct from `.error`'s red circle). No text labels. Flash: staged terminals hide after NEW `PillMetrics.stagedFlashDuration = 1.2 s` (two symbols + amber semantics need more read time); D31's 0.8 s stands untouched for `.success`/`.error`; both literals live only in PillMetrics (D31 single-site) | Reuses every existing visual token (green check, small spinner, exclamation) so the two-stage read is instant; 1.2 s is the smallest bump that makes a two-symbol + warning read comfortable without making the pill feel sticky | 3D |
| D49 | 2026-07-05 | R31 pull-forward APPROVED (amends the phase-1 note-only posture): `handleTapEvent` re-enables the tap on `.tapDisabledByUserInput` exactly as it does on `.tapDisabledByTimeout` — one combined case (`case .tapDisabledByTimeout, .tapDisabledByUserInput:`), plus ONE log line naming which cause fired; `return false` (never swallow), no other change, no new state. Constraints: machine verify = compile + existing suite stays 126/16 (the branch is unreachable without a real CGEventTap — this is the adapter side of the D14 split, `tap` is nil in tests, so NO new test is owed); live dead-tap recovery is HUMAN-AT-SCREEN, queued behind the same blocked-verify wall as 3C/3D/D45 and does NOT gate the code landing | Dead tap = dead hotkey with no recovery path — a real resilience gap, and the fix is a strict mirror of the proven timeout branch (near-zero risk, ~3 lines). The surgical-change deferral was about not touching an unrelated surface mid-phase; a blocked window burning down machine-verifiable backlog is exactly when a mirror-branch fix should land | backlog (blocked window) |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| — | carried | R4 (phase 0): close by exercising a Keychain read under the 5RC66Q82V9 identity. Note: 3A's probe hits the no-key D13 endpoint, so it does not exercise this — still owed at first authed-endpoint work. CLOSED 2026-07-05 as moot-until-API-key-feature (see Notes ruling); reopen trigger = first authed-endpoint work | closed (moot) | — |

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

2026-07-05: 3B SHAPE NON-OBJECTION. CleanupService placement/API confirmed
against D39/D40 verbatim: struct in Sources/, init(settings:session:),
isEnabled = D40 rule, strict OpenAI-standard hot-path body (keep_alive
reachable only from warmUp()), 4 s timeout, error enum mirrors
TranscriptionError; DictationController hop implements D43 exactly (raw
fallback, second generation check after the cleanup await, .success on raw
insert). D42 retry reading RATIFIED as spec-literal — decision text amended
with one clarifying clause (HTTP non-2xx only; transport failures log and
stop); spec §3B warm-up paragraph mirrored. LoC ceilings raised per R6/R13
precedent (stub infra + doc comments, not logic creep): CleanupService.swift
~90 → ~120, CleanupServiceTests ~120 → ~195; spec budget rows updated.
No-DI-seam in DictationController accepted — the seam is CleanupService's
injectable URLSession; controller-level DI is speculative until a test
needs it (CLAUDE.md §2). R38 (warm-up log cosmetics) and R39 (raw-defaults
empty string bypasses D25 empty→nil; degrades safely to a failed cleanup +
raw insert) are 3C intake — both touch surfaces 3C reworks anyway
(warm-up hook, settings/draft plumbing).

2026-07-05: 3C SHAPE NON-OBJECTION (post-execution, reviewer 120/15
approved). (a) ConnectionProbe `send(_:)` extraction: correct second-caller
factoring — private, transport+status gate only, per-endpoint decoding
stays in the callers; the hardcoded "Timed out after 10 s" reason is safe
while both probes share D36/D44's 10 s. (b) Warm-up seam + single-write-path
confirmed against source: `persist()` is the only `draft.save()` caller
(probe-success, Save Anyway, both-URLs-empty), and the before/after LLM
tuple compare + `CleanupService.isEnabled` gate implements D42's
endpoint-change trigger exactly — clearing the endpoint changes the tuple
but disables cleanup, so no warm-up fires (correct). The `warmUp ?? { Task
{ … } }` init-body fallback (default params can't capture `store`) is the
right minimal seam. (c) SettingsForm.swift split: boundary is exactly
view-vs-lifecycle — form owns drafts/probeState rendering + Esc route,
controller owns tasks/sheet/persist; mechanical per R37, picker row is the
only net-new. R40 (420x390 literal in two files): BACKLOG — name a shared
constant on next touch of either file; a doc-mandated now-edit fails
CLAUDE.md §3. R41 (default warm-up closure = real-network seam): BACKLOG —
every test injects a stub today; revisit only if a test ever constructs the
controller without one. No spec divergence found; no round-trip.

2026-07-05: MAINTENANCE SWEEP SHAPE NON-OBJECTION. (a) R3:
AppDelegate.dictationController `private` → `private(set)` (getter
internal, @testable-visible) so the hosted smoke test asserts real
post-launch composition instead of mere linkage — minimal visibility
relaxation, setter stays private, correct. (b) R40:
`SettingsForm.contentSize` static on the form itself, referenced by
SettingsWindowController.setContentSize — this IS the backlogged
"shared constant on next touch"; the form is the natural owner (the
size exists because of its root-frame workaround), and a separate
PillMetrics-style enum would be a speculative third file for one
CGSize.R40 backlog item closed.

2026-07-05: D45 authored (reasoning-model fix, empirical). Spec §3B updated
in the same pass: Service paragraph timeout 4 → 8, prompt fixtures now carry
the `/no_think ` prefix, all §3B "4 s" mentions (failure policy, tests,
verify step 3) aligned. Engineer implements from the spec: CleanupLevel
prompt strings + CleanupService timeout + CleanupLevelTests/
CleanupServiceTests fixtures change; nothing else. Verify: re-run spec §3B
verify steps 2–3 against the user's vLLM — step 2 must now produce CLEANED
text (was the failing observation), step 3's raw fallback now lands after
~8 s.

2026-07-05: phase-3-spec.md §3D authored (D46–D48) — user-directed
two-stage pill success. ONE sub-phase: one enum case, one view branch, one
pipeline touch; slicing gates nothing. Code-verified against
DictationController.stopRecording: insertion happens after the cleanup
await (cleaned text is what inserts), so stage 1 (STT) must display at the
transcript-accepted point, pre-insert — D47 rules the exact sequence and
amends only D43's pill face (`.success` on miss → `.stagedSuccess(.missed)`
amber); fallback/stale/no-alert semantics untouched. D14 split: the
flash/sticky decision extracted to pure `PillState.flashDuration`
(headless PillStateTests); DictationController staged transitions ride the
3B no-DI-seam ruling, human-verified live; visuals human-verified. LoC
ceilings: source ~61 across PillState/PillView/PillController/
DictationController, tests ~35. Forced-miss verify path: bogus LLM URL via
Save Anyway (D37). HUMAN GATE: user's LLM endpoint needed for the
two-stage happy path, as at 3B/3C.

2026-07-05: BLOCKED-WINDOW BACKLOG RULINGS (vLLM host unreachable; all
HUMAN-AT-SCREEN verifies blocked; orchestrator burning down
machine-verifiable backlog at 126/16 baseline, 7f7c8a4).
(1) R4 — CLOSED AS MOOT-UNTIL-API-KEY-FEATURE. The feared failure
(legacy-keychain ACL on an item written under an old signature becoming
unreadable after re-signing) requires a pre-existing production item, and
none has ever been written: the app has NO API-key feature (D13 endpoints
need no key), KeychainStore has zero production callers, and every gate
runs KeychainStoreTests writing/reading FRESH items green under the stable
5RC66Q82V9 identity (R27) — fresh items are created with the current
identity's ACL, so the legacy-ACL hazard cannot exist for anything the app
will ever write from here. Carrying the row buys nothing. REOPEN TRIGGER
(named, binding): the first authed-endpoint work — the sub-phase that adds
the first production API-key write must include a verify step that stores
a key, rebuilds+re-signs, relaunches, and reads it back; that step IS the
R4 close-out and must cite this ruling.
(2) R31 — PULL-FORWARD APPROVED as D49 (see Locked decisions): mirror the
`.tapDisabledByTimeout` re-enable for `.tapDisabledByUserInput`, one log
line naming the cause, nothing else. No new test owed (tap is nil under
tests — adapter side of D14); suite must stay 126/16; live dead-tap
recovery joins the blocked HUMAN-AT-SCREEN queue, non-gating.
(3) Rest of backlog — NOTHING ELSE PULLED FORWARD. R34: unrealistic
microsecond race, cosmetic even if hit — any "fix" is speculative code for
a non-event (CLAUDE.md §2), stays note-only. R41: latent test-hygiene seam
with zero current exposure (every test stubs `warmUp:`); adding a guard now
is a test-only seam code-norms disfavor — stays backlog per the 3C ruling.
R42: truthfulness wrinkle is D47's accepted framing (slot 1 = STT proof),
reachable only by deliberate overlap — a change would reopen a
just-locked, just-reviewed design for note-grade value; stays note-only.
R7 (for completeness): hotkey-config UI is Phase 7+ — untouched.

2026-07-05: 3D SHAPE NON-OBJECTION (post-execution, 126/16 ×2). (a) Local
`var terminal = PillState.success` mutated inside the existing do/catch,
keeping one `inserter.insert` site: correct minimal realization of D47 —
sequence points (pending pre-await, second generation guard, insert, then
terminal update) unchanged; fewer branches than the spec's prose, same
semantics. (b) `HStack(spacing: 16)` inline in PillView: D31 governs pill
SIZE/POSITION literals (panel geometry, one definition site); interior
layout spacing is view-local, same class as PillView's existing 24 pt
interior inset (R32 precedent — "numeric match coincidental, not
shared"). D48's "only PillMetrics delta is stagedFlashDuration" stands as
written. No D-number warranted for either.

2026-07-06: **PHASE 3 CLOSED** (architect close-out audit vs §3A–§3D
verify lists).
- MACHINE: full suite green ×2 at HEAD 13ddec6 (226/22, tester baselines)
  — every §3A/3B/3C/3D `make test` gate satisfied, including the
  ConnectionProbe / CleanupService / CleanupLevel / PillState headless
  suites and the byte-identity fixtures.
- HUMAN/LIVE (user on-device 2026-07-06): warm-up HTTP 200 confirmed in
  log (§3B v5); two-stage pill both slots green on a real cleaned
  dictation (§3D v3); forced amber-miss — bogus LLM URL via Save Anyway →
  amber slot 2 + RAW text lands (§3C v3 sheet names endpoint, §3D v4,
  D43/D47); STT-only regression — cleared LLM URL → single green check
  (§3D v2); cleanup-level Off → raw single-check (§3B v4). The Save
  test-then-close flow (spinner → checkmark → auto-close → persist, §3A
  v2) is exercised implicitly by every configured-endpoint dictation in
  the batch and by the failure-sheet path being reached.
- #7 RULING (rephrasing + leaked "Note:" commentary on the D45 flagship
  cleaned dictation): NOT a Phase-3 pipeline defect. The pipeline met its
  contract — fillers removed (D45), raw fallback intact, pill staged
  correctly. The rephrase/commentary is a MODEL-CONFIGURATION issue
  (Qwen3.6 silently ignoring `/no_think` → hidden reasoning; Phi-3.5-mini
  a weak instruction-follower), root-caused and resolved in Phase 8A
  (D72/D73: `reasoning_effort:"none"`). Phase 3 ships the pipeline; the
  pipeline works.
- DEFERRALS (non-gating, documented): the cleaned-OUTPUT quality
  re-confirmation (clean text, no commentary) rides under Phase 8 §G as an
  8A live leg, NOT a Phase-3 gate — Phase 3 delivered the cleanup pipeline
  (verified end-to-end), the output quality is a model/param concern owned
  by Phase 8. The §3A titlebar-close / Esc-mid-spinner "writes nothing"
  leg (v4) and §3C endpoint-change warm-up log leg (v4) were not
  separately re-run at screen; both are covered by the headless
  injected-closure controller tests (cancel semantics; warm-up tuple
  trigger) and are low-risk. D49 dead-tap live recovery remains a
  non-gating backlog observation. None block v1 close.
CLOSED as of 2026-07-06.
