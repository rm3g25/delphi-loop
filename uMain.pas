unit uMain;

{
  DelphiLoop v0.3 — FMX main form
  All controls built programmatically (no designer dependency).

  Output: TVertScrollBox with native chat bubbles.
    Task      — right-aligned blue-bordered collapsible bubble.
    Thinking  — plain dim text row "-> Model thinking..." (no bubble).
    Code      — dark TCodeView with Delphi syntax highlighting, collapsible.
    Review    — tinted bubble, three styles:
                  rejection  (red, collapsible),
                  approved   (green, flat — rare path, approval without NO_ISSUES),
                  no_issues  (green flat, non-collapsible strip).
    Done/Error/Cost — slim status bars.
    Result  — final code bubble in the chat stream, auto-opened on EngDone.

  No external browser, no WebView2, no internet dependency for rendering.

  Engine event contract (v0.3):
    OnThink  — accumulates per-phase into FThinkBuf / FThinkModel.
                Flushed as a plain text row before each code or review bubble.
    OnPhase  — updates sidebar + progress; adds iter header for iter > 1.
    OnCode   — flushes thinking, then adds a code bubble.
    OnReview — flushes thinking, then adds a review bubble.
    OnDone   — flushes thinking, adds done bar, shows result panel.
    OnError  — adds error bar, stops running state.
    OnTokens — adds inline cost label.

  All handlers run on the main thread via TThread.Synchronize in the engine;
  no extra TThread.Queue wrapping needed here.
}

interface

