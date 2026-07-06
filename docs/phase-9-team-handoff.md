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

**Where we are:** 9A+9B committed. Next: 9C (live re-bind seam).
**Baseline tests:** 242 tests / 22 suites green (9B close).
**Active gate:** 9A cleared (reviewer APPROVE). 9B given a lightweight
orchestrator gate (trivial: store property mirroring 5 existing ones + a
1-line default swap onto the already-reviewed `resolved()`; spot-checked,
tests green). 9C gets a full reviewer gate (AppDelegate restructure).

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
