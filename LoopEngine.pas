unit LoopEngine;

{
  DelphiLoop v0.3 — Engine with semantic typed events.

  Event contract (no raw text callbacks):
    OnThink  — internal engine thinking: model name + short status message.
                UI accumulates these per-phase and shows as collapsible bubbles.
    OnPhase  — phase transition: lpGenerating / lpReviewing / lpRefining.
                Carries iteration index and max so UI needs no counters.
    OnCode   — code is ready: AIteration=0 means initial draft, >0 means refined.
    OnReview — review is ready: AApproved signals verdict, no string parsing in UI.
    OnDone   — loop finished cleanly: carries final code + model names.
    OnError  — unhandled exception from the background thread.
    OnTokens — tokens used + cost after each API call.

  All Do* methods synchronize to the main thread via TThread.Synchronize,
  so UI handlers run on the main thread without extra wrapping.
}

interface

uses
  System.SysUtils, System.Classes, System.Threading, System.JSON,
  System.Net.HttpClient, System.Net.HttpClientComponent,
  System.Generics.Collections,
  LoopTypes, LoopConsts, LoopConfig, LoopPrompts;

type
  TLoopPhase = (lpGenerating, lpReviewing, lpRefining);

  TOnThinkEvent  = procedure(const AModel, AMsg: string) of object;
  TOnPhaseEvent  = procedure(APhase: TLoopPhase;
                             AIteration, AMaxIter: Integer) of object;
  TOnCodeEvent   = procedure(const ACode: string;
                             AIteration: Integer;
                             AIsDraft: Boolean) of object;
  TOnReviewEvent = procedure(const AReview: string;
                             AIteration: Integer;
                             AApproved: Boolean;
                             const AReviewer: string) of object;
  TOnDoneEvent   = procedure(const ACode: string;
                             AIterations: Integer;
                             const AExecutor, AReviewer: string) of object;
  TOnErrorEvent  = procedure(const AMsg: string) of object;
  TOnTokensEvent = procedure(ATokens: Integer; ACost: Double) of object;

  TLoopEngine = class
  private
    FProviders :array of TProviderConfig;
    FModels    :array of TModelConfig;
    FMaxIter   :Integer;

    FOnThink  :TOnThinkEvent;
    FOnPhase  :TOnPhaseEvent;
    FOnCode   :TOnCodeEvent;
    FOnReview :TOnReviewEvent;
    FOnDone   :TOnDoneEvent;
    FOnError  :TOnErrorEvent;
    FOnTokens :TOnTokensEvent;

    procedure DoThink(const AModel, AMsg: string);
    procedure DoPhase(APhase: TLoopPhase; AIteration, AMaxIter: Integer);
    procedure DoCode(const ACode: string; AIteration: Integer; AIsDraft: Boolean);
    procedure DoReview(const AReview: string; AIteration: Integer;
                       AApproved: Boolean; const AReviewer: string);
    procedure DoDone(const ACode: string; AIterations: Integer;
                     const AExecutor, AReviewer: string);
    procedure DoError(const AMsg: string);
    procedure DoTokens(ATokens: Integer; ACost: Double);

    function  AskOllama(const ABaseURL, AModelID, APrompt: string): string;
    function  AskOpenAI(const ABaseURL, AAPIKey, AModelID,
                        APrompt: string;
                        var ATokensUsed: Integer): string;
    function  AskModel(const AConfig: TModelConfig;
                       const APrompt: string;
                       var ATokensUsed: Integer): string;
    function  StripMarkdown(const ACode: string): string;

    procedure RunLoop(const ATask: string;
                      AExecutorIdx, AReviewerIdx: Integer);

  public
    constructor Create;

    procedure SetProviders(AConfig: TLoopConfig);
    procedure SetModels(AConfig: TLoopConfig);

    procedure Run(const ATask: string;
                  AExecutorIdx, AReviewerIdx, AMaxIter: Integer);

    property OnThink  :TOnThinkEvent  read FOnThink  write FOnThink;
    property OnPhase  :TOnPhaseEvent  read FOnPhase  write FOnPhase;
    property OnCode   :TOnCodeEvent   read FOnCode   write FOnCode;
    property OnReview :TOnReviewEvent read FOnReview write FOnReview;
    property OnDone   :TOnDoneEvent   read FOnDone   write FOnDone;
    property OnError  :TOnErrorEvent  read FOnError  write FOnError;
    property OnTokens :TOnTokensEvent read FOnTokens write FOnTokens;
  end;

