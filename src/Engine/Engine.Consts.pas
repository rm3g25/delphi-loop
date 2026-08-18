unit Engine.Consts;

{
  Shared engine constants: app identity, defaults, provider endpoints,
  protocol markers, built-in prompts, token pricing.
  Values are part of the wire/config protocol - renaming an identifier is
  free, changing a value is not.
}

interface

const
  // App
  AppTitle = 'DelphiLoop';
  AppVersion = '0.3';

  // Defaults. Executor/reviewer values are positions in the default model
  // list built by TLoopConfig.SetDefaults - reorder that list and these
  // point at different models.
  DefaultMaxIterations = 4;
  DefaultExecutorIndex = 5; // Qwen3 Coder (OpenRouter)
  DefaultReviewerIndex = 2; // gpt-4o

  // Default providers
  ProviderOllamaName = 'Ollama (local)';
  ProviderOllamaUrl = 'http://localhost:11434';
  ProviderOpenAIName = 'OpenAI';
  ProviderOpenAIUrl = 'https://api.openai.com';
  ProviderOpenAIKey = 'sk-YOUR-KEY-HERE';

  // OpenRouter (OpenAI-compatible)
  ProviderOpenRouterName = 'OpenRouter';
  ProviderOpenRouterUrl = 'https://openrouter.ai/api';
  ProviderOpenRouterKey = 'sk-YOUR-OPENROUTER-KEY-HERE';

  // Default models
  ModelQwenDisplay = 'qwen2.5-coder:7b  (local)';
  ModelQwenId = 'qwen2.5-coder:7b';
  ModelLlamaDisplay = 'llama3.1:8b  (local)';
  ModelLlamaId = 'llama3.1:8b';
  ModelGpt4oDisplay = 'gpt-4o  (OpenAI)';
  ModelGpt4oId = 'gpt-4o';
  ModelGpt4oMiniDisplay = 'gpt-4o-mini  (OpenAI)';
  ModelGpt4oMiniId = 'gpt-4o-mini';
  ModelGpt5Display = 'gpt-5  (OpenAI)';
  ModelGpt5Id = 'gpt-5';

  // OpenRouter models
  ModelQwen36Display = 'Qwen3 Coder  (OpenRouter)';
  ModelQwen36Id = 'qwen/qwen3-coder';

  // API paths
  OllamaGeneratePath = '/api/generate';
  OpenAIChatPath = '/v1/chat/completions';

  // API
  OpenAIMaxTokens = 2048;
  NoIssuesMarker = 'NO_ISSUES';

  // HTTP error prefix (returned by AskOllama / AskOpenAI on non-200)
  ErrorHttpPrefix = 'Error: ';

  // Markdown strip tokens
  MarkdownDelphi = '```delphi';
  MarkdownPascal = '```pascal';
  MarkdownGeneric = '```';

  // Prompts
  PromptExecutor =
    'You are a senior Delphi developer. ' +
    'Write clean, compilable Delphi / Object Pascal code for the task below. ' +
    'Do NOT add features not mentioned in the task. ' +
    'Reply with Delphi code ONLY. No markdown, no explanation.' + #10;

  PromptReviewer =
    'You are a strict Delphi code reviewer. ' +
    'Check ONLY: bugs, memory leaks, logic errors, compilation errors, bad practices. ' +
    'Do NOT suggest new features, thread safety, or anything not required by the original task. ' +
    'Do NOT add requirements that were not in the original task. ' +
    'Be specific — reference exact line or method names. ' +
    'If code correctly implements the task with no bugs, reply with exactly: NO_ISSUES' + #10 +
    'Code:' + #10;

  PromptRefine =
    'You are a senior Delphi developer. ' +
    'Fix ONLY the issues listed in the review below. ' +
    'Do NOT add new features or change working code. ' +
    'Reply with corrected Delphi / Object Pascal code ONLY. No markdown.' + #10;

  PromptRefineCodeLabel = 'Code:' + #10;
  PromptRefineReviewLabel = 'Review:' + #10;

  // Cost format
  CostFormat = '$0.0000';
  CostPrefix = '$';

  // Token pricing (per token, USD):
  // - gpt-4o: $5.00/1M input + $15.00/1M output ~ avg $10.00/1M
  // - gpt-4o-mini: $0.15/1M input + $0.60/1M output ~ avg $0.375/1M
  CostPerTokenGpt4o = 0.00001; // $10.00 per 1M tokens
  CostPerTokenGpt4oMini = 0.000000375; // $0.375 per 1M tokens

implementation

end.
