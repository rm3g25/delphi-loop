unit LoopConfig;

// TODO v0.2: encrypt API keys using Windows DPAPI (CryptProtectData)

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  System.Generics.Collections,
  Xml.XMLDoc, Xml.XMLIntf,
  LoopTypes,
  LoopConsts;

type
  TLoopSettings = record
    MaxIterations : Integer;
    Language      : string;
    ExecutorIdx   : Integer;
    ReviewerIdx   : Integer;
  end;

  TLoopConfig = class
  private
    FSettings  : TLoopSettings;
    FProviders : TList<TProviderConfig>;
    FModels    : TList<TModelConfig>;

  public
    constructor Create;
    destructor  Destroy; override;

    procedure SetDefaults;
    procedure Clear;

    procedure AddProvider(const AProvider : TProviderConfig);
    procedure InsertProvider(AIndex : Integer; const AProvider : TProviderConfig);
    procedure RemoveProvider(AIndex : Integer);
    procedure UpdateProvider(AIndex : Integer; const AProvider : TProviderConfig);

    procedure AddModel(const AModel : TModelConfig);
    procedure InsertModel(AIndex : Integer; const AModel : TModelConfig);
    procedure RemoveModel(AIndex : Integer);

    function ProviderCount : Integer;
    function ModelCount    : Integer;
    function GetProvider(AIndex : Integer) : TProviderConfig;
    function GetModel(AIndex : Integer)    : TModelConfig;

    property Settings : TLoopSettings read FSettings write FSettings;
  end;

  TLoopConfigIO = class
  private
    class procedure SaveProviders(AParent : IXMLNode; AConfig : TLoopConfig);
    class procedure SaveModels(AParent : IXMLNode; AConfig : TLoopConfig);
    class procedure SaveSettings(AParent : IXMLNode; AConfig : TLoopConfig);

    class procedure LoadProviders(AParent : IXMLNode; AConfig : TLoopConfig);
    class procedure LoadModels(AParent : IXMLNode; AConfig : TLoopConfig);
    class procedure LoadSettings(AParent : IXMLNode; AConfig : TLoopConfig);
  public
    class procedure Save(const AFileName : string; AConfig : TLoopConfig);
    class procedure Load(const AFileName : string; AConfig : TLoopConfig);
    class function  DefaultFileName : string;
  end;

implementation

const
  XML_ROOT         = 'DelphiLoop';
  XML_SETTINGS     = 'Settings';
  XML_PROVIDERS    = 'Providers';
  XML_PROVIDER     = 'Provider';
  XML_MODELS       = 'Models';
  XML_MODEL        = 'Model';

  XML_MAX_ITER     = 'MaxIterations';
  XML_LANGUAGE     = 'Language';
  XML_EXEC_IDX     = 'ExecutorIdx';
  XML_REV_IDX      = 'ReviewerIdx';

  XML_NAME         = 'Name';
  XML_BASEURL      = 'BaseURL';
  XML_APIKEY       = 'APIKey';
  XML_PROV_TYPE    = 'Type';

  XML_DISPLAY      = 'DisplayName';
  XML_MODEL_ID     = 'ModelID';
  XML_PROV_IDX     = 'ProviderIdx';

  PROV_TYPE_OLLAMA = 'Ollama';
  PROV_TYPE_OPENAI = 'OpenAI';
  PROV_TYPE_CUSTOM = 'Custom';

constructor TLoopConfig.Create;
begin
  inherited;
  FProviders := TList<TProviderConfig>.Create;
  FModels    := TList<TModelConfig>.Create;
  SetDefaults;
end;

destructor TLoopConfig.Destroy;
begin
  FProviders.Free;
  FModels.Free;
  inherited;
end;

procedure TLoopConfig.SetDefaults;
var
  P : TProviderConfig;
  M : TModelConfig;
begin
  FSettings.MaxIterations := DEFAULT_MAX_ITERATIONS;
  FSettings.Language      := 'Delphi / Object Pascal';
  FSettings.ExecutorIdx   := DEFAULT_EXECUTOR_INDEX;
  FSettings.ReviewerIdx   := DEFAULT_REVIEWER_INDEX;

  FProviders.Clear;
  FModels.Clear;

  P.Name    := PROVIDER_OLLAMA_NAME;
  P.BaseURL := PROVIDER_OLLAMA_URL;
  P.APIKey  := '';
  P.Kind    := ptOllama;
  FProviders.Add(P);

  P.Name    := PROVIDER_OPENAI_NAME;
  P.BaseURL := PROVIDER_OPENAI_URL;
  P.APIKey  := '';
  P.Kind    := ptOpenAI;
  FProviders.Add(P);

  M.DisplayName := MODEL_QWEN_DISPLAY;
  M.ModelID     := MODEL_QWEN_ID;
  M.ProviderIdx := 0;
  FModels.Add(M);

  M.DisplayName := MODEL_LLAMA_DISPLAY;
  M.ModelID     := MODEL_LLAMA_ID;
  M.ProviderIdx := 0;
  FModels.Add(M);

  M.DisplayName := MODEL_GPT4O_DISPLAY;
  M.ModelID     := MODEL_GPT4O_ID;
  M.ProviderIdx := 1;
  FModels.Add(M);

  M.DisplayName := MODEL_GPT4O_MINI_DISPLAY;
  M.ModelID     := MODEL_GPT4O_MINI_ID;
  M.ProviderIdx := 1;
  FModels.Add(M);

  M.DisplayName := MODEL_GPT5_DISPLAY;
  M.ModelID     := MODEL_GPT5_ID;
  M.ProviderIdx := 1;
  FModels.Add(M);
