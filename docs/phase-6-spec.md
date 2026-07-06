# Phase 6 Spec — Insertion hardening (PLAN.md §Phase 6)

> Authored by architect, 2026-07-05. Rulings D61–D65 in
> docs/phase-6-architect-log.md; D1–D60 remain binding (carry pointer
> there). Baseline: 177 tests / 18 suites at 94c4b5d. LoC budgets are
> ceilings. No third-party deps (D7). No new entitlements or Info.plist
> keys: AX insertion rides the already-granted Accessibility TCC
> (Permissions.swift `AXIsProcessTrusted()`), Carbon/HIToolbox links via
> auto-linking, pasteboard privacy is a runtime pane, not an entitlement.
>
> **Standing context:** vLLM is DOWN and the user is AWAY (Q4-2). Every
> sub-phase below is machine-verifiable-first and committable during the
> blocked window. Verify items are classified MACHINE / AT-SCREEN
> (no vLLM) / BLOCKED-BATCH (needs live dictation); the orchestrator
> copies the latter two classes into when-vllm-is-back.md verbatim.

## Requirement (PLAN.md §Phase 6, authoritative)

1. AX-first insertion (`AXUIElement` selected-text replacement) where the
   focused element supports it; pasteboard+Cmd-V fallback.
2. Clipboard restore gated on NSPasteboard privacy state; testable under
   `EnablePasteboardPrivacyDeveloperPreview`.
3. Secure-input detection (`IsSecureEventInputEnabled`) → pill shows
   "can't dictate here".

**PLAN verify:** clipboard survives a dictation; password field shows the
blocked state; Electron apps (Slack/VS Code) still work via fallback.

## Cross-cutting design

- **Seam posture (D61/D63, mirrors D49/D52):** AX calls,
  `IsSecureEventInputEnabled()`, and NSPasteboard stay adapter-side as
  DIRECT calls — no protocol seams, no DI. The DECISION LOGIC moves to a
  new pure Foundation-only `InsertionPolicy.swift` (D40/D50 proven shape:
  pure enum + static functions, inputs as arguments, no AppKit/Carbon).
  Under tests the adapter branches are unreachable (no real AX target, no
  secure input in the test runner) — like D49, no adapter test is owed;
  the policy suite carries the semantics.
