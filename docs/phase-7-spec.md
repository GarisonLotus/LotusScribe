# Phase 7 Spec — Distribution (PLAN.md §Phase 7)

> Authored by architect, 2026-07-05. Rulings D66–D71 in
> docs/phase-7-architect-log.md; D1–D65 (+D62a) remain binding.
> Baseline: 191 tests / 19 suites at 4c779b1. LoC budgets are ceilings.
>
> **Standing context:** AUTONOMOUS RUN — user away until 2026-07-06
> morning; vLLM UP but human testing deferred. Signing is PERSONAL TEAM
> (5RC66Q82V9, project.yml `DEVELOPMENT_TEAM`); Developer ID +
> notarization runs are BLOCKED-USER. Every verify below is classified
> MACHINE / AT-SCREEN (no dictation) / BLOCKED-BATCH (needs dictation) /
> BLOCKED-USER (creds, Apple ID, second Mac, or a user decision).
> Orchestrator copies §Copy-ready block into when-vllm-is-back.md.

## Requirement (PLAN.md §Phase 7, authoritative)

(1) first-run onboarding walkthrough with live preflight status +
Fn-key guidance; (2) Developer ID signing + notarization, DMG, Sparkle,
optional cask; (3) endpoint presets + connection-test button.
**PLAN verify:** clean second-Mac install from DMG — Gatekeeper passes,
onboarding grants, first dictation works (BLOCKED-USER).

## Cross-cutting rulings

- **Sparkle (D66, RULING on D7):** recommend option (b) — defer updates
  to v1.1, ship DMG-only. D7 has held six phases; Sparkle also needs
  EdDSA key custody, an appcast host, and Developer ID signing to be
  worth anything — all BLOCKED-USER today. (a) adopt-now blocks on
  creds anyway; (c) build-nothing forecloses nothing extra vs (b).
  **Decision is BLOCKED-USER (Q7-1)** — no 7A–7C work depends on it;
  if the user picks (a), Sparkle becomes a v1.1 phase, not a re-slice.
- **Signing posture (D71):** project.yml stays untouched (personal-team
  Automatic signing — D12/Q1, TCC-grant persistence). Developer ID
  enters only at the recipe layer: `make dmg` re-signs with
  `$(SIGN_IDENTITY)` when set, else ships the dev-signed app;
  `make notarize`/`make staple` fail fast without creds. Note: a
  Developer ID re-sign changes the code signature → local TCC grants
  invalidate (Q2 pattern, phase-1 record) — release builds are for
  distribution, not the dev machine.
- **Untouched:** dictation loop, services, request shapes (D39/D45),
  hotkey path (R7 stays open — no hotkey UI this phase), pill, history
  (D41), generation discipline (D23).

## Sub-phase 7A — Endpoint presets + connection-test button

**Preset table (D69):** new `Sources/LotusScribe/EndpointPreset.swift`,
pure Foundation (D40 shape):

```swift
struct EndpointPreset { let name: String
    let sttEndpointURL: String?; let llmEndpointURL: String? }
```

`static let all: [EndpointPreset]` =
- "Speaches (recommended for STT)" — stt `http://localhost:8000/v1/audio/transcriptions`, llm nil
- "Ollama" — stt nil, llm `http://localhost:11434/v1/chat/completions`
- "vLLM" — stt `http://localhost:8000/v1/audio/transcriptions`, llm `http://localhost:8000/v1/chat/completions`

