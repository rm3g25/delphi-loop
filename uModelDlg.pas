unit uModelDlg;

interface

uses
  System.SysUtils,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  LoopTypes,
  LoopConfig, System.Classes;

type
  TfrmModelDlg = class(TForm)
    lblDisplay  :TLabel;
    lblModelID  :TLabel;
    lblProvider :TLabel;
    edDisplay   :TEdit;
    edModelID   :TEdit;
    cmbProvider :TComboBox;
    btnOK       :TButton;
    btnCancel   :TButton;

    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);

  private
    function  GetModel :TModelConfig;
    procedure SetModel(const AValue :TModelConfig);

  public
    procedure LoadProviders(AConfig :TLoopConfig);

    property Model :TModelConfig read GetModel write SetModel;
  end;

implementation

{$R *.dfm}




procedure TfrmModelDlg.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmModelDlg.btnOKClick(Sender: TObject);
begin
  if Trim(edModelID.Text) = '' then
  begin
    edModelID.SetFocus;
    Exit;
  end;
  if cmbProvider.ItemIndex < 0 then
  begin
    cmbProvider.SetFocus;
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TfrmModelDlg.LoadProviders(AConfig :TLoopConfig);
var
  I :Integer;
begin
  cmbProvider.Items.Clear;
  for I := 0 to AConfig.ProviderCount - 1 do
    cmbProvider.Items.Add(AConfig.GetProvider(I).Name);
  if cmbProvider.Items.Count > 0 then
    cmbProvider.ItemIndex := 0;
end;

function TfrmModelDlg.GetModel :TModelConfig;
begin
  Result.DisplayName := Trim(edDisplay.Text);
  Result.ModelID     := Trim(edModelID.Text);
  Result.ProviderIdx := cmbProvider.ItemIndex;
end;

procedure TfrmModelDlg.SetModel(const AValue :TModelConfig);
begin
  edDisplay.Text        := AValue.DisplayName;
  edModelID.Text        := AValue.ModelID;
  cmbProvider.ItemIndex := AValue.ProviderIdx;
end;

end.
