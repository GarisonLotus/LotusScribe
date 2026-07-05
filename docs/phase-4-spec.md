# Phase 4 Spec — App-aware context (PLAN.md §Phase 4)

> Authored by architect, 2026-07-05. Rulings D50–D55 in
> docs/phase-4-architect-log.md; D1–D49 remain binding (see carry pointer
> there). Baseline: 126 tests / 16 suites at 75822bc. LoC budgets are
> ceilings. No third-party deps (D7).
>
> **Standing context:** the Phase 3 close gate is OPEN — its
> HUMAN-AT-SCREEN queue is blocked on vLLM access. Phase 4 build proceeds
> by user directive; every dictation-dependent Phase 4 verify below is
> marked HUMAN-AT-SCREEN (BLOCKED-BATCH) and joins the same queue, to be
> run as one batch when a live STT endpoint returns.

## Requirement (PLAN.md §Phase 4, authoritative)

1. `NSWorkspace.frontmostApplication` at key-down; bundle-ID → category
   map (Email / Work messaging / Personal messaging / Code / Other) with
   per-category tone, user-overridable (Wispr's exact taxonomy).
2. Category + tone woven into the cleanup prompt.
3. Defer per-website browser detection (AX URL extraction) to v2.

**PLAN verify:** same utterance produces casual text in Messages, formal
in Mail.

## Cross-cutting design

- **Taxonomy (D50):** `AppCategory: String, CaseIterable` =
  `email / workMessaging / personalMessaging / code / other`. Exact
  bundle-ID match only — no prefix/wildcard rules (speculative complexity;
  the override map covers the long tail). Unmatched bundle ID, nil bundle
  ID, and all browsers (D55) resolve to `.other`.
- **Neutrality invariant (D51):** `.other` composes a system prompt
  BYTE-IDENTICAL to today's D45 fixtures. App-awareness can only ever
  change behavior for recognized/overridden apps; everything else is
  exactly Phase-3 behavior. Test-guarded.
- **Capture point (D52):** frontmost app is captured at KEY-DOWN
  (`startRecording`) — the app the user was in when they pressed the
  hotkey is the insertion target. Category resolution happens at cleanup
  time inside CleanupService (fresh override read, same live-read posture
  as `isEnabled`/D40).
- **Testability split (D14):** taxonomy, map, override resolution, and
  prompt composition are pure/headless. The one-line NSWorkspace read is
  the adapter side (like the CGEventTap in D49 — under tests the frontmost
  app is the test runner → `.other` → byte-identical prompt → zero test
  interference). Tone EFFECT on real cleanup output is HUMAN-AT-SCREEN
  (BLOCKED-BATCH).
- **Untouched surfaces:** warm-up and probe bodies (content-indifferent,
  D42/D44/D45); pill states (D46–D48); failure policy (D43 — a cleanup
  miss still inserts raw, category changes nothing about fallback);
  TranscriptionService; hotkey path.

## Sub-phase 4A — Category core + prompt weaving (pure, headless)

**Taxonomy + map (D50):** new `AppCategory.swift`:

```swift
enum AppCategory: String, CaseIterable {
    case email, workMessaging, personalMessaging, code, other
    var displayName: String { ... }        // "Email", "Work Messaging", …
    var toneClause: String? { ... }        // .other → nil; fixtures below
    static func category(forBundleID id: String?,
                         overrides: [String: String]) -> AppCategory
}
```

Resolution order: nil id → `.other`; else overrides[id] (valid rawValue
only — an unrecognized override value is IGNORED and falls through, D53's
safe-resolution mirror of D40's `resolve`); else built-in map; else
`.other`.

Built-in map (exact bundle IDs; user-extensible via overrides, D53 —
user confirms/extends this list at verify time, architect log open item):

- `.email`: com.apple.mail, com.microsoft.Outlook,
  com.readdle.smartemail-Mac, org.mozilla.thunderbird
- `.workMessaging`: com.tinyspeck.slackmacgap, com.microsoft.teams2,
  com.microsoft.teams
- `.personalMessaging`: com.apple.MobileSMS, net.whatsapp.WhatsApp,
  ru.keepcoder.Telegram, com.tdesktop.Telegram,
  org.whispersystems.signal-desktop, com.hnc.Discord
- `.code`: com.apple.dt.Xcode, com.microsoft.VSCode,
  com.todesktop.230313mzl4w4u92 (Cursor), com.apple.Terminal,
  com.googlecode.iterm2, dev.warp.Warp-Stable, com.mitchellh.ghostty

**Tone fixtures (D51, verbatim — test fixtures).** Tone is register /
formatting guidance ONLY, subordinate to the level body's own constraints
(it may never instruct rephrasing — light's "Change nothing else."
remains authoritative):

- `.email`: "This text will be sent as an email. Punctuate, capitalize,
  and paragraph it in a clear, professional email register."
- `.workMessaging`: "This text is a workplace chat message. Keep the
  register concise and professional, conversational rather than formal."
- `.personalMessaging`: "This text is a casual personal message. Keep the
  register relaxed and informal — do not formalize the speaker's wording."
- `.code`: "This text is for a coding context (editor, terminal, or
  commit message). Preserve technical terms, identifiers, and symbols
  exactly as spoken."
- `.other`: nil.

**Prompt composition (D51, precise rule):** `CleanupLevel.systemPrompt`
becomes `systemPrompt(for category: AppCategory) -> String?` (replace,
not overload — one composition path). `.off` → nil regardless of
category. Otherwise:

```
"/no_think " + levelBody + " " + (toneClause + " ")? + closer
```

where the tone term is omitted entirely when `toneClause` is nil, and:

- `levelBody(.standard)` = "You clean up dictated speech-to-text
  transcripts. Remove filler and pause words (um, uh, you know, like),
  fix punctuation and capitalization, and add paragraph breaks where
  natural. Preserve the speaker's meaning, wording, and voice — never
  rephrase, summarize, shorten, or add content."
- `levelBody(.light)` = "You clean up dictated speech-to-text
  transcripts. Remove filler and pause words (um, uh, you know, like)
  and fix punctuation and capitalization only. Change nothing else."
- `closer` = "Output only the cleaned text, with no commentary."

Tone sits BEFORE the closer so the output-only instruction keeps the
final (strongest) position. For `.other` the concatenation reproduces
the D45 fixtures byte-for-byte — the neutrality invariant. Tone weaves
into BOTH light and standard (even punctuation choices are
register-dependent); the fixtures above are worded so they cannot
contradict light's contract.

**Storage (D53):** SettingsStore gains
`appCategoryOverrides: [String: String]` (get: `defaults.dictionary`
filtered to String values; set: whole-dict write; key
`"appCategoryOverrides"`; empty dict ⇄ absent key). Values are
AppCategory rawValues; bundle IDs are keys. Per-category tone TEXT is
NOT user-editable this phase (fixed fixtures; custom tones are future
scope).

**Service plumbing (D52):** `CleanupService.cleanup(transcript:)` becomes
`cleanup(transcript: String, frontmostBundleID: String?)` — explicit
parameter, NO default value (a forgotten pass-through must not compile).
Inside, category = `AppCategory.category(forBundleID:overrides:)` with
`settings.appCategoryOverrides`, then the composed prompt. 4A updates the
single production call site (DictationController) to pass literal `nil`
(→ `.other` → byte-identical behavior); 4B replaces it with the captured
value. `isEnabled`, warm-up, timeouts, error mapping all untouched.

**Deliverables + LoC ceilings:**
- `AppCategory.swift` (~85): enum, displayName, toneClause, built-in map,
  `category(forBundleID:overrides:)`. Pure — no NSWorkspace, no
  SettingsStore access (overrides arrive as an argument).
- `CleanupLevel.swift` delta (~20): segment refactor + `systemPrompt(for:)`.
- `CleanupService.swift` delta (~10): signature + resolution line.
- `SettingsStore.swift` delta (~12): overrides key.
- `DictationController.swift` delta (~2): pass `nil` at the call site.
- `Tests/AppCategoryTests.swift` (~90, new, headless): resolution matrix
  (nil id, unmatched id, one representative built-in per category,
  override wins over built-in, override with garbage value falls through
  to built-in, override on an unmapped bundle, empty overrides);
  toneClause fixtures; displayName mapping.
- `Tests/CleanupLevelTests.swift` delta (~45): per-category × per-level
  composition fixtures; BYTE-IDENTITY test — `.other` × light/standard
  equals the pre-4A D45 fixture strings verbatim; `.off` → nil for every
  category.
- `Tests/CleanupServiceTests.swift` delta (~30): request-shape test now
  passes a mapped bundle ID → body carries the category-composed system
  prompt; nil bundle ID → D45 prompt unchanged; overrides read from the
  service's own store at request time.
- `Tests/SettingsStoreTests.swift` delta (~15): overrides round-trip;
  absent key → empty dict; non-string junk filtered.

**Verify (4A) — all machine, committable during the blocked window:**
1. `make test` green ×2 (delta ≈ +16 tests, +1 suite vs 126/16; tester
   records exacts).
2. Byte-identity test present and green (the neutrality invariant is
   test-enforced, not eyeballed).
3. Grep: no NSWorkspace reference anywhere in 4A's diff.

**Invariants (4A):** zero behavior change for `.other`/nil (byte-identical
prompts, same request shape); no new network surface; warm-up/probe bodies
untouched; AppCategory has no framework imports beyond Foundation.

## Sub-phase 4B — Frontmost-app capture (thin adapter)

**Capture (D52):** in `DictationController.startRecording()`, at key-down
(before/alongside `recorder.start()` — exact line order engineer's
choice, but capture must happen in `startRecording`, not at cleanup
time): `capturedBundleID = NSWorkspace.shared.frontmostApplication?
.bundleIdentifier`, stored in a new instance var, read into a local
alongside `capturedGeneration` in `stopRecording` so the in-flight Task
carries its own dictation's value (D23 generation discipline — a newer
dictation's capture can never bleed into an older Task). One log line at
capture: bundle ID (or "nil") — category is logged by CleanupService at
resolution time, keeping the map read in one place. Direct NSWorkspace
call, no DI seam (3B no-seam ruling; this is the adapter side of D14,
exactly like the nil-tap posture in D49). Under tests the frontmost app
is the test runner → unmapped → `.other` → byte-identical prompt.

**Deliverables + LoC ceilings:**
- `DictationController.swift` delta (~12): instance var, capture +
  log line, local snapshot, pass to `cleanup(transcript:frontmostBundleID:)`.
- No new tests owed (adapter side of D14 — NSWorkspace is not stubbable
  without a seam we ruled against building; D49 precedent). Suite must
  stay at the 4A count.

**Verify (4B):**
1. `make test` green ×2 (counts unchanged vs 4A gate).
2. HUMAN-AT-SCREEN (NOT vLLM-dependent — capture logs fire even when STT
   fails): launch app, focus a mapped app (e.g. Mail), press-hold-release
   the hotkey; log stream shows the captured bundle ID at key-down.
   Repeat over an unmapped app → logged, resolves `.other`.
3. HUMAN-AT-SCREEN (BLOCKED-BATCH — needs live STT + LLM): PLAN verify —
   dictate the same utterance in Messages and in Mail; Messages output is
   casual, Mail output is formal email register.
4. HUMAN-AT-SCREEN (BLOCKED-BATCH): dictate in an unmapped app → output
   identical in kind to Phase-3 behavior (neutral prompt).

**Invariants (4B):** capture at key-down only; nil frontmost degrades to
`.other`, never errors; no pill/UI change; dictation loop failure policy
untouched (D43); stale discipline holds across the new plumbing (D23).

## Sub-phase 4C — Override settings UI

**UI (D54):** SettingsForm gains an "App Categories" section (grouped
Form style, matching existing sections):
- One row per existing override: app display (bundle ID; app name where
  resolvable via `NSWorkspace.shared.urlForApplication` → bundle name is
  NOT required — bundle ID text is acceptable this phase), a category
  `Picker` over `AppCategory.allCases` (displayName), and a remove button.
- An "Add app…" control: menu of currently running regular-activation
  apps (`NSWorkspace.shared.runningApplications` filtered to
  `.regular`), each item = localizedName + bundle ID; selecting adds an
  override row seeded with the app's current effective category (built-in
  map result). Running-apps enumeration is the pragmatic Wispr-style
  picker; a full /Applications browser is out of scope.
