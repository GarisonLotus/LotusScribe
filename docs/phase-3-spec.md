# Phase 3 Spec — 3A: Settings Save connection test; 3B/3C: LLM cleanup

> Authored by architect, 2026-07-05 (incrementally: §3A now; §3B+ appended
> when PLAN.md §Phase 3 LLM-cleanup work starts). Placement ruling: this is
> user-directed scope arriving between phases, ruled INTO Phase 3 as its
> first sub-phase 3A rather than a standalone mini-phase — Phase 3 adds the
> LLM endpoint setting, and PLAN.md Phase 7.3 already plans a
> connection-test affordance; one probe surface serves both endpoints when
> 3B lands, and integer phase numbering (CLAUDE.md §5) stays clean. PLAN.md
> itself is annotated, not rewritten (see architect log note). Honors
> D1–D35; new rulings D36–D38 in docs/phase-3-architect-log.md. Baseline:
> 80 tests / 12 suites at e6b6fe6. LoC budgets are ceilings. No third-party
> deps (D7).

## User requirement (verbatim intent, authoritative)

"When you click the Save button in the Settings screen, it should do a test
right then and there that the connection is working and the settings are
accurate and report back before closing the window. If it's green, have a
green checkmark and then close the window after about two seconds. If it's
red, pop up telling that there is a problem with the connection and offer
to close anyways or cancel."

## Cross-cutting design

- **Alert-policy scope (D38):** the "never alerts" rule governs the
  autonomous dictation loop only. A sheet in the settings window, in direct
  response to the user's own Save click, is outside that scope and
  explicitly user-requested. No alert may ever originate from the loop.
- **Testability split (D14):** probe + result plumbing headless
  (StubURLProtocol pattern from TranscriptionServiceTests, serialized
  suite); sheet / checkmark / 2 s auto-close are thin UI, human-verified.
- **D26 stands except where D37 amends it:** buffered drafts, Cancel /
  titlebar-close write nothing, reopen re-seeds. Only Save's
  write-then-close step is now gated on the probe.

## Sub-phase 3A — Save = test-then-close

**Probe (D36):** "connection working and settings accurate" = a real
round-trip: multipart POST of a ~0.2 s silent WAV (WavEncoder, 16 kHz mono
zero samples) with the DRAFTED model to the DRAFTED STT endpoint URL — same
request shape as TranscriptionService. Success = HTTP 200 + decodable
`{"text": …}`; response content ignored (D28 record: silence may
hallucinate text — irrelevant, the round-trip is the proof). Timeout 10 s
(watched interaction; half the dictation timeout; warm vLLM answers a 0.2 s
clip well inside it). Rejected: GET/HEAD reachability ping — wrong verb for
the path, validates neither route nor model. Empty drafted STT URL → skip
the probe, save+close exactly as today (clearing settings must not be
blocked by a guaranteed-fail test). Un-parseable URL → immediate failure,
no network. 3A probes the STT endpoint only (no code path uses the LLM
endpoint yet); the surface generalizes per-endpoint in 3B.

**Save flow (D37):**
- Save (button or Return) → probe in-flight: fields + Save + Cancel
  disabled, spinner + "Testing connection…" in the button row.
- Success → `draft.save()` IMMEDIATELY (a force-close during the flash
  cannot lose the save), green checkmark + "Connected" in-window,
  auto-close after ~2 s.
- Failure → NSAlert sheet on the window: message "There's a problem with
  the connection.", informative text = brief reason (invalid URL / HTTP
  status / transport error / unexpected response / timed out). Buttons:
  **Save Anyway** = `draft.save()` then close (user clicked Save —
  settings DO persist on this path); **Try Again** = dismiss sheet, back
  to editing, drafts intact, nothing written. (Labels renamed from Close
  Anyway / Cancel per user directive, 2026-07-05.)
- Titlebar close / Esc mid-test: cancel the probe task, write nothing (D26
  cancel semantics). Reopen resets probe state to idle.

