# Team Handoff — LotusScribe (Phase 3)

> If you are a restarting orchestrator, this is your single entry point.
> Read top to bottom, then the three phase-3 role logs, then verify git
> state. Docs carry phase numbers (CLAUDE.md §5); phase-0/1/2 files are
> the archives of those phases.

**Last updated:** 2026-07-05, mid-3C — engineer dispatch died (session limit); see §3 resume point.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`). Handoff covers
project state; skill covers framework.

## §2. Project context

LotusScribe: native Swift macOS menu bar app — hold hotkey → speak →
release → STT over HTTP → LLM cleanup over HTTP → text lands in the
focused app. Phases 0–2 complete (scaffold, core loop, pill overlay +
swallowing + cold-start). Phase 3 = 3A settings save-test (user-directed
addition, pulled forward from Phase 7.3) then 3B+ LLM cleanup per
PLAN.md.

Primary references:
- `PLAN.md` — authoritative design doc; §Phase 3 (with 3A annotation)
- `docs/phase-3-spec.md` — active spec (§3A authored; 3B+ appended when
  LLM cleanup starts)
- `CLAUDE.md` — behavioral guidelines + docs naming (§5)

## §3. Current state

**Where we are:** 3A IMPLEMENTED, 4-way GATED, COMMITTED 4f21c17
(ConnectionProbe + probe-gated Save per D36/D37/D38; reviewer R36/R37
notes; architect ratified lean items; 89/13 green ×2 ×3 runners).
Sheet labels renamed per user directive 2026-07-05: Save Anyway (was
Close Anyway), Try Again (was Cancel) — behavior unchanged, orchestrator
trivial-change edit, rides in the label-rename commit after 4f21c17.

**3A CLOSED 2026-07-05:** human verify 2–5 all passed (user-confirmed
at 638b11d).

**3B CLOSED 2026-07-05** at 2083eb0 (human gate: primary path
user-confirmed; negative paths waived, unit-covered).

**Where we are (2026-07-05, evening):** all automated work done and
pushed.3C 7d5ecf7 + D45 81e6dbe (cleanup /no_think + 8 s) + 3D
7f7c8a4 (two-stage pill: STT check, cleanup check, amber miss —
D46–D48) + debt sweeps a5960da (R3/R30/R32/R40) and 75822bc (D49
closes R31; R4 closed moot-until-API-key). Backlog now note-only:
R34/R41/R42, R7 (Phase 7+), R35 rule.

**BLOCKED — user lost access to the vLLM host.** Every HUMAN-AT-SCREEN
item needs live STT, so all are queued until vLLM (or another Whisper
endpoint) is back:
1.3B/D45 re-verify: filler dictation returns CLEANED text (was 100%
   timeout pre-D45; never yet verified live).
2.3D verify 2–4: two-stage pill (check → spinner → check), amber on
   forced miss (Save Anyway a bogus LLM URL), STT-only single-check
   regression.
3.3C verify: picker persists; failure sheet names the endpoint;
   390 pt window fit; D38 dictation regression.
4.D49: dead-tap recovery (non-gating).
Then the Phase-3 close gate (architect declares complete or names 3E).

**Cleanup endpoint context:** user plans local Ollama for cleanup.
Local `qwen3.6:35b-mlx` is UNUSABLE for the 8 s budget (11–14 s; its
Ollama template ignores /no_think — 935 think tokens measured).
Recommended: `ollama pull llama3.2:3b` (user must pull), then LLM URL
http://localhost:11434/v1/chat/completions, model llama3.2:3b.
Verified-working alternative when vLLM returns:
https://vllm.garison.com/v1/chat/completions + Qwen/Qwen3.6-35B-A3B-FP8
(~3.4 s with /no_think).

**Baseline:** 126 tests / 16 suites green ×2 at 75822bc.

**Working tree:** untracked RESEARCH.md, claude.md (user's files).

## §4. Roles

One-shot sub-agents; orchestrator persists. Templates:
`/Users/garisondraper/.claude/skills/phased-delivery/references/briefing-templates.md`.
Engineer specialty: macos-engineer (Swift/AppKit/SwiftUI).

| Role | State file |
|---|---|
| architect | docs/phase-3-architect-log.md |
| reviewer | docs/phase-3-reviewer-observations.md |
| tester | docs/phase-3-tester-baselines.md |

## §5. Operating rules

Per skill. Project-specific:
- Toolchain: Xcode 26.6, xcodegen, Swift Testing; `make generate/build/test`.
- Docs naming: `phase-N-<name>.md` (CLAUDE.md §5).
- TCC-bearing runtime checks need the user at the screen —
  HUMAN-AT-SCREEN items are marked explicitly in the spec.
- Launch recipe: `pkill -x LotusScribe; make build; open <DerivedData
  app path>` — verify launch via `/usr/bin/log stream` subsystem
  `com.garisonlotus.LotusScribe` (zsh shadows `log`).

## §6. Locked decisions carried forward

D1–D28 (phase-0/1 logs), D29–D35 (phase-2 log; D29a rescinded by D34),
D36–D38 locked in docs/phase-3-architect-log.md.

## §7. Open decisions / questions

- R4 (carried): close by exercising a Keychain read under the new
  identity — 3A touches settings; opportunity if a key field is read.

## §8. Non-blocking items

Carried in docs/phase-3-reviewer-observations.md: R3, R7, R30, R31,
R32, R34, R35.

## §9. How to resume

Skill's Resume-from-crash pattern; phase-3 file set + this doc.

## §10. Reference index

- `docs/phase-3-spec.md` — active spec
- `docs/phase-3-architect-log.md` / `docs/phase-3-reviewer-observations.md`
  / `docs/phase-3-tester-baselines.md` — role logs
- `docs/phase-0/1/2-*.md` — archives
- Tooling: Makefile (generate/build/test)

## §11. Revision notes

Rev A — Phase 3 bootstrap (3A save-test spec + docs set), 2026-07-05.
