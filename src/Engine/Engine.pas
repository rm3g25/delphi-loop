unit Engine;

{
  The agent loop engine with semantic typed events.

  Event contract (no raw text callbacks):
  - OnThink: internal engine thinking, model name + short status message;
    the UI accumulates these per-phase and shows them as collapsible bubbles.
  - OnPhase: phase transition (lpGenerating / lpReviewing / lpRefining);
    carries iteration index and max so the UI needs no counters.
  - OnCode: code is ready; AIteration = 0 means initial draft, > 0 refined.
  - OnReview: review is ready; AApproved signals the verdict, no string
    parsing on the UI side.
  - OnDone: loop finished cleanly; carries final code + model names.
  - OnError: unhandled exception from the background thread.
  - OnTokens: tokens used + cost after each API call.

  All Do* dispatchers synchronize to the main thread via TThread.Synchronize,
  so UI handlers run on the main thread without extra wrapping.
}

interface

uses
  Engine.Types,
  Engine.Config;

type
  TLoopPhase = (lpGenerating, lpReviewing, lpRefining);

  TOnThinkEvent = procedure(const AModel, AMessage: string) of object;
  TOnPhaseEvent = procedure(APhase: TLoopPhase;
    AIteration, AMaxIterations: Integer) of object;
  TOnCodeEvent = procedure(const ACode: string; AIteration: Integer;
    AIsDraft: Boolean) of object;
  TOnReviewEvent = procedure(const AReview: string; AIteration: Integer;
    AApproved: Boolean; const AReviewer: string) of object;
  TOnDoneEvent = procedure(const ACode: string; AIterations: Integer;
    const AExecutor, AReviewer: string) of object;
  TOnErrorEvent = procedure(const AMessage: string) of object;
  TOnTokensEvent = procedure(ATokens: Integer; ACost: Double) of object;

  TLoopEngine = class
  private
    FProviders: array of TProviderConfig;
    FModels: array of TModelConfig;
    FMaxIterations: Integer;

    FOnThink: TOnThinkEvent;
    FOnPhase: TOnPhaseEvent;
    FOnCode: TOnCodeEvent;
    FOnReview: TOnReviewEvent;
    FOnDone: TOnDoneEvent;
    FOnError: TOnErrorEvent;
    FOnTokens: TOnTokensEvent;

    procedure DoThink(const AModel, AMessage: string);
    procedure DoPhase(APhase: TLoopPhase; AIteration, AMaxIterations: Integer);
    procedure DoCode(const ACode: string; AIteration: Integer; AIsDraft: Boolean);
    procedure DoReview(const AReview: string; AIteration: Integer;
      AApproved: Boolean; const AReviewer: string);
    procedure DoDone(const ACode: string; AIterations: Integer;
      const AExecutor, AReviewer: string);
    procedure DoError(const AMessage: string);
    procedure DoTokens(ATokens: Integer; ACost: Double);

    function AskModel(const AConfig: TModelConfig; const APrompt: string;
      var ATokensUsed: Integer): string;

    procedure RunLoop(const ATask: string; AExecutorIndex, AReviewerIndex: Integer);
  public
    constructor Create;

    procedure SetProviders(AConfig: TLoopConfig);
    procedure SetModels(AConfig: TLoopConfig);

    procedure Run(const ATask: string;
      AExecutorIndex, AReviewerIndex, AMaxIterations: Integer);

    property OnThink: TOnThinkEvent read FOnThink write FOnThink;
    property OnPhase: TOnPhaseEvent read FOnPhase write FOnPhase;
    property OnCode: TOnCodeEvent read FOnCode write FOnCode;
    property OnReview: TOnReviewEvent read FOnReview write FOnReview;
    property OnDone: TOnDoneEvent read FOnDone write FOnDone;
    property OnError: TOnErrorEvent read FOnError write FOnError;
    property OnTokens: TOnTokensEvent read FOnTokens write FOnTokens;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.JSON,
  // Inline-support only: TJSONValue.GetValue<T> cannot be expanded without it
  // (compiler hint H2443). Referenced by no symbol here - do not "clean up".
  System.Generics.Collections,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  Engine.Consts,
  Engine.Prompts;

