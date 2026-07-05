# Reviewer observations — LotusScribe (Phase 4)

> Forward-looking items for Phase 4. Archives: phase-0 (R1–R4), phase-1
> (R5–R28), phase-2 (R29–R35), phase-3 (R36–R42). Numbering continues at
> R43. Only still-open rows carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R7 | 1A (carried) | Combo keycode map is ANSI-positional (kVK_ANSI_*): "z" means the physical ANSI-Z key, not the layout character (AZERTY/Dvorak diverge). Revisit when hotkey-config UI lands (Phase 7+) | open (future phase, note only) |
| R34 | 2C (carried) | Straggler-attribution micro-window: a queued level block from a just-stopped capture could flip a NEW capture's `.warming` → `.recording` one frame early — not realistic; cosmetic even if hit. Blocked-window ruling (phase-3 log): stays note-only, no speculative fix | open (note only) |
| R35 | 2C (carried) | STANDING RULE — construction-smoke coverage for composition roots: any TCC-free composition-root type constructed on the launch path gets a construction test at introduction, not after a regression (D34 lesson; AppKit swallows init-time NSExceptions silently) | open (process rule) |
| R41 | 3C (carried) | Latent test-hygiene hazard: SettingsWindowController's default warm-up closure runs a REAL `CleanupService.warmUp()` network Task; XCTestSessionIdentifier guard covers only the AppDelegate launch trigger. Every current test stubs `warmUp:` or never persists a changed LLM config. Blocked-window ruling: stays backlog; revisit only if a test ever constructs the controller without a stub. **Phase-4 relevance: 4C touches SettingsWindowControllerTests — new tests there MUST keep stubbing `warmUp:`** | open (note only, 4C watch) |
| R42 | 3D (carried) | Slot-1 truthfulness wrinkle on the stale-drop path: staged slot 1 shows "STT succeeded" at transcript-accept, pre-insert; a deliberate overlapping dictation drops gen N after that display. Accepted as D47's framing (slot 1 = STT proof, not insert proof); note only | open (note only) |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
|    | (none yet)   |      |        |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
