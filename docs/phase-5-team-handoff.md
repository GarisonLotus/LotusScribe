# Team Handoff — LotusScribe (Phase 5)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-5 role logs, then verify git state. Phase-0…4 docs are archives —
> EXCEPT the Phase-3 AND Phase-4 human gates, both still OPEN (see §3).

**Last updated:** 2026-07-05, Phase 5 bootstrap — next is architect spec dispatch.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`).

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app (hold chord →
speak → STT → LLM cleanup → insert). Phases 0–2 complete; Phase 3 + 4
machine work complete, human gates BLOCKED on vLLM. Phase 5 = custom
dictionary per PLAN.md §Phase 5: (1) user-managed vocabulary list in
settings; (2) inject into BOTH stages — Whisper `prompt` field (initial
prompt biasing) and cleanup system prompt ("these terms are spelled
exactly: …"). Verify: personal names / product terms spelled correctly.

References: `PLAN.md` §Phase 5; `docs/phase-5-spec.md` (once authored);
`CLAUDE.md` §5 (docs naming).

## §3. Current state

**Where we are:** 5A CLOSED 2026-07-05 (this commit): dictionary core —
D56 storage, DictionaryPrompt builders, D57 cleanup weave with
empty-dict byte-identity floor. 4-way gated, 170/18 green ×2 on three
independent runners. Spec: docs/phase-5-spec.md (D56–D60).

**User-reported 4C UI defect (2026-07-05, at-screen):** Save/Cancel
buttons overlap the scrollable App Categories list in Settings — fix
owed NEXT (before 5B/5C; touches SettingsForm, same file 5C reworks).
Related at-screen finding: user's overrides "disappeared" — diagnosis:
never persisted (vLLM down → Save probe fails; only Save Anyway
persists; draft discarded on Cancel/close per D26). Not a code bug;
mis-click risk from the overlap defect may have contributed.

**vLLM constraint (user directive at Phase-5 start):** vLLM still DOWN.
All HUMAN-AT-SCREEN / vLLM-dependent verifies for Phase 5 get recorded in
**`when-vllm-is-back.md`** (project root, untracked, user's scratch —
ORCHESTRATOR maintains it, sub-agents do not edit it). Machine-verifiable
slices land now, same posture as Phase 4.

**Open prior gates:** Phase-3 human gate + Phase-4 human gate — both in
the BLOCKED-BATCH queue (when-vllm-is-back.md §A/§B). Architect has NOT
declared Phase 3 or 4 complete.

**Overlap defect FIXED** at 6a98dfb; retroactively reviewer-APPROVED at
the 5B gate (R49 watch: button row now outside Form's disabled scope).
User re-persisted overrides via Save Anyway — confirmed on disk.

**5B CLOSED 2026-07-05** (this commit): Whisper `prompt` multipart
injection (D58/D59), 4-way gated, 173/18 green ×2 on three runners.
R48 pinned in architect log (truncation-log recovery ↔ strict-prefix
contract).

**5C BUILT in isolated worktree** (concurrent with 5B gate, user-
directed): 174/18 green ×2 there; diff (+137/−5, SettingsForm +
controller + tests) awaiting apply → gate → commit in main tree.

**AUTONOMOUS RUN (user away, 2026-07-05):** user directed: continue
through phases until they return ("I'm back"). Queue: land 5C → Phase 5
machine-complete → bootstrap Phase 6 (insertion hardening, PLAN.md §6)
→ Phase 7 (distribution) as far as machine-verifiable. All at-screen /
vLLM items accumulate in when-vllm-is-back.md.

**RESUME POINT (next):** apply 5C worktree diff, gate, commit.

**Cleanup endpoints:** vLLM (verified, down): chat/completions +
Qwen/Qwen3.6-35B-A3B-FP8. STT: https://vllm.garison.com/v1/audio/transcriptions
+ whisper-large-v3. Local Ollama: needs `ollama pull llama3.2:3b` (user).

**Working tree:** untracked RESEARCH.md, claude.md, when-vllm-is-back.md
(user's / orchestrator-maintained scratch — never commit).

## §4. Roles

One-shot sub-agents; orchestrator persists. Engineer specialty:
macos-engineer. Logs: docs/phase-5-architect-log.md /
phase-5-reviewer-observations.md / phase-5-tester-baselines.md.

## §5. Operating rules

Per skill. Toolchain: Xcode 26.6, xcodegen, Swift Testing, `make
generate/build/test` (run test TWICE per gate). Launch recipe: `pkill -x
LotusScribe; make build;
open ~/Library/Developer/Xcode/DerivedData/LotusScribe-cqifdkbqqymodjfelqaaxtpwejca/Build/Products/Debug/LotusScribe.app`.
SourceKit cross-file diagnostics are stale-index noise — trust `make
test`. Parallel test suites: dedicated URLProtocol stub per suite;
UUID-suffixed UserDefaults suites. R41/R44: SettingsWindowControllerTests
MUST stub `warmUp:` (default closure is real network).

## §6. Locked decisions

D1–D55 carried (phase-0…4 logs), all binding. Most Phase-5-relevant:
D14 (headless core / adapter split), D26 (draft-buffered settings, sole
persist via draft.save()), D37/D44 (Save-probe semantics), D40 (pure
enum + safe resolve pattern), D42 (warm-up trigger = (llmEndpointURL,
llmModel) tuple), D45 (prompt fixtures, /no_think position 0, closer
final), D51 (systemPrompt(for:) composition + .other byte-identity
floor), D53 (defaults-dict storage pattern for keyed settings).

## §7–§8. Open questions / non-blocking

Q4-1 (builtin map contents, batch-time), Q4-2 (vLLM restoration — gates
BLOCKED-BATCH). Note-only carries: R7 (Phase 7+), R34, R42, R44, R45;
R35 standing rule (construction-smoke for composition roots).

## §9–§10. Resume / references

Skill resume pattern; phase-5 file set + this doc + PLAN.md +
when-vllm-is-back.md. Archives: phase-0…4 docs.

## §11. Revision notes

Rev A — Phase 5 bootstrap (docs set, vLLM-down tracking rule), 2026-07-05.
