# LotusScribe

**Hold a key, talk, release — your words land as clean text in whatever app you're in.**

LotusScribe is a native macOS menu-bar dictation app: an open, self-hosted clone of [Wispr Flow](https://wisprflow.ai/). Hold the hotkey, speak, let go. Your speech is transcribed by a speech-to-text endpoint, lightly cleaned up by an LLM (filler words gone, punctuation and paragraphs fixed, your meaning untouched), and inserted straight into the focused text field.

It's a **thin client**. LotusScribe ships no model and does no inference — you point it at your own OpenAI-compatible endpoints (local or remote). Nothing is sent anywhere you didn't configure.

> ⚠️ **Not notarized.** There is no signed, notarized release — the author isn't enrolled in the paid Apple Developer Program. You build it from source (instructions below). It's a small Swift app; the build takes about a minute.

---

## How this was built

This is an experiment that turned into a daily driver.

The entire app — every line of Swift, the design system, the build pipeline, the phase docs — was written by **[Fable 5](https://www.anthropic.com/)**, Anthropic's coding model, driving itself through a disciplined **multi-agent, phased-delivery workflow**. Work was cut into numbered phases (scaffold → core hold-to-talk loop → floating waveform HUD → LLM cleanup → app-aware tone → custom dictionary → insertion hardening → distribution → hotkey picker → onboarding → microphone selection). Each phase ran a small crew of one-shot sub-agents:

- an **architect** that wrote the spec and locked decisions,
- a **reviewer** that audited the diff,
- a **tester** that recorded baselines and verify results,

with every gate requiring agreement before the phase closed. The trail is all in [`docs/`](docs/) — one `phase-N-spec.md`, `-architect-log.md`, `-reviewer-observations.md`, `-tester-baselines.md`, and `-team-handoff.md` per phase. [`PLAN.md`](PLAN.md) is the original plan; [`RESEARCH.md`](RESEARCH.md) is the evidence behind the technical choices.

The point was to see how far Fable could get on a real, thorny macOS app — CGEventTap hotkeys, TCC permission dances, Accessibility text insertion, all of it. It got far enough that the author now uses LotusScribe instead of Wispr Flow.

### Want to see the agents think?

If the origin story is the part you're actually here for, **read [`docs/`](docs/).** It's the unedited notebook of the agents building this — not tidied-up marketing, but the real trail: what was proposed, what got pushed back on, what broke on device, and why each decision went the way it did. For every phase you get five files:

- **`phase-N-spec.md`** — the architect's spec: scope, the design, and the numbered decisions (D-numbers) it locked.
- **`phase-N-architect-log.md`** — the running decision log and open questions (Q-numbers), including the ones that were wrong at first and got corrected.
- **`phase-N-reviewer-observations.md`** — the reviewer's audit of the diff.
- **`phase-N-tester-baselines.md`** — what the tester actually ran on a real Mac, with pass/fail outcomes (including the ones that failed).
- **`phase-N-team-handoff.md`** — the state passed to the next phase.

Some of the best reading is where reality overruled the plan — e.g. discovering macOS 26 delivers no Fn-key events to a session event tap (killing the intended hotkey and forcing a redesign), or that Slack silently swallows Accessibility-inserted text. Start at [`PLAN.md`](PLAN.md) for the map, [`RESEARCH.md`](RESEARCH.md) for the evidence behind the choices, then dip into whichever phase interests you.

---

## Features

- **Hold-to-talk** with a configurable hotkey (default **⌃⌘D**). Pick your own chord in Settings; the picker warns about collisions with existing shortcuts.
- **Floating HUD pill** with a live gradient waveform driven by your mic — appears bottom-center, never steals focus, shows over fullscreen apps.
- **LLM cleanup** with three levels — Off / Light / Standard. The model is kept warm so there's no cold-start lag; if it times out, your raw transcript is inserted anyway. It never eats your words.
- **App-aware tone.** LotusScribe notices the frontmost app and adjusts tone by category — Email, Work Messaging, Personal Messaging, Code, Other. Same sentence comes out formal in Mail, casual in Messages. All categories are user-overridable.
- **Custom dictionary** — feed it names, product terms, jargon. It biases both the transcription and the cleanup so they're spelled right.
- **Smart insertion** — Accessibility-API insertion where the field supports it, pasteboard + ⌘V fallback everywhere else, a denylist for apps that silently drop AX text (e.g. Slack), and secure-input detection so it won't fight a password field.
- **Microphone selection** — pin a specific input device.
- **Menu-bar only** — no Dock icon, no ⌘-Tab entry. Lives quietly in the menu bar with a lotus glyph that glows while listening.
- **Onboarding wizard** that walks you through permissions and runs a live connection test against your endpoints.
- **"Lotus Bloom" UI** — dark by default, light mode supported.

---

## Requirements

- **macOS 14 (Sonoma) or newer.**
- **Xcode 15+** with command-line tools (`xcode-select --install`).
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — `brew install xcodegen`.
- An **OpenAI-compatible speech-to-text endpoint** (`/v1/audio/transcriptions`).
- An **OpenAI-compatible chat endpoint** (`/v1/chat/completions`) for cleanup — optional if you set cleanup to Off.

Don't have backends yet? See [Getting a backend running](#getting-a-backend-running) below.

---

## Install (build from source)

```bash
git clone https://github.com/GarisonLotus/LotusScribe.git
cd LotusScribe
```

**Set a signing identity.** `project.yml` hardcodes the author's Apple team ID, which won't work for you. Pick one:

- **Free Apple ID (recommended).** In Xcode → Settings → Accounts, add your Apple ID and note your personal Team ID. Then edit `project.yml` and set `DEVELOPMENT_TEAM:` to that ID. This is recommended because a stable signing identity lets macOS **remember your permission grants** across rebuilds — with ad-hoc signing you re-grant Mic / Accessibility / Input Monitoring every time.
- **Ad-hoc (no Apple ID).** In `project.yml`, under the app target's `settings.base`, replace the `DEVELOPMENT_TEAM` / `CODE_SIGN_STYLE: Automatic` lines with:
  ```yaml
  CODE_SIGN_IDENTITY: "-"
  CODE_SIGN_STYLE: Manual
  ```

**Build:**

```bash
make build
```

**Install the app:**

```bash
cp -R build/Build/Products/Debug/LotusScribe.app /Applications/
open /Applications/LotusScribe.app
```

LotusScribe has no Dock icon — look for the **lotus glyph in your menu bar**. First launch runs the onboarding wizard: it requests Microphone, Accessibility, and Input Monitoring permissions (all needed for hold-to-talk + text insertion), then lets you enter your endpoints and test the connection live.

Run `make test` any time to run the unit-test suite.

---

## Configuration

Open **Settings** from the menu bar. The four fields that matter:

| Field | Example | Notes |
|---|---|---|
| STT endpoint | `http://localhost:8000/v1/audio/transcriptions` | multipart audio in, transcript out |
| STT model | `Systran/faster-whisper-large-v3` | whatever your server exposes |
| LLM endpoint | `http://localhost:11434/v1/chat/completions` | leave blank / cleanup Off to skip |
| LLM model | `llama3.2` | any chat model your server has |

Built-in presets fill in the endpoint URLs for **Speaches**, **Ollama**, and **vLLM** — one click, then adjust the model names to match your server. API keys (if your endpoint needs one) are stored in the macOS Keychain, never in plain settings.

---

## Getting a backend running

LotusScribe needs two OpenAI-compatible endpoints. Here's the shortest path from nothing to working, all local:

### Speech-to-text — [Speaches](https://github.com/speaches-ai/speaches)

A Whisper server that speaks the OpenAI transcription API. With Docker:

```bash
docker run --rm -p 8000:8000 ghcr.io/speaches-ai/speaches:latest-cpu
```

Point LotusScribe's **STT endpoint** at `http://localhost:8000/v1/audio/transcriptions` and set the **STT model** to a Whisper model your server has pulled (e.g. `Systran/faster-whisper-small` on CPU). Check the [Speaches docs](https://github.com/speaches-ai/speaches) for GPU images and model management — they move faster than this README.

### Cleanup LLM — [Ollama](https://ollama.com)

```bash
brew install ollama
ollama serve &
ollama pull llama3.2
```

Point the **LLM endpoint** at `http://localhost:11434/v1/chat/completions` and set the **LLM model** to `llama3.2` (or any chat model you've pulled). A small 3–8B model is plenty for cleanup and stays fast.

> Any OpenAI-compatible server works — [vLLM](https://github.com/vllm-project/vllm), LM Studio, a remote box on your LAN, a cloud endpoint. Local keeps latency low (the whole round-trip targets under ~2 s) and your audio on your own hardware. The commands above are a starting point; treat the upstream projects' docs as the source of truth.

### How the author runs it

The Docker one-liners above are the easy on-ramp. My own setup is heavier, and it's what LotusScribe was actually tuned against:

- **Two [NVIDIA DGX Spark](https://www.nvidia.com/en-us/products/workstations/dgx-spark/) units** sitting on my desk, clustered — both the Whisper STT model and the cleanup LLM (**`nvidia/Qwen3.6-35B-A3B-NVFP4`**) are served from them via **[vLLM](https://github.com/vllm-project/vllm)** behind the OpenAI-compatible API LotusScribe expects.
- **[Traefik](https://traefik.io/traefik/)** as the reverse proxy in front of vLLM, terminating **TLS** so the connection from the Mac to the cluster is **encrypted end-to-end** — not plaintext HTTP over the LAN.
- **Encryption at rest** on the cluster, so the models and any cached data live on encrypted storage.

None of this is required to use LotusScribe — a single machine running the Docker commands above is plenty. But if you want a properly secured, always-warm, GPU-backed setup, that's the shape of it: real inference boxes, vLLM for throughput, and a TLS-terminating proxy so nothing about your voice or text crosses the wire in the clear.

---

## License

MIT — see [`LICENSE`](LICENSE). Use it, fork it, borrow from it, ship your own. No attribution required, though a nod is always nice. No warranty; it's a personal project shared as-is.
