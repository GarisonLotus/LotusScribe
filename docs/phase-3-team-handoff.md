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

**3C CLOSED (automated gates) 2026-07-05** at 7d5ecf7: level picker,
D44 dual-endpoint Save probe, endpoint-change warm-up; R36–R39 folded
and closed.Debt sweep a5960da closed R3/R30/R32/R40.3B verify-2
CORRECTED to false positive and re-opened (c01f808): no LLM settings
were ever persisted — cleanup was effective-off during the user's
test.

**RESUME POINT — AWAITING USER ("I'm back"):**
1.Settings → enter LLM endpoint URL + model + pick cleanup level →
   Save (now probes BOTH endpoints; sheet names the failing one).
2.Re-run 3B verify-2 for real: dictate a filler sentence, confirm
   cleaned text; check warm-up fires on the endpoint-change Save.
3.3C human items: picker persists across reopen; bogus-LLM sheet says
   "Cleanup LLM"; 390 pt window fits; one end-to-end dictation (D38).
Then Phase-3 close gate needs an architect decision: PLAN.md Phase 3
items 3B+3C are done except the human confirms above; remaining
PLAN.md Phase-3 scope (cleanup-level prompt variants exist; history
deferred by D41) — architect declares Phase 3 complete or names 3D.

**Session context:** launch recipe §5; sheet labels Save Anyway / Try
Again; SourceKit cross-file diagnostics are stale-index noise — trust
`make test`; running app pid/build = debt-sweep a5960da.

**Baseline:** 120 tests / 15 suites green ×2 at a5960da.

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
