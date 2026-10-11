program MTN2Sdl;

{ Modern Terminal Navigator 2 in an SDL2 window (Linux). The same windows as
  the other programs, drawn by the pixel renderer of Hosts\Sdl. The picture
  preview unit of this host replaces the one of Platform\Posix. }

{$APPTYPE CONSOLE}

{$R MTN2Tui.dres}

uses
  System.SysUtils,
  uOverlayRenderer in 'Hosts\Sdl\Platform\uOverlayRenderer.pas',
  uSdlMain in 'Hosts\Sdl\uSdlMain.pas';

begin
  ExitCode := RunSdl;
end.