// ===========================================================================
//  Model API transport - free functions, no engine state involved
// ===========================================================================

// Posts ARequestJson to AUrl. An empty AApiKey means no Authorization header.
function PostJson(const AUrl, ARequestJson: string;
  const AApiKey: string = ''): IHTTPResponse;
var
  Client: TNetHTTPClient;
  Body: TStringStream;
begin
  Client := nil;
  Body := nil;
  try
    Client := TNetHTTPClient.Create(nil);
    Client.ContentType := 'application/json';
    if AApiKey <> '' then
      Client.CustomHeaders['Authorization'] := 'Bearer ' + AApiKey;

    Body := TStringStream.Create(ARequestJson, TEncoding.UTF8);
    Result := Client.Post(AUrl, Body);
  finally
    Body.Free;
    Client.Free;
  end;
end;

function BuildOllamaRequest(const AModelId, APrompt: string): string;
var
  Request: TJSONObject;
begin
  Request := TJSONObject.Create;
  try
    Request.AddPair('model', AModelId);
    Request.AddPair('prompt', APrompt);
    Request.AddPair('stream', TJSONBool.Create(False));

    Result := Request.ToJSON;
  finally
    Request.Free;
  end;
end;

function BuildOpenAIRequest(const AModelId, APrompt: string): string;
var
  Request: TJSONObject;
  Messages: TJSONArray;
  Message: TJSONObject;
begin
  Request := TJSONObject.Create;
  try
    // Every Create is handed to an owner on the next line, so the single
    // finally on Request frees the whole tree.
    Request.AddPair('model', AModelId);

    Messages := TJSONArray.Create;
    Request.AddPair('messages', Messages);
    Message := TJSONObject.Create;
    Messages.Add(Message);
    Message.AddPair('role', 'user');
    Message.AddPair('content', APrompt);

    Request.AddPair('max_tokens', TJSONNumber.Create(OpenAIMaxTokens));

    Result := Request.ToJSON;
  finally
    Request.Free;
  end;
end;

function ParseOllamaResponse(const AContent: string): string;
var
  Json: TJSONObject;
begin
  Json := TJSONObject.ParseJSONValue(AContent) as TJSONObject;
  try
    Result := Trim(Json.GetValue<string>('response'));
  finally
    Json.Free;
  end;
end;

function ParseOpenAIResponse(const AContent: string;
  var ATokensUsed: Integer): string;
var
  Json: TJSONObject;
  Choice: TJSONObject;
  Usage: TJSONObject;
begin
  Json := TJSONObject.ParseJSONValue(AContent) as TJSONObject;
  try
    Choice := Json.GetValue<TJSONArray>('choices').Items[0] as TJSONObject;
    Result := Trim(Choice.GetValue<TJSONObject>('message').GetValue<string>('content'));

    Usage := Json.GetValue<TJSONObject>('usage');
    if Assigned(Usage) then
      ATokensUsed := Usage.GetValue<Integer>('total_tokens');
  finally
    Json.Free;
  end;
end;

function AskOllama(const ABaseUrl, AModelId, APrompt: string): string;
var
  Response: IHTTPResponse;
begin
  Response := PostJson(ABaseUrl + OllamaGeneratePath,
    BuildOllamaRequest(AModelId, APrompt));
  if Response.StatusCode <> 200 then
    Exit(ErrorHttpPrefix + Response.StatusCode.ToString);
  Result := ParseOllamaResponse(Response.ContentAsString);
end;

function AskOpenAI(const ABaseUrl, AApiKey, AModelId, APrompt: string;
  var ATokensUsed: Integer): string;
var
  Response: IHTTPResponse;
