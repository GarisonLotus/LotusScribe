# Phase 8 Spec — 8A: reasoning-suppression setting; 8B: warm-up at recording start; 8C: per-bundle AX denylist (Slack)

> Authored by architect, 2026-07-06. Live-test corrections — correction
> phase, not new architecture. Rulings D72–D74 in
> docs/phase-8-architect-log.md; amends D42/D45 (D51's /no_think rationale
> recorded obsolete). Honors D26/D40/D43. Baseline 218 tests / 22 suites at
> e9f53a7. Empirical basis (handoff §2 + architect-log note, 2026-07-06):
> Qwen3.6 ignores `/no_think` (19.5 s reasoning); the body parameter
> suppresses it (0.3 s); harmless on Phi-3.5-mini (0.8 s, no error).

## User requirement (authoritative)

Reasoning suppression must be a USER SETTING, default suppress-ON — a user
running a reasoning model may want thinking ON — plus a guidance caption
("model behavior varies; Qwen3.6 recommended"). 8B: fire a warm-up when
recording starts so an evicted model loads while the user speaks (#16).

## Sub-phase 8A — Reasoning-suppression setting

**Mechanism (D72):** `reasoning_effort: "none"` — scalar top-level field.
RULED over `chat_template_kwargs:{enable_thinking:false}`: empirically
equivalent (both 0.3 s on Qwen3.6, harmless on Phi), but `reasoning_effort`
is an OpenAI-API field (D39's endpoint-agnostic posture — nothing may
assume vLLM) while `chat_template_kwargs` is vLLM-only and needs a nested
Encodable struct for one boolean. One optional String on the existing
`ChatRequest` (synthesized Codable omits nil — the proven D42 idiom):
simpler Codable, simpler key-set tests, more standard.

**Store key (D72):** `SettingsStore.suppressModelReasoning`, Bool, DEFAULT
TRUE. `defaults.bool(forKey:)` reads an absent key as false, so the getter
special-cases absence — exact shape:

```swift
/// D72: true (default) → cleanup/warm-up requests carry
/// `reasoning_effort: "none"`; false → field omitted (model default).
/// Absent key must read TRUE — `defaults.bool` alone would flip the
/// default (contrast onboardingCompleted, where absent→false is meant).
var suppressModelReasoning: Bool {
    get {
        defaults.object(forKey: "suppressModelReasoning") == nil
            || defaults.bool(forKey: "suppressModelReasoning")
    }
    set { defaults.set(newValue, forKey: "suppressModelReasoning") }
}
```

**Draft (D26):** `SettingsDraft` gains `@Published var
suppressModelReasoning = true`; `reload()` seeds from the store, `save()`
always writes it (like `cleanupLevel` — the absent-key nuance only matters
before the first Save). Cancel/titlebar-close write nothing, unchanged.

**Request wiring (D72, amends D45):** `ChatRequest` gains `var
reasoningEffort: String?` (`CodingKeys` → `"reasoning_effort"`).
`cleanup()` sets it to `settings.suppressModelReasoning ? "none" : nil` —
read at request time (D40 live-read posture, same as overrides/dictionary).
Scope ruling:
- **warmUp() CARRIES it** (same conditional) — 8B's point is warming the
  real inference path; the D42 non-2xx retry drops `keep_alive` ONLY
  (that was the known offender; `reasoning_effort` is standard and stays).
- **ConnectionProbe.testLLM UNCHANGED** — content-indifferent, `max_tokens
  1` bounds any reasoning, and the probe reads only its arguments, never
  SettingsStore (D36 invariant); threading a setting in breaches that for
  zero validation value.
- AppDelegate's launch warm-up and the 3C endpoint-change warm-up call the
  same `warmUp()` — they inherit the parameter with no further change.

**/no_think prefix (D73): KEEP.** Empirically ineffective on Qwen3.6 —
D51/D45's suppression rationale is OBSOLETE — but stripping it churns the
locked byte-identity prompt fixtures (CleanupLevelTests' D51/D57 neutrality
invariants) for zero runtime benefit; it is inert text everywhere observed.
D73 caveat: a hypothetical soft-switch-honoring model would still see the
prefix under suppress-OFF; revisit only if one surfaces live.

**SettingsForm:** Cleanup LLM section, after the Model field, before the
Cleanup picker: `Toggle("Suppress model reasoning", isOn:
$draft.suppressModelReasoning)` plus a caption row (`.font(.caption)`,
`.foregroundStyle(.secondary)`): "Model behavior varies — some models
'think' before replying (slower) or follow cleanup instructions loosely.
Qwen3.6 is recommended." (User may adjust wording at review.) The toggle
sits inside the Form, so the existing `.disabled(probeState.phase ==
.testing)` covers it (R49: button-row guard untouched).
`SettingsForm.contentSize` height 740 → 780 (+40 for toggle + caption, 7A
precedent); R40 single site — the controller's `setContentSize` follows,
no second edit.

**R45 watch (explicit invariant):** `persist()`'s warm-up trigger tuple
stays exactly `(llmEndpointURL, llmModel)` — `suppressModelReasoning` must
NOT join it (toggling the setting alone fires no warm-up; the parameter
changes request shape, not model residency). Probes remain triggered by
drafted URLs only (D37/D44).

**Tests (D14 headless):**
- `SettingsStoreTests` (+2): absent key reads true; written false / true
  round-trip.
- `CleanupServiceTests` — amend the key-set tripwires (tester-baselines 8A
  note): `cleanupRequestMatchesSpec` (default = suppress ON) now expects
  `Set(json.keys) == ["model","messages","temperature","reasoning_effort"]`
  and `json["reasoning_effort"] as? String == "none"`;
  `warmUpRequestMatchesSpec` gains `"reasoning_effort"`;
  `warmUpRetriesOnceWithoutKeepAliveOnNon2xx` retry set =
  `["model","messages","max_tokens","reasoning_effort"]` (keep_alive
  dropped, reasoning kept). NEW (+2): suppress false → cleanup key set
  back to `["model","messages","temperature"]`; suppress false → warm-up
  omits the field.
- `SettingsWindowControllerTests` (+1): reload seeds the toggle from the
  store; save persists a flipped value (stub probes + `warmUp:`, R41/R44).

**LoC ceilings (8A):** SettingsStore ~10; CleanupService ~10; SettingsDraft
~5; SettingsForm ~12; tests ~75 across the three files.

**Verify (8A):**
1. MACHINE: `make test` green ×2 — delta ≈ +5 tests, +0 suites (223/22).
2. AT-SCREEN: open Settings → toggle ON by default with caption under the
   Model field; flip OFF, Save (endpoints valid), reopen → OFF persisted;
   `defaults delete … suppressModelReasoning` → reopen shows ON.
3. LIVE-DICTATION (suppress ON, Qwen3.6-NVFP4): dictate → cleaned text,
   both pill checks green, well inside 8 s (was: amber every time). This
   unblocks live items #7/#13/#14/#18/#19.
4. LIVE-DICTATION (suppress OFF, same model): dictate → model reasons →
   ~8 s timeout → amber + RAW transcript (proves the wire end-to-end; D43
   fallback intact). Flip back ON afterwards.

**Invariants:** D43 untouched — a cleanup miss still inserts raw; hot-path
body stays keep_alive-free (D42); prompt fixtures byte-identical (D73);
probe reads drafts/arguments only (D36); no alerts from the loop (D38).

## Sub-phase 8B — Warm-up at recording start

**Trigger (D74, amends D42's trigger set):** in
`DictationController.startRecording`, AFTER the 6A/D63 secure-input guard,
the D23 generation bump, and a SUCCESSFUL `recorder.start()` — i.e. inside
the `do` branch, immediately after `pill.show(.warming)`:

```swift
if Self.shouldFireRecordWarmUp(now: Date(), last: lastRecordWarmUp) {
    lastRecordWarmUp = Date()
    Task { await cleanup.warmUp() }  // D42 posture: log-only, self-skips
}
```

Placement rationale: a secure-input-blocked press dictates nothing (no
warm-up); a failed recorder start likewise. Fire-and-forget Task — never
blocks recording, never touches the pill (D42 posture verbatim); `warmUp()`
already self-skips + logs when not effective-enabled, so no `isEnabled`
check at the call site. It is the same `warmUp()`, so it carries the 8A
`reasoning_effort` parameter (real inference path).

**Debounce (D74):** one warm-up per 30 s window. `private var
lastRecordWarmUp: Date?` on the controller, decision extracted pure (the
`hasUsableAudio` precedent — headless-testable, no seam):

```swift
/// D74: ≥ 30 s between record-start warm-ups — covers hotkey spam and
/// rapid re-records without stacking cold loads (cold start 3–10 s,
/// warm-up timeout 30 s). Eviction inside a 30 s window is a
/// multi-client race the D43 raw fallback already absorbs.
nonisolated static func shouldFireRecordWarmUp(now: Date, last: Date?) -> Bool {
    last.map { now.timeIntervalSince($0) >= 30 } ?? true
}
```

Rejected: tracking in-flight warm-up Tasks or cancel plumbing — warm-up is
log-only and idempotent server-side; a timestamp is the whole guard.

**Test surface (R41 spirit, tester-baselines 8B note):** NO test may reach
`startRecording` — the controller has no DI seam (3B ruling stands) and its
CleanupService rides the real URLSession; existing DictationControllerTests
only construct. Headless surface = the pure debounce function: nil → true;
29.9 s → false; 30 s boundary → true. The fire itself is AT-SCREEN via log.

**LoC ceilings (8B):** DictationController ~15;
DictationControllerTests ~20 (+3 tests).

**Verify (8B):**
1. MACHINE: `make test` green ×2 — delta ≈ +3 tests, +0 suites (226/22
   cumulative).
2. AT-SCREEN: start a dictation → log shows the warm-up at record start
   ("warm-up done (HTTP …)" while still speaking); two dictations within
   30 s → exactly one record-start warm-up line; secure-input blocked
   press → `.blocked` pill, no warm-up line.
3. LIVE-DICTATION (#16): evict Qwen (curl a different model, or natural
   eviction) → dictate a several-second sentence → cleanup lands green
   (model loaded during speech; was amber). Utterance shorter than the
   cold load → amber raw fallback is still correct — note, don't fail.

**Invariants:** warm-up never blocks or delays recording; pill driven only
by the existing show/update calls; blocked/failed starts fire nothing;
generation/stale semantics (D23/D43) untouched; warm-up remains the only
request carrying keep_alive (D42).

## Sub-phase 8C — Per-bundle AX denylist (Q6-2 fired live: Slack)

> Appended 2026-07-06 by architect. Live evidence at HEAD 13ddec6:
> dictation into Slack (com.tinyspeck.slackmacgap) inserts NOTHING; route
> log shows `insertion route: ax` both attempts. Slack's focused element
> reports kAXSelectedText SETTABLE and `AXUIElementSetAttributeValue`
> returns `.success`, but the Electron/Chromium layer silently discards
> the set — the exact Q6-2 silent-AX-success case D61 pre-authorized the
> denylist escape hatch for. Mail/Spark (route=pasteboard) and TextEdit
> (route=ax) landed correctly. Ruling D75 in phase-8-architect-log.md;
> amends D61; answers Q6-2 (phase-6 log).

**Route change (D75, pure — InsertionPolicy.swift):** denylist lives in
the pure policy (D65 policy-in-one-file; D14 headless):

```swift
/// D75: bundles whose AX reports kAXSelectedText settable AND returns
/// .success on set WITHOUT inserting (silent AX failure). Evidence-gated:
/// add a bundle only on a confirmed live silent failure, never
/// prophylactically — over-blocking costs AX-route quality (no clipboard
/// traffic) in apps where AX is honest.
static let axDenylist: Set<String> = ["com.tinyspeck.slackmacgap"]

static func route(
    targetBundleID: String?, focusedElementFound: Bool,
    selectedTextSettable: Bool
) -> InsertionRoute
```

Logic: `targetBundleID` in `axDenylist` → `.pasteboard` regardless of the
probe; otherwise the existing D61 table unchanged; nil bundle → unchanged
(no denylist match possible). Seed = Slack ONLY: pre-adding other Electron
bundles REJECTED — most Electron elements fail the settable probe and fall
back naturally (VS Code confirmed live), so only lying-AX apps ever need a
row, and each addition is one line + one truth-table cell when evidence
demands.

**Plumbing (D75, adapter — TextInserter.swift):** `targetBundleID` is
derived at PROBE time from the focused element itself:
`AXUIElementGetPid(focused, &pid)` →
`NSRunningApplication(processIdentifier: pid)?.bundleIdentifier`; any
failure → nil (route unchanged). `probeFocusedElement()` tuple grows to
`(element, selectedTextSettable, targetBundleID)`. RULED OVER the two
candidate plumbings: (a) threading the D52 key-down `capturedBundleID` —
rejected because routing must bind to the element actually written at
insert time (the probe and both landing paths act on live focus; a
key-down binding reintroduces silent loss in reverse when the user
switches INTO Slack mid-flight; D52's intent-binds-at-key-down serves
cleanup tone, a different concern — capture stays untouched); (b)
re-reading `NSWorkspace.frontmostApplication` at insert — workable but the
element's own PID is exact and equally direct (both symbols already
imported). Zero DictationController changes. Log (D65 one-line-per-
insertion): the denylist-forced branch logs
`insertion route: pasteboard (AX denylist <bundle>)` so the live verify
reads Console, not guesses.

**Readback verification: re-rejected** (D61 grounds stand, strengthened):
an AX layer that returns `.success` without inserting cannot be trusted to
return an honest kAXSelectedText/kAXValue readback either — Chromium's
a11y tree can echo the set value without committing it to the DOM input —
so readback adds latency and fragility while remaining blind to exactly
the failure class it exists to catch.

**Tests (D14 headless — InsertionPolicyTests):** existing 4-cell route
table amended to pass `targetBundleID: nil` (asserts nil → D61 table
unchanged). NEW ≈ +4: denylisted + found + settable → pasteboard;
denylisted + probe-failed → pasteboard; non-denylisted bundle (e.g.
`com.apple.TextEdit`) + found + settable → ax; nil + found + settable → ax.

**LoC ceilings (8C):** InsertionPolicy ~14; TextInserter ~10;
InsertionPolicyTests ~30. No other files.

**Verify (8C):**
1. MACHINE: `make test` green ×2 — delta ≈ +4 tests, +0 suites (≈230/22
   cumulative; tester records exacts).
2. LIVE-DICTATION (the gating leg): dictate into Slack → Console shows
   `insertion route: pasteboard (AX denylist com.tinyspeck.slackmacgap)`
   → text LANDS in the Slack message box.
3. LIVE-DICTATION (no over-blocking): dictate into TextEdit → still
   `insertion route: ax`, text lands.

**Invariants:** D43 untouched — pasteboard route is the universal landing
path, so a denylist hit can never lose text; D61's probe chain, fallback,
and no-readback posture unchanged for all non-denylisted bundles; AX usage
stays confined to TextInserter (6B grep, R57); D62 save/restore rides the
pasteboard route unchanged; D52 capture untouched.

## Slicing & gates

8A first (unblocks the live cleanup-quality backlog), 8B second — 8B's
live verify needs 8A's parameter on the warm-up body. 8C third —
independent of 8A/8B (live-surfaced insertion correction; can land any
time after 8B). Each sub-phase gates on `make test` ×2 + its AT-SCREEN
steps; LIVE-DICTATION steps run in the user's next human batch (same
posture as phases 3–7). 8C's Slack leg is its own gate — the sub-phase is
not closed until text demonstrably lands in Slack.
