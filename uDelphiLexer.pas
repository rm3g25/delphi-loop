unit uDelphiLexer;

{
  DelphiLoop — Delphi syntax lexer for code highlighting.

  Single-pass, left-to-right. Produces a flat TList<TCodeToken>.
  No FMX / VCL dependency — pure System units only.
  Caller owns the returned list.

  Recognized token kinds:
    tkKeyword    — reserved words (case-insensitive)
    tkIdentifier — user identifiers
    tkString     — 'quoted' literals and #NN char literals
    tkNumber     — decimal / float / hex ($FF)
    tkComment    — // line  |  (* block *)
    tkOperator   — := + - * / < > = ( ) [ ] . , ; : @ ^ ..
    tkWhitespace — spaces, tabs, CR, LF
    tkUnknown    — anything else (should not appear in valid code)
}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TTokenKind = (
    tkWhitespace,
    tkKeyword,
    tkIdentifier,
    tkString,
    tkNumber,
    tkComment,
    tkOperator,
    tkUnknown
  );

  TCodeToken = record
    Text: string;
    Kind: TTokenKind;
  end;

  TDelphiLexer = class
  private
    FSource: string;
    FPos: Integer;   // 1-based, Delphi string convention
    FLen: Integer;
    FKeywords: TDictionary<string, Boolean>;

    function  Current: Char; inline;
    function  Peek(AOffset: Integer = 1): Char; inline;
    function  AtEnd: Boolean; inline;
    procedure Advance(ACount: Integer = 1); inline;

    function ReadWhitespace: string;
    function ReadLineComment: string;
    function ReadBlockCommentBrace: string;
    function ReadBlockCommentParen: string;
    function ReadString: string;
    function ReadCharLiteral: string;
    function ReadNumber: string;
    function ReadHexNumber: string;
    function ReadIdentifier: string;
    function ReadOperator: string;

    function IsIdentStart(C: Char): Boolean; inline;
    function IsIdentPart(C: Char): Boolean; inline;
    function IsDigit(C: Char): Boolean; inline;

    procedure BuildKeywords;
    function  IsKeyword(const AWord: string): Boolean; inline;

    function MakeToken(const AText: string; AKind: TTokenKind): TCodeToken;
  public
    constructor Create;
    destructor  Destroy; override;

    // Returns a new TList<TCodeToken>. Caller is responsible for freeing it.
    function Tokenize(const ASource: string): TList<TCodeToken>;
  end;

implementation

// ===========================================================================
//  Keyword table
// ===========================================================================
procedure TDelphiLexer.BuildKeywords;
const
  KW: array[0..88] of string = (
    'and', 'array', 'as', 'asm',
    'begin', 'boolean', 'break',
    'cardinal', 'case', 'char', 'class', 'const', 'constructor', 'continue',
    'destructor', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exit',
    'false', 'file', 'finalization', 'finally', 'for', 'forward', 'function',
    'goto',
    'if', 'implementation', 'in', 'inherited', 'initialization', 'inline',
    'int64', 'integer', 'interface', 'is',
    'label', 'library',
    'mod',
    'nil', 'not',
    'object', 'of', 'on', 'operator', 'or', 'out', 'overload', 'override',
    'packed', 'pointer', 'private', 'procedure', 'program', 'property',
    'protected', 'public', 'published',
    'raise', 'read', 'real', 'record', 'repeat', 'result',
    'self', 'set', 'shl', 'shr', 'single', 'smallint', 'string',
    'then', 'to', 'true', 'try', 'type',
    'unit', 'until', 'uses',
    'var', 'virtual',
    'while', 'with', 'write',
    'xor'
  );
var
  W: string;
begin
  for W in KW do
    FKeywords.AddOrSetValue(W, True);
end;

// ===========================================================================
//  Constructor / Destructor
// ===========================================================================
constructor TDelphiLexer.Create;
begin
  inherited;
  FKeywords := TDictionary<string, Boolean>.Create(128);
  BuildKeywords;
end;

destructor TDelphiLexer.Destroy;
begin
  FKeywords.Free;
  inherited;
