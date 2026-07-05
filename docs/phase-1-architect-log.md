# Architect log — LotusScribe (Phase 1)

> Locked decisions + open questions for Phase 1. D1–D11 live in
> docs/phase-0-architect-log.md and remain binding. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D12 | 2026-07-04 | Personal-team signing (DEVELOPMENT_TEAM in project.yml) once user adds Apple ID in Xcode; ad-hoc until then | User choice; stable TCC grants + Keychain ACLs (R4) | 1 |
| D13 | 2026-07-04 | Real STT test endpoint: https://vllm.garison.com/v1/audio/transcriptions, model whisper-large-v3, no API key | Orchestrator-verified round-trip 2026-07-04 | 1 |
| D14 | 2026-07-04 | Slicing 1A hotkey → 1B audio → 1C transcription → 1D insertion+loop → 1E settings UI; pure logic unit-tested headlessly, TCC adapters thin + manually verified; pre-1E config seeded via `defaults write` | Front-loads Fn capture + TCC empirical question; every sub-phase committable with green `make test` | 1A–1E |
| D15 | 2026-07-04 | Hotkey chord from UserDefaults key `hotkeyChord` (string, `HotkeyChord.parse`), nil → hold-Fn; no hotkey UI in Phase 1 | PLAN wants configurable fallback; settings pane scope is 4 D9 fields only | 1A |
| D16 | 2026-07-04 | Listen-only session CGEventTap (`.listenOnly`); no event swallowing in Phase 1 | Smallest TCC surface (RESEARCH: Accessibility may suffice for listen-only); swallowing deferred | 1A |
| D17 | 2026-07-04 | Client-side resample to 16 kHz/mono/16-bit via AVAudioConverter; RIFF header built by pure WavEncoder | Deterministic payload regardless of server; header unit-testable | 1B |
| D18 | 2026-07-04 | Optional STT language via UserDefaults key `sttLanguage`; nil → field omitted; no UI in Phase 1 | PLAN requires configurable language; UI scope stays 4 fields | 1C |
| D19 | 2026-07-04 | TranscriptionService unit tests via URLProtocol stub, not a localhost listener | In-process, deterministic, no port/network flake | 1C |
| D20 | 2026-07-04 | Insertion = pasteboard write + synthesized Cmd-V only; no clipboard save/restore (no pasteboard reads anywhere) in Phase 1 | Restore needs a pasteboard read → upcoming privacy alert (RESEARCH §2); restore is Phase 6 | 1D |
| D21 | 2026-07-04 | Settings pane = SwiftUI Form in NSHostingController-backed window, opened from status-item menu | No storyboard/SwiftUI-App churn; macOS 14 baseline (D5); fewest LoC without deps | 1E |
| D22 | 2026-07-04 | Keep `CGRequestListenEventAccess()` at launch, guarded from test hosts (rules R5) | Deterministic, user-visible prompt → clean §1A-verify-3 TCC record; dropping it = silent failure until user finds System Settings; Phase 7 owns real onboarding | 1A |
| D23 | 2026-07-04 | Overlapping dictation (R11): generation counter — only the latest dictation's transcript inserts; stale results logged + dropped. No cancel/serialize plumbing | Simplest guaranteed fix for stale insertion (CLAUDE.md); cancel adds Task bookkeeping + CancellationError noise, serialize locks the user out for up to 20 s | 1D |
| D24 | 2026-07-04 | D23 refinement: generation bump precedes `recorder.start()` — a failed start also invalidates any in-flight transcript | User's latest intent wins even when the new capture fails; strictly-stronger reading of "bump on each start", locked so a future refactor can't reorder it | 1D |
| D25 | 2026-07-04 | Settings pane: emptying a field writes nil to SettingsStore, never "" — unset keeps its phase-0 meaning (nil → code-path defaults, D15/D18 pattern) | "" would silently defeat every nil-fallback; locked so a future form rewrite can't regress it | 1E |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| Q1 | 2026-07-04 | Wire DEVELOPMENT_TEAM — which team ID? | open | user adding Apple ID in Xcode |
| Q2 | 2026-07-04 | Ad-hoc re-signing (D6) may reset TCC grants each build, making the Phase-1 empirical TCC record noisy — record prompts per fresh build; re-baseline once Q1 closes | open | Q1 |
| Q3 | 2026-07-04 | Does synthesized Cmd-V land in Terminal / secure-input contexts? 1D verify observes and records; handling (if needed) is Phase 6 scope | open | 1D verify |

## Notes

PLAN.md §Phase 1 is the scope. Empirical question Phase 1 must answer
(PLAN.md verify): which TCC prompts actually fire (Mic + Accessibility
expected; Input Monitoring uncertain — RESEARCH.md refuted-claim nuance).
The spec spreads the empirical record across three checkpoints: 1A (event
tap), 1B (mic), 1D (final matrix incl. synthetic paste).

2026-07-04: docs/phase-1-spec.md authored (sub-phases 1A–1E, D14–D21).
2026-07-04: 1B shape approved (post-R8). R9 tail-drop accepted for
dictation; spec §1C verify-2 amended to make temp-write removal explicit (R10).
2026-07-04: 1C shape approved. R11 ruled → D23 (generation counter, spec
§1D). R12: required in 1D — one-line timeout assertion in the 1C test.
2026-07-04: 1D shape non-object. Bump-before-start locked as D24 (spec §1D
amended). Check ordering, @MainActor inserter, strong-self capture (R15):
implementation-level, no spec text. R16 (CGEvent failure leaves transcript
on clipboard, no paste) is covered by the §1D clobber-accepted invariant —
add to the HUMAN-AT-SCREEN failure matrix, no spec change.
2026-07-04: 1E shape non-object. Empty-field→nil locked as D25 (spec §1E
amended). Implementation-level, no spec text: SettingsValidation colocated
in SettingsWindowController.swift (spec listed it under that deliverable);
local @State + per-change write-through (no ObservableObject retrofit —
SettingsStore stays the single backing store); StatusItemController as
NSObject subclass (NSMenuItem target needs ObjC dispatch); activate +
makeKeyAndOrderFront + lazy retained controller for LSUIElement focus;
keyEquivalent "," on Settings… (standard macOS, cosmetic in a status menu).