implementation

// ===========================================================================
//  Constructor
// ===========================================================================

constructor TLoopEngine.Create;
begin
  inherited;
  FMaxIter := DEFAULT_MAX_ITERATIONS;
end;

// ===========================================================================
//  Config
// ===========================================================================

procedure TLoopEngine.SetProviders(AConfig: TLoopConfig);
var
  I: Integer;
begin
  SetLength(FProviders, AConfig.ProviderCount);
  for I := 0 to AConfig.ProviderCount - 1 do
    FProviders[I] := AConfig.GetProvider(I);
end;

procedure TLoopEngine.SetModels(AConfig: TLoopConfig);
var
  I: Integer;
begin
  SetLength(FModels, AConfig.ModelCount);
  for I := 0 to AConfig.ModelCount - 1 do
    FModels[I] := AConfig.GetModel(I);
end;

// ===========================================================================
//  Typed event dispatchers — all synchronize to the main thread
// ===========================================================================

procedure TLoopEngine.DoThink(const AModel, AMsg: string);
begin
  if Assigned(FOnThink) then
    TThread.Synchronize(nil, procedure
    begin
      FOnThink(AModel, AMsg);
    end);
end;

procedure TLoopEngine.DoPhase(APhase: TLoopPhase; AIteration, AMaxIter: Integer);
begin
  if Assigned(FOnPhase) then
    TThread.Synchronize(nil, procedure
    begin
      FOnPhase(APhase, AIteration, AMaxIter);
    end);
end;

procedure TLoopEngine.DoCode(const ACode: string; AIteration: Integer;
  AIsDraft: Boolean);
begin
  if Assigned(FOnCode) then
    TThread.Synchronize(nil, procedure
    begin
      FOnCode(ACode, AIteration, AIsDraft);
    end);
end;

procedure TLoopEngine.DoReview(const AReview: string; AIteration: Integer;
  AApproved: Boolean; const AReviewer: string);
begin
  if Assigned(FOnReview) then
    TThread.Synchronize(nil, procedure
    begin
      FOnReview(AReview, AIteration, AApproved, AReviewer);
    end);
end;

procedure TLoopEngine.DoDone(const ACode: string; AIterations: Integer;
  const AExecutor, AReviewer: string);
begin
  if Assigned(FOnDone) then
    TThread.Synchronize(nil, procedure
    begin
      FOnDone(ACode, AIterations, AExecutor, AReviewer);
    end);
end;

procedure TLoopEngine.DoError(const AMsg: string);
begin
  if Assigned(FOnError) then
    TThread.Synchronize(nil, procedure
    begin
      FOnError(AMsg);
    end);
end;

procedure TLoopEngine.DoTokens(ATokens: Integer; ACost: Double);
begin
  if Assigned(FOnTokens) then
    TThread.Synchronize(nil, procedure
    begin
      FOnTokens(ATokens, ACost);
    end);
end;

// ===========================================================================
//  Markdown strip
// ===========================================================================

function TLoopEngine.StripMarkdown(const ACode: string): string;
begin
  Result := ACode.Trim;
  if Result.StartsWith(MARKDOWN_DELPHI, True) then
    Result := Result.Substring(Length(MARKDOWN_DELPHI));
  if Result.StartsWith(MARKDOWN_PASCAL, True) then
    Result := Result.Substring(Length(MARKDOWN_PASCAL));
  if Result.StartsWith(MARKDOWN_GENERIC) then
    Result := Result.Substring(Length(MARKDOWN_GENERIC));
  if Result.EndsWith(MARKDOWN_GENERIC) then
    Result := Result.Substring(0, Result.Length - Length(MARKDOWN_GENERIC));
  Result := Result.Trim;