end;

procedure TLoopConfig.Clear;
begin
  FProviders.Clear;
  FModels.Clear;
end;

procedure TLoopConfig.AddProvider(const AProvider : TProviderConfig);
begin
  FProviders.Add(AProvider);
end;

procedure TLoopConfig.InsertProvider(AIndex : Integer;
                                      const AProvider : TProviderConfig);
begin
  FProviders.Insert(AIndex, AProvider);
end;

procedure TLoopConfig.RemoveProvider(AIndex : Integer);
begin
  if (AIndex < 0) or (AIndex >= FProviders.Count) then Exit;
  FProviders.Delete(AIndex);
end;

procedure TLoopConfig.UpdateProvider(AIndex : Integer;
                                     const AProvider : TProviderConfig);
begin
  if (AIndex < 0) or (AIndex >= FProviders.Count) then Exit;
  FProviders[AIndex] := AProvider;
end;

procedure TLoopConfig.AddModel(const AModel : TModelConfig);
begin
  FModels.Add(AModel);
end;

procedure TLoopConfig.InsertModel(AIndex : Integer;
                                   const AModel : TModelConfig);
begin
  FModels.Insert(AIndex, AModel);
end;

procedure TLoopConfig.RemoveModel(AIndex : Integer);
begin
  if (AIndex < 0) or (AIndex >= FModels.Count) then Exit;
  FModels.Delete(AIndex);
end;

function TLoopConfig.ProviderCount : Integer;
begin
  Result := FProviders.Count;
end;

function TLoopConfig.ModelCount : Integer;
begin
  Result := FModels.Count;
end;

function TLoopConfig.GetProvider(AIndex : Integer) : TProviderConfig;
begin
  Result := FProviders[AIndex];
end;

function TLoopConfig.GetModel(AIndex : Integer) : TModelConfig;
begin
  Result := FModels[AIndex];
end;

class function TLoopConfigIO.DefaultFileName : string;
begin
  Result := ChangeFileExt(ParamStr(0), '.xml');
end;

class procedure TLoopConfigIO.SaveSettings(AParent : IXMLNode;
                                            AConfig : TLoopConfig);
var
  Node : IXMLNode;
begin
  Node := AParent.AddChild(XML_SETTINGS);
  Node.AddChild(XML_MAX_ITER).Text := IntToStr(AConfig.Settings.MaxIterations);
  Node.AddChild(XML_LANGUAGE).Text := AConfig.Settings.Language;
  Node.AddChild(XML_EXEC_IDX).Text := IntToStr(AConfig.Settings.ExecutorIdx);
  Node.AddChild(XML_REV_IDX).Text  := IntToStr(AConfig.Settings.ReviewerIdx);
end;

class procedure TLoopConfigIO.SaveProviders(AParent : IXMLNode;
                                             AConfig : TLoopConfig);
var
  I    : Integer;
  List : IXMLNode;
  Node : IXMLNode;
  P    : TProviderConfig;
  Kind : string;
begin
  List := AParent.AddChild(XML_PROVIDERS);
  for I := 0 to AConfig.ProviderCount - 1 do
  begin
    P    := AConfig.GetProvider(I);
    Node := List.AddChild(XML_PROVIDER);

    case P.Kind of
      ptOllama : Kind := PROV_TYPE_OLLAMA;
      ptOpenAI : Kind := PROV_TYPE_OPENAI;
      ptCustom : Kind := PROV_TYPE_CUSTOM;
    end;

    Node.AddChild(XML_NAME).Text      := P.Name;
    Node.AddChild(XML_BASEURL).Text   := P.BaseURL;
    Node.AddChild(XML_APIKEY).Text    := P.APIKey;
    Node.AddChild(XML_PROV_TYPE).Text := Kind;
  end;
end;

class procedure TLoopConfigIO.SaveModels(AParent : IXMLNode;
                                          AConfig : TLoopConfig);
var
  I    : Integer;
  List : IXMLNode;
  Node : IXMLNode;
  M    : TModelConfig;
