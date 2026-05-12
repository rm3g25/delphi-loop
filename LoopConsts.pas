unit LoopConsts;

interface

const
  // App
  APP_TITLE   = 'DelphiLoop';
  APP_VERSION = '0.3';

  // Defaults
  DEFAULT_MAX_ITERATIONS   = 4;
  DEFAULT_EXECUTOR_INDEX   = 5;  // Qwen3 Coder (OpenRouter)
  DEFAULT_REVIEWER_INDEX   = 2;  // gpt-4o

  // Default providers
  PROVIDER_OLLAMA_NAME     = 'Ollama (local)';
  PROVIDER_OLLAMA_URL      = 'http://localhost:11434';
  PROVIDER_OPENAI_NAME     = 'OpenAI';
  PROVIDER_OPENAI_URL      = 'https://api.openai.com';
  PROVIDER_OPENAI_KEY      = 'sk-YOUR-KEY-HERE';

  // OpenRouter (OpenAI-compatible)
  PROVIDER_OPENROUTER_NAME = 'OpenRouter';
  PROVIDER_OPENROUTER_URL  = 'https://openrouter.ai/api';
  PROVIDER_OPENROUTER_KEY  = 'sk-YOUR-OPENROUTER-KEY-HERE';

  // Default models
  MODEL_QWEN_DISPLAY       = 'qwen2.5-coder:7b  (local)';
  MODEL_QWEN_ID            = 'qwen2.5-coder:7b';
  MODEL_LLAMA_DISPLAY      = 'llama3.1:8b  (local)';
  MODEL_LLAMA_ID           = 'llama3.1:8b';
  MODEL_GPT4O_DISPLAY      = 'gpt-4o  (OpenAI)';
  MODEL_GPT4O_ID           = 'gpt-4o';
  MODEL_GPT4O_MINI_DISPLAY = 'gpt-4o-mini  (OpenAI)';
  MODEL_GPT4O_MINI_ID      = 'gpt-4o-mini';
  MODEL_GPT5_DISPLAY       = 'gpt-5  (OpenAI)';
  MODEL_GPT5_ID            = 'gpt-5';

  // OpenRouter models
  MODEL_QWEN36_DISPLAY     = 'Qwen3 Coder  (OpenRouter)';
  MODEL_QWEN36_ID          = 'qwen/qwen3-coder';

  // API paths
  OLLAMA_GENERATE_PATH     = '/api/generate';
  OPENAI_CHAT_PATH         = '/v1/chat/completions';

  // API
  OPENAI_MAX_TOKENS        = 2048;
  NO_ISSUES_MARKER         = 'NO_ISSUES';

  // HTTP error prefix (returned by AskOllama / AskOpenAI on non-200)
  ERROR_HTTP_PREFIX        = 'Error: ';

  // Markdown strip tokens
  MARKDOWN_DELPHI          = '```delphi';
  MARKDOWN_PASCAL          = '```pascal';
  MARKDOWN_GENERIC         = '```';

  // Prompts
  PROMPT_EXECUTOR =
    'You are a senior Delphi developer. ' +
    'Write clean, compilable Delphi / Object Pascal code for the task below. ' +
    'Do NOT add features not mentioned in the task. ' +
    'Reply with Delphi code ONLY. No markdown, no explanation.' + #10;

  PROMPT_REVIEWER =
    'You are a strict Delphi code reviewer. ' +
    'Check ONLY: bugs, memory leaks, logic errors, compilation errors, bad practices. ' +
    'Do NOT suggest new features, thread safety, or anything not required by the original task. ' +
    'Do NOT add requirements that were not in the original task. ' +
    'Be specific — reference exact line or method names. ' +
    'If code correctly implements the task with no bugs, reply with exactly: NO_ISSUES' + #10 +
    'Code:' + #10;

  PROMPT_REFINE =
    'You are a senior Delphi developer. ' +
    'Fix ONLY the issues listed in the review below. ' +
    'Do NOT add new features or change working code. ' +
    'Reply with corrected Delphi / Object Pascal code ONLY. No markdown.' + #10;

  PROMPT_REFINE_CODE_LABEL   = 'Code:' + #10;
  PROMPT_REFINE_REVIEW_LABEL = 'Review:' + #10;

  // Cost format
  COST_FORMAT        = '$0.0000';
  COST_PREFIX        = '$';

  // Token pricing (per token, USD)
  // gpt-4o:      $5.00/1M input + $15.00/1M output ~ avg $10.00/1M
  // gpt-4o-mini: $0.15/1M input +  $0.60/1M output ~ avg  $0.375/1M
  COST_PER_TOKEN_GPT4O      = 0.00001;      // $10.00 per 1M tokens
  COST_PER_TOKEN_GPT4O_MINI = 0.000000375;  // $0.375 per 1M tokens

implementation

end.
