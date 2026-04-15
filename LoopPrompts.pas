unit LoopPrompts;

interface

function GetExecutorPrompt : string;
function GetReviewerPrompt : string;
function GetRefinePrompt   : string;

implementation

uses
  System.SysUtils, System.Classes,
  LoopConsts;

const
  FILE_EXECUTOR = 'prompt_executor.md';
  FILE_REVIEWER = 'prompt_reviewer.md';
  FILE_REFINE   = 'prompt_refine.md';

function LoadFromFile(const AFileName : string) : string;
var
  Lines : TStringList;
  Path  : string;
begin
  Result := '';
  Path   := ExtractFilePath(ParamStr(0)) + AFileName;
  if not FileExists(Path) then Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path, TEncoding.UTF8);
    Result := Trim(Lines.Text);
  finally
    Lines.Free;
  end;
end;

function GetExecutorPrompt : string;
begin
  Result := LoadFromFile(FILE_EXECUTOR);
  if Result = '' then
    Result := PROMPT_EXECUTOR;
end;

function GetReviewerPrompt : string;
begin
  Result := LoadFromFile(FILE_REVIEWER);
  if Result = '' then
    Result := PROMPT_REVIEWER;
end;

function GetRefinePrompt : string;
begin
  Result := LoadFromFile(FILE_REFINE);
  if Result = '' then
    Result := PROMPT_REFINE;
end;

end.
