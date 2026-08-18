unit Engine.Prompts;

{
  Agent prompts with external override.
  Each prompt is loaded from a markdown file next to the executable; when the
  file is missing or empty, the built-in default from Engine.Consts is used.
  File names are user-facing contract documented in the README - frozen.
}

interface

function GetExecutorPrompt: string;
function GetReviewerPrompt: string;
function GetRefinePrompt: string;

implementation

uses
  System.SysUtils,
  System.Classes,
  Engine.Consts;

const
  // Override file names - documented in the README, values are frozen.
  ExecutorPromptFile = 'prompt_executor.md';
  ReviewerPromptFile = 'prompt_reviewer.md';
  RefinePromptFile = 'prompt_refine.md';

function LoadPromptFile(const AFileName: string): string;
var
  Path: string;
  Lines: TStringList;
begin
  Result := '';
  Path := ExtractFilePath(ParamStr(0)) + AFileName;
  if not FileExists(Path) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path, TEncoding.UTF8);
    Result := Trim(Lines.Text);
  finally
    Lines.Free;
  end;
end;

function GetPromptOrDefault(const AFileName, ADefault: string): string;
begin
  Result := LoadPromptFile(AFileName);
  if Result = '' then
    Result := ADefault;
end;

function GetExecutorPrompt: string;
begin
  Result := GetPromptOrDefault(ExecutorPromptFile, PromptExecutor);
end;

function GetReviewerPrompt: string;
begin
  Result := GetPromptOrDefault(ReviewerPromptFile, PromptReviewer);
end;

function GetRefinePrompt: string;
begin
  Result := GetPromptOrDefault(RefinePromptFile, PromptRefine);
end;

end.
