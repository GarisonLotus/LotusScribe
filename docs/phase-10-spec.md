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

## Sub-phase summary

| ID | Deliverable | Headless (D14) | Files |
|----|-------------|----------------|-------|
| 10A | "Command + F5" spelled label | `HotkeyChord.spelledLabel` | HotkeyStateMachine, HotkeyPicker, OnboardingView |
| 10B | 4th step scaffold + renumber | — | OnboardingView |
| 10C | Persistence + featured prefill + fields | prefill map, preset fields | EndpointPreset(+Tests), OnboardingWindowController, OnboardingView |
| 10D | Install cards + connection test | probe orchestration | OnboardingWindowController, OnboardingView |
