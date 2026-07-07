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

**Where we are:** 10A + 10B + 10C CLOSED. 10C = real STT/LLM endpoint+model
fields on the Setup step, "Use recommended (Speaches+Ollama)" prefill,
persistence via a buffered `SettingsDraft` committed on Continue (D90/D91;
D95 accepted local field-builder duplication). Reviewer APPROVE + architect
non-objection, 258/24. Next: **10E** (see below), then 10D.
**Baseline tests:** 271 tests / 24 suites green.
**Active gate:** ALL of 10A–10G cleared. **PHASE 10 CODE-COMPLETE.**
10D = install cards (Speaches/Ollama, copyable command + docs link) +
read-only Test-connection button (mirrors SettingsWindowController probe;
never persists, never blocks Continue). Reviewer APPROVE + tester PASS (+5).
Remaining human glance (non-blocking): 10D install-card Copy/Test-connection
click-through.
10F = "Hold Command + F5" clarity: picker label fix (R10A-1), F5-only why-line
(`usesMicKey`), collision-copy redesign (⌘F5 clean, bare-F5 leads with
"Command"). Reviewer APPROVE + tester PASS (266/24). NOTE: 10F's code is
correct for any chord; its F5-specific copy only appears when a user PICKS
F5 — moot for the new ⌃⌥D default but retained for F5 pickers.

**NEW — 10G default hotkey OFF F5 (user-decided 2026-07-06):** ⌘F5 is a bad
default — F5 is Apple's accessibility key and EVERY combo is a system
accessibility shortcut handled ABOVE our session tap (can't be swallowed):
F5→Dictation, ⌘F5→VoiceOver, ⌥⌘F5→Accessibility panel. Live-confirmed ⌘F5
triggers the VoiceOver enable-prompt even with Input Monitoring granted.
Decision: default hotkey → **⌃⌥D (Ctrl+Option+D, `.combo(2, [.maskControl,
.maskAlternate])`)**, LIVE-VERIFIED working (dictation fires, no collision, no
stray "d"). Supersedes D87. 10G = flip the two default sites
(`HotkeyChord.resolved`, `HotkeyOption.from(nil)`) + retarget the ⌘F5-default
tests + docs. Picker still offers F-keys (10F warns on F5). Forward item:
ALL top-row F-keys are media/accessibility traps on MacBooks — the F1–F12
picker menu is a latent trap beyond F5; revisit if desired.
10E2 = Try-it focused `TextEditor` box + inline "no text? → Setup" hint;
`HUDPreview` removed. SPIKE PASSED: real transcript inserts into the app's
own focused box (⌘F5 end-to-end + 10C persistence confirmed).

**NEW — 10F Command+F5 guidance (user-surfaced 2026-07-06):** onboarding does
NOT explain that the working hotkey is HELD as **Command + F5**. On mic-key
laptops F5 alone is macOS's mic key (never emits keycode 96); Command frees it
(D87). But: (a) the picker DROPDOWN shows "Custom" / a bare "F5" label, not
"Command + F5" (R10A-1); (b) the F5 collision warning (D86) still says "turn
off Dictation" — outdated guidance; the real fix is HOLD COMMAND. (c) Picking
bare "F5" from the F1–F12 menu yields a non-working hotkey on these laptops.
Also the test machine has a stale persisted `hotkeyChord="f5"` (bare) — real
default is nil→⌘F5. 10F must make onboarding clearly say "Hold Command + F5"
and why, and reconcile the collision copy with D87.

**NEW — 10E "Try it" live test box (user-surfaced 2026-07-06):** the current
Try-it step has NO editable target, so dictated text (which `TextInserter`
lands in the system-wide FOCUSED element) has nowhere to go — step 4 appears
dead. Fix = a focused TextField on Try-it receiving REAL insertion
(user-chosen: authentic end-to-end, not a preview sink) + an inline "no text?
→ Setup" hint on empty/failed dictation. Needs: (1) a `DictationController`
outcome signal (mirror `onListeningChanged`) so onboarding knows a dictation
happened + its result; (2) EARLY empirical de-risk that the app can insert
into its OWN focused field (AX set-selected-text or Cmd-V self-paste). Also
note: a real test needs a REACHABLE STT endpoint — localhost recommended
won't return text unless the user runs those servers.
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
