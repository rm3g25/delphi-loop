unit LoopEngine;

interface

uses
  System.SysUtils, System.Classes, System.Threading, System.JSON,
  System.Net.HttpClient, System.Net.HttpClientComponent,
  System.Generics.Collections,
  LoopTypes, LoopConsts, LoopConfig, LoopPrompts;

type
  TOnLogEvent      = procedure(const AMsg :string) of object;
  TOnProgressEvent = procedure(APosition, AMax :Integer) of object;
  TOnStatusEvent   = procedure(const AMsg :string) of object;
  TOnIterEvent     = procedure(const AMsg :string) of object;
  TOnDoneEvent     = procedure(const ACode :string;
                               AIterations :Integer;
                               const AExecutor, AReviewer :string) of object;
  TOnErrorEvent    = procedure(const AMsg :string) of object;
  TOnTokensEvent   = procedure(ATokens :Integer; ACost :Double) of object;

  TLoopEngine = class
  private
    FProviders :array of TProviderConfig;
    FModels    :array of TModelConfig;
    FMaxIter   :Integer;

    FOnLog      :TOnLogEvent;
    FOnProgress :TOnProgressEvent;
    FOnStatus   :TOnStatusEvent;
    FOnIter     :TOnIterEvent;
    FOnDone     :TOnDoneEvent;
    FOnError    :TOnErrorEvent;
    FOnTokens   :TOnTokensEvent;

    procedure DoLog(const AMsg :string);
    procedure DoProgress(APosition, AMax :Integer);
    procedure DoStatus(const AMsg :string);
    procedure DoIter(const AMsg :string);
    procedure DoDone(const ACode :string; AIterations :Integer;
                     const AExecutor, AReviewer :string);
    procedure DoError(const AMsg :string);
    procedure DoTokens(ATokens :Integer; ACost :Double);

    function  AskOllama(const ABaseURL, AModelID, APrompt :string) :string;
    function  AskOpenAI(const ABaseURL, AAPIKey, AModelID,
                        APrompt :string;
                        var ATokensUsed :Integer) :string;
    function  AskModel(const AConfig :TModelConfig;
                       const APrompt :string;
                       var ATokensUsed :Integer) :string;
    function  StripMarkdown(const ACode :string) :string;

    procedure RunLoop(const ATask :string;
                      AExecutorIdx, AReviewerIdx :Integer);

  public
    constructor Create;

    procedure SetProviders(AConfig :TLoopConfig);
    procedure SetModels(AConfig :TLoopConfig);

    procedure Run(const ATask :string;
                  AExecutorIdx, AReviewerIdx, AMaxIter :Integer);

    property OnLog      :TOnLogEvent      read FOnLog      write FOnLog;
    property OnProgress :TOnProgressEvent read FOnProgress write FOnProgress;
    property OnStatus   :TOnStatusEvent   read FOnStatus   write FOnStatus;
    property OnIter     :TOnIterEvent     read FOnIter     write FOnIter;
    property OnDone     :TOnDoneEvent     read FOnDone     write FOnDone;
    property OnError    :TOnErrorEvent    read FOnError    write FOnError;
    property OnTokens   :TOnTokensEvent   read FOnTokens   write FOnTokens;
  end;

implementation

constructor TLoopEngine.Create;
begin
  inherited;
  FMaxIter := DEFAULT_MAX_ITERATIONS;
end;

procedure TLoopEngine.SetProviders(AConfig :TLoopConfig);
var
  I :Integer;
begin
  SetLength(FProviders, AConfig.ProviderCount);
  for I := 0 to AConfig.ProviderCount - 1 do
    FProviders[I] := AConfig.GetProvider(I);
end;

procedure TLoopEngine.SetModels(AConfig :TLoopConfig);
var
  I :Integer;
begin
  SetLength(FModels, AConfig.ModelCount);
  for I := 0 to AConfig.ModelCount - 1 do
    FModels[I] := AConfig.GetModel(I);
end;

procedure TLoopEngine.DoLog(const AMsg :string);
begin
  if Assigned(FOnLog) then
    TThread.Synchronize(nil, procedure
    begin
      FOnLog(AMsg);
    end);
end;

procedure TLoopEngine.DoProgress(APosition, AMax :Integer);
begin
  if Assigned(FOnProgress) then
    TThread.Synchronize(nil, procedure
    begin
      FOnProgress(APosition, AMax);
    end);
end;

procedure TLoopEngine.DoStatus(const AMsg :string);
begin
  if Assigned(FOnStatus) then
    TThread.Synchronize(nil, procedure
    begin
      FOnStatus(AMsg);
    end);
end;

procedure TLoopEngine.DoIter(const AMsg :string);
begin
  if Assigned(FOnIter) then
    TThread.Synchronize(nil, procedure
    begin
      FOnIter(AMsg);
    end);
end;

procedure TLoopEngine.DoDone(const ACode :string; AIterations :Integer;
                              const AExecutor, AReviewer :string);
begin
  if Assigned(FOnDone) then
    TThread.Synchronize(nil, procedure
    begin
      FOnDone(ACode, AIterations, AExecutor, AReviewer);
    end);
end;

procedure TLoopEngine.DoTokens(ATokens :Integer; ACost :Double);
begin
  if Assigned(FOnTokens) then
    TThread.Synchronize(nil, procedure
    begin
      FOnTokens(ATokens, ACost);
    end);
end;

