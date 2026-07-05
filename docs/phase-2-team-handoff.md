# Team Handoff — LotusScribe (Phase 2)

> If you are a restarting orchestrator, this is your single entry point.
> Read top to bottom, then the three phase-2 role logs, then verify git
> state. Docs carry phase numbers (CLAUDE.md §5); phase-0/phase-1 files
> are the archives of those phases.

**Last updated:** 2026-07-04, Phase 2 spec authored — implementation not started.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`). Handoff covers
project state; skill covers framework.

## §2. Project context

LotusScribe: native Swift macOS menu bar app — hold hotkey → speak → release
→ STT over HTTP → LLM cleanup over HTTP → text lands in the focused app.
Phases 0 (scaffold) and 1 (core loop) complete. Phase 2 = pill overlay
(NSPanel + SwiftUI waveform) PLUS two Phase-1 promotions: event swallowing
(D28→D30) and cold-start mitigation (Q4→D29).

Primary references:
- `PLAN.md` — authoritative design doc; §"Phase 2" is the active scope
- `docs/phase-2-spec.md` — active spec (sub-phases 2A/2B/2C)
- `CLAUDE.md` — behavioral guidelines + docs naming (§5)

## §3. Current state

**Where we are:** Phase 1 complete and pushed at b148cff (stable
personal-team signing 5RC66Q82V9, empty-audio guard, full empirical TCC
record in docs/phase-1-tester-baselines.md). Phase 2 spec authored
2026-07-04; no Phase 2 code exists yet.

**Baseline:** 54 tests / 9 suites green at b148cff (see phase-2 tester file).

**Key facts for Phase 2:**
- STT endpoint live: https://vllm.garison.com/v1/audio/transcriptions,
  model whisper-large-v3, no key (D13).
- Chord ctrl+alt+cmd+9 is the working hotkey (D27 — Fn dead on macOS 26).
- Input Monitoring + Accessibility already granted; Q5 (phase-2 log) asks
  whether `.defaultTap` works under those grants — 2A human verify.
- R23 lesson binds 2B: explicit `setContentSize`, test `contentLayoutRect`.

**Active sub-phase:** none — next step is dispatching 2A (swallowing + RMS,
pure logic first). Slicing: 2A → 2B (pill panel + view, unreachable but
committable) → 2C (state wiring + cold-start, HUMAN-AT-SCREEN phase gate).

**Working tree:** untracked RESEARCH.md, claude.md (user's files).

## §4. Roles

One-shot sub-agents; orchestrator persists. Templates:
`/Users/garisondraper/.claude/skills/phased-delivery/references/briefing-templates.md`.
Engineer specialty: macos-engineer (Swift/AppKit/SwiftUI).

| Role | State file |
|---|---|
| architect | docs/phase-2-architect-log.md |
| reviewer | docs/phase-2-reviewer-observations.md |
| tester | docs/phase-2-tester-baselines.md |

## §5. Operating rules

Per skill. Project-specific:
- Toolchain: Xcode 26.6, xcodegen, Swift Testing; `make generate/build/test`.
- Docs naming: `phase-N-<name>.md` (CLAUDE.md §5).
- TCC-bearing runtime checks (mic, tap, pill visuals) need the user at the
  screen — HUMAN-AT-SCREEN items are marked explicitly in the spec.

## §6. Locked decisions carried forward

D1–D11 (phase-0 log) and D12–D28 (phase-1 log) remain binding. New phase-2
decisions D29–D32 locked in docs/phase-2-architect-log.md: D29 cold-start
(prepare() + pill warming-truth), D30 swallowing (.defaultTap, pair-balanced,
.listenOnly fallback), D31 PillMetrics constants, D32 RMS plumbing.

## §7. Open decisions / questions

- Q5: `.defaultTap` under existing TCC grants — empirical, 2A verify 3.
- R4 (carried): close by exercising a Keychain read under the new identity.

## §8. Non-blocking items

- R3 (carried): 0A smoke test still link-smoke; repoint when convenient.
- R7 (carried): ANSI-positional keycodes — revisit at hotkey-config UI.

## §9. How to resume

Skill's Resume-from-crash pattern; phase-2 file set + this doc.

## §10. Reference index

- `docs/phase-2-spec.md` — active spec
- `docs/phase-2-architect-log.md` / `docs/phase-2-reviewer-observations.md`
  / `docs/phase-2-tester-baselines.md` — role logs
- `docs/phase-0-*.md`, `docs/phase-1-*.md` — archives
- Tooling: Makefile (generate/build/test)

## §11. Revision notes

Rev A — Phase 2 bootstrap (spec + docs set), 2026-07-04.
