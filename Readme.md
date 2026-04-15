# DelphiLoop

> An AI-powered code generation agent built entirely in Delphi.  
> Two models. One loop. Clean code or keep trying.

![Delphi](https://img.shields.io/badge/Delphi-Object%20Pascal-red?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Version](https://img.shields.io/badge/version-0.2-green?style=flat-square)
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
- **External prompts** — override agent behavior via markdown files, no recompile needed
- **Persistent XML config** — providers, models, and settings saved between sessions
- **Settings UI** — add/edit/remove providers and models without touching config files
- **Token counter** — tracks tokens used and estimated cost per session
- **Resizable layout** — drag the splitter to adjust task input vs output area
- **Copy to clipboard** — one click to grab the generated code
- **Clear log** — cleans up the log between runs

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

DelphiLoop is intentionally structured so the engine is decoupled from the UI.

```
DelphiLoop.dpr
│
├── uMain.pas / uMain.dfm     ← UI only, subscribes to engine events
│
├── LoopEngine.pas            ← All agent logic, HTTP, JSON parsing
│                               Communicates via callbacks only
│
├── LoopPrompts.pas           ← Loads prompts from .md files or falls back to constants
│
├── LoopConfig.pas            ← TLoopConfig (data) + TLoopConfigIO (XML)
│                               Uses TList<T> generics
│
├── LoopTypes.pas             ← TProviderConfig, TModelConfig, TProviderType
│
└── LoopConsts.pas            ← All strings, prompts, pricing constants
```

### Engine Callbacks

The engine fires these events (all marshalled to the main thread via `TThread.Synchronize`):

| Event | When |
|---|---|
| `OnLog` | Every log message |
| `OnProgress` | Progress bar update |
| `OnStatus` | Status bar message |
| `OnIter` | Iteration status label |
| `OnDone` | Loop finished successfully |
| `OnError` | Exception during loop |
| `OnTokens` | Tokens used + estimated cost |

Because the engine only knows about callbacks, the same `LoopEngine` can run in a console application, a service, or an FMX Android app — just replace `uMain`.

---

## Prompts

Starting from v0.2, prompts are loaded from external markdown files placed next to the executable:

```
prompt_executor.md
prompt_reviewer.md
prompt_refine.md
```

If a file is missing, DelphiLoop falls back to built-in defaults in `LoopConsts.pas`. This means you can tune agent behavior without recompiling — just edit the file and run again.

The default prompts are inspired by [Andrej Karpathy's agent skill guidelines](https://github.com/forrestchang/andrej-karpathy-skills), adapted for non-interactive code generation agents:

**Executor** — states assumptions before writing, generates minimum working code, no speculative abstractions.

**Reviewer** — flags only real bugs in Delphi/Object Pascal context, ignores style and unrelated code, references exact method names.

**Refine** — touches only what the review explicitly listed. Every changed line traces to a specific issue.

---

## Getting Started

### Requirements

- **RAD Studio** 11 Alexandria or newer (tested on RAD Studio 13 Florence)
- **Windows** 10/11
- **Ollama** (optional, for local models) — [ollama.com](https://ollama.com)
- **OpenAI API key** (optional, for cloud models)
- **OpenRouter API key** (optional) — [openrouter.ai](https://openrouter.ai)

### Build

1. Clone the repository
2. Open `DelphiLoop.dpr` in RAD Studio
3. Build (`Shift+F9`)
4. Run

No third-party components. No GetIt packages. Pure VCL.

### First Run

On first launch, DelphiLoop creates a default `DelphiLoop.xml` config file next to the executable with three providers and six models pre-configured:

**Providers:**
- `Ollama (local)` — `http://localhost:11434`
- `OpenAI` — `https://api.openai.com`
- `OpenRouter` — `https://openrouter.ai/api`

**Models:**
- `qwen2.5-coder:7b` (Ollama)
- `llama3.1:8b` (Ollama)
- `gpt-4o` (OpenAI)
- `gpt-4o-mini` (OpenAI)
- `gpt-5` (OpenAI)
- `Qwen3 Coder` (OpenRouter)

To use OpenAI or OpenRouter models, open **Settings** and edit the provider to add your API key.

---

## Configuration

All configuration is stored in `DelphiLoop.xml` (same directory as the executable).

```xml
<DelphiLoop version="0.2">
  <Settings>
    <MaxIterations>4</MaxIterations>
    <ExecutorIdx>5</ExecutorIdx>
    <ReviewerIdx>2</ReviewerIdx>
  </Settings>
  <Providers>
    <Provider>
      <Name>OpenRouter</Name>
      <BaseURL>https://openrouter.ai/api</BaseURL>
      <APIKey>sk-or-...</APIKey>
      <Type>OpenAI</Type>
    </Provider>
  </Providers>
  <Models>
    <Model>
      <DisplayName>Qwen3 Coder  (OpenRouter)</DisplayName>
      <ModelID>qwen/qwen3-coder</ModelID>
      <ProviderIdx>2</ProviderIdx>
    </Model>
  </Models>
</DelphiLoop>
```

---

## Adding a Custom Provider

1. Click **Settings**
2. In the **Providers** section, click **+ add**
3. Enter Name, Base URL, API Key, and Type (`OpenAI / Compatible`)
4. Click **OK**
5. In the **Models** section, click **+ add**
6. Enter Display Name, Model ID, and select your provider
7. Click **OK** → **Close**

Settings are saved automatically on close.

---

## Model Recommendations

Based on experiments with Delphi code generation:

| Pair | Iterations | Quality | Cost |
|---|---|---|---|
| Qwen3 Coder → gpt-4o | ~2 | ★★★★★ | Low |
| gpt-4o-mini → gpt-4o | ~3 | ★★★★★ | Low |
| qwen2.5-coder:7b → gpt-4o | ~4 | ★★★ | Free* |
| gpt-4o → gpt-4o | ~2 | ★★★★★ | High |

**Best value:** `Qwen3 Coder` (OpenRouter) as Executor, `gpt-4o` as Reviewer — ~$0.01 per run.  
**Best quality:** `gpt-4o` as both.  
**Fully local (free):** `qwen2.5-coder:7b` as Executor, `llama3.1:8b` as Reviewer.

*Requires Ollama locally + OpenAI key for reviewer.

> More systematic benchmarks are coming in a future article.

---

## Token Pricing

Approximate prices used for cost estimation (per token):

| Model | Price |
|---|---|
| gpt-4o | ~$10.00 / 1M tokens |
| gpt-4o-mini | ~$0.375 / 1M tokens |

OpenRouter returns actual cost per request in the API response — visible in the log.

---

## Roadmap

- [ ] Per-model token pricing in config
- [ ] Pass original task to refine context
- [ ] API key encryption (Windows DPAPI)
- [ ] `ILoopEngine` interface + mock for testing
- [ ] RAG over `.pas` files — context-aware generation
- [ ] Benchmark mode — run same task N times, compare pairs
- [ ] Export results to file
- [ ] FMX Android port (engine is already platform-agnostic)

---

## Changelog

### v0.2
- **OpenRouter support** — added as a built-in provider; any OpenAI-compatible endpoint works out of the box
- **External prompts** — agent prompts moved to `prompt_executor.md`, `prompt_reviewer.md`, `prompt_refine.md`; built-in constants remain as fallback
- **Modernized prompt design** — prompts redesigned using principles from [Andrej Karpathy's agent skill guidelines](https://github.com/forrestchang/andrej-karpathy-skills): state assumptions before writing, minimum code only, surgical fixes in refine
- **Dropped C++ Builder** — DelphiLoop is Delphi-only; language selector removed from settings
- **Default model updated** — Qwen3 Coder 480B via OpenRouter is now the recommended executor

### v0.1
- Initial release
- Generate → review → refine loop
- Ollama + OpenAI support
- Persistent XML config, settings UI, token counter

---

## Why Delphi?

Because why not.

Delphi has a mature HTTP client, JSON parser, XML support, generics, anonymous methods, and threading primitives — everything needed to build an AI agent loop. The result is a single native `.exe`, no runtime, no dependencies, instant startup.

If you've been writing Delphi for years and think AI tooling is "not for you" — it is. One evening and you have a working agent.

---

## License

MIT — see [LICENSE](LICENSE)

---

## Author

Built by a senior Delphi developer who got curious about local LLMs one evening.

Follow the journey on [LinkedIn](https://www.linkedin.com/in/kusmin-ilia/) | [GitHub](https://github.com/rm3g25/)