end;

// ===========================================================================
//  Navigation helpers
// ===========================================================================
function TDelphiLexer.Current: Char;
begin
  if FPos <= FLen then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TDelphiLexer.Peek(AOffset: Integer): Char;
var
  P: Integer;
begin
  P := FPos + AOffset;
  if (P >= 1) and (P <= FLen) then
    Result := FSource[P]
  else
    Result := #0;
end;

function TDelphiLexer.AtEnd: Boolean;
begin
  Result := FPos > FLen;
end;

procedure TDelphiLexer.Advance(ACount: Integer);
begin
  Inc(FPos, ACount);
end;

// ===========================================================================
//  Character classification
// ===========================================================================
function TDelphiLexer.IsIdentStart(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '_']);
end;

function TDelphiLexer.IsIdentPart(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function TDelphiLexer.IsDigit(C: Char): Boolean;
begin
  Result := CharInSet(C, ['0'..'9']);
end;

function TDelphiLexer.IsKeyword(const AWord: string): Boolean;
begin
  Result := FKeywords.ContainsKey(AWord);
end;

function TDelphiLexer.MakeToken(const AText: string; AKind: TTokenKind): TCodeToken;
begin
  Result.Text := AText;
  Result.Kind := AKind;
end;

// ===========================================================================
//  Readers — each consumes chars and returns the raw text
// ===========================================================================
function TDelphiLexer.ReadWhitespace: string;
var
  Start: Integer;
begin
  Start := FPos;
  while (not AtEnd) and CharInSet(Current, [' ', #9, #13, #10]) do
    Advance;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadLineComment: string;
// Consumes from '//' to end of line (not including the line break itself)
var
  Start: Integer;
begin
  Start := FPos;
  while (not AtEnd) and not CharInSet(Current, [#13, #10]) do
    Advance;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadBlockCommentBrace: string;
// Consumes { ... } — nested braces NOT supported (standard Pascal)
var
  Start: Integer;
begin
  Start := FPos;
  Advance; // consume '{'
  while not AtEnd do
  begin
    if Current = '}' then
    begin
      Advance;
      Break;
    end;
    Advance;
  end;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadBlockCommentParen: string;
// Consumes (* ... *)
var
  Start: Integer;
begin
  Start := FPos;
  Advance(2); // consume '(*'
  while not AtEnd do
  begin
    if (Current = '*') and (Peek = ')') then
    begin
      Advance(2);
      Break;
    end;
    Advance;
  end;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadString: string;
// Consumes '...' including doubled '' escape sequences
var
  Start: Integer;
begin
  Start := FPos;
  Advance; // opening quote
  while not AtEnd do
  begin
    if Current = '''' then
    begin
      Advance;
      // Doubled quote is an escape — keep going
      if (not AtEnd) and (Current = '''') then
        Advance
      else
        Break;
    end
    else if CharInSet(Current, [#13, #10]) then
      Break  // unterminated — stop at EOL gracefully
    else
      Advance;
  end;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadCharLiteral: string;
// Consumes #NN or #$NN — chains of them are one token
// e.g.  #13#10  or  #$0D
var
  Start: Integer;
begin
  Start := FPos;
  while (not AtEnd) and (Current = '#') do
  begin
    Advance; // '#'
    if (not AtEnd) and (Current = '$') then
    begin
      Advance; // '$'
      while (not AtEnd) and CharInSet(Current, ['0'..'9', 'A'..'F', 'a'..'f']) do
        Advance;
    end
    else
    begin
      while (not AtEnd) and IsDigit(Current) do
        Advance;
    end;
  end;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadHexNumber: string;
// Consumes $HEXDIGITS
var
  Start: Integer;
begin
  Start := FPos;
  Advance; // '$'
  while (not AtEnd) and CharInSet(Current, ['0'..'9', 'A'..'F', 'a'..'f']) do
    Advance;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadNumber: string;
// Consumes decimal integer or float: 123  3.14  1e-5
var
  Start: Integer;
begin
  Start := FPos;
  while (not AtEnd) and IsDigit(Current) do
    Advance;
  // Optional fractional part
  if (not AtEnd) and (Current = '.') and IsDigit(Peek) then
  begin
    Advance; // '.'
    while (not AtEnd) and IsDigit(Current) do
      Advance;
  end;
  // Optional exponent
  if (not AtEnd) and CharInSet(Current, ['e', 'E']) then
  begin
    Advance;
    if (not AtEnd) and CharInSet(Current, ['+', '-']) then
      Advance;
    while (not AtEnd) and IsDigit(Current) do
      Advance;
  end;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadIdentifier: string;
var
  Start: Integer;
begin
  Start := FPos;
  while (not AtEnd) and IsIdentPart(Current) do
    Advance;
  Result := Copy(FSource, Start, FPos - Start);
end;

function TDelphiLexer.ReadOperator: string;
// Consumes one operator; handles two-char ones first: := .. //
var
  C, N: Char;
begin
  C := Current;
  N := Peek;
  // Two-char operators
  if ((C = ':') and (N = '=')) or  // :=
     ((C = '.') and (N = '.')) or  // ..
     ((C = '<') and (N = '>')) or  // <>
     ((C = '<') and (N = '=')) or  // <=
     ((C = '>') and (N = '='))     // >=
  then
  begin
    Result := C + N;
    Advance(2);
  end
  else
  begin
    Result := C;
    Advance;
  end;
end;

// ===========================================================================
//  Main tokenizer
// ===========================================================================
function TDelphiLexer.Tokenize(const ASource: string): TList<TCodeToken>;
var
  C: Char;
  Text: string;
  Kind: TTokenKind;
  Lower: string;
begin
  FSource := ASource;
  FPos    := 1;
  FLen    := Length(ASource);

  Result := TList<TCodeToken>.Create;

  while not AtEnd do
  begin
    C := Current;

    // --- Whitespace ---
    if CharInSet(C, [' ', #9, #13, #10]) then
    begin
      Result.Add(MakeToken(ReadWhitespace, tkWhitespace));
      Continue;
    end;

    // --- Line comment: // ---
    if (C = '/') and (Peek = '/') then
    begin
      Result.Add(MakeToken(ReadLineComment, tkComment));
      Continue;
    end;

    // --- Block comment: { } ---
    if C = '{' then
    begin
      Result.Add(MakeToken(ReadBlockCommentBrace, tkComment));
      Continue;
    end;

    // --- Block comment: (* *) ---
    if (C = '(') and (Peek = '*') then
    begin
      Result.Add(MakeToken(ReadBlockCommentParen, tkComment));
      Continue;
    end;

    // --- String literal: '...' ---
    if C = '''' then
    begin
      Result.Add(MakeToken(ReadString, tkString));
      Continue;
    end;

    // --- Char literal: #13 #$0D ---
    if C = '#' then
    begin
      Result.Add(MakeToken(ReadCharLiteral, tkString));
      Continue;
    end;

    // --- Hex number: $FF ---
    if C = '$' then
    begin
      Result.Add(MakeToken(ReadHexNumber, tkNumber));
      Continue;
    end;

    // --- Decimal / float number ---
    if IsDigit(C) then
    begin
      Result.Add(MakeToken(ReadNumber, tkNumber));
      Continue;
    end;

    // --- Identifier or keyword ---
    if IsIdentStart(C) then
    begin
      Text  := ReadIdentifier;
      Lower := LowerCase(Text);
      if IsKeyword(Lower) then
        Kind := tkKeyword
      else
        Kind := tkIdentifier;
      Result.Add(MakeToken(Text, Kind));
      Continue;
    end;

    // --- Operators and punctuation ---
    if CharInSet(C, ['+', '-', '*', '/', '=', '<', '>', '(', ')',
                     '[', ']', '.', ',', ';', ':', '@', '^', '&', '!']) then
    begin
      Result.Add(MakeToken(ReadOperator, tkOperator));
      Continue;
    end;

    // --- Unknown — consume one char so we never loop forever ---
    Result.Add(MakeToken(C, tkUnknown));
    Advance;
  end;
end;

end.
