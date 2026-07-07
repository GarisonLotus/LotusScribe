# Team Handoff — LotusScribe (Phase 10)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-10 role logs, then verify git state. Phase 0–9 docs are archives.

**Last updated:** 2026-07-06, Phase 10 bootstrap — architect spec dispatched.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`). Docs are
phase-numbered (CLAUDE.md §5): `docs/phase-10-*.md`.

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app (LSUIElement). Phases
0–8 built the pipeline; a "Lotus Bloom" reskin + Phase 9 (user-selectable
hotkey) landed 2026-07-06. Phase 9 closed at commit `03f4ebe` with the
Input Monitoring fix (D88) and the ⌘F5 default (D87).

**Phase 10 = ONBOARDING: server-setup step + hotkey-label clarity.** Two
user requests:

1. **Hotkey label clarity.** The onboarding "Try it" step (and its HUD chip)
   must spell out that the user holds **Command + their chosen key** — it
   should read "Command + F5" by default, not the bare "F5"/"cmd+f5" it
   shows today. Ties to D87 (default is ⌘F5).
2. **New STT/LLM setup step, inserted BEFORE "Try it".** Onboarding grows
   from 3 steps to 4: Welcome → Permissions → **Setup (NEW)** → Try it. The
   Setup step walks the user through the endpoint presets, shows concise
   install instructions for the servers, suggests models, and lets them test
   the connection — all BEFORE they test the hotkey.

## §3. Locked product decisions (from user, 2026-07-06)

- **Gate = SKIPPABLE.** The Setup step offers a "Test connection" but does
  NOT block Continue. Users can finish setup later in Settings.
- **Featured recommended stack = ALL-LOCAL: Speaches (STT, `whisper-large-v3`)
  + Ollama (LLM cleanup, `llama3.2:3b`).** Both localhost. (vLLM stays a
  preset but is not the headline recommendation.)
- **Install guide format = concise numbered steps + ONE copyable command +
  a "full docs" link** per server. Must fit the 480×480 onboarding window;
  no wall-of-text inline walkthrough.

## §4. Current state

**Where we are:** 10A + 10B CLOSED. 10B = 4th step scaffold ("Set up your
servers" placeholder) + renumber to 4 steps (reviewer APPROVE, build green,
human-verified visual flow). Next: 10C (real STT/LLM fields + "Use
recommended" prefill + persistence). Slice/decisions in
`phase-10-architect-log.md` (D89–D94); spec in `phase-10-spec.md`.
**Baseline tests:** 254 tests / 24 suites green (10B added no tests).
**Active gate:** 10A + 10B cleared; 10C not started.
**Open forward items:** R10A-1 — the Settings hotkey picker DROPDOWN still
prints literal "Custom" for a custom chord, so the ⌘F5 default reads "Custom"
there (not "Command + F5"). Onboarding copy/HUD are correct; this is a
separate Settings surface. Fold a one-line fix (show `displayLabel`) into a
later sub-phase or a tidy-up commit if the user wants it.

## §5. Load-bearing constraints (do not break)

- **D87 (phase-9-architect-log):** default hotkey is ⌘F5 (`.combo(96,
  .maskCommand)`); on mic-key laptops bare F5 never emits keycode 96, Command
  frees it. The label work must reflect the REAL resolved chord + modifiers,
  not hardcode "Command + F5".
- **D88:** Input Monitoring request lives in `main.swift` before any AX check
  (rdar://7381305). Do not touch that ordering.
- **D26/D69 (settings):** endpoint presets fill a buffered `SettingsDraft`;
  Save is the sole store-write path in the Settings window. The onboarding
  step must NOT quietly bypass that contract — architect decides how the step
  persists (draft+save vs a dedicated write path) and records it.
- **D14:** pure/headless logic separated from TCC/UI for testability.
- Reskin rules: no raw hex in views, LotusTheme components only, respect the
  design system, min 11pt text, honor Reduce Motion.
- App logic / networking / transcription / persistence semantics unchanged —
  this is onboarding presentation + wiring to EXISTING settings machinery.

## §6. Pointers

- Spec: `docs/phase-10-spec.md` (architect authoring)
- Architect decisions: `docs/phase-10-architect-log.md`
- Reviewer items: `docs/phase-10-reviewer-observations.md`
- Tester baselines: `docs/phase-10-tester-baselines.md`
- Key existing code: `OnboardingView.swift` (3-step flow to extend),
  `EndpointPreset.swift` (presets), `ConnectionProbe.swift` (testSTT/testLLM),
  `SettingsForm.swift` (429 lines — the existing endpoint/model/preset UI to
  mirror), `SettingsStore.swift` / `SettingsDraft`, `HotkeyPicker.swift`
  (`HotkeyOption.displayLabel` — the label to enrich).
