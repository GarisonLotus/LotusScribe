# Reviewer observations — LotusScribe (Phase 1)

> Forward-looking items for Phase 1. Phase-0 archive:
> docs/phase-0-reviewer-observations.md (R1–R4; numbering continues here).

## Items

| id | first raised | item | status |
|----|--------------|------|--------|
| R3 | 0B (carried) | 0A link-smoke test: repoint at real behavior in Phase 1 | open |
| R4 | 0B (carried) | Legacy-keychain ACLs vs ad-hoc re-signing may break later-phase API-key reads; resolves with Q1/D12 | open |
| R5 | 1A | TCC-request guard (AppDelegate: `XCTestSessionIdentifier` env check around `CGRequestListenEventAccess()`): execution is clean — single call site, why-comment, marker empirically verified. But whether to request at launch at all vs. drop the call (user grants via System Settings) changes the TCC empirical record (spec §1A verify 3) and Phase-7 onboarding UX → SHAPE question, routed to orchestrator | ruled: keep launch request (D22) |
| R6 | 1A | LoC ceiling overages, both engineer-flagged: HotkeyStateMachine 87 code lines vs ~80 (17-line keycode data table; splitting it out would violate one-concern norm) and AppDelegate 21 vs ~15 (the R5 guard + launch logging). Accepted — overage is data/guard, not logic creep | accepted |
| R7 | 1A | Combo keycode map is ANSI-positional (kVK_ANSI_*): "z" in `hotkeyChord` means the physical ANSI-Z key, not the character z on the user's layout (AZERTY/Dvorak diverge). Fine for Phase 1 (no hotkey UI, D15); revisit when hotkey-config UI lands | open (future phase) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
