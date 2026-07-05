# Team Handoff — LotusScribe (Phase 1)

> If you are a restarting orchestrator, this is your single entry point.
> Read top to bottom. Then read the three phase-1 role logs. Then verify
> git state. All docs/ files carry the phase number (CLAUDE.md §5);
> phase-0 files are the archive of that phase.

**Last updated:** 2026-07-04, 1C closed.

## §1. How to use this doc

This project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`). Handoff covers
project state; skill covers framework.

## §2. Project context

LotusScribe: native Swift macOS menu bar app — hold hotkey → speak → release
→ STT over HTTP → LLM cleanup over HTTP → text lands in the focused app.
Phase 0 (scaffold) complete. Phase 1 = core loop: CGEventTap hotkey,
AVAudioEngine capture, TranscriptionService, pasteboard insertion, bare
settings pane.

Primary references:
- `PLAN.md` — authoritative design doc; §"Phase 1" is the active scope
- `RESEARCH.md` — evidence; §2 (macOS client engineering) most relevant
- `docs/phase-1-spec.md` — active phase spec (being authored)
- `CLAUDE.md` — behavioral guidelines + docs naming convention (§5)

## §3. Current state

**Where we are:** Phase 1 sub-phases 1A (hotkey, 11c5efd), 1B (audio,
89a4aa7), 1C (TranscriptionService, this commit) closed — 4-way gates
passed. Spec: docs/phase-1-spec.md (slicing D14: 1A–1E). Baselines: 43
tests / 6 suites green ×2 (tester log). Real-endpoint round-trip verified
twice (engineer probe + tester's independent oracle).

**Verified facts for Phase 1 (orchestrator probes, 2026-07-04):**
- STT endpoint LIVE and verified end-to-end: POST 16kHz mono WAV multipart
  to `https://vllm.garison.com/v1/audio/transcriptions`, model
  `whisper-large-v3`, no API key → correct transcript returned.
- Same server's `/v1/models` also lists Qwen3.6-35B chat models (Phase 3
  cleanup candidates).
- Signing: user chose personal-team signing; Apple ID not yet added in
  Xcode (0 identities). DEVELOPMENT_TEAM wired once user completes
  Xcode → Settings → Accounts.

**Active sub-phase:** 1D next — insertion (pasteboard + Cmd-V, D20) +
core-loop wiring with generation counter (D23); includes R12 one-line
timeout assertion in 1C test. Then 1E settings UI. HUMAN-AT-SCREEN
remainders (1A/1B TCC records + 1D dictation matrix) owed before phase
close — see tester log.

**Working tree:** untracked PLAN.md, RESEARCH.md, claude.md (user's files).

## §4. Roles

One-shot sub-agents; orchestrator persists. Templates:
`/Users/garisondraper/.claude/skills/phased-delivery/references/briefing-templates.md`.
Engineer specialty: macos-engineer (Swift/AppKit/SwiftUI).

| Role | State file |
|---|---|
| architect | docs/phase-1-architect-log.md |
| reviewer | docs/phase-1-reviewer-observations.md |
| tester | docs/phase-1-tester-baselines.md |

## §5. Operating rules

Per skill. Project-specific:
- Toolchain: Xcode 26.6, xcodegen, Swift Testing; `make generate/build/test`.
- Docs naming: `phase-N-<name>.md` (CLAUDE.md §5).
- TCC-bearing runtime checks (mic, Accessibility) need the user at the
  screen — mark human-visual items explicitly.

## §6. Locked decisions carried forward (phase 0)

D1–D11 in docs/phase-0-architect-log.md remain binding (XcodeGen; bundle ID
com.garisonlotus.LotusScribe; Swift Testing; macOS 14+; no third-party deps;
own Keychain wrapper; generated Info.plists never committed). New phase-1
decisions go in docs/phase-1-architect-log.md (starts at D12).

## §7. Open decisions / questions

- Q1 (carried): personal-team signing chosen; BLOCKED on user adding Apple
  ID in Xcode. Gates TCC grant stability + reliable Keychain reads (R4).

## §8. Non-blocking items

- R4 (phase 0): legacy-keychain ACLs vs ad-hoc re-signing — resolves with Q1.
- R3 resolved-keep: 0A smoke test stays as link-smoke; repoint at real
  behavior in Phase 1.

## §9. How to resume

Skill's Resume-from-crash pattern; phase-1 file set + this doc.

## §10. Reference index

- `docs/phase-1-spec.md` — active spec
- `docs/phase-1-architect-log.md` / `docs/phase-1-reviewer-observations.md`
  / `docs/phase-1-tester-baselines.md` — role logs
- `docs/phase-0-*.md` — phase-0 archive
- Tooling: Makefile (generate/build/test)

## §11. Revision notes

Rev A — Phase 1 bootstrap, 2026-07-04.
