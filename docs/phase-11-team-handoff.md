# Team Handoff — LotusScribe (Phase 11)

> Restarting orchestrator: single entry point. Read this, then the three
> phase-11 role logs, then verify git state. Phase 0–10 docs are archives.

**Last updated:** 2026-07-08, **PHASE 11 CLOSED** (11A–11D committed + human-verified).

## §1. How to use this doc

Project follows the `phased-delivery` skill
(`/Users/garisondraper/.claude/skills/phased-delivery/`). Docs are
phase-numbered (CLAUDE.md §5): `docs/phase-11-*.md`. Decision numbering:
docs stopped at D105, but commit messages claim D106 (hotkey ⌘⌥D, 8db562b)
and D107 (cleanup injection, 267cfd3/a49945f). Phase 11 uses **D108+** to
avoid collision (Q11-1, resolved).

## §2. Project context

LotusScribe: native Swift macOS menu-bar dictation app (LSUIElement). Phases
0–10 built the pipeline, the "Lotus Bloom" reskin, user-selectable hotkey
(⌘⌥D default, D106 — supersedes the ⌃⌥D of D105), and a 4-step onboarding
with a server-setup step. Phase
10 closed code-complete at 271 tests / 24 suites.

**Phase 11 = MICROPHONE SELECTION.** User request: pick which audio input
device dictation records from, instead of always using the system default.
Today `AudioRecorder` uses `AVAudioEngine.inputNode` (always the OS default
input); there is no device-selection surface anywhere.

## §3. Locked product decisions (from user, 2026-07-08)

Confirmed via a clarify pass BEFORE this phase opened:

1. **Two surfaces.** A "Microphone ▸" submenu in the status-bar menu
   (`StatusItemController`) AND a mirror picker in the Settings window. Both
   stay in sync.
2. **Follow-system entry + pin.** A top "System Default (follow)" entry that
   always tracks whatever macOS picks, PLUS the ability to pin a specific
   device. A pinned device that is gone at dictation time → **silent
   fallback** to the system default (no warning, no error pill).
3. **"System Default" shows its resolved name** — e.g. "System Default
   (MacBook Pro Microphone)" — so the user knows what following-system means
   right now.
4. **Selection applies at the NEXT dictation**, not mid-recording. The device
   is set before `engine.start()`; no live device swap.
5. **Settings picker saves instantly** (live write-through), matching the
   hotkey picker pattern (`lotusHotkeyChanged` notification), NOT the buffered
   `SettingsDraft`/Save flow used for endpoints. A new
   `lotusInputDeviceChanged` notification keeps menu + Settings checkmarks in
   sync.
6. **No level meter.** Device list + checkmark only. The pill waveform during
   dictation already confirms the mic works.

**Persistence:** store the chosen device by its Core Audio **UID** (stable
across reboot/replug), NOT its name. nil/empty UID = follow system.

**Orchestrator implementation calls (stated to user, un-objected):**
- Device list includes any input-capable device (input channel count > 0),
  including virtual mics (Loopback etc.); excludes output-only devices.
- Menu submenu rebuilds on open (NSMenu delegate) so replug reflects live.
- Recorder does NOT observe the notification — it reads the UID at
  `start()`. The notification only refreshes the two UI checkmarks.

## §4. Current state

**Where we are:** **PHASE 11 CODE-COMPLETE.** All four sub-phases committed:
- **11A** (`13e2222`) — device layer (`AudioInputDevice` pure +
  `CoreAudioDeviceEnumerator` edge), `inputDeviceUID`, `InputDeviceSetting` /
  `.lotusInputDeviceChanged`. +13 tests (284/25).
- **11B** (`7dd0173`) — `AudioRecorder` pins the chosen device before the
  engine runs (D112); pin-first-then-read-format ordering (D117); silent
  fallback (D88).
- **11C** (`c234954`) — "Microphone ▸" status-bar submenu, rebuilt on open.
- **11D** (final) — Settings `MicrophonePicker` + card, live write-through,
  `.lotusInputDeviceChanged`-synced; in-menu checkmark kept (D118).

Each sub-phase cleared its 4-way gate. **Tests: 284/25, 0 failures** (all +13
in 11A; 11B–11D are UI/edge, no new units).