uses
 {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.DwmApi,
  FMX.Platform.Win,
 {$ENDIF}
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Math, System.Generics.Collections, System.StrUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.EditBox,
  FMX.Layouts, FMX.Objects, FMX.StdCtrls, FMX.Edit, FMX.Memo, FMX.Styles,
  FMX.ListBox, FMX.ScrollBox, FMX.SpinBox, FMX.Platform, FMX.Ani,
  LoopEngine, LoopConfig, LoopTypes, LoopConsts,
  uCodeView, uUIConsts;

type
  // Review bubble style — three distinct visual modes.
  TReviewStyle = (rsRejection, rsApproved, rsNoIssues);

  TfrmMain = class; // forward

  // ---------------------------------------------------------------------------
  //  TChatBubble — collapsible bubble helper for Code and Review items.
  //  Owns nothing extra; FMX parent chain owns all controls.
  // ---------------------------------------------------------------------------
  TChatBubble = class(TComponent)
  public
    FIsOpen      :Boolean;
    FBubbleRect  :TRectangle;
    FChevronLbl  :TLabel;
    FBodyRect    :TRectangle; // container shown/hidden on toggle
    FCollH       :Single;     // collapsed height
    FExpandH     :Single;     // expanded height
    FOwner       :TfrmMain;
  public
    constructor Create(AOwner: TfrmMain; ABubble: TRectangle;
                       AChevron: TLabel; ABody: TRectangle;
                       ACollH, AExpandH: Single); reintroduce;
    procedure HandleClick(Sender: TObject);
  end;

  TfrmMain = class(TForm)
  private
    // --- Engine & state ---
    FEngine      :TLoopEngine;
    FConfig      :TLoopConfig;
    FRunning     :Boolean;
    FCurrentIter :Integer;
    FMaxIter     :Integer;
    FThinkBuf    :TStringBuilder; // accumulates OnThink messages per phase
    FThinkModel  :string;         // model name for the current thinking row

    // --- Chat area ---
    FScrollChat  :TVertScrollBox;
    FChatBubbles :TList<TFmxObject>; // root controls per chat item (non-owning)

    // --- Sidebar ---
    FRectSidebar :TRectangle;
    FRectStatus  :TRectangle;
    FLblRunTitle :TLabel;
    FLblRunIter  :TLabel;
    FPrgRun      :TProgressBar;
    FRectSettBtn :TRectangle;

    // --- Input area ---
    FRectInput   :TRectangle;
    FMemoTask    :TMemo;
    FCboExec     :TComboBox;
    FCboRev      :TComboBox;
    FCboIter     :TComboBox;
    FRectRun     :TRectangle;
    FLblRunBtn   :TLabel;
    FRectClear   :TRectangle;

    // --- Settings overlay ---
    FRectSettings :TRectangle;
    FEdtORKey     :TEdit;
    FEdtOAIKey    :TEdit;
    FEdtOllamaURL :TEdit;
    FCboSExec     :TComboBox;
    FCboSRev      :TComboBox;
    FSpbIter      :TSpinBox;

    FNextChatY    :Single; // accumulated Y for next bubble

    // --- Build helpers ---
    function  MkRect(AParent: TFmxObject; AAlign: TAlignLayout;
                     AColor: TAlphaColor; AW, AH: Single): TRectangle;
    function  MkLbl(AParent: TFmxObject; const ATxt: string;
                    ASz: Single; AColor: TAlphaColor;
                    ABold: Boolean = False): TLabel;
    function  MkLine(AParent: TFmxObject; AAlign: TAlignLayout): TRectangle;
    function  MkRectBtn(AParent: TFmxObject; const ATxt: string;
                        AColor: TAlphaColor; AW: Single): TRectangle;
    function  MkEdit(AParent: TFmxObject; const AHint: string;
                     APassword: Boolean = False): TEdit;
    function  MkCombo(AParent: TFmxObject; AW: Single): TComboBox;

    // --- Build sections ---
    procedure LoadStyle;
    procedure BuildSidebar;
    procedure BuildMain;
    procedure BuildSettingsOverlay;
    procedure FillCombos;
    procedure SyncConfigToUI;
    procedure SyncUIToConfig;

    // --- Chat helpers ---
    function  MkBubble(AColor: TAlphaColor; AHeight: Single): TRectangle;
    procedure RecalcBubblesFrom(AFrom: TFmxObject; ADelta: Single);
    procedure ChatClear;
    procedure ChatAddIterHeader(ANum, AMax: Integer);
    procedure ChatAddTask(const AText: string);
    procedure ChatAddThinkingText(const AExecutor: string);
    procedure ChatAddCode(const ACode: string; AIteration: Integer);
    procedure ChatAddReview(const AModel: string; AStyle: TReviewStyle;
                            const AText: string);
    procedure ChatAddDone(AIter: Integer; const AExec, ARev: string);
    procedure ChatAddError(const AMsg: string);
    procedure ChatAddCost(ATokens: Integer; ACost: Double);
    procedure ChatAddResult(const ACode: string; AIter: Integer;
                            const ARevName: string; AChars: Integer);
    procedure ChatScrollToBottom;
    procedure CopyToClipboard(const AText: string);
    function  ShortName(const AName: string): string;

    // --- Thinking buffer helpers ---
    procedure FlushThinking;

    // --- Engine event bridges ---
    // All called via TThread.Synchronize — already on main thread.
    procedure EngThink(const AModel, AMsg: string);
    procedure EngPhase(APhase: TLoopPhase; AIter, AMaxIter: Integer);
    procedure EngCode(const ACode: string; AIteration: Integer; AIsDraft: Boolean);
    procedure EngReview(const AReview: string; AIteration: Integer;
                        AApproved: Boolean; const AReviewer: string);
    procedure EngDone(const ACode: string; AIter: Integer;
                      const AExec, ARev: string);
    procedure EngError(const AMsg: string);
    procedure EngTokens(ATokens: Integer; ACost: Double);

    // --- State ---
    procedure SetRunning(AVal: Boolean);
    procedure UpdateSidebar(const APhase: string; AIter, AMax: Integer);

    // --- Event handlers ---
    procedure OnRunClick(Sender: TObject);
    procedure OnClearClick(Sender: TObject);
    procedure OnSettingsClick(Sender: TObject);
    procedure OnSettBackClick(Sender: TObject);
    procedure OnResetClick(Sender: TObject);
    procedure OnMemoChange(Sender: TObject);

    procedure OnSettBtnMouseEnter(Sender: TObject);
    procedure OnSettBtnMouseLeave(Sender: TObject);
    procedure OnRunBtnMouseEnter(Sender: TObject);
    procedure OnRunBtnMouseLeave(Sender: TObject);
    procedure OnClearBtnMouseEnter(Sender: TObject);
    procedure OnClearBtnMouseLeave(Sender: TObject);
    procedure OnBackBtnMouseEnter(Sender: TObject);
    procedure OnBackBtnMouseLeave(Sender: TObject);
    procedure OnResetBtnMouseEnter(Sender: TObject);
    procedure OnResetBtnMouseLeave(Sender: TObject);
    procedure OnCopyLblClick(Sender: TObject);
    procedure OnCodeViewResized(Sender: TObject);
    procedure OnSettingsHideFinish(Sender: TObject);
    procedure ApplyDarkTitleBar;

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  end;

var
  frmMain: TfrmMain;

implementation

// ===========================================================================
//  TChatBubble — collapsible bubble toggle (code + review)
// ===========================================================================

constructor TChatBubble.Create(AOwner: TfrmMain; ABubble: TRectangle;
  AChevron: TLabel; ABody: TRectangle; ACollH, AExpandH: Single);
begin
  inherited Create(ABubble); // bubble owns us, gets freed when bubble dies
  FIsOpen     := False;
  FBubbleRect := ABubble;
  FChevronLbl := AChevron;
  FBodyRect   := ABody;
  FCollH      := ACollH;
  FExpandH    := AExpandH;
  FOwner      := AOwner;
end;

procedure TChatBubble.HandleClick(Sender: TObject);
var
  OldH, NewH, Delta: Single;
begin
  FIsOpen := not FIsOpen;

  if FIsOpen then
  begin
    // Restore body height so Align=Top allocates space, then show
    FBodyRect.Height := FExpandH - FCollH;
    FBodyRect.Visible  := True;
    FBodyRect.HitTest  := True;
    FChevronLbl.Text   := STR_CHEVRON_OPEN;
    NewH := FExpandH;
  end
  else
  begin
    // Collapse: height=0 so Align=Top takes no space, then hide
    FBodyRect.Height   := 0;
    FBodyRect.Visible  := False;
    FBodyRect.HitTest  := False;
    FChevronLbl.Text   := STR_CHEVRON_COLL;
    NewH := FCollH;
  end;

  OldH := FBubbleRect.Height;
  FBubbleRect.Height := NewH;
  Delta := NewH - OldH;
  FOwner.RecalcBubblesFrom(FBubbleRect, Delta);
end;

// ===========================================================================
//  Styles
// ===========================================================================

procedure TfrmMain.LoadStyle;
begin
  TStyleManager.SetStyleFromFile(
    ExtractFilePath(ParamStr(0)) + PATH_STYLES + FILE_STYLE
  );
end;

procedure TfrmMain.ApplyDarkTitleBar;
{$IFDEF MSWINDOWS}
var
  Value: BOOL;
begin
  Value := True;
  DwmSetWindowAttribute(
    FormToHWND(Self),
    DWMWA_USE_IMMERSIVE_DARK_MODE,
    @Value,
    SizeOf(Value)
  );
{$ELSE}
begin
{$ENDIF}
end;

// ===========================================================================
//  Constructor / Destructor
// ===========================================================================

constructor TfrmMain.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  LoadStyle;
  Caption  := APP_NAME + ' ' + APP_VERSION;
  Width    := FORM_W;
  Height   := FORM_H;
  Position := TFormPosition.ScreenCenter;
  Constraints.MinWidth  := FORM_MIN_W;
  Constraints.MinHeight := FORM_MIN_H;
  Fill.Color := CLR_BG;
  Fill.Kind  := TBrushKind.Solid;

  FThinkBuf    := TStringBuilder.Create;
  FThinkModel  := '';
  FChatBubbles := TList<TFmxObject>.Create;
  FRunning     := False;
  FCurrentIter := 0;
  FMaxIter     := 3;

  FConfig := TLoopConfig.Create;
  TLoopConfigIO.Load(TLoopConfigIO.DefaultFileName, FConfig);

  FEngine := TLoopEngine.Create;
  FEngine.SetProviders(FConfig);
  FEngine.SetModels(FConfig);
  FEngine.OnThink  := EngThink;
  FEngine.OnPhase  := EngPhase;
  FEngine.OnCode   := EngCode;
  FEngine.OnReview := EngReview;
  FEngine.OnDone   := EngDone;
  FEngine.OnError  := EngError;
  FEngine.OnTokens := EngTokens;

  Application.ShowHint := True;

  BuildSidebar;
  BuildMain;
  BuildSettingsOverlay;
  FillCombos;
  SyncConfigToUI;
  ApplyDarkTitleBar;
end;

destructor TfrmMain.Destroy;
begin
  FEngine.Free;
  FConfig.Free;
  FChatBubbles.Free; // non-owning list — FMX owns controls via Parent
  FThinkBuf.Free;
  inherited;
end;

// ===========================================================================
//  Build helpers
// ===========================================================================

function TfrmMain.MkRect(AParent: TFmxObject; AAlign: TAlignLayout;
  AColor: TAlphaColor; AW, AH: Single): TRectangle;
begin
  Result := TRectangle.Create(AParent);
  Result.Parent := AParent;
  Result.Align := AAlign;
  Result.Fill.Color := AColor;
  Result.Stroke.Kind := TBrushKind.None;
  if AW > 0 then Result.Width  := AW;
  if AH > 0 then Result.Height := AH;
end;

function TfrmMain.MkLbl(AParent: TFmxObject; const ATxt: string;
  ASz: Single; AColor: TAlphaColor; ABold: Boolean): TLabel;
begin
  Result := TLabel.Create(AParent);
  Result.Parent := AParent;
  Result.Text := ATxt;
  Result.FontColor := AColor;
  Result.Font.Size := ASz;
  if ABold then
    Result.Font.Style := [TFontStyle.fsBold];
end;

function TfrmMain.MkLine(AParent: TFmxObject; AAlign: TAlignLayout): TRectangle;
begin
  Result := MkRect(AParent, AAlign, CLR_BORDER, 0, 1);
end;

function TfrmMain.MkRectBtn(AParent: TFmxObject; const ATxt: string;
  AColor: TAlphaColor; AW: Single): TRectangle;
var
  Lbl: TLabel;
begin
  Result := TRectangle.Create(AParent);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Right;
  Result.Width := AW;
  Result.Height := BTN_H;
  Result.Fill.Color := AColor;
  Result.Stroke.Kind := TBrushKind.None;
  Result.XRadius := CORNER_MD;
  Result.YRadius := CORNER_MD;
  Result.Cursor := crHandPoint;
  Result.Margins.Left := 6;

  Lbl := TLabel.Create(Result);
  Lbl.Parent := Result;
  Lbl.Align := TAlignLayout.Client;
  Lbl.Text := ATxt;
  Lbl.FontColor := TAlphaColorRec.White;
  Lbl.Font.Size := FONT_MD;
  Lbl.Font.Style := [TFontStyle.fsBold];
  Lbl.TextSettings.HorzAlign := TTextAlign.Center;
  Lbl.TextSettings.VertAlign := TTextAlign.Center;
  Lbl.HitTest := False;
end;

function TfrmMain.MkEdit(AParent: TFmxObject; const AHint: string;
  APassword: Boolean): TEdit;
begin
  Result := TEdit.Create(AParent);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Right;
  Result.Width := 220;
  Result.TextPrompt := AHint;
  Result.Password := APassword;
end;

function TfrmMain.MkCombo(AParent: TFmxObject; AW: Single): TComboBox;
begin
  Result := TComboBox.Create(AParent);
  Result.Parent := AParent;
  Result.Width := AW;
end;

// ===========================================================================
//  Build Sidebar
// ===========================================================================

procedure TfrmMain.BuildSidebar;

  procedure BuildLogoRow;
  var
    LayLogo :TRectangle;
    ImgLogo :TImage;
  begin
    LayLogo := MkRect(FRectSidebar, TAlignLayout.Top, CLR_SIDEBAR, 0, LOGO_H);
    LayLogo.Padding.Left  := 14;
    LayLogo.Padding.Right := 14;

    ImgLogo := TImage.Create(LayLogo);
    ImgLogo.Parent   := LayLogo;
    ImgLogo.Align    := TAlignLayout.Center;
    ImgLogo.Width    := LOGO_IMG_W;
    ImgLogo.Height   := LOGO_IMG_H;
    ImgLogo.WrapMode := TImageWrapMode.Fit;
    ImgLogo.Bitmap.LoadFromFile(ExtractFilePath(ParamStr(0)) + FILE_LOGO);

    MkLine(FRectSidebar, TAlignLayout.Top);
  end;

  procedure BuildStatusBlock;
  begin
    FRectStatus := MkRect(FRectSidebar, TAlignLayout.Top, CLR_SIDEBAR, 0, STATUS_H);
    FRectStatus.Margins.Left   := 10;
    FRectStatus.Margins.Right  := 10;
    FRectStatus.Margins.Top    := 8;
    FRectStatus.Margins.Bottom := 4;
    FRectStatus.XRadius := CORNER_MD;
    FRectStatus.YRadius := CORNER_MD;
    FRectStatus.Padding.Left  := 11;
    FRectStatus.Padding.Right := 11;

    FLblRunTitle := MkLbl(FRectStatus, '', FONT_MD, TAlphaColor(CLR_ACCENT), True);
    FLblRunTitle.Align  := TAlignLayout.Top;
    FLblRunTitle.Height := 22;
    FLblRunTitle.Margins.Top := 9;

    FLblRunIter := MkLbl(FRectStatus, STR_READY, FONT_SM, CLR_MUTE);
    FLblRunIter.Align  := TAlignLayout.Top;
    FLblRunIter.Height := 18;

    FPrgRun := TProgressBar.Create(FRectStatus);
    FPrgRun.Parent := FRectStatus;
    FPrgRun.Align  := TAlignLayout.Bottom;
    FPrgRun.Height := PROGRESS_H;
    FPrgRun.Margins.Bottom := 11;
    FPrgRun.Min   := 0;
    FPrgRun.Max   := 3;
    FPrgRun.Value := 0;
  end;

  procedure BuildSettingsFooter;
  var
    LayFoot :TRectangle;
    LblSett :TLabel;
  begin
    MkLine(FRectSidebar, TAlignLayout.Bottom);
    LayFoot := MkRect(FRectSidebar, TAlignLayout.Bottom, CLR_SIDEBAR, 0, SFOOTER_H);

    FRectSettBtn := MkRect(LayFoot, TAlignLayout.Client, CLR_SIDEBAR, 0, 0);
    FRectSettBtn.Margins.Left   := 8;
    FRectSettBtn.Margins.Right  := 8;
    FRectSettBtn.Margins.Top    := 9;
    FRectSettBtn.Margins.Bottom := 9;
    FRectSettBtn.XRadius := CORNER_SM;
    FRectSettBtn.YRadius := CORNER_SM;
    FRectSettBtn.Cursor       := crHandPoint;
    FRectSettBtn.OnClick      := OnSettingsClick;
    FRectSettBtn.OnMouseEnter := OnSettBtnMouseEnter;
    FRectSettBtn.OnMouseLeave := OnSettBtnMouseLeave;

    LblSett := MkLbl(FRectSettBtn, STR_SETTINGS, 12.5, CLR_DIM);
    LblSett.Align  := TAlignLayout.Client;
    LblSett.Margins.Left := 12;
    LblSett.TextSettings.HorzAlign := TTextAlign.Leading;
    LblSett.TextSettings.VertAlign := TTextAlign.Center;
    LblSett.HitTest := False;
  end;

begin
  FRectSidebar := MkRect(Self, TAlignLayout.Left, CLR_SIDEBAR, SIDEBAR_W, 0);
  BuildLogoRow;
  BuildStatusBlock;
  MkRect(FRectSidebar, TAlignLayout.Client, CLR_SIDEBAR, 0, 0); // history v0.4
  BuildSettingsFooter;
end;

// ===========================================================================
//  Build Main area
// ===========================================================================

procedure TfrmMain.BuildMain;

  procedure BuildChatArea(AParent: TLayout);
  begin
    FScrollChat := TVertScrollBox.Create(AParent);
    FScrollChat.Parent := AParent;
    FScrollChat.Align := TAlignLayout.Client;
    FScrollChat.ShowScrollBars := True;
    FScrollChat.StyleLookup := 'transparentscrollboxstyle';
  end;

  procedure BuildInputMemo(ABox: TRectangle);
  begin
    FMemoTask := TMemo.Create(ABox);
    FMemoTask.Parent := ABox;
    FMemoTask.Align := TAlignLayout.Client;
    FMemoTask.TextPrompt := STR_MEMO_PROMPT;
    FMemoTask.Font.Size := FONT_LG;
    FMemoTask.Height := MEMO_MIN_H;
    FMemoTask.OnChange := OnMemoChange;
    FMemoTask.StyleLookup := 'memostyle';
  end;

  procedure BuildInputFooter(ABox: TRectangle);
  var
    RectFooter :TRectangle;
    Spacer     :TLayout;
    LblArr     :TLabel;
  begin
    MkLine(ABox, TAlignLayout.Bottom);
    RectFooter := MkRect(ABox, TAlignLayout.Bottom, CLR_SURFACE, 0, IFOOTER_H);

    FRectRun := MkRectBtn(RectFooter, STR_BTN_RUN_ICON, CLR_ACCENT, BTN_RUN_W);
    FRectRun.Margins.Right  := 9;
    FRectRun.Margins.Top    := 8;
    FRectRun.Margins.Bottom := 8;
    FRectRun.OnClick      := OnRunClick;
    FRectRun.OnMouseEnter := OnRunBtnMouseEnter;
    FRectRun.OnMouseLeave := OnRunBtnMouseLeave;
    FRectRun.ShowHint := True;
    FRectRun.Hint := STR_HINT_RUN;
    FLblRunBtn := FRectRun.Children[0] as TLabel;

    FRectClear := MkRectBtn(RectFooter, STR_BTN_CLEAR, CLR_SURF2, BTN_CLEAR_W);
    FRectClear.Margins.Top    := 8;
    FRectClear.Margins.Bottom := 8;
    FRectClear.OnClick      := OnClearClick;
    FRectClear.OnMouseEnter := OnClearBtnMouseEnter;
    FRectClear.OnMouseLeave := OnClearBtnMouseLeave;
    FRectClear.ShowHint := True;
    FRectClear.Hint := STR_HINT_CLEAR;

    FCboIter := MkCombo(RectFooter, 54);
    FCboIter.Align := TAlignLayout.Right;
    FCboIter.Margins.Left  := 6;
    FCboIter.Margins.Right := 6;

    Spacer := TLayout.Create(RectFooter);
    Spacer.Parent := RectFooter;
    Spacer.Align := TAlignLayout.Client;

    FCboExec := MkCombo(RectFooter, 170);
    FCboExec.Align := TAlignLayout.Left;
    FCboExec.Margins.Left := 9;

    LblArr := MkLbl(RectFooter, '  '#$2192'  ', 11.5, CLR_MUTE);
    LblArr.Align := TAlignLayout.Left;
    LblArr.Width := 30;
    LblArr.TextSettings.VertAlign := TTextAlign.Center;

    FCboRev := MkCombo(RectFooter, 150);
    FCboRev.Align := TAlignLayout.Left;
  end;

  procedure BuildInputArea(AParent: TLayout);
  var
    RectInputBox :TRectangle;
  begin
    // Separator and FRectInput are Bottom-aligned directly on LayMain.
    MkLine(AParent, TAlignLayout.Bottom);

    FRectInput := MkRect(AParent, TAlignLayout.Bottom, CLR_BG, 0,
                          MEMO_MIN_H + IFOOTER_H + INPUT_PAD_H);

    RectInputBox := MkRect(FRectInput, TAlignLayout.Client, CLR_SURFACE, 0, 0);
    RectInputBox.Margins.Left   := 14;
    RectInputBox.Margins.Right  := 14;
    RectInputBox.Margins.Top    := 10;
    RectInputBox.Margins.Bottom := 10;
    RectInputBox.XRadius := CORNER_LG;
    RectInputBox.YRadius := CORNER_LG;
    RectInputBox.Stroke.Color := CLR_BORDER;
    RectInputBox.Stroke.Kind  := TBrushKind.Solid;

    BuildInputMemo(RectInputBox);
    BuildInputFooter(RectInputBox);
  end;

var
  LayMain: TLayout;
begin
  LayMain := TLayout.Create(Self);
  LayMain.Parent := Self;
  LayMain.Align := TAlignLayout.Client;

  // Input area sits at the bottom; chat takes the remaining Client space.
  BuildInputArea(LayMain);
  BuildChatArea(LayMain);
end;

// ===========================================================================
//  Build Settings overlay
// ===========================================================================

procedure TfrmMain.BuildSettingsOverlay;

  procedure AddSectionLabel(AScroll: TScrollBox; const ATxt: string);
  var
    L: TLabel;
  begin
    L := MkLbl(AScroll, ATxt, FONT_XS, CLR_MUTE);
    L.Align := TAlignLayout.Top;
    L.Height := 26;
    L.Margins.Left := 2;
    L.Margins.Top  := 8;
  end;

  function AddCard(AScroll: TScrollBox): TRectangle;
  begin
    Result := MkRect(AScroll, TAlignLayout.Top, CLR_SURFACE, 0, 0);
    Result.XRadius := CORNER_LG;
    Result.YRadius := CORNER_LG;
    Result.Stroke.Color := CLR_BORDER;
    Result.Stroke.Kind  := TBrushKind.Solid;
    Result.Margins.Bottom := 2;
  end;

  function AddRow(ACard: TRectangle; const AIcon, AName, ADesc: string): TLayout;
  var
    LblIcon :TLabel;
    LayInfo :TLayout;
    LblName :TLabel;
    LblDesc :TLabel;
    Sep     :TRectangle;
  begin
    ACard.Height := ACard.Height + SETTINGS_ROW_H;

    Result := TLayout.Create(ACard);
    Result.Parent := ACard;
    Result.Align := TAlignLayout.Top;
    Result.Height := SETTINGS_ROW_H;
    Result.Padding.Left   := 16;
    Result.Padding.Right  := 16;
    Result.Padding.Top    := 12;
    Result.Padding.Bottom := 12;

    if ACard.ChildrenCount > 1 then
    begin
      Sep := MkLine(ACard, TAlignLayout.Top);
      Sep.BringToFront;
    end;

    LblIcon := MkLbl(Result, AIcon, 14, CLR_DIM);
    LblIcon.Align := TAlignLayout.Left;
    LblIcon.Width := 28;
    LblIcon.TextSettings.HorzAlign := TTextAlign.Center;
    LblIcon.TextSettings.VertAlign := TTextAlign.Center;

    LayInfo := TLayout.Create(Result);
    LayInfo.Parent := Result;
    LayInfo.Align := TAlignLayout.Client;

    LblName := MkLbl(LayInfo, AName, FONT_LG, CLR_TEXT, True);
    LblName.Align := TAlignLayout.Top;
    LblName.Height := 22;

    if ADesc <> '' then
    begin
      LblDesc := MkLbl(LayInfo, ADesc, 11.5, CLR_MUTE);
      LblDesc.Align := TAlignLayout.Top;
      LblDesc.Height := 18;
    end;
  end;

  procedure BuildHeader;
  var
    RectHdr  :TRectangle;
    RectBack :TRectangle;
    LblBack  :TLabel;
    LblTitle :TLabel;
  begin
    RectHdr := MkRect(FRectSettings, TAlignLayout.Top, CLR_BG, 0, 50);
    MkLine(FRectSettings, TAlignLayout.Top);

    RectBack := MkRect(RectHdr, TAlignLayout.Left, CLR_BG, 44, 0);
    RectBack.Margins.Left := 14;
    RectBack.XRadius := CORNER_SM;
    RectBack.YRadius := CORNER_SM;
    RectBack.Cursor       := crHandPoint;
    RectBack.OnClick      := OnSettBackClick;
    RectBack.OnMouseEnter := OnBackBtnMouseEnter;
    RectBack.OnMouseLeave := OnBackBtnMouseLeave;

    LblBack := MkLbl(RectBack, #$2190, 18, CLR_DIM);
    LblBack.Align := TAlignLayout.Client;
    LblBack.TextSettings.HorzAlign := TTextAlign.Center;
    LblBack.TextSettings.VertAlign := TTextAlign.Center;
    LblBack.HitTest := False;

    LblTitle := MkLbl(RectHdr, 'Settings', 15, CLR_TEXT, True);
    LblTitle.Align := TAlignLayout.Client;
    LblTitle.Margins.Left := 8;
    LblTitle.TextSettings.VertAlign := TTextAlign.Center;
  end;

  procedure BuildBody;
  var
    Scroll :TScrollBox;
    Card   :TRectangle;
    Row    :TLayout;
    Pad    :TLayout;
  begin
    Scroll := TScrollBox.Create(FRectSettings);
    Scroll.Parent := FRectSettings;
    Scroll.Align := TAlignLayout.Client;
    Scroll.Padding.Left  := Max(0, (Width - 620) / 2);
    Scroll.Padding.Right := Scroll.Padding.Left;

    AddSectionLabel(Scroll, 'LOOP');
    Card := AddCard(Scroll);
    Row := AddRow(Card, #$1F501, 'Max Iterations', 'Generate '#$2192' Review cycles');
    FSpbIter := TSpinBox.Create(Row);
    FSpbIter.Parent := Row;
    FSpbIter.Align := TAlignLayout.Right;
    FSpbIter.Width := 80;
    FSpbIter.Min := 1;
    FSpbIter.Max := 10;
    FSpbIter.Value := 3;
    FSpbIter.Increment := 1;

    AddSectionLabel(Scroll, 'MODELS');
    Card := AddCard(Scroll);
    Row := AddRow(Card, #$26A1, 'Executor', 'Generates the code');
    FCboSExec := MkCombo(Row, 200);
    FCboSExec.Align := TAlignLayout.Right;
    Row := AddRow(Card, #$1F441, 'Reviewer', 'Reviews and approves');
    FCboSRev := MkCombo(Row, 200);
    FCboSRev.Align := TAlignLayout.Right;

    AddSectionLabel(Scroll, 'PROVIDERS');
    Card := AddCard(Scroll);
    Row := AddRow(Card, #$1F511, 'OpenRouter API key', 'sk-or-'#$2026);
    FEdtORKey := MkEdit(Row, 'sk-or-v1-'#$2026, True);
    FEdtORKey.Width := 220;
    Row := AddRow(Card, #$1F511, 'OpenAI API key', 'sk-'#$2026);
    FEdtOAIKey := MkEdit(Row, 'sk-'#$2026, True);
    FEdtOAIKey.Width := 220;
    Row := AddRow(Card, #$1F99A, 'Ollama URL', 'Local endpoint');
    FEdtOllamaURL := MkEdit(Row, 'http://localhost:11434');
    FEdtOllamaURL.Width := 220;

    Pad := TLayout.Create(Scroll);
    Pad.Parent := Scroll;
    Pad.Align := TAlignLayout.Top;
    Pad.Height := 16;
  end;

  procedure BuildFooter;
  var
    RectFooter :TRectangle;
    BtnReset   :TRectangle;
  begin
    RectFooter := MkRect(FRectSettings, TAlignLayout.Bottom, CLR_BG, 0, 52);
    MkLine(FRectSettings, TAlignLayout.Bottom);

    BtnReset := MkRectBtn(RectFooter, 'Reset to defaults', CLR_SURFACE, 160);
    BtnReset.Margins.Right  := 20;
    BtnReset.Margins.Top    := 10;
    BtnReset.Margins.Bottom := 10;
    BtnReset.OnClick      := OnResetClick;
    BtnReset.OnMouseEnter := OnResetBtnMouseEnter;
    BtnReset.OnMouseLeave := OnResetBtnMouseLeave;
    (BtnReset.Children[0] as TLabel).FontColor := CLR_DIM;
  end;

begin
  FRectSettings := MkRect(Self, TAlignLayout.None, CLR_BG, 0, 0);
  FRectSettings.SetBounds(Width, 0, Width, Height);
  FRectSettings.Visible := False;
  FRectSettings.BringToFront;

  BuildHeader;
  BuildBody;
  BuildFooter;
end;

// ===========================================================================
//  FillCombos / Sync
// ===========================================================================

procedure TfrmMain.FillCombos;
var
  I: Integer;
begin
  FCboExec.Items.Clear;
  FCboRev.Items.Clear;
  FCboSExec.Items.Clear;
  FCboSRev.Items.Clear;
  for I := 0 to FConfig.ModelCount - 1 do
  begin
    FCboExec.Items.Add(ShortName(FConfig.GetModel(I).DisplayName));
    FCboRev.Items.Add(ShortName(FConfig.GetModel(I).DisplayName));
    FCboSExec.Items.Add(FConfig.GetModel(I).DisplayName);
    FCboSRev.Items.Add(FConfig.GetModel(I).DisplayName);
  end;
  FCboIter.Items.Clear;
  for I := 1 to 10 do
    FCboIter.Items.Add(IntToStr(I));
end;

procedure TfrmMain.SyncConfigToUI;
var
  S: TLoopSettings;
begin
  S := FConfig.Settings;
  FCboExec.ItemIndex  := S.ExecutorIdx;
  FCboRev.ItemIndex   := S.ReviewerIdx;
  FCboIter.ItemIndex  := S.MaxIterations - 1;
  FCboSExec.ItemIndex := S.ExecutorIdx;
  FCboSRev.ItemIndex  := S.ReviewerIdx;
  FSpbIter.Value      := S.MaxIterations;
  if FConfig.ProviderCount > 2 then
    FEdtORKey.Text := FConfig.GetProvider(2).APIKey;
  if FConfig.ProviderCount > 1 then
    FEdtOAIKey.Text := FConfig.GetProvider(1).APIKey;
  if FConfig.ProviderCount > 0 then
    FEdtOllamaURL.Text := FConfig.GetProvider(0).BaseURL;
end;

procedure TfrmMain.SyncUIToConfig;
var
  S: TLoopSettings;
  P: TProviderConfig;
begin
  S.ExecutorIdx   := FCboSExec.ItemIndex;
  S.ReviewerIdx   := FCboSRev.ItemIndex;
  S.MaxIterations := Round(FSpbIter.Value);
  FConfig.Settings := S;
  if FConfig.ProviderCount > 0 then
  begin
    P := FConfig.GetProvider(0);
    P.BaseURL := FEdtOllamaURL.Text;
    FConfig.UpdateProvider(0, P);
  end;
  if FConfig.ProviderCount > 1 then
  begin
    P := FConfig.GetProvider(1);
    P.APIKey := FEdtOAIKey.Text;
    FConfig.UpdateProvider(1, P);
  end;
  if FConfig.ProviderCount > 2 then
  begin
    P := FConfig.GetProvider(2);
    P.APIKey := FEdtORKey.Text;
    FConfig.UpdateProvider(2, P);
  end;
  FCboExec.ItemIndex := S.ExecutorIdx;
  FCboRev.ItemIndex  := S.ReviewerIdx;
  FCboIter.ItemIndex := S.MaxIterations - 1;
  TLoopConfigIO.Save(TLoopConfigIO.DefaultFileName, FConfig);
  FEngine.SetProviders(FConfig);
  FEngine.SetModels(FConfig);
end;

// ===========================================================================
//  Chat helpers
// ===========================================================================

function TfrmMain.MkBubble(AColor: TAlphaColor; AHeight: Single): TRectangle;
begin
  Result := TRectangle.Create(FScrollChat);
  Result.Parent := FScrollChat;
  Result.Align := TAlignLayout.None;
  Result.Width := FScrollChat.Width - BUBBLE_MH * 2;
  Result.Height := AHeight;
  Result.Position.X := BUBBLE_MH;
  Result.Position.Y := FNextChatY + BUBBLE_MV;
  Result.Fill.Color := AColor;
  Result.Stroke.Kind := TBrushKind.None;
  Result.XRadius := 8;
  Result.YRadius := 8;
  Result.Margins.Left   := BUBBLE_MH;
  Result.Margins.Right  := BUBBLE_MH;
  Result.Margins.Top    := BUBBLE_MV;
  Result.Margins.Bottom := BUBBLE_MV;
  FNextChatY := Result.Position.Y + AHeight + BUBBLE_MV;
  FChatBubbles.Add(Result);
end;

procedure TfrmMain.RecalcBubblesFrom(AFrom: TFmxObject; ADelta: Single);
var
  Found :Boolean;
  Ctrl  :TFmxObject;
  I     :Integer;
begin
  Found := False;
  for I := 0 to FChatBubbles.Count - 1 do
  begin
    Ctrl := FChatBubbles[I];
    if Ctrl = AFrom then
    begin
      Found := True;
      Continue;
    end;
    if Found then
      TControl(Ctrl).Position.Y := TControl(Ctrl).Position.Y + ADelta;
  end;
  FNextChatY := FNextChatY + ADelta;
end;

procedure TfrmMain.ChatClear;
var
  Obj: TFmxObject;
begin
  for Obj in FChatBubbles do
    Obj.Free;
  FChatBubbles.Clear;
  FThinkBuf.Clear;
  FThinkModel  := '';
  FCurrentIter := 0;
  FNextChatY   := 0;
end;

procedure TfrmMain.ChatScrollToBottom;
var
  CB   :TRectF;
  MaxY :Single;
begin
  CB   := FScrollChat.ContentBounds;
  MaxY := Max(0, CB.Bottom - FScrollChat.Height);
  FScrollChat.ViewportPosition := PointF(0, MaxY);
end;

procedure TfrmMain.CopyToClipboard(const AText: string);
var
  Svc: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(
       IFMXClipboardService, IInterface(Svc)) then
    Svc.SetClipboard(AText);
end;

function TfrmMain.ShortName(const AName: string): string;
var
  P: Integer;
begin
  P := Pos(' (', AName);
  if P > 0 then
    Result := Trim(Copy(AName, 1, P - 1))
  else
    Result := Trim(AName);
end;

// ---------------------------------------------------------------------------
//  ChatAddIterHeader — thin separator between iterations
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddIterHeader(ANum, AMax: Integer);
var
  Lbl: TLabel;
begin
  Lbl := TLabel.Create(FScrollChat);
  Lbl.Parent := FScrollChat;
  Lbl.Align := TAlignLayout.None;
  Lbl.Width := FScrollChat.Width - BUBBLE_MH * 2;
  Lbl.Height := 20;
  Lbl.Position.X := BUBBLE_MH;
  Lbl.Position.Y := FNextChatY + 14;
  Lbl.Text := Format(STR_FMT_ITER_HDR, [ANum, AMax]);
  Lbl.Font.Size := 10;
  Lbl.FontColor := CLR_MUTE;
  Lbl.TextSettings.HorzAlign := TTextAlign.Center;
  FNextChatY := Lbl.Position.Y + Lbl.Height + 4;
  FChatBubbles.Add(Lbl);
  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddTask — right-aligned task bubble, collapsible
//  Shows first line collapsed; full text on click.
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddTask(const AText: string);
var
  BubbleW    :Single;
  BubbleRect :TRectangle;
  TagLbl     :TLabel;
  PreviewLbl :TLabel;
  BodyLbl    :TLabel;
  ChevronLbl :TLabel;
  HeaderLay  :TLayout;
  BodyRect   :TRectangle;
  FirstLine  :string;
  ExpandH    :Single;
  LineCount  :Integer;
  Bubble     :TChatBubble;
begin
  if AText.Trim = '' then Exit;

  // First line for preview
  FirstLine := AText;
  if Pos(#10, FirstLine) > 0 then
    FirstLine := Copy(FirstLine, 1, Pos(#10, FirstLine) - 1);
  if Length(FirstLine) > 90 then
    FirstLine := Copy(FirstLine, 1, 90) + #$2026;

  LineCount := Max(3, AText.CountChar(#10) + 2);
  ExpandH   := TASK_H_COLL + LineCount * 18 + 16;

  BubbleW := Round((FScrollChat.Width - BUBBLE_MH * 2) * 0.62);

  // Build bubble positioned right
  BubbleRect := TRectangle.Create(FScrollChat);
  BubbleRect.Parent := FScrollChat;
  BubbleRect.Align := TAlignLayout.None;
  BubbleRect.Width  := BubbleW;
  BubbleRect.Height := TASK_H_COLL;
  BubbleRect.Position.X := FScrollChat.Width - BUBBLE_MH - BubbleW;
  BubbleRect.Position.Y := FNextChatY + BUBBLE_MV;
  BubbleRect.Fill.Color := CLR_TASK_BG;
  BubbleRect.Stroke.Kind := TBrushKind.None;
  BubbleRect.XRadius := 12;
  BubbleRect.YRadius := 12;
  BubbleRect.ClipChildren := True;
  BubbleRect.Cursor := crHandPoint;
  FNextChatY := BubbleRect.Position.Y + TASK_H_COLL + BUBBLE_MV;
  FChatBubbles.Add(BubbleRect);

  // Header row: TASK label + chevron
  HeaderLay := TLayout.Create(BubbleRect);
  HeaderLay.Parent := BubbleRect;
  HeaderLay.Align := TAlignLayout.Top;
  HeaderLay.Height := 22;
  HeaderLay.Padding.Left  := 10;
  HeaderLay.Padding.Right := 8;
  HeaderLay.Padding.Top   := 6;

  TagLbl := MkLbl(HeaderLay, STR_TASK_TAG, FONT_XS, TAlphaColor(CLR_ACCENT), True);
  TagLbl.Align := TAlignLayout.Left;
  TagLbl.Width := 40;
  TagLbl.TextSettings.VertAlign := TTextAlign.Center;
  TagLbl.HitTest := False;

  ChevronLbl := MkLbl(HeaderLay, STR_CHEVRON_COLL, FONT_XS, CLR_DIM);
  ChevronLbl.Align := TAlignLayout.Right;
  ChevronLbl.Width := 18;
  ChevronLbl.TextSettings.HorzAlign := TTextAlign.Trailing;
  ChevronLbl.TextSettings.VertAlign := TTextAlign.Center;
  ChevronLbl.HitTest := False;

  // Preview line (collapsed state)
  PreviewLbl := MkLbl(BubbleRect, FirstLine, FONT_SM, CLR_DIM);
  PreviewLbl.Align := TAlignLayout.Top;
  PreviewLbl.Height := 18;
  PreviewLbl.Margins.Left := 10;
  PreviewLbl.Margins.Right := 8;
  PreviewLbl.Margins.Bottom := 6;
  PreviewLbl.TextSettings.HorzAlign := TTextAlign.Leading;
  PreviewLbl.TextSettings.VertAlign := TTextAlign.Center;
  PreviewLbl.HitTest := False;

  // Body (expanded state, initially hidden — Height=0 keeps Align=Top from pushing layout)
  BodyRect := MkRect(BubbleRect, TAlignLayout.Top, CLR_TASK_BG, 0, 0);
  BodyRect.Stroke.Kind := TBrushKind.None;
  BodyRect.Visible  := False;
  BodyRect.HitTest  := False;
  BodyRect.Padding.Left  := 10;
  BodyRect.Padding.Right := 8;
  BodyRect.Padding.Top   := 4;

  BodyLbl := MkLbl(BodyRect, AText, FONT_SM, CLR_TEXT);
  BodyLbl.Align := TAlignLayout.Client;
  BodyLbl.WordWrap := True;
  BodyLbl.TextSettings.HorzAlign := TTextAlign.Leading;
  BodyLbl.TextSettings.VertAlign := TTextAlign.Leading;
  BodyLbl.HitTest := False;

  // Wire up toggle
  Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLbl, BodyRect,
                               TASK_H_COLL, ExpandH);
  BubbleRect.OnClick := Bubble.HandleClick;
  HeaderLay.OnClick  := Bubble.HandleClick;
  PreviewLbl.HitTest := False;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddThinkingText — plain dim text row "-> Model thinking..."
//  No bubble, no toggle. Just a label, like a status whisper.
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddThinkingText(const AExecutor: string);
var
  Lbl: TLabel;
begin
  if AExecutor.Trim = '' then Exit;

  Lbl := TLabel.Create(FScrollChat);
  Lbl.Parent := FScrollChat;
  Lbl.Align := TAlignLayout.None;
  Lbl.Width := FScrollChat.Width - BUBBLE_MH * 2;
  Lbl.Height := 20;
  Lbl.Position.X := BUBBLE_MH;
  Lbl.Position.Y := FNextChatY + 6;
  Lbl.Text := STR_THINK_ARROW + ' ' + AExecutor + STR_THINK_SUFFIX;
  Lbl.Font.Size := FONT_XS;
  Lbl.Font.Style := [TFontStyle.fsItalic];
  Lbl.FontColor := CLR_MUTE;
  Lbl.TextSettings.HorzAlign := TTextAlign.Leading;
  Lbl.HitTest := False;
  FNextChatY := Lbl.Position.Y + Lbl.Height + 4;
  FChatBubbles.Add(Lbl);
  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddCode — dark code block, collapsible (closed by default)
//  AIteration=0 -> 'draft' badge; >0 -> 'v2','v3',... badge
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddCode(const ACode: string; AIteration: Integer);
var
  BubbleRect  :TRectangle;
  HeaderLay   :TLayout;
  BadgeRect   :TRectangle;
  BadgeLbl    :TLabel;
  ModelLbl    :TLabel;
  CopyLbl     :TLabel;
  ChevronLbl  :TLabel;
  BodyRect    :TRectangle;
  CV          :TCodeView;
  LineCount   :Integer;
  EstCodeH    :Single;
  CollH       :Single;
  ExpandH     :Single;
  CodeCapture :string;
  Bubble      :TChatBubble;
begin
  if ACode.Trim = '' then Exit;

  LineCount := Max(1, ACode.CountChar(#10) + 1);
  EstCodeH  := LineCount * CV_LINE_H_EST + CV_PAD_V * 2;
  CollH     := CODE_BUBBLE_COLL_H;
  ExpandH   := CollH + EstCodeH;

  BubbleRect := MkBubble(CCLR_BG, CollH);
  BubbleRect.ClipChildren := True;
  BubbleRect.Cursor := crHandPoint;

  // Header strip
  HeaderLay := TLayout.Create(BubbleRect);
  HeaderLay.Parent := BubbleRect;
  HeaderLay.Align := TAlignLayout.Top;
  HeaderLay.Height := CODE_BUBBLE_COLL_H;
  HeaderLay.Padding.Left   := 12;
  HeaderLay.Padding.Right  := 10;
  HeaderLay.Padding.Top    := 7;
  HeaderLay.Padding.Bottom := 7;

  // Badge pill
  BadgeRect := TRectangle.Create(HeaderLay);
  BadgeRect.Parent := HeaderLay;
  BadgeRect.Align := TAlignLayout.Left;
  BadgeRect.Width := 44;
  BadgeRect.Margins.Right := 8;
  BadgeRect.XRadius := 10;
  BadgeRect.YRadius := 10;
  BadgeRect.Stroke.Kind := TBrushKind.None;
  if AIteration = 0 then
  begin
    BadgeRect.Fill.Color := CLR_BADGE_DRAFT;
    BadgeLbl := MkLbl(BadgeRect, 'draft', 9.5, CLR_ACCENT);
  end
  else
  begin
    BadgeRect.Fill.Color := CLR_BADGE_FINAL;
    BadgeLbl := MkLbl(BadgeRect, 'v' + IntToStr(AIteration + 1), 9.5, CLR_GREEN);
  end;
  BadgeLbl.Align := TAlignLayout.Client;
  BadgeLbl.TextSettings.HorzAlign := TTextAlign.Center;
  BadgeLbl.TextSettings.VertAlign := TTextAlign.Center;
  BadgeLbl.HitTest := False;

  // Model name label (filled later by EngTokens — we show what we have)
  ModelLbl := MkLbl(HeaderLay, ShortName(FCboExec.Text), FONT_SM, CLR_DIM);
  ModelLbl.Align := TAlignLayout.Client;
  ModelLbl.TextSettings.VertAlign := TTextAlign.Center;
  ModelLbl.HitTest := False;

  // Chevron toggle
  ChevronLbl := MkLbl(HeaderLay, STR_CHEVRON_COLL, FONT_SM, CLR_MUTE);
  ChevronLbl.Align := TAlignLayout.Right;
  ChevronLbl.Width := 22;
  ChevronLbl.TextSettings.HorzAlign := TTextAlign.Trailing;
  ChevronLbl.TextSettings.VertAlign := TTextAlign.Center;
  ChevronLbl.HitTest := False;

  // Copy button
  CodeCapture := ACode;
  CopyLbl := MkLbl(HeaderLay, STR_COPY_CODE, FONT_SM, CLR_MUTE);
  CopyLbl.Align := TAlignLayout.Right;
  CopyLbl.Width := 48;
  CopyLbl.Margins.Right := 4;
  CopyLbl.TextSettings.HorzAlign := TTextAlign.Center;
  CopyLbl.TextSettings.VertAlign := TTextAlign.Center;
  CopyLbl.Cursor := crHandPoint;
  CopyLbl.HitTest := True;
  CopyLbl.TagString := CodeCapture;
  CopyLbl.OnClick   := OnCopyLblClick;

  // Body — code view (collapsed by default = hidden, Height=0 keeps Align=Top from pushing layout)
  BodyRect := MkRect(BubbleRect, TAlignLayout.Top, CCLR_BG, 0, 0);
  BodyRect.Stroke.Kind := TBrushKind.None;
  BodyRect.Visible  := False;
  BodyRect.HitTest  := False;

  // Wire toggle first so OnCodeViewResized has a valid TChatBubble reference
  Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLbl, BodyRect,
                               CollH, ExpandH);
  CV := TCodeView.Create(BodyRect);
  CV.Parent := BodyRect;
  CV.Align := TAlignLayout.Top;
  CV.TagObject := Bubble;
  CV.OnResized := OnCodeViewResized;
  CV.SetCode(ACode);
  // FExpandH is updated in OnCodeViewResized with real measured height
  HeaderLay.OnClick  := Bubble.HandleClick;
  BubbleRect.OnClick := Bubble.HandleClick;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddReview — three visual modes
//    rsRejection : red, collapsible — shows rejection reason
//    rsApproved  : green flat — approved but with text (rare path)
//    rsNoIssues  : green flat strip — no chevron, no expand
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddReview(const AModel: string; AStyle: TReviewStyle;
  const AText: string);
var
  BubbleRect  :TRectangle;
  HeaderLay   :TLayout;
  IconLbl     :TLabel;
  VerdictLbl  :TLabel;
  ChevronLbl  :TLabel;
  BodyRect    :TRectangle;
  BodyLbl     :TLabel;
  BgColor     :TAlphaColor;
  IconText    :string;
  IconColor   :TAlphaColor;
  VerdictText :string;
  VerdictColor:TAlphaColor;
  LineCount   :Integer;
  ExpandH     :Single;
  Bubble      :TChatBubble;
begin
  BgColor := CLR_REV_REJECT_BG;
  IconColor := TAlphaColor(CLR_REV_REJECT_ICO);
  VerdictColor := TAlphaColor(CLR_REV_REJECT_ICO);
  case AStyle of
    rsRejection:
    begin
      BgColor      := CLR_REV_REJECT_BG;
      IconText     := #$2717; // ✗
      IconColor    := TAlphaColor(CLR_REV_REJECT_ICO);
      VerdictText  := AModel + ' ' + 'rejected result';
      VerdictColor := TAlphaColor(CLR_REV_REJECT_ICO);
    end;
    rsApproved:
    begin
      BgColor      := CLR_REV_OK;
      IconText     := #$2713; // ✓
      IconColor    := CLR_GREEN;
      VerdictText  := AModel + ': approved';
      VerdictColor := CLR_GREEN;
    end;
    rsNoIssues:
    begin
      BgColor      := CLR_REV_NOISS_BG;
      IconText     := #$2713; // ✓
      IconColor    := CLR_GREEN;
      VerdictText  := AModel + ': NO_ISSUES';
      VerdictColor := CLR_GREEN;
    end;
  end;

  BubbleRect := MkBubble(BgColor, REVIEW_BUBBLE_H);
  BubbleRect.ClipChildren := True;

  // Header
  HeaderLay := TLayout.Create(BubbleRect);
  HeaderLay.Parent := BubbleRect;
  HeaderLay.Align := TAlignLayout.Top;
  HeaderLay.Height := REVIEW_BUBBLE_H;
  HeaderLay.Padding.Left   := 12;
  HeaderLay.Padding.Right  := 10;
  HeaderLay.Padding.Top    := 0;
  HeaderLay.Padding.Bottom := 0;

  IconLbl := MkLbl(HeaderLay, IconText, FONT_MD, IconColor, True);
  IconLbl.Align := TAlignLayout.Left;
  IconLbl.Width := 22;
  IconLbl.TextSettings.HorzAlign := TTextAlign.Center;
  IconLbl.TextSettings.VertAlign := TTextAlign.Center;
  IconLbl.HitTest := False;

  VerdictLbl := MkLbl(HeaderLay, VerdictText, FONT_SM, VerdictColor, True);
  VerdictLbl.Align := TAlignLayout.Client;
  VerdictLbl.Margins.Left := 4;
  VerdictLbl.TextSettings.VertAlign := TTextAlign.Center;
  VerdictLbl.HitTest := False;

  // Only rejection bubbles are collapsible
  if AStyle = rsRejection then
  begin
    ChevronLbl := MkLbl(HeaderLay, STR_CHEVRON_COLL, FONT_SM, CLR_MUTE);
    ChevronLbl.Align := TAlignLayout.Right;
    ChevronLbl.Width := 20;
    ChevronLbl.TextSettings.HorzAlign := TTextAlign.Trailing;
    ChevronLbl.TextSettings.VertAlign := TTextAlign.Center;
    ChevronLbl.HitTest := False;

    LineCount := Max(2, AText.CountChar(#10) + 1 + Length(AText) div 60);
    ExpandH   := REVIEW_BUBBLE_H + LineCount * 16 + 20;

    BodyRect := MkRect(BubbleRect, TAlignLayout.Top, BgColor, 0, 0);
    BodyRect.Stroke.Kind := TBrushKind.None;
    BodyRect.Visible  := False;
    BodyRect.HitTest  := False;
    BodyRect.Padding.Left   := 12;
    BodyRect.Padding.Right  := 12;
    BodyRect.Padding.Top    := 6;
    BodyRect.Padding.Bottom := 8;

    BodyLbl := MkLbl(BodyRect, AText, FONT_XS, CLR_DIM);
    BodyLbl.Align := TAlignLayout.Client;
    BodyLbl.WordWrap := True;
    BodyLbl.TextSettings.HorzAlign := TTextAlign.Leading;
    BodyLbl.TextSettings.VertAlign := TTextAlign.Leading;
    BodyLbl.HitTest := False;

    Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLbl, BodyRect,
                                 REVIEW_BUBBLE_H, ExpandH);
    BubbleRect.Cursor := crHandPoint;
    HeaderLay.OnClick  := Bubble.HandleClick;
    BubbleRect.OnClick := Bubble.HandleClick;
  end;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddDone — slim green done bar
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddDone(AIter: Integer; const AExec, ARev: string);
var
  BubbleRect :TRectangle;
  Lbl        :TLabel;
begin
  BubbleRect := MkBubble(CLR_DONE_BG, 40);
  BubbleRect.Padding.Left  := 14;
  BubbleRect.Padding.Right := 14;

  Lbl := MkLbl(BubbleRect,
    Format('%s  Done '#$2014' %d iteration(s)  '#$00B7'  %s '#$2192' %s',
      [#$2713, AIter, AExec, ARev]),
    12, CLR_GREEN, True);
  Lbl.Align := TAlignLayout.Client;
  Lbl.TextSettings.VertAlign := TTextAlign.Center;
  Lbl.HitTest := False;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddError
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddError(const AMsg: string);
var
  BubbleRect :TRectangle;
  Lbl        :TLabel;
begin
  BubbleRect := MkBubble(CLR_ERR_BG, 40);
  BubbleRect.Padding.Left  := 14;
  BubbleRect.Padding.Right := 14;

  Lbl := MkLbl(BubbleRect, #$26A0 + '  ' + AMsg, 12, CLR_ORANGE);
  Lbl.Align := TAlignLayout.Client;
  Lbl.TextSettings.VertAlign := TTextAlign.Center;
  Lbl.HitTest := False;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddCost — inline token/cost label (right-aligned, dim)
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddCost(ATokens: Integer; ACost: Double);
var
  Lbl     :TLabel;
  CostStr :string;
begin
  CostStr := FormatFloat('0.0000', ACost);
  CostStr := CostStr.Replace(',', '.');

  Lbl := TLabel.Create(FScrollChat);
  Lbl.Parent := FScrollChat;
  Lbl.Align := TAlignLayout.None;
  Lbl.Width := FScrollChat.Width - BUBBLE_MH * 2;
  Lbl.Height := 20;
  Lbl.Position.X := BUBBLE_MH;
  Lbl.Position.Y := FNextChatY;
  Lbl.Text := Format('%d tokens  '#$00B7'  $%s', [ATokens, CostStr]);
  Lbl.Font.Size := 10;
  Lbl.FontColor := CLR_MUTE;
  Lbl.TextSettings.HorzAlign := TTextAlign.Trailing;
  Lbl.HitTest := False;
  FNextChatY := Lbl.Position.Y + Lbl.Height + 8;
  FChatBubbles.Add(Lbl);

  ChatScrollToBottom;
end;

// ===========================================================================
//  FlushThinking — resets the thinking buffer (text already emitted in EngThink)
// ===========================================================================

procedure TfrmMain.FlushThinking;
begin
  FThinkBuf.Clear;
  FThinkModel := '';
end;

// ---------------------------------------------------------------------------
//  ChatAddResult — final result bubble in the chat stream.
//  Blue accent border, dark background, collapsible TCodeView body.
//  Called by EngDone after ChatAddDone — this is the last bubble in the run.
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddResult(const ACode: string; AIter: Integer;
  const ARevName: string; AChars: Integer);
var
  BubbleRect  :TRectangle;
  HeaderLay   :TLayout;
  TitleLbl    :TLabel;
  SubLbl      :TLabel;
  CopyBtn     :TRectangle;
  FooterRect  :TRectangle;
  FooterLbl   :TLabel;
  BodyRect    :TRectangle;
  CV          :TCodeView;
  LineCount   :Integer;
  EstCodeH    :Single;
  CollH       :Single;
  ExpandH     :Single;
  SubText     :string;
  FootText    :string;
  CodeCapture :string;
  Bubble      :TChatBubble;
  ChevronLbl  :TLabel;
begin
  if ACode.Trim = '' then Exit;

  CollH    := RESULT_BUBBLE_COLL_H;
  LineCount := Max(1, ACode.CountChar(#10) + 1);
  EstCodeH  := LineCount * CV_LINE_H_EST + CV_PAD_V * 2;
  ExpandH   := CollH + EstCodeH;

  // Build bubble manually — result needs CLR_RESULT_BG, not a chat color param
  BubbleRect := TRectangle.Create(FScrollChat);
  BubbleRect.Parent := FScrollChat;
  BubbleRect.Align := TAlignLayout.None;
  BubbleRect.Width := FScrollChat.Width - BUBBLE_MH * 2;
  BubbleRect.Height := CollH;
  BubbleRect.Position.X := BUBBLE_MH;
  BubbleRect.Position.Y := FNextChatY + BUBBLE_MV;
  BubbleRect.Fill.Color := CLR_RESULT_BG;
  BubbleRect.Stroke.Kind := TBrushKind.None;
  BubbleRect.XRadius := CORNER_LG;
  BubbleRect.YRadius := CORNER_LG;
  BubbleRect.ClipChildren := True;
  BubbleRect.Cursor := crHandPoint;
  FNextChatY := BubbleRect.Position.Y + CollH + BUBBLE_MV;
  FChatBubbles.Add(BubbleRect);

  // --- Header ---
  HeaderLay := TLayout.Create(BubbleRect);
  HeaderLay.Parent := BubbleRect;
  HeaderLay.Align := TAlignLayout.Top;
  HeaderLay.Height := RESULT_BUBBLE_HDR_H;
  HeaderLay.Padding.Left   := 14;
  HeaderLay.Padding.Right  := 8;
  HeaderLay.Padding.Top    := 0;
  HeaderLay.Padding.Bottom := 0;

  TitleLbl := MkLbl(HeaderLay, STR_RESULT_TITLE, FONT_MD, TAlphaColor(CLR_ACCENT), True);
  TitleLbl.Align := TAlignLayout.Left;
  TitleLbl.Width := 120;
  TitleLbl.TextSettings.VertAlign := TTextAlign.Center;
  TitleLbl.HitTest := False;

  SubText := Format('%d iteration%s '#$00B7' approved',
    [AIter, IfThen(AIter = 1, '', 's')]);
  SubLbl := MkLbl(HeaderLay, SubText, FONT_XS, CLR_DIM);
  SubLbl.Align := TAlignLayout.Client;
  SubLbl.Margins.Left := 6;
  SubLbl.TextSettings.VertAlign := TTextAlign.Center;
  SubLbl.HitTest := False;

  // Chevron (right of header, before copy button)
  ChevronLbl := MkLbl(HeaderLay, STR_CHEVRON_COLL, FONT_SM, CLR_MUTE);
  ChevronLbl.Align := TAlignLayout.Right;
  ChevronLbl.Width := 22;
  ChevronLbl.TextSettings.HorzAlign := TTextAlign.Trailing;
  ChevronLbl.TextSettings.VertAlign := TTextAlign.Center;
  ChevronLbl.HitTest := False;

  // Copy button — TagString lives on the inner label (TRectangle has no TagString-aware click).
  // The label handles the click; CopyBtn.OnClick stays nil so the bubble toggle fires normally.
  CodeCapture := ACode;
  CopyBtn := MkRectBtn(HeaderLay, STR_COPY_CODE, CLR_SURF2, BTN_COPY_W);
  CopyBtn.Margins.Top    := 5;
  CopyBtn.Margins.Bottom := 5;
  CopyBtn.Margins.Right  := 4;
  CopyBtn.OnMouseEnter := OnClearBtnMouseEnter;
  CopyBtn.OnMouseLeave := OnClearBtnMouseLeave;

  // --- Footer strip (Bottom-aligned so it's always visible when collapsed) ---
  FooterRect := MkRect(BubbleRect, TAlignLayout.Bottom, CLR_RESULT_FOOT, 0, RESULT_BUBBLE_FOOT_H);
  FooterRect.Stroke.Kind := TBrushKind.None;
  FooterRect.Padding.Left  := 14;
  FooterRect.Padding.Right := 14;

  FootText := #$2713 + ' Approved by ' + ARevName;
  if AChars > 0 then
    FootText := FootText + '    ' + IntToStr(AChars) + ' chars';
  FooterLbl := MkLbl(FooterRect, FootText, FONT_XS, CLR_DIM);
  FooterLbl.Align := TAlignLayout.Client;
  FooterLbl.TextSettings.VertAlign := TTextAlign.Center;
  FooterLbl.HitTest := False;

  // --- Body: TCodeView, collapsible ---
  BodyRect := MkRect(BubbleRect, TAlignLayout.Top, CLR_RESULT_BG, 0, 0);
  BodyRect.Stroke.Kind := TBrushKind.None;
  BodyRect.Visible  := False;
  BodyRect.HitTest  := False;

  // Wire toggle before creating TCodeView (OnCodeViewResized needs TChatBubble)
  Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLbl, BodyRect,
                               CollH, ExpandH);
  CV := TCodeView.Create(BodyRect);
  CV.Parent := BodyRect;
  CV.Align := TAlignLayout.Top;
  CV.TagObject := Bubble;
  CV.OnResized := OnCodeViewResized;
  CV.SetCode(ACode);

  HeaderLay.OnClick  := Bubble.HandleClick;
  BubbleRect.OnClick := Bubble.HandleClick;

  // Wire copy: TagString on the label inside MkRectBtn, OnCopyLblClick handles it.
  (CopyBtn.Children[0] as TLabel).TagString := CodeCapture;
  (CopyBtn.Children[0] as TLabel).OnClick   := OnCopyLblClick;
  (CopyBtn.Children[0] as TLabel).HitTest   := True;
  (CopyBtn.Children[0] as TLabel).Cursor    := crHandPoint;

  // Result is the final deliverable — open it immediately.
  Bubble.HandleClick(nil);

  ChatScrollToBottom;
end;

// ===========================================================================
//  Engine event bridges
// ===========================================================================

procedure TfrmMain.EngThink(const AModel, AMsg: string);
begin
  // First OnThink in a phase: show "→ Model thinking..." immediately.
  // Subsequent calls just accumulate (buffer kept for potential future use).
  if FThinkModel = '' then
  begin
    FThinkModel := AModel;
    ChatAddThinkingText(AModel);
  end;
  FThinkBuf.AppendLine(AMsg);
end;

procedure TfrmMain.EngPhase(APhase: TLoopPhase; AIter, AMaxIter: Integer);
begin
  FCurrentIter := AIter;
  FMaxIter     := AMaxIter;

  FPrgRun.Max := AMaxIter * 2;
  case APhase of
    lpGenerating : FPrgRun.Value := 0;
    lpReviewing  : FPrgRun.Value := (AIter - 1) * 2 + 1;
    lpRefining   : FPrgRun.Value := AIter * 2;
  end;

  if (APhase = lpReviewing) and (AIter > 1) then
    ChatAddIterHeader(AIter, AMaxIter);

  case APhase of
    lpGenerating : UpdateSidebar(STR_PHASE_EXECUTOR, 0,     AMaxIter);
    lpReviewing  : UpdateSidebar(STR_PHASE_REVIEWER, AIter, AMaxIter);
    lpRefining   : UpdateSidebar(STR_PHASE_EXECUTOR, AIter, AMaxIter);
  end;
end;

procedure TfrmMain.EngCode(const ACode: string; AIteration: Integer;
  AIsDraft: Boolean);
begin
  FlushThinking;
  ChatAddCode(ACode, AIteration);
end;

procedure TfrmMain.EngReview(const AReview: string; AIteration: Integer;
  AApproved: Boolean; const AReviewer: string);
var
  Style :TReviewStyle;
begin
  FlushThinking;
  if AApproved then
  begin
    if Pos(NO_ISSUES_MARKER, AReview) > 0 then
      Style := rsNoIssues
    else
      Style := rsApproved;
  end
  else
    Style := rsRejection;
  ChatAddReview(ShortName(AReviewer), Style, AReview);
end;

procedure TfrmMain.EngDone(const ACode: string; AIter: Integer;
  const AExec, ARev: string);
begin
  FlushThinking;
  ChatAddDone(AIter, ShortName(AExec), ShortName(ARev));
  ChatAddResult(ACode, AIter, ShortName(ARev), Length(ACode));
  SetRunning(False);
end;

procedure TfrmMain.EngError(const AMsg: string);
begin
  ChatAddError(AMsg);
  SetRunning(False);
end;

procedure TfrmMain.EngTokens(ATokens: Integer; ACost: Double);
begin
  ChatAddCost(ATokens, ACost);
end;

// ===========================================================================
//  State helpers
// ===========================================================================

procedure TfrmMain.SetRunning(AVal: Boolean);
begin
  FRunning := AVal;
  FRectRun.HitTest := not AVal;
  FRectRun.Fill.Color := IfThen(AVal,
    TAlphaColor(CLR_SURF2), TAlphaColor(CLR_ACCENT));
  FLblRunBtn.Text := IfThen(AVal, STR_BTN_RUNNING, STR_BTN_RUN);
  FMemoTask.ReadOnly := AVal;
  FCboExec.Enabled := not AVal;
  FCboRev.Enabled  := not AVal;
  FCboIter.Enabled := not AVal;
  if not AVal then
  begin
    FPrgRun.Value := 0;
    UpdateSidebar(STR_PHASE_DONE, FCurrentIter, FMaxIter);
  end;
end;

procedure TfrmMain.UpdateSidebar(const APhase: string; AIter, AMax: Integer);
begin
  if FRunning then
  begin
    FRectStatus.Fill.Color := CLR_STATUS_BG;
    FLblRunTitle.Text := STR_RUNNING;
    FLblRunIter.Text  := Format(STR_FMT_ITERATION, [AIter, AMax, APhase]);
    FPrgRun.Max   := Max(1, AMax);
    FPrgRun.Value := Max(0, AIter);
  end
  else
  begin
    FRectStatus.Fill.Color := CLR_SIDEBAR;
    FLblRunTitle.Text := '';
    FLblRunIter.Text  := STR_READY;
    FPrgRun.Value := 0;
  end;
end;

// ===========================================================================
//  Event handlers
// ===========================================================================

procedure TfrmMain.OnRunClick(Sender: TObject);
var
  Task              :string;
  ExecIdx, RevIdx   :Integer;
  MaxIter           :Integer;
begin
  if FRunning then Exit;
  Task := FMemoTask.Text.Trim;
  if Task = '' then Exit;

  ExecIdx := Max(0, FCboExec.ItemIndex);
  RevIdx  := Max(0, FCboRev.ItemIndex);
  MaxIter := StrToIntDef(
    FCboIter.Items[Max(0, FCboIter.ItemIndex)], 3);

  FCurrentIter := 1;
  FMaxIter     := MaxIter;
  FThinkBuf.Clear;
  FThinkModel := '';

  SetRunning(True);
  UpdateSidebar(STR_PHASE_EXECUTOR, 1, MaxIter);
  ChatAddTask(Task);
  ChatAddIterHeader(1, MaxIter);

  FEngine.Run(Task, ExecIdx, RevIdx, MaxIter);
end;

procedure TfrmMain.OnClearClick(Sender: TObject);
begin
  if FRunning then Exit;
  ChatClear;
end;

procedure TfrmMain.OnSettingsClick(Sender: TObject);
begin
  SyncConfigToUI;
  FRectSettings.SetBounds(Width, 0, Width, Height);
  FRectSettings.Visible := True;
  TAnimator.AnimateFloat(FRectSettings, 'Position.X', 0, 0.22);
end;

procedure TfrmMain.OnSettBackClick(Sender: TObject);
var
  Anim: TFloatAnimation;
begin
  SyncUIToConfig;
  Anim := TFloatAnimation.Create(FRectSettings);
  Anim.Parent := FRectSettings;
  Anim.PropertyName := 'Position.X';
  Anim.StartValue := FRectSettings.Position.X;
  Anim.StopValue  := Width;
  Anim.Duration   := 0.22;
  Anim.AnimationType  := TAnimationType.Out;
  Anim.Interpolation  := TInterpolationType.Quadratic;
  Anim.OnFinish := OnSettingsHideFinish;
  Anim.Start;
end;

procedure TfrmMain.OnResetClick(Sender: TObject);
begin
  FConfig.SetDefaults;
  FillCombos;
  SyncConfigToUI;
end;

procedure TfrmMain.OnMemoChange(Sender: TObject);
var
  Lines :Integer;
  LineH :Single;
  NewH  :Single;
begin
  Lines := Max(2, Min(FMemoTask.Lines.Count, 6));
  LineH := FMemoTask.Font.Size * 1.5 + 2;
  NewH  := Ceil(LineH * Lines) + 16;
  NewH  := EnsureRange(NewH, MEMO_MIN_H, MEMO_MAX_H);
  if not SameValue(FMemoTask.Height, NewH, 0.5) then
  begin
    FMemoTask.Height  := NewH;
    FRectInput.Height := NewH + IFOOTER_H + INPUT_PAD_H;
  end;
end;

procedure TfrmMain.OnSettBtnMouseEnter(Sender: TObject);
begin
  FRectSettBtn.Fill.Color := CLR_SURFACE;
end;

procedure TfrmMain.OnSettBtnMouseLeave(Sender: TObject);
begin
  FRectSettBtn.Fill.Color := CLR_SIDEBAR;
end;

procedure TfrmMain.OnRunBtnMouseEnter(Sender: TObject);
begin
  if not FRunning then
    FRectRun.Fill.Color := CLR_RUN_HOVER;
end;

procedure TfrmMain.OnRunBtnMouseLeave(Sender: TObject);
begin
  if not FRunning then
    FRectRun.Fill.Color := CLR_ACCENT;
end;

procedure TfrmMain.OnClearBtnMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := CLR_CLEAR_HOVER;
end;

procedure TfrmMain.OnClearBtnMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := CLR_SURF2;
end;

procedure TfrmMain.OnBackBtnMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := CLR_SURFACE;
end;

procedure TfrmMain.OnBackBtnMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := CLR_BG;
end;

procedure TfrmMain.OnResetBtnMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := CLR_SURF2;
end;

procedure TfrmMain.OnResetBtnMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := CLR_SURFACE;
end;

procedure TfrmMain.OnCopyLblClick(Sender: TObject);
begin
  CopyToClipboard(TLabel(Sender).TagString);
end;

procedure TfrmMain.OnCodeViewResized(Sender: TObject);
var
  CV     :TCodeView;
  Bubble :TChatBubble;
  OldH   :Single;
  Delta  :Single;
begin
  CV := TCodeView(Sender);
  if not (CV.TagObject is TChatBubble) then Exit;

  Bubble := TChatBubble(CV.TagObject);
  Bubble.FExpandH := Bubble.FCollH + CV.Height;

  if Bubble.FIsOpen then
  begin
    Bubble.FBodyRect.Height := CV.Height;
    OldH := Bubble.FBubbleRect.Height;
    Bubble.FBubbleRect.Height := Bubble.FExpandH;
    Delta := Bubble.FExpandH - OldH;
    if not SameValue(Delta, 0, 0.5) then
      RecalcBubblesFrom(Bubble.FBubbleRect, Delta);
  end;
  // No ChatScrollToBottom here — that was throwing the user to the bottom
  // on first expand (triggered by deferred font measurement after first Paint).
  // Scrolling is handled only by ChatAdd* methods when new content arrives.
end;

procedure TfrmMain.OnSettingsHideFinish(Sender: TObject);
begin
  FRectSettings.Visible := False;
end;

end.
