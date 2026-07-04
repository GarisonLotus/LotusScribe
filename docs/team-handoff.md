# Team Handoff — LotusScribe

> If you are a restarting orchestrator, this is your single entry point.
> Read top to bottom. Then read the three role logs (architect-log.md,
> reviewer-observations.md, tester-baselines.md). Then verify git state.

**Last updated:** 2026-07-04, post-0A close.

## §1. How to use this doc

This project follows the `phased-delivery` skill (installed at
`/Users/garisondraper/.claude/skills/phased-delivery/`). Load the skill
alongside this doc — handoff covers project state, skill covers framework.

1. Read §2–§3 for project context + current state.
2. Use §4 to know which engineer specialty to dispatch next.
3. Preserve §5's operating rules.
4. Scan §6–§8 for decisions + open questions + non-blocking carries.
5. Follow §9 to resume work.
6. Reference §10 for this project's paths.

## §2. Project context

LotusScribe: native Swift macOS menu bar app — hold hotkey → speak → release
→ STT over HTTP → LLM cleanup over HTTP → text lands in the focused app.
Thin client; all inference on user-configured OpenAI-compatible endpoints.
Currently building Phase 0 (scaffold).

Primary references:
- `PLAN.md` — authoritative design doc + phase breakdown
- `RESEARCH.md` — evidence behind every design choice
- `docs/phase-0-spec.md` — active phase spec (being authored)
- `CLAUDE.md` — behavioral guidelines (simplicity, surgical changes)

## §3. Current state

**Where we are in implementation:** sub-phase 0A closed (scaffold + menu-bar
presence); full 4-way gate passed (reviewer approved, architect shape
approved + R1/R2 round-tripped, tester green, spot-checks clean).

**Last code-carrying commit:** see `git log` — 0A bundled commit.

**Active sub-phase:** 0B — settings storage + tests. Pending: engineer dispatch.

**Sub-phase grid for Phase 0:**
- 0A: CLOSED (scaffold, LSUIElement, NSStatusItem, test target, Makefile)
- 0B: NEXT (SettingsStore, KeychainStore, Swift Testing suites)

**Working tree at handoff time:** untracked PLAN.md, RESEARCH.md, claude.md
(user's files — not committed without user say-so).

## §4. Roles (one-shot, dispatched on demand)

One-shot sub-agents; orchestrator is the only persistent entity. Dispatch
using templates in
`/Users/garisondraper/.claude/skills/phased-delivery/references/briefing-templates.md`.

| Role | When to dispatch | Where state lives |
|---|---|---|
| architect | Spec creation, shape ruling, round-trip | docs/architect-log.md + spec docs |
| reviewer | Each gate's execution review | docs/reviewer-observations.md |
| tester | Each gate's independent verification | docs/tester-baselines.md |
| macos-engineer | Each sub-phase implementation | (no log — code is the artifact) |

Engineer specialties: macos-engineer (Swift/AppKit/SwiftUI).

## §5. Operating rules

Per skill — gate sequence, stuck rule, user-authorization, commit
discipline. Project-specific additions:

- Toolchain: Xcode 26.6, xcodegen (installed), Swift Testing framework.
- Build/test via `xcodebuild`; wrap repeated commands as Makefile recipes.
- No signing identities on this machine — ad-hoc "Sign to Run Locally".

## §6. Locked decisions carried forward

1. XcodeGen: commit `project.yml`, gitignore generated `.xcodeproj`. (user)
2. Bundle ID: `com.garisonlotus.LotusScribe`. (user)
3. Phase 0 settings = storage only + unit tests; no settings UI until Phase 1. (user)
4. Swift Testing (not XCTest). (user)
5. macOS 14+ deployment target. (PLAN.md)
6. Ad-hoc dev signing for Phase 0; revisit team ID at Phase 1 for TCC stability. (orchestrator, user-flagged)
7. Own small Keychain wrapper via Security framework; no third-party dep. (orchestrator)

## §7. Open decisions / questions

- Signing team ID for Phase 1 (TCC grants reset with ad-hoc re-signing).

## §8. Non-blocking items

None yet.

## §9. How to resume

Follow the skill's Resume-from-crash pattern. No project-specific resume
steps yet.

## §10. Reference index

- `PLAN.md` — authoritative architecture + phases
- `RESEARCH.md` — research evidence
- `docs/phase-0-spec.md` — active phase spec
- `docs/architect-log.md` — locked decisions + open questions
- `docs/reviewer-observations.md` — forward-looking review items
- `docs/tester-baselines.md` — last-gate counts + flake registry
- `CLAUDE.md` — behavioral guidelines
- Test layout: TBD by phase-0 spec
- Tooling: xcodegen + xcodebuild; Makefile recipes TBD

## §11. Revision notes

Rev A — Day-0 bootstrap, 2026-07-04.
