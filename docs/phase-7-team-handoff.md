# Team Handoff — LotusScribe (Phase 7)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-7 role logs, then verify git state. Phase-0…6 docs are archives —
> EXCEPT the Phase-3/4/5/6 human gates, all OPEN (see §3).

**Last updated:** 2026-07-05, Phase 7 bootstrap — next is architect spec dispatch.

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`).

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app. Phases 0–2
complete; 3/4/5/6 machine work complete, human gates queued in
when-vllm-is-back.md (user tests tomorrow morning, 2026-07-06). Phase 7 =
distribution per PLAN.md §7: (1) first-run onboarding (Mic →
Accessibility (→ Input Monitoring if needed) walkthrough, live preflight
status, Fn-key System Settings guidance); (2) Developer ID signing +
notarization (notarytool), DMG, Sparkle updates, optional Homebrew cask;
(3) endpoint presets in settings (Speaches / Ollama / vLLM / custom) +
connection-test button.

References: `PLAN.md` §Phase 7; `docs/phase-7-spec.md` (once authored).

## §3. Current state

**Where we are:** Phase 7 bootstrap. Baseline 191 tests / 19 suites at
4c779b1 (6C commit).

**AUTONOMOUS RUN:** user away until tomorrow morning; vLLM is UP but
human testing deferred — all at-screen items keep accumulating in
**when-vllm-is-back.md** (untracked, ORCHESTRATOR maintains).

**KNOWN CONSTRAINTS for Phase 7:** current signing is PERSONAL TEAM
(5RC66Q82V9) — Developer ID signing + notarization need the user's paid
Apple Developer credentials (BLOCKED-USER, not machine-doable). Sparkle
is a third-party dep — D7 (no third-party deps) needs an explicit
architect ruling + user sign-off before adoption. Machine-buildable now:
endpoint presets, onboarding UI/state machine, DMG/notarization
SCRIPTS (recipes that run once creds exist).

**Open prior gates:** Phase-3/4/5/6 human gates → when-vllm-is-back.md.

**7A CLOSED 2026-07-05** (this commit): endpoint presets + connection-
test button (D69/D70), 4-way gated, 201/20 green (engineer ×2, reviewer
×1, tester ×2). R62/R63 note-only.

**7B CLOSED 2026-07-05** (this commit): onboarding state machine +
checklist window + launch hook + Rerun menu item (D67/D68), 4-way
gated, 218/22 green (engineer ×2, reviewer ×1, tester ×2). R64–R67
filed; R66 ruled intended shape (titlebar close ≠ Skip; at-screen may
overrule); R67 ruled non-blocking follow-up: StatusItemController
becomes sole OnboardingWindowController owner.

**R67 fix committed** at 5335d98 (single onboarding-controller owner);
retroactively reviewer-approved at the 7C gate, R67 closed.

**7C CLOSED 2026-07-05** (this commit): release recipes
(make release/dmg/notarize/staple + scripts/make-dmg.sh, D71), 4-way
gated — dmg dry-runs clean dev-signed (753 KB, hdiutil VALID,
spctl-rejected baseline recorded pre-Developer-ID); notarize/staple
fail fast without NOTARY_PROFILE; suite unchanged 218/22 ×3 runners.
R68 deferred to first version bump (D71 amended); R69 pinned as
Sparkle-adoption precondition (D66 amended).

**PHASE 7 MACHINE-SCOPE COMPLETE** (architect-declared). Phases 3–7 all
machine-complete; every remaining item is in when-vllm-is-back.md
(§A–§F: at-screen + dictation batches for tomorrow morning, plus
BLOCKED-USER distribution decisions Q7-1/2/3).

**RESUME POINT (next):** user batch-testing (when-vllm-is-back.md, top
to bottom); record results → architect closes Phases 3→7 in order as
their legs clear.

**Working tree:** untracked RESEARCH.md, claude.md, when-vllm-is-back.md
(never commit).

## §4. Roles

One-shot sub-agents; orchestrator persists. Engineer specialty:
macos-engineer (+ possibly a build/release-engineer for DMG/notary
recipes). Logs: docs/phase-7-architect-log.md /
phase-7-reviewer-observations.md / phase-7-tester-baselines.md.

## §5. Operating rules

Per skill. Toolchain: Xcode 26.6, xcodegen, Swift Testing, `make
generate/build/test` (test ×2 per gate). Launch recipe: `pkill -x
LotusScribe; make build;
open ~/Library/Developer/Xcode/DerivedData/LotusScribe-cqifdkbqqymodjfelqaaxtpwejca/Build/Products/Debug/LotusScribe.app`.
SourceKit diagnostics = stale-index noise — trust `make test`. Dedicated
URLProtocol stub per suite; UUID-suffixed defaults suites; R41/R44
warmUp: stubbing.

## §6. Locked decisions

D1–D65 (+D62a) carried, all binding. Phase-7-relevant: D7 (no
third-party deps — Sparkle needs a ruling), D26 (draft-buffered
settings), D36–D38 (probe/save/alert surfaces), D37/D44 (Save-probe
semantics — presets interact), D40 (pure enum + resolve), R40 (single
contentSize site — presets UI may grow the window again). Onboarding:
Permissions.swift preflight surface exists (AXIsProcessTrusted etc.).

## §7–§8. Open questions / non-blocking

Q4-2 answered (vLLM back). Carries: R7 (LIVE THIS PHASE if hotkey-config
UI ships — it does NOT per PLAN; stays open), R34, R42, R44, R45, R46,
R48, R49, R51, R59, R60; R35 standing rule (onboarding window controller
= new composition root → construction-smoke test owed AT INTRODUCTION).

## §9–§10. Resume / references

Skill resume pattern; phase-7 file set + this doc + PLAN.md +
when-vllm-is-back.md. Archives: phase-0…6 docs.

## §11. Revision notes

Rev A — Phase 7 bootstrap, 2026-07-05.
