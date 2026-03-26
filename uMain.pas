unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Samples.Spin, Vcl.Clipbrd,
  uSettings,
  LoopTypes,
  LoopConsts,
  LoopConfig,
  LoopEngine;

type
  TfrmMain = class(TForm)
    pnlMain           :TPanel;
    pnlContent        :TPanel;
    pnlAgents         :TPanel;
    lblExecutorTitle  :TLabel;
    cmbExecutor       :TComboBox;
    lblReviewerTitle  :TLabel;
    cmbReviewer       :TComboBox;
    btnSettings       :TButton;
    pnlTaskHeader     :TPanel;
    lblTaskTitle      :TLabel;
    pnlTaskFooter     :TPanel;
    lblIterStatus     :TLabel;
    pbProgress        :TProgressBar;
    btnGenerate       :TButton;
    pnlStatus         :TPanel;
    lblStatus         :TLabel;
    lblStats          :TLabel;
    pnlResizable      :TPanel;
    pnlTask           :TPanel;
    memoTask          :TMemo;
    splTaskOutput     :TSplitter;
    pcOutput          :TPageControl;
    tsLog             :TTabSheet;
    memoLog           :TMemo;
    tsResult          :TTabSheet;
    memoResult        :TMemo;
    btnCopy           :TButton;
    btnClearLog       :TButton;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnGenerateClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);

  protected
    procedure CreateParams(var Params :TCreateParams); override;

  private
    FEngine      :TLoopEngine;
    FConfig      :TLoopConfig;
    FTotalRuns   :Integer;
    FTotalIter   :Integer;
    FTotalTokens :Integer;
    FTotalCost   :Double;

    procedure LoadConfig;
    procedure SaveConfig;
    procedure BindEngineEvents;
    procedure ApplyConfigToUI;
    procedure ApplyUIToConfig;
    procedure RebuildModelCombos;
    procedure UpdateStats;
    procedure AppendLog(const AMsg :string);

    // Engine callbacks
    procedure OnEngineLog(const AMsg :string);
    procedure OnEngineProgress(APosition, AMax :Integer);
    procedure OnEngineStatus(const AMsg :string);
    procedure OnEngineIter(const AMsg :string);
    procedure OnEngineDone(const ACode :string; AIterations :Integer;
                           const AExecutor, AReviewer :string);
    procedure OnEngineError(const AMsg :string);
    procedure OnEngineTokens(ATokens :Integer; ACost :Double);

  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FConfig := TLoopConfig.Create;
  FEngine := TLoopEngine.Create;

  BindEngineEvents;
  LoadConfig;
  RebuildModelCombos;
  ApplyConfigToUI;
  UpdateStats;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  ApplyUIToConfig;
  SaveConfig;
  FEngine.Free;
  FConfig.Free;
end;

procedure TfrmMain.CreateParams(var Params :TCreateParams);
begin
  inherited;
  Params.ExStyle := Params.ExStyle or WS_EX_COMPOSITED;
end;

procedure TfrmMain.LoadConfig;
begin
  TLoopConfigIO.Load(TLoopConfigIO.DefaultFileName, FConfig);
  FEngine.SetProviders(FConfig);
  FEngine.SetModels(FConfig);
end;

procedure TfrmMain.SaveConfig;
begin
  TLoopConfigIO.Save(TLoopConfigIO.DefaultFileName, FConfig);
end;

procedure TfrmMain.BindEngineEvents;
begin
  FEngine.OnLog      := OnEngineLog;
  FEngine.OnProgress := OnEngineProgress;
  FEngine.OnStatus   := OnEngineStatus;
  FEngine.OnIter     := OnEngineIter;
  FEngine.OnDone     := OnEngineDone;
  FEngine.OnError    := OnEngineError;
  FEngine.OnTokens   := OnEngineTokens;
end;

procedure TfrmMain.ApplyConfigToUI;
begin
  cmbExecutor.ItemIndex := FConfig.Settings.ExecutorIdx;
  cmbReviewer.ItemIndex := FConfig.Settings.ReviewerIdx;
end;

procedure TfrmMain.ApplyUIToConfig;
var
  S :TLoopSettings;
