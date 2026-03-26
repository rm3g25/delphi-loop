unit uProviderDlg;

interface

uses
  System.SysUtils,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  LoopTypes, System.Classes;

type
  TfrmProviderDlg = class(TForm)
    lblName   :TLabel;
    lblURL    :TLabel;
    lblAPIKey :TLabel;
    lblType   :TLabel;
    edName    :TEdit;
    edURL     :TEdit;
    edAPIKey  :TEdit;
    cmbType   :TComboBox;
    btnOK     :TButton;
    btnCancel :TButton;

    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);

  private
    function  GetProvider :TProviderConfig;
    procedure SetProvider(const AValue :TProviderConfig);

  public
    property Provider :TProviderConfig read GetProvider write SetProvider;
  end;

implementation

{$R *.dfm}

procedure TfrmProviderDlg.FormCreate(Sender: TObject);
begin
  cmbType.ItemIndex := 0;
end;

procedure TfrmProviderDlg.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmProviderDlg.btnOKClick(Sender: TObject);
begin
  if Trim(edName.Text) = '' then
  begin
    edName.SetFocus;
    Exit;
  end;
  if Trim(edURL.Text) = '' then
  begin
    edURL.SetFocus;
    Exit;
  end;
  ModalResult := mrOk;
end;

function TfrmProviderDlg.GetProvider :TProviderConfig;
begin
  Result.Name    := Trim(edName.Text);
  Result.BaseURL := Trim(edURL.Text);
  Result.APIKey  := Trim(edAPIKey.Text);
  case cmbType.ItemIndex of
    0: Result.Kind := ptOllama;
    1: Result.Kind := ptOpenAI;
  else Result.Kind := ptCustom;
  end;
end;

procedure TfrmProviderDlg.SetProvider(const AValue :TProviderConfig);
begin
  edName.Text   := AValue.Name;
  edURL.Text    := AValue.BaseURL;
  edAPIKey.Text := AValue.APIKey;
  case AValue.Kind of
    ptOllama: cmbType.ItemIndex := 0;
    ptOpenAI: cmbType.ItemIndex := 1;
    ptCustom: cmbType.ItemIndex := 2;
  end;
end;

end.
