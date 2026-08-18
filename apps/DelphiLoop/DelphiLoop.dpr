program DelphiLoop;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main in 'Main.pas',
  Engine in '..\..\src\Engine\Engine.pas',
  Engine.Types in '..\..\src\Engine\Engine.Types.pas',
  Engine.Consts in '..\..\src\Engine\Engine.Consts.pas',
  Engine.Config in '..\..\src\Engine\Engine.Config.pas',
  Engine.Prompts in '..\..\src\Engine\Engine.Prompts.pas',
  Syntax.DelphiLexer in '..\..\src\Syntax\Syntax.DelphiLexer.pas',
  UI.Consts in '..\..\src\UI\UI.Consts.pas',
  UI.CodeView in '..\..\src\UI\UI.CodeView.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
