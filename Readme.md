# DelphiLoop

> An AI-powered code generation agent built entirely in Delphi.  
> Two models. One loop. Clean code or keep trying.

![Delphi](https://img.shields.io/badge/Delphi-Object%20Pascal-red?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Version](https://img.shields.io/badge/version-0.3-green?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey?style=flat-square)

---

## What is DelphiLoop?

DelphiLoop is a desktop application that runs an agentic **generate → review → refine** loop using two AI models simultaneously.

You write a task. The **Executor** model generates Delphi code. The **Reviewer** model inspects it for bugs, memory leaks, logic errors, and bad practices. If issues are found, the Executor fixes them. This continues until the Reviewer says `NO_ISSUES` — or the iteration limit is reached.

It works with local models via **Ollama** and cloud models via **OpenAI** or **OpenRouter** (or any OpenAI-compatible API). You can mix and match — local executor, cloud reviewer, or the other way around.

---

## Screenshots

![Main window](docs/screenshot_main.png)

---

## Features

- **Agentic loop** — generate → review → refine, up to N iterations
- **Two independent agents** — Executor writes, Reviewer criticizes
- **Multi-provider support** — Ollama, OpenAI, OpenRouter, any OpenAI-compatible endpoint
- **Model mixing** — local + cloud, any combination
- **Native chat UI** — FMX-based chat bubbles: task, thinking, code, review, result — each rendered as a distinct visual element
- **Delphi syntax highlighting** — custom lexer written from scratch, no WebView, no dependencies
- **Collapsible code bubbles** — intermediate drafts stay out of the way; final result opens automatically
- **External prompts** — override agent behavior via markdown files, no recompile needed
- **Persistent XML config** — providers, models, and settings saved between sessions
- **Token counter** — tracks tokens used and estimated cost per session
- **Copy to clipboard** — one click to grab any generated code

---

## How It Works

```
┌─────────────────────────────────────────────────────┐
│                     Your Task                       │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │    EXECUTOR     │  ← writes code
              │  (any model)    │
              └────────┬────────┘
                       │ code
                       ▼
              ┌─────────────────┐
              │    REVIEWER     │  ← finds issues
              │  (any model)    │
              └────────┬────────┘
                       │
              ┌────────┴────────┐
              │                 │
           NO_ISSUES         issues found
              │                 │
              ▼                 ▼
           DONE ✓         back to EXECUTOR
                          (with review notes)
```

The loop runs in a background thread. The UI stays responsive throughout. All events flow back to the form via callbacks — the engine knows nothing about buttons or labels.

---

## Architecture

```
DelphiLoop.dpr
│
├── uMain.pas                 ← UI only, subscribes to engine events
│                               Built entirely in code — no DFM, no designer
│
├── uCodeView.pas             ← Custom TCodeView control
│                               Canvas-based Delphi syntax highlighter
│
├── uDelphiLexer.pas          ← Hand-written Delphi lexer
│                               Tokenizes keywords, identifiers, strings, comments
│
├── LoopEngine.pas            ← All agent logic, HTTP, JSON parsing
│                               Communicates via callbacks only
│
├── LoopPrompts.pas           ← Loads prompts from .md files or falls back to constants
│
├── LoopConfig.pas            ← TLoopConfig (data) + TLoopConfigIO (XML)
│
├── LoopTypes.pas             ← TProviderConfig, TModelConfig, TProviderType
│
└── LoopConsts.pas            ← All strings, prompts, pricing constants
```

The engine is decoupled from the UI by design. The same `LoopEngine` can run in a console app, a service, or an FMX Android app — just replace `uMain`.

### Engine Events

All events marshalled to the main thread via `TThread.Synchronize`:

| Event | When |
|---|---|
| `OnThink` | Model is generating (shows "→ Model thinking...") |
| `OnPhase` | Phase changed — generating / reviewing / refining |
| `OnCode` | Code produced, adds a collapsible code bubble |
| `OnReview` | Review result — rejection (red), approved (green), or NO_ISSUES |
| `OnDone` | Loop finished — final result bubble added, auto-opened |
| `OnError` | Exception during loop |
| `OnTokens` | Tokens used + estimated cost |

---

## The UI

v0.3 is a full rewrite of the interface. Old VCL layout replaced with FMX, built entirely in code — no `.dfm`, no designer, no external component packages.

The chat area uses a `TVertScrollBox` with manually positioned controls. Each message type is a distinct visual element:

- **Task** — right-aligned bubble, collapsible
- **Thinking** — plain italic row, no bubble
- **Code** — dark bubble with Delphi syntax highlighting, collapsible, copy button
- **Review** — tinted bubble: red for rejection (collapsible with reason), green for approval
- **Done** — slim green status bar
- **Result** — accent-bordered bubble, opens automatically, copy button

Code rendering uses a hand-written lexer (`uDelphiLexer.pas`) and a custom `TCodeView` control that paints directly to canvas. No WebView2, no HTML, no Chromium. One `.exe`, no runtime.

---

## Prompts

Prompts are loaded from external markdown files placed next to the executable:

```
prompt_executor.md
prompt_reviewer.md
prompt_refine.md
```

If a file is missing, DelphiLoop falls back to built-in defaults in `LoopConsts.pas`.

**Executor** — minimum code only, no preamble, no explanations outside the code. Interprets the task, picks the simplest approach, writes it.

**Reviewer** — hardened in v0.3 using principles from [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills): severity tagging (`[CRITICAL]`, `[MAJOR]`, `[MINOR]`), impact statements, silent pre-reasoning. Flags only real bugs in Delphi/Object Pascal context.

**Refine** — touches only what the review explicitly listed. Every changed line traces to a specific issue.

---

## Getting Started

### Requirements

- **RAD Studio** 11 Alexandria or newer (tested on RAD Studio 13 Florence)
- **Windows** 10/11
- **Ollama** (optional, for local models) — [ollama.com](https://ollama.com)
- **OpenAI API key** (optional)
- **OpenRouter API key** (optional) — [openrouter.ai](https://openrouter.ai)

### Build

1. Clone the repository
2. Open `DelphiLoop.dpr` in RAD Studio
3. Build (`Shift+F9`)
4. Run

No third-party components. No GetIt packages. Pure FMX.

### First Run

On first launch, DelphiLoop creates a default `DelphiLoop.xml` config file with three providers and several models pre-configured. Open **Settings** to add API keys.

---

## Model Recommendations

Based on real runs:

| Pair | Iterations | Quality | Cost |
|---|---|---|---|
| Qwen3 Coder → gpt-4o | ~2 | ★★★★★ | Low |
| gpt-4o-mini → gpt-4o | ~3 | ★★★★★ | Low |
| qwen2.5-coder:7b → gpt-4o | ~4 | ★★★ | Free* |
| gpt-4o → gpt-4o | ~2 | ★★★★★ | High |

**Best value:** `Qwen3 Coder 480B` (OpenRouter) as Executor + `gpt-4o` as Reviewer — ~$0.01 per run.  
**Fully local:** `qwen2.5-coder:7b` as Executor + `llama3.1:8b` as Reviewer.

> Note: `gpt-4o-mini` as reviewer tends to hallucinate issues that don't exist. Use `gpt-4o` for review.

---

## Roadmap

- [ ] Persistent chat history
- [ ] Per-model token pricing in config
- [ ] API key encryption (Windows DPAPI)
- [ ] RAG over `.pas` files — context-aware generation
- [ ] Benchmark mode — run same task N times, compare model pairs
- [ ] FMX Android port (engine is already platform-agnostic)

---

## Changelog

### v0.3
- **Full UI rewrite** — VCL replaced with FMX, built entirely in code (no DFM)
- **Native chat interface** — chat bubbles for every message type; no WebView, no HTML
- **Delphi syntax highlighter** — hand-written lexer + canvas-based TCodeView
- **Collapsible code bubbles** — intermediate drafts collapse; final result opens automatically
- **Reviewer prompt hardened** — severity tagging, impact statements, silent pre-reasoning based on [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills)
- **Executor prompt tightened** — no preamble, no prose before code

### v0.2
- OpenRouter support
- External prompts (`prompt_executor.md`, `prompt_reviewer.md`, `prompt_refine.md`)
- Modernized prompt design based on Karpathy's agent skill guidelines
- Dropped C++ Builder — Delphi-only
- Default model updated to Qwen3 Coder 480B via OpenRouter

### v0.1
- Initial release
- Generate → review → refine loop
- Ollama + OpenAI support
- Persistent XML config, settings UI, token counter

---

## Why Delphi?

Because why not.

Delphi has a mature HTTP client, JSON parser, XML support, generics, and threading primitives — everything needed to build an AI agent loop. The result is a single native `.exe`, no runtime, no dependencies, instant startup.

This is still a rough version. But rough versions ship, and sometimes they inspire someone.

---

## License

MIT — see [LICENSE](LICENSE)

---

## Author

Built by a senior Delphi developer who got curious about local LLMs one evening.

[LinkedIn](https://www.linkedin.com/in/kusmin-ilia/) | [GitHub](https://github.com/rm3g25/)