**HUMAN-AT-SCREEN verification: DONE (2026-07-08).** User confirmed
"everything is working" — device switching, silent fallback, both surfaces,
and cross-surface sync all verified at the machine. **PHASE 11 CLOSED.** The
checklist below is retained as the record of what was verified:
1. **11B core** — pin an EXTERNAL/USB mic whose native rate differs from the
   built-in (`defaults write com.garisonlotus.LotusScribe inputDeviceUID <UID>`,
   or pick it in the menu), then dictate → capture comes from that mic, NO
   crash (R11B-1: this is the D117 fix's real proof).
2. Bogus/unplugged UID → dictation still works from the system default (silent
   fallback); clear the key → follows system; pin survives app relaunch.
3. **11C** — menu "Microphone ▸" lists System Default (resolved name) + all
   input devices; checkmark on the active choice; clicking pins; reopen after
   replug shows the new list.
4. **11D** — Settings Microphone card mirrors the list; picking pins; changing
   the device in the status-bar submenu while Settings is open updates the
   Settings picker (and vice-versa) via `.lotusInputDeviceChanged`.

**Active gate:** none — PHASE 11 CLOSED (code + human verify complete).

---
_(prior 11B state — retained for context)_

**11B CLOSED** — `AudioRecorder.start()` pins the chosen
input device (via `AUAudioUnit.setDeviceID`, resolved at compile) BEFORE the
engine runs; nil/unresolved/pin-error → silent fallback to system default
(D88). Gate caught + fixed an ordering bug (D117): the tap/converter must read
`inputFormat` AFTER the pin, else `installTap` crashes on a sample-rate
mismatch (external mics). Order now: pin → read format → guard → tap → start;
§1B preserved. 4-way gate cleared: reviewer APPROVED, architect ruled/blessed
via D117, tester reproducible-green. **Next: 11C** — "Microphone ▸" status-bar
submenu in `StatusItemController`, rebuilt on open via `NSMenuDelegate`,
rendering the shared `AudioInputMenuModel`; click writes `InputDeviceSetting.set`.
**Baseline tests:** 284 tests / 25 suites, 0 failures, `make test` (11B adds
no tests — edge change).
**Active gate:** none open — 11B committed; 11C not yet dispatched.
**Pending HUMAN-AT-SCREEN (deferred, non-blocking):** 11B `defaults write
com.garisonlotus.LotusScribe inputDeviceUID <UID>` → capture from that device;
bogus/unplugged UID → silent fallback; cleared → follows system; pin survives
relaunch. Exercise an EXTERNAL/USB mic at a differing native rate (R11B-1 —
the D117 fix's real proof).
**Open reviewer items:** R11A-1 (double `inputDevices()` call), R11A-3 (benign
TOCTOU in `allDeviceIDs`), R11B-2 (`devices` seam not wired to an initializer —
spec-sanctioned YAGNI). All non-blocking. (R11A-2 resolved by D116.)

## §5. Load-bearing constraints (do not break)

- **D14:** pure/headless logic separated from TCC/UI for testability. Core
  Audio device enumeration must have a pure/testable seam where feasible.
- **AudioRecorder §1B invariant:** the engine runs only between `start()` and
  `stop()`. Device selection happens BEFORE `engine.start()`; do not add a
  device swap while running.
- **D88:** Input Monitoring request lives in `main.swift` before any AX check
  (rdar://7381305). Do not touch that ordering. (Mic TCC is separate — first
  `engine.start()` triggers it; device enumeration must degrade gracefully
  before mic permission is granted.)
- Reskin rules: no raw hex in views, LotusTheme components only, respect the
  design system, min 11pt text, honor Reduce Motion.
- **Live write-through pattern** for the mic setting mirrors `hotkeyChord`
  (D83): SettingsStore write + notification post; NOT the buffered
  `SettingsDraft`. Do not route the mic setting through `SettingsDraft`/Save.
- App logic / networking / transcription / cleanup semantics unchanged — this
  is a capture-source selection + two UI surfaces + one settings key.

## §6. Pointers

- Spec: `docs/phase-11-spec.md` (architect authoring)
- Architect decisions: `docs/phase-11-architect-log.md`
- Reviewer items: `docs/phase-11-reviewer-observations.md`
- Tester baselines: `docs/phase-11-tester-baselines.md`
- Key existing code: `AudioRecorder.swift` (uses `engine.inputNode` — the
  capture site to make device-aware), `StatusItemController.swift` (the menu
  to add the submenu to), `SettingsStore.swift` (add the UID key),
  `SettingsForm.swift` / `SettingsWindowController.swift` (mirror picker +
  live write-through), `HotkeyPicker.swift` / `AppDelegate.swift`
  (`lotusHotkeyChanged` — the live-write-through + notification pattern to
  mirror), `DictationController.swift` (owns the single `AudioRecorder`).
- Carried-forward open reviewer items (non-blocking, unrelated): R10A-2
  (linear map scan in `keyName`), R10E2-1 (implicit `stepIndex` gate).
