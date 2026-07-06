# Architect log — LotusScribe (Phase 8)

> Locked decisions + open questions for Phase 8. Carry pointer: D1–D71
> (+D62a) in phase-0…7 logs; all binding. Numbering continues at D72.
> Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D72 | 2026-07-06 | Reasoning suppression = USER SETTING `suppressModelReasoning` (Bool, DEFAULT TRUE; getter special-cases the absent key — `defaults.object(forKey:) == nil \|\| defaults.bool(forKey:)` — because `defaults.bool` reads absent as false), draft-buffered per D26. Mechanism: top-level `reasoning_effort: "none"` on ChatRequest (optional String, nil-omitted); `chat_template_kwargs:{enable_thinking:false}` REJECTED — vLLM-only + nested struct for one bool, vs an OpenAI-API scalar (D39 endpoint-agnostic posture). Scope (amends D45's scope clause): cleanup AND warmUp() carry it when true (warm-up must warm the real inference path — 8B); the D42 non-2xx retry drops keep_alive ONLY, reasoning_effort stays; ConnectionProbe.testLLM UNCHANGED (content-indifferent, max_tokens 1, reads only its arguments per D36). R45 invariant: the key must NOT join persist()'s (llmEndpointURL, llmModel) warm-up tuple or any probe trigger | Empirical 2026-07-06: /no_think prefix ignored by Qwen3.6 (19.5 s); both body params → 0.3 s, harmless on Phi. USER DECISION: setting, not hardcode — a reasoning-model user may want thinking ON. Parameter changes request shape, not model residency → no warm-up trigger | 8A |
| D73 | 2026-07-06 | `/no_think ` prefix (D45/D51 position 0): KEEP, verbatim. D51/D45's suppression rationale recorded OBSOLETE — the prefix is empirically inert on Qwen3.6; suppression now rides D72's body param. Caveat: on a hypothetical soft-switch-honoring model, suppress-OFF still carries the prefix; revisit only if such a model surfaces live | Stripping churns the locked byte-identity fixtures (CleanupLevelTests D51/D57 neutrality invariants, byte-for-byte) for zero runtime benefit; CLAUDE.md §3 surgical-change | 8A |
| D74 | 2026-07-06 | Record-start warm-up (amends D42's trigger set: launch + endpoint-change + NOW recording start): in startRecording, after the D63 secure-input guard, generation bump, and a SUCCESSFUL recorder.start() (inside the do, after pill.show(.warming)), fire-and-forget `Task { await cleanup.warmUp() }` — D42 posture verbatim (log-only, self-skips when not effective-enabled, never touches the pill, never blocks). Debounce: ≥ 30 s between record-start warm-ups via `lastRecordWarmUp: Date?` + pure `nonisolated static shouldFireRecordWarmUp(now:last:)` (hasUsableAudio precedent — headless-testable). Rejected: in-flight Task tracking/cancel plumbing (warm-up is idempotent, a timestamp is the whole guard). No test may reach startRecording (no controller DI seam, 3B ruling stands; real URLSession) — headless surface is the pure function only | #16: vLLM evicts among 6 models; D42's launch/endpoint-change triggers leave between-dictation evictions cold → 8 s amber. Warming at pill-show loads the model while the user speaks. 30 s covers hotkey spam without stacking cold loads (cold start 3–10 s) | 8B |
| D75 | 2026-07-06 | Per-bundle AX denylist (AMENDS D61 — the pre-authorized Q6-2 escape hatch, now built; ANSWERS Q6-2: YES — Slack): pure `InsertionPolicy.axDenylist: Set<String>`, seed `["com.tinyspeck.slackmacgap"]` ONLY (evidence-gated additions; prophylactic Electron pre-adds rejected — most Electron elements fail the settable probe and fall back naturally, VS Code confirmed live; over-blocking costs AX quality where AX is honest). `route(targetBundleID:focusedElementFound:selectedTextSettable:)` — denylisted → `.pasteboard` regardless of probe; nil bundle → D61 table unchanged. Plumbing adapter-side in TextInserter: `targetBundleID` derived at probe time from the focused element's own PID (`AXUIElementGetPid` → `NSRunningApplication.bundleIdentifier`; failure → nil) — RULED OVER threading the D52 key-down capture (routing must bind to the element actually written at insert time; the probe and both landing paths act on live focus; a key-down binding reintroduces silent loss in reverse when the user switches INTO Slack mid-flight; D52 serves cleanup tone and stays untouched) and over an NSWorkspace re-read (element PID is exact, both symbols already imported). Readback verification RE-REJECTED, grounds strengthened: an AX layer returning `.success` without inserting cannot be trusted to give an honest readback either (Chromium a11y tree can echo the set without committing it to the DOM), so readback stays blind to exactly the failure class it would exist to catch. Denylist-forced route logs `insertion route: pasteboard (AX denylist <bundle>)` (D65 one-line) | Live 2026-07-06 at HEAD 13ddec6: Slack reports kAXSelectedText settable, set returns `.success`, NOTHING lands — the D61 fallback never fires because AX lies about success; Mail/Spark (pasteboard) and TextEdit (ax) landed. The pasteboard route works in Slack, so forcing it is a pure win there | 8C |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
|    |             |          |        |            |

## Notes

2026-07-06: PHASE 8 BOOTSTRAP — live-test corrections. Empirical facts
(orchestrator probes, live vLLM, temp 0):
- `/no_think` prompt prefix (D51 position 0) is IGNORED by
  Qwen3.6-35B-A3B (FP8 and NVFP4): 19.5s reasoning per cleanup.
- Request-body `chat_template_kwargs:{enable_thinking:false}` AND
  `reasoning_effort:none` both → 0.3s clean on Qwen3.6; both harmless to
  Phi-3.5-mini (0.8s, no error). → parameter is model-agnostic-safe.
- Phi-3.5-mini (fast, 0.7–1.9s warm) is a weak instruction-follower:
  rephrases ("said"→"stated that") and adds artifacts (trailing "---")
  — corroborates the user's #7. Qwen3.6 follows instructions cleanly.
USER DECISION (load-bearing, do NOT hardcode): reasoning-suppression is
a USER SETTING, default suppress-ON, overridable — a user may run a
reasoning model and want thinking ON. Spec 8A around a setting + request
wiring + SettingsForm toggle + guidance caption; 8B = warm-up at
recording start (amends D42's launch/endpoint-only trigger).

2026-07-06: docs/phase-8-spec.md authored (D72–D74). SLICING: 8A first
(reasoning setting — unblocks live cleanup-quality items #7/#13/#14/#18/
#19, which amber on every cleanup without it), 8B second (record-start
warm-up — its live verify needs 8A's parameter on the warm-up body so it
warms the real inference path). Code-verified against source:
CleanupService.ChatRequest already nil-omits optionals (synthesized
Codable — the D42 keep_alive idiom D72 rides); SettingsStore has no
default-true bool precedent (onboardingCompleted wants absent→false, so
D72 specs the object(forKey:)==nil getter explicitly); persist()'s
warm-up tuple is (llmEndpointURL, llmModel) exactly — R45 invariant
stated in-spec; SettingsForm's .disabled covers the new toggle (inside
the Form; R49 button-row guard untouched); contentSize is the R40 single
site (740 → 780, one edit); startRecording's D63 guard precedes the
generation bump — D74 places the warm-up after a SUCCESSFUL
recorder.start() so blocked/failed starts fire nothing;
DictationControllerTests never reach startRecording today (construct +
pure statics only), keeping the R41-spirit no-network posture with zero
new seams. Tripwire amendments owed: CleanupServiceTests
cleanupRequestMatchesSpec / warmUpRequestMatchesSpec /
warmUpRetriesOnceWithoutKeepAliveOnNon2xx key sets (spec §8A lists exact
expected sets). Expected deltas: 8A ≈ +5 tests (223/22), 8B ≈ +3
(226/22), suites unchanged. LIVE-DICTATION legs join the user's human
batch, same posture as phases 3–7. No open Q8-x raised — the caption
wording is flagged in-spec as user-adjustable at review, not a blocking
question.

2026-07-06: 8A NON-OBJECTION (architect, staged diff vs D72/D73).
Setting-not-hardcode honored: store key + draft + Form toggle, `? "none"
: nil` at both call sites. Getter matches the D72 spec snippet
byte-exact (absent→true). Mechanism is the ruled scalar
(`reasoningEffort: String?`, `reasoning_effort` CodingKey, nil-omitted
synthesized Codable — D42 idiom). Scope correct: cleanup + warmUp carry
it read-at-request-time (D40); retry nils keepAlive ONLY; probe files
untouched (D36); R45 tuple unchanged in persist(). D73: no prompt edits
— /no_think verbatim. 740→780 is the R40 single site; comment update is
same-site, in-scope. NOTHING requires round-trip — 8A clear to gate.

2026-07-06: 8B NON-OBJECTION (architect, staged diff vs D74). Placement
exact: inside the do, after D63 guard + bump + successful
recorder.start() + pill.show(.warming) — blocked/failed starts fire
nothing. Timestamp IS the entire guard (pure nonisolated static, `>= 30`
boundary); no Task tracking per the D74 rejection. Fire-and-forget
`Task { await cleanup.warmUp() }` — D42 posture, no pill touch, no
isEnabled at site. No new seams (hasUsableAudio precedent); suite stays
construction+statics. LoC +19/+22 vs ~15/~20 — doc comments, waved.
PHASE 8 MACHINE SCOPE COMPLETE once 8B commits (spec = 8A+8B only);
phase NOT closed — LIVE-DICTATION legs (8A #3/#4, 8B #16) still open.

2026-07-06: **PHASE 8 CLOSE BLOCKED ON** (architect close-out audit).
Machine scope COMPLETE + committed (8A/8B, 226/22 ×2 ×N runners at HEAD
13ddec6). The §G on-device retest has NOT yet been run — it is the sole
gate. All legs below are AT-SCREEN with vLLM up (the user must run them);
no BLOCKED-USER legs in Phase 8.

Remaining feature-verification legs:
- 8A #7 (§G, D72): with Qwen3.6 + reasoning-suppression ON (default),
  dictate the flagship cleaned passage → clean output, NO rephrasing, NO
  leaked commentary ("Note:", trailing "---"), fast (~sub-second, not the
  12–20 s reasoning stall). This ALSO discharges the Phase-3 D45
  cleaned-output quality re-confirmation deferred into this phase.
- 8A #3/#4 (§G toggle, D72): flip the reasoning-suppression toggle OFF →
  a reasoning model's thinking returns (behavior changes) → flip ON again
  → clean/fast — proves the setting is honored, not hardcoded.
- 8B #16 (§G, D74): over MANY consecutive dictations (including ones
  spaced apart enough that vLLM would evict the model), amber is GONE —
  the record-start warm-up loads the model while the user speaks, so no
  cold-reload timeout → raw fallback. Confirm the amber that intermittently
  appeared in the earlier batch no longer occurs.

2026-07-06: 8C SPEC APPENDED (docs/phase-8-spec.md §8C, D75) — live
insertion bug: Slack silent-AX-success (Q6-2 fired; the Phase 6 close's
"Slack fallback worked" line rested on an inaccurate user #21 report —
close note amended in phase-6-architect-log.md, Q6-2 flipped to
answered). Fix = per-bundle denylist in pure InsertionPolicy (seed:
com.tinyspeck.slackmacgap only), target bundle derived adapter-side from
the probed element's PID at insert time — NOT the D52 key-down capture
(routing binds to the element actually written; D52 stays cleanup-only)
— readback re-rejected (a lying AX cannot be trusted to read back
honestly). Code-verified against source: `InsertionPolicy.route` is the
only route site and TextInserter its only caller; `capturedBundleID` is
threaded to cleanup only, never to `inserter.insert` — no controller
change needed under the PID plumbing; AppKit + ApplicationServices
already imported in TextInserter (AXUIElementGetPid /
NSRunningApplication add no imports). Expected delta ≈ +4 tests
(≈230/22), suites unchanged. Verify: MACHINE route truth table;
LIVE-DICTATION Slack-lands is the gating leg (plus TextEdit still
route=ax, no over-blocking). 8C independent of 8A/8B.

2026-07-06: 8C NON-OBJECTION (architect, staged diff vs D75). Denylist +
route(targetBundleID:...) live in pure InsertionPolicy, spec-snippet
faithful; denylist check precedes the D61 table, nil bundle → table
unchanged. PID binding is insert-time from the probed element's own pid
(AXUIElementGetPid → NSRunningApplication), failure → nil; D52 capture
untouched; AX symbols stay in TextInserter (R57). Seed Slack-only with
the evidence-gated comment. Log: exactly one route line per insertion;
denylist branch unreachable from ax-fallback. NOTHING to round-trip.

2026-07-06: **PHASE 8 CLOSED** (architect, per explicit user directive).
Basis — 8A/8B/8C all machine-gated (230/22 ×2 runners at HEAD) plus live
evidence from the user's 2026-07-06 09:xx at-screen session
(orchestrator-verified via logs/screenshots):
- 8A #7 / 8B #16 (informal): the entire session (Mail, TextEdit ×2,
  Slack ×2 dictations) produced fast, clean, register-correct output —
  no rephrasing, no commentary leaks, no ambers reported.Contrast
  pre-8A: ambers "every few turns" plus rephrasing.This is the #7/#16
  resolution evidenced in normal use, and it also discharges the
  Phase-3 D45 cleaned-output quality re-confirmation deferred here.
- 8C Slack leg CLOSED (tester baselines §Live-leg results): log-verified
  denylist route (`insertion route: pasteboard (AX denylist …)` for
  com.tinyspeck.slackmacgap) with TextEdit still route=ax immediately
  after — no over-blocking.Q6-2's resolution is COMPLETE: D75
  live-verified.
USER-WAIVED legs (user directed close WITHOUT running these — waived,
NOT verified):
- 8A #3/#4 reasoning-toggle honor check (OFF → thinking/slow returns →
  ON → clean/fast).
- A systematic spaced-dictation amber observation for 8B #16 (only the
  informal same-session evidence above exists; eviction-window spacing
  was never deliberately exercised).
Reopen trigger: if a waived behavior misbehaves in daily use, it reopens
as a DEFECT against the shipped code, not as a phase reopen.