Apply semantics (D69): `apply(to: SettingsDraft)` sets only the non-nil
URL fields; **model fields are never overwritten** (server-specific;
user's models must survive preset switching); no persisted "selected
preset" key — apply is stateless, "custom" = just type in the fields
(current behavior, no menu item needed). Presets edit the DRAFT only
(D26); Save/probe path unchanged (R45: no new probe-trigger keys).

**UI:** `SettingsForm` gains a `Menu("Apply Preset…")` row at the top
of the "Speech to Text" section (one control; both sections' URLs may
change; no filled-fields hint owed). R40: `SettingsForm.contentSize`
height bumps 700 → 740 at the single site. R49: the preset menu sits
inside the Form's `.disabled(probeState.phase == .testing)` scope — no
new guard owed; button-row sole-guard watch unaffected.

**Connection-test button (D70):** reuses the D37/D44 machinery — no new
probe code. `SettingsWindowController` gains `func test()`, mirroring
`save()`'s probe leg (cancel stale `probeTask`/`autoCloseTask` per R36,
set `.testing`, call the existing private
`probeEndpoints(sttEndpoint:sttModel:llmEndpoint:llmModel:)` on the
injected `runSTTProbe`/`runLLMProbe` seams) but on completion it only
sets `probeState.phase` — **never persists, never closes, never
sheets** (D38 sheet stays Save-only). Both URLs empty → no-op.
`SettingsForm` gains a "Test" button in the `safeAreaInset` row (left
of Cancel) via a new `onTest: () -> Void` closure; `probeIndicator`'s
`.failure` arm changes from `EmptyView()` to inline orange
`exclamationmark.triangle.fill` + caption reason (Save's sheet still
precedes it; Try Again resets `.idle`). Mid-test close:
`windowWillClose` already cancels `probeTask` — holds.

**LoC:** EndpointPreset.swift ≤ 45; SettingsForm.swift +≤ 40;
SettingsWindowController.swift +≤ 30.

**Verify 7A**
1. MACHINE — `make test` ×2: new `EndpointPresetTests` (~7: table
   contents, apply fills only non-nil fields, models untouched, apply
   twice idempotent) + `SettingsWindowControllerTests` (+3: `test()`
   success → `.success` and store unwritten; `test()` failure →
   `.failure(reason)` and no close; both-empty no-op).
2. MACHINE — R49 grep: button row still carries its own `.disabled`.
3. AT-SCREEN — presets menu fills fields; Test button spins then shows
   Connected / inline failure; window fits at 740 (no clipped rows).

## Sub-phase 7B — First-run onboarding

**Input-Monitoring answer (D68):** phase-1 empirical record
(phase-1-tester-baselines.md TCC matrix): BOTH Input Monitoring AND
Accessibility are required for tap delivery, and NO automatic prompt
fires (`CGRequestListenEventAccess()` silently ignored) — so the step
is **unconditional**, and both AX/IM steps are "Open System Settings"
deep links, not request calls. Mic is the only real prompt
(`AVCaptureDevice.requestAccess(for: .audio)`).

**State machine (D67, D40 shape):** new pure
`OnboardingStateMachine.swift`:

```swift
struct PermissionSnapshot { let micGranted: Bool
    let accessibilityTrusted: Bool; let listenEventGranted: Bool }
enum OnboardingStep: Equatable { case mic, accessibility, inputMonitoring, done
    static func resolve(_ s: PermissionSnapshot) -> OnboardingStep }
```

`resolve` = first ungranted in order mic → accessibility →
inputMonitoring, else `.done`. No stored step index — the UI is a
checklist of all three rows with live status glyphs; `resolve` picks
the highlighted "current" row. Headless-testable (8 combinations).

**Adapters (D14, no seams beyond a closure):** `Permissions.swift` gains
`static func isMicrophoneGranted() -> Bool`
(`AVCaptureDevice.authorizationStatus(for: .audio) == .authorized`,
`import AVFoundation`) and
`static func snapshot() -> PermissionSnapshot` composing the three
existing/new checks. Deep links opened via `NSWorkspace.shared.open`:
- AX: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- IM: `…?Privacy_ListenEvent`
- Fn: `x-apple.systempreferences:com.apple.Keyboard-Settings.extension`

