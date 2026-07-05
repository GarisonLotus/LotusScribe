# Phase 2 Spec — Pill overlay + waveform, event swallowing, cold-start

> Authored by architect, 2026-07-04. Scope: PLAN.md §"Phase 2 — Pill overlay
> + waveform" PLUS two Phase-1 promotions: event swallowing (D28) and Q4
> cold-start (ruled → D29). Honors D1–D28; new rulings D29–D32 locked in
> docs/phase-2-architect-log.md. Baseline: 54 tests / 9 suites at b148cff.
> LoC budgets are ceilings, not targets. No third-party deps (D7).

## Cross-cutting design

- **Testability split (D14):** pure logic (swallow decisions, RMS math, pill
  state model, panel metrics) headless-tested; TCC/UI adapters (event tap,
  recorder, NSPanel) stay thin and are human-verified.
- **R23 (macOS 26):** SwiftUI-hosted AppKit windows must be sized explicitly
  — PillPanel uses `setContentSize` from `PillMetrics` (D31); materialization
  tests assert `contentLayoutRect`, never window frame.
- **Failure policy unchanged:** log via os.Logger; the pill may flash its
  error state — never alerts, never partial paste. D23/D24 generation
  semantics untouched.
- New files land flat in `Sources/LotusScribe/` (established style).

## Sub-phase 2A — Event swallowing + RMS plumbing (pure logic first)

**Deliverables:**
- `HotkeyStateMachine.swift` delta (~30):
  ```swift
  struct HotkeyDecision: Equatable { var action: HotkeyAction; var swallow: Bool }
  mutating func handle(_ event: HotkeyEvent) -> HotkeyDecision
  ```
  Swallow rules (D30, combo chords only): the matching keyDown that starts
  capture; chord-keycode autorepeat downs while capturing; the chord-keycode
  keyUp iff its keyDown was swallowed (pair balance — track a
  `chordKeyDownSwallowed` flag so the modifier-release stop path still
  swallows the trailing keyUp). Never `flagsChanged`, never other keycodes,
  never `.fnHold`.
- `EventTapMonitor.swift` delta (~20): `tapCreate` with `.defaultTap`; if
  creation fails, retry `.listenOnly` and log the fallback (D30 — Phase-1
  leakage beats a dead hotkey). Callback returns nil when
  `decision.swallow`, otherwise passes the event unmodified.
- `AudioLevel.swift` (~20): pure. `static func rms(pcm16: Data) -> Float` —
  normalized 0…1 (root-mean-square of Int16 samples / Int16.max).
- `AudioRecorder.swift` delta (~15): `var onLevel: ((Float) -> Void)?`;
  `appendConverted` computes `AudioLevel.rms` per chunk on the audio thread
  and dispatches the value to the main thread (D32). Doubles as the
  engine-live signal for D29.
- `Tests/HotkeyStateMachineTests.swift` delta (~50): swallow matrix —
  start-down, autorepeat-down, stop-up, up-after-modifier-release-stop all
  swallowed; non-chord keycodes, flagsChanged, fnHold never; existing action
  assertions migrate to `.action`.
- `Tests/AudioLevelTests.swift` (~30): empty → 0; silence → 0; full-scale
  square → 1.0; half-scale ≈ 0.5.

**Verify:**
1. `make test` green ×2.
2. HUMAN-AT-SCREEN: dictate into TextEdit with the chord (ctrl+alt+cmd+9):
   no "9" character leaks on press, hold (autorepeat), or release; keys
   typed mid-dictation still pass through; chord modifiers keep working
   for other shortcuts when the chord key isn't involved.
3. HUMAN-AT-SCREEN (TCC record, Q5): fresh build — does `.defaultTap`
   creation succeed under the existing Input Monitoring + Accessibility
   grants (no new prompt/pane)? Console log shows which mode is active;
   record → phase-2-tester-baselines.

**Invariants:** only the chord keycode's keyDown/keyUp are ever swallowed —
never flagsChanged, never any other key; no app ever sees an unbalanced half
of the chord key's down/up pair; the `.listenOnly` fallback preserves
Phase-1 behavior exactly; RMS math is pure and headless-tested.

## Sub-phase 2B — PillPanel + waveform view (no wiring yet)

**Deliverables:**
- `PillState.swift` (~30): pure. `enum PillState: Equatable { case hidden,
  warming, recording, processing, success, error }` plus `enum PillMetrics`
  (D31 single site): contentSize 260×52 pt, bottomMargin 24 pt, barCount 24,
  flashDuration 0.8 s.
