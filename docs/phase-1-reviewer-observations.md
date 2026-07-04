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
| R8 | 1B | **BLOCKER — data race on `AudioRecorder.converter`.** `private var converter: AVAudioConverter?` is written on the main thread (`start()` assigns, `stop()` nils) and read on the audio render thread (`appendConverted`'s `guard let converter`), with no synchronization — the NSLock guards only `pcm`. `removeTap(onBus:)` does not synchronize with an in-flight tap callback, so `stop()`'s `converter = nil` (ARC release) can race the audio thread's load+retain → over-release/use-after-free. TSan-visible; rare crash in production. Surgical fix: capture the freshly created converter in the tap closure (`installTap { [weak self] buffer, _ in self?.appendConverted(buffer, using: converter) }`) and delete the `converter` stored property — no shared mutable state remains. The `pcm` path itself is correctly locked (post-stop stragglers are cleared by `pcm.removeAll()` at next start). **Fix applied and re-reviewed:** stored property deleted, converter is a local `let` captured immutably by the tap closure, `appendConverted(_:using:)` takes it as a parameter; stop()/catch no longer touch converter state, tap-removal-on-throw intact. Reviewer re-ran `make test`: 32/4 green. Race eliminated, no behavior change beyond the fix | resolved (1B) |
| R9 | 1B | Converter tail never flushed: `stop()` discards frames buffered inside AVAudioConverter (resampler filter delay, ~ms). Inaudible for dictation (user releases after speaking); a final `.endOfStream` drain would add complexity for no 1B value. No action | accepted |
| R10 | 1B | Temp WAVs (`LotusScribe-<UUID>.wav`) are written but never deleted — they accumulate in `temporaryDirectory` until OS purge. Spec §1B mandates the temp-file hand-off itself and 1C replaces the write with TranscriptionService, so this self-resolves; flagging so 1C review confirms the write path is actually removed | open (resolves in 1C) |

## Convention-violation tracking

| id | violation | files affected | resolution plan |
|----|-----------|----------------|-----------------|
|    | (none)    |                |                 |
