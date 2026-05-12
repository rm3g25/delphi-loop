unit uCodeView;

{
  DelphiLoop — FMX custom control for syntax-highlighted Delphi code.

  Renders tokenized source to FMX Canvas using Cascadia Code (monospace).
  Token colors are VSCode dark+-inspired, tuned to the DelphiLoop palette.

  Usage:
    CV := TCodeView.Create(Self);
    CV.Parent := SomeContainer;  // container clips rounded corners
    CV.Align  := TAlignLayout.Top;
    CV.SetCode(MySourceString);

  Contract:
    - Parent provides rounded background + clipping (TRectangle + ClipChildren).
    - This control paints a flat background and renders tokens on top.
    - HitTest = False — read-only display, no interaction.
    - Height is auto-calculated from line count on each SetCode call.
    - Font is measured on first Paint (Canvas is valid there); subsequent
      paints use cached FCharWidth / FLineHeight.
}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Generics.Collections, System.Threading,
  FMX.Types, FMX.Controls, FMX.Graphics,
  uDelphiLexer;

const
  // Syntax token colors — VSCode Dark+ palette
  CCLR_BG       = $FF1E1E2E;  // code block background (slightly blue-dark)
  CCLR_KEYWORD  = $FF569CD6;  // blue       — begin end if procedure ...
  CCLR_STRING   = $FFCE9178;  // orange     — 'quoted string' #13
  CCLR_NUMBER   = $FFB5CEA8;  // sage green — 42  3.14  $FF
  CCLR_COMMENT  = $FF6A9955;  // muted green — // { } (* *)
  CCLR_IDENT    = $FFE8E8EC;  // near-white  — identifiers
  CCLR_OPERATOR = $FF888896;  // dim gray    — := + - . , ; ( )
  CCLR_DEFAULT  = $FFE8E8EC;

  CV_FONT_SIZE  = 12.5;
  CV_PAD_H      = 16.0;       // horizontal padding inside the code block
  CV_PAD_V      = 13.0;       // vertical padding
  CV_LINE_GAP   = 4.0;        // extra pixels between lines beyond font height
  CV_TAB_COLS   = 2;          // tab = 2 spaces (Delphi community standard)

  // Estimated metrics used before first Paint measures the actual font.
  // Cascadia Code 12.5px: empirically ~7.5px wide, ~17px tall.
  CV_CHAR_W_EST = 7.5;
  CV_LINE_H_EST = CV_FONT_SIZE * 1.5 + CV_LINE_GAP;

type
  TCodeView = class(TControl)
  private
    FLexer: TDelphiLexer;
    FTokens: TList<TCodeToken>;
    FCode: string;

    // Measured after first Paint
    FCharWidth: Single;
    FLineHeight: Single;
    FMeasured: Boolean;

    function ColorForKind(AKind: TTokenKind): TAlphaColor; inline;
    procedure MeasureFont;
    procedure UpdateHeight;
    function CountLines: Integer;

  protected
    procedure Paint; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    // Tokenizes ACode and schedules a repaint. Safe to call from main thread only.
    procedure SetCode(const ACode: string);

    property Code: string read FCode;
  end;

implementation

// ===========================================================================
//  Lifecycle
// ===========================================================================
constructor TCodeView.Create(AOwner: TComponent);
begin
  inherited;
  FLexer     := TDelphiLexer.Create;
  FTokens    := TList<TCodeToken>.Create;
  FMeasured  := False;
  FCharWidth := CV_CHAR_W_EST;
  FLineHeight:= CV_LINE_H_EST;
  HitTest    := False; // display only
end;

destructor TCodeView.Destroy;
begin
  FTokens.Free;
  FLexer.Free;
  inherited;
end;

// ===========================================================================
//  Color map
// ===========================================================================
function TCodeView.ColorForKind(AKind: TTokenKind): TAlphaColor;
begin
  case AKind of
    tkKeyword:    Result := CCLR_KEYWORD;
    tkString:     Result := CCLR_STRING;
    tkNumber:     Result := CCLR_NUMBER;
    tkComment:    Result := CCLR_COMMENT;
    tkOperator:   Result := CCLR_OPERATOR;
    tkIdentifier: Result := CCLR_IDENT;
  else
    Result := CCLR_DEFAULT;
  end;
