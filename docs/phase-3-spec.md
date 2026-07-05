# Phase 3 Spec — 3A: Settings Save connection test; 3B+ LLM cleanup (TBD)

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
  **Close Anyway** = `draft.save()` then close (user clicked Save; "close
  anyways" means save-then-close — settings DO persist on this path);
  **Cancel** = dismiss sheet, back to editing, drafts intact, nothing
  written.
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
   Save → sheet "There's a problem with the connection." + reason; Cancel →
   editing resumes with edits intact; Save again → Close Anyway → window
   closes; reopen proves the bogus URL persisted.
4. HUMAN-AT-SCREEN: titlebar close (or Esc) during the spinner → window
   closes, nothing written (reopen shows old values).
5. HUMAN-AT-SCREEN (D38 regression): one end-to-end dictation after the
   change — loop behavior and its no-alert policy untouched.

**Invariants:** probe reads drafts only, never SettingsStore; store writes
happen exactly at probe-success or Close Anyway, both via `draft.save()`
(D25 empty→nil preserved); no alert ever originates outside the settings
window (D38); probe never blocks the main thread; dictation loop untouched.

**Out of scope (3B+):** LLM endpoint probing, CleanupService, cleanup
levels, warm-up, PLAN.md Phase 4+ items.