end;

// ===========================================================================
//  API calls
// ===========================================================================

function TLoopEngine.AskOllama(const ABaseURL, AModelID, APrompt: string): string;
var
  Client   :TNetHTTPClient;
  Response :IHTTPResponse;
  Body     :TStringStream;
  Request  :TJSONObject;
  Json     :TJSONObject;
begin
  Result := '';
  Client := TNetHTTPClient.Create(nil);
  try
    Request := TJSONObject.Create;
    try
      Request.AddPair('model',  AModelID);
      Request.AddPair('prompt', APrompt);
      Request.AddPair('stream', TJSONBool.Create(False));
      Body := TStringStream.Create(Request.ToJSON, TEncoding.UTF8);
      try
        Client.ContentType := 'application/json';
        Response := Client.Post(ABaseURL + OLLAMA_GENERATE_PATH, Body);
        if Response.StatusCode = 200 then
        begin
          Json := TJSONObject.ParseJSONValue(
            Response.ContentAsString) as TJSONObject;
          try
            Result := Trim(Json.GetValue<string>('response'));
          finally
            Json.Free;
          end;
        end
        else
          Result := ERROR_HTTP_PREFIX + Response.StatusCode.ToString;
      finally
        Body.Free;
      end;
    finally
      Request.Free;
    end;
  finally
    Client.Free;
  end;
end;

function TLoopEngine.AskOpenAI(const ABaseURL, AAPIKey, AModelID,
  APrompt: string; var ATokensUsed: Integer): string;
var
  Client   :TNetHTTPClient;
  Response :IHTTPResponse;
  Body     :TStringStream;
  Request  :TJSONObject;
  Messages :TJSONArray;
  Message  :TJSONObject;
  Json     :TJSONObject;
  Choices  :TJSONArray;
  Choice   :TJSONObject;
  Usage    :TJSONObject;
begin
  Result      := '';
  ATokensUsed := 0;
  Client := TNetHTTPClient.Create(nil);
  try
    Messages := TJSONArray.Create;
    Message  := TJSONObject.Create;
    Message.AddPair('role',    'user');
    Message.AddPair('content', APrompt);
    Messages.Add(Message);

    Request := TJSONObject.Create;
    try
      Request.AddPair('model',      AModelID);
      Request.AddPair('messages',   Messages);
      Request.AddPair('max_tokens', TJSONNumber.Create(OPENAI_MAX_TOKENS));

      Body := TStringStream.Create(Request.ToJSON, TEncoding.UTF8);
      try
        Client.ContentType := 'application/json';
        Client.CustomHeaders['Authorization'] := 'Bearer ' + AAPIKey;
        Response := Client.Post(ABaseURL + OPENAI_CHAT_PATH, Body);

        if Response.StatusCode = 200 then
        begin
          Json := TJSONObject.ParseJSONValue(
            Response.ContentAsString) as TJSONObject;
          try
            Choices := Json.GetValue<TJSONArray>('choices');
            Choice  := Choices.Items[0] as TJSONObject;
            Result  := Trim(
              Choice.GetValue<TJSONObject>('message')
                     .GetValue<string>('content'));
            Usage := Json.GetValue<TJSONObject>('usage');
            if Assigned(Usage) then
              ATokensUsed := Usage.GetValue<Integer>('total_tokens');
          finally
            Json.Free;
          end;
        end
        else
          Result := ERROR_HTTP_PREFIX + Response.StatusCode.ToString;
      finally
        Body.Free;
      end;
    finally
      Request.Free;
    end;
  finally
    Client.Free;
  end;
end;

