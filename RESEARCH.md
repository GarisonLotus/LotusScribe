# LotusScribe Research Report

Deep research for building **LotusScribe** — a native Swift macOS clone of [Wispr Flow](https://wisprflow.ai/): push-to-talk dictation with server-side STT + LLM cleanup over user-configured OpenAI-compatible HTTP endpoints.

**Method:** 5 parallel search angles → 23 sources fetched → 109 claims extracted → top 25 adversarially verified (3 independent verifiers each). Verification markers: ✅ = confirmed 3-0 (or 2-1), ⚠️ = extracted from a primary source but verification incomplete (rate-limited), ❌ = refuted. Unmarked claims come from fetched sources but weren't in the verified top-25.

---

## 1. How Wispr Flow actually works

### Pipeline
- Two-stage cloud pipeline: speech-to-text models followed by **fine-tuned Llama** transcript enhancement (fine-tuned, not merely prompted). Runs on Baseten infrastructure (AWS us-east-1) with traffic-based GPU autoscaling — a thin client with server-side models, exactly LotusScribe's chosen shape. ([Baseten case study](https://www.baseten.co/resources/customers/wispr-flow/))
- Claimed end-to-end clean-transcript latency: **under 700 ms at p99**. The Llama cleanup stage must generate 100+ tokens in under 250 ms — roughly a third of the budget. ([Baseten](https://www.baseten.co/resources/customers/wispr-flow/))
- Real-world users report **closer to 1–2 seconds** end-to-end — "fine for paragraph-by-paragraph dictation." This is the honest latency bar for LotusScribe. ([zackproser review](https://zackproser.com/blog/wisprflow-review))
- Cleanup uses an OpenAI subprocessor plus fine-tuned Llama, with four user-selectable levels (None / Light / Medium / High) and an **"Undo AI Edit"** button revealing the raw transcript. Known failure mode: over-editing — "improving" what the user actually said. ([zackproser](https://zackproser.com/blog/wisprflow-review))

### Interaction model
- ✅ Core interaction is push-to-talk: **hold the shortcut key** to dictate; double-tap for hands-free/toggle mode. ([Wispr docs](https://docs.wisprflow.ai/articles/3152211871-setup-guide))
- ✅ Default hotkey on Apple keyboards is the **Fn key**; falls back to **Ctrl+Opt** on non-Apple external keyboards. LotusScribe needs Fn capture plus a configurable modifier-combo fallback. ([Wispr docs](https://docs.wisprflow.ai/articles/3152211871-setup-guide))
- Secondary Mac shortcuts: Cmd+Ctrl+V = paste last transcript, Fn+Space = hands-free. Good v2 candidates.
- Menu bar app; standard macOS microphone permission dialog during setup.
- ✅ Requires **Accessibility** permission specifically to insert text into other apps. ([Wispr docs](https://docs.wisprflow.ai/articles/3152211871-setup-guide))
- Insertion works universally — one reviewer tested 36+ apps (Cursor, Slack, web apps, email). Keeps up with 2x-speed speech.
- 6-minute recording cap per session.

### Context awareness (the moat feature)
- ✅ Reads the **active app plus a limited amount of text near the cursor** to adapt accuracy, style, and formatting. ([Wispr docs](https://docs.wisprflow.ai/articles/4678293671-feature-context-awareness))
- ✅ Four app categories with default tones: **Email → Formal, Work messaging → Formal, Personal messaging → Casual, Other → Formal**, each with user-selectable alternatives. ([Wispr docs](https://docs.wisprflow.ai/articles/4678293671-feature-context-awareness))
- ✅ For browsers, detects the **specific website**, not just the browser (Chrome, Safari, Arc, Brave, Edge, Firefox, Opera). Plain NSWorkspace frontmost-app detection is insufficient for browser context. ([Wispr docs](https://docs.wisprflow.ai/articles/4678293671-feature-context-awareness))
- Mid-sentence continuation: lowercases first letter, manages spacing based on surrounding text; skips placeholder/hint text in Notion/Claude/ChatGPT.
- Privacy posture: context processed locally, relevant context sent to servers during transcription; **password fields explicitly excluded**; user toggle in settings.

### Product positioning
- Pricing: free Basic tier at 2,000 words/week; Pro $12–15/month (sources differ by date) with unlimited words + Command Mode; Teams tier. Custom dictionary syncs across devices on all tiers.
- Claims ~97.2% accuracy on standard English; 100+ languages with code-switching and auto-detection. Cloud-only, no offline mode.

---

## 2. macOS client engineering

### Global hotkey (incl. Fn key)
- ✅ Apple DTS (Quinn "The Eskimo!") recommends **CGEventTap** over NSEvent global monitors and Carbon `RegisterEventHotKey`, specifically because of its TCC interactions. ([Apple dev forums](https://developer.apple.com/forums/thread/735223))
- ✅ Listening to global keyboard events requires the **Input Monitoring** TCC privilege (verified 2-1 — see permission nuance below). ([Apple dev forums](https://developer.apple.com/forums/thread/735223))
- ✅ CGEventTap has first-class privilege APIs — `CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()` — and is App Sandbox–compatible since macOS 10.15. ([Apple dev forums](https://developer.apple.com/forums/thread/735223))
- Apple's engineer warns CGEventTap "is a bit tricky to use from Swift" — implementation risk, but four shipped open-source apps prove it out.
- Fn is a modifier, so capture means watching `flagsChanged` events via the tap. **FreeFlow proves hold-Fn push-to-talk works in a distributable Swift app** (with Cmd-Fn toggle mode). ([FreeFlow](https://github.com/zachlatta/freeflow))
- **Permission nuance:** the claim "you need all three of Microphone + Accessibility + Input Monitoring" was **❌ refuted (0-3)**. Shipped apps differ: Parrote requires Accessibility (not Input Monitoring) for its hotkey. In practice, an app granted Accessibility can run listen-only event taps without a separate Input Monitoring grant. Plan for **Microphone + Accessibility** as the required set, with Input Monitoring as a possible extra depending on tap configuration — verify empirically in Phase 1.

### Text insertion into the focused app
Three options, with real-world evidence:

| Approach | Evidence | Tradeoff |
|---|---|---|
| Pasteboard + synthesized Cmd-V | ✅ Parakey, ✅ Parrote ("works everywhere"), Handy all ship this | Universal; clobbers clipboard; new privacy alert risk (below) |
| AX API (`AXUIElement` value/selected-text) | Wispr's Accessibility requirement implies AX or synthetic events | Clean, no clipboard; not all apps implement AX text editing (Electron apps are spotty) |
| CGEvent per-keystroke synthesis | — | Slow for long text; layout-dependent |

- **Upcoming pasteboard privacy alert:** macOS (previewed ~WWDC 2025) will show a user-facing alert whenever an app **programmatically reads** the general pasteboard. Writing is unaffected — but the standard "save clipboard, paste, restore clipboard" dance requires a read. New `detect` methods on NSPasteboard let you inspect pasteboard content types without triggering the alert. Testable today via `defaults write <bundle-id> EnablePasteboardPrivacyDeveloperPreview -bool yes`. ([Lapcat Software](https://lapcatsoftware.com/articles/2025/5/3.html))
- An experienced macOS dev removed a clipboard feature entirely rather than expose users to the alert — prompt fatigue is a real product risk on top of mic + Accessibility prompts.
- **Recommendation:** paste-based insertion as the universal default; attempt AX insertion first where the focused element supports it; make clipboard-restore optional/smart via `detect` methods.
- **Secure input fields** (password fields, apps that enable EnableSecureEventInput) block event taps and synthetic input — detect and show a "can't dictate here" state rather than failing silently. (Flagged as risk; not deeply covered by sources.)

### Floating pill overlay (the animation)
All from [Cindori's floating panel guide](https://cindori.com/developer/floating-panel) and [Fazm's menu-bar best practices](https://fazm.ai/blog/swiftui-menu-bar-app-floating-window-best-practices):
- Subclass **NSPanel** with `styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView]` — `.nonactivatingPanel` prevents stealing focus, so the target app keeps keyboard focus while the pill is visible. Clicking the pill keeps the underlying app frontmost.
- `isFloatingPanel = true`, `level = .floating` → always on top. `becomesKeyOnlyIfNeeded = true`.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` → pill appears across Spaces and over fullscreen apps.
- Host SwiftUI via `NSHostingView(rootView: view().ignoresSafeArea())` — safe-area must be ignored or the hidden title bar breaks layout geometry.
- Leave `canBecomeKey`/`canBecomeMain` returning false for a display-only pill — keyboard focus never leaves the target app.
- `LSUIElement = YES` in Info.plist → no Dock icon, no Cmd-Tab entry, menu-bar-only presence.
- Use **NSStatusItem + custom NSPanel**, not SwiftUI `MenuBarExtra(.window)` — MenuBarExtra can't do custom positioning like a bottom-center pill.
- Waveform animation: drive SwiftUI bars from RMS/FFT of the live `AVAudioEngine` input tap (Parrote ships exactly this: floating panel + live waveform, SwiftUI/AppKit hybrid).
- Launch at login: `SMAppService.loginItem`.

### Mic capture
- ✅ **AVAudioEngine** is the proven choice (Parakey, Parrote). Install a tap on the input node; Whisper-family models want 16 kHz mono — resample client-side or let the server do it (vLLM resamples server-side).

---

## 3. Server-side STT (OpenAI-compatible `/v1/audio/transcriptions`)

### Speaches — recommended default
- ✅ OpenAI API-compatible server for transcription, translation, and TTS. ([speaches-ai/speaches](https://github.com/speaches-ai/speaches))
- ✅ Backend is **faster-whisper**, so Whisper-family accuracy/latency characteristics apply.
- MIT, ~3.4k stars, active (v0.9.0-rc.3, Dec 2025). Docker/Compose, GPU + CPU.
- Positions itself as "Ollama, but for TTS/STT models" — dynamic model load/offload. **Cold-start risk:** configure it to keep the model resident.
- Validated in the wild: Whispering uses Speaches as its fully-local backend.

### vLLM
- ⚠️ Serves STT at `/v1/audio/transcriptions` and `/v1/audio/translations`, accepting OpenAI-style multipart form-data (`file`, `model`) — a client written against the OpenAI audio API points at vLLM unchanged. ([vLLM docs](https://docs.vllm.ai/en/latest/contributing/model/transcription/))
- ⚠️ Whisper is **in-tree** (`vllm/model_executor/models/whisper.py`), first-party. Also in-tree ASR: Voxtral, Gemma3n, Qwen3-Omni behind the same endpoint.
- ⚠️ Server handles resampling and >30 s energy-aware chunking — client can send arbitrary-length raw audio. Language defaults to English; override via `language` field.

### DGX Spark (GB10) reference deployment
- ⚠️ vLLM runs on DGX Spark via NVIDIA's official Docker image (`nvcr.io/nvidia/vllm:25.11-py3`), OpenAI-compatible chat endpoint tested. ([Arm learning path](https://learn.arm.com/learning-paths/laptops-and-desktops/dgx_spark_voicechatbot/))
- ⚠️ **Notably, Arm's own DGX Spark voice pipeline does NOT use vLLM for STT** — it runs faster-whisper (small.en/medium.en, int8) on CPU. Treat vLLM-Whisper-on-GB10 as unproven; **Speaches/faster-whisper is the battle-tested STT route on Spark**, with vLLM serving the LLM half.
- ⚠️ Spark headroom: vLLM + GPTQ Mistral-7B loaded in ~20 s using ~3.9 GiB, leaving ~102 GiB KV cache — a small cleanup LLM co-locates comfortably with an STT server.
- Parakeet alternative behind OpenAI API: [achetronic/parakeet](https://github.com/achetronic/parakeet) wraps NVIDIA Parakeet TDT 0.6B in a Whisper-compatible server.

### Model choice
- whisper-large-v3-turbo and distil-large-v3 trade a little accuracy for large speed gains vs large-v3 (HF benchmarks; details not deep-verified). For dictation-length clips on GPU, turbo-class models are the sweet spot; expose model name as a setting and pass it through.

---

## 4. LLM cleanup stage

### Prompt pattern (validated by an MIT-licensed shipped prompt)
From [danielrosehill/STT-Basic-Cleanup-System-Prompt](https://github.com/danielrosehill/STT-Basic-Cleanup-System-Prompt) + [Tap2Talk guide](https://tap2talk.app/blog/custom-cleanup-prompt-dictation/):
- Frame as "improve the user's text for flow and accuracy" — **not** rewrite.
- Enumerate exactly what to fix: filler/pause words, missing punctuation, paragraph breaks.
- Guard meaning drift explicitly: "Preserve the content… preserve the uniqueness of their voice and perspective."
- "Return only the cleaned text, no commentary" — required for programmatic insertion.
- Strip long-form document rules (max-3-sentence paragraphs, subheadings) for short field dictation.
- Wispr's own failure mode (over-editing) argues for a Light/Medium/High cleanup setting + "insert raw transcript" escape hatch, mirroring their Undo AI Edit.

### Serving: Ollama vs vLLM
- **Ollama cold-start is the #1 latency landmine:** default unload after 5 min idle; reload penalty **3–10 s for a 7B model** — triple the entire latency budget. Fix: `keep_alive: -1` per-request or `OLLAMA_KEEP_ALIVE=-1` env; warm the model at app launch with a minimal request; `/api/ps` shows loaded models. ([mljourney](https://mljourney.com/ollama-keep-alive-and-model-preloading-eliminate-cold-start-latency/))
- vLLM: ~6x lower time-to-first-token in one benchmark (10.7 ms vs 65 ms); far better concurrency; fuller OpenAI compatibility (JSON-schema structured outputs). For a single user, **either works** — "Ollama is not a production server, and vLLM is not a developer tool." ([particula.tech](https://particula.tech/blog/ollama-vs-vllm-comparison))
- Model size: 3–8B is plenty. A fine-tuned Llama 3.2 3B beat 70B models on transcript tasks in one writeup ([bilawal.net](https://bilawal.net/post/finetuning-llama32-3b-for-transcripts/)); Qwen/Gemma small models are the usual candidates ([BentoML SLM roundup](https://www.bentoml.com/blog/the-best-open-source-small-language-models)). Wispr fine-tunes; LotusScribe v1 should prompt-engineer first.
- Latency math: Wispr's fine-tuned stage does 100+ tokens < 250 ms on dedicated GPUs. Self-hosted prompt-based cleanup of a typical utterance (~50–150 output tokens) on a decent GPU ≈ 300–800 ms — fits the 1–2 s budget only if STT is fast and the model is warm. FreeFlow ships a 20 s default network timeout and warns local backends are slower — timeout + fall-back-to-raw-transcript is mandatory.

---

## 5. Prior art (what to borrow)

| Project | Stack | License | Key takeaways for LotusScribe |
|---|---|---|---|
| [FreeFlow](https://github.com/zachlatta/freeflow) | Swift (94%), 2.1k★ | MIT | **Closest architectural match.** Hold-Fn push-to-talk + Cmd-Fn toggle; thin client; any OpenAI-compatible endpoint (Groq default, Ollama/LM Studio supported); app-aware context + custom vocabulary in the LLM stage. Borrow freely. |
| [Parakey](https://github.com/rcourtman/parakey) | Swift | MIT | ✅ CGEventTap hotkey + AVAudioEngine capture; ✅ paste-at-cursor insertion. Minimal, readable reference for the core loop. |
| [Parrote](https://github.com/shubham-web/parrote-dictation-app) | Swift, macOS 14+ | MIT | ✅ Same loop, ✅ CGEventTap + Accessibility, ✅ clipboard paste "works everywhere"; **floating waveform recording panel** (SwiftUI/AppKit hybrid) = the pill overlay reference; per-mode dictation styles with optional Ollama refinement. |
| [VoiceInk](https://github.com/Beingpax/VoiceInk) | Swift, 5.4k★ | **GPLv3** | ⚠️ Ships all three v1 differentiators (app-aware "Power Mode", trainable dictionary, screen-context transcription) but on-device (whisper.cpp/FluidAudio). **Study only — do not copy code** unless LotusScribe goes GPL. Proves Homebrew-cask + notarized direct-download distribution works for this category. |
| [Handy](https://github.com/cjpais/handy) | Tauri/Rust | MIT | Silero **VAD** for silence filtering; Whisper + Parakeet V3 engine menu. Architecture reference only (not Swift). |
| [Whispering](https://epicenter.so/whispering/) | Cross-platform | MIT | Validates Speaches as a local backend; post-transcription LLM workflows; BYO-key direct-to-provider pattern. |

---

## 6. Engineering risk register

1. **Fn-key capture** — needs a CGEventTap watching `flagsChanged`; Fn also triggers system actions (emoji picker / system dictation) — onboarding must tell users to set System Settings → Keyboard → "Press fn key to: Do Nothing". Feasibility proven by FreeFlow. Ship Ctrl+Opt-style fallback.
2. **Permission friction** — Mic + Accessibility required; Input Monitoring possibly a third prompt depending on tap type (empirically verify). Build a first-run onboarding that walks each grant with preflight checks (`CGPreflightListenEventAccess`, `AXIsProcessTrusted`). The refuted 3-permission claim means the set is app-configuration-dependent — test, don't assume.
3. **Pasteboard privacy alert (upcoming macOS)** — programmatic clipboard *reads* will alert; paste-insertion writes are fine but save/restore needs `detect`-method gating or an opt-out. Test with `EnablePasteboardPrivacyDeveloperPreview`.
4. **Secure input** — password fields/secure-input apps block synthetic input; detect (`IsSecureEventInputEnabled`) and surface a clear "can't dictate here" pill state.
5. **Cold starts** — Ollama unload (3–10 s reload) and Speaches dynamic offload both blow the latency budget; warm models at launch + keep-alive; show processing state honestly in the pill.
6. **vLLM Whisper on GB10/ARM unverified** — Arm's own Spark pipeline uses faster-whisper instead. Default docs should point Spark users at Speaches for STT + vLLM/Ollama for LLM.
7. **Over-editing by cleanup LLM** — mirror Wispr: cleanup intensity setting + raw-transcript escape hatch; prompt hard against meaning changes.
8. **Latency honesty** — Wispr's 700 ms p99 rides fine-tuned models on dedicated autoscaled GPUs; realistic self-hosted target is 1–2 s with a warm 3–8B model and turbo-class Whisper.
9. **Browser context** — matching Wispr's per-website detection needs AX/AppleScript URL extraction per browser; ship app-level categories first, website detection later.

---

## Sources (23 fetched, quality-tagged by extractors)

**Primary:** [Wispr docs — Context Awareness](https://docs.wisprflow.ai/articles/4678293671-feature-context-awareness) · [Wispr docs — setup guide](https://docs.wisprflow.ai/articles/3152211871-setup-guide) · [Apple dev forums (Quinn on hotkeys)](https://developer.apple.com/forums/thread/735223) · [vLLM transcription docs](https://docs.vllm.ai/en/latest/contributing/model/transcription/) · [Arm DGX Spark voice pipeline](https://learn.arm.com/learning-paths/laptops-and-desktops/dgx_spark_voicechatbot/) · [speaches](https://github.com/speaches-ai/speaches) · [Parakey](https://github.com/rcourtman/parakey) · [Parrote](https://github.com/shubham-web/parrote-dictation-app) · [VoiceInk](https://github.com/Beingpax/VoiceInk) · [Handy](https://github.com/cjpais/handy) · [FreeFlow](https://github.com/zachlatta/freeflow) · [Whispering](https://epicenter.so/whispering/) · [STT cleanup prompt](https://github.com/danielrosehill/STT-Basic-Cleanup-System-Prompt)

**Secondary/blog:** [Baseten × Wispr Flow case study](https://www.baseten.co/resources/customers/wispr-flow/) · [zackproser review](https://zackproser.com/blog/wisprflow-review) · [Spokenly review](https://spokenly.app/blog/wispr-flow-review) · [Zapier on Wispr Flow](https://zapier.com/blog/wispr-flow/) · [Cindori floating panel](https://cindori.com/developer/floating-panel) · [Fazm menu-bar best practices](https://fazm.ai/blog/swiftui-menu-bar-app-floating-window-best-practices) · [Lapcat on pasteboard privacy](https://lapcatsoftware.com/articles/2025/5/3.html) · [Ollama keep-alive](https://mljourney.com/ollama-keep-alive-and-model-preloading-eliminate-cold-start-latency/) · [Ollama vs vLLM](https://particula.tech/blog/ollama-vs-vllm-comparison)

*Verification note: 16 claims confirmed 3-0 by independent verifiers; 8 claims (vLLM Whisper details, DGX Spark specifics, VoiceInk details) extracted from primary sources but adversarial verification was cut short by a rate limit — treat ⚠️ items as high-confidence-unverified.*
