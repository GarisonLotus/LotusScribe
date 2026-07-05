# Team Handoff — LotusScribe (Phase 4)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-4 role logs, then verify git state. Phase-0/1/2/3 docs are
> archives — EXCEPT the Phase-3 human gate, which is still OPEN (see §3).

**Last updated:** 2026-07-05, Phase 4 bootstrap — next is dispatching 4A.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`).

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app (hold chord →
speak → STT → LLM cleanup → insert). Phases 0–2 complete; Phase 3
(save-test, LLM cleanup, two-stage pill) built + machine-gated, human
gate BLOCKED on vLLM access. Phase 4 = app-aware context per PLAN.md
§Phase 4 (user-directed start while blocked).

References: `PLAN.md` §Phase 4; `docs/phase-4-spec.md` (4A/4B/4C);
`CLAUDE.md` §5 (docs naming).

## §3. Current state

**Where we are:** Phase 4 bootstrapped (spec + docs set staged, D50–D55
locked). Baseline 126 tests / 16 suites at 75822bc.

**RESUME POINT (next):** dispatch 4A engineer per spec §4A (AppCategory
map + prompt composition + service plumbing, pure/headless; D51
byte-identity floor for `.other`). Then 4B (key-down capture adapter),
4C (override UI). Gate each; commit each.

**BLOCKED-BATCH queue (needs vLLM/STT back):** Phase-3 human gate
(D45 cleaned dictation, 3D two-stage pill + amber, 3C settings checks,
D49 dead-tap non-gating) + Phase-4 tone-effect verifies (4B/4C) +
Phase-3 close gate, then Phase-4 close gate. Q4-1 (builtin map
confirmation) batches there too.

**Cleanup endpoints:** vLLM (verified, down): chat/completions +
Qwen/Qwen3.6-35B-A3B-FP8. Local Ollama: needs `ollama pull llama3.2:3b`
(user); local qwen3.6:35b-mlx unusable (thinks 11–14 s).

**Working tree:** untracked RESEARCH.md, claude.md (user's).

## §4. Roles

One-shot sub-agents; orchestrator persists. Engineer specialty:
macos-engineer. Logs: docs/phase-4-architect-log.md /
phase-4-reviewer-observations.md / phase-4-tester-baselines.md.

## §5. Operating rules

Per skill. Toolchain: Xcode 26.6, xcodegen, Swift Testing, `make
generate/build/test`. Launch recipe: `pkill -x LotusScribe; make build;
open ~/Library/Developer/Xcode/DerivedData/LotusScribe-cqifdkbqqymodjfelqaaxtpwejca/Build/Products/Debug/LotusScribe.app`.
SourceKit cross-file diagnostics are stale-index noise — trust `make
test`. Parallel test suites: dedicated URLProtocol stub per suite.

## §6. Locked decisions

D1–D49 carried (phase-0…3 logs). D50–D55 in phase-4 log: D50 taxonomy/
map, D51 prompt composition + `.other` byte-identity floor, D52
key-down capture, D53 overrides defaults-dict, D54 override UI = 4C,
D55 per-website → v2.

## §7–§8. Open questions / non-blocking

Q4-1 (map contents, batch-time), Q4-2 (vLLM restoration). Note-only:
R7 (Phase 7+), R34, R41, R42; R35 standing rule.

## §9–§10. Resume / references

Skill resume pattern; phase-4 file set + this doc. Archives:
phase-0/1/2/3 docs.

## §11. Revision notes

Rev A — Phase 4 bootstrap (spec 4A/4B/4C, D50–D55), 2026-07-05.
