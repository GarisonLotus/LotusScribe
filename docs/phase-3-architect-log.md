# Architect log — LotusScribe (Phase 3)

> Locked decisions + open questions for Phase 3. D1–D11 live in
> docs/phase-0-architect-log.md, D12–D28 in phase-1, D29–D35 in phase-2;
> all remain binding. Numbering continues at D36. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D36 | 2026-07-05 | Connection-test probe = real round-trip: multipart POST of a ~0.2 s silent WAV (WavEncoder, 16 kHz mono zeros) + DRAFTED model to the DRAFTED STT endpoint URL, same request shape as TranscriptionService; success = HTTP 200 + decodable `{"text": …}`, content ignored (D28: silence may hallucinate — irrelevant); 10 s timeout; probe reads drafts only, never SettingsStore; empty drafted STT URL → skip probe, save+close unchanged (clearing settings must not be blocked by a guaranteed-fail test); un-parseable URL → immediate failure, no network. 3A probes STT only; per-endpoint generalization lands with 3B's LLM setting | The user's "settings are accurate" is only proven by the real request (URL path + model + reachability); GET/HEAD validates none of that. 10 s: watched interaction, half the dictation timeout, ample for a 0.2 s clip on warm vLLM | 3A |
| D37 | 2026-07-05 | Save flow (amends D26's "Save writes and closes" — the write-then-close step is now probe-gated; all other D26 semantics stand): Save → in-flight (fields+buttons disabled, spinner "Testing connection…"); success → `draft.save()` immediately + green checkmark, auto-close ~2 s later; failure → NSAlert sheet ("There's a problem with the connection." + brief reason), Close Anyway = `draft.save()` then close — failure-path save DOES persist (user clicked Save; "close anyways" = save-then-close), Cancel = back to editing, drafts intact, nothing written; titlebar close / Esc mid-test cancels the probe and writes nothing; reopen resets probe state to idle | Persist-at-success (not at window close) means a force-close during the 2 s flash cannot lose the save; failure-path persistence honors the explicit Save click while the sheet keeps the user informed; Cancel preserves D26 buffered editing exactly | 3A |
| D38 | 2026-07-05 | Alert-policy scope annotation: the cross-cutting "never alerts" rule (phase-1/2 specs) governs the AUTONOMOUS dictation loop — hotkey→record→transcribe→insert must never interrupt the user with UI. A modal sheet in the settings window, in direct response to the user's own Save click, is outside that scope and was explicitly user-requested. Restated rule: no alert may ever originate from the dictation loop; settings-window direct-response dialogs are permitted | The policy's purpose is protecting flow during dictation, not banning dialogs the user asked for in a window they are actively operating; scoping it prevents both future misreadings | 3A |

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