**Window (D67):** new `OnboardingWindowController.swift`
(NSWindowController + NSHostingController) + `OnboardingView.swift`.
Fixed-size titled window ~480×420, centered, `NSApp.activate` on show
(LSUIElement — same reason as SettingsWindowController.show()). Live
status: injected `snapshotProvider: () -> PermissionSnapshot` (defaults
to `Permissions.snapshot`) polled by a 1 s `Timer` while visible (no
TCC change notifications exist), republished to the view. View: three
checklist rows (green `checkmark.circle.fill` / gray `circle`;
per-row action — "Allow Microphone…" fires the real request, AX/IM rows
open System Settings); a Fn footer: "Using the Fn key on older macOS?
Set System Settings → Keyboard → 'Press fn key to' → 'Do Nothing'" +
button (macOS 26 uses the chord, D27 — guidance only); bottom row
"Skip" (always enabled) + "Finish" (enabled at `.done` only) — both set
`onboardingCompleted` and close. `.done` shows a relaunch hint ("If the
hotkey doesn't respond, quit and reopen LotusScribe") for the
tap-created-before-grant case (whether delivery starts without restart
is AT-SCREEN verify 4 / Q7-4).

**Persistence:** `SettingsStore` gains `var onboardingCompleted: Bool`
(`defaults.bool` get / `set` write; absent → false; not a D9 pane key,
D25/R39 n/a to Bool).

**Launch hook + re-entry (D67):** in
`AppDelegate.applicationDidFinishLaunching`, inside the existing
`XCTestSessionIdentifier == nil` guard (a TCC-adjacent window must
never appear mid-`make test`), after the warm-up Task: if
`!SettingsStore().onboardingCompleted`, create + show the onboarding
controller (retained in a new private property). Existing
`requestListenEventAccess()` call stays (harmless — silently ignored,
phase-1). `StatusItemController` menu gains "Rerun Onboarding…" between
Settings… and Quit (lazy controller, same caching idiom as
`openSettings`) — reopens regardless of the flag; self-contained,
mirrors SettingsWindowController.

**R35 (LIVE):** OnboardingWindowController is a new composition root on
the launch path → construction-smoke test owed AT INTRODUCTION: hosted
test constructs it with a stubbed snapshotProvider (all-false), asserts
window non-nil + contentSize, `show()` + close — no real TCC touched
(request calls only fire from button taps).

**LoC:** OnboardingStateMachine.swift ≤ 40; OnboardingView.swift ≤ 130;
OnboardingWindowController.swift ≤ 90; Permissions.swift +≤ 18;
SettingsStore.swift +≤ 10; AppDelegate.swift +≤ 12;
StatusItemController.swift +≤ 14.

**Verify 7B**
1. MACHINE — `make test` ×2: `OnboardingStateMachineTests` (~9: all 8
   snapshot combinations + Equatable), `SettingsStoreTests` (+2: flag
   default false, roundtrip), R35 smoke (+1–2 in SmokeTests or a new
   hosted test), timer-tick republish via stubbed provider (+1).
2. MACHINE — grep: onboarding show is inside the
   `XCTestSessionIdentifier` guard; no `requestAccess` at construction.
3. AT-SCREEN — reset TCC (`tccutil reset All com.garisonlotus.LotusScribe`
   + mic), launch: onboarding appears; mic button fires the real prompt;
   AX/IM buttons land on the right System Settings panes; rows flip
   green live (≤1 s) after manual toggles; Finish enables at done; Skip
   works; relaunch → no onboarding; "Rerun Onboarding…" reopens it;
   Fn button opens Keyboard settings.
4. AT-SCREEN — after grants via onboarding, does the hotkey deliver
   without relaunch? (record answer; copy adjusts if yes)
5. BLOCKED-BATCH — full first-run → first dictation lands end-to-end.

## Sub-phase 7C — Release recipes (DMG / notarization, dry-run clean)

**Makefile targets (D71)** (+ helper `scripts/make-dmg.sh` so the
Makefile stays recipes-only):
- `release`: `xcodegen generate` then `xcodebuild … -configuration
  Release -derivedDataPath build build` (deterministic app path
  `build/Build/Products/Release/LotusScribe.app`).
- `dmg`: depends on `release`; script stages the .app + `/Applications`
  symlink, re-signs only when `SIGN_IDENTITY` is set (`codesign --force
  --deep --options runtime --timestamp` — hardened runtime, the
  notarization prerequisite), then `hdiutil create -volname LotusScribe
  -srcfolder <staging> -ov -format UDZO dist/LotusScribe-<version>.dmg`
  (version = CFBundleShortVersionString via `plutil -extract`; currently
  1.0). No `SIGN_IDENTITY` → dev-signed DMG, exit 0.
- `notarize`: exit 1 with a clear message unless `NOTARY_PROFILE` is
  set AND the DMG exists; else `xcrun notarytool submit dist/*.dmg
  --keychain-profile "$NOTARY_PROFILE" --wait`.
- `staple`: same gate; `xcrun stapler staple`.
Homebrew cask: **deferred** (Q7-3) — needs a notarized artifact at a
public URL; Makefile comment only. project.yml unchanged.

**LoC:** Makefile +≤ 30; scripts/make-dmg.sh ≤ 60. No XCTest delta.

**Verify 7C**
1. MACHINE — `make dmg` (no `SIGN_IDENTITY`) exits 0; `hdiutil attach`
   the DMG → contains `LotusScribe.app` + `Applications` symlink;
   `codesign -dv` on the mounted app succeeds (dev signature); detach.
2. MACHINE — `make notarize` and `make staple` without `NOTARY_PROFILE`
   exit non-zero, message names the missing credential and where it
   will come from. `make test` ×2 still green (no target regressions).
3. MACHINE — `spctl --assess` on the mounted app FAILS (expected — no
   Developer ID); record as the pre-creds baseline.
4. BLOCKED-USER — with Developer ID creds: `SIGN_IDENTITY=… make dmg`,
   `make notarize`, `make staple`, then `spctl --assess` passes.
5. BLOCKED-USER — clean install on a second Mac from the DMG:
   Gatekeeper passes, onboarding grants, first dictation works.

## Slicing / test deltas

Order 7A → 7B → 7C (7C is app-code-free; safe last). Independently
committable; none blocks on the D66 Sparkle sign-off. Expected totals:
baseline 191/19 → ~208–212 tests / 21 suites (+EndpointPresetTests,
+OnboardingStateMachineTests; 7C adds none).

D-rows touched: D7 (ruled via D66), D12/Q1 (kept), D14 (adapters), D23,
D25/R39 (n/a-Bool noted), D26 (presets draft-only), D27 (Fn copy),
D36–D38 (test-button vs Save split), D37/D44 (probe reuse), D40 (pure
shapes), D41, D42 (persist path untouched), R35 (LIVE — smoke owed),
R36 (test() cancels stale tasks), R40 (contentSize 740), R45, R49.

## Copy-ready block for when-vllm-is-back.md

- [ ] AT-SCREEN 7A: presets menu fills URL fields (models untouched);
      Test button → spinner → Connected / inline failure text; settings
      window shows all rows at 740 pt.
- [ ] AT-SCREEN 7B: `tccutil reset All com.garisonlotus.LotusScribe`,
      relaunch → onboarding appears; mic prompt fires from its button;
      AX/IM buttons open the correct System Settings panes; rows go
      green within ~1 s of manual grants; Finish gated on all-green;
      Skip closes and suppresses; "Rerun Onboarding…" menu item reopens;
      Fn footer button opens Keyboard settings.
- [ ] AT-SCREEN 7B: record whether the hotkey delivers post-grant
      WITHOUT relaunching (adjust done-step copy if it does).
- [ ] BLOCKED-BATCH 7B: fresh-permissions first dictation lands
      end-to-end after onboarding Finish.
- [ ] BLOCKED-USER D66/Q7-1: Sparkle ruling sign-off — architect
      recommends DEFER updates to v1.1, ship DMG-only (options: adopt
      now / defer / never).
- [ ] BLOCKED-USER Q7-2: Developer ID credentials — enroll paid Apple
      Developer, create "Developer ID Application" cert, `xcrun
      notarytool store-credentials` a keychain profile; then run
      `SIGN_IDENTITY=… make dmg && make notarize && make staple` and
      `spctl --assess` must pass.
- [ ] BLOCKED-USER: clean-install test on a second Mac from the stapled
      DMG (PLAN §7 verify).
- [ ] BLOCKED-USER Q7-3: Homebrew cask — decide artifact hosting
      (GitHub Releases?) after notarization exists.
