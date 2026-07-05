# Phase 1 Spec — Core loop, no polish

> Authored by architect, 2026-07-04. Scope: PLAN.md §"Phase 1 — Core loop".
> Honors D1–D13. Phase verify: dictate into TextEdit, Slack, browser
> textarea, terminal against the real endpoint (D13); empirically record
> which TCC prompts fire. LoC budgets are ceilings, not targets.

## Cross-cutting design

- **Testability split (D14):** pure logic gets headless Swift Testing unit
  tests; thin TCC-bearing adapters (no branching logic) verified manually.
- New files land flat in `Sources/LotusScribe/` (phase-0 style). No
  third-party deps (D7). No status-item state changes (pill is Phase 2).
- **Ad-hoc signing caveat (Q1):** every rebuild re-signs, so TCC grants may
  reset between builds. Expect re-prompting; record prompts per fresh build
  in docs/phase-1-tester-baselines.md. Don't "fix" — resolves with Q1.
- **Failure policy:** any stage failing → log via os.Logger, do nothing (no
  alerts, no partial paste). Empty transcript → no paste. Before 1E, verify
  steps seed D13 values via `defaults write com.garisonlotus.LotusScribe …`.

## Sub-phase 1A — Hotkey: state machine + event tap + permissions (risky 20%)

**Deliverables:**
- `HotkeyStateMachine.swift` (~80): pure. Shape:
  ```swift
  enum HotkeyChord: Equatable { case fnHold; case combo(keyCode: Int64, modifiers: CGEventFlags)
      static func parse(_ s: String) -> HotkeyChord? }  // "fn" | e.g. "ctrl+alt+z"
  enum HotkeyEvent { case flagsChanged(CGEventFlags); case keyDown(Int64, CGEventFlags); case keyUp(Int64) }
  struct HotkeyStateMachine { init(chord: HotkeyChord)
      mutating func handle(_ event: HotkeyEvent) -> HotkeyAction }  // .startCapture/.stopCapture/.none
  ```
  fnHold: start when `.maskSecondaryFn` appears, stop when it clears. Combo:
  start on matching keyDown, stop on that keyUp or modifier release. Never
  emits stop without a prior start; duplicate downs are `.none`.
- `EventTapMonitor.swift` (~90): TCC-bearing adapter. Listen-only CGEventTap
  (`.listenOnly`, session tap) for `flagsChanged` + `keyDown`/`keyUp`; maps
  CGEvents to `HotkeyEvent`, feeds the machine, forwards actions to a closure
  on the main thread. Re-enables on `tapDisabledByTimeout`. No event
  swallowing in Phase 1 (D16).
- `Permissions.swift` (~30): wraps `CGPreflightListenEventAccess()` /
  `CGRequestListenEventAccess()` / `AXIsProcessTrusted()`; logs at launch.
  Listen access is requested once at launch, guarded from test hosts (D22).
  No onboarding UI (Phase 7).
- `AppDelegate.swift` delta (~15): monitor with chord from UserDefaults key
  `hotkeyChord` (nil → `.fnHold`, D15); log start/stop.
- `Tests/HotkeyStateMachineTests.swift` (~90): fn press/release; combo
  match/non-match; chord parsing; no stop-without-start; repeated flags.

**Verify:**
1. `make test` green (headless).
2. HUMAN-AT-SCREEN: set "Press fn key to: Do Nothing" first (RESEARCH §6.1).
   Launch app; hold/release Fn; Console logs show start/stop. Repeat with
   `defaults write … hotkeyChord ctrl+alt+z`.
