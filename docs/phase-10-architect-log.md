# Architect Log — LotusScribe (Phase 10)

Locked decisions (compact; git log carries provenance). Newest at bottom.
Continues numbering from Phase 9 (…D88).

| ID | Date | Decision | Why | Sub-phase |
|----|------|----------|-----|-----------|
| D89 | 2026-07-06 | Hotkey label spelled as words joined by `" + "` → "Command + F5" (NOT glyphs "⌘F5"), from a PURE `HotkeyChord.spelledLabel` (reverse-looks-up the existing keycode maps, spells modifiers Control/Option/Shift/Command). `HotkeyOption.displayLabel` redefined to delegate; all 3 sites (HUD chip, picker menu, Try-it copy) inherit it | User's phrasing was "Command + F5"; must reflect the REAL resolved chord (D87), never hardcoded; no test references `displayLabel`, so redefining is safe | 10A |
| D90 | 2026-07-06 | Onboarding Setup persists via a buffered `SettingsDraft` (owned by `OnboardingWindowController`) committed by `draft.save()` on Continue — ungated (skippable), no D42 warm-up. Hotkey stays live write-through (D83). D26 ("Save is sole store-write in the **Settings window**") untouched — onboarding is a separate window/draft; mirrors Settings' own endpoint-buffered / hotkey-live split | Endpoints are buffered+probe-gated by nature in Settings; a per-keystroke live write of half-typed URLs to the shared store is wrong. Buffered draft REUSES `apply`, `endpointField`, `ConnectionProbe` seams and gives onboarding a coherent, D26-safe write path | 10C |
| D91 | 2026-07-06 | Suggested models live on `EndpointPreset` as new optional `suggestedSTTModel`/`suggestedLLMModel` (default nil → memberwise-init source-compatible). Speaches `whisper-large-v3`, Ollama `llama3.2:3b`, vLLM nil. `apply(to:)` UNCHANGED (D69 — never sets model fields). Entries named `static let speaches/ollama/vllm` so onboarding references the featured two | Keeps model+endpoint together and reusable; must not regress the Settings preset menu, which relies on `apply` not touching models | 10C |
| D92 | 2026-07-06 | Onboarding shows install cards for the featured servers ONLY (Speaches, Ollama); vLLM gets none (stays a Settings preset). Each card = short numbered steps + ONE copyable mono command + a "Full docs" link. Speaches: `docker run -p 8000:8000 ghcr.io/speaches-ai/speaches:latest`, docs speaches.ai. Ollama: `ollama pull llama3.2:3b`, docs ollama.com | Locked format (handoff §3) must fit 480×480; three servers is a wall. Commands realistic-not-code-verified per task rails | 10D |
| D93 | 2026-07-06 | Flow Welcome→Permissions→**Setup(NEW)**→Try it. `stepIndex` 0/1/2/3; `stepContent` adds `case 2: setupStep`; `progressDots` 3→4; `navBar` adds `case 2` (Back→1, Continue→3 always enabled); Try-it becomes `case 3` (Finish gated `.done`, D67). Kickers all → "STEP N OF 4" | Setup gate LOCKED skippable — Continue never blocks; Finish's all-green gate stays on Try it | 10B/10D |
| D94 | 2026-07-06 | Slice: 10A label clarity (ship first) → 10B step scaffold+renumber → 10C persistence+featured-prefill+fields → 10D install content+connection test. Each independently committable, 4-way gated | 10A is the quick win and touches only the label; 10B is pure UI scaffolding; 10C is data/persistence; 10D is content+probe | — |

## Open questions

- Install command exactness: the Speaches `docker run` image tag and the Ollama
  steps are realistic-but-unverified (task rails say do not code-verify servers).
  Engineer/human should confirm against current Speaches/Ollama docs before 10D
  ships — not a blocker for 10A/10B.
- None block 10A: it is self-contained (label formatter + 3 call sites).