end;

// ===========================================================================
//  Height management
// ===========================================================================
function TCodeView.CountLines: Integer;
var
  C: Char;
begin
  Result := 1;
  for C in FCode do
    if C = #10 then
      Inc(Result);
end;

procedure TCodeView.UpdateHeight;
begin
  Height := CV_PAD_V * 2 + CountLines * FLineHeight;
end;

// ===========================================================================
//  SetCode — retokenize and refresh
// ===========================================================================
procedure TCodeView.SetCode(const ACode: string);
begin
  FCode := ACode;
  FTokens.Free;
  FTokens := FLexer.Tokenize(ACode);
  UpdateHeight; // uses FLineHeight (estimated or measured)
  Repaint;
end;

// ===========================================================================
//  Font measurement — called once inside Paint when Canvas is valid
// ===========================================================================
procedure TCodeView.MeasureFont;
var
  R: TRectF;
begin
  Canvas.Font.Family := 'Cascadia Code';
  Canvas.Font.Size   := CV_FONT_SIZE;

  // Measure a typical wide character — 'W' in monospace = any char
  R := RectF(0, 0, 9999, 9999);
  Canvas.MeasureText(R, 'W', False, [], TTextAlign.Leading, TTextAlign.Leading);

  FCharWidth  := R.Width;
  FLineHeight := R.Height + CV_LINE_GAP;
  FMeasured   := True;

  // Recalculate height with accurate metrics.
  // Deferred so we don't mutate layout mid-Paint.
  TThread.ForceQueue(nil, procedure
  begin
    UpdateHeight;
  end);
end;

// ===========================================================================
//  Paint
// ===========================================================================
procedure TCodeView.Paint;
var
  I: Integer;
  Token: TCodeToken;
  C: Char;
  X, Y, TW: Single;
  ColPos, NextTab: Integer;
  R: TRectF;
begin
  // --- Background ---
  Canvas.Fill.Color := CCLR_BG;
  Canvas.FillRect(LocalRect, 0, 0, [], 1);

  if FTokens.Count = 0 then
    Exit;

  // --- Measure font on first call ---
  if not FMeasured then
    MeasureFont;

  // --- Set font for all text drawing ---
  Canvas.Font.Family := 'Cascadia Code';
  Canvas.Font.Size   := CV_FONT_SIZE;

  X := CV_PAD_H;
  Y := CV_PAD_V;

  for I := 0 to FTokens.Count - 1 do
  begin
    Token := FTokens[I];

    // --- Whitespace — advance cursor, handle newlines ---
    if Token.Kind = tkWhitespace then
    begin
      for C in Token.Text do
      begin
        case C of
          #10: // LF — new line
          begin
            X := CV_PAD_H;
            Y := Y + FLineHeight;
          end;
          #13: ; // CR — skip (CRLF: LF above does the job)
          #9:    // Tab — advance to next tab stop
          begin
            ColPos  := Round((X - CV_PAD_H) / FCharWidth);
            NextTab := ((ColPos div CV_TAB_COLS) + 1) * CV_TAB_COLS;
            X       := CV_PAD_H + NextTab * FCharWidth;
          end;
        else
          X := X + FCharWidth; // regular space
        end;
      end;
      Continue;
    end;

    // --- Skip tokens below visible area (performance guard) ---
    if Y > LocalRect.Bottom then
      Break;

    // --- Monospace: token width = char count × char width ---
    TW := Length(Token.Text) * FCharWidth;

    // --- Draw token ---
    Canvas.Fill.Color := ColorForKind(Token.Kind);
    R := RectF(X, Y, X + TW, Y + FLineHeight);
    Canvas.FillText(R, Token.Text, False, 1, [], TTextAlign.Leading, TTextAlign.Leading);

    X := X + TW;
  end;
end;

end.
