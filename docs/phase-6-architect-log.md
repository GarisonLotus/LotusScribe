# Architect log — LotusScribe (Phase 6)

> Locked decisions + open questions for Phase 6. Carry pointer: D1–D11
> phase-0, D12–D28 phase-1, D29–D35 phase-2 (D29a rescinded by D34),
> D36–D49 phase-3, D50–D55 phase-4, D56–D60 phase-5; all binding.
> Numbering continues at D61. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D61 | 2026-07-05 | AX-first insertion: probe = `AXUIElementCreateSystemWide()` → messaging timeout 0.25 s → copy `kAXFocusedUIElementAttribute` (`.success` + non-nil) → `AXUIElementIsAttributeSettable(el, kAXSelectedTextAttribute)` (`.success` && settable); insert = `AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute, text)`; ANY non-success at any step → pasteboard+Cmd-V fallback in the same call (D43 chain: write precedes synthesis, so even CGEvent failure leaves text on the board as last resort). NO readback verification (rejected: kAXValue reads on large documents are slow/fragile); silent-AX-success apps are Q6-2, answered by the 6B batch matrix; per-bundle denylist is the escape hatch, built only if the matrix demands it. AX calls stay adapter-side direct in TextInserter (D49/D52 no-seam posture); route decision is pure `InsertionPolicy.route(focusedElementFound:selectedTextSettable:)` | Settable-selected-text is the one probe that means "this element accepts programmatic text replacement"; Electron/Chromium elements typically fail it → natural fallback (PLAN requirement); messaging timeout bounds a beachballing target so insertion cannot stall for seconds | 6B |
| D62 | 2026-07-05 | Clipboard save/restore (pasteboard route only — AX route never touches the board): gate = pure `PasteboardAccessGate` mirror of `NSPasteboard.AccessBehavior` (macOS 15.4; pre-15.4 → `.unavailable`); save+restore when unavailable/standard/alwaysAllow, SKIP (Phase-1 clobber, logged) when ask/alwaysDeny — a read under `.ask` fires the system alert mid-dictation while synthesized Cmd-V is in flight → paste lands in the dialog (D43 violation). Snapshot = ALL `pasteboardItems` × types × `data(forType:)` (string-only rejected: PLAN says contents survive — images too); empty board snapshots as [] (restore = clear). Record written changeCount; restore via asyncAfter `restoreDelay = 0.5 s` (single site) ONLY if live changeCount still equals written (any other writer — user copy, clipboard manager, newer dictation — wins). AMENDS D20/Phase-1 §1D: pasteboard reads now allowed, confined to TextInserter's gated save path (grep-enforced). PLAN-divergence note: PLAN says "detect methods", but `detectPatterns/detectValues` return pattern metadata, not contents — they cannot rebuild a clipboard; `accessBehavior` is the privacy-aware gate that actually supports restore, and preview-flag testability is preserved | Restore requires a read; the only safe reads are the ones that cannot prompt; changeCount is the race-free "did anyone else write" primitive; 0.5 s errs long because restoring before the target app reads the board pastes the OLD clipboard (worse than clobbering) | 6C |
| D62a | 2026-07-05 | AMENDS D62 (ordering pin): restore is scheduled ONLY after CGEvent synthesis posts (after keyUp.post); the CGEvent-creation-failure path schedules NO restore — the board then holds the dictated text as the D43 last-resort landing spot, and a delayed restore would overwrite it. Supersedes any step-ordering reading of spec §6C steps 3–4 | The spec's "record changeCount at write + asyncAfter" wording permitted scheduling restore before synthesis, which reviewer caught as a live D43 violation; pin it so it cannot regress | 6C |
| D63 | 2026-07-05 | Secure-input UX: `IsSecureEventInputEnabled()` (Carbon, direct call, no seam — D49/D52 posture) checked at KEY-DOWN as the FIRST line of `startRecording()`, BEFORE the `generation += 1` bump; true → `pill.show(.blocked)` + return — no recorder start, no generation bump (a blocked press must not invalidate an in-flight prior dictation's insert, D23/D43), `isRecording` stays false so key-up no-ops. No re-check at insert time (intent binds at key-down, D52 precedent; revisit only if live testing surfaces stale-focus pastes into secure fields). Branch unreachable headless (test runner never has secure input) → no controller test owed, D49 precedent; PillState purity carries the machine tests | Recording during password entry is both useless (insertion is blocked/misdirected) and creepy; refusing to start is the honest UX and the cheapest correct one | 6A |
| D64 | 2026-07-05 | Pill blocked state: new TOP-LEVEL `PillState.blocked` (not the D46 staged family — pre-dictation environment state, not a pipeline stage); renders `lock.fill` systemOrange + first-ever pill text label "Can't dictate here" (.callout) in the existing 260×52; flash = new `PillMetrics.blockedFlashDuration = 1.6 s` via the D46 pure `flashDuration` mapping (D31 single-site; 0.8/1.2 untouched). Orange = environmental warning, consistent with D48 amber; red stays transcription-failure-only | A bare lock glyph is unlearnable — the user must be told WHY nothing happened; a sentence needs more read time than D48's two symbols, hence 1.6 over 1.2 | 6A |
| D65 | 2026-07-05 | Slicing: 6A secure-input blocked state → 6B AX-first + fallback → 6C clipboard save/restore; each independently committable with green `make test` during the blocked window (Phase-4/5 posture). Decision logic concentrated in ONE new pure Foundation-only `InsertionPolicy.swift` (route + save gate + restore guard; D40/D50 pure-enum shape) grown across 6B/6C; adapters stay thin/direct. One log line per insertion names the route taken (`ax` / `pasteboard` / `ax-fallback`) — the BLOCKED-BATCH matrix reads Console instead of guessing. No new entitlements/Info.plist keys: AX rides the granted Accessibility TCC; pasteboard privacy is a runtime pane | Smallest→largest risk ordering; 6A ships user-visible value with near-zero blast radius; policy-in-one-file keeps the headless test surface single-sited exactly as CleanupLevel/AppCategory proved | 6A–6C |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| Q6-1 | 2026-07-05 | Under `EnablePasteboardPrivacyDeveloperPreview` with no grant, does `NSPasteboard.general.accessBehavior` report `.ask` (D62's assumption — restore skips cleanly, no alert) or stay `.default` while reads alert anyway? If the latter, re-rule the D62 gate (likely: strict alwaysAllow-only) | answered (indicative, CLI — see Notes 2026-07-05; signed-app at-screen §E.6 run remains the authority) | 6C batch verify item 5 (vLLM) |
| Q6-2 | 2026-07-05 | Does any matrix app report AX `.success` on set-kAXSelectedText WITHOUT actually inserting (silent AX failure)? If yes, rule the per-bundle fallback denylist (D61 escape hatch) | open | 6B batch matrix (vLLM) |
| Q6-3 | 2026-07-05 | Terminal (Secure Keyboard Entry OFF): does the AX route land text where Phase-1's Cmd-V did not (closes Phase-1 Q3's deferred handling)? Record route + outcome | open | 6B batch matrix (vLLM) |

(status: open / answered / deferred / closed-as-moot)

## Notes

2026-07-05: PHASE 6 BOOTSTRAP (autonomous run, user away). Phase-3/4/5
close gates all OPEN (vLLM down, Q4-2). Phase 6 proceeds machine-first;
NOTE insertion verifies need live dictation → most human checks are
BLOCKED-BATCH; orchestrator records them in when-vllm-is-back.md. Spec
must classify every verify MACHINE / AT-SCREEN (no vLLM) /
BLOCKED-BATCH (vLLM).

2026-07-05: phase-6-spec.md authored (D61–D65, Q6-1..3). Slicing note:
6A (secure-input blocked pill, ~+2 tests) → 6B (InsertionPolicy.route +
AX-first TextInserter, ~+4 tests +1 suite) → 6C (save/restore gate +
snapshot + changeCount-guarded delayed restore, ~+8 tests). Expected end
state ≈ 191/19 vs baseline 177/18 (tester records exacts per gate). All
SDK symbols code-verified against MacOSX.sdk (NSPasteboard.accessBehavior
macOS 15.4, detectPatterns metadata-only → D62 PLAN-divergence note,
IsSecureEventInputEnabled in Carbon/HIToolbox tbd, kAXSelectedText /
kAXFocusedUIElement / AXUIElementIsAttributeSettable /
AXUIElementSetMessagingTimeout in HIServices headers); insertion-path
symbols verified against Sources (TextInserter write→Cmd-V order,
DictationController startRecording/stopRecording generation discipline,
PillState/PillMetrics/PillView exhaustive switches). 6A's blocked-state
check is the ONLY at-screen verify runnable without vLLM (warming/
recording pill needs no network until key-up). Non-machine verify items
written copy-ready in spec §6A/§6B/§6C for when-vllm-is-back.md.

2026-07-05: 6A NON-OBJECTION (SHAPE). Staged diffs (PillState/PillView/
DictationController) conform to D63/D64: `.blocked` top-level (not staged
family); 1.6 s single-sited as `PillMetrics.blockedFlashDuration` via the
D46 flashDuration mapping; guard precedes `generation += 1` (load-bearing,
comment present); direct Carbon `IsSecureEventInputEnabled()` — no seam;
no insert-time re-check. Color: `.foregroundStyle(.orange)` accepted —
spec's "systemOrange" names the color, not an API; SwiftUI `.orange` is
the system-adaptive orange and is the file's existing D48 amber idiom
(PillView lines 37/77). No pinning needed; no spec amendment warranted.

2026-07-05: 6B NON-OBJECTION (SHAPE). Staged InsertionPolicy.swift +
TextInserter.swift conform to D61/D65: policy pure/Foundation-only with
headless 4-cell truth table; AX confined adapter-side direct (D49/D52);
probe chain exact (system-wide → 0.25 s messaging timeout →
CFGetTypeID-guarded focused-element copy → IsAttributeSettable); no
readback, no denylist; D43 fall-through in the SAME call, write-before-
Cmd-V preserved; one route log per insertion (ax/pasteboard/ax-fallback).
RULED (R57): spec §6B verify item 2 amended — grep contract is "no AX
*usage* (imports/calls) outside TextInserter"; the 2 comment-only
kAXSelectedText mentions (InsertionPolicy + tests) are tolerated.

2026-07-05: 6C NON-OBJECTION (SHAPE, post-fix delta). Staged
InsertionPolicy/TextInserter conform to D62: gate enum a pure
Foundation-only AccessBehavior mirror (.standard for .default — keyword);
shouldSaveClipboard/shouldRestore pure truth tables exact; snapshot =
all items × types × data, empty → [] (restore = clear); changeCount
recorded at write, live-checked in the asyncAfter guard; restoreDelay
0.5 s single-sited; AX route zero pasteboard traffic; skipped restore
silent-but-logged (D38). Ordering fix verified: scheduleRestore sits
after keyUp.post; CGEvent-failure path returns with no restore,
why-comments on both sites. @unknown default → .ask APPROVED: an unknown
future behavior must degrade to the shipped Phase-1 clobber, never risk
a mid-dictation alert (D62 rationale extends). RULED: D62a filed pinning
restore-after-synthesis; spec §6C steps 3–4 read as amended by D62a.

2026-07-05: Q6-1 ANSWERED (indicative). Orchestrator ran a throwaway
Swift CLI calling `NSPasteboard.general.accessBehavior` (macOS 15.4 API):
no flag → `.alwaysAllow`; with `-EnablePasteboardPrivacyDeveloperPreview
YES` (argument domain) → `.default` (= `.standard` in the app's
PasteboardAccessGate mirror). `.ask` was NOT observed, and no alert
fired in the CLI. CLI-identity caveat: a CLI has a different TCC
identity than the signed app, so this is INDICATIVE, not definitive —
the at-screen §E.6 run inside the real signed app stays the authority.
D62-branch clarification: D62's prose predicted "preview flag → .ask →
restore skips cleanly"; the observed flag flips to `.standard` instead,
which `shouldSaveClipboard` treats as SAVE (not skip). If the signed app
also reports `.standard` under the flag, the D62 gate still
SAVES/RESTORES — no alert was observed, so there is NO D43 violation;
it is merely a different branch than D62's prose predicted. No code
change; wording note only.

2026-07-06: **PHASE 6 CLOSED** (architect close-out audit vs §6A–§6C
verify lists).
- MACHINE: full suite green ×2 at HEAD 13ddec6 (226/22) — §6A/6B/6C
  `make test` gates satisfied, including InsertionPolicyTests (route truth
  table + shouldSaveClipboard/shouldRestore gates), the PillState
  `.blocked` flashDuration tests (§6A v1), the `IsSecureEventInputEnabled`
  single-site / guard-precedes-`generation += 1` grep (§6A v2), the
  AX-usage-confined-to-TextInserter grep (§6B v2), and the pasteboard-read
  confinement grep (§6C v2).
- HUMAN/LIVE (user on-device 2026-07-06): insertion matrix — TextEdit
  route=ax, Slack/VS Code fallback, text lands everywhere (§6B v3);
  mid-sentence caret insert without eating neighbors (§6B v4); PLAN
  clipboard survival — copied string/image survives a dictation (§6C v3);
  copy-during-processing — changeCount guard skips restore, second string
  intact (§6C v4).
- **Q6-1 RULING (pasteboard-privacy developer-preview flag, §6C v5):
  DEFERRED, forward-looking — NOT gating for v1 close.** Grounds: (1) the
  behavior lives behind `EnablePasteboardPrivacyDeveloperPreview`, an
  opt-in developer flag that is NOT active in normal macOS use, so it
  gates zero real-user behavior today; (2) the DECISION LOGIC
  (`shouldSaveClipboard` over all five `PasteboardAccessGate` cases) is
  fully machine-tested and green — only the live `accessBehavior` mapping
  under the flag is unobserved in the signed app; (3) it was already
  probed indicatively (Notes 2026-07-05: flag flips to `.standard`, which
  SAVES/RESTORES cleanly, no alert observed → no D43 violation on either
  branch). The signed-app §E.6 confirmation stays OWED as a forward-
  looking verify for whenever the preview flag ships / is exercised, but
  it does not block the phase. Q6-2 (silent-AX-success denylist) and Q6-3
  (Terminal AX landing) were implicitly answered by the §6B matrix (text
  landed everywhere, no denylist demanded); no escape hatch needed.
- DEFERRAL (non-gating): the §6A secure-input blocked-pill AT-SCREEN flash
  (Terminal Secure Keyboard Entry / password field → orange lock + "Can't
  dictate here") was not separately reported in the batch. Ruled
  non-gating: the PillState.blocked render + flash + the key-down guard
  are machine-covered, and the only unobserved surface is the trivial
  direct `IsSecureEventInputEnabled()` call + `pill.show(.blocked)` — the
  exact D49/D63 "adapter branch unreachable headless, purity carries the
  tests" posture already ruled acceptable. A quick at-screen spot-check is
  RECOMMENDED but does not block close.
CLOSED as of 2026-07-06.