begin
  S               := FConfig.Settings;
  S.ExecutorIdx   := cmbExecutor.ItemIndex;
  S.ReviewerIdx   := cmbReviewer.ItemIndex;
  FConfig.Settings := S;
end;

procedure TfrmMain.RebuildModelCombos;
begin
  cmbExecutor.Items.Clear;
  cmbReviewer.Items.Clear;
  for var I := 0 to FConfig.ModelCount - 1 do
  begin
    var Model := FConfig.GetModel(I);
    cmbExecutor.Items.Add(Model.DisplayName);
    cmbReviewer.Items.Add(Model.DisplayName);
  end;
end;

procedure TfrmMain.UpdateStats;
begin
  var CostStr := FormatFloat(COST_FORMAT, FTotalCost);

  lblStats.Caption := Format(
    STATS_FMT,
    [FTotalRuns, FTotalIter, FTotalTokens, CostStr]
  );
end;

procedure TfrmMain.AppendLog(const AMsg :string);
begin
  memoLog.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + AMsg);
  memoLog.Perform(WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TfrmMain.OnEngineLog(const AMsg :string);
begin
  AppendLog(AMsg);
end;

procedure TfrmMain.OnEngineProgress(APosition, AMax :Integer);
begin
  pbProgress.Max      := AMax;
  pbProgress.Position := APosition;
  Inc(FTotalIter);
  UpdateStats;
end;

procedure TfrmMain.OnEngineStatus(const AMsg :string);
begin
  lblStatus.Caption := AMsg;
end;

procedure TfrmMain.OnEngineIter(const AMsg :string);
begin
  lblIterStatus.Caption := AMsg;
end;

procedure TfrmMain.OnEngineDone(const ACode :string; AIterations :Integer;
                                 const AExecutor, AReviewer :string);
begin
  memoResult.Lines.Text := ACode;
  pcOutput.ActivePage   := tsResult;
  Inc(FTotalRuns);
  UpdateStats;
  lblStatus.Caption     := Format(STATUS_DONE_FMT,
    [AIterations, AExecutor, AReviewer]);
  lblIterStatus.Caption := ITER_DONE;
  btnGenerate.Enabled := True;
  btnClearLog.Enabled := True;
end;

procedure TfrmMain.OnEngineError(const AMsg :string);
begin
  AppendLog(STATUS_ERROR + AMsg);
  lblStatus.Caption   := STATUS_ERROR + AMsg;
  btnGenerate.Enabled := True;
  btnClearLog.Enabled := True;
end;

procedure TfrmMain.OnEngineTokens(ATokens :Integer; ACost :Double);
begin
  Inc(FTotalTokens, ATokens);
  FTotalCost := FTotalCost + ACost;
  UpdateStats;
end;

procedure TfrmMain.btnGenerateClick(Sender: TObject);
begin
  if Trim(memoTask.Text) = '' then Exit;

  btnGenerate.Enabled := False;
  btnClearLog.Enabled := False;
  memoLog.Clear;
  memoResult.Clear;
  pbProgress.Position := 0;
  pcOutput.ActivePage := tsLog;

  FEngine.Run(
    memoTask.Text,
    cmbExecutor.ItemIndex,
    cmbReviewer.ItemIndex,
    FConfig.Settings.MaxIterations
  );
end;

procedure TfrmMain.btnCopyClick(Sender: TObject);
begin
  if memoResult.Text <> '' then
  begin
    Clipboard.AsText  := memoResult.Text;
    lblStatus.Caption := STATUS_COPIED;
  end;
end;

procedure TfrmMain.btnClearLogClick(Sender: TObject);
begin
  memoLog.Clear;
end;

procedure TfrmMain.btnSettingsClick(Sender: TObject);
var
  Dlg: TfrmSettings;
begin
  Dlg := TfrmSettings.Create(Self);
  try
    Dlg.LoadFromConfig(FConfig);
    if Dlg.ShowModal = mrOk then
    begin
      Dlg.SaveToConfig(FConfig);
      FEngine.SetProviders(FConfig);
      FEngine.SetModels(FConfig);
      RebuildModelCombos;
      ApplyConfigToUI;
      SaveConfig;
    end;
  finally
    Dlg.Free;
  end;
end;

end.
