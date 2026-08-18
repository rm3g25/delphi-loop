unit UI.CodeView;

{
  FMX custom control for syntax-highlighted Delphi code.

  Renders tokenized source to FMX Canvas using Cascadia Code (monospace).
  Token colors are VSCode dark+-inspired, tuned to the DelphiLoop palette.

  Usage:
    CV := TCodeView.Create(Self);
    CV.Parent := SomeContainer; // container clips rounded corners
    CV.Align := TAlignLayout.Top;
    CV.SetCode(MySourceString);

  Contract:
  - Parent provides rounded background + clipping (TRectangle + ClipChildren).
  - This control paints a flat background and renders tokens on top.
  - HitTest = False - read-only display, no interaction.
  - Height is auto-calculated from line count on each SetCode call.
  - Font is measured on first Paint (Canvas is valid there); subsequent
    paints use cached FCharWidth / FLineHeight.
}

interface

uses
  System.Classes,
  System.Generics.Collections,
  FMX.Controls,
  Syntax.DelphiLexer;

const
  // Syntax token colors - VSCode Dark+ palette
  CodeColorBackground = $FF1E1E2E; // code block background (slightly blue-dark)
  CodeColorKeyword = $FF569CD6; // blue - begin end if procedure ...
  CodeColorString = $FFCE9178; // orange - 'quoted string' #13
  CodeColorNumber = $FFB5CEA8; // sage green - 42 3.14 $FF
  CodeColorComment = $FF6A9955; // muted green - // { } (* *)
  CodeColorIdentifier = $FFE8E8EC; // near-white - identifiers
  CodeColorOperator = $FF888896; // dim gray - := + - . , ; ( )
  CodeColorDefault = $FFE8E8EC;

  CodeFontFamily = 'Cascadia Code';
  CodeFontSize = 12.5;
  CodePaddingHorizontal = 16.0; // horizontal padding inside the code block
  CodePaddingVertical = 13.0; // vertical padding
  CodeLineGap = 4.0; // extra pixels between lines beyond font height
  CodeTabColumns = 2; // tab = 2 spaces (Delphi community standard)

  // Estimated metrics used before first Paint measures the actual font.
  // Cascadia Code 12.5px: empirically ~7.5px wide, ~17px tall.
  CodeCharWidthEstimate = 7.5;
  CodeLineHeightEstimate = CodeFontSize * 1.5 + CodeLineGap;

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

    procedure ApplyCodeFont;
    procedure MeasureFont;
    procedure UpdateHeight;

  protected
    procedure Paint; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Tokenizes ACode and schedules a repaint. Safe to call from main thread only.
    procedure SetCode(const ACode: string);

    property Code: string read FCode;
  end;

implementation

uses
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Graphics;

// ===========================================================================
//  Free helpers - no control state involved
// ===========================================================================

function ColorForKind(AKind: TTokenKind): TAlphaColor; inline;
begin
  case AKind of
    tkKeyword: Result := CodeColorKeyword;
    tkString: Result := CodeColorString;
    tkNumber: Result := CodeColorNumber;
    tkComment: Result := CodeColorComment;
    tkOperator: Result := CodeColorOperator;
    tkIdentifier: Result := CodeColorIdentifier;
  else
    Result := CodeColorDefault;
  end;
end;

function CountLines(const AText: string): Integer;
begin
  Result := 1;
  for var Ch in AText do
    if Ch = #10 then
      Inc(Result);
end;

// ===========================================================================
//  Lifecycle
// ===========================================================================
constructor TCodeView.Create(AOwner: TComponent);
begin
  inherited;
  FLexer := TDelphiLexer.Create;
  FTokens := TList<TCodeToken>.Create;
  FMeasured := False;
  FCharWidth := CodeCharWidthEstimate;
  FLineHeight := CodeLineHeightEstimate;
  HitTest := False; // display only
end;

destructor TCodeView.Destroy;
begin
  FTokens.Free;
  FLexer.Free;
  inherited;
end;

// ===========================================================================
//  Height management
// ===========================================================================
procedure TCodeView.UpdateHeight;
begin
  Height := CodePaddingVertical * 2 + CountLines(FCode) * FLineHeight;
end;

// ===========================================================================
//  SetCode - retokenize and refresh
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
//  Font measurement - called once inside Paint when Canvas is valid
// ===========================================================================
procedure TCodeView.ApplyCodeFont;
begin
  Canvas.Font.Family := CodeFontFamily;
  Canvas.Font.Size := CodeFontSize;
end;

procedure TCodeView.MeasureFont;
var
  Bounds: TRectF;
begin
  ApplyCodeFont;

  // Measure a typical wide character - 'W' in monospace = any char
  Bounds := RectF(0, 0, 9999, 9999);
  Canvas.MeasureText(Bounds, 'W', False, [], TTextAlign.Leading, TTextAlign.Leading);

  FCharWidth := Bounds.Width;
  FLineHeight := Bounds.Height + CodeLineGap;
  FMeasured := True;

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
  CursorX: Single;
  CursorY: Single;
begin
  // --- Background ---
  Canvas.Fill.Color := CodeColorBackground;
  Canvas.FillRect(LocalRect, 0, 0, [], 1);

  if FTokens.Count = 0 then
    Exit;

  // --- Measure font on first call ---
  if not FMeasured then
    MeasureFont;

  // --- Set font for all text drawing ---
  ApplyCodeFont;

  CursorX := CodePaddingHorizontal;
  CursorY := CodePaddingVertical;

  for var i := 0 to FTokens.Count - 1 do
  begin
    var Token := FTokens[i];

    // --- Whitespace - advance cursor, handle newlines ---
    if Token.Kind = tkWhitespace then
    begin
      for var Ch in Token.Text do
      begin
        case Ch of
          #10: // LF - new line
          begin
            CursorX := CodePaddingHorizontal;
            CursorY := CursorY + FLineHeight;
          end;
          #13: ; // CR - skip (CRLF: LF above does the job)
          #9: // Tab - advance to next tab stop
          begin
            var Column := Round((CursorX - CodePaddingHorizontal) / FCharWidth);
            var NextTabStop := ((Column div CodeTabColumns) + 1) * CodeTabColumns;
            CursorX := CodePaddingHorizontal + NextTabStop * FCharWidth;
          end;
        else
          CursorX := CursorX + FCharWidth; // regular space
        end;
      end;
      Continue;
    end;

    // --- Skip tokens below visible area (performance guard) ---
    if CursorY > LocalRect.Bottom then
      Break;

    // --- Monospace: token width = char count x char width ---
    var TokenWidth := Length(Token.Text) * FCharWidth;

    // --- Draw token ---
    Canvas.Fill.Color := ColorForKind(Token.Kind);
    var TokenRect := RectF(CursorX, CursorY, CursorX + TokenWidth, CursorY + FLineHeight);
    Canvas.FillText(TokenRect, Token.Text, False, 1, [], TTextAlign.Leading, TTextAlign.Leading);

    CursorX := CursorX + TokenWidth;
  end;
end;

end.
