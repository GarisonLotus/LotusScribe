# Architect log — LotusScribe (Phase 2)

> Locked decisions + open questions for Phase 2. D1–D11 live in
> docs/phase-0-architect-log.md, D12–D28 in docs/phase-1-architect-log.md;
> all remain binding. Numbering continues at D29. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D29 | 2026-07-04 | Cold-start (Q4) ruling — both prongs, minimal: (a) `engine.prepare()` at AudioRecorder init (no TCC touch, no mic indicator; best-effort HAL warm-up); (b) load-bearing fix is pill truth — pill shows `.warming` at key-down and switches to waveform only when the first converted buffer arrives (engine demonstrably live); waveform = "speak now". Rejected: throwaway engine start at launch — fires the mic TCC prompt at launch + flashes the orange indicator (trust damage), and changes the 1B empirical property "prompt at first recording". Closes Q4. **[2026-07-05: prong (a) rescinded by D34 — fatal NSException at init; prong (b) stands as sole mitigation]** | 2.5 s first-ever cold start ate the user's words (phase-1 record); honest UI beats speculative prewarm | 2A/2C |
| D34 | 2026-07-05 | D29a rescinded (amends D29; Q6 closed empirically): `prepare()` on an empty graph throws NSException (`AVAudioEngineGraph.mm:1322 inputNode != nullptr \|\| outputNode != nullptr`) inside applicationDidFinishLaunching; AppKit swallows it — dead hotkey, no Console error (orchestrator lldb, 2026-07-05). Fix: delete the init-time `prepare()`; do NOT relocate it into start() — `engine.start()` prepares implicitly, an explicit call immediately before it warms nothing, so no warming claim survives (verify-4 keeps measuring observed duration for baselines only). Rejected: touch `inputNode` at init (HAL/TCC poke at launch, D29's original grounds). In-scope regression test: hosted unit test constructs `DictationController` — the D29a exception would have failed it; safe iff construction stays TCC-free (D14 constraint: recorder init must never touch `inputNode`/HAL) | fatal beats ineffective; D29b pill truth was always the load-bearing fix; the launch path had zero test coverage | 2C |
| D30 | 2026-07-04 | Event swallowing (D28 promotion): tap becomes `.defaultTap`; swallow = callback returns nil. Scope: chord keycode's keyDown (start + autorepeats while `chordKeyDownSwallowed` — swallowed press physically held, strict superset of while-capturing; ratified from 2A implementation) and its keyUp, pair-balanced — keyUp swallowed iff its keyDown was (covers the modifier-release stop path). Never flagsChanged, never other keycodes, never `.fnHold`. If `.defaultTap` creation fails, retry `.listenOnly` + log the fallback | Modifiers are shared system state — swallowing flagsChanged breaks other shortcuts; pair balance means no app ever sees half a down/up pair; fallback: Phase-1 leakage beats a dead hotkey | 2A |
| D31 | 2026-07-04 | Pill metrics, single definition site `PillMetrics`: content 260×52 pt, bottom-center of `NSScreen.main` at `visibleFrame.minY + 24`, 24 waveform bars, 0.8 s success/error flash. Panel sized via explicit `setContentSize`; tests assert `contentLayoutRect` | R23: macOS 26 fitting-size autosizing is broken for SwiftUI-hosted windows; R21: shared constant once a literal wants a 3rd site | 2B |
| D32 | 2026-07-04 | RMS plumbing: pure `AudioLevel.rms(pcm16:) -> Float` (0…1); AudioRecorder gains `onLevel` closure, computed per converted chunk on the audio thread, value dispatched to main. First callback doubles as the D29 engine-live signal | D14 split: math pure/headless, delivery adapter thin; no Combine/ObservableObject in the recorder | 2A |
| D33 | 2026-07-05 | R33 ruling — accept the widened PillController surface: 2C-facing API stays the four methods (show/update/push/hide); read-only observability (internal `let panel`, computed `var state`) is ratified as part of the surface, test/assert access only. Spec §2B round-tripped | R24 precedent (test observability over NSApp-hosted windows); `state` is computed read-only and `panel` is `let` — no state-ownership change; narrowing buys no encapsulation, costs test reach | 2B |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| Q5 | 2026-07-04 | Does `.defaultTap` session-tap creation succeed under the already-granted Input Monitoring + Accessibility (no new TCC pane/prompt)? Empirical — spec §2A verify 3 | open | 2A human verify |
| — | carried | R4 (phase 0): close by exercising a Keychain read under the 5RC66Q82V9 identity — precondition satisfied since R27 | open | any authed-endpoint work |
| Q6 | 2026-07-05 | D29a effectiveness: `prepare()` at init precedes graph configuration (inputNode untouched by design — no HAL/TCC poke), so warm-up may be limited until first start(). Kept as-is; §2C verify 4 records observed warming duration → tester baselines, which closes this either way (D29b pill-truth is the load-bearing fix regardless) | closed 2026-07-05 (D34): worse than ineffective — fatal NSException on the empty graph, silent launch abort | — |

## Notes

2026-07-05: 2C SHAPE NON-OBJECTION. Transitions = spec §2C state model; sole-
ownership invariant holds (DictationController owns state, pill display-only,
four-method surface per D33). D23 error-path generation guard ruled consistent:
spec "stale results never touch the pill" always covered error results — an
error flash is a result. Code-verified guards (DictationController.swift:102
success, :124 catch). No spec change. D29a effectiveness → Q6 (pending).

2026-07-05: 2B SHAPE NON-OBJECTION. R33 accepted (D33, spec §2B round-tripped).
Other 4 beyond-spec additions (`isReleasedWhenClosed = false`, setContentSize
re-assert, paddedLevels fill-from-right, optional-screen guard) confirmed
execution-level — no shape change, no round-trip. R29 fix code-verified:
`chordKeyDownPassedThrough` refuses start/swallow until a clean keyUp (R29
option 1) under the D30 pair-balance invariant — matches mandated disposition.

2026-07-04: docs/phase-2-spec.md authored — sub-phases 2A (swallowing + RMS,
pure logic first) → 2B (PillPanel + waveform, unreachable but committable)
→ 2C (state wiring + cold-start, human phase gate). D28's promotion and Q4's
ruling are both inside Phase 2 scope per phase-1 close.
