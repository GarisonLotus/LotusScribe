# Phase 10 Spec — Onboarding: setup step + hotkey-label clarity

Shape-only. Grounds every symbol against the live tree. Two user requests
(handoff §2): (1) spell the hotkey as "Command + F5"; (2) a new STT/LLM Setup
step before "Try it". Four independently-committable sub-phases, 4-way gate
each. Do NOT change app/networking/transcription semantics — presentation +
wiring to EXISTING settings machinery only. Reskin rules: LotusTheme only, no
raw hex, ≥11pt, honor Reduce Motion.

## Locked shape decisions (see architect log D89–D94)

- **Spelling = words joined by " + ": "Command + F5"** (user's phrasing), NOT
  glyphs "⌘F5". Driven by the REAL resolved chord (D87), never hardcoded.
- **Onboarding Setup persists via a buffered `SettingsDraft` committed on
  Continue** — mirrors the Settings window's own split (endpoints buffered;
  hotkey live write-through D83). D26 ("Save is sole store-write **in the
  Settings window**") is untouched — onboarding is a different window/draft.
- **Suggested models live on `EndpointPreset`** as new optional fields;
  `apply(to:)` stays unchanged (D69 — never sets model fields).
- **Featured stack is one-tap prefill:** Speaches `whisper-large-v3` (STT) +
  Ollama `llama3.2:3b` (LLM), both localhost. vLLM stays a preset, no headline.
- **Flow: Welcome → Permissions → Setup(NEW) → Try it.** Setup gate SKIPPABLE:
  Continue always enabled. Finish's all-green gate (D67) stays on Try it.

---

## 10A — Hotkey label clarity (Request 1) — ship first, quick win

Pure formatter + 3 call sites. No new step, no persistence.

**Deliverable**
- `HotkeyStateMachine.swift`: add PURE `HotkeyChord.spelledLabel: String`
  (D14). `.fnHold` → `"fn"`. `.combo(keyCode, modifiers)` → spell present
  modifiers in canonical order **Control, Option, Shift, Command**, then the
  key, joined by `" + "`. Key name via a private reverse lookup of the existing
  `functionKeyCodes` (→ `"F5"`) / `keyCodes` (→ uppercased `"9"`, `"Z"`);
  unknown keycode → `"key\(code)"` fallback. Examples the tests must pin:
  `.combo(96, .maskCommand)` → `"Command + F5"`; `.combo(96, [])` → `"F5"`;
  `.combo(25, [.maskControl,.maskAlternate,.maskCommand])` → `"Control + Option + Command + 9"`.
- `HotkeyPicker.swift`: redefine `HotkeyOption.displayLabel` to delegate —
  `.functionKey(n)` → `"F\(n)"`; `.custom(s)` → `(chord?.spelledLabel) ?? s`
  (unparseable partials fall back to raw). No new symbol; all existing
  `displayLabel` call sites (onboarding seed + `onReceive`, picker menu label)
  inherit the spelling automatically. No test references `displayLabel` today.
- `OnboardingView.swift`: the Try-it copy currently ignores the label — change
  the instructional line to interpolate `hotkeyLabel`, e.g.
  `"Hold \(hotkeyLabel) and talk:"`. HUD chip already reads `hotkeyLabel`.

**Files:** `HotkeyStateMachine.swift`, `HotkeyPicker.swift`, `OnboardingView.swift`.
**Pure/headless (D14):** `HotkeyChord.spelledLabel`. **UI:** copy + HUD read.
**Verify:** unit tests for the 3 pinned examples + fnHold + multi-modifier
order; build green; HUMAN-AT-SCREEN: onboarding HUD chip and Try-it copy read
"Command + F5" on a fresh install; picking F5 in the menu re-reads "F5".

---

## 10B — Setup step scaffold + renumber (pure mechanical UI)

Insert the 4th step as a placeholder; wire navigation. No persistence/fields
yet — Continue just advances.

**Deliverable (`OnboardingView.swift` only)**
- `stepIndex` map becomes 0 Welcome / 1 Permissions / 2 **Setup** / 3 Try it.
  `stepContent` switch: add `case 2: setupStep`, `default` → `tryItStep`.
- New `setupStep`: kicker `"STEP 3 OF 4"` + title "Set up your servers" +
  a placeholder `LotusCard` (filled in 10C/10D). Wrap step body in a
  `ScrollView` (480×480 is tight; Settings uses one).
- `progressDots`: `ForEach(0..<3)` → `ForEach(0..<4)`.
- `navBar`: add `case 2` — Back → 1, Continue → 3, **always enabled**
  (skippable). Try-it becomes `case 3` (Back → 2; Finish gated `.done`, D67).
- Kickers renumber to "OF 4": Welcome "STEP 1 OF 4", Permissions "STEP 2 OF 4",
  Setup "STEP 3 OF 4", Try it "STEP 4 OF 4".

**Pure/headless:** none. **UI:** all.
**Verify:** build green; HUMAN: 4 dots track; Skip only on Welcome; Continue on
Setup advances with no server info entered; Back reverses each step.

---

## 10C — Persistence + featured prefill + preset/model fields (Requests 2 + models)

**Deliverable**
- `EndpointPreset.swift`: add `let suggestedSTTModel: String? = nil` and
  `let suggestedLLMModel: String? = nil` (defaults keep the synthesized
  memberwise init source-compatible — existing `.all` entries and tests
  compile unchanged). Set Speaches `suggestedSTTModel: "whisper-large-v3"`,
  Ollama `suggestedLLMModel: "llama3.2:3b"`, vLLM both nil. Give the entries
  names — `static let speaches/ollama/vllm`, `all = [speaches, ollama, vllm]`
  — so onboarding can reference the featured two. `apply(to:)` UNCHANGED (D69).
- `OnboardingWindowController.swift`: own `draft = SettingsDraft(store:)` (like
  `SettingsWindowController`); inject `draft` + an `onSetupCommit` closure into
  `OnboardingView` (mirrors the existing `onSkip`/`onFinish` closures).
  `commitSetup()` = `draft.save()` — an explicit, UNGATED commit (skippable
  lock; no probe gate, no D42 warm-up — first run, unneeded). `draft.reload()`
  in `show()`.
- `OnboardingView.swift`: `setupStep` renders, reusing Settings idioms —
  `endpointField("Speech to Text endpoint", $draft.sttEndpointURL)`,
  `monoField` for `$draft.sttModel`, same for LLM. A primary
  **"Use recommended (Speaches + Ollama)"** button prefills all four via the
  presets: `EndpointPreset.speaches.apply(to: draft)` then
  `draft.sttModel = .speaches.suggestedSTTModel ?? draft.sttModel`, likewise
  Ollama for LLM. `navBar` `case 2` Continue calls `onSetupCommit()` then
  advances.

> **Reconciliation (D95):** "reusing Settings idioms" means the field-row
> builders (`labeledField`/`monoField`/`endpointField`) are mirrored as LOCAL
> `private` helpers in `OnboardingView.swift` — NOT the `private` SettingsForm
> symbols (accepted duplication; SettingsForm untouched). Preset fields ship as
> `var …: String? = nil` (not `let`) so the synthesized memberwise init stays
> source-compatible — a mechanical necessity, not a shape change.

**Pure/headless (D14):** the featured-prefill mapping (preset → draft field
values) is assertable; `EndpointPreset` field wiring.
**Files:** `EndpointPreset.swift`, `EndpointPresetTests.swift` (add suggested-
model assertions), `OnboardingWindowController.swift`, `OnboardingView.swift`.
**Verify:** unit — Speaches/Ollama carry the locked models, vLLM nil, prefill
fills all four draft fields; `apply(to:)` still never touches models. HUMAN:
"Use recommended" fills the fields; Continue then reopening Settings shows the
saved endpoints/models (proves commit hit the shared store).

---

## 10D — Install instructions + connection test (Request 2 content)

**Deliverable**
- `OnboardingView.swift`: two compact install `LotusCard`s (featured servers
  ONLY; vLLM gets none — stays a Settings preset). Each = short numbered steps
  + ONE copyable mono command (with a ghost "Copy" button →
  `NSPasteboard.general`) + a "Full docs" link (`NSWorkspace.open`). Content:
  - **Speaches (STT):** 1. Install Docker  2. Run Speaches  3. Serves at
    `localhost:8000`. Command: `docker run -p 8000:8000 ghcr.io/speaches-ai/speaches:latest`.
    Docs: `https://speaches.ai`.
  - **Ollama (LLM):** 1. Install Ollama  2. Pull the model  3. Serves at
    `localhost:11434`. Command: `ollama pull llama3.2:3b`. Docs: `https://ollama.com`.
- Connection test: `OnboardingWindowController` gains `probeState = ProbeState()`
  (reuse the existing type) + injected `sttProbe`/`llmProbe` seams (default
  `ConnectionProbe().testSTT/testLLM`, like `SettingsWindowController`) +
  `testSetupConnection()` that probes non-empty drafted STT then LLM
  sequentially (same shape as `SettingsWindowController.probeEndpoints`),
  publishing `.testing/.success/.failure`. Inject `probeState` + an
  `onSetupTest` closure into `OnboardingView`; a "Test connection" button in
  `setupStep` reflects `probeState.phase` inline (spinner / check / reason) —
  NEVER blocks Continue (skippable) and never persists.

**Pure/headless (D14):** the sequential-probe orchestration in the controller
is testable via injected seams (mirror `SettingsWindowControllerTests`).
**Files:** `OnboardingWindowController.swift`, `OnboardingView.swift`.
**Verify:** unit — probe orchestration skips empty URLs, stops at first
failure, sets phases; both-empty → no-op. HUMAN: Copy buttons copy the exact
commands; Test against a live/dead endpoint shows success/failure inline;
Continue still works while a test is idle or failed.

---

## 10E — "Try it" live test box (Request 3) — ship BEFORE 10D

The Try-it step (step 4) has no editable target, so real insertion — which
`TextInserter` lands in the system-wide FOCUSED element — has nowhere to go and
the step looks dead. Fix: a focused editable box that receives the ACTUAL
pipeline output (authentic end-to-end, NOT a preview sink) + an inline "no
text? → Setup" hint on empty/failed dictation. Sequenced BEFORE 10D so the step
is provably live before install content lands. Two sub-phases (risk split).
Rails: the dictation pipeline is UNCHANGED — the seam is purely observational
and additive (behavior identical when the callback is nil). Reskin: LotusTheme
only, no raw hex, ≥11pt, honor Reduce Motion.

### 10E1 — DictationController outcome seam + observation wiring (headless)

**Deliverable**
- `DictationController.swift`: add `enum DictationOutcome: String { case
  inserted, empty, failed, tooShort }` and `var onOutcome: ((DictationOutcome)
  -> Void)?` — mirrors `onListeningChanged` (nil in headless tests, main-actor,
  additive). Fire at the EXISTING branch points in `stopRecording()`, current
  generation only, NEVER for stale-dropped Tasks:
  - `.tooShort` — the `guard hasUsableAudio` else branch (after "capture too
    short", by `pill.hide()`), synchronous, pre-Task → always current.
  - `.empty` — the `guard !text.isEmpty` else branch ("empty transcript"), past
    the D23 stale guard → current.
  - `.inserted` — after `inserter.insert(text)` + `pill.update(terminal)` (past
    the D43 post-cleanup re-check) → current.
  - `.failed` — the transcription `catch`, INSIDE the existing
    `capturedGeneration == generation` guard (never fire on stale failure).
  - The two stale-drop returns fire NOTHING.
- `DictationController.shouldShowSetupHint(for: DictationOutcome?) -> Bool` —
  PURE (D14): `true` iff `.empty` or `.failed`. Single source for the hint.
- `AppDelegate.swift`: wire `dictation.onOutcome` beside `onListeningChanged`
  to `NotificationCenter.default.post(name: .lotusDictationOutcome, …,
  userInfo: ["outcome": outcome.rawValue])`. Add `Notification.Name
  .lotusDictationOutcome` (idiom of `.lotusHotkeyChanged`). Loosest coupling:
  no window reference; DictationController stays NotificationCenter-free.

**Pure/headless (D14):** `shouldShowSetupHint`; the outcome→rawValue transport.
**Files:** `DictationController.swift`, `AppDelegate.swift`, `DictationControllerTests.swift`.
**Verify:** unit — predicate maps empty/failed→true, inserted/tooShort→false;
`onOutcome` nil → loop behavior unchanged. Build green.

### 10E2 — Try-it focused box + inline hint (human-verified)

> **DE-RISK FIRST (engineer step 1, before the hint):** build the focused box
> and manually confirm a REAL dictation lands text in it — against a REACHABLE
> STT endpoint (localhost recommended returns nothing unless running; the
> user's reachable vLLM is the practical target). If self-insertion fails (AX
> `kAXSelectedText` not settable on the SwiftUI field AND Cmd-V does not
> self-paste), STOP and surface. Contingency = preview-sink fallback — a
> fallback ONLY, not the plan.

**Deliverable (`OnboardingView.swift`)**
- `tryItStep`: KEEP `HotkeyPicker()`. Replace the decorative `HUDPreview` with
  a focused, editable multi-line box (LotusTheme-styled, mono, like `monoField`
  but taller). Prompt: "Hold \(hotkeyLabel) and speak — your words appear
  here." The real `PillController` panel already gives live listening feedback,
  so `HUDPreview` becomes orphaned → remove it (own-change cleanup, CLAUDE.md §3).
- Focus: `@FocusState private var tryItFocused`, set `true` when the step
  reaches `stepIndex == 3` (on appear / on change) so the box is first
  responder and a synthesized Cmd-V lands. Window is already key/active
  (`makeKeyAndOrderFront` + `NSApp.activate`); LSUIElement is no obstacle — the
  picker's custom field already accepts key input today.
- Inline hint: `@State lastOutcome`, updated via
  `.onReceive(publisher(for: .lotusDictationOutcome))` (SwiftUI auto-tears-down
  on window close → a closed window never reacts; no manual clear). Show the
  hint iff `stepIndex == 3 && DictationController.shouldShowSetupHint(for:
  lastOutcome)`: a note "No text? Check your servers." + a "Back to setup"
  button → `stepIndex = 2`. `.inserted` clears it.

**Pure/headless (D14):** none new (predicate lives in 10E1). **UI:** all.
**Files:** `OnboardingView.swift`.
**Verify:** HUMAN-AT-SCREEN — with a reachable STT: hold hotkey on step 4, real
transcript appears in the box; empty/failed (servers down) shows the hint and
"Back to setup" jumps to step 3; box is focused on entering step 4.

---

## Sub-phase summary

| ID | Deliverable | Headless (D14) | Files |
|----|-------------|----------------|-------|
| 10A | "Command + F5" spelled label | `HotkeyChord.spelledLabel` | HotkeyStateMachine, HotkeyPicker, OnboardingView |
| 10B | 4th step scaffold + renumber | — | OnboardingView |
| 10C | Persistence + featured prefill + fields | prefill map, preset fields | EndpointPreset(+Tests), OnboardingWindowController, OnboardingView |
| 10E | Try-it live test box (before 10D): E1 outcome seam+wiring, E2 focused box+hint | `shouldShowSetupHint`, seam | DictationController(+Tests), AppDelegate, OnboardingView |
| 10D | Install cards + connection test | probe orchestration | OnboardingWindowController, OnboardingView |
| 10F | "Hold Command + F5" clarity: picker label fix + Try-it why-line + collision-copy redesign | `HotkeyChord.usesMicKey`, `HotkeyCollision.warning` map | HotkeyStateMachine, HotkeyPicker, OnboardingView, HotkeyCollisionTests |

---

## §10F — "Hold Command + F5" clarity (copy + labels only; D101–D104)

Reconciles the stale F5 collision guidance with the ⌘F5 default (D87) and makes
onboarding say the hotkey is HELD as **Command + F5**. COPY/LABEL/lookup-TABLE
only — no binding/parse/swallow change (D80–D88 intact). Reskin: LotusTheme,
≥11pt, no raw hex. Superset matching (`handleCombo`, `flags.isSuperset(of:)`)
already makes "Hold Command + F5" fire BOTH the ⌘F5 default AND a bare-F5 pick,
so this is pure reconciliation, not logic. Resolves reviewer item **R10A-1**.

**1. Picker collapsed-label fix (R10A-1).** `HotkeyPicker.swift` line 90
`Text(isCustom ? "Custom" : option.displayLabel)` collapses the custom ⌘F5
default to the literal "Custom". Change to
`Text(option.displayLabel.isEmpty ? "Custom…" : option.displayLabel)` — a custom
chord now shows its spelled label (default `.custom("cmd+f5")` →
`displayLabel` → `"Command + F5"`). The `Button("Custom…")` MENU ITEM (line 87)
that reveals the text field is UNTOUCHED; the "Custom…" placeholder shows only
while the field is empty. `isCustom` stays (gates the field, lines 105/130).

**2. Try-it why-line (`OnboardingView.swift`).** The instruction (line 205)
already leads with the resolved chord: "Hold \(hotkeyLabel) and speak…"
(default → "Hold Command + F5…"). ADD one why-line UNDER it, shown ONLY when the
resolved chord's key is F5 (keycode 96): "F5 is macOS's mic key — holding
Command lets LotusScribe catch it." For non-F5 chords the why-line is HIDDEN (the
"why" is F5-specific; a generic line is noise). Condition derives from a new
PURE `HotkeyChord.usesMicKey` (D14): `if case .combo(96, _) = self { true }`.
Mirror `hotkeyLabel`: add `@State hotkeyUsesMicKey =
HotkeyOption.from(persisted: SettingsStore().hotkeyChord).chord?.usesMicKey ??
false`, refreshed beside `hotkeyLabel` (line 68). Style `.lotusCaption` (11pt) /
`.lotusTextSecondary`.

**3. Collision-copy redesign** (`HotkeyCollision.warning(for:)`, supersedes D86
copy; chord-based per R9E-2/3). Cases:
- ⌘F5 `.combo(96, .maskCommand)` — the WORKING default: NO warning (already the
  `default:` → nil arm; keep nil, add NO tip — an orange tip on the default is
  the alarm we remove; the label + why-line carry the calm explanation).
- bare F5 `.combo(96, [])`: LEAD with the working path — message "Hold Command +
  F5 — F5 alone is macOS's mic key. To use bare F5 instead, turn off macOS's
  Dictation and Siri hold-key shortcuts." KEEP BOTH links (Siri, Keyboard — bare
  F5 is double-claimed). No longer reads as an error for a chord that works.
- `.fnHold`: UNCHANGED (globe message + Keyboard link).

**4. No migration for legacy persisted `"f5"`.** The improved bare-F5 warning +
"hold Command" copy make bare-f5 usable; adding migration code is out of scope.
Tester note: `defaults delete com.garisonlotus.LotusScribe hotkeyChord` to see
the true nil→⌘F5 default.

**Slice:** ONE sub-phase (10F). **Headless (D14):** `HotkeyChord.usesMicKey`
predicate; the new `warning(for:)` mapping. **Files:** `HotkeyStateMachine.swift`
(add `usesMicKey`), `HotkeyPicker.swift` (label + warning map), `OnboardingView.swift`
(why-line), `HotkeyCollisionTests.swift` (retarget: bare-F5 message leads with
"Command", still 2 panes; add ⌘F5-is-clean + `usesMicKey` cases).
**Verify:** unit — `warning(.custom("cmd+f5")) == nil`; bare-F5 message contains
"Command"; `usesMicKey` true for `.combo(96,_)`, false otherwise. HUMAN — picker
shows "Command + F5" (not "Custom") on the default; Try-it why-line visible on
F5, hidden on e.g. ctrl+alt+9; no alarm on the ⌘F5 default.
