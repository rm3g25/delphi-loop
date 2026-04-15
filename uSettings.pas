unit uSettings;

interface

uses
  System.SysUtils,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Samples.Spin, Vcl.Dialogs, System.UITypes, System.Classes,
  LoopConsts,
  LoopConfig,
  uProviderDlg,
  uModelDlg;

type
  TfrmSettings = class(TForm)
    pnlTop            :TPanel;
    pnlProviders      :TPanel;
    lblProvidersTitle :TLabel;
    lbProviders       :TListBox;
    pnlProviderBtns   :TPanel;
    btnAddProvider    :TButton;
    btnEditProvider   :TButton;
    btnRemoveProvider :TButton;
    pnlModels         :TPanel;
    lblModelsTitle    :TLabel;
    lbModels          :TListBox;
    pnlModelBtns      :TPanel;
    btnAddModel       :TButton;
    btnEditModel      :TButton;
    btnRemoveModel    :TButton;
    pnlGeneral        :TPanel;
    lblMaxIter        :TLabel;
    spnMaxIter        :TSpinEdit;
    btnClose          :TButton;

    procedure btnAddProviderClick(Sender: TObject);
    procedure btnEditProviderClick(Sender: TObject);
    procedure btnRemoveProviderClick(Sender: TObject);
    procedure lbProvidersDblClick(Sender: TObject);
    procedure btnAddModelClick(Sender: TObject);
    procedure btnEditModelClick(Sender: TObject);
    procedure btnRemoveModelClick(Sender: TObject);
    procedure lbModelsDblClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);

  private
    FConfig :TLoopConfig;

    procedure RefreshProviders;
    procedure RefreshModels;

  public
    procedure LoadFromConfig(AConfig :TLoopConfig);
    procedure SaveToConfig(AConfig :TLoopConfig);
  end;

implementation

{$R *.dfm}

procedure TfrmSettings.LoadFromConfig(AConfig :TLoopConfig);
begin
  FConfig := AConfig;
  spnMaxIter.Value := FConfig.Settings.MaxIterations;
  RefreshProviders;
  RefreshModels;
end;

procedure TfrmSettings.SaveToConfig(AConfig :TLoopConfig);
var
  S :TLoopSettings;
begin
  S               := AConfig.Settings;
  S.MaxIterations := spnMaxIter.Value;
  AConfig.Settings := S;
end;

procedure TfrmSettings.RefreshProviders;
var
  I :Integer;
begin
  lbProviders.Clear;
  for I := 0 to FConfig.ProviderCount - 1 do
    lbProviders.Items.Add(FConfig.GetProvider(I).Name);
end;

procedure TfrmSettings.RefreshModels;
var
  I :Integer;
begin
  lbModels.Clear;
  for I := 0 to FConfig.ModelCount - 1 do
    lbModels.Items.Add(FConfig.GetModel(I).DisplayName);
end;

procedure TfrmSettings.btnAddProviderClick(Sender: TObject);
var
  Dlg :TfrmProviderDlg;
begin
  Dlg := TfrmProviderDlg.Create(Self);
  try
    if Dlg.ShowModal = mrOk then
    begin
      FConfig.AddProvider(Dlg.Provider);
      RefreshProviders;
      RefreshModels;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmSettings.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmSettings.btnEditProviderClick(Sender: TObject);
var
  Dlg :TfrmProviderDlg;
  Idx :Integer;
begin
  Idx := lbProviders.ItemIndex;
  if Idx < 0 then Exit;

  Dlg := TfrmProviderDlg.Create(Self);
  try
    Dlg.Provider := FConfig.GetProvider(Idx);
    if Dlg.ShowModal = mrOk then
    begin
      FConfig.UpdateProvider(Idx, Dlg.Provider);
      RefreshProviders;
      lbProviders.ItemIndex := Idx;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmSettings.btnRemoveProviderClick(Sender: TObject);
var
  Idx :Integer;
begin
  Idx := lbProviders.ItemIndex;
  if Idx < 0 then Exit;
  if MessageDlg('Remove provider "' + FConfig.GetProvider(Idx).Name + '"?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FConfig.RemoveProvider(Idx);
    RefreshProviders;
    RefreshModels;
  end;
end;

procedure TfrmSettings.lbProvidersDblClick(Sender: TObject);
begin
  btnEditProviderClick(Sender);
end;

procedure TfrmSettings.btnAddModelClick(Sender: TObject);
var
  Dlg :TfrmModelDlg;
begin
  if FConfig.ProviderCount = 0 then
  begin
    MessageDlg('Add at least one provider first.', mtInformation, [mbOK], 0);
    Exit;
  end;

  Dlg := TfrmModelDlg.Create(Self);
  try
    Dlg.LoadProviders(FConfig);
    if Dlg.ShowModal = mrOk then
    begin
      FConfig.AddModel(Dlg.Model);
      RefreshModels;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmSettings.btnEditModelClick(Sender: TObject);
var
  Dlg :TfrmModelDlg;
  Idx :Integer;
begin
  Idx := lbModels.ItemIndex;
  if Idx < 0 then Exit;

  Dlg := TfrmModelDlg.Create(Self);
  try
    Dlg.LoadProviders(FConfig);
    Dlg.Model := FConfig.GetModel(Idx);
    if Dlg.ShowModal = mrOk then
    begin
      FConfig.RemoveModel(Idx);
      FConfig.InsertModel(Idx, Dlg.Model);
      RefreshModels;
      lbModels.ItemIndex := Idx;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmSettings.btnRemoveModelClick(Sender: TObject);
var
  Idx :Integer;
begin
  Idx := lbModels.ItemIndex;
  if Idx < 0 then Exit;
  if MessageDlg('Remove model "' + FConfig.GetModel(Idx).DisplayName + '"?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FConfig.RemoveModel(Idx);
    RefreshModels;
  end;
end;

procedure TfrmSettings.lbModelsDblClick(Sender: TObject);
begin
  btnEditModelClick(Sender);
end;

end.
