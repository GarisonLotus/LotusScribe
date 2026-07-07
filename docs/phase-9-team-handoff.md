# Team Handoff — LotusScribe (Phase 9)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-9 role logs, then verify git state. Phase-0…8 docs are archives.

**Last updated:** 2026-07-06, Phase 9 bootstrap — architect spec dispatched.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`).

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app. Phases 0–8 built.
A "Lotus Bloom" reskin (undocumented, non-phased) landed on 2026-07-06
(design system, settings/onboarding/HUD reskin, menu-bar icon) plus
permission-flow fixes.

**Phase 9 = USER-SELECTABLE HOTKEY.** Live-test finding: onboarding step 3
told the user to "hold fn", but D27 established that macOS 26 delivers NO
Fn events to session taps — fn is dead on the user's OS. The real working
hotkey has been a combo (`ctrl+alt+cmd+9`). User wants:

1. Default hotkey = **F5** (the mac "dictation/mic" key), hold-to-talk.
2. A **user-selectable key** on onboarding step 3 AND in Settings.
3. Picker offers **function keys F1–F12 + a custom modifier-combo field**.
4. Changes take effect **immediately (live re-bind)** — no relaunch.

macOS-side prerequisite (guidance, not code): user disables the system
Dictation shortcut and uses standard function keys so F5 (keycode 96)
reaches the session tap.

## §3. Current state

**Where we are:** Phase 9 CODE-COMPLETE + LIVE-VERIFIED. 9A–9E committed;
post-9E landed two live-debug fixes (D87 ⌘F5 default, D88 Input Monitoring
ordering) in one commit.
**Baseline tests:** 249 tests / 24 suites green (unchanged count; 6 default
assertions retargeted F5→⌘F5).
**Active gate:** all sub-phases cleared.

**RESOLVED — empirical hotkey acceptance (human-at-screen, 2026-07-06):**
- Input Monitoring now grants (D88: request moved to main.swift before any
  AX check; rdar://7381305).
- F5 was DEAD like fn: on this laptop F5 is the hardware mic key, bare F5
  never emits keycode 96 (system eats it → beep + "enable Dictation?").
  **Command** frees keycode 96 (Ctrl/Option don't). New default = **⌘F5**
  (D87), live-confirmed: hold ⌘F5 → pill appears. Phase 9 done.

## §4. Load-bearing constraints (do not break)

- **D30 swallow pair-balance** (phase-2-architect-log): chord keyDown/keyUp
  swallowing is pair-balanced — no app ever sees half a down/up pair.
  HotkeyStateMachine.handleCombo already implements this; any bare-key
  support must preserve it.
- **D27**: fn is dead on macOS 26 session taps. Keep `.fnHold` in code for
  older macOS, but it is NOT the default and NOT offered as the primary UI
  choice.
- **R7**: combo keycodes are ANSI-positional (kVK_ANSI_*). The picker maps
  UI labels → keycodes; document the positional caveat.
- Reskin rules still apply to any UI: no raw hex in views, use LotusTheme
  components, respect the design system.

## §5. Pointers

- Architect decisions: docs/phase-9-architect-log.md
- Reviewer items: docs/phase-9-reviewer-observations.md
- Tester baselines: docs/phase-9-tester-baselines.md
- Spec: docs/phase-9-spec.md (architect authoring)
