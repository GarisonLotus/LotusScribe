# Architect log — LotusScribe (Phase 7)

> Locked decisions + open questions for Phase 7. Carry pointer: D1–D11
> phase-0, D12–D28 phase-1, D29–D35 phase-2 (D29a rescinded), D36–D49
> phase-3, D50–D55 phase-4, D56–D60 phase-5, D61–D65+D62a phase-6; all
> binding. Numbering continues at D66. Terse entries.

## Locked decisions

| id | date | decision | rationale | sub-phase |
|----|------|----------|-----------|-----------|
| D66 | 2026-07-05 | Sparkle ruling on D7: recommend DEFER updates to v1.1, ship DMG-only (option b). Decision itself BLOCKED-USER (Q7-1); no Phase-7 slice depends on it | D7 held six phases; Sparkle also needs EdDSA key custody, appcast host, Developer ID — all BLOCKED-USER today; deferring forecloses nothing | cross |
| D67 | 2026-07-05 | Onboarding = pure `OnboardingStateMachine` (`OnboardingStep.resolve(PermissionSnapshot)`, D40 shape) + checklist window (OnboardingWindowController/View, ~480×420, 1 s snapshot poll via injected provider). Shown at launch when `onboardingCompleted` unset, inside the XCTestSessionIdentifier guard; Skip + Finish both set the flag; "Rerun Onboarding…" status-menu item reopens. R35 smoke owed at introduction | no TCC change notifications exist → poll; checklist avoids paged-wizard nav state; flag-gated launch keeps existing flow intact | 7B |
| D68 | 2026-07-05 | Input Monitoring step is UNCONDITIONAL, and AX/IM steps are System Settings deep links, not request calls; mic is the only real prompt (`AVCaptureDevice.requestAccess`) | phase-1 empirical record: BOTH IM+AX required for tap delivery; `CGRequestListenEventAccess()` silently ignored on macOS 26 | 7B |
| D69 | 2026-07-05 | Presets = pure stateless `EndpointPreset` table (Speaches STT-only, Ollama LLM-only, vLLM both, localhost defaults); apply fills only non-nil URL fields on the DRAFT (D26); model fields never overwritten; no persisted preset selection; custom = edit fields (no menu item) | models are server-specific; stateless apply avoids selection-sync drift; draft-only keeps D26/D37 Save semantics untouched | 7A |
| D70 | 2026-07-05 | Connection-test button reuses D37/D44 probe machinery: `SettingsWindowController.test()` mirrors save()'s probe leg via the existing seams + `probeEndpoints`, but only sets ProbeState — never persists/closes/sheets (D38 sheet stays Save-only). probeIndicator `.failure` arm becomes inline warning text | one probe implementation (D36/D44) serves both flows; Save keeps its sheet, Test stays lightweight | 7A |
| D71 | 2026-07-05 | Release pipeline = Makefile recipes (`release`/`dmg`/`notarize`/`staple` + scripts/make-dmg.sh): `dmg` dev-signs by default, re-signs with `--options runtime` when SIGN_IDENTITY set; notarize/staple fail fast without NOTARY_PROFILE. project.yml untouched (personal team stays, D12/Q1). Homebrew cask deferred (Q7-3) | dry-runs clean without creds (machine-verifiable now); Developer ID re-sign invalidates local TCC (Q2) so it stays distribution-only | 7C |

## Open questions

| id | date raised | question | status | blocked-by |
|----|-------------|----------|--------|------------|
| Q7-1 | 2026-07-05 | Sparkle sign-off: adopt now / defer to v1.1 (recommended, D66) / never? | open | BLOCKED-USER (user decision) |
| Q7-2 | 2026-07-05 | Developer ID credentials: paid enrollment + "Developer ID Application" cert + notarytool keychain profile — when? | open | BLOCKED-USER (Apple ID, payment) |
| Q7-3 | 2026-07-05 | Homebrew cask: artifact hosting (GitHub Releases?) — only actionable after Q7-2 + a stapled DMG exists | deferred | Q7-2 |
| Q7-4 | 2026-07-05 | Does the event tap deliver after AX/IM grants WITHOUT relaunch? (7B at-screen verify 4 — adjusts onboarding done-step copy) | open | AT-SCREEN |

(status: open / answered / deferred / closed-as-moot)

## Notes

2026-07-05: PHASE 7 BOOTSTRAP (autonomous run; user tests tomorrow
morning). Phase-3/4/5/6 close gates OPEN (human batches queued in
when-vllm-is-back.md; vLLM is UP again). Constraints: Developer ID
signing/notarization BLOCKED-USER (personal-team signing only today);
Sparkle adoption needs a D7 ruling + user sign-off (it is a third-party
dep AND an outward-facing distribution decision). Machine-first slices:
endpoint presets, onboarding UI, release recipes that dry-run without
creds. Spec must classify every verify MACHINE / AT-SCREEN /
BLOCKED-BATCH (needs dictation) / BLOCKED-USER (needs credentials or a
second Mac).

2026-07-05: 7A NON-OBJECTION. Staged diff conforms to D69/D70: pure
stateless preset table (URLs byte-match §7A; apply fills only non-nil
URLs on the DRAFT; models never touched; no persisted selection; no
Custom item). test() reuses the single probeEndpoints implementation,
mirrors R36 cancels, sets phase only — never persists/closes/sheets
(D38 Save-only holds). R40 740 single-site; R49 scope intact; inline
.failure arm per D70. @MainActor-on-apply lean shape accepted. R62
(stale "Connected" after edits): NO D70 amendment now — cosmetic,
Test-only surface; AT-SCREEN 7A judges tomorrow. If misleading, amend
then as "draft edit resets ProbeState to .idle" (~1 onChange). R63 =
intended R36 mirror. No objection — 7A may proceed to commit.

2026-07-05: SPEC AUTHORED (docs/phase-7-spec.md). Slicing: 7A presets +
connection-test button (reuses D37/D44 probe seams; R40 contentSize
700→740; R49 intact) → 7B onboarding (pure state machine + checklist
window + launch hook + Rerun menu item; R35 smoke owed; D68: IM step
unconditional per phase-1 empirical record) → 7C release recipes
(make release/dmg/notarize/staple, dry-run clean without creds; cask
deferred). Order machine-first; 7C is app-code-free and adds no tests.
NOTHING blocks on the D66 Sparkle sign-off. Expected totals: 191/19 →
~208–212 tests / 21 suites (+EndpointPresetTests,
+OnboardingStateMachineTests). Non-machine verifies are copy-ready in
spec §"Copy-ready block for when-vllm-is-back.md".
