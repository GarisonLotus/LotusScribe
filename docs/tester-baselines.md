# Tester baselines — LotusScribe

> Last gate's exact counts + flake registry. Updated by tester at end of
> each dispatch. Read by tester on every spawn for cross-checking.

## Last gate

**Sub-phase:** 0A
**Date:** 2026-07-04
**Test command:** `make test` (xcodegen generate → xcodebuild test, scheme LotusScribe, platform=macOS)
**Counts:** TEST SUCCEEDED — 1 test, 0 failures, 0 suites ("Test run with 1 test in 0 suites passed"). xcresult: errorCount 0, warningCount 0, analyzerWarningCount 0.
**Per-file breakdown:**
- `Tests/LotusScribeTests/SmokeTests.swift` — 1 test: `appDelegateInitializes()` — passed (0.001s)

**Warnings triaged:** none — zero compiler/analyzer warnings (verified via
`xcrun xcresulttool get build-results` on the test xcresult). Runtime log
noise during hosted test run is tracked in the flake registry below, not a
warning.

Runtime/artifact checks (0A verify steps 2–4), 2026-07-04:
- Built app Info.plist: `LSUIElement => true`, `CFBundleIdentifier => com.garisonlotus.LotusScribe`, `LSMinimumSystemVersion => 14.0`.
- Launched .app via `open`: process ran (pgrep confirmed); `lsappinfo` reported `ApplicationType="UIElement"` (programmatic no-Dock/no-Cmd-Tab evidence); quit cleanly via AppleScript.
- `git status --porcelain`: no `.xcodeproj`, DerivedData, or generated `Sources/LotusScribe/Info.plist` tracked/staged; both confirmed matched by `.gitignore` via `git check-ignore -v`.
- Human-visual remainder: status item actually visible in menu bar; Quit menu item works from the UI; visual absence from Cmd-Tab switcher.

## Flake registry

| date | test name | failure mode | other tests in same file affected |
|------|-----------|--------------|-----------------------------------|
| 2026-07-04 | (known-noise, not a flake) | `com.apple.linkd.autoShortcut` XPC errors (NSCocoaErrorDomain 4097) logged at hosted-app launch during `make test`; cosmetic, tests unaffected | none |
| 2026-07-04 | (known-noise, not a flake) | one `[WarnOnce] It's not legal to call -layoutSubtreeIfNeeded on a view which is already being laid out` runtime log at hosted-app launch; cosmetic, tests unaffected | none |