**Deliverables:**
- `ConnectionProbe.swift` (~55): headless, no SettingsStore access.
  ```swift
  enum ProbeResult: Equatable { case success; case failure(reason: String) }
  struct ConnectionProbe {
      init(session: URLSession = .shared)
      func testSTT(endpoint: String, model: String) async -> ProbeResult
  }
  ```
  Reuses MultipartBody + WavEncoder; 10 s `timeoutInterval`.
- `SettingsWindowController.swift` delta (~85): probe phase enum
  (`idle / testing / success / failure(String)`) published for the form;
  probe injected as `(String, String) async -> ProbeResult` closure
  (defaults to ConnectionProbe) so controller logic tests headlessly;
  Save path, sheet, and 2 s auto-close per D37. SettingsForm gains the
  spinner row / green checkmark / disabled states.
- `Tests/ConnectionProbeTests.swift` (~60), StubURLProtocol (serialized,
  global-handler pattern): 200+JSON → success; non-200 → failure with
  status in reason; transport error → failure; 200 non-JSON → failure;
  invalid URL string → failure without touching the session; request-shape
  check (multipart carries model field + wav file part).
- `Tests/SettingsWindowControllerTests.swift` delta (~35), injected stub
  probe: empty drafted STT URL → closes without invoking probe; stub
  success → store written + phase == success; stub failure → store
  untouched + phase == failure(reason). Timer/sheet not unit-tested.

**Execution notes (architect-accepted lean deltas, 2026-07-05):** Esc-mid-test
lands via `.onExitCommand` (key equivalents skip the disabled Cancel button);
probe phase publishes through a tiny `ProbeState: ObservableObject`
(NSWindowController cannot publish); `probeTask` is `private(set)` so tests
await Save's async leg; probe tests use a dedicated ProbeStubURLProtocol.

**Verify:**
1. `make test` green ×2 (delta ≈ +9 tests, +1 suite vs 80/12).
2. HUMAN-AT-SCREEN (success): real settings (D13 endpoint,
   whisper-large-v3) → Save → spinner, then green checkmark, window closes
   by itself after ~2 s; reopen shows values persisted.
