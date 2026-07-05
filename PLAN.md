# LotusScribe Build Plan

Native Swift macOS menu bar app: hold hotkey → speak → release → STT over HTTP → LLM cleanup over HTTP → text lands in the focused app. Thin client; all inference on user-configured OpenAI-compatible endpoints. See RESEARCH.md for evidence behind every choice.

## Architecture

```
┌─ LotusScribe.app (Swift, macOS 14+) ──────────────────────────┐
│  HotkeyManager      CGEventTap (flagsChanged for Fn,          │
│                     keyDown/Up for combos)                    │
│  AudioRecorder      AVAudioEngine input tap → 16kHz mono WAV; │
│                     RMS levels published for waveform         │
│  PillOverlay        NSPanel(.nonactivatingPanel), floating,   │
│                     all-Spaces + fullscreen; SwiftUI waveform │
│  ContextProvider    NSWorkspace frontmost app → category/tone │
│  TranscriptionSvc   POST /v1/audio/transcriptions (multipart) │
│  CleanupService     POST /v1/chat/completions (prompt below)  │
│  TextInserter       AX insertion → fallback pasteboard+Cmd-V  │
│  Settings           endpoints, models, hotkey, tones,         │
│                     dictionary, cleanup level                 │
│  MenuBar            NSStatusItem: state, history, settings    │
└───────────────────────────────────────────────────────────────┘
        │ HTTP (OpenAI-compatible)
        ▼
  STT: Speaches / vLLM Whisper / any /v1/audio/transcriptions
  LLM: Ollama / vLLM / any /v1/chat/completions
```

**Latency budget (target ≤ 2 s perceived):** upload ~50–150 ms (LAN) · STT 300–700 ms (turbo-class Whisper, warm) · LLM cleanup 300–800 ms (warm 3–8B) · insertion <50 ms.

## Phase 0 — Scaffold
Xcode project, `LSUIElement = YES`, NSStatusItem menu bar presence, settings storage (UserDefaults + Keychain for API keys), SPM.
**Verify:** app runs as menu-bar-only item; settings persist across relaunch.

## Phase 1 — Core loop, no polish (the risky 20%)
1. CGEventTap hotkey manager: configurable combo chord default (D27 — macOS 26 delivers no Fn events to session CGEventTaps, live-verified 2026-07-04; hold-Fn code path kept for older macOS only); preflight/request via `CGPreflightListenEventAccess` / `AXIsProcessTrusted`.
2. AVAudioEngine capture on key-down; stop + hand off WAV on key-up.
3. `TranscriptionService`: multipart POST to configured `/v1/audio/transcriptions`; configurable model name, language; 20 s timeout.
4. Insertion v1: pasteboard write + synthesized Cmd-V (the approach every shipped MIT clone uses).
5. Bare settings pane for the two endpoint URLs + model names.

**Verify:** dictate into TextEdit, Slack, a browser textarea, and a terminal against a local Speaches container; empirically record which TCC prompts actually fire (Mic + Accessibility expected; note whether Input Monitoring is demanded) — this resolves the refuted-claim ambiguity before onboarding is built.
**Verify outcome (2026-07-04):** PASSED live on macOS 26 via chord ctrl+alt+cmd+9 against the vllm.garison.com Whisper endpoint; Fn dead at the tap (→ D27); Cmd-V did not land in Terminal (Phase 6); chord leakage + empty-audio hallucination logged (D28, architect log).
**Risks retired:** Fn capture (answered: impossible on macOS 26 → combo default), permission set, insertion, endpoint round-trip.

## Phase 2 — Pill overlay + waveform
1. NSPanel subclass: `[.nonactivatingPanel, .fullSizeContentView]`, `isFloatingPanel`, `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `canBecomeKey = false`; positioned bottom-center of the active screen.
2. SwiftUI waveform bars driven by published RMS from the audio tap; states: idle (hidden) → recording (waveform) → processing (spinner/shimmer) → done (brief checkmark) / error.
3. NSHostingView with `.ignoresSafeArea()`.

**Verify:** pill never steals focus (type in target app while it's visible); shows over a fullscreen app; waveform tracks voice.

## Phase 3 — LLM cleanup
1. `CleanupService`: chat completion against configured endpoint. System prompt pattern (per RESEARCH.md §4): fix filler/punctuation/paragraphs, preserve meaning and voice verbatim otherwise, output cleaned text only.
2. Cleanup levels: Off / Light / Standard (maps to prompt variants); per-utterance raw-transcript fallback kept in history ("undo cleanup" mirror of Wispr).
3. Warm-up: on launch and endpoint change, fire minimal request with `keep_alive: -1` (Ollama) to defeat the 3–10 s cold start.
4. Timeout (~4 s) → insert raw transcript instead; never eat the user's words.

**Verify:** "um so basically I think we should uh ship it tomorrow" → "I think we should ship it tomorrow."; kill the LLM server mid-flight → raw transcript still inserted.

## Phase 4 — App-aware context
1. `NSWorkspace.frontmostApplication` at key-down; bundle-ID → category map (Email / Work messaging / Personal messaging / Code / Other) with per-category tone, user-overridable (Wispr's exact taxonomy).
2. Category + tone woven into the cleanup prompt.
3. Defer per-website browser detection (AX URL extraction) to v2.

**Verify:** same utterance produces casual text in Messages, formal in Mail.

## Phase 5 — Custom dictionary
1. User-managed vocabulary list in settings.
2. Inject into both stages: Whisper `prompt` field (initial prompt biasing) and cleanup system prompt ("these terms are spelled exactly: …").

**Verify:** dictate personal names/product terms; spelled correctly.

## Phase 6 — Insertion hardening
1. AX-first insertion (`AXUIElement` selected-text replacement) where the focused element supports it; pasteboard+Cmd-V fallback.
2. Clipboard restore gated on NSPasteboard `detect` methods; test under `EnablePasteboardPrivacyDeveloperPreview`.
3. Secure-input detection (`IsSecureEventInputEnabled`) → pill shows "can't dictate here".

**Verify:** clipboard contents survive a dictation; password field shows the blocked state; Electron apps (Slack/VS Code) still work via fallback.

## Phase 7 — Distribution
1. First-run onboarding: sequential Mic → Accessibility (→ Input Monitoring if Phase 1 showed it's needed) walkthrough with live preflight status; Fn-key System Settings guidance ("Press fn key to: Do Nothing").
2. Developer ID signing + notarization (`notarytool`), DMG; Sparkle for updates; optional Homebrew cask (VoiceInk-proven path).
3. Endpoint presets in settings: "Speaches (recommended for STT)", "Ollama", "vLLM", custom URL; connection-test button.

**Verify:** clean install on a second Mac from DMG: Gatekeeper passes, onboarding grants all permissions, first dictation works end-to-end.

## Deferred (v2+)
Hands-free/double-tap toggle mode · paste-last-transcript shortcut · per-website browser context · history window with re-copy · streaming partial transcripts · snippets/voice shortcuts · Windows anything.

## Reference borrowing (licenses)
Borrow freely (MIT): **FreeFlow** (Fn hotkey + thin-client endpoints + context), **Parakey** (minimal core loop), **Parrote** (waveform panel, dictation modes), **Handy** (VAD ideas), **danielrosehill prompt**. Study only (GPLv3): **VoiceInk** — no code copying.
