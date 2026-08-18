unit Main;

{
  FMX main form. All controls are built programmatically (no designer
  dependency).

  Output: TVertScrollBox with native chat bubbles.
  - Task: right-aligned blue-bordered collapsible bubble.
  - Thinking: plain dim text row "-> Model thinking..." (no bubble).
  - Code: dark TCodeView with Delphi syntax highlighting, collapsible.
  - Review: tinted bubble, three styles - rejection (red, collapsible),
    approved (green, flat - rare path, approval without NO_ISSUES),
    no_issues (green flat, non-collapsible strip).
  - Done/Error/Cost: slim status bars.
  - Result: final code bubble in the chat stream, auto-opened on EngDone.

  No external browser, no WebView2, no internet dependency for rendering.

  Engine event contract:
  - OnThink: accumulates per-phase into FThinkBuffer / FThinkModel; flushed
    as a plain text row before each code or review bubble.
  - OnPhase: updates sidebar + progress; adds iteration header for iter > 1.
  - OnCode: flushes thinking, then adds a code bubble.
  - OnReview: flushes thinking, then adds a review bubble.
  - OnDone: flushes thinking, adds the done bar and the result bubble.
  - OnError: adds error bar, stops running state.
  - OnTokens: adds inline cost label.

  All handlers run on the main thread via TThread.Synchronize in the engine;
  no extra TThread.Queue wrapping needed here.
}

interface

uses
  System.SysUtils, System.UITypes, System.Classes, System.Generics.Collections,
  FMX.Types, FMX.Forms, FMX.Objects, FMX.StdCtrls, FMX.Layouts, FMX.Edit,
  FMX.Memo, FMX.ListBox, FMX.SpinBox, FMX.ScrollBox,
  Engine, Engine.Config;

type
  // Review bubble style - three distinct visual modes.
  TReviewStyle = (rsRejection, rsApproved, rsNoIssues);

  TfrmMain = class; // forward

  // ---------------------------------------------------------------------------
  //  TChatBubble - collapsible bubble helper for Code and Review items.
  //  Owns nothing extra; FMX parent chain owns all controls.
  //  Fields are public on purpose: OnCodeViewResized adjusts them after the
  //  code view reports its measured height.
  // ---------------------------------------------------------------------------
  TChatBubble = class(TComponent)
  public
    FIsOpen: Boolean;
    FBubbleRect: TRectangle;
    FChevronLabel: TLabel;
    FBodyRect: TRectangle; // container shown/hidden on toggle
    FCollapsedHeight: Single;
    FExpandedHeight: Single;
    FOwner: TfrmMain;

    constructor Create(AOwner: TfrmMain; ABubble: TRectangle; AChevron: TLabel;
      ABody: TRectangle; ACollapsedHeight, AExpandedHeight: Single); reintroduce;
    procedure HandleClick(Sender: TObject);
  end;

  TfrmMain = class(TForm)
  private
    // --- Engine & state ---
    FEngine: TLoopEngine;
    FConfig: TLoopConfig;
    FRunning: Boolean;
    FCurrentIteration: Integer;
    FMaxIterations: Integer;
    FThinkBuffer: TStringBuilder; // accumulates OnThink messages per phase
    FThinkModel: string; // model name for the current thinking row

    // --- Chat area ---
    FScrollChat: TVertScrollBox;
    FChatBubbles: TList<TFmxObject>; // root controls per chat item (non-owning)

    // --- Sidebar ---
    FRectSidebar: TRectangle;
    FRectStatus: TRectangle;
    FLabelRunTitle: TLabel;
    FLabelRunIteration: TLabel;
    FProgressRun: TProgressBar;
    FRectSettingsButton: TRectangle;

    // --- Input area ---
    FRectInput: TRectangle;
    FMemoTask: TMemo;
    FComboExecutor: TComboBox;
    FComboReviewer: TComboBox;
    FComboIterations: TComboBox;
    FRectRun: TRectangle;
    FLabelRunButton: TLabel;
    FRectClear: TRectangle;

    // --- Settings overlay ---
    FRectSettings: TRectangle;
    FEditOpenRouterKey: TEdit;
    FEditOpenAIKey: TEdit;
    FEditOllamaUrl: TEdit;
    FComboSettingsExecutor: TComboBox;
    FComboSettingsReviewer: TComboBox;
    FSpinIterations: TSpinBox;

    FNextChatY: Single; // accumulated Y for next bubble

    // --- Build helpers ---
    function MakeRect(AParent: TFmxObject; AAlign: TAlignLayout;
      AColor: TAlphaColor; AWidth, AHeight: Single): TRectangle;
    function MakeLabel(AParent: TFmxObject; const AText: string; ASize: Single;
      AColor: TAlphaColor; ABold: Boolean = False): TLabel;
    function MakeLine(AParent: TFmxObject; AAlign: TAlignLayout): TRectangle;
    function MakeRectButton(AParent: TFmxObject; const AText: string;
      AColor: TAlphaColor; AWidth: Single): TRectangle;
    function MakeEdit(AParent: TFmxObject; const AHint: string;
      APassword: Boolean = False): TEdit;
    function MakeCombo(AParent: TFmxObject; AWidth: Single): TComboBox;

    // --- Build sections ---
    procedure LoadStyle;
    procedure BuildSidebar;
    procedure BuildLogoRow;
    procedure BuildStatusBlock;
    procedure BuildSidebarFooter;
    procedure BuildMain;
    procedure BuildChatArea(AParent: TLayout);
    procedure BuildInputArea(AParent: TLayout);
    procedure BuildInputMemo(ABox: TRectangle);
    procedure BuildInputFooter(ABox: TRectangle);
    procedure BuildSettingsOverlay;
    procedure BuildSettingsHeader;
    procedure BuildSettingsBody;
    procedure BuildSettingsFooter;
    procedure AddSettingsSectionLabel(AScroll: TScrollBox; const AText: string);
    function AddSettingsCard(AScroll: TScrollBox): TRectangle;
    function AddSettingsRow(ACard: TRectangle;
      const AIcon, AName, ADescription: string): TLayout;
    procedure FillCombos;
    procedure SyncConfigToUI;
    procedure SyncUIToConfig;

    // --- Chat helpers ---
    function MakeBubble(AColor: TAlphaColor; AHeight: Single): TRectangle;
    procedure RecalcBubblesFrom(AFrom: TFmxObject; ADelta: Single);
    procedure ChatClear;
    procedure ChatAddIterationHeader(ANumber, AMaxIterations: Integer);
    procedure ChatAddTask(const AText: string);
    procedure ChatAddThinkingText(const AExecutor: string);
    procedure ChatAddCode(const ACode: string; AIteration: Integer);
    procedure ChatAddReview(const AModel: string; AStyle: TReviewStyle;
      const AText: string);
    procedure ChatAddDone(AIteration: Integer; const AExecutor, AReviewer: string);
    procedure ChatAddError(const AMessage: string);
    procedure ChatAddCost(ATokens: Integer; ACost: Double);
    procedure ChatAddResult(const ACode: string; AIteration: Integer;
      const AReviewerName: string; ACharCount: Integer);
    procedure ChatScrollToBottom;
    procedure CopyToClipboard(const AText: string);
    function ShortName(const AName: string): string;

    // --- Thinking buffer helpers ---
    procedure FlushThinking;

    // --- Engine event bridges ---
    // All called via TThread.Synchronize - already on main thread.
    procedure EngThink(const AModel, AMessage: string);
    procedure EngPhase(APhase: TLoopPhase; AIteration, AMaxIterations: Integer);
    procedure EngCode(const ACode: string; AIteration: Integer; AIsDraft: Boolean);
    procedure EngReview(const AReview: string; AIteration: Integer;
      AApproved: Boolean; const AReviewer: string);
    procedure EngDone(const ACode: string; AIteration: Integer;
      const AExecutor, AReviewer: string);
    procedure EngError(const AMessage: string);
    procedure EngTokens(ATokens: Integer; ACost: Double);

    // --- State ---
    procedure SetRunning(AValue: Boolean);
    procedure UpdateSidebar(const APhase: string; AIteration, AMaxIterations: Integer);

    // --- Event handlers ---
    procedure OnRunClick(Sender: TObject);
    procedure OnClearClick(Sender: TObject);
    procedure OnSettingsClick(Sender: TObject);
    procedure OnSettingsBackClick(Sender: TObject);
    procedure OnResetClick(Sender: TObject);
    procedure OnMemoChange(Sender: TObject);

    procedure OnSettingsButtonMouseEnter(Sender: TObject);
    procedure OnSettingsButtonMouseLeave(Sender: TObject);
    procedure OnRunButtonMouseEnter(Sender: TObject);
    procedure OnRunButtonMouseLeave(Sender: TObject);
    procedure OnClearButtonMouseEnter(Sender: TObject);
    procedure OnClearButtonMouseLeave(Sender: TObject);
    procedure OnBackButtonMouseEnter(Sender: TObject);
    procedure OnBackButtonMouseLeave(Sender: TObject);
    procedure OnResetButtonMouseEnter(Sender: TObject);
    procedure OnResetButtonMouseLeave(Sender: TObject);
    procedure OnCopyLabelClick(Sender: TObject);
    procedure OnCodeViewResized(Sender: TObject);
    procedure OnSettingsHideFinish(Sender: TObject);
    procedure ApplyDarkTitleBar;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmMain: TfrmMain;

implementation

