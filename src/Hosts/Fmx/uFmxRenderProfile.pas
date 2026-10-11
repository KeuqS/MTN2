unit uFmxRenderProfile;

{ How the FireMonkey host tells the core about its renderer: the strength of
  the modal dim and of drop shadows, and the name of the graphics engine shown
  in the About dialog. With Skia the glyph edges are smooth, so the dim is
  stronger and the shadow strip lighter than on the plain FMX canvas. }

interface

/// <summary>Call once at start, after the Skia switch is decided.</summary>
procedure InstallFmxRenderProfile;

implementation

uses
  System.SysUtils,
  {$IFDEF SKIA}
  FMX.Skia,
  {$ENDIF}
  uThemeDrawing, uStrings, uUpdater;

procedure InstallFmxRenderProfile;
begin
  {$IFDEF SKIA}
  GModalDimPercent := 88;
  GShadowCover := 168;
  {$ENDIF}
  // --no-skia wins even if GlobalUseSkia was already captured by the canvas.
  GGraphicsEngineLabel :=
    function: string
    begin
      {$IFDEF SKIA}
      if GlobalUseSkia and not NoSkiaRequested then
        Exit(T('ui.about.engine.skia', 'Graphics Engine: Skia (mono AA + modal dim)'));
      {$ENDIF}
      Result := T('ui.about.engine.gdi', 'Graphics Engine: Standard GDI/FMX Renderer');
    end;
end;

end.
