# Reviewer observations — LotusScribe (Phase 2)

> Forward-looking items for Phase 2. Archives: phase-0 (R1–R4), phase-1
> (R5–R28). Numbering continues at R29. Only still-open rows carried.

## Carried items

| id | first raised | item | status |
|----|--------------|------|--------|
| R3 | 0B (carried) | 0A smoke test is still link-smoke (`appDelegateInitializes`, with the pre-existing "'is' test is always true" warning); repoint at real behavior when convenient | open |
| R4 | 0B (carried) | Legacy-keychain ACLs vs re-signing may break later-phase API-key reads. Precondition resolved (R27: stable team signing); close by exercising a Keychain read under the 5RC66Q82V9 identity | open |
| R7 | 1A (carried) | Combo keycode map is ANSI-positional (kVK_ANSI_*): "z" means the physical ANSI-Z key, not the layout character (AZERTY/Dvorak diverge). Revisit when hotkey-config UI lands (Phase 7+) | open (future phase) |
| R23 | 1E (carried) | macOS 26: SwiftUI-hosted AppKit windows need explicit sizing; assert `contentLayoutRect`, not window frame | absorbed into phase-2 spec (§2B, D31); close at 2B review once the test lands |

## New items

| id | first raised | item | status |
|----|--------------|------|--------|
|     |              | (none yet — starts at R29) | |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