procedure TLoopEngine.DoError(const AMsg :string);
begin
  if Assigned(FOnError) then
    TThread.Synchronize(nil, procedure
    begin
      FOnError(AMsg);
    end);
end;

function TLoopEngine.StripMarkdown(const ACode :string) :string;
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

function TLoopEngine.AskOllama(const ABaseURL, AModelID, APrompt :string) :string;
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
      Request.AddPair('model', AModelID);
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
          Result := STATUS_ERROR + Response.StatusCode.ToString;
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
                                APrompt :string;
                                var ATokensUsed :Integer) :string;
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
    Message.AddPair('role', 'user');
    Message.AddPair('content', APrompt);
    Messages.Add(Message);

    Request := TJSONObject.Create;
    try
      Request.AddPair('model', AModelID);
      Request.AddPair('messages', Messages);
      Request.AddPair('max_tokens', TJSONNumber.Create(OPENAI_MAX_TOKENS));

      Body := TStringStream.Create(Request.ToJSON, TEncoding.UTF8);
      try
        Client.ContentType := 'application/json';
        Client.CustomHeaders['Authorization'] := 'Bearer ' + AAPIKey;
        DoLog('POST: ' + ABaseURL + OPENAI_CHAT_PATH);
        Response := Client.Post(ABaseURL + OPENAI_CHAT_PATH, Body);
        DoLog('Response: ' + Response.ContentAsString);

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
          Result := STATUS_ERROR + Response.StatusCode.ToString;
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

function TLoopEngine.AskModel(const AConfig :TModelConfig;
                               const APrompt :string;
                               var ATokensUsed :Integer) :string;
var
  Provider :TProviderConfig;
begin
  ATokensUsed := 0;
  Provider := FProviders[AConfig.ProviderIdx];
  case Provider.Kind of
    ptOllama: Result := AskOllama(Provider.BaseURL,
                                   AConfig.ModelID, APrompt);
    ptOpenAI,
    ptCustom: Result := AskOpenAI(Provider.BaseURL, Provider.APIKey,
                                   AConfig.ModelID, APrompt,
                                   ATokensUsed);
  end;
end;

procedure TLoopEngine.RunLoop(const ATask :string;
                               AExecutorIdx, AReviewerIdx :Integer);
var
  Executor  :TModelConfig;
  Reviewer  :TModelConfig;
  Code      :string;
  Review    :string;
  Iteration :Integer;
  Done      :Boolean;
  Tokens    :Integer;
begin
  Executor := FModels[AExecutorIdx];
  Reviewer := FModels[AReviewerIdx];

  DoLog(LOG_EXECUTOR + Executor.DisplayName);
  DoLog(LOG_REVIEWER + Reviewer.DisplayName);
  DoLog('');

  DoIter(ITER_GENERATING);
  DoLog(LOG_GENERATING);

  Tokens := 0;
  Code := StripMarkdown(
    AskModel(Executor, GetExecutorPrompt + ATask, Tokens)
  );
  DoTokens(Tokens, Tokens * COST_PER_TOKEN_GPT4O);

  DoLog(Format(LOG_GENERATED, [Length(Code)]));
  DoLog(LOG_CODE_START);
  DoLog(Code);
  DoLog(LOG_CODE_END);
  DoProgress(1, FMaxIter * 2);

  Iteration := 0;
  Done      := False;

  while (Iteration < FMaxIter) and not Done do
  begin
    Inc(Iteration);
    DoIter(Format(ITER_REVIEW, [Iteration, FMaxIter]));
    DoLog('');
    DoLog(Format(LOG_REVIEW_HDR, [Iteration, Reviewer.DisplayName]));

    Review := AskModel(Reviewer, GetReviewerPrompt + Code, Tokens);
    DoTokens(Tokens, Tokens * COST_PER_TOKEN_GPT4O);

    DoLog(LOG_REVIEW_PREFIX + Review);
    DoProgress(Iteration * 2, FMaxIter * 2);

    if Pos(NO_ISSUES_MARKER, UpperCase(Review)) > 0 then
    begin
      Done := True;
      DoLog('');
      DoLog(Format(LOG_PASSED, [Iteration]));
    end
    else if Iteration < FMaxIter then
    begin
      DoIter(Format(ITER_REFINE, [Iteration, FMaxIter]));
      DoLog('');
      DoLog(Format(LOG_REFINE_HDR, [Iteration, Executor.DisplayName]));

      Code := StripMarkdown(
        AskModel(Executor,
          GetRefinePrompt +
          PROMPT_REFINE_CODE_LABEL   + Code   + #10 +
          PROMPT_REFINE_REVIEW_LABEL + Review,
          Tokens)
      );
      DoTokens(Tokens, Tokens * COST_PER_TOKEN_GPT4O);

      DoLog(Format(LOG_REFINED, [Length(Code)]));
      DoLog(LOG_CODE_START);
      DoLog(Code);
      DoLog(LOG_CODE_END);
    end
    else
      DoLog(LOG_MAX_ITER);
  end;

  DoProgress(FMaxIter * 2, FMaxIter * 2);
  DoDone(Code, Iteration, Executor.DisplayName, Reviewer.DisplayName);
end;

procedure TLoopEngine.Run(const ATask :string;
                           AExecutorIdx, AReviewerIdx, AMaxIter :Integer);
begin
  FMaxIter := AMaxIter;
  DoStatus(STATUS_RUNNING);

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