- **Failure chain (D43, never eat the user's words):** AX route fails at
  ANY step → pasteboard+Cmd-V fallback runs in the same `insert` call.
  If CGEvent synthesis then also fails, the text is already ON the
  pasteboard (write precedes synthesis, Phase-1 order kept) — that is the
  last-resort landing spot; log says so. No path discards text.
- **Phase-1 §1D amendment (D62 amends D20):** "zero pasteboard reads
  anywhere" becomes "pasteboard reads confined to TextInserter's gated
  save/restore path". Grep-enforced (see 6C verify).
- **Untouched surfaces:** hotkey path, recorder, transcription/cleanup
  services and their request shapes (D39/D45), generation discipline
  (D23), pill driver pattern (§2C — DictationController stays sole
  driver), history (D41), `cleanup(transcript:frontmostBundleID:)` (D52).

## Sub-phase 6A — Secure-input blocked state

**Pill state (D64):** `PillState` gains top-level `case blocked` (not the
staged family — it is pre-dictation, not a pipeline stage).
- `flashDuration`: new `PillMetrics.blockedFlashDuration: TimeInterval
  = 1.6` (a sentence needs more read time than symbols; D31 single-site;
  D48's 0.8/1.2 literals untouched).
- `PillView` render arm (exhaustive switch forces it): HStack(spacing 8)
  of `lock.fill` `.title2` systemOrange + `Text("Can't dictate here")`
  `.font(.callout)`. First text label in the pill — ruled acceptable
  because a bare lock glyph is unlearnable (D64 rationale); orange =
  environmental warning, consistent with D48's amber (red stays
  transcription-failure-only, D43).

**Controller guard (D63):** in `DictationController.startRecording()`,
FIRST line, before the `generation += 1` bump:

```swift
guard !IsSecureEventInputEnabled() else {
    Self.logger.info("secure input active — dictation blocked")
    pill.show(.blocked)
    return
}
```

`import Carbon` added to DictationController.swift. Placement before the
bump is load-bearing: a blocked press must NOT invalidate an in-flight
prior dictation (D23/D43 — its words still land). `isRecording` stays
false → key-up hits the existing `guard isRecording` no-op. Checked at
key-down only (D52 precedent: intent binds at key-down); no re-check at
insert time (out of scope, revisit only if live testing surfaces it).

**Deliverables + LoC ceilings:**
- `PillState.swift` delta (~10): case + flash arm + metrics constant.
- `PillView.swift` delta (~14): blocked render arm.
- `DictationController.swift` delta (~8): import + guard.
- `Tests/PillStateTests.swift` delta (~14): `.blocked` flashDuration ==
  blockedFlashDuration; blocked is non-sticky (non-nil); constant is 1.6.

**Verify (6A):**
1. MACHINE: `make test` green ×2 (delta ≈ +2 tests vs 177/18; tester
   records exacts).
2. MACHINE: grep — `IsSecureEventInputEnabled` appears only in
   DictationController.swift; guard precedes `generation += 1`.
3. AT-SCREEN (no vLLM): In Terminal, enable Terminal → Secure Keyboard
   Entry. Focus Terminal and press-and-hold the dictation chord: the pill
   flashes an orange lock + "Can't dictate here" (~1.6 s), no waveform
   ever appears; release the chord: nothing inserted, no error flash.
   Disable Secure Keyboard Entry, press-and-hold again: warming bars then
   live waveform appear (no vLLM needed — network starts only at key-up;
   an error flash after release is expected and fine while vLLM is down).
4. AT-SCREEN (no vLLM): Click into a browser password field (any login
   page) and press-and-hold the chord: same blocked flash, no recording.

## Sub-phase 6B — AX-first insertion + fallback

**Pure route (D61/D65):** new `InsertionPolicy.swift` (Foundation-only):

```swift
enum InsertionRoute: Equatable { case ax, pasteboard }

enum InsertionPolicy {
    /// AX only when the focused element was found AND reports
    /// kAXSelectedText settable; anything less → pasteboard.
    static func route(focusedElementFound: Bool,
                      selectedTextSettable: Bool) -> InsertionRoute
}
```

**Adapter (D61), in TextInserter:** `insert(_:)` becomes route-then-land:
1. **Probe:** `AXUIElementCreateSystemWide()` →
   `AXUIElementSetMessagingTimeout(systemWide, 0.25)` (a beachballing
   target must not stall insertion past PLAN's <50 ms budget by seconds)
   → `AXUIElementCopyAttributeValue(systemWide,
   kAXFocusedUIElementAttribute, &focused)`; "found" = `.success` and a
   non-nil AXUIElement → `AXUIElementIsAttributeSettable(focused,
   kAXSelectedTextAttribute, &settable)`; "settable" = `.success` &&
   `settable`. Feed both booleans to `InsertionPolicy.route`.
2. **AX route:** `AXUIElementSetAttributeValue(focused,
   kAXSelectedTextAttribute, text as CFString)` — replaces the selection
   or inserts at the caret. Non-`.success` → fall through to the
   pasteboard route in the same call (D43 chain). NO readback
   verification (rejected, D61: reading kAXValue on large documents is
   slow/fragile; silent-success apps are an empirical question → Q6-2,
   answered by the 6B batch matrix, escape hatch = bundle denylist ruled
   only if the matrix demands it).
3. **Pasteboard route:** today's write + Cmd-V, byte-identical behavior.
4. One log line per insertion naming the route taken (and `ax-fallback`
   when step 2 fell through) — the batch matrix reads it from Console.

**Deliverables + LoC ceilings:**
- `InsertionPolicy.swift` (~25, new): route enum + function, doc comments
  citing D61/D65.
- `TextInserter.swift` delta (~55): probe, AX set, routing, logs.
  `import ApplicationServices` (Permissions.swift precedent).
- `Tests/InsertionPolicyTests.swift` (~40, new, headless): route truth
  table — (true,true)→ax; (true,false)/(false,true)/(false,false)→
  pasteboard.

**Verify (6B):**
1. MACHINE: `make test` green ×2 (delta ≈ +4 tests, +1 suite vs 6A gate).
2. MACHINE: grep — InsertionPolicy.swift imports Foundation only; no
   AX *usage* (imports/calls in code) outside TextInserter.swift
   (Permissions.swift's `AXIsProcessTrusted` excepted; comment-only
   mentions of AX names, e.g. kAXSelectedText in doc comments, are
   tolerated — R57). Same reading applies wherever this grep re-runs
   (6C gate).
3. BLOCKED-BATCH (insertion matrix — for each app dictate a short
   utterance and check Console for the route log): TextEdit (expect
   route=ax; text lands at caret; then select a word first and dictate —
   selection replaced), Slack and VS Code (expect fallback or ax-fallback;
   text still lands — PLAN's Electron requirement), Safari textarea
   (record route; text lands), Mail compose (record route; text lands),
   Terminal with Secure Keyboard Entry OFF (record route and whether text
   lands — closes Phase-1 Q3's deferred handling question, Q6-3).
4. BLOCKED-BATCH: dictate mid-sentence in TextEdit with the caret between
   existing words — text lands at the caret without eating neighbors.

**Invariants (6B):** pasteboard route byte-identical to Phase 1 (write →
Cmd-V, clobber still accepted until 6C); no pasteboard reads yet; AX
failure can never surface to the user as lost text (D43 chain).

## Sub-phase 6C — Clipboard save/restore

**Pure gate (D62):** `InsertionPolicy.swift` gains:

```swift
/// Foundation-only mirror of NSPasteboard.AccessBehavior (macOS 15.4);
/// .unavailable = pre-15.4 API absent (no enforcement exists there).
enum PasteboardAccessGate: Equatable {
    case unavailable, standard, ask, alwaysAllow, alwaysDeny
}

extension InsertionPolicy {
    /// Save+restore only when reading cannot prompt or fail:
    /// unavailable/standard/alwaysAllow → true; ask/alwaysDeny → false.
    static func shouldSaveClipboard(gate: PasteboardAccessGate) -> Bool
    /// Restore only if nothing else wrote since our write.
    static func shouldRestore(hasSnapshot: Bool,
                              writtenChangeCount: Int,
                              currentChangeCount: Int) -> Bool
}
```

Rationale (D62): a read under `.ask` fires the system alert mid-dictation
while a synthesized Cmd-V is in flight — the alert steals focus and the
paste lands in the dialog (a D43 violation). Skipping restore there is
the Phase-1 clobber behavior, which shipped and is accepted. `.standard`
(`.default` in AppKit; renamed — `default` is a Swift keyword) means no
enforcement is active today → read freely; Q6-1 confirms the preview flag
flips the reported behavior to `.ask` rather than alerting under
`.standard`.

**Adapter (D62), pasteboard route only (AX route never touches the
pasteboard → clipboard trivially survives):**
1. Map `NSPasteboard.general.accessBehavior` → gate under
   `if #available(macOS 15.4, *)`, else `.unavailable`.
2. If `shouldSaveClipboard`: snapshot ALL items — for each
   `pasteboard.pasteboardItems` item, each of its `types`,
   `data(forType:)` → `[[NSPasteboard.PasteboardType: Data]]` (string-only
   restore rejected: PLAN says clipboard CONTENTS survive — images/files
   included). Empty pasteboard snapshots as `[]` (restore = clear).
3. Write + Cmd-V as today; record the written `changeCount`.
4. `DispatchQueue.main.asyncAfter(deadline: .now() +
   PillMetrics-style single-site constant `TextInserter.restoreDelay =
   0.5`)`: guard `InsertionPolicy.shouldRestore(...)` with the LIVE
   `changeCount` — another writer (user copy, clipboard manager, a
   second dictation's own write) bumped it → skip, never clobber newer
   content. Else `clearContents()` + rebuild `NSPasteboardItem`s from the
   snapshot. 0.5 s ≈ 5× the observed synthesized-paste handling time;
   restoring before the target app reads the pasteboard would paste the
   OLD clipboard (D43 violation), so the constant errs long — revisit
   trigger: any batch-matrix late-paste observation.

**Deliverables + LoC ceilings:**
- `InsertionPolicy.swift` delta (~20): gate enum + two functions.
- `TextInserter.swift` delta (~50): gate mapping, snapshot, delayed
  restore, logs (saved/restored/skipped + reason).
- `Tests/InsertionPolicyTests.swift` delta (~45): shouldSaveClipboard
  truth table (all five gates); shouldRestore — no snapshot → false;
  changeCount moved → false; equal + snapshot → true.

**Verify (6C):**
1. MACHINE: `make test` green ×2 (delta ≈ +8 tests vs 6B gate).
2. MACHINE: grep — pasteboard READS (`pasteboardItems`, `data(forType:`,
   `string(forType:`) appear in TextInserter.swift only (D62 amendment
   boundary); `accessBehavior` only behind `#available(macOS 15.4, *)`.
3. BLOCKED-BATCH (PLAN verify): copy a distinctive string; dictate into
   Slack (pasteboard route); within a second of the text landing, press
   Cmd-V manually in TextEdit — the ORIGINAL string pastes (clipboard
   survived). Repeat with a copied IMAGE (screenshot) — image survives.
4. BLOCKED-BATCH: copy a string, dictate, and DURING the processing pill
   copy a different string; after insertion, paste — the SECOND string is
   intact (changeCount guard; restore skipped, Console log says so).
5. BLOCKED-BATCH (privacy preview): run `defaults write
   com.garisonlotus.LotusScribe EnablePasteboardPrivacyDeveloperPreview
   -bool YES`, relaunch LotusScribe. With no pasteboard grant: dictate
   into Slack — NO system pasteboard alert appears at any point, text
   lands, clipboard is clobbered (restore skipped, log says gate=ask —
   this also answers Q6-1). Then in System Settings → Privacy & Security
   → Pasteboard set LotusScribe to Always Allow: dictate again — clipboard
   survives. Finish: `defaults delete com.garisonlotus.LotusScribe
   EnablePasteboardPrivacyDeveloperPreview`.

**Invariants (6C):** AX route does zero pasteboard traffic; a skipped
restore is always silent-but-logged (no pill/alert surface — D38);
restore can never fire while a newer write is on the board; write→Cmd-V
ordering unchanged (text on board before synthesis, D43 last resort).

## Out of scope (explicit)

- Per-bundle AX denylist / readback verification (Q6-2 escape hatch —
  built only if the 6B matrix demands it).
- Secure-input re-check at insert time; polling secure-input state while
  the pill is up.
- kAXValue/kAXSelectedTextRange caret manipulation, AX for
  per-website context (D55 stands).
- Restore-delay configurability; transient/concealed pasteboard type
  marking (Phase-7 polish candidate, not requested).
