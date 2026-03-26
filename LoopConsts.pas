unit LoopConsts;

interface

const
  // App
  APP_TITLE   = 'DelphiLoop';
  APP_VERSION = '0.1';

  // Defaults
  DEFAULT_MAX_ITERATIONS   = 4;
  DEFAULT_EXECUTOR_INDEX   = 0;
  DEFAULT_REVIEWER_INDEX   = 2;

  // Default providers
  PROVIDER_OLLAMA_NAME     = 'Ollama (local)';
  PROVIDER_OLLAMA_URL      = 'http://localhost:11434';
  PROVIDER_OPENAI_NAME     = 'OpenAI';
  PROVIDER_OPENAI_URL      = 'https://api.openai.com';
  PROVIDER_OPENAI_KEY      = 'sk-YOUR-KEY-HERE';

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

  // API paths
  OLLAMA_GENERATE_PATH     = '/api/generate';
  OPENAI_CHAT_PATH         = '/v1/chat/completions';

  // API response fields
  OPENAI_DEFAULT_MAX_TOKENS= 2048;
  NO_ISSUES_MARKER         = 'NO_ISSUES';

  // Markdown strip tokens
  MARKDOWN_DELPHI          = '```delphi';
  MARKDOWN_PASCAL          = '```pascal';
  MARKDOWN_GENERIC         = '```';

  // Prompts
  PROMPT_EXECUTOR =
    'You are a senior Delphi developer. ' +
    'Write clean, compilable Delphi code for the task below. ' +
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
    'Reply with corrected Delphi code ONLY. No markdown.' + #10;

  PROMPT_REFINE_CODE_LABEL   = 'Code:' + #10;
  PROMPT_REFINE_REVIEW_LABEL = 'Review:' + #10;

  // UI status messages
  STATUS_READY       = 'Ready';
  STATUS_RUNNING     = 'Running...';
  STATUS_GENERATING  = 'Generating...';
  STATUS_DONE        = 'Done';
  STATUS_COPIED      = 'Copied to clipboard';
  STATUS_ERROR       = 'Error: ';
  STATS_FMT          = 'runs: %d  iter: %d  tokens: %d  cost: %s';

  // UI log messages
  LOG_EXECUTOR       = 'Executor : ';
  LOG_REVIEWER       = 'Reviewer : ';
  LOG_GENERATING     = 'Generating code...';
  LOG_GENERATED      = 'Generated (%d chars)';
  LOG_REFINED        = 'Refined (%d chars)';
  LOG_CODE_START     = '--- CODE ---';
  LOG_CODE_END       = '------------';
  LOG_REVIEW_HDR     = '=== REVIEW %d by %s ===';
  LOG_REFINE_HDR     = '=== REFINE %d by %s ===';
  LOG_REVIEW_PREFIX  = 'Review: ';
  LOG_PASSED         = 'Passed review after %d iteration(s)';
  LOG_MAX_ITER       = 'Max iterations reached — using last version';

  // UI iter status messages
  ITER_GENERATING    = 'Generating...';
  ITER_REVIEW        = 'Iteration %d/%d — Review...';
  ITER_REFINE        = 'Iteration %d/%d — Refining...';
  ITER_DONE          = 'Done';

  // UI final status
  STATUS_DONE_FMT    = 'Done — %d iteration(s)  |  %s -> %s';

  // Cost format
  COST_FORMAT        = '$0.0000';
  COST_PREFIX        = '$';



  // Token pricing (per token, USD)
  // gpt-4o: $5.00/1M input + $15.00/1M output ~ avg $10.00/1M
  // gpt-4o-mini: $0.15/1M input + $0.60/1M output ~ avg $0.375/1M
  COST_PER_TOKEN_GPT4O      = 0.00001;   // $10.00 per 1M tokens
  COST_PER_TOKEN_GPT4O_MINI = 0.000000375; // $0.375 per 1M tokens

implementation

end.
