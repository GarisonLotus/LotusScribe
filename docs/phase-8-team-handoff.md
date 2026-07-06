# Team Handoff — LotusScribe (Phase 8)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-8 role logs, then verify git state. Phase-0…7 docs are archives.

**Last updated:** 2026-07-06, Phase 8 bootstrap — next is architect spec dispatch.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`).

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app. Phases 0–7 built
(3–7 machine-complete; human batch in progress 2026-07-06). Phase 8 =
LIVE-TEST CORRECTIONS surfaced during the human batch:

1. **Model reasoning control (8A):** the cleanup prompt's `/no_think`
   prefix is SILENTLY IGNORED by Qwen3.6 (both FP8 and the user's
   nvidia/Qwen3.6-35B-A3B-NVFP4) — the model reasons 12–20s per cleanup,
   blowing the 8s timeout → amber → raw text. Empirically confirmed
   (2026-07-06): the request BODY parameter suppresses it — Qwen-NVFP4
   drops 19.5s → 0.3s with `enable_thinking:false` (or
   `reasoning_effort:none`); both are HARMLESS to non-thinking models
   (Phi-3.5-mini: 0.8s, no error) so the parameter is safe to send to
   any model. USER DECISION (load-bearing): this must be a USER SETTING
   (default: suppress ON), NOT hardcoded — a user running a reasoning
   model may want thinking ON. Plus a settings guidance caption
   ("model behavior varies; Qwen3.6 recommended").
2. **Warm-up while recording (8B):** cold-reload amber (#16) — vLLM
   serves 6 models and evicts on demand; the app only warms at launch/
   endpoint-change (D42), so a model evicted between dictations cold-
   loads on the next → timeout. Fire a warm-up at RECORDING START (pill
   show) so the model loads while the user is still speaking.

## §3. Current state

**Where we are:** Phase 8 bootstrap. Baseline 218 tests / 22 suites at
e9f53a7. Flake sweep: 10× green (2026-07-05).

**8A CLOSED 2026-07-06** (this commit): reasoning-suppression setting
(D72/D73 — reasoning_effort:"none" when ON, default TRUE, draft-
buffered; /no_think kept inert; toggle + guidance caption; 740→780),
4-way gated, 223/22 green ×2 ×3 runners. R70/R71 note-only.

**8B CLOSED 2026-07-06** (this commit): record-start warm-up (D74 —
after successful recorder.start(), 30 s debounce via pure predicate),
4-way gated, 226/22 green ×2 ×2 runners. R72/R73 note-only. PHASE 8
MACHINE-SCOPE COMPLETE (architect-declared); live legs open (8A steps
3/4, 8B #16 re-verify).

**RESUME POINT (next):** user's remaining live batch — retest cleanup-
quality items (#7/#13/#14/#18/#19), #16 amber-gone, #25 pasteboard
preview, #26 onboarding rerun (with the corrected two-command reset),
#27/Q7-4, #28, Q7-5 Local Network observation.

**Live-test status:** most of the human batch (when-vllm-is-back.md)
passed; open cleanup-quality items (#7/#13/#14/#18/#19) are blocked on
8A landing (Qwen without the fix ambers on every cleanup). #26/#27
clarified (docs, not bugs). Q7-5 (Local Network) still open at screen.

**Working tree:** untracked RESEARCH.md, claude.md, when-vllm-is-back.md.

## §4. Roles

One-shot sub-agents; orchestrator persists. Engineer specialty:
macos-engineer. Logs: docs/phase-8-*.md.

## §5. Operating rules

Per skill. Toolchain: Xcode 26.6, xcodegen, Swift Testing, `make
generate/build/test` (×2 per gate). SourceKit cross-file diagnostics =
stale-index noise. R41/R44: SettingsWindowControllerTests stub `warmUp:`.
Cleanup request shape has a key-set tripwire test (currently asserts
exactly model/messages/temperature) — 8A adds a key, must update it.

## §6. Locked decisions

D1–D71 (+D62a) carried. Phase-8-relevant: D26 (draft-buffered settings),
D40 (pure resolve), D42 (warm-up policy — 8B amends), D45 (cleanup
request shape + 8s timeout + prompt fixtures — 8A amends), D51/D57
(prompt composition — /no_think at position 0 now known INEFFECTIVE on
Qwen3.6), D53 (defaults storage pattern). EMPIRICAL (2026-07-06):
enable_thinking:false / reasoning_effort:none both → 0.3s on Qwen3.6,
safe on Phi; /no_think prefix ignored by Qwen3.6.

## §7–§8. Open questions / non-blocking

Q7-5 (Local Network, at-screen). Carries: R35 (construction-smoke for
new composition roots), R45/R49 (settings probe/guard watches — 8A
touches SettingsForm), plus phase-3…7 note-only carries.

## §9–§10. Resume / references

Skill resume pattern; phase-8 file set + PLAN.md + when-vllm-is-back.md.
Archives: phase-0…7 docs.

## §11. Revision notes

Rev A — Phase 8 bootstrap (8A reasoning toggle, 8B warm-up-on-record),
2026-07-06.