3. HUMAN-AT-SCREEN (TCC record #1): on a fresh build, note exactly which
   prompts/toggles were needed for the tap to deliver events (Accessibility
   vs Input Monitoring) → phase-1-tester-baselines.md.

**Invariants:** hotkey logic is 100% unit-tested pure code; the tap never
blocks or modifies events; app stays functional when permissions are denied.

## Sub-phase 1B — Audio capture + WAV hand-off

**Deliverables:**
- `WavEncoder.swift` (~60): pure. `static func wavData(pcm16: Data,
  sampleRate: Int, channels: Int) -> Data` — RIFF/fmt/data header + samples.
- `AudioRecorder.swift` (~100): TCC-bearing adapter. AVAudioEngine input tap;
  AVAudioConverter to 16 kHz mono Int16 (client-side resample, D17);
  `start() throws` / `stop() -> Data` (WAV via WavEncoder). No RMS (Phase 2).
- `DictationController.swift` (~50): main-actor owner of the loop; v1 wiring:
  hotkey start → recorder.start; stop → write WAV to a temp file, log path.
- `Tests/WavEncoderTests.swift` (~60): header fields (RIFF, fmt 16, PCM,
  rate/channels/byte-rate), data-chunk length, empty input.

**Verify:**
1. `make test` green.
2. HUMAN-AT-SCREEN: hold Fn, speak ~3 s, release. `afinfo <temp>.wav` reports
   16000 Hz, 1 ch, 16-bit LPCM; QuickLook playback is intelligible.
3. HUMAN-AT-SCREEN (TCC record #2): note when the Microphone prompt fires
   (expect first `start()`, not launch) → tester baselines. Requires
   `NSMicrophoneUsageDescription` in project.yml `info:` block (D11 carries).

**Invariants:** WAV is fixed 16 kHz/mono/16-bit; engine runs only between
key-down and key-up; no audio persisted beyond the temp hand-off.

## Sub-phase 1C — TranscriptionService (headless, mock-tested)

**Deliverables:**
- `MultipartBody.swift` (~60): pure builder — `init(boundary:)` (injectable
  for tests), `addField(name:value:)`, `addFile(name:filename:contentType:
  data:)`, `var data: Data`, `var contentType: String`.
- `TranscriptionService.swift` (~90):
  ```swift
  struct TranscriptionService { init(settings: SettingsStore, session: URLSession = .shared)
      func transcribe(wav: Data) async throws -> String }
  enum TranscriptionError: Error { case notConfigured, http(Int), badResponse, transport(Error) }
  ```
  Multipart POST to `sttEndpointURL`: fields `model` (from `sttModel`),
  optional `language` (UserDefaults key `sttLanguage`, nil → omitted, D18),
  file part `file`/`audio.wav`/`audio/wav`; `timeoutInterval = 20` (PLAN);
  response JSON `{"text": …}`. No API-key header in Phase 1 (D13: none
  needed; Keychain wiring waits for an authed endpoint).
- `Tests/MultipartBodyTests.swift` (~50): exact body bytes with fixed
  boundary; content-type header.
- `Tests/TranscriptionServiceTests.swift` (~90): URLProtocol stub (D19) —
  asserts URL/method/content-type/body, decodes success, maps non-200,
  malformed JSON, and unset settings to the right errors.

**Verify:**
1. `make test` green — all headless, no network, no TCC.
2. INTEGRATION (the one real-endpoint step): with settings seeded (D13),
   rewire 1B to call the service and log the transcript — the temp-file
   write is removed, not kept alongside (R10) — speak a known sentence,
   confirm correct text in the log.

**Invariants:** service never touches TCC-bearing APIs; request construction
is byte-for-byte unit-tested; 20 s timeout enforced.

## Sub-phase 1D — Insertion v1 + full-loop wiring (phase verify)

**Deliverables:**
- `TextInserter.swift` (~40): TCC-bearing adapter. `NSPasteboard.general`
  clearContents + setString, then synthesized Cmd-V via CGEvent key 9 +
  `.maskCommand` posted to `.cghidEventTap`. No clipboard save/restore (D20
  — restore requires a pasteboard *read*, deferred to Phase 6).
- `DictationController.swift` delta (~40): key-up → stop → transcribe →
  non-empty → insert; errors logged, nothing inserted. Overlapping dictation
  (R11, D23): generation counter — bump an Int on each start, capture it in
  the transcribe Task; insert only if still current, else log + drop.
  No new unit tests (adapter-only; logic already covered in 1A–1C), except:
  add `#expect(request.timeoutInterval == 20)` to the existing 1C
  request-shape test (R12 — required in 1D).

**Verify (all HUMAN-AT-SCREEN — this is the PLAN.md phase gate):**
1. Dictate into TextEdit, Slack, a browser textarea, and Terminal against
   the D13 endpoint; text lands in the focused app each time.
2. TCC record #3 (final matrix): full empirical prompt list for tap + mic +
   synthetic paste; note whether Input Monitoring was ever demanded → tester
   baselines. This closes the refuted-claim ambiguity (RESEARCH §2).
3. Negative: focus a password field; observe and record behavior (secure
   input handling itself is Phase 6+; observe, don't build).

**Invariants:** insertion is write + paste only — no pasteboard reads
anywhere in the app; clipboard clobbering is accepted Phase-1 behavior.

## Sub-phase 1E — Bare settings pane

**Deliverables:**
- `SettingsWindowController.swift` (~100): SwiftUI `Form` in an
  `NSHostingController`-backed window (D21) — four text fields bound to
  SettingsStore (the four D9 keys, no new ones); URL-field hint via pure
  `SettingsValidation.isValidEndpointURL` (http/https scheme + host).
  Invalid values still saved (hint only). App stays LSUIElement.
- `StatusItemController.swift` delta (~10): "Settings…" menu item above Quit.
- `Tests/SettingsValidationTests.swift` (~30): valid/invalid URL cases.

**Verify:**
1. `make test` green.
2. HUMAN-AT-SCREEN: open Settings from menu; edit sttModel; quit + relaunch;
   value persists (`defaults read` confirms) and next dictation uses it.

**Invariants:** pane touches only the four D9 keys; SettingsStore remains
the single backing store; no Keychain UI (no authed endpoint yet).

**Out of scope (Phase 2+):** pill overlay/RMS, cleanup LLM, app-aware
context, AX insertion, clipboard restore, onboarding UI, event swallowing,
hotkey-config UI, history.
