unit Engine.Config;

{
  Runtime configuration: providers, models, loop settings.
  TLoopConfig holds the data; TLoopConfigIO reads and writes it as XML.
  XML tag names and the provider-type vocabulary are wire protocol: their
  values are frozen, only the identifiers may change.
}

// TODO: encrypt API keys with Windows DPAPI (CryptProtectData) - README roadmap item.

interface

uses
  System.Generics.Collections,
  Xml.XMLIntf,
  Engine.Types;

type
  TLoopConfig = class
  private
    FSettings: TLoopSettings;
    FProviders: TList<TProviderConfig>;
    FModels: TList<TModelConfig>;

    procedure AddDefaultProvider(const AName, AUrl: string; AKind: TProviderType);
    procedure AddDefaultModel(const ADisplayName, AModelId: string; AProviderIndex: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetDefaults;
    procedure Clear;

    procedure AddProvider(const AProvider: TProviderConfig);
    procedure InsertProvider(AIndex: Integer; const AProvider: TProviderConfig);
    procedure RemoveProvider(AIndex: Integer);
    procedure UpdateProvider(AIndex: Integer; const AProvider: TProviderConfig);

    procedure AddModel(const AModel: TModelConfig);
    procedure InsertModel(AIndex: Integer; const AModel: TModelConfig);
    procedure RemoveModel(AIndex: Integer);

    function ProviderCount: Integer;
    function ModelCount: Integer;
    function GetProvider(AIndex: Integer): TProviderConfig;
    function GetModel(AIndex: Integer): TModelConfig;

    property Settings: TLoopSettings read FSettings write FSettings;
  end;

  TLoopConfigIO = class
  private
    class procedure SaveSettings(AParent: IXMLNode; AConfig: TLoopConfig);
    class procedure SaveProviders(AParent: IXMLNode; AConfig: TLoopConfig);
    class procedure SaveModels(AParent: IXMLNode; AConfig: TLoopConfig);

    class procedure LoadSettings(AParent: IXMLNode; AConfig: TLoopConfig);
    class procedure LoadProviders(AParent: IXMLNode; AConfig: TLoopConfig);
    class procedure LoadModels(AParent: IXMLNode; AConfig: TLoopConfig);
  public
    class procedure Save(const AFileName: string; AConfig: TLoopConfig);
    class procedure Load(const AFileName: string; AConfig: TLoopConfig);
    class function DefaultFileName: string;
  end;

implementation

uses
  System.SysUtils,
  System.Variants,
  Xml.XMLDoc,
  Engine.Consts;

const
  // XML tag names - wire protocol. A typo here silently loses user data on
  // the next Load, so these are constants, not inline literals.
  XmlRoot = 'DelphiLoop';
  XmlSettings = 'Settings';
  XmlProviders = 'Providers';
  XmlProvider = 'Provider';
  XmlModels = 'Models';
  XmlModel = 'Model';

  XmlMaxIterations = 'MaxIterations';
  XmlExecutorIndex = 'ExecutorIdx';
  XmlReviewerIndex = 'ReviewerIdx';

  XmlName = 'Name';
  XmlBaseUrl = 'BaseURL';
  XmlApiKey = 'APIKey';
  XmlProviderType = 'Type';

  XmlDisplayName = 'DisplayName';
  XmlModelId = 'ModelID';
  XmlProviderIndex = 'ProviderIdx';

  // Fixed vocabulary of the Type tag - frozen as well.
  ProviderTypeOllama = 'Ollama';
  ProviderTypeOpenAI = 'OpenAI';
  ProviderTypeCustom = 'Custom';

// ===========================================================================
//  TLoopConfig
// ===========================================================================

constructor TLoopConfig.Create;
begin
  inherited;
  FProviders := TList<TProviderConfig>.Create;
  FModels := TList<TModelConfig>.Create;
  SetDefaults;
end;

destructor TLoopConfig.Destroy;
begin
  FProviders.Free;
  FModels.Free;
  inherited;
end;

procedure TLoopConfig.AddDefaultProvider(const AName, AUrl: string; AKind: TProviderType);
var
  Provider: TProviderConfig;
begin
  Provider.Name := AName;
  Provider.BaseUrl := AUrl;
  Provider.ApiKey := '';
  Provider.Kind := AKind;
  FProviders.Add(Provider);
end;

procedure TLoopConfig.AddDefaultModel(const ADisplayName, AModelId: string;
  AProviderIndex: Integer);
var
  Model: TModelConfig;
begin
  Model.DisplayName := ADisplayName;
  Model.ModelId := AModelId;
  Model.ProviderIndex := AProviderIndex;
  FModels.Add(Model);
end;

procedure TLoopConfig.SetDefaults;
begin
  FSettings.MaxIterations := DefaultMaxIterations;
  FSettings.ExecutorIndex := DefaultExecutorIndex;
  FSettings.ReviewerIndex := DefaultReviewerIndex;

  FProviders.Clear;
  FModels.Clear;

  AddDefaultProvider(ProviderOllamaName, ProviderOllamaUrl, ptOllama);
  AddDefaultProvider(ProviderOpenAIName, ProviderOpenAIUrl, ptOpenAI);
  AddDefaultProvider(ProviderOpenRouterName, ProviderOpenRouterUrl, ptOpenAI);

  // Model -> provider references are positions in the list above:
  // 0 = Ollama, 1 = OpenAI, 2 = OpenRouter.
  AddDefaultModel(ModelQwenDisplay, ModelQwenId, 0);
  AddDefaultModel(ModelLlamaDisplay, ModelLlamaId, 0);
  AddDefaultModel(ModelGpt4oDisplay, ModelGpt4oId, 1);
  AddDefaultModel(ModelGpt4oMiniDisplay, ModelGpt4oMiniId, 1);
  AddDefaultModel(ModelGpt5Display, ModelGpt5Id, 1);
  AddDefaultModel(ModelQwen36Display, ModelQwen36Id, 2);
end;

procedure TLoopConfig.Clear;
begin
  FProviders.Clear;
  FModels.Clear;
end;

procedure TLoopConfig.AddProvider(const AProvider: TProviderConfig);
begin
  FProviders.Add(AProvider);
end;

procedure TLoopConfig.InsertProvider(AIndex: Integer; const AProvider: TProviderConfig);
begin
  FProviders.Insert(AIndex, AProvider);
end;

procedure TLoopConfig.RemoveProvider(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FProviders.Count) then
    Exit;
  FProviders.Delete(AIndex);
end;

procedure TLoopConfig.UpdateProvider(AIndex: Integer; const AProvider: TProviderConfig);
begin
  if (AIndex < 0) or (AIndex >= FProviders.Count) then
    Exit;
  FProviders[AIndex] := AProvider;
end;

procedure TLoopConfig.AddModel(const AModel: TModelConfig);
begin
  FModels.Add(AModel);
end;

procedure TLoopConfig.InsertModel(AIndex: Integer; const AModel: TModelConfig);
begin
  FModels.Insert(AIndex, AModel);
end;

procedure TLoopConfig.RemoveModel(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FModels.Count) then
    Exit;
  FModels.Delete(AIndex);
end;

function TLoopConfig.ProviderCount: Integer;
begin
  Result := FProviders.Count;
end;

function TLoopConfig.ModelCount: Integer;
begin
  Result := FModels.Count;
end;

function TLoopConfig.GetProvider(AIndex: Integer): TProviderConfig;
begin
  Result := FProviders[AIndex];
end;

function TLoopConfig.GetModel(AIndex: Integer): TModelConfig;
begin
  Result := FModels[AIndex];
end;

// ===========================================================================
//  TLoopConfigIO
// ===========================================================================

class function TLoopConfigIO.DefaultFileName: string;
begin
  Result := ChangeFileExt(ParamStr(0), '.xml');
end;

class procedure TLoopConfigIO.SaveSettings(AParent: IXMLNode; AConfig: TLoopConfig);
var
  Node: IXMLNode;
begin
  Node := AParent.AddChild(XmlSettings);
  Node.AddChild(XmlMaxIterations).Text := IntToStr(AConfig.Settings.MaxIterations);
  Node.AddChild(XmlExecutorIndex).Text := IntToStr(AConfig.Settings.ExecutorIndex);
  Node.AddChild(XmlReviewerIndex).Text := IntToStr(AConfig.Settings.ReviewerIndex);
end;

class procedure TLoopConfigIO.SaveProviders(AParent: IXMLNode; AConfig: TLoopConfig);
var
  List: IXMLNode;
begin
  List := AParent.AddChild(XmlProviders);
  for var i := 0 to AConfig.ProviderCount - 1 do
  begin
    var Provider: TProviderConfig := AConfig.GetProvider(i);
    var Node: IXMLNode := List.AddChild(XmlProvider);

    var Kind: string;
    case Provider.Kind of
      ptOllama: Kind := ProviderTypeOllama;
      ptOpenAI: Kind := ProviderTypeOpenAI;
      ptCustom: Kind := ProviderTypeCustom;
    end;

    Node.AddChild(XmlName).Text := Provider.Name;
    Node.AddChild(XmlBaseUrl).Text := Provider.BaseUrl;
    Node.AddChild(XmlApiKey).Text := Provider.ApiKey;
    Node.AddChild(XmlProviderType).Text := Kind;
  end;
end;

class procedure TLoopConfigIO.SaveModels(AParent: IXMLNode; AConfig: TLoopConfig);
var
  List: IXMLNode;
begin
  List := AParent.AddChild(XmlModels);
  for var i := 0 to AConfig.ModelCount - 1 do
  begin
    var Model: TModelConfig := AConfig.GetModel(i);
    var Node: IXMLNode := List.AddChild(XmlModel);
    Node.AddChild(XmlDisplayName).Text := Model.DisplayName;
    Node.AddChild(XmlModelId).Text := Model.ModelId;
    Node.AddChild(XmlProviderIndex).Text := IntToStr(Model.ProviderIndex);
  end;
end;

class procedure TLoopConfigIO.Save(const AFileName: string; AConfig: TLoopConfig);
var
  Doc: IXMLDocument;
  Root: IXMLNode;
begin
  Doc := NewXMLDocument;
  Doc.Encoding := 'UTF-8';
  Doc.Options := [doNodeAutoIndent];
  Root := Doc.AddChild(XmlRoot);
  Root.Attributes['version'] := AppVersion;

  SaveSettings(Root, AConfig);
  SaveProviders(Root, AConfig);
  SaveModels(Root, AConfig);

  Doc.SaveToFile(AFileName);
end;

class procedure TLoopConfigIO.LoadSettings(AParent: IXMLNode; AConfig: TLoopConfig);
var
  Node: IXMLNode;
  Settings: TLoopSettings;
begin
  Node := AParent.ChildNodes.FindNode(XmlSettings);
  if not Assigned(Node) then
    Exit;

  Settings := AConfig.Settings;
  Settings.MaxIterations := StrToIntDef(Node.ChildValues[XmlMaxIterations], DefaultMaxIterations);
  Settings.ExecutorIndex := StrToIntDef(Node.ChildValues[XmlExecutorIndex], DefaultExecutorIndex);
  Settings.ReviewerIndex := StrToIntDef(Node.ChildValues[XmlReviewerIndex], DefaultReviewerIndex);
  AConfig.Settings := Settings;
end;

class procedure TLoopConfigIO.LoadProviders(AParent: IXMLNode; AConfig: TLoopConfig);
var
  List: IXMLNode;
begin
  List := AParent.ChildNodes.FindNode(XmlProviders);
  if not Assigned(List) then
    Exit;

  for var i := 0 to List.ChildNodes.Count - 1 do
  begin
    var Node: IXMLNode := List.ChildNodes[i];
    if Node.NodeName <> XmlProvider then
      Continue;

    var Provider: TProviderConfig;
    Provider.Name := VarToStrDef(Node.ChildValues[XmlName], '');
    Provider.BaseUrl := VarToStrDef(Node.ChildValues[XmlBaseUrl], '');
    Provider.ApiKey := VarToStrDef(Node.ChildValues[XmlApiKey], '');
    if Provider.Name = '' then
      Continue;

    var Kind: string := VarToStrDef(Node.ChildValues[XmlProviderType], '');
    if Kind = ProviderTypeOllama then
      Provider.Kind := ptOllama
    else if Kind = ProviderTypeOpenAI then
      Provider.Kind := ptOpenAI
    else
      Provider.Kind := ptCustom;

    AConfig.AddProvider(Provider);
  end;
end;

class procedure TLoopConfigIO.LoadModels(AParent: IXMLNode; AConfig: TLoopConfig);
var
  List: IXMLNode;
begin
  List := AParent.ChildNodes.FindNode(XmlModels);
  if not Assigned(List) then
    Exit;

  for var i := 0 to List.ChildNodes.Count - 1 do
  begin
    var Node: IXMLNode := List.ChildNodes[i];
    if Node.NodeName <> XmlModel then
      Continue;

    var Model: TModelConfig;
    Model.DisplayName := VarToStrDef(Node.ChildValues[XmlDisplayName], '');
    Model.ModelId := VarToStrDef(Node.ChildValues[XmlModelId], '');
    Model.ProviderIndex := StrToIntDef(VarToStrDef(Node.ChildValues[XmlProviderIndex], '0'), 0);
    if Model.ModelId = '' then
      Continue;

    AConfig.AddModel(Model);
  end;
end;

class procedure TLoopConfigIO.Load(const AFileName: string; AConfig: TLoopConfig);
var
  Doc: IXMLDocument;
  Root: IXMLNode;
begin
  if not FileExists(AFileName) then
  begin
    AConfig.SetDefaults;
    Exit;
  end;

  Doc := LoadXMLDocument(AFileName);
  Root := Doc.ChildNodes.FindNode(XmlRoot);
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