3. HUMAN-AT-SCREEN (failure): bogus URL (e.g. https://nope.invalid/v1/x) →
   Save → sheet "There's a problem with the connection." + reason; Try Again →
   editing resumes with edits intact; Save again → Save Anyway → window
   closes; reopen proves the bogus URL persisted.
4. HUMAN-AT-SCREEN: titlebar close (or Esc) during the spinner → window
   closes, nothing written (reopen shows old values).
5. HUMAN-AT-SCREEN (D38 regression): one end-to-end dictation after the
   change — loop behavior and its no-alert policy untouched.

**Invariants:** probe reads drafts only, never SettingsStore; store writes
happen exactly at probe-success or Save Anyway, both via `draft.save()`
(D25 empty→nil preserved); no alert ever originates outside the settings
window (D38); probe never blocks the main thread; dictation loop untouched.

**Out of scope (3B+):** LLM endpoint probing, CleanupService, cleanup
levels, warm-up, PLAN.md Phase 4+ items.

---

# §3B/§3C — LLM cleanup (PLAN.md §Phase 3 items 1–4)

> Authored 2026-07-05 after 3A close (638b11d, 89 tests / 13 suites ×2).
> Rulings D39–D44 in docs/phase-3-architect-log.md. Slices: 3B = service +
> dictation pipeline (headless-heavy); 3C = settings surface + per-endpoint
> probe (folds R36/R37). Store already carries `llmEndpointURL`/`llmModel`
> (D9) and the form shows both fields — 3B adds no settings UI.
> Endpoint-agnostic: any `/v1/chat/completions` server; user infra is vLLM,
> but nothing may assume Ollama or vLLM.

## Cross-cutting (3B/3C)

- **History/undo (D41):** PLAN item 2's "undo cleanup" history mirror
  DEFERRED to the Phase-5+ history feature; 3B ships the raw-transcript
  fallback only. PLAN.md annotation owed (orchestrator applies).
- **Effective-enabled rule (D40):** cleanup runs iff `llmEndpointURL` and
  `llmModel` are both set (D25: empty saved as nil) AND resolved level ≠
  `.off`. Otherwise the transcript inserts untouched — no request, no error.
- **Failure policy (D43, extends D23/D38):** any cleanup failure (timeout
  ~8 s per D45, HTTP/transport, undecodable or empty output) → insert the RAW
  transcript, log, pill flashes `.success` (the words landed — that is the
  success). No new pill state (cleanup runs under `.processing`); `.error`
  stays transcription-failure-only; no alert ever. Generation re-checked
  after the cleanup await: stale → drop, no insert, no pill touch.

## Sub-phase 3B — CleanupService + dictation pipeline

**Levels (D40):** `CleanupLevel.swift` (~30): `enum CleanupLevel: String,
CaseIterable { case off, light, standard }`; `static func resolve(_ raw:
String?) -> CleanupLevel` (nil / unrecognized → `.standard`);
`var systemPrompt: String?` (`.off` → nil). Prompts (RESEARCH.md §4 —
verbatim, they are test fixtures). D45: both prompts begin with the literal
prefix `/no_think ` (token + one space) — the Qwen3-family soft switch that
suppresses the hidden reasoning block; inert prompt text on any other
OpenAI-compatible backend:
- `.standard`: "/no_think You clean up dictated speech-to-text transcripts. Remove
  filler and pause words (um, uh, you know, like), fix punctuation and
  capitalization, and add paragraph breaks where natural. Preserve the
  speaker's meaning, wording, and voice — never rephrase, summarize,
  shorten, or add content. Output only the cleaned text, with no
  commentary."
- `.light`: same prefix + first + last sentences, middle replaced by: "Remove filler
  and pause words (um, uh, you know, like) and fix punctuation and
  capitalization only. Change nothing else."

**Service (D39):** `CleanupService.swift` (~120; raised from ~90 at 3B
close per R6/R13 precedent), mirrors
TranscriptionService: `init(settings: SettingsStore, session: URLSession =
.shared)`; `var isEnabled: Bool` (D40 rule); `func cleanup(transcript:
String) async throws -> String`; `func warmUp() async`. Cleanup request:
JSON POST to `llmEndpointURL` (full URL, as with STT), body exactly
`{"model", "messages": [system, user(transcript)], "temperature": 0}` —
strictly OpenAI-standard, no `keep_alive` on the hot path (D42) and no
vLLM-only `chat_template_kwargs` (D45 — reasoning suppression rides in the
prompt prefix instead); `timeoutInterval` 8 (PLAN item 4 said 4; raised by
D45 — empirically, reasoning-mode chat latency blew the 4 s cap on every
real dictation, and with `/no_think` typical latency is 3.4 s). Success =
200 + decodable
`choices[0].message.content`, trimmed; trimmed-empty → throw (never insert
emptiness for spoken words). Errors mirror TranscriptionError.

**Warm-up (D42):** `warmUp()` fire-and-forget, log-only, never touches the
pill: body `{"model", "messages": [user("ok")], "max_tokens": 1,
"keep_alive": -1}`, `timeoutInterval` 30 (cold start 3–10 s); HTTP non-2xx →
retry ONCE without `keep_alive` (strict OpenAI-compat validators may 400 on
unknown fields — vLLM must still warm); transport failures log and stop, no
retry (D42 as amended). Skipped when not effective-enabled.
Launch trigger: AppDelegate, inside the existing `XCTestSessionIdentifier`
guard (tests never fire network warm-ups); endpoint-change trigger is 3C.

**Pipeline:** DictationController delta (~30): after the non-empty
transcript guard, if `cleanup.isEnabled` → `try await cleanup.cleanup(...)`
with do/catch → raw fallback per D43; re-check `capturedGeneration ==
generation` after the await; insert, `.success`. SettingsStore delta (~8):
`cleanupLevel: String?` following the existing key pattern.

**Tests (D14 headless):** `CleanupLevelTests` (~35): resolve mapping (nil,
garbage, each raw); prompt fixtures. `CleanupServiceTests` (~195, raised from ~120 at 3B close per
R6/R13 precedent — stub infra; dedicated
stub URLProtocol per 3A precedent, serialized): request shape (URL, model,
level→system prompt incl. `/no_think ` prefix, temperature 0, NO
keep_alive, timeout 8 per D45); 200+content
→ trimmed text; 200 empty-content / non-200 / transport / non-JSON → throw;
`isEnabled` matrix; warm-up shape (`max_tokens` 1, `keep_alive` -1) +
4xx-then-retry-without-keep_alive. Timing + live loop human-verified.

**Verify (3B):**
1. `make test` green ×2 (delta ≈ +16 tests, +2 suites vs 89/13).
2. HUMAN-AT-SCREEN: with the USER'S LLM endpoint/model saved (user supplies
   at the gate — spec hardcodes none), dictate "um so basically I think we
   should uh ship it tomorrow" → cleaned text (fillers gone) lands.
