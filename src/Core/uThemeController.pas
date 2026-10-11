unit uThemeController;

{ The active theme of a host: one shared IThemeRenderer that every window and
  dialog holds, whose inner theme is swapped when the theme changes, so open
  windows pick the new one up on their next repaint without being recreated.
  The theme is chosen by its uThemeRegistry id; an unknown id selects the
  default theme. }

interface

uses
  uThemeTypes, uThemeProxy, uThemeSpec;

type
  TThemeController = class
  private
    FProxy: TThemeProxy;
    FTheme: IThemeRenderer;
    FThemeId: string;
    FMissingId: string;
  public
    /// <summary>Loads the theme AThemeId ('' = the default one). A theme that
    /// cannot be loaded falls back to the default and is remembered in
    /// MissingId. With AImportLegacy the coloring and Markdown color files of
    /// earlier versions are imported as a user theme first.</summary>
    constructor Create(const AThemeId: string; AImportLegacy: Boolean = False;
      const ALegacyFile: string = '');
    /// <summary>Points the shared theme at ASpec and hands its file coloring
    /// to the panels; the selected theme id does not change.</summary>
    procedure Apply(const ASpec: TThemeSpec);
    /// <summary>Switches to the theme AThemeId and remembers it as the
    /// selected one; an unknown id selects the default theme. False when
    /// not even the default theme could be loaded.</summary>
    function Switch(const AThemeId: string): Boolean;
    /// <summary>The theme every window holds.</summary>
    property Theme: IThemeRenderer read FTheme;
    /// <summary>Id of the selected theme.</summary>
    property ThemeId: string read FThemeId;
    /// <summary>Id requested at start that could not be loaded; '' when it
    /// loaded.</summary>
    property MissingId: string read FMissingId;
  end;

implementation

uses
  uThemeRegistry, uColorCoding;

constructor TThemeController.Create(const AThemeId: string; AImportLegacy: Boolean;
  const ALegacyFile: string);
var
  Id, ImportedId: string;
  Spec: TThemeSpec;
begin
  inherited Create;
  Id := AThemeId;
  if Id = '' then
    Id := uThemeRegistry.DefaultThemeId;
  if AImportLegacy and uThemeRegistry.ImportLegacyFiles(Id, ALegacyFile, ImportedId) then
    Id := ImportedId;
  if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
  begin
    FMissingId := Id;
    Id := uThemeRegistry.DefaultThemeId;
    if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
      Spec := ResolveThemeSpec(nil);
  end;
  FThemeId := Id;
  FProxy := TThemeProxy.Create(uThemeRegistry.CreateThemeFromSpec(Spec));
  FTheme := FProxy;
  uColorCoding.SetActiveColorCodingGroups(Spec.FileColoring);
end;

procedure TThemeController.Apply(const ASpec: TThemeSpec);
begin
  FProxy.SetInner(uThemeRegistry.CreateThemeFromSpec(ASpec));
  uColorCoding.SetActiveColorCodingGroups(ASpec.FileColoring);
end;

function TThemeController.Switch(const AThemeId: string): Boolean;
var
  Id: string;
  Spec: TThemeSpec;
begin
  Id := AThemeId;
  if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
  begin
    Id := uThemeRegistry.DefaultThemeId;
    if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
      Exit(False);
  end;
  Apply(Spec);
  FThemeId := Id;
  Result := True;
end;

end.