begin
  ATokensUsed := 0;
  Response := PostJson(ABaseUrl + OpenAIChatPath,
    BuildOpenAIRequest(AModelId, APrompt), AApiKey);
  if Response.StatusCode <> 200 then
    Exit(ErrorHttpPrefix + Response.StatusCode.ToString);
  Result := ParseOpenAIResponse(Response.ContentAsString, ATokensUsed);
end;

// Strips a leading ```delphi / ```pascal / ``` fence and a trailing ``` fence.
function StripMarkdown(const ACode: string): string;
begin
  Result := ACode.Trim;
  if Result.StartsWith(MarkdownDelphi, True) then
    Result := Result.Substring(Length(MarkdownDelphi));
  if Result.StartsWith(MarkdownPascal, True) then
    Result := Result.Substring(Length(MarkdownPascal));
  if Result.StartsWith(MarkdownGeneric) then
    Result := Result.Substring(Length(MarkdownGeneric));

  if Result.EndsWith(MarkdownGeneric) then
    Result := Result.Substring(0, Result.Length - Length(MarkdownGeneric));

  Result := Result.Trim;
end;

// ===========================================================================
//  TLoopEngine - lifecycle and config
// ===========================================================================

constructor TLoopEngine.Create;
begin
  inherited;
  FMaxIterations := DefaultMaxIterations;
end;

procedure TLoopEngine.SetProviders(AConfig: TLoopConfig);
begin
  SetLength(FProviders, AConfig.ProviderCount);
  for var i := 0 to AConfig.ProviderCount - 1 do
    FProviders[i] := AConfig.GetProvider(i);
end;

procedure TLoopEngine.SetModels(AConfig: TLoopConfig);
begin
  SetLength(FModels, AConfig.ModelCount);
  for var i := 0 to AConfig.ModelCount - 1 do
    FModels[i] := AConfig.GetModel(i);
end;

// ===========================================================================
//  Typed event dispatchers - all synchronize to the main thread
// ===========================================================================

procedure TLoopEngine.DoThink(const AModel, AMessage: string);
begin
  if not Assigned(FOnThink) then
    Exit;
  TThread.Synchronize(nil, procedure
  begin
    FOnThink(AModel, AMessage);
  end);
end;

procedure TLoopEngine.DoPhase(APhase: TLoopPhase;
  AIteration, AMaxIterations: Integer);
begin
  if not Assigned(FOnPhase) then
    Exit;
  TThread.Synchronize(nil, procedure
  begin
    FOnPhase(APhase, AIteration, AMaxIterations);
  end);
end;

procedure TLoopEngine.DoCode(const ACode: string; AIteration: Integer;
  AIsDraft: Boolean);
begin
  if not Assigned(FOnCode) then
    Exit;
  TThread.Synchronize(nil, procedure
  begin
    FOnCode(ACode, AIteration, AIsDraft);
  end);
end;

procedure TLoopEngine.DoReview(const AReview: string; AIteration: Integer;
  AApproved: Boolean; const AReviewer: string);
begin
  if not Assigned(FOnReview) then
    Exit;
  TThread.Synchronize(nil, procedure
  begin
    FOnReview(AReview, AIteration, AApproved, AReviewer);
  end);
end;

procedure TLoopEngine.DoDone(const ACode: string; AIterations: Integer;
  const AExecutor, AReviewer: string);
begin
  if not Assigned(FOnDone) then
    Exit;
  TThread.Synchronize(nil, procedure
  begin
    FOnDone(ACode, AIterations, AExecutor, AReviewer);
  end);
end;

procedure TLoopEngine.DoError(const AMessage: string);
begin
  if not Assigned(FOnError) then
    Exit;
  TThread.Synchronize(nil, procedure
  begin
    FOnError(AMessage);
  end);
end;

procedure TLoopEngine.DoTokens(ATokens: Integer; ACost: Double);
begin
  if not Assigned(FOnTokens) then
    Exit;
  TThread.Synchronize(nil, procedure
  begin
    FOnTokens(ATokens, ACost);
  end);
