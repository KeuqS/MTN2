program MTN2Tui;

{ Modern Terminal Navigator 2 for a text terminal (Linux). The same windows as
  the graphical program, drawn with escape sequences. }

{$APPTYPE CONSOLE}

{$R MTN2Tui.dres}

uses
  System.SysUtils,
  uTuiMain in 'Hosts\Ansi\uTuiMain.pas';

begin
  ExitCode := RunTui;
end.
