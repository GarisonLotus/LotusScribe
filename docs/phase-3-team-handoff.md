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

**RESUME POINT (3C dispatch, 2026-07-05): engineer dispatch DIED
MID-RUN (session limit). It staged/wrote NOTHING — working tree clean
at 52cf28f, `make test` green (106/15). Simply RE-DISPATCH the 3C
engineer with the same brief:** spec §3C scope — (1) settings cleanup
level Picker (Off/Light/Standard, D40 key, through the D26 buffered
draft); (2) D44 per-endpoint Save probe — probe ANY non-empty drafted
endpoint, STT then LLM (`ConnectionProbe.testLLM`, chat-completion
round-trip), stop at first failure, failure sheet NAMES the failing
endpoint; (3) endpoint-change warm-up after successful Save
(CleanupService.warmUp exists); (4) folds: R36 (save() cancels stale
flash/auto-close tasks), R37 (extract SettingsForm.swift from the
214-line SettingsWindowController.swift), R38 (warm-up log cosmetics),
R39 (D25 empty→nil normalization at read time). Tests per spec §3C
(dedicated-stub discipline, parallel-suite race); baseline 106/15.
Then 4-way gate (reviewer → architect+tester parallel is fine) → ONE
commit → rebuild + relaunch → HUMAN verify (picker, dual-probe sheet
naming the endpoint, warm-up on endpoint change) → Phase-3 close gate.

**Session context worth carrying:** user's LLM endpoint+model are
configured in the app and verified working (3B human gate); sheet
labels are Save Anyway / Try Again; launch recipe in §5; SourceKit
cross-file "cannot find in scope" diagnostics are stale-index noise —
trust `make test`.

(superseded 3B note: implementation per spec §3B (D39–D44
locked 2026-07-05): CleanupLevel + CleanupService + pipeline hop +
launch warm-up. Then 3C (settings level picker + per-endpoint Save
probe, folds R36/R37). User's LLM endpoint URL + model needed at the
3B/3C human gates (spec hardcodes none; SettingsStore already carries
the LLM URL/model fields).

**Baseline:** 89 tests / 13 suites green ×2 at 4f21c17.

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