end;

// ===========================================================================
//  Model dispatch
// ===========================================================================

function TLoopEngine.AskModel(const AConfig: TModelConfig; const APrompt: string;
  var ATokensUsed: Integer): string;
var
  Provider: TProviderConfig;
begin
  ATokensUsed := 0;
  Provider := FProviders[AConfig.ProviderIndex];

  case Provider.Kind of
    ptOllama:
      Result := AskOllama(Provider.BaseUrl, AConfig.ModelId, APrompt);
    ptOpenAI, ptCustom:
      Result := AskOpenAI(Provider.BaseUrl, Provider.ApiKey, AConfig.ModelId,
        APrompt, ATokensUsed);
  end;
end;

// ===========================================================================
//  Main loop - emits typed events, zero string parsing on the UI side
// ===========================================================================

procedure TLoopEngine.RunLoop(const ATask: string;
  AExecutorIndex, AReviewerIndex: Integer);
var
  Executor: TModelConfig;
  Reviewer: TModelConfig;
  Code: string;
  Review: string;
  Iteration: Integer;
  Approved: Boolean;
  Tokens: Integer;
begin
  Executor := FModels[AExecutorIndex];
  Reviewer := FModels[AReviewerIndex];

  // --- Initial draft ---
  DoPhase(lpGenerating, 0, FMaxIterations);
  DoThink(Executor.DisplayName,
    'Executor : ' + Executor.DisplayName + #10 +
    'Reviewer : ' + Reviewer.DisplayName);

  Tokens := 0;
  Code := StripMarkdown(AskModel(Executor, GetExecutorPrompt + ATask, Tokens));
  DoTokens(Tokens, Tokens * CostPerTokenGpt4o);
  DoThink(Executor.DisplayName, Format('Generated %d chars', [Length(Code)]));
  DoCode(Code, 0, True); // iteration 0 = draft

  Iteration := 0;
  Approved := False;

  while (Iteration < FMaxIterations) and not Approved do
  begin
    Inc(Iteration);

    // --- Review ---
    DoPhase(lpReviewing, Iteration, FMaxIterations);
    DoThink(Reviewer.DisplayName, 'Reviewing...');

    Review := AskModel(Reviewer, GetReviewerPrompt + Code, Tokens);
    DoTokens(Tokens, Tokens * CostPerTokenGpt4o);

    Approved := Pos(NoIssuesMarker, UpperCase(Review)) > 0;
    DoReview(Review, Iteration, Approved, Reviewer.DisplayName);

    if Approved then
      Break;

    if Iteration < FMaxIterations then
    begin
      // --- Refine ---
      DoPhase(lpRefining, Iteration, FMaxIterations);
      DoThink(Executor.DisplayName, 'Refining...');

      Code := StripMarkdown(AskModel(Executor,
        GetRefinePrompt +
        PromptRefineCodeLabel + Code + #10 +
        PromptRefineReviewLabel + Review,
        Tokens));
      DoTokens(Tokens, Tokens * CostPerTokenGpt4o);
      DoThink(Executor.DisplayName, Format('Refined %d chars', [Length(Code)]));
      DoCode(Code, Iteration, False); // iteration > 0 = refined version
    end
    else
      DoThink(Reviewer.DisplayName, 'Max iterations reached — using last version');
  end;

  DoDone(Code, Iteration, Executor.DisplayName, Reviewer.DisplayName);
end;

// ===========================================================================
//  Public entry point
// ===========================================================================

procedure TLoopEngine.Run(const ATask: string;
  AExecutorIndex, AReviewerIndex, AMaxIterations: Integer);
begin
  FMaxIterations := AMaxIterations;

  // Broad catch at the top of the background task is deliberate: without it
  // an exception in the loop dies silently.
  TTask.Run(procedure
  begin
    try
      RunLoop(ATask, AExecutorIndex, AReviewerIndex);
    except
      on E: Exception do
        DoError(E.Message);
    end;
  end);
end;

end.