uses
 {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.DwmApi,
  FMX.Platform.Win,
 {$ENDIF}
  System.Types, System.Math, System.StrUtils,
  FMX.Controls, FMX.Graphics, FMX.EditBox, FMX.Styles,
  FMX.Platform, FMX.Ani,
  Engine.Types, Engine.Consts, UI.CodeView, UI.Consts;

// ===========================================================================
//  TChatBubble - collapsible bubble toggle (code + review)
// ===========================================================================

constructor TChatBubble.Create(AOwner: TfrmMain; ABubble: TRectangle;
  AChevron: TLabel; ABody: TRectangle; ACollapsedHeight, AExpandedHeight: Single);
begin
  inherited Create(ABubble); // bubble owns us, gets freed when bubble dies
  FIsOpen := False;
  FBubbleRect := ABubble;
  FChevronLabel := AChevron;
  FBodyRect := ABody;
  FCollapsedHeight := ACollapsedHeight;
  FExpandedHeight := AExpandedHeight;
  FOwner := AOwner;
end;

procedure TChatBubble.HandleClick(Sender: TObject);
var
  OldHeight: Single;
  NewHeight: Single;
begin
  FIsOpen := not FIsOpen;

  if FIsOpen then
  begin
    // Restore body height so Align=Top allocates space, then show
    FBodyRect.Height := FExpandedHeight - FCollapsedHeight;
    FBodyRect.Visible := True;
    FBodyRect.HitTest := True;
    FChevronLabel.Text := SChevronOpen;
    NewHeight := FExpandedHeight;
  end
  else
  begin
    // Collapse: height=0 so Align=Top takes no space, then hide
    FBodyRect.Height := 0;
    FBodyRect.Visible := False;
    FBodyRect.HitTest := False;
    FChevronLabel.Text := SChevronCollapsed;
    NewHeight := FCollapsedHeight;
  end;

  OldHeight := FBubbleRect.Height;
  FBubbleRect.Height := NewHeight;
  FOwner.RecalcBubblesFrom(FBubbleRect, NewHeight - OldHeight);
end;

// ===========================================================================
//  Styles
// ===========================================================================

procedure TfrmMain.LoadStyle;
begin
  TStyleManager.SetStyleFromFile(
    ExtractFilePath(ParamStr(0)) + StylesPath + StyleFileName
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
  Caption := AppName + ' ' + AppVersionLabel;
  Width := FormWidth;
  Height := FormHeight;
  Position := TFormPosition.ScreenCenter;
  Constraints.MinWidth := FormMinWidth;
  Constraints.MinHeight := FormMinHeight;
  Fill.Color := ColorBackground;
  Fill.Kind := TBrushKind.Solid;

  FThinkBuffer := TStringBuilder.Create;
  FThinkModel := '';
  FChatBubbles := TList<TFmxObject>.Create;
  FRunning := False;
  FCurrentIteration := 0;
  FMaxIterations := 3;

  FConfig := TLoopConfig.Create;
  TLoopConfigIO.Load(TLoopConfigIO.DefaultFileName, FConfig);

  FEngine := TLoopEngine.Create;
  FEngine.SetProviders(FConfig);
  FEngine.SetModels(FConfig);
  FEngine.OnThink := EngThink;
  FEngine.OnPhase := EngPhase;
  FEngine.OnCode := EngCode;
  FEngine.OnReview := EngReview;
  FEngine.OnDone := EngDone;
  FEngine.OnError := EngError;
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
  FChatBubbles.Free; // non-owning list - FMX owns controls via Parent
  FThinkBuffer.Free;
  inherited;
end;

// ===========================================================================
//  Build helpers
// ===========================================================================

function TfrmMain.MakeRect(AParent: TFmxObject; AAlign: TAlignLayout;
  AColor: TAlphaColor; AWidth, AHeight: Single): TRectangle;
begin
  Result := TRectangle.Create(AParent);
  Result.Parent := AParent;
  Result.Align := AAlign;
  Result.Fill.Color := AColor;
  Result.Stroke.Kind := TBrushKind.None;
  if AWidth > 0 then
    Result.Width := AWidth;
  if AHeight > 0 then
    Result.Height := AHeight;
end;

function TfrmMain.MakeLabel(AParent: TFmxObject; const AText: string;
  ASize: Single; AColor: TAlphaColor; ABold: Boolean): TLabel;
begin
  Result := TLabel.Create(AParent);
  Result.Parent := AParent;
  Result.Text := AText;
  Result.FontColor := AColor;
  Result.Font.Size := ASize;
  if ABold then
    Result.Font.Style := [TFontStyle.fsBold];
end;

function TfrmMain.MakeLine(AParent: TFmxObject; AAlign: TAlignLayout): TRectangle;
begin
  Result := MakeRect(AParent, AAlign, ColorBorder, 0, 1);
end;

function TfrmMain.MakeRectButton(AParent: TFmxObject; const AText: string;
  AColor: TAlphaColor; AWidth: Single): TRectangle;
var
  ButtonLabel: TLabel;
begin
  Result := TRectangle.Create(AParent);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Right;
  Result.Width := AWidth;
  Result.Height := ButtonHeight;
  Result.Fill.Color := AColor;
  Result.Stroke.Kind := TBrushKind.None;
  Result.XRadius := CornerMedium;
  Result.YRadius := CornerMedium;
  Result.Cursor := crHandPoint;
  Result.Margins.Left := 6;

  ButtonLabel := TLabel.Create(Result);
  ButtonLabel.Parent := Result;
  ButtonLabel.Align := TAlignLayout.Client;
  ButtonLabel.Text := AText;
  ButtonLabel.FontColor := TAlphaColorRec.White;
  ButtonLabel.Font.Size := FontMd;
  ButtonLabel.Font.Style := [TFontStyle.fsBold];
  ButtonLabel.TextSettings.HorzAlign := TTextAlign.Center;
  ButtonLabel.TextSettings.VertAlign := TTextAlign.Center;
  ButtonLabel.HitTest := False;
end;

function TfrmMain.MakeEdit(AParent: TFmxObject; const AHint: string;
  APassword: Boolean): TEdit;
begin
  Result := TEdit.Create(AParent);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Right;
  Result.Width := 220;
  Result.TextPrompt := AHint;
  Result.Password := APassword;
end;

function TfrmMain.MakeCombo(AParent: TFmxObject; AWidth: Single): TComboBox;
begin
  Result := TComboBox.Create(AParent);
  Result.Parent := AParent;
  Result.Width := AWidth;
end;

// ===========================================================================
//  Build Sidebar
// ===========================================================================

procedure TfrmMain.BuildLogoRow;
var
  LogoRect: TRectangle;
  LogoImage: TImage;
begin
  LogoRect := MakeRect(FRectSidebar, TAlignLayout.Top, ColorSidebar, 0, LogoHeight);
  LogoRect.Padding.Left := 14;
  LogoRect.Padding.Right := 14;

  LogoImage := TImage.Create(LogoRect);
  LogoImage.Parent := LogoRect;
  LogoImage.Align := TAlignLayout.Center;
  LogoImage.Width := LogoImageWidth;
  LogoImage.Height := LogoImageHeight;
  LogoImage.WrapMode := TImageWrapMode.Fit;
  LogoImage.Bitmap.LoadFromFile(ExtractFilePath(ParamStr(0)) + LogoFileName);

  MakeLine(FRectSidebar, TAlignLayout.Top);
end;

procedure TfrmMain.BuildStatusBlock;
begin
  FRectStatus := MakeRect(FRectSidebar, TAlignLayout.Top, ColorSidebar, 0, StatusHeight);
  FRectStatus.Margins.Left := 10;
  FRectStatus.Margins.Right := 10;
  FRectStatus.Margins.Top := 8;
  FRectStatus.Margins.Bottom := 4;
  FRectStatus.XRadius := CornerMedium;
  FRectStatus.YRadius := CornerMedium;
  FRectStatus.Padding.Left := 11;
  FRectStatus.Padding.Right := 11;

  FLabelRunTitle := MakeLabel(FRectStatus, '', FontMd, TAlphaColor(ColorAccent), True);
  FLabelRunTitle.Align := TAlignLayout.Top;
  FLabelRunTitle.Height := 22;
  FLabelRunTitle.Margins.Top := 9;

  FLabelRunIteration := MakeLabel(FRectStatus, SReady, FontSm, ColorMute);
  FLabelRunIteration.Align := TAlignLayout.Top;
  FLabelRunIteration.Height := 18;

  FProgressRun := TProgressBar.Create(FRectStatus);
  FProgressRun.Parent := FRectStatus;
  FProgressRun.Align := TAlignLayout.Bottom;
  FProgressRun.Height := ProgressHeight;
  FProgressRun.Margins.Bottom := 11;
  FProgressRun.Min := 0;
  FProgressRun.Max := 3;
  FProgressRun.Value := 0;
end;

procedure TfrmMain.BuildSidebarFooter;
var
  FooterRect: TRectangle;
  SettingsLabel: TLabel;
begin
  MakeLine(FRectSidebar, TAlignLayout.Bottom);
  FooterRect := MakeRect(FRectSidebar, TAlignLayout.Bottom, ColorSidebar, 0, SidebarFooterHeight);

  FRectSettingsButton := MakeRect(FooterRect, TAlignLayout.Client, ColorSidebar, 0, 0);
  FRectSettingsButton.Margins.Left := 8;
  FRectSettingsButton.Margins.Right := 8;
  FRectSettingsButton.Margins.Top := 9;
  FRectSettingsButton.Margins.Bottom := 9;
  FRectSettingsButton.XRadius := CornerSmall;
  FRectSettingsButton.YRadius := CornerSmall;
  FRectSettingsButton.Cursor := crHandPoint;
  FRectSettingsButton.OnClick := OnSettingsClick;
  FRectSettingsButton.OnMouseEnter := OnSettingsButtonMouseEnter;
  FRectSettingsButton.OnMouseLeave := OnSettingsButtonMouseLeave;

  SettingsLabel := MakeLabel(FRectSettingsButton, SSettings, 12.5, ColorDim);
  SettingsLabel.Align := TAlignLayout.Client;
  SettingsLabel.Margins.Left := 12;
  SettingsLabel.TextSettings.HorzAlign := TTextAlign.Leading;
  SettingsLabel.TextSettings.VertAlign := TTextAlign.Center;
  SettingsLabel.HitTest := False;
end;

procedure TfrmMain.BuildSidebar;
begin
  FRectSidebar := MakeRect(Self, TAlignLayout.Left, ColorSidebar, SidebarWidth, 0);
  BuildLogoRow;
  BuildStatusBlock;
  // TODO: session history list here (roadmap).
  MakeRect(FRectSidebar, TAlignLayout.Client, ColorSidebar, 0, 0);
  BuildSidebarFooter;
end;

// ===========================================================================
//  Build Main area
// ===========================================================================

procedure TfrmMain.BuildChatArea(AParent: TLayout);
begin
  FScrollChat := TVertScrollBox.Create(AParent);
  FScrollChat.Parent := AParent;
  FScrollChat.Align := TAlignLayout.Client;
  FScrollChat.ShowScrollBars := True;
  FScrollChat.StyleLookup := 'transparentscrollboxstyle';
end;

procedure TfrmMain.BuildInputMemo(ABox: TRectangle);
begin
  FMemoTask := TMemo.Create(ABox);
  FMemoTask.Parent := ABox;
  FMemoTask.Align := TAlignLayout.Client;
  FMemoTask.TextPrompt := SMemoPrompt;
  FMemoTask.Font.Size := FontLg;
  FMemoTask.Height := MemoMinHeight;

  FMemoTask.OnChange := OnMemoChange;
  FMemoTask.StyleLookup := 'memostyle';
end;

procedure TfrmMain.BuildInputFooter(ABox: TRectangle);
var
  RectFooter: TRectangle;
  Spacer: TLayout;
  ArrowLabel: TLabel;
begin
  MakeLine(ABox, TAlignLayout.Bottom);
  RectFooter := MakeRect(ABox, TAlignLayout.Bottom, ColorSurface, 0, InputFooterHeight);

  FRectRun := MakeRectButton(RectFooter, SButtonRunIcon, ColorAccent, RunButtonWidth);
  FRectRun.Margins.Right := 9;
  FRectRun.Margins.Top := 8;
  FRectRun.Margins.Bottom := 8;
  FRectRun.OnClick := OnRunClick;
  FRectRun.OnMouseEnter := OnRunButtonMouseEnter;
  FRectRun.OnMouseLeave := OnRunButtonMouseLeave;
  FRectRun.ShowHint := True;
  FRectRun.Hint := SHintRun;
  FLabelRunButton := FRectRun.Children[0] as TLabel;

  FRectClear := MakeRectButton(RectFooter, SButtonClear, ColorSurface2, ClearButtonWidth);
  FRectClear.Margins.Top := 8;
  FRectClear.Margins.Bottom := 8;
  FRectClear.OnClick := OnClearClick;
  FRectClear.OnMouseEnter := OnClearButtonMouseEnter;
  FRectClear.OnMouseLeave := OnClearButtonMouseLeave;
  FRectClear.ShowHint := True;
  FRectClear.Hint := SHintClear;

  FComboIterations := MakeCombo(RectFooter, 54);
  FComboIterations.Align := TAlignLayout.Right;
  FComboIterations.Margins.Left := 6;
  FComboIterations.Margins.Right := 6;

  Spacer := TLayout.Create(RectFooter);
  Spacer.Parent := RectFooter;
  Spacer.Align := TAlignLayout.Client;

  FComboExecutor := MakeCombo(RectFooter, 170);
  FComboExecutor.Align := TAlignLayout.Left;
  FComboExecutor.Margins.Left := 9;

  ArrowLabel := MakeLabel(RectFooter, '  '#$2192'  ', 11.5, ColorMute);
  ArrowLabel.Align := TAlignLayout.Left;
  ArrowLabel.Width := 30;
  ArrowLabel.TextSettings.VertAlign := TTextAlign.Center;

  FComboReviewer := MakeCombo(RectFooter, 150);
  FComboReviewer.Align := TAlignLayout.Left;
end;

procedure TfrmMain.BuildInputArea(AParent: TLayout);
var
  RectInputBox: TRectangle;
begin
  // Separator and FRectInput are Bottom-aligned directly on LayMain.
  MakeLine(AParent, TAlignLayout.Bottom);

  FRectInput := MakeRect(AParent, TAlignLayout.Bottom, ColorBackground, 0,
                        MemoMinHeight + InputFooterHeight + InputPaddingVertical);

  RectInputBox := MakeRect(FRectInput, TAlignLayout.Client, ColorSurface, 0, 0);
  RectInputBox.Margins.Left := 14;
  RectInputBox.Margins.Right := 14;
  RectInputBox.Margins.Top := 10;
  RectInputBox.Margins.Bottom := 10;
  RectInputBox.XRadius := CornerLarge;
  RectInputBox.YRadius := CornerLarge;
  RectInputBox.Stroke.Color := ColorBorder;
  RectInputBox.Stroke.Kind := TBrushKind.Solid;

  BuildInputMemo(RectInputBox);
  BuildInputFooter(RectInputBox);
end;

procedure TfrmMain.BuildMain;
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

procedure TfrmMain.AddSettingsSectionLabel(AScroll: TScrollBox; const AText: string);
var
  SectionLabel: TLabel;
begin
  SectionLabel := MakeLabel(AScroll, AText, FontXs, ColorMute);
  SectionLabel.Align := TAlignLayout.Top;
  SectionLabel.Height := 26;
  SectionLabel.Margins.Left := 2;
  SectionLabel.Margins.Top := 8;
end;

function TfrmMain.AddSettingsCard(AScroll: TScrollBox): TRectangle;
begin
  Result := MakeRect(AScroll, TAlignLayout.Top, ColorSurface, 0, 0);
  Result.XRadius := CornerLarge;
  Result.YRadius := CornerLarge;
  Result.Stroke.Color := ColorBorder;
  Result.Stroke.Kind := TBrushKind.Solid;
  Result.Margins.Bottom := 2;
end;

function TfrmMain.AddSettingsRow(ACard: TRectangle;
  const AIcon, AName, ADescription: string): TLayout;
var
  IconLabel: TLabel;
  InfoLayout: TLayout;
  NameLabel: TLabel;
  Separator: TRectangle;
begin
  ACard.Height := ACard.Height + SettingsRowHeight;

  Result := TLayout.Create(ACard);
  Result.Parent := ACard;
  Result.Align := TAlignLayout.Top;
  Result.Height := SettingsRowHeight;
  Result.Padding.Left := 16;
  Result.Padding.Right := 16;
  Result.Padding.Top := 12;
  Result.Padding.Bottom := 12;

  if ACard.ChildrenCount > 1 then
  begin
    Separator := MakeLine(ACard, TAlignLayout.Top);
    Separator.BringToFront;
  end;

  IconLabel := MakeLabel(Result, AIcon, 14, ColorDim);
  IconLabel.Align := TAlignLayout.Left;
  IconLabel.Width := 28;
  IconLabel.TextSettings.HorzAlign := TTextAlign.Center;
  IconLabel.TextSettings.VertAlign := TTextAlign.Center;

  InfoLayout := TLayout.Create(Result);
  InfoLayout.Parent := Result;
  InfoLayout.Align := TAlignLayout.Client;

  NameLabel := MakeLabel(InfoLayout, AName, FontLg, ColorText, True);
  NameLabel.Align := TAlignLayout.Top;
  NameLabel.Height := 22;

  if ADescription <> '' then
  begin
    var DescriptionLabel := MakeLabel(InfoLayout, ADescription, 11.5, ColorMute);
    DescriptionLabel.Align := TAlignLayout.Top;
    DescriptionLabel.Height := 18;
  end;
end;

procedure TfrmMain.BuildSettingsHeader;
var
  HeaderRect: TRectangle;
  RectBack: TRectangle;
  BackLabel: TLabel;
  TitleLabel: TLabel;
begin
  HeaderRect := MakeRect(FRectSettings, TAlignLayout.Top, ColorBackground, 0, 50);
  MakeLine(FRectSettings, TAlignLayout.Top);

  RectBack := MakeRect(HeaderRect, TAlignLayout.Left, ColorBackground, 44, 0);
  RectBack.Margins.Left := 14;
  RectBack.XRadius := CornerSmall;
  RectBack.YRadius := CornerSmall;
  RectBack.Cursor := crHandPoint;
  RectBack.OnClick := OnSettingsBackClick;
  RectBack.OnMouseEnter := OnBackButtonMouseEnter;
  RectBack.OnMouseLeave := OnBackButtonMouseLeave;

  BackLabel := MakeLabel(RectBack, #$2190, 18, ColorDim);
  BackLabel.Align := TAlignLayout.Client;
  BackLabel.TextSettings.HorzAlign := TTextAlign.Center;
  BackLabel.TextSettings.VertAlign := TTextAlign.Center;
  BackLabel.HitTest := False;

  TitleLabel := MakeLabel(HeaderRect, 'Settings', 15, ColorText, True);
  TitleLabel.Align := TAlignLayout.Client;
  TitleLabel.Margins.Left := 8;
  TitleLabel.TextSettings.VertAlign := TTextAlign.Center;
end;

procedure TfrmMain.BuildSettingsBody;
var
  Scroll: TScrollBox;
  Card: TRectangle;
  Row: TLayout;
  BottomPad: TLayout;
begin
  Scroll := TScrollBox.Create(FRectSettings);
  Scroll.Parent := FRectSettings;
  Scroll.Align := TAlignLayout.Client;
  Scroll.Padding.Left := Max(0, (Width - 620) / 2);
  Scroll.Padding.Right := Scroll.Padding.Left;

  AddSettingsSectionLabel(Scroll, 'LOOP');
  Card := AddSettingsCard(Scroll);
  Row := AddSettingsRow(Card, #$1F501, 'Max Iterations', 'Generate '#$2192' Review cycles');
  FSpinIterations := TSpinBox.Create(Row);
  FSpinIterations.Parent := Row;
  FSpinIterations.Align := TAlignLayout.Right;
  FSpinIterations.Width := 80;
  FSpinIterations.Min := 1;
  FSpinIterations.Max := 10;
  FSpinIterations.Value := 3;
  FSpinIterations.Increment := 1;

  AddSettingsSectionLabel(Scroll, 'MODELS');
  Card := AddSettingsCard(Scroll);
  Row := AddSettingsRow(Card, #$26A1, 'Executor', 'Generates the code');
  FComboSettingsExecutor := MakeCombo(Row, 200);
  FComboSettingsExecutor.Align := TAlignLayout.Right;
  Row := AddSettingsRow(Card, #$1F441, 'Reviewer', 'Reviews and approves');
  FComboSettingsReviewer := MakeCombo(Row, 200);
  FComboSettingsReviewer.Align := TAlignLayout.Right;

  AddSettingsSectionLabel(Scroll, 'PROVIDERS');
  Card := AddSettingsCard(Scroll);
  Row := AddSettingsRow(Card, #$1F511, 'OpenRouter API key', 'sk-or-'#$2026);
  FEditOpenRouterKey := MakeEdit(Row, 'sk-or-v1-'#$2026, True);
  FEditOpenRouterKey.Width := 220;
  Row := AddSettingsRow(Card, #$1F511, 'OpenAI API key', 'sk-'#$2026);
  FEditOpenAIKey := MakeEdit(Row, 'sk-'#$2026, True);
  FEditOpenAIKey.Width := 220;
  Row := AddSettingsRow(Card, #$1F99A, 'Ollama URL', 'Local endpoint');
  FEditOllamaUrl := MakeEdit(Row, 'http://localhost:11434');
  FEditOllamaUrl.Width := 220;

  BottomPad := TLayout.Create(Scroll);
  BottomPad.Parent := Scroll;
  BottomPad.Align := TAlignLayout.Top;
  BottomPad.Height := 16;
end;

procedure TfrmMain.BuildSettingsFooter;
var
  RectFooter: TRectangle;
  ResetButton: TRectangle;
begin
  RectFooter := MakeRect(FRectSettings, TAlignLayout.Bottom, ColorBackground, 0, 52);
  MakeLine(FRectSettings, TAlignLayout.Bottom);

  ResetButton := MakeRectButton(RectFooter, 'Reset to defaults', ColorSurface, 160);
  ResetButton.Margins.Right := 20;
  ResetButton.Margins.Top := 10;
  ResetButton.Margins.Bottom := 10;
  ResetButton.OnClick := OnResetClick;
  ResetButton.OnMouseEnter := OnResetButtonMouseEnter;
  ResetButton.OnMouseLeave := OnResetButtonMouseLeave;
  (ResetButton.Children[0] as TLabel).FontColor := ColorDim;
end;

procedure TfrmMain.BuildSettingsOverlay;
begin
  FRectSettings := MakeRect(Self, TAlignLayout.None, ColorBackground, 0, 0);
  FRectSettings.SetBounds(Width, 0, Width, Height);
  FRectSettings.Visible := False;
  FRectSettings.BringToFront;

  BuildSettingsHeader;
  BuildSettingsBody;
  BuildSettingsFooter;
end;

// ===========================================================================
//  FillCombos / Sync
// ===========================================================================

procedure TfrmMain.FillCombos;
begin
  FComboExecutor.Items.Clear;
  FComboReviewer.Items.Clear;
  FComboSettingsExecutor.Items.Clear;
  FComboSettingsReviewer.Items.Clear;

  for var i := 0 to FConfig.ModelCount - 1 do
  begin
    FComboExecutor.Items.Add(ShortName(FConfig.GetModel(i).DisplayName));
    FComboReviewer.Items.Add(ShortName(FConfig.GetModel(i).DisplayName));
    FComboSettingsExecutor.Items.Add(FConfig.GetModel(i).DisplayName);
    FComboSettingsReviewer.Items.Add(FConfig.GetModel(i).DisplayName);
  end;

  FComboIterations.Items.Clear;
  for var i := 1 to 10 do
    FComboIterations.Items.Add(IntToStr(i));
end;

procedure TfrmMain.SyncConfigToUI;
var
  Settings: TLoopSettings;
begin
  Settings := FConfig.Settings;

  FComboExecutor.ItemIndex := Settings.ExecutorIndex;
  FComboReviewer.ItemIndex := Settings.ReviewerIndex;
  FComboIterations.ItemIndex := Settings.MaxIterations - 1;
  FComboSettingsExecutor.ItemIndex := Settings.ExecutorIndex;
  FComboSettingsReviewer.ItemIndex := Settings.ReviewerIndex;
  FSpinIterations.Value := Settings.MaxIterations;

  if FConfig.ProviderCount > 2 then
    FEditOpenRouterKey.Text := FConfig.GetProvider(2).ApiKey;
  if FConfig.ProviderCount > 1 then
    FEditOpenAIKey.Text := FConfig.GetProvider(1).ApiKey;
  if FConfig.ProviderCount > 0 then
    FEditOllamaUrl.Text := FConfig.GetProvider(0).BaseUrl;
end;

procedure TfrmMain.SyncUIToConfig;
var
  Settings: TLoopSettings;
  Provider: TProviderConfig;
begin
  Settings.ExecutorIndex := FComboSettingsExecutor.ItemIndex;
  Settings.ReviewerIndex := FComboSettingsReviewer.ItemIndex;
  Settings.MaxIterations := Round(FSpinIterations.Value);
  FConfig.Settings := Settings;

  if FConfig.ProviderCount > 0 then
  begin
    Provider := FConfig.GetProvider(0);
    Provider.BaseUrl := FEditOllamaUrl.Text;
    FConfig.UpdateProvider(0, Provider);
  end;
  if FConfig.ProviderCount > 1 then
  begin
    Provider := FConfig.GetProvider(1);
    Provider.ApiKey := FEditOpenAIKey.Text;
    FConfig.UpdateProvider(1, Provider);
  end;
  if FConfig.ProviderCount > 2 then
  begin
    Provider := FConfig.GetProvider(2);
    Provider.ApiKey := FEditOpenRouterKey.Text;
    FConfig.UpdateProvider(2, Provider);
  end;

  FComboExecutor.ItemIndex := Settings.ExecutorIndex;
  FComboReviewer.ItemIndex := Settings.ReviewerIndex;
  FComboIterations.ItemIndex := Settings.MaxIterations - 1;

  TLoopConfigIO.Save(TLoopConfigIO.DefaultFileName, FConfig);
  FEngine.SetProviders(FConfig);
  FEngine.SetModels(FConfig);
end;

// ===========================================================================
//  Chat helpers
// ===========================================================================

function TfrmMain.MakeBubble(AColor: TAlphaColor; AHeight: Single): TRectangle;
begin
  Result := TRectangle.Create(FScrollChat);
  Result.Parent := FScrollChat;
  Result.Align := TAlignLayout.None;
  Result.Width := FScrollChat.Width - BubbleMarginHorizontal * 2;
  Result.Height := AHeight;
  Result.Position.X := BubbleMarginHorizontal;
  Result.Position.Y := FNextChatY + BubbleMarginVertical;
  Result.Fill.Color := AColor;
  Result.Stroke.Kind := TBrushKind.None;
  Result.XRadius := 8;
  Result.YRadius := 8;
  Result.Margins.Left := BubbleMarginHorizontal;
  Result.Margins.Right := BubbleMarginHorizontal;
  Result.Margins.Top := BubbleMarginVertical;
  Result.Margins.Bottom := BubbleMarginVertical;

  FNextChatY := Result.Position.Y + AHeight + BubbleMarginVertical;
  FChatBubbles.Add(Result);
end;

procedure TfrmMain.RecalcBubblesFrom(AFrom: TFmxObject; ADelta: Single);
var
  Found: Boolean;
begin
  Found := False;
  for var i := 0 to FChatBubbles.Count - 1 do
  begin
    var Item := FChatBubbles[i];
    if Item = AFrom then
    begin
      Found := True;
      Continue;
    end;
    if Found then
      TControl(Item).Position.Y := TControl(Item).Position.Y + ADelta;
  end;

  FNextChatY := FNextChatY + ADelta;
end;

procedure TfrmMain.ChatClear;
begin
  for var Item in FChatBubbles do
    Item.Free;
  FChatBubbles.Clear;

  FThinkBuffer.Clear;
  FThinkModel := '';
  FCurrentIteration := 0;
  FNextChatY := 0;
end;

procedure TfrmMain.ChatScrollToBottom;
var
  ContentRect: TRectF;
  MaxScrollY: Single;
begin
  ContentRect := FScrollChat.ContentBounds;
  MaxScrollY := Max(0, ContentRect.Bottom - FScrollChat.Height);
  FScrollChat.ViewportPosition := PointF(0, MaxScrollY);
end;

procedure TfrmMain.CopyToClipboard(const AText: string);
var
  ClipboardService: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(
       IFMXClipboardService, IInterface(ClipboardService)) then
    ClipboardService.SetClipboard(AText);
end;

function TfrmMain.ShortName(const AName: string): string;
var
  ParenPos: Integer;
begin
  ParenPos := Pos(' (', AName);
  if ParenPos > 0 then
    Result := Trim(Copy(AName, 1, ParenPos - 1))
  else
    Result := Trim(AName);
end;

// ---------------------------------------------------------------------------
//  ChatAddIterationHeader - thin separator between iterations
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddIterationHeader(ANumber, AMaxIterations: Integer);
var
  HeaderLabel: TLabel;
begin
  HeaderLabel := TLabel.Create(FScrollChat);
  HeaderLabel.Parent := FScrollChat;
  HeaderLabel.Align := TAlignLayout.None;
  HeaderLabel.Width := FScrollChat.Width - BubbleMarginHorizontal * 2;
  HeaderLabel.Height := 20;
  HeaderLabel.Position.X := BubbleMarginHorizontal;
  HeaderLabel.Position.Y := FNextChatY + 14;
  HeaderLabel.Text := Format(SIterationHeaderFormat, [ANumber, AMaxIterations]);
  HeaderLabel.Font.Size := 10;
  HeaderLabel.FontColor := ColorMute;
  HeaderLabel.TextSettings.HorzAlign := TTextAlign.Center;

  FNextChatY := HeaderLabel.Position.Y + HeaderLabel.Height + 4;
  FChatBubbles.Add(HeaderLabel);
  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddTask - right-aligned task bubble, collapsible
//  Shows first line collapsed; full text on click.
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddTask(const AText: string);
var
  BubbleWidth: Single;
  BubbleRect: TRectangle;
  TagLabel: TLabel;
  PreviewLabel: TLabel;
  BodyLabel: TLabel;
  ChevronLabel: TLabel;
  HeaderLayout: TLayout;
  BodyRect: TRectangle;
  FirstLine: string;
  ExpandedHeight: Single;
  LineCount: Integer;
  Bubble: TChatBubble;
begin
  if AText.Trim = '' then
    Exit;

  // First line for preview
  FirstLine := AText;
  if Pos(#10, FirstLine) > 0 then
    FirstLine := Copy(FirstLine, 1, Pos(#10, FirstLine) - 1);
  if Length(FirstLine) > 90 then
    FirstLine := Copy(FirstLine, 1, 90) + #$2026;

  LineCount := Max(3, AText.CountChar(#10) + 2);
  ExpandedHeight := TaskCollapsedHeight + LineCount * 18 + 16;

  BubbleWidth := Round((FScrollChat.Width - BubbleMarginHorizontal * 2) * 0.62);

  // Build bubble positioned right
  BubbleRect := TRectangle.Create(FScrollChat);
  BubbleRect.Parent := FScrollChat;
  BubbleRect.Align := TAlignLayout.None;
  BubbleRect.Width := BubbleWidth;
  BubbleRect.Height := TaskCollapsedHeight;
  BubbleRect.Position.X := FScrollChat.Width - BubbleMarginHorizontal - BubbleWidth;
  BubbleRect.Position.Y := FNextChatY + BubbleMarginVertical;
  BubbleRect.Fill.Color := ColorTaskBackground;
  BubbleRect.Stroke.Kind := TBrushKind.None;
  BubbleRect.XRadius := 12;
  BubbleRect.YRadius := 12;
  BubbleRect.ClipChildren := True;
  BubbleRect.Cursor := crHandPoint;
  FNextChatY := BubbleRect.Position.Y + TaskCollapsedHeight + BubbleMarginVertical;
  FChatBubbles.Add(BubbleRect);

  // Header row: TASK label + chevron
  HeaderLayout := TLayout.Create(BubbleRect);
  HeaderLayout.Parent := BubbleRect;
  HeaderLayout.Align := TAlignLayout.Top;
  HeaderLayout.Height := 22;
  HeaderLayout.Padding.Left := 10;
  HeaderLayout.Padding.Right := 8;
  HeaderLayout.Padding.Top := 6;

  TagLabel := MakeLabel(HeaderLayout, STaskTag, FontXs, TAlphaColor(ColorAccent), True);
  TagLabel.Align := TAlignLayout.Left;
  TagLabel.Width := 40;
  TagLabel.TextSettings.VertAlign := TTextAlign.Center;
  TagLabel.HitTest := False;

  ChevronLabel := MakeLabel(HeaderLayout, SChevronCollapsed, FontXs, ColorDim);
  ChevronLabel.Align := TAlignLayout.Right;
  ChevronLabel.Width := 18;
  ChevronLabel.TextSettings.HorzAlign := TTextAlign.Trailing;
  ChevronLabel.TextSettings.VertAlign := TTextAlign.Center;
  ChevronLabel.HitTest := False;

  // Preview line (collapsed state)
  PreviewLabel := MakeLabel(BubbleRect, FirstLine, FontSm, ColorDim);
  PreviewLabel.Align := TAlignLayout.Top;
  PreviewLabel.Height := 18;
  PreviewLabel.Margins.Left := 10;
  PreviewLabel.Margins.Right := 8;
  PreviewLabel.Margins.Bottom := 6;
  PreviewLabel.TextSettings.HorzAlign := TTextAlign.Leading;
  PreviewLabel.TextSettings.VertAlign := TTextAlign.Center;
  PreviewLabel.HitTest := False;

  // Body (expanded state, initially hidden - Height=0 keeps Align=Top from pushing layout)
  BodyRect := MakeRect(BubbleRect, TAlignLayout.Top, ColorTaskBackground, 0, 0);
  BodyRect.Stroke.Kind := TBrushKind.None;
  BodyRect.Visible := False;
  BodyRect.HitTest := False;
  BodyRect.Padding.Left := 10;
  BodyRect.Padding.Right := 8;
  BodyRect.Padding.Top := 4;

  BodyLabel := MakeLabel(BodyRect, AText, FontSm, ColorText);
  BodyLabel.Align := TAlignLayout.Client;
  BodyLabel.WordWrap := True;
  BodyLabel.TextSettings.HorzAlign := TTextAlign.Leading;
  BodyLabel.TextSettings.VertAlign := TTextAlign.Leading;
  BodyLabel.HitTest := False;

  // Wire up toggle
  Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLabel, BodyRect,
                               TaskCollapsedHeight, ExpandedHeight);
  BubbleRect.OnClick := Bubble.HandleClick;
  HeaderLayout.OnClick := Bubble.HandleClick;
  PreviewLabel.HitTest := False;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddThinkingText - plain dim text row "-> Model thinking..."
//  No bubble, no toggle. Just a label, like a status whisper.
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddThinkingText(const AExecutor: string);
var
  ThinkingLabel: TLabel;
begin
  if AExecutor.Trim = '' then
    Exit;

  ThinkingLabel := TLabel.Create(FScrollChat);
  ThinkingLabel.Parent := FScrollChat;
  ThinkingLabel.Align := TAlignLayout.None;
  ThinkingLabel.Width := FScrollChat.Width - BubbleMarginHorizontal * 2;
  ThinkingLabel.Height := 20;
  ThinkingLabel.Position.X := BubbleMarginHorizontal;
  ThinkingLabel.Position.Y := FNextChatY + 6;
  ThinkingLabel.Text := SThinkArrow + ' ' + AExecutor + SThinkSuffix;
  ThinkingLabel.Font.Size := FontXs;
  ThinkingLabel.Font.Style := [TFontStyle.fsItalic];
  ThinkingLabel.FontColor := ColorMute;
  ThinkingLabel.TextSettings.HorzAlign := TTextAlign.Leading;
  ThinkingLabel.HitTest := False;

  FNextChatY := ThinkingLabel.Position.Y + ThinkingLabel.Height + 4;
  FChatBubbles.Add(ThinkingLabel);
  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddCode - dark code block, collapsible (closed by default)
//  AIteration=0 -> 'draft' badge; >0 -> 'v2','v3',... badge
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddCode(const ACode: string; AIteration: Integer);
var
  BubbleRect: TRectangle;
  HeaderLayout: TLayout;
  BadgeRect: TRectangle;
  BadgeLabel: TLabel;
  ModelLabel: TLabel;
  CopyLabel: TLabel;
  ChevronLabel: TLabel;
  BodyRect: TRectangle;
  CodeView: TCodeView;
  LineCount: Integer;
  EstimatedCodeHeight: Single;
  CollapsedHeight: Single;
  ExpandedHeight: Single;
  CodeCapture: string;
  Bubble: TChatBubble;
begin
  if ACode.Trim = '' then
    Exit;

  LineCount := Max(1, ACode.CountChar(#10) + 1);
  EstimatedCodeHeight := LineCount * CodeLineHeightEstimate + CodePaddingVertical * 2;
  CollapsedHeight := CodeBubbleCollapsedHeight;
  ExpandedHeight := CollapsedHeight + EstimatedCodeHeight;

  BubbleRect := MakeBubble(CodeColorBackground, CollapsedHeight);
  BubbleRect.ClipChildren := True;
  BubbleRect.Cursor := crHandPoint;

  // Header strip
  HeaderLayout := TLayout.Create(BubbleRect);
  HeaderLayout.Parent := BubbleRect;
  HeaderLayout.Align := TAlignLayout.Top;
  HeaderLayout.Height := CodeBubbleCollapsedHeight;
  HeaderLayout.Padding.Left := 12;
  HeaderLayout.Padding.Right := 10;
  HeaderLayout.Padding.Top := 7;
  HeaderLayout.Padding.Bottom := 7;

  // Badge pill
  BadgeRect := TRectangle.Create(HeaderLayout);
  BadgeRect.Parent := HeaderLayout;
  BadgeRect.Align := TAlignLayout.Left;
  BadgeRect.Width := 44;
  BadgeRect.Margins.Right := 8;
  BadgeRect.XRadius := 10;
  BadgeRect.YRadius := 10;
  BadgeRect.Stroke.Kind := TBrushKind.None;
  if AIteration = 0 then
  begin
    BadgeRect.Fill.Color := ColorBadgeDraft;
    BadgeLabel := MakeLabel(BadgeRect, 'draft', 9.5, ColorAccent);
  end
  else
  begin
    BadgeRect.Fill.Color := ColorBadgeFinal;
    BadgeLabel := MakeLabel(BadgeRect, 'v' + IntToStr(AIteration + 1), 9.5, ColorGreen);
  end;
  BadgeLabel.Align := TAlignLayout.Client;
  BadgeLabel.TextSettings.HorzAlign := TTextAlign.Center;
  BadgeLabel.TextSettings.VertAlign := TTextAlign.Center;
  BadgeLabel.HitTest := False;

  // Model name label (filled later by EngTokens - we show what we have)
  ModelLabel := MakeLabel(HeaderLayout, ShortName(FComboExecutor.Text), FontSm, ColorDim);
  ModelLabel.Align := TAlignLayout.Client;
  ModelLabel.TextSettings.VertAlign := TTextAlign.Center;
  ModelLabel.HitTest := False;

  // Chevron toggle
  ChevronLabel := MakeLabel(HeaderLayout, SChevronCollapsed, FontSm, ColorMute);
  ChevronLabel.Align := TAlignLayout.Right;
  ChevronLabel.Width := 22;
  ChevronLabel.TextSettings.HorzAlign := TTextAlign.Trailing;
  ChevronLabel.TextSettings.VertAlign := TTextAlign.Center;
  ChevronLabel.HitTest := False;

  // Copy button
  CodeCapture := ACode;
  CopyLabel := MakeLabel(HeaderLayout, SCopyCode, FontSm, ColorMute);
  CopyLabel.Align := TAlignLayout.Right;
  CopyLabel.Width := 48;
  CopyLabel.Margins.Right := 4;
  CopyLabel.TextSettings.HorzAlign := TTextAlign.Center;
  CopyLabel.TextSettings.VertAlign := TTextAlign.Center;
  CopyLabel.Cursor := crHandPoint;
  CopyLabel.HitTest := True;
  CopyLabel.TagString := CodeCapture;
  CopyLabel.OnClick := OnCopyLabelClick;

  // Body - code view. Collapsed by default = hidden; Height=0 keeps
  // Align=Top from pushing the layout.
  BodyRect := MakeRect(BubbleRect, TAlignLayout.Top, CodeColorBackground, 0, 0);
  BodyRect.Stroke.Kind := TBrushKind.None;
  BodyRect.Visible := False;
  BodyRect.HitTest := False;

  // Wire toggle first so OnCodeViewResized has a valid TChatBubble reference
  Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLabel, BodyRect,
                               CollapsedHeight, ExpandedHeight);
  CodeView := TCodeView.Create(BodyRect);
  CodeView.Parent := BodyRect;
  CodeView.Align := TAlignLayout.Top;
  CodeView.TagObject := Bubble;
  CodeView.OnResized := OnCodeViewResized;
  CodeView.SetCode(ACode);
  // FExpandedHeight is updated in OnCodeViewResized with real measured height
  HeaderLayout.OnClick := Bubble.HandleClick;
  BubbleRect.OnClick := Bubble.HandleClick;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddReview - three visual modes
//    rsRejection : red, collapsible - shows rejection reason
//    rsApproved  : green flat - approved but with text (rare path)
//    rsNoIssues  : green flat strip - no chevron, no expand
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddReview(const AModel: string; AStyle: TReviewStyle;
  const AText: string);
var
  BubbleRect: TRectangle;
  HeaderLayout: TLayout;
  IconLabel: TLabel;
  VerdictLabel: TLabel;
  ChevronLabel: TLabel;
  BodyRect: TRectangle;
  BodyLabel: TLabel;
  BackgroundColor: TAlphaColor;
  IconText: string;
  IconColor: TAlphaColor;
  VerdictText: string;
  VerdictColor:TAlphaColor;
  LineCount: Integer;
  ExpandedHeight: Single;
  Bubble: TChatBubble;
begin
  BackgroundColor := ColorReviewRejectBackground;
  IconColor := TAlphaColor(ColorReviewRejectIcon);
  VerdictColor := TAlphaColor(ColorReviewRejectIcon);
  case AStyle of
    rsRejection:
    begin
      BackgroundColor := ColorReviewRejectBackground;
      IconText := #$2717; // ✗
      IconColor := TAlphaColor(ColorReviewRejectIcon);
      VerdictText := AModel + ' ' + 'rejected result';
      VerdictColor := TAlphaColor(ColorReviewRejectIcon);
    end;
    rsApproved:
    begin
      BackgroundColor := ColorReviewOk;
      IconText := #$2713; // ✓
      IconColor := ColorGreen;
      VerdictText := AModel + ': approved';
      VerdictColor := ColorGreen;
    end;
    rsNoIssues:
    begin
      BackgroundColor := ColorReviewNoIssuesBackground;
      IconText := #$2713; // ✓
      IconColor := ColorGreen;
      VerdictText := AModel + ': NO_ISSUES';
      VerdictColor := ColorGreen;
    end;
  end;

  BubbleRect := MakeBubble(BackgroundColor, ReviewBubbleHeight);
  BubbleRect.ClipChildren := True;

  // Header
  HeaderLayout := TLayout.Create(BubbleRect);
  HeaderLayout.Parent := BubbleRect;
  HeaderLayout.Align := TAlignLayout.Top;
  HeaderLayout.Height := ReviewBubbleHeight;
  HeaderLayout.Padding.Left := 12;
  HeaderLayout.Padding.Right := 10;
  HeaderLayout.Padding.Top := 0;
  HeaderLayout.Padding.Bottom := 0;

  IconLabel := MakeLabel(HeaderLayout, IconText, FontMd, IconColor, True);
  IconLabel.Align := TAlignLayout.Left;
  IconLabel.Width := 22;
  IconLabel.TextSettings.HorzAlign := TTextAlign.Center;
  IconLabel.TextSettings.VertAlign := TTextAlign.Center;
  IconLabel.HitTest := False;

  VerdictLabel := MakeLabel(HeaderLayout, VerdictText, FontSm, VerdictColor, True);
  VerdictLabel.Align := TAlignLayout.Client;
  VerdictLabel.Margins.Left := 4;
  VerdictLabel.TextSettings.VertAlign := TTextAlign.Center;
  VerdictLabel.HitTest := False;

  // Only rejection bubbles are collapsible
  if AStyle = rsRejection then
  begin
    ChevronLabel := MakeLabel(HeaderLayout, SChevronCollapsed, FontSm, ColorMute);
    ChevronLabel.Align := TAlignLayout.Right;
    ChevronLabel.Width := 20;
    ChevronLabel.TextSettings.HorzAlign := TTextAlign.Trailing;
    ChevronLabel.TextSettings.VertAlign := TTextAlign.Center;
    ChevronLabel.HitTest := False;

    LineCount := Max(2, AText.CountChar(#10) + 1 + Length(AText) div 60);
    ExpandedHeight := ReviewBubbleHeight + LineCount * 16 + 20;

    BodyRect := MakeRect(BubbleRect, TAlignLayout.Top, BackgroundColor, 0, 0);
    BodyRect.Stroke.Kind := TBrushKind.None;
    BodyRect.Visible := False;
    BodyRect.HitTest := False;
    BodyRect.Padding.Left := 12;
    BodyRect.Padding.Right := 12;
    BodyRect.Padding.Top := 6;
    BodyRect.Padding.Bottom := 8;

    BodyLabel := MakeLabel(BodyRect, AText, FontXs, ColorDim);
    BodyLabel.Align := TAlignLayout.Client;
    BodyLabel.WordWrap := True;
    BodyLabel.TextSettings.HorzAlign := TTextAlign.Leading;
    BodyLabel.TextSettings.VertAlign := TTextAlign.Leading;
    BodyLabel.HitTest := False;

    Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLabel, BodyRect,
                                 ReviewBubbleHeight, ExpandedHeight);
    BubbleRect.Cursor := crHandPoint;
    HeaderLayout.OnClick := Bubble.HandleClick;
    BubbleRect.OnClick := Bubble.HandleClick;
  end;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddDone - slim green done bar
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddDone(AIteration: Integer; const AExecutor, AReviewer: string);
var
  BubbleRect: TRectangle;
  DoneLabel: TLabel;
begin
  BubbleRect := MakeBubble(ColorDoneBackground, 40);
  BubbleRect.Padding.Left := 14;
  BubbleRect.Padding.Right := 14;

  DoneLabel := MakeLabel(BubbleRect,
    Format('%s  Done '#$2014' %d iteration(s)  '#$00B7'  %s '#$2192' %s',
      [#$2713, AIteration, AExecutor, AReviewer]),
    12, ColorGreen, True);
  DoneLabel.Align := TAlignLayout.Client;
  DoneLabel.TextSettings.VertAlign := TTextAlign.Center;
  DoneLabel.HitTest := False;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddError
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddError(const AMessage: string);
var
  BubbleRect: TRectangle;
  ErrorLabel: TLabel;
begin
  BubbleRect := MakeBubble(ColorErrorBackground, 40);
  BubbleRect.Padding.Left := 14;
  BubbleRect.Padding.Right := 14;

  ErrorLabel := MakeLabel(BubbleRect, #$26A0 + '  ' + AMessage, 12, ColorOrange);
  ErrorLabel.Align := TAlignLayout.Client;
  ErrorLabel.TextSettings.VertAlign := TTextAlign.Center;
  ErrorLabel.HitTest := False;

  ChatScrollToBottom;
end;

// ---------------------------------------------------------------------------
//  ChatAddCost - inline token/cost label (right-aligned, dim)
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddCost(ATokens: Integer; ACost: Double);
var
  CostLabel: TLabel;
  CostStr: string;
begin
  CostStr := FormatFloat('0.0000', ACost);
  CostStr := CostStr.Replace(',', '.');

  CostLabel := TLabel.Create(FScrollChat);
  CostLabel.Parent := FScrollChat;
  CostLabel.Align := TAlignLayout.None;
  CostLabel.Width := FScrollChat.Width - BubbleMarginHorizontal * 2;
  CostLabel.Height := 20;
  CostLabel.Position.X := BubbleMarginHorizontal;
  CostLabel.Position.Y := FNextChatY;
  CostLabel.Text := Format('%d tokens  '#$00B7'  $%s', [ATokens, CostStr]);
  CostLabel.Font.Size := 10;
  CostLabel.FontColor := ColorMute;
  CostLabel.TextSettings.HorzAlign := TTextAlign.Trailing;
  CostLabel.HitTest := False;
  FNextChatY := CostLabel.Position.Y + CostLabel.Height + 8;
  FChatBubbles.Add(CostLabel);

  ChatScrollToBottom;
end;

// ===========================================================================
//  FlushThinking - resets the thinking buffer (text already emitted in EngThink)
// ===========================================================================

procedure TfrmMain.FlushThinking;
begin
  FThinkBuffer.Clear;
  FThinkModel := '';
end;

// ---------------------------------------------------------------------------
//  ChatAddResult - final result bubble in the chat stream.
//  Blue accent border, dark background, collapsible TCodeView body.
//  Called by EngDone after ChatAddDone - this is the last bubble in the run.
// ---------------------------------------------------------------------------

procedure TfrmMain.ChatAddResult(const ACode: string; AIteration: Integer;
  const AReviewerName: string; ACharCount: Integer);
var
  BubbleRect: TRectangle;
  HeaderLayout: TLayout;
  TitleLabel: TLabel;
  SubLabel: TLabel;
  CopyButton: TRectangle;
  FooterRect: TRectangle;
  FooterLabel: TLabel;
  BodyRect: TRectangle;
  CodeView: TCodeView;
  LineCount: Integer;
  EstimatedCodeHeight: Single;
  CollapsedHeight: Single;
  ExpandedHeight: Single;
  SubText: string;
  FootText: string;
  CodeCapture: string;
  Bubble: TChatBubble;
  ChevronLabel: TLabel;
begin
  if ACode.Trim = '' then
    Exit;

  CollapsedHeight := ResultBubbleCollapsedHeight;
  LineCount := Max(1, ACode.CountChar(#10) + 1);
  EstimatedCodeHeight := LineCount * CodeLineHeightEstimate + CodePaddingVertical * 2;
  ExpandedHeight := CollapsedHeight + EstimatedCodeHeight;

  // Build bubble manually - result needs ColorResultBackground, not a chat color param
  BubbleRect := TRectangle.Create(FScrollChat);
  BubbleRect.Parent := FScrollChat;
  BubbleRect.Align := TAlignLayout.None;
  BubbleRect.Width := FScrollChat.Width - BubbleMarginHorizontal * 2;
  BubbleRect.Height := CollapsedHeight;
  BubbleRect.Position.X := BubbleMarginHorizontal;
  BubbleRect.Position.Y := FNextChatY + BubbleMarginVertical;
  BubbleRect.Fill.Color := ColorResultBackground;
  BubbleRect.Stroke.Kind := TBrushKind.None;
  BubbleRect.XRadius := CornerLarge;
  BubbleRect.YRadius := CornerLarge;
  BubbleRect.ClipChildren := True;
  BubbleRect.Cursor := crHandPoint;
  FNextChatY := BubbleRect.Position.Y + CollapsedHeight + BubbleMarginVertical;
  FChatBubbles.Add(BubbleRect);

  // --- Header ---
  HeaderLayout := TLayout.Create(BubbleRect);
  HeaderLayout.Parent := BubbleRect;
  HeaderLayout.Align := TAlignLayout.Top;
  HeaderLayout.Height := ResultBubbleHeaderHeight;
  HeaderLayout.Padding.Left := 14;
  HeaderLayout.Padding.Right := 8;
  HeaderLayout.Padding.Top := 0;
  HeaderLayout.Padding.Bottom := 0;

  TitleLabel := MakeLabel(HeaderLayout, SResultTitle, FontMd, TAlphaColor(ColorAccent), True);
  TitleLabel.Align := TAlignLayout.Left;
  TitleLabel.Width := 120;
  TitleLabel.TextSettings.VertAlign := TTextAlign.Center;
  TitleLabel.HitTest := False;

  SubText := Format('%d iteration%s '#$00B7' approved',
    [AIteration, IfThen(AIteration = 1, '', 's')]);
  SubLabel := MakeLabel(HeaderLayout, SubText, FontXs, ColorDim);
  SubLabel.Align := TAlignLayout.Client;
  SubLabel.Margins.Left := 6;
  SubLabel.TextSettings.VertAlign := TTextAlign.Center;
  SubLabel.HitTest := False;

  // Chevron (right of header, before copy button)
  ChevronLabel := MakeLabel(HeaderLayout, SChevronCollapsed, FontSm, ColorMute);
  ChevronLabel.Align := TAlignLayout.Right;
  ChevronLabel.Width := 22;
  ChevronLabel.TextSettings.HorzAlign := TTextAlign.Trailing;
  ChevronLabel.TextSettings.VertAlign := TTextAlign.Center;
  ChevronLabel.HitTest := False;

  // Copy button - TagString lives on the inner label (TRectangle has no TagString-aware click).
  // The label handles the click; CopyButton.OnClick stays nil so the bubble toggle fires normally.
  CodeCapture := ACode;
  CopyButton := MakeRectButton(HeaderLayout, SCopyCode, ColorSurface2, CopyButtonWidth);
  CopyButton.Margins.Top := 5;
  CopyButton.Margins.Bottom := 5;
  CopyButton.Margins.Right := 4;
  CopyButton.OnMouseEnter := OnClearButtonMouseEnter;
  CopyButton.OnMouseLeave := OnClearButtonMouseLeave;

  // --- Footer strip (Bottom-aligned so it's always visible when collapsed) ---
  FooterRect := MakeRect(BubbleRect, TAlignLayout.Bottom, ColorResultFooter, 0,
    ResultBubbleFooterHeight);
  FooterRect.Stroke.Kind := TBrushKind.None;
  FooterRect.Padding.Left := 14;
  FooterRect.Padding.Right := 14;

  FootText := #$2713 + ' Approved by ' + AReviewerName;
  if ACharCount > 0 then
    FootText := FootText + '    ' + IntToStr(ACharCount) + ' chars';
  FooterLabel := MakeLabel(FooterRect, FootText, FontXs, ColorDim);
  FooterLabel.Align := TAlignLayout.Client;
  FooterLabel.TextSettings.VertAlign := TTextAlign.Center;
  FooterLabel.HitTest := False;

  // --- Body: TCodeView, collapsible ---
  BodyRect := MakeRect(BubbleRect, TAlignLayout.Top, ColorResultBackground, 0, 0);
  BodyRect.Stroke.Kind := TBrushKind.None;
  BodyRect.Visible := False;
  BodyRect.HitTest := False;

  // Wire toggle before creating TCodeView (OnCodeViewResized needs TChatBubble)
  Bubble := TChatBubble.Create(Self, BubbleRect, ChevronLabel, BodyRect,
                               CollapsedHeight, ExpandedHeight);
  CodeView := TCodeView.Create(BodyRect);
  CodeView.Parent := BodyRect;
  CodeView.Align := TAlignLayout.Top;
  CodeView.TagObject := Bubble;
  CodeView.OnResized := OnCodeViewResized;
  CodeView.SetCode(ACode);

  HeaderLayout.OnClick := Bubble.HandleClick;
  BubbleRect.OnClick := Bubble.HandleClick;

  // Wire copy: TagString on the label inside MakeRectButton, OnCopyLabelClick handles it.
  (CopyButton.Children[0] as TLabel).TagString := CodeCapture;
  (CopyButton.Children[0] as TLabel).OnClick := OnCopyLabelClick;
  (CopyButton.Children[0] as TLabel).HitTest := True;
  (CopyButton.Children[0] as TLabel).Cursor := crHandPoint;

  // Result is the final deliverable - open it immediately.
  Bubble.HandleClick(nil);

  ChatScrollToBottom;
end;

// ===========================================================================
//  Engine event bridges
// ===========================================================================

procedure TfrmMain.EngThink(const AModel, AMessage: string);
begin
  // First OnThink in a phase: show "-> Model thinking..." immediately.
  // Subsequent calls just accumulate (buffer kept for potential future use).
  if FThinkModel = '' then
  begin
    FThinkModel := AModel;
    ChatAddThinkingText(AModel);
  end;

  FThinkBuffer.AppendLine(AMessage);
end;

procedure TfrmMain.EngPhase(APhase: TLoopPhase; AIteration, AMaxIterations: Integer);
begin
  FCurrentIteration := AIteration;
  FMaxIterations := AMaxIterations;

  FProgressRun.Max := AMaxIterations * 2;
  case APhase of
    lpGenerating: FProgressRun.Value := 0;
    lpReviewing: FProgressRun.Value := (AIteration - 1) * 2 + 1;
    lpRefining: FProgressRun.Value := AIteration * 2;
  end;

  if (APhase = lpReviewing) and (AIteration > 1) then
    ChatAddIterationHeader(AIteration, AMaxIterations);

  case APhase of
    lpGenerating: UpdateSidebar(SPhaseExecutor, 0, AMaxIterations);
    lpReviewing: UpdateSidebar(SPhaseReviewer, AIteration, AMaxIterations);
    lpRefining: UpdateSidebar(SPhaseExecutor, AIteration, AMaxIterations);
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
  Style: TReviewStyle;
begin
  FlushThinking;
  if AApproved then
  begin
    if Pos(NoIssuesMarker, AReview) > 0 then
      Style := rsNoIssues
    else
      Style := rsApproved;
  end
  else
    Style := rsRejection;

  ChatAddReview(ShortName(AReviewer), Style, AReview);
end;

procedure TfrmMain.EngDone(const ACode: string; AIteration: Integer;
  const AExecutor, AReviewer: string);
begin
  FlushThinking;
  ChatAddDone(AIteration, ShortName(AExecutor), ShortName(AReviewer));
  ChatAddResult(ACode, AIteration, ShortName(AReviewer), Length(ACode));
  SetRunning(False);
end;

procedure TfrmMain.EngError(const AMessage: string);
begin
  ChatAddError(AMessage);
  SetRunning(False);
end;

procedure TfrmMain.EngTokens(ATokens: Integer; ACost: Double);
begin
  ChatAddCost(ATokens, ACost);
end;

// ===========================================================================
//  State helpers
// ===========================================================================

procedure TfrmMain.SetRunning(AValue: Boolean);
begin
  FRunning := AValue;
  FRectRun.HitTest := not AValue;
  FRectRun.Fill.Color := IfThen(AValue,
    TAlphaColor(ColorSurface2), TAlphaColor(ColorAccent));
  FLabelRunButton.Text := IfThen(AValue, SButtonRunning, SButtonRun);

  FMemoTask.ReadOnly := AValue;
  FComboExecutor.Enabled := not AValue;
  FComboReviewer.Enabled := not AValue;
  FComboIterations.Enabled := not AValue;

  if not AValue then
  begin
    FProgressRun.Value := 0;
    UpdateSidebar(SPhaseDone, FCurrentIteration, FMaxIterations);
  end;
end;

procedure TfrmMain.UpdateSidebar(const APhase: string; AIteration, AMaxIterations: Integer);
begin
  if FRunning then
  begin
    FRectStatus.Fill.Color := ColorStatusBackground;
    FLabelRunTitle.Text := SRunning;
    FLabelRunIteration.Text := Format(SIterationFormat, [AIteration, AMaxIterations, APhase]);
    FProgressRun.Max := Max(1, AMaxIterations);
    FProgressRun.Value := Max(0, AIteration);
  end
  else
  begin
    FRectStatus.Fill.Color := ColorSidebar;
    FLabelRunTitle.Text := '';
    FLabelRunIteration.Text := SReady;
    FProgressRun.Value := 0;
  end;
end;

// ===========================================================================
//  Event handlers
// ===========================================================================

procedure TfrmMain.OnRunClick(Sender: TObject);
var
  Task: string;
  ExecutorIndex, ReviewerIndex: Integer;
  MaxIterations: Integer;
begin
  if FRunning then
    Exit;
  Task := FMemoTask.Text.Trim;
  if Task = '' then
    Exit;

  ExecutorIndex := Max(0, FComboExecutor.ItemIndex);
  ReviewerIndex := Max(0, FComboReviewer.ItemIndex);
  MaxIterations := StrToIntDef(
    FComboIterations.Items[Max(0, FComboIterations.ItemIndex)], 3);

  FCurrentIteration := 1;
  FMaxIterations := MaxIterations;
  FThinkBuffer.Clear;
  FThinkModel := '';

  SetRunning(True);
  UpdateSidebar(SPhaseExecutor, 1, MaxIterations);
  ChatAddTask(Task);
  ChatAddIterationHeader(1, MaxIterations);

  FEngine.Run(Task, ExecutorIndex, ReviewerIndex, MaxIterations);
end;

procedure TfrmMain.OnClearClick(Sender: TObject);
begin
  if FRunning then
    Exit;
  ChatClear;
end;

procedure TfrmMain.OnSettingsClick(Sender: TObject);
begin
  SyncConfigToUI;
  FRectSettings.SetBounds(Width, 0, Width, Height);
  FRectSettings.Visible := True;
  TAnimator.AnimateFloat(FRectSettings, 'Position.X', 0, 0.22);
end;

procedure TfrmMain.OnSettingsBackClick(Sender: TObject);
begin
  SyncUIToConfig;

  var Anim := TFloatAnimation.Create(FRectSettings);
  Anim.Parent := FRectSettings;
  Anim.PropertyName := 'Position.X';
  Anim.StartValue := FRectSettings.Position.X;
  Anim.StopValue := Width;
  Anim.Duration := 0.22;
  Anim.AnimationType := TAnimationType.Out;
  Anim.Interpolation := TInterpolationType.Quadratic;
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
  Lines: Integer;
  LineHeight: Single;
  NewHeight: Single;
begin
  Lines := Max(2, Min(FMemoTask.Lines.Count, 6));
  LineHeight := FMemoTask.Font.Size * 1.5 + 2;
  NewHeight := Ceil(LineHeight * Lines) + 16;
  NewHeight := EnsureRange(NewHeight, MemoMinHeight, MemoMaxHeight);

  if not SameValue(FMemoTask.Height, NewHeight, 0.5) then
  begin
    FMemoTask.Height := NewHeight;
    FRectInput.Height := NewHeight + InputFooterHeight + InputPaddingVertical;
  end;
end;

procedure TfrmMain.OnSettingsButtonMouseEnter(Sender: TObject);
begin
  FRectSettingsButton.Fill.Color := ColorSurface;
end;

procedure TfrmMain.OnSettingsButtonMouseLeave(Sender: TObject);
begin
  FRectSettingsButton.Fill.Color := ColorSidebar;
end;

procedure TfrmMain.OnRunButtonMouseEnter(Sender: TObject);
begin
  if not FRunning then
    FRectRun.Fill.Color := ColorRunHover;
end;

procedure TfrmMain.OnRunButtonMouseLeave(Sender: TObject);
begin
  if not FRunning then
    FRectRun.Fill.Color := ColorAccent;
end;

procedure TfrmMain.OnClearButtonMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := ColorClearHover;
end;

procedure TfrmMain.OnClearButtonMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := ColorSurface2;
end;

procedure TfrmMain.OnBackButtonMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := ColorSurface;
end;

procedure TfrmMain.OnBackButtonMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := ColorBackground;
end;

procedure TfrmMain.OnResetButtonMouseEnter(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := ColorSurface2;
end;

procedure TfrmMain.OnResetButtonMouseLeave(Sender: TObject);
begin
  TRectangle(Sender).Fill.Color := ColorSurface;
end;

procedure TfrmMain.OnCopyLabelClick(Sender: TObject);
begin
  CopyToClipboard(TLabel(Sender).TagString);
end;

procedure TfrmMain.OnCodeViewResized(Sender: TObject);
var
  CodeView: TCodeView;
  Bubble: TChatBubble;
  OldHeight: Single;
  Delta: Single;
begin
  CodeView := TCodeView(Sender);
  if not (CodeView.TagObject is TChatBubble) then
    Exit;

  Bubble := TChatBubble(CodeView.TagObject);
  Bubble.FExpandedHeight := Bubble.FCollapsedHeight + CodeView.Height;

  if Bubble.FIsOpen then
  begin
    Bubble.FBodyRect.Height := CodeView.Height;
    OldHeight := Bubble.FBubbleRect.Height;
    Bubble.FBubbleRect.Height := Bubble.FExpandedHeight;
    Delta := Bubble.FExpandedHeight - OldHeight;
    if not SameValue(Delta, 0, 0.5) then
      RecalcBubblesFrom(Bubble.FBubbleRect, Delta);
  end;
  // No ChatScrollToBottom here - that was throwing the user to the bottom
  // on first expand (triggered by deferred font measurement after first Paint).
  // Scrolling is handled only by ChatAdd* methods when new content arrives.
end;

procedure TfrmMain.OnSettingsHideFinish(Sender: TObject);
begin
  FRectSettings.Visible := False;
end;

end.