- `PillPanel.swift` (~60): NSPanel subclass. `styleMask = [.borderless,
  .nonactivatingPanel, .fullSizeContentView]`; `isFloatingPanel = true`;
  `level = .floating`; `collectionBehavior = [.canJoinAllSpaces,
  .fullScreenAuxiliary]`; `canBecomeKey`/`canBecomeMain` overridden false;
  `isOpaque = false`, `backgroundColor = .clear`, `hidesOnDeactivate =
  false`, `ignoresMouseEvents = true` (display-only). Explicit
  `setContentSize(PillMetrics.contentSize)` (R23);
  `positionBottomCenter(on:)` — centered on `NSScreen.main`,
  `visibleFrame.minY + bottomMargin`.
- `PillViewModel.swift` (~25): `@MainActor final class PillViewModel:
  ObservableObject` — `@Published var state: PillState`, `@Published var
  levels: [Float]`; `push(level:)` appends and trims to `barCount`.
- `PillView.swift` (~70): SwiftUI capsule (.ultraThinMaterial); per-state
  content: warming = dimmed static bars, recording = bars scaled by
  `levels`, processing = spinner/shimmer, success = checkmark, error =
  exclamation. Root frame from PillMetrics (mirrored why-comment, R21
  pattern). Hosted via NSHostingView with `.ignoresSafeArea()`.
- `PillController.swift` (~50): owns panel + hosting view + view model;
  `show(_ state:)`, `update(_ state:)`, `push(level:)`, `hide()`;
  success/error auto-hide after `flashDuration`.
- `Tests/PillPanelTests.swift` (~50): materialize PillController; assert
  `contentLayoutRect` ≥ 260×52 (R23 — content area, not window frame);
  `canBecomeKey == false`; collectionBehavior contains both flags; level ==
  `.floating`; styleMask contains `.nonactivatingPanel`. (Hosted-app NSApp
  dependency same as SettingsWindowControllerTests — R24 note applies.)
- `Tests/PillViewModelTests.swift` (~20): push trims to barCount, order
  preserved, oldest dropped first.

**Verify:**
1. `make test` green ×2 — 2B is committable with the pill unreachable;
   visual verification is deliberately deferred to the 2C gate (no
   speculative debug trigger).

**Invariants:** pill code touches no TCC-bearing API; the panel can never
become key or main; every size/position literal comes from PillMetrics —
no second definition site (R21 lesson).

## Sub-phase 2C — State wiring + cold-start mitigation (phase gate)

**Deliverables:**
- `AudioRecorder.swift` delta (~5): `engine.prepare()` at init (D29a —
  no TCC touch, no mic indicator; best-effort HAL warm-up).
- `DictationController.swift` delta (~45): owns a PillController.
  startCapture → `recorder.start()` ok → pill `.warming`; first `onLevel`
  callback → `.recording` (then `push(level:)` per callback); start failure
  → `.error` flash. stopCapture → `.processing`; short-capture guard →
  `hide()` (no error — user just tapped the chord); transcript inserted →
  `.success` flash; empty transcript → hide; transcription error → `.error`
  flash. Stale (D23 generation) results never touch the pill — a newer
  dictation owns it.
- No new unit tests: the transition wiring is thin glue over the
  TCC-bearing recorder (D14) — covered by the human gate below.

**Verify (all HUMAN-AT-SCREEN — this is the PLAN.md phase gate):**
1. Focus-steal: while the pill is visible mid-dictation, keep typing in
   TextEdit — every keystroke lands in TextEdit; focus never moves.
2. Fullscreen: dictate over a fullscreen app — pill shows above it; text
   lands on release.
3. Waveform tracks voice: silence → near-flat bars; speech → bars follow
   loudness.
4. Cold-start (Q4/D29): quit + relaunch; on the first dictation the pill
   appears in `.warming` immediately at key-down and switches to waveform
   when the engine is live; speaking only after the waveform appears loses
   no words. Record observed warming duration → tester baselines.
5. States: successful dictation → checkmark flash then hidden; unreachable
   `sttEndpointURL` → error flash, nothing pasted; tap-length press → pill
   hides with no error flash.
6. Swallowing regression: 2A verify-2 still holds with the pill visible.

**Invariants:** pill is display-only — accepts no input, takes no focus,
holds no state of its own beyond view data; DictationController remains the
sole owner of dictation state; failure policy unchanged (log + flash, no
alerts, no partial paste); D23/D24 semantics untouched.

**Out of scope (Phase 3+):** LLM cleanup, app-aware context, AX insertion,
clipboard restore, secure-input detection, hotkey-config UI, history,
onboarding, streaming partials.
