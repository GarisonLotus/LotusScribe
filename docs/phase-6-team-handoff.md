# Team Handoff — LotusScribe (Phase 6)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-6 role logs, then verify git state. Phase-0…5 docs are archives —
> EXCEPT the Phase-3/4/5 human gates, all OPEN (see §3).

**Last updated:** 2026-07-05, Phase 6 bootstrap — next is architect spec dispatch.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`).

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app (hold chord →
speak → STT → LLM cleanup → insert). Phases 0–2 complete; Phase 3/4/5
machine work complete, human gates BLOCKED on vLLM (queue:
when-vllm-is-back.md). Phase 6 = insertion hardening per PLAN.md §6:
(1) AX-first insertion (AXUIElement selected-text replacement) where the
focused element supports it, pasteboard+Cmd-V fallback; (2) clipboard
restore gated on NSPasteboard `detect` methods, test under
`EnablePasteboardPrivacyDeveloperPreview`; (3) secure-input detection
(`IsSecureEventInputEnabled`) → pill shows "can't dictate here".
Verify: clipboard survives a dictation; password field shows blocked
state; Electron apps (Slack/VS Code) still work via fallback.

References: `PLAN.md` §Phase 6; `docs/phase-6-spec.md` (once authored);
`CLAUDE.md` §5.

## §3. Current state

**Where we are:** Phase 6 bootstrap. Baseline 177 tests / 18 suites at
94c4b5d (5C commit).

**AUTONOMOUS RUN (user away, 2026-07-05):** user directive: build out as
much as possible across phases until they say "I'm back". vLLM DOWN —
all at-screen / vLLM-dependent verifies accumulate in
**when-vllm-is-back.md** (untracked, ORCHESTRATOR maintains; sub-agents
never edit). NOTE: Phase-6 insertion verifies need live dictation →
mostly BLOCKED-BATCH; machine slices land now (Phase-4/5 posture).

**Open prior gates:** Phase-3, Phase-4, Phase-5 human gates — all
BLOCKED-BATCH in when-vllm-is-back.md.

**6A CLOSED 2026-07-05** (this commit): secure-input blocked pill
(D63/D64), 4-way gated, 179/18 green ×2 ×2 runners (reviewer verdict
collated from partial return after an API cutoff — source checks pass +
179/18 ×2 + R54/R55 filed as accepted; orchestrator ruled that an
approval). vLLM RESTORED + user back at screen 2026-07-05 — batch
testing (when-vllm-is-back.md) begins.

**6B CLOSED 2026-07-05** (this commit): AX-first insertion + fallback
(D61/D65), 4-way gated, 183/19 green (×2 tester, ×1 reviewer, ×1
orchestrator). Spec §6B verify-2 wording amended (AX *usage* grep, R57).
User defers batch testing to TOMORROW MORNING — orchestrator continues
autonomously; when-vllm-is-back.md keeps growing.

**RESUME POINT (next):** 6C (clipboard save/restore), then Phase 7
bootstrap (machine-verifiable slices only).

**Working tree:** untracked RESEARCH.md, claude.md, when-vllm-is-back.md
(never commit).

## §4. Roles

One-shot sub-agents; orchestrator persists. Engineer specialty:
macos-engineer. Logs: docs/phase-6-architect-log.md /
phase-6-reviewer-observations.md / phase-6-tester-baselines.md.

## §5. Operating rules

Per skill. Toolchain: Xcode 26.6, xcodegen, Swift Testing, `make
generate/build/test` (test ×2 per gate). Launch recipe: `pkill -x
LotusScribe; make build;
open ~/Library/Developer/Xcode/DerivedData/LotusScribe-cqifdkbqqymodjfelqaaxtpwejca/Build/Products/Debug/LotusScribe.app`.
SourceKit cross-file diagnostics = stale-index noise — trust `make test`.
Parallel suites: dedicated URLProtocol stub per suite; UUID-suffixed
UserDefaults suites; R41/R44: SettingsWindowControllerTests MUST stub
`warmUp:`.

## §6. Locked decisions

D1–D60 carried (phase-0…5 logs), all binding. Most Phase-6-relevant:
D14 (headless core / adapter split — AX + pasteboard are adapter-side),
D23 (per-Task snapshot discipline), D43 (failure policy — never eat the
user's words), D46–D48 (pill state machine), D49 (adapter, no DI seam
posture + dead-tap re-enable), D52 (key-down capture pattern).
Current insertion path: pasteboard + Cmd-V (Phase 1/2 era) — find the
exact current shape in the phase-1/2 specs + source before ruling.

## §7–§8. Open questions / non-blocking

Q4-2 (vLLM restoration) gates all human batches. Carries: R7 (Phase 7+),
R34, R42, R44, R45, R46 (non-ASCII STT budget), R47 (setter
un-normalized by design), R48 (truncation-log coupling), R49 (button-row
disabled guard), R51 (Unicode fold nit), R35 standing rule
(construction-smoke for composition roots).

## §9–§10. Resume / references

Skill resume pattern; phase-6 file set + this doc + PLAN.md +
when-vllm-is-back.md. Archives: phase-0…5 docs.

## §11. Revision notes

Rev A — Phase 6 bootstrap, 2026-07-05.