begin
  List := AParent.AddChild(XML_MODELS);
  for I := 0 to AConfig.ModelCount - 1 do
  begin
    M    := AConfig.GetModel(I);
    Node := List.AddChild(XML_MODEL);
    Node.AddChild(XML_DISPLAY).Text  := M.DisplayName;
    Node.AddChild(XML_MODEL_ID).Text := M.ModelID;
    Node.AddChild(XML_PROV_IDX).Text := IntToStr(M.ProviderIdx);
  end;
end;

class procedure TLoopConfigIO.Save(const AFileName : string;
                                    AConfig : TLoopConfig);
var
  Doc  : IXMLDocument;
  Root : IXMLNode;
begin
  Doc          := NewXMLDocument;
  Doc.Encoding := 'UTF-8';
  Doc.Options  := [doNodeAutoIndent];
  Root         := Doc.AddChild(XML_ROOT);
  Root.Attributes['version'] := APP_VERSION;

  SaveSettings(Root, AConfig);
  SaveProviders(Root, AConfig);
  SaveModels(Root, AConfig);

  Doc.SaveToFile(AFileName);
end;

class procedure TLoopConfigIO.LoadSettings(AParent : IXMLNode;
                                            AConfig : TLoopConfig);
var
  Node : IXMLNode;
  S    : TLoopSettings;
begin
  Node := AParent.ChildNodes.FindNode(XML_SETTINGS);
  if not Assigned(Node) then Exit;

  S               := AConfig.Settings;
  S.MaxIterations := StrToIntDef(Node.ChildValues[XML_MAX_ITER],
                                  DEFAULT_MAX_ITERATIONS);
  S.Language      := VarToStrDef(Node.ChildValues[XML_LANGUAGE],
                                  'Delphi / Object Pascal');
  S.ExecutorIdx   := StrToIntDef(Node.ChildValues[XML_EXEC_IDX],
                                  DEFAULT_EXECUTOR_INDEX);
  S.ReviewerIdx   := StrToIntDef(Node.ChildValues[XML_REV_IDX],
                                  DEFAULT_REVIEWER_INDEX);
  AConfig.Settings := S;
end;

class procedure TLoopConfigIO.LoadProviders(AParent : IXMLNode;
                                             AConfig : TLoopConfig);
var
  I    : Integer;
  List : IXMLNode;
  Node : IXMLNode;
  P    : TProviderConfig;
  Kind : string;
begin
  List := AParent.ChildNodes.FindNode(XML_PROVIDERS);
  if not Assigned(List) then Exit;

  for I := 0 to List.ChildNodes.Count - 1 do
  begin
    Node := List.ChildNodes[I];
    if Node.NodeName <> XML_PROVIDER then Continue;

    P.Name    := VarToStrDef(Node.ChildValues[XML_NAME],      '');
    P.BaseURL := VarToStrDef(Node.ChildValues[XML_BASEURL],   '');
    P.APIKey  := VarToStrDef(Node.ChildValues[XML_APIKEY],    '');
    Kind      := VarToStrDef(Node.ChildValues[XML_PROV_TYPE], '');
    if P.Name = '' then Continue;

    if Kind = PROV_TYPE_OLLAMA then
      P.Kind := ptOllama
    else if Kind = PROV_TYPE_OPENAI then
      P.Kind := ptOpenAI
    else
      P.Kind := ptCustom;

    AConfig.AddProvider(P);
  end;
end;

class procedure TLoopConfigIO.LoadModels(AParent : IXMLNode;
                                          AConfig : TLoopConfig);
var
  I    : Integer;
  List : IXMLNode;
  Node : IXMLNode;
  M    : TModelConfig;
begin
  List := AParent.ChildNodes.FindNode(XML_MODELS);
  if not Assigned(List) then Exit;

  for I := 0 to List.ChildNodes.Count - 1 do
  begin
    Node := List.ChildNodes[I];
    if Node.NodeName <> XML_MODEL then Continue;

    M.DisplayName := VarToStrDef(Node.ChildValues[XML_DISPLAY],   '');
    M.ModelID     := VarToStrDef(Node.ChildValues[XML_MODEL_ID],  '');
    M.ProviderIdx := StrToIntDef(VarToStrDef(
                       Node.ChildValues[XML_PROV_IDX], '0'), 0);
    if M.ModelID = '' then Continue;

    AConfig.AddModel(M);
  end;
end;

class procedure TLoopConfigIO.Load(const AFileName : string;
                                    AConfig : TLoopConfig);
var
  Doc  : IXMLDocument;
  Root : IXMLNode;
begin
  if not FileExists(AFileName) then
  begin
    AConfig.SetDefaults;
    Exit;
  end;

  Doc  := LoadXMLDocument(AFileName);
  Root := Doc.ChildNodes.FindNode(XML_ROOT);
  if not Assigned(Root) then
  begin
    AConfig.SetDefaults;
    Exit;
  end;

  AConfig.Clear;

  LoadSettings(Root, AConfig);
  LoadProviders(Root, AConfig);
  LoadModels(Root, AConfig);
end;

end.
