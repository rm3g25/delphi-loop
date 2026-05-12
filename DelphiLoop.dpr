program DelphiLoop;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'uMain.pas',
  LoopEngine in 'LoopEngine.pas',
  LoopConfig in 'LoopConfig.pas',
  LoopTypes in 'LoopTypes.pas',
  LoopConsts in 'LoopConsts.pas',
  uUIConsts in 'uUIConsts.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