function TLoopEngine.AskModel(const AConfig: TModelConfig;
  const APrompt: string; var ATokensUsed: Integer): string;
var
  Provider :TProviderConfig;
begin
  ATokensUsed := 0;
  Provider    := FProviders[AConfig.ProviderIdx];
  case Provider.Kind of
    ptOllama: Result := AskOllama(Provider.BaseURL,
                                   AConfig.ModelID, APrompt);
    ptOpenAI,
    ptCustom: Result := AskOpenAI(Provider.BaseURL, Provider.APIKey,
                                   AConfig.ModelID, APrompt, ATokensUsed);
  end;
end;

// ===========================================================================
//  Main loop — emits typed events, zero string parsing on the UI side
// ===========================================================================

procedure TLoopEngine.RunLoop(const ATask: string;
  AExecutorIdx, AReviewerIdx: Integer);
var
  Executor  :TModelConfig;
  Reviewer  :TModelConfig;
  Code      :string;
  Review    :string;
  Iteration :Integer;
  Approved  :Boolean;
  Tokens    :Integer;
begin
  Executor := FModels[AExecutorIdx];
  Reviewer := FModels[AReviewerIdx];

  // --- Generate initial draft ---
  DoPhase(lpGenerating, 0, FMaxIter);
  DoThink(Executor.DisplayName,
    'Executor : ' + Executor.DisplayName + #10 +
    'Reviewer : ' + Reviewer.DisplayName);

  Tokens := 0;
  Code := StripMarkdown(
    AskModel(Executor, GetExecutorPrompt + ATask, Tokens)
  );
  DoTokens(Tokens, Tokens * COST_PER_TOKEN_GPT4O);
  DoThink(Executor.DisplayName, Format('Generated %d chars', [Length(Code)]));
  DoCode(Code, 0, True);   // iteration 0 = draft

  Iteration := 0;
  Approved  := False;

  while (Iteration < FMaxIter) and not Approved do
  begin
    Inc(Iteration);

    // --- Review ---
    DoPhase(lpReviewing, Iteration, FMaxIter);
    DoThink(Reviewer.DisplayName, 'Reviewing...');

    Review := AskModel(Reviewer, GetReviewerPrompt + Code, Tokens);
    DoTokens(Tokens, Tokens * COST_PER_TOKEN_GPT4O);

    Approved := Pos(NO_ISSUES_MARKER, UpperCase(Review)) > 0;
    DoReview(Review, Iteration, Approved, Reviewer.DisplayName);

    if Approved then
      Break;

    if Iteration < FMaxIter then
    begin
      // --- Refine ---
      DoPhase(lpRefining, Iteration, FMaxIter);
      DoThink(Executor.DisplayName, 'Refining...');

      Code := StripMarkdown(
        AskModel(Executor,
          GetRefinePrompt                        +
          PROMPT_REFINE_CODE_LABEL   + Code   + #10 +
          PROMPT_REFINE_REVIEW_LABEL + Review,
          Tokens)
      );
      DoTokens(Tokens, Tokens * COST_PER_TOKEN_GPT4O);
      DoThink(Executor.DisplayName, Format('Refined %d chars', [Length(Code)]));
      DoCode(Code, Iteration, False);   // iteration > 0 = refined version
    end
    else
      DoThink(Reviewer.DisplayName,
        'Max iterations reached — using last version');
  end;

  DoDone(Code, Iteration, Executor.DisplayName, Reviewer.DisplayName);
end;

// ===========================================================================
//  Public entry point
// ===========================================================================

procedure TLoopEngine.Run(const ATask: string;
  AExecutorIdx, AReviewerIdx, AMaxIter: Integer);
begin
  FMaxIter := AMaxIter;
  TTask.Run(procedure
  begin
    try
      RunLoop(ATask, AExecutorIdx, AReviewerIdx);
    except
      on E: Exception do
        DoError(E.Message);
    end;
  end);
end;

end.