3. HUMAN-AT-SCREEN (PLAN verify): point `llmEndpointURL` at a dead host →
   dictate → RAW transcript inserted after ~8 s (D45), pill success, failure
   logged. Never eat the user's words.
4. HUMAN-AT-SCREEN: `defaults write … cleanupLevel off` (picker is 3C) →
   dictate → raw path, log shows no cleanup request.
5. Launch app → warm-up request + outcome in the log stream.

**Invariants:** cleanup failure can never block or discard an insertion; no
`keep_alive` on cleanup requests; pill states untouched (D31); no alerts
from the loop (D38); TranscriptionService untouched.

## Sub-phase 3C — Settings level picker + per-endpoint probe

**Probe (D44, generalizes D36):** `ConnectionProbe.testLLM(endpoint:model:)
async -> ProbeResult` (~50 delta): POST `{"model", "messages":
[user("ping")], "max_tokens": 1}` (no keep_alive — probe body stays
strictly standard), 10 s timeout, success = 200 + decodable
`choices[0].message`; same invalid-URL / error mapping as `testSTT`. Save
flow: probe each endpoint whose DRAFTED URL is non-empty (level-independent
— one rule, mirrors D36's empty-skip), sequentially STT then LLM, stop at
first failure; sheet reason prefixed with the endpoint name ("Speech to
Text: …" / "Cleanup LLM: …"). Both empty → save+close unchanged. D37
otherwise unchanged.

**Controller delta (~60):** second injected probe closure (LLM) beside the
STT one; R36 FOLD: `save()` cancels any prior `probeTask`/`autoCloseTask`
first; warm-up hook (D42's endpoint-change trigger): after any
`draft.save()` (success or Save Anyway) where `llmEndpointURL`/`llmModel`
changed and cleanup is effective-enabled, fire injected warm-up closure
(default `CleanupService(settings:).warmUp()` in a Task). R37 FOLD: extract
`SettingsForm` to `SettingsForm.swift` (mechanical move + picker row, net
new ~15). Form: `Picker("Cleanup", …)` Off/Light/Standard in the Cleanup
LLM section; draft gains `cleanupLevel: CleanupLevel` (reload via
`resolve`, save writes rawValue).

**Tests:** `ConnectionProbeTests` delta (~50): testLLM shape (max_tokens 1,
no keep_alive, timeout 10) + success/failure mapping.
`SettingsWindowControllerTests` delta (~45, stub probes): empty LLM URL →
LLM probe not invoked; STT failure → LLM probe not invoked; both stubbed
green → save + success phase; LLM-change save → warm-up closure fired once,
no-change save → not fired; R36: second save() cancels the first task pair.

**Verify (3C):**
1. `make test` green ×2 (delta ≈ +9 tests vs 3B baseline).
2. HUMAN-AT-SCREEN: picker shows Off/Light/Standard, persists across
   reopen; Save with both endpoints valid (user's) → spinner → checkmark →
   auto-close.
3. HUMAN-AT-SCREEN: valid STT + bogus LLM URL → sheet names "Cleanup LLM";
   Try Again / Save Anyway behave per D37.
4. HUMAN-AT-SCREEN: change LLM model → Save → warm-up fires (log); Save
   with nothing changed → no warm-up line.
5. HUMAN-AT-SCREEN (D38 regression): one end-to-end dictation untouched.

**Invariants:** probes read drafts only; store writes only via
`draft.save()` at probe-success or Save Anyway (D25/D37); warm-up never
blocks Save or close; SettingsForm extraction is behavior-neutral.