- Overrides are draft-buffered (D26): edits touch `SettingsDraft` only;
  written solely via `draft.save()` (single-write-path invariant from
  3C). Save-probe flow untouched — overrides never trigger a probe or
  warm-up (the (llmEndpointURL, llmModel) tuple compare from D42/3C is
  unchanged).
- Window: `SettingsForm.contentSize` 420×390 → 420×560 — single-site
  change (R40 constant); the overrides List scrolls internally beyond
  ~4 rows.

**Deliverables + LoC ceilings:**
- `SettingsForm.swift` delta (~95): section, row view, add-menu.
- `SettingsWindowController.swift` / `SettingsDraft` delta (~55): draft
  dict, reload/save plumbing.
- `Tests/SettingsWindowControllerTests.swift` delta (~45, headless):
  overrides round-trip through draft save/reload; removing a row removes
  the key on save; Cancel writes nothing (D26); save with only an
  override change fires NO probe and NO warm-up.
- `Tests/SettingsStoreTests` — already covered in 4A.

**Verify (4C):**
1. `make test` green ×2 (delta ≈ +4 tests vs 4B gate).
2. HUMAN-AT-SCREEN (NOT vLLM-dependent): App Categories section renders
   in the 560 pt window without clipping; add an override from the
   running-apps menu; category picker + remove work; persists across
   reopen; Cancel discards.
3. HUMAN-AT-SCREEN (BLOCKED-BATCH): override a mapped app (e.g. force
   Mail → Personal Messaging), dictate in it → casual register (override
   beat the built-in, live).
4. HUMAN-AT-SCREEN (D38 regression): one end-to-end dictation after the
   settings rework — loop untouched. (BLOCKED-BATCH for the cleaned-text
   leg; capture/paste leg runs without vLLM only if a fallback STT
   endpoint exists, else fully batched.)

**Invariants (4C):** store writes only via `draft.save()` (D26/3C);
probe/warm-up triggers unchanged; tone text not editable; the settings
window remains the only alert surface (D38).

## Out of scope (explicit)

- Per-website browser detection (AX URL extraction) — **v2**, per PLAN.md
  §Deferred (D55). Browsers default `.other`; a user who lives in one
  web app may override the browser's bundle wholesale — that is the
  documented interim posture. Reopen trigger: v2 browser-context work.
- Custom/per-category tone text editing; per-app custom prompts.
- Prefix/wildcard bundle matching (e.g. com.jetbrains.*) — overrides
  cover the long tail; revisit only on real user friction.
- History integration (D41 — Phase 5+).
