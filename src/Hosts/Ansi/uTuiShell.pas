unit uTuiShell;

{ The program behind the text-terminal host: the theme, the compositor with
  the dual panel window (documents and terminals live in its tabs) and the
  background console, the commands the windows ask of their host, and the
  routing of keys and mouse events. It knows nothing about the terminal
  itself: it takes decoded events (uTermInput) and returns the character grid
  to show. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  uTerminalTypes, uThemeTypes, uThemeProxy, uThemeSpec, uMdiCompositor,
  uDualPanelWindow, uConsoleWindow, uSession, uTermInput, uCoreTimer,
  uUpdateController, uDisplaySettings;

type
  TTuiShell = class
  private
    FThemeProxy: TThemeProxy;
    FTheme: IThemeRenderer;
    FThemeName: string;
    FMdi: TMdiCompositor;
    FDualPanel: TDualPanelWindow;
    FConsole: TConsoleWindow;
    FSession: TMtnSession;
    FCols: Integer;
    FRows: Integer;
    FGrid: TTerminalGrid;
    FDirty: Boolean;
    FQuit: Boolean;
    FPeekTimer: TCoreTimer;
    FDriveTimer: TCoreTimer;
    FAltTimer: TCoreTimer;
    FHeldShift: TShiftState;
    FUpdater: TUpdateController;
    FUpdateTimer: TCoreTimer;
    FLastClickTick: UInt64;
    FLastClickCol: Integer;
    FLastClickRow: Integer;
    FButtonsDown: Integer;
    procedure Recompose;
    procedure LoadTheme(const AThemeId: string);
    procedure ApplyThemeSpec(const ASpec: TThemeSpec);
    procedure SwitchTheme(const AThemeId: string);
    procedure RestoreSession;
    procedure ApplyChromeRows(AMenuBar, AKeyBar, AStatusLine: Boolean);
    function GetDisplaySettings: TDisplaySettings;
    procedure ApplyDisplaySettings(const ASettings: TDisplaySettings);
    procedure CreateDualPanel;
    function EnsureConsole: TConsoleWindow;
    procedure SyncHiddenConsoleArea(ACols, ARows: Integer);
    procedure ShowConsoleMode;
    procedure ShowPanelMode;
    procedure ApplyConsoleLayout;
    function IsConsoleActiveInConsoleMode: Boolean;
    function IsConsoleScrollOrSelectionKey(AKey: Word; AKeyChar: Char;
      AShift: TShiftState): Boolean;
    procedure SyncKeyModifiers(AShift: TShiftState);
    function DispatchTerminalKey(var AKey: Word; var AKeyChar: Char;
      AShift: TShiftState): Boolean;
    procedure HandleKey(const AEvent: TTermEvent);
    procedure HandleMouse(const AEvent: TTermEvent);
    procedure HandleMouseDown(const AEvent: TTermEvent);
    procedure HandleMouseMove(const AEvent: TTermEvent);
    procedure HandleMouseUp(const AEvent: TTermEvent);
    procedure HandleWheel(const AEvent: TTermEvent);
    procedure HandlePaste(const AText: string);
    // Commands of the dual panel window.
    procedure DualPanelContentChanged(Sender: TObject);
    procedure DualPanelQuitRequest(Sender: TObject);
    procedure DualPanelOpenUpdates(Sender: TObject);
    procedure UpdateTimerTick(Sender: TObject);
    procedure DualPanelOpenViewer(const AURI: string);
    procedure DualPanelOpenEditor(const AURI: string);
    procedure DualPanelRunCommand(const ACommand, AWorkingDir: string);
    procedure DualPanelRunInBackground(Sender: TObject);
    procedure DualPanelReturnWhenDone(Sender: TObject);
    procedure DualPanelShellCwdSync(const APath: string);
    function DualPanelSaveConsoleOutput(const APath: string; out AError: string): Boolean;
    procedure DualPanelClearConsoleBuffer(Sender: TObject);
    procedure DualPanelToggleConsole(Sender: TObject);
    procedure DualPanelOpenTerminal(const AProfileId, ACwd: string);
    procedure DualPanelOpenTerminalWith(const AProfileId, ACwd, ACommand: string);
    function DualPanelLaunchConsoleFile(const APath: string): Boolean;
    procedure ChangeConsoleProfile(const AProfileId: string);
    function GetConsoleProfile: string;
    function GetConsoleStartOnLaunch: Boolean;
    procedure SetConsoleStartOnLaunch(AValue: Boolean);
    function GetConsoleCwdToPanels: Boolean;
    procedure SetConsoleCwdToPanels(AValue: Boolean);
    procedure ThemeSelected(const AThemeId: string);
    procedure ThemePreview(const ASpec: TThemeSpec);
    function GetActiveThemeId: string;
    procedure PeekTimerTick(Sender: TObject);
    procedure DriveTimerTick(Sender: TObject);
    procedure AltTimerTick(Sender: TObject);
    // Commands of the console window.
    procedure ConsoleContentChanged(Sender: TObject);
    procedure ConsoleCloseRequest(Sender: TObject);
    procedure ConsoleBackToPanels(Sender: TObject);
    procedure ConsoleDismiss(Sender: TObject);
    procedure ConsoleFocusCommandLine(Sender: TObject);
    procedure ConsoleSyncDirToPanels(Sender: TObject);
    function ConsoleGetCmdHistory: TArray<string>;
    procedure ConsoleCommandExecuted(const ACommand: string);
  public
    constructor Create(ACols, ARows: Integer);
    destructor Destroy; override;
    procedure Resize(ACols, ARows: Integer);
    /// <summary>The composed screen; valid until the next call.</summary>
    function Compose: TTerminalGrid;
    procedure HandleEvent(const AEvent: TTermEvent);
    /// <summary>Saves the panels and settings; call before leaving.</summary>
    procedure PersistSession;
    /// <summary>The terminal window title: the program and the folder of the
    /// active panel.</summary>
    function Title: string;
    /// <summary>Starts the plugin host and lets plugins reach the panels and
    /// show dialogs; call once before the first frame.</summary>
    procedure AttachPlugins(const APluginsDir: string);
    /// <summary>Stops the plugin host.</summary>
    procedure DetachPlugins;
    /// <summary>Starts the self-updater: Help > Updates and the quiet check
    /// shortly after the start.</summary>
    procedure AttachUpdater;
    /// <summary>Installs a staged update that was left for the exit, then
    /// drops the updater.</summary>
    procedure DetachUpdater;
    /// <summary>True when the screen must be composed again.</summary>
    property Dirty: Boolean read FDirty write FDirty;
    property Quit: Boolean read FQuit;
    property DualPanel: TDualPanelWindow read FDualPanel;
    property Cols: Integer read FCols;
    property Rows: Integer read FRows;
  end;

implementation

uses
  System.IOUtils, uThemeRegistry, uColorCoding, uKeymap, uStrings, uChromeRows,
  uShellProfiles, uDualPanelTypes, uConsoleSettings,
  uEditorSearch, uEditorWindow, uBaseConsoleWindow, uPanelColumns, uThemeDrawing,
  uDualPanelDrag, uKeyChord, uDialogHost, uPlatformInfo, uTerminalWindow,
  uDualPanelUiTypes, uToast, uWindowChrome, uConsoleLaunch, uPluginHost,
  uPluginPanelServices, uPluginServices, uPluginUi, uPluginChrome, uDialogTypes, uVfsTypes,
  uOverlayRenderer;

const
  cDefaultThemeFallback = 'NDN';
  // Pause after the last Ctrl+Left/Right that applies the chosen drive.
  cDriveCommitMs = 700;
  cAltReleaseMs = 1500;

constructor TTuiShell.Create(ACols, ARows: Integer);
begin
  inherited Create;
  FCols := Max(ACols, 20);
  FRows := Max(ARows, 6);
  FLastClickCol := -1;
  FLastClickRow := -1;
  ReloadKeymap('');
  // The terminal has no window frame of its own to draw and no file icons;
  // pictures come as colored cells.
  GShowTitleBar := True;
  GShowPanelIcons := False;
  GFileDragEnabled := False;
  SetOverlayRepaintHandler(
    procedure
    begin
      Recompose;
    end);

  FSession := Default(TMtnSession);
  FSession.ConsoleRestartOnExit := True;
  FSession.TerminalCloseOnExit := True;
  FSession.ConsoleCwdToPanels := True;
  FSession.RestoreWorkspaceOnStart := True;
  FSession.CursorBlink := True;
  FSession.ShowNotifications := True;
  FSession.ShowTitleBar := True;
  FSession.ShowMenuBar := True;
  FSession.ShowKeyBar := True;
  FSession.ShowStatusLine := True;
  FSession.PassiveCursor := True;
  FSession.ShadowStyle := ShadowStyleId(ssClassic);
  FSession.MarkedRows := MarkedRowStyleId(mrsText);

  if TryLoadSession(DefaultSessionFilePath, FSession) then
    SetLocale(FSession.Language);
  LoadTheme(FSession.ThemeName);
  FTheme := FThemeProxy;
  FMdi := TMdiCompositor.Create(FTheme);
  CreateDualPanel;
  RestoreSession;
  FPeekTimer := TCoreTimer.Create(nil);
  FPeekTimer.Enabled := False;
  FPeekTimer.OnTimer := PeekTimerTick;
  FDriveTimer := TCoreTimer.Create(nil);
  FDriveTimer.Enabled := False;
  FDriveTimer.Interval := cDriveCommitMs;
  FDriveTimer.OnTimer := DriveTimerTick;
  FAltTimer := TCoreTimer.Create(nil);
  FAltTimer.Enabled := False;
  FAltTimer.Interval := cAltReleaseMs;
  FAltTimer.OnTimer := AltTimerTick;
  AllocTerminalGrid(FGrid, FCols, FRows);
  FDirty := True;
end;

destructor TTuiShell.Destroy;
begin
  SetOverlayRepaintHandler(nil);
  FreeAndNil(FUpdateTimer);
  FreeAndNil(FUpdater);
  FreeAndNil(FPeekTimer);
  FreeAndNil(FDriveTimer);
  FreeAndNil(FAltTimer);
  // The windows call back into the shell while they close.
  if Assigned(FDualPanel) then
  begin
    FDualPanel.OnContentChanged := nil;
    FDualPanel.OnQuitRequest := nil;
  end;
  if Assigned(FConsole) then
  begin
    FConsole.OnContentChanged := nil;
    FConsole.OnCloseRequest := nil;
    FConsole.OnBackToPanels := nil;
    FConsole.OnDismissConsole := nil;
    FConsole.OnFocusCommandLine := nil;
    FConsole.OnSyncDirToPanels := nil;
    FConsole.OnGetCmdHistory := nil;
    FConsole.OnCommandExecuted := nil;
  end;
  FreeAndNil(FMdi);
  FTheme := nil;
  FThemeProxy := nil;
  inherited Destroy;
end;

procedure TTuiShell.AttachPlugins(const APluginsDir: string);
begin
  StartPluginHost(APluginsDir);
  // Dialogs a plugin asks for appear only over the panels, never inside an
  // editor, viewer or terminal.
  SetPluginDialogHost(
    function(const ADecl: TDialogDeclaration; const AOnCommand: TProc<string, string>): Boolean
    begin
      Result := Assigned(FDualPanel) and (FMdi.Active = FDualPanel) and
        FDualPanel.Visible and FDualPanel.ShowHostDialog(ADecl, AOnCommand);
      if Result then
        Recompose;
    end);
  SetPluginHostServices(BuildPanelPluginServices(
    function: TDualPanelWindow
    begin
      Result := FDualPanel;
    end,
    function: Boolean
    begin
      Result := FMdi.Active = FDualPanel;
    end,
    procedure
    begin
      Recompose;
    end));
  SetPluginChromeChanged(
    procedure
    begin
      Recompose;
    end);
end;

procedure TTuiShell.DetachPlugins;
begin
  SetPluginHostServices(Default(TPluginHostServices));
  SetPluginChromeChanged(nil);
  SetPluginDialogHost(nil);
  StopPluginHost;
end;

procedure TTuiShell.Recompose;
begin
  FDirty := True;
end;

{ ---- theme -------------------------------------------------------------- }

procedure TTuiShell.ApplyThemeSpec(const ASpec: TThemeSpec);
begin
  FThemeProxy.SetInner(uThemeRegistry.CreateThemeFromSpec(ASpec));
  uColorCoding.SetActiveColorCodingGroups(ASpec.FileColoring);
end;

procedure TTuiShell.LoadTheme(const AThemeId: string);
var
  Id: string;
  Spec: TThemeSpec;
begin
  Id := AThemeId;
  if Id = '' then
    Id := uThemeRegistry.DefaultThemeId;
  if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
  begin
    Id := uThemeRegistry.DefaultThemeId;
    if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
      Spec := ResolveThemeSpec(nil);
  end;
  FThemeName := Id;
  FThemeProxy := TThemeProxy.Create(uThemeRegistry.CreateThemeFromSpec(Spec));
  uColorCoding.SetActiveColorCodingGroups(Spec.FileColoring);
end;

procedure TTuiShell.SwitchTheme(const AThemeId: string);
var
  Id: string;
  Spec: TThemeSpec;
begin
  Id := AThemeId;
  if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
  begin
    Id := uThemeRegistry.DefaultThemeId;
    if not uThemeRegistry.TryLoadThemeSpec(Id, Spec) then
      Exit;
  end;
  ApplyThemeSpec(Spec);
  FThemeName := Id;
  Recompose;
end;

procedure TTuiShell.ThemeSelected(const AThemeId: string);
begin
  SwitchTheme(AThemeId);
end;

procedure TTuiShell.ThemePreview(const ASpec: TThemeSpec);
begin
  ApplyThemeSpec(ASpec);
  Recompose;
end;

function TTuiShell.GetActiveThemeId: string;
begin
  Result := FThemeName;
end;

{ ---- session ------------------------------------------------------------ }

function TTuiShell.GetDisplaySettings: TDisplaySettings;
begin
  Result := DefaultDisplaySettings;
  Result.CursorBlink := FSession.CursorBlink;
  Result.ShowPanelIcons := GShowPanelIcons;
  Result.ShowNotifications := GShowToasts;
  Result.ShowTitleBar := GShowTitleBar;
  Result.ShowMenuBar := GShowMenuBar;
  Result.FileDrag := GFileDragEnabled;
  Result.PassiveCursor := GShowPassiveCursor;
  Result.ShowKeyBar := GShowKeyBar;
  Result.ShowStatusLine := GShowStatusLine;
  Result.ShadowStyle := GShadowStyle;
  Result.MarkedRowStyle := GMarkedRowStyle;
  Result.SelectFolders := FDualPanel.SelectFolders;
  Result.Language := CurrentLocale;
end;

procedure TTuiShell.ApplyDisplaySettings(const ASettings: TDisplaySettings);
var
  LanguageChanged: Boolean;
begin
  // The terminal owns the font, the zoom, the window frame and the icons.
  FSession.CursorBlink := ASettings.CursorBlink;
  FSession.ShowNotifications := ASettings.ShowNotifications;
  GShowToasts := ASettings.ShowNotifications;
  FSession.PassiveCursor := ASettings.PassiveCursor;
  GShowPassiveCursor := ASettings.PassiveCursor;
  FSession.ShowMenuBar := ASettings.ShowMenuBar;
  FSession.ShowKeyBar := ASettings.ShowKeyBar;
  FSession.ShowStatusLine := ASettings.ShowStatusLine;
  ApplyChromeRows(ASettings.ShowMenuBar, ASettings.ShowKeyBar, ASettings.ShowStatusLine);
  FSession.ShadowStyle := ShadowStyleId(ASettings.ShadowStyle);
  GShadowStyle := ASettings.ShadowStyle;
  FSession.MarkedRows := MarkedRowStyleId(ASettings.MarkedRowStyle);
  GMarkedRowStyle := ASettings.MarkedRowStyle;
  FSession.SelectFolders := ASettings.SelectFolders;
  FDualPanel.SelectFolders := ASettings.SelectFolders;
  LanguageChanged := not SameText(CurrentLocale, ASettings.Language) and
    not (SameText(CurrentLocale, 'en') and (Trim(ASettings.Language) = ''));
  FSession.Language := ASettings.Language;
  if LanguageChanged then
  begin
    SetLocale(ASettings.Language);
    FDualPanel.ReloadMenuStructure;
  end;
  Recompose;
end;

procedure TTuiShell.ApplyChromeRows(AMenuBar, AKeyBar, AStatusLine: Boolean);
begin
  GShowMenuBar := AMenuBar;
  GShowKeyBar := AKeyBar;
  GShowStatusLine := AStatusLine;
  if Assigned(FConsole) then
    FConsole.LayoutBottomMargin := ChromeBottomRows;
end;

procedure TTuiShell.RestoreSession;
var
  Sess: TMtnSession;
begin
  if not TryLoadSession(DefaultSessionFilePath, Sess) then
    Exit;
  FSession := Sess;
  FDualPanel.ApplySessionState(Sess.Panels);
  FDualPanel.TerminalCloseOnExit := Sess.TerminalCloseOnExit;
  FDualPanel.AutoSyncConsoleCwd := Sess.AutoSyncConsoleCwd;
  FDualPanel.SelectFolders := Sess.SelectFolders;
  if Sess.RestoreWorkspaceOnStart then
    FDualPanel.RestoreWorkspaceLibrary(Sess.LastWorkspaceId);
  GCustomColumnsConfig := Sess.CustomColumns;
  GShowToasts := Sess.ShowNotifications;
  GShowPassiveCursor := Sess.PassiveCursor;
  ApplyChromeRows(Sess.ShowMenuBar, Sess.ShowKeyBar, Sess.ShowStatusLine);
  GShadowStyle := ShadowStyleFromId(Sess.ShadowStyle);
  GMarkedRowStyle := MarkedRowStyleFromId(Sess.MarkedRows);
  GConsoleSettings.ScrollbackLines := ClampScrollbackLines(Sess.ConsoleScrollback);
  GConsoleSettings.ConfirmMultiLinePaste := Sess.ConsoleConfirmPaste;
  GConsoleSettings.TrimCopiedSpaces := Sess.ConsoleTrimCopy;
  GConsoleSettings.TrimPastedSpaces := Sess.ConsoleTrimPaste;
  GConsoleSettings.ReturnToPanels := Sess.ConsoleReturnToPanels;
  GConsoleSettings.BackgroundShowMs := ClampBackgroundShowMs(Sess.ConsoleBackgroundShowMs);
  GEditorSearchOptions.MatchCase := Sess.EditorSearchCase;
  GEditorSearchOptions.WholeWord := Sess.EditorSearchWords;
  GEditorSearchOptions.UseRegex := Sess.EditorSearchRegex;
end;

procedure TTuiShell.PersistSession;
var
  Sess: TMtnSession;
begin
  if not Assigned(FDualPanel) then
    Exit;
  Sess := FSession;
  Sess.Version := cSessionVersion;
  Sess.Panels := FDualPanel.ExportSessionState;
  if Assigned(FConsole) then
  begin
    Sess.BackgroundConsoleProfile := FConsole.ProfileId;
    Sess.ConsoleRestartOnExit := FConsole.RestartOnExit;
  end;
  Sess.TerminalCloseOnExit := FDualPanel.TerminalCloseOnExit;
  Sess.AutoSyncConsoleCwd := FDualPanel.AutoSyncConsoleCwd;
  Sess.ThemeName := FThemeName;
  Sess.ThemeFile := '';
  Sess.ShowNotifications := GShowToasts;
  Sess.ShowMenuBar := GShowMenuBar;
  Sess.ShowKeyBar := GShowKeyBar;
  Sess.ShowStatusLine := GShowStatusLine;
  Sess.PassiveCursor := GShowPassiveCursor;
  Sess.ShadowStyle := ShadowStyleId(GShadowStyle);
  Sess.MarkedRows := MarkedRowStyleId(GMarkedRowStyle);
  Sess.ConsoleScrollback := GConsoleSettings.ScrollbackLines;
  Sess.ConsoleConfirmPaste := GConsoleSettings.ConfirmMultiLinePaste;
  Sess.ConsoleTrimCopy := GConsoleSettings.TrimCopiedSpaces;
  Sess.ConsoleTrimPaste := GConsoleSettings.TrimPastedSpaces;
  Sess.ConsoleReturnToPanels := GConsoleSettings.ReturnToPanels;
  Sess.ConsoleBackgroundShowMs := GConsoleSettings.BackgroundShowMs;
  Sess.EditorSearchCase := GEditorSearchOptions.MatchCase;
  Sess.EditorSearchWords := GEditorSearchOptions.WholeWord;
  Sess.EditorSearchRegex := GEditorSearchOptions.UseRegex;
  Sess.SelectFolders := FDualPanel.SelectFolders;
  Sess.Language := CurrentLocale;
  Sess.CustomColumns := GCustomColumnsConfig;
  Sess.LastWorkspaceId := FDualPanel.WorkspaceLibraryId;
  FSession := Sess;
  SaveSession(DefaultSessionFilePath, Sess);
end;

{ ---- windows ------------------------------------------------------------ }

procedure TTuiShell.CreateDualPanel;
begin
  FDualPanel := TDualPanelWindow.Create(FTheme, FMdi.AllocId);
  FDualPanel.OnContentChanged := DualPanelContentChanged;
  FDualPanel.OnOpenViewer := DualPanelOpenViewer;
  FDualPanel.OnOpenEditor := DualPanelOpenEditor;
  FDualPanel.OnQuitRequest := DualPanelQuitRequest;
  FDualPanel.OnRunCommand := DualPanelRunCommand;
  FDualPanel.OnReturnWhenDone := DualPanelReturnWhenDone;
  FDualPanel.OnRunInBackground := DualPanelRunInBackground;
  FDualPanel.OnShellCwdSync := DualPanelShellCwdSync;
  FDualPanel.OnSaveConsoleOutput := DualPanelSaveConsoleOutput;
  FDualPanel.OnClearConsoleBuffer := DualPanelClearConsoleBuffer;
  FDualPanel.OnGetDisplaySettings := GetDisplaySettings;
  FDualPanel.OnApplyDisplaySettings := ApplyDisplaySettings;
  FDualPanel.OnToggleConsole := DualPanelToggleConsole;
  FDualPanel.OnOpenTerminal := DualPanelOpenTerminal;
  FDualPanel.OnLaunchConsoleFile := DualPanelLaunchConsoleFile;
  FDualPanel.OnQueryConsoleKeyCapture :=
    function: Boolean
    begin
      Result := IsConsoleActiveInConsoleMode and Assigned(FConsole) and
        FConsole.KeysToProgram;
    end;
  FDualPanel.OnSetConsoleProfile := ChangeConsoleProfile;
  FDualPanel.OnGetConsoleProfile := GetConsoleProfile;
  FDualPanel.OnGetConsoleStartOnLaunch := GetConsoleStartOnLaunch;
  FDualPanel.OnSetConsoleStartOnLaunch := SetConsoleStartOnLaunch;
  FDualPanel.OnGetConsoleCwdToPanels := GetConsoleCwdToPanels;
  FDualPanel.OnSetConsoleCwdToPanels := SetConsoleCwdToPanels;
  FDualPanel.OnThemeSelect := ThemeSelected;
  FDualPanel.OnThemePreview := ThemePreview;
  FDualPanel.OnGetActiveThemeId := GetActiveThemeId;
  FMdi.AttachWindow(FDualPanel);
end;

function TTuiShell.EnsureConsole: TConsoleWindow;
var
  ProfileId: string;
begin
  if not Assigned(FConsole) then
  begin
    ProfileId := FSession.BackgroundConsoleProfile;
    FConsole := TConsoleWindow.Create(FTheme, FMdi.AllocId, ProfileId);
    FConsole.RestartOnExit := FSession.ConsoleRestartOnExit;
    FConsole.OnContentChanged := ConsoleContentChanged;
    FConsole.OnCloseRequest := ConsoleCloseRequest;
    FConsole.OnBackToPanels := ConsoleBackToPanels;
    FConsole.OnDismissConsole := ConsoleDismiss;
    FConsole.OnFocusCommandLine := ConsoleFocusCommandLine;
    FConsole.OnSyncDirToPanels := ConsoleSyncDirToPanels;
    FConsole.OnGetCmdHistory := ConsoleGetCmdHistory;
    FConsole.OnCommandExecuted := ConsoleCommandExecuted;
    FMdi.AttachWindow(FConsole);
    // Attaching activates the window; it stays hidden until it is asked for.
    FConsole.Visible := False;
    FMdi.Activate(FDualPanel);
    FConsole.LayoutBottomMargin := ChromeBottomRows;
    SyncHiddenConsoleArea(FCols, FRows);
  end;
  Result := FConsole;
end;

procedure TTuiShell.SyncHiddenConsoleArea(ACols, ARows: Integer);
begin
  if Assigned(FConsole) and not FConsole.Visible and (ACols > 0) and (ARows > 1) then
    FConsole.Area := TRectI.Make(0, 0, ACols - 1, Max(ARows - 1 - ChromeBottomRows, 1));
end;

procedure TTuiShell.ApplyConsoleLayout;
begin
  FMdi.LayoutMaximized(FCols, FRows);
end;

procedure TTuiShell.ShowConsoleMode;
begin
  EnsureConsole;
  FDualPanel.Visible := True;
  FDualPanel.ConsoleMode := True;
  FDualPanel.CmdFocused := False;
  FConsole.Visible := True;
  ApplyConsoleLayout;
  if not FConsole.Running then
    FConsole.EnsureShell(FDualPanel.ActiveLocalPath);
  FMdi.Activate(FConsole);
end;

procedure TTuiShell.ShowPanelMode;
var
  Cwd: string;
begin
  if Assigned(FConsole) and FSession.ConsoleCwdToPanels and FConsole.TakeCwdChange(Cwd) then
    FDualPanel.SetActivePanelDir(Cwd);
  if Assigned(FConsole) then
    FConsole.Visible := False;
  FDualPanel.ConsoleMode := False;
  FDualPanel.Visible := True;
  FMdi.Activate(FDualPanel);
end;

function TTuiShell.IsConsoleActiveInConsoleMode: Boolean;
begin
  Result := Assigned(FDualPanel) and FDualPanel.ConsoleMode and Assigned(FMdi) and
    Assigned(FMdi.Active) and (FMdi.Active = FConsole);
end;

{ ---- dual panel commands --------------------------------------------------- }

procedure TTuiShell.DualPanelContentChanged(Sender: TObject);
begin
  Recompose;
end;

procedure TTuiShell.DualPanelQuitRequest(Sender: TObject);
begin
  FQuit := True;
end;

procedure TTuiShell.DualPanelOpenUpdates(Sender: TObject);
begin
  if Assigned(FUpdater) then
    FUpdater.OpenUpdatesDialog;
end;

procedure TTuiShell.UpdateTimerTick(Sender: TObject);
begin
  FUpdateTimer.Enabled := False;
  if Assigned(FUpdater) then
    FUpdater.StartupCheck;
end;

procedure TTuiShell.AttachUpdater;
var
  Host: TUpdateHost;
begin
  Host.ShowDialog :=
    function(ADecl: TDialogDeclaration; AOnCommand: TProc<string, string>): Boolean
    begin
      // Only over the panels: never inside an editor, viewer or terminal the
      // user is working in. The controller retries later.
      Result := Assigned(FDualPanel) and (FMdi.Active = FDualPanel) and
        FDualPanel.Visible and FDualPanel.ShowHostDialog(ADecl, AOnCommand);
      if Result then
        Recompose;
    end;
  Host.HasBusyJob :=
    function: Boolean
    begin
      Result := Assigned(FDualPanel) and FDualPanel.HasBusyJob;
    end;
  Host.RequestClose :=
    procedure
    begin
      FQuit := True;
    end;
  Host.OpenFile :=
    procedure(APath: string)
    begin
      DualPanelOpenViewer(PathToFileUri(APath));
    end;
  FUpdater := TUpdateController.Create(Host);
  FDualPanel.OnOpenUpdates := DualPanelOpenUpdates;
  FUpdateTimer := TCoreTimer.Create(nil);
  FUpdateTimer.Interval := 5000;
  FUpdateTimer.OnTimer := UpdateTimerTick;
  FUpdateTimer.Enabled := True;
end;

procedure TTuiShell.DetachUpdater;
begin
  if Assigned(FUpdateTimer) then
    FUpdateTimer.Enabled := False;
  if Assigned(FUpdater) then
    FUpdater.BeforeExit;
  if Assigned(FDualPanel) then
    FDualPanel.OnOpenUpdates := nil;
  FreeAndNil(FUpdater);
end;

procedure TTuiShell.DualPanelOpenViewer(const AURI: string);
begin
  if AURI = '' then
    Exit;
  FDualPanel.OpenDocument(AURI, True);
  FMdi.Activate(FDualPanel);
  Recompose;
end;

procedure TTuiShell.DualPanelOpenEditor(const AURI: string);
begin
  if AURI = '' then
    Exit;
  FDualPanel.OpenDocument(AURI, False);
  FMdi.Activate(FDualPanel);
  Recompose;
end;

procedure TTuiShell.DualPanelRunCommand(const ACommand, AWorkingDir: string);
begin
  ShowConsoleMode;
  ApplyConsoleLayout;
  FConsole.RunCommand(ACommand, AWorkingDir);
  Recompose;
end;

procedure TTuiShell.DualPanelRunInBackground(Sender: TObject);
begin
  FPeekTimer.Enabled := False;
  FPeekTimer.Interval := ClampBackgroundShowMs(GConsoleSettings.BackgroundShowMs);
  FPeekTimer.Enabled := True;
end;

procedure TTuiShell.PeekTimerTick(Sender: TObject);
begin
  FPeekTimer.Enabled := False;
  if IsConsoleActiveInConsoleMode then
    ConsoleBackToPanels(Self);
end;

procedure TTuiShell.AltTimerTick(Sender: TObject);
begin
  FAltTimer.Enabled := False;
  // No key release arrives from a terminal: Alt counts as released when no
  // Alt key has come for a while, which closes Alt quick search and the
  // directory-history popup.
  SyncKeyModifiers(FHeldShift - [ssAlt]);
  Recompose;
end;

procedure TTuiShell.DriveTimerTick(Sender: TObject);
begin
  FDriveTimer.Enabled := False;
  // A terminal reports no key releases: the drive chosen with Ctrl+Left/Right
  // is applied when the keys stop coming.
  FDualPanel.ApplyDrivePreview;
  Recompose;
end;

procedure TTuiShell.DualPanelReturnWhenDone(Sender: TObject);
begin
  if Assigned(FConsole) then
    FConsole.ReturnToPanelsWhenDone;
end;

procedure TTuiShell.DualPanelShellCwdSync(const APath: string);
begin
  if Assigned(FConsole) then
    FConsole.SyncWorkingDir(APath);
end;

function TTuiShell.DualPanelSaveConsoleOutput(const APath: string;
  out AError: string): Boolean;
begin
  if not Assigned(FConsole) then
  begin
    AError := T('ui.toast.noConsole', 'The background console has not been started yet');
    Exit(False);
  end;
  Result := FConsole.SaveOutputToFile(APath, AError);
end;

procedure TTuiShell.DualPanelClearConsoleBuffer(Sender: TObject);
begin
  if Assigned(FConsole) then
  begin
    FConsole.ClearOutputBuffer;
    Recompose;
  end;
end;

procedure TTuiShell.DualPanelToggleConsole(Sender: TObject);
begin
  if FDualPanel.ConsoleMode then
  begin
    if Assigned(FConsole) and FConsole.Visible then
      ShowPanelMode
    else
      ShowConsoleMode;
  end
  else if Assigned(FConsole) and FConsole.Visible and (FMdi.Active = FConsole) then
    ShowPanelMode
  else
    ShowConsoleMode;
  Recompose;
end;

procedure TTuiShell.DualPanelOpenTerminal(const AProfileId, ACwd: string);
begin
  DualPanelOpenTerminalWith(AProfileId, ACwd, '');
end;

procedure TTuiShell.DualPanelOpenTerminalWith(const AProfileId, ACwd, ACommand: string);
begin
  if AProfileId = '' then
    Exit;
  if FDualPanel.ConsoleMode then
    ShowPanelMode;
  FDualPanel.OpenTerminal(AProfileId, ACwd, ACommand);
  FMdi.Activate(FDualPanel);
  Recompose;
end;

function TTuiShell.DualPanelLaunchConsoleFile(const APath: string): Boolean;
var
  Kind: TLaunchFileKind;
  Cwd, Profile: string;
begin
  Kind := DetectLaunchFileKind(APath);
  Result := Kind <> lfkOther;
  if not Result then
    Exit;
  Cwd := ExtractFileDir(APath);
  Profile := GetConsoleProfile;
  case ChooseConsoleLaunch(Kind, Profile, Assigned(FConsole) and FConsole.ShellBusy) of
    cltConsole:
      DualPanelRunCommand(BuildConsoleLaunchLine(APath, Kind, Profile), Cwd);
    cltTerminal:
      begin
        Profile := TerminalProfileForLaunch(Kind);
        DualPanelOpenTerminalWith(Profile, Cwd, BuildConsoleLaunchLine(APath, Kind, Profile));
      end;
  else
    Result := False;
  end;
end;

procedure TTuiShell.ChangeConsoleProfile(const AProfileId: string);
var
  ProfileId: string;
  WasVisible: Boolean;
begin
  ProfileId := CanonicalShellProfileId(AProfileId);
  FSession.BackgroundConsoleProfile := ProfileId;
  if not Assigned(FConsole) or SameText(FConsole.ProfileId, ProfileId) then
    Exit;
  WasVisible := FConsole.Visible;
  FConsole.OnCloseRequest := nil;
  FConsole.OnContentChanged := nil;
  FConsole.OnBackToPanels := nil;
  FConsole.OnDismissConsole := nil;
  FConsole.OnFocusCommandLine := nil;
  FConsole.OnSyncDirToPanels := nil;
  FConsole.OnGetCmdHistory := nil;
  FConsole.OnCommandExecuted := nil;
  FMdi.CloseWindow(FConsole);
  FConsole := nil;
  if WasVisible then
    ShowConsoleMode
  else
  begin
    EnsureConsole;
    FConsole.EnsureShell(FDualPanel.ActiveLocalPath);
  end;
  Recompose;
end;

function TTuiShell.GetConsoleProfile: string;
begin
  if Assigned(FConsole) then
    Result := FConsole.ProfileId
  else
    Result := FSession.BackgroundConsoleProfile;
end;

function TTuiShell.GetConsoleStartOnLaunch: Boolean;
begin
  Result := FSession.ConsoleStartOnLaunch;
end;

procedure TTuiShell.SetConsoleStartOnLaunch(AValue: Boolean);
begin
  FSession.ConsoleStartOnLaunch := AValue;
end;

function TTuiShell.GetConsoleCwdToPanels: Boolean;
begin
  Result := FSession.ConsoleCwdToPanels;
end;

procedure TTuiShell.SetConsoleCwdToPanels(AValue: Boolean);
begin
  FSession.ConsoleCwdToPanels := AValue;
end;

{ ---- console commands ---------------------------------------------------- }

procedure TTuiShell.ConsoleContentChanged(Sender: TObject);
begin
  Recompose;
end;

procedure TTuiShell.ConsoleCloseRequest(Sender: TObject);
var
  ToFree: TConsoleWindow;
begin
  ToFree := FConsole;
  FConsole := nil;
  if Assigned(ToFree) then
  begin
    ToFree.OnCloseRequest := nil;
    ToFree.OnContentChanged := nil;
    ToFree.OnBackToPanels := nil;
    ToFree.OnDismissConsole := nil;
    ToFree.OnFocusCommandLine := nil;
    FMdi.CloseWindow(ToFree);
  end;
  ShowPanelMode;
  Recompose;
end;

procedure TTuiShell.ConsoleBackToPanels(Sender: TObject);
begin
  ShowPanelMode;
  Recompose;
end;

procedure TTuiShell.ConsoleDismiss(Sender: TObject);
begin
  if Assigned(FConsole) then
  begin
    ShowPanelMode;
    Recompose;
  end;
end;

procedure TTuiShell.ConsoleFocusCommandLine(Sender: TObject);
begin
  FDualPanel.FocusCommandLine;
  Recompose;
end;

procedure TTuiShell.ConsoleSyncDirToPanels(Sender: TObject);
var
  Cwd: string;
begin
  if not Assigned(FConsole) then
    Exit;
  Cwd := FConsole.PromptCwd;
  if Cwd = '' then
    Cwd := FConsole.WorkingDir;
  FDualPanel.SetActivePanelDir(Cwd);
  Recompose;
end;

function TTuiShell.ConsoleGetCmdHistory: TArray<string>;
begin
  Result := FDualPanel.GetCommandHistoryItems;
end;

procedure TTuiShell.ConsoleCommandExecuted(const ACommand: string);
begin
  FDualPanel.RecordConsoleCommand(ACommand);
end;

{ ---- screen -------------------------------------------------------------- }

function TTuiShell.Title: string;
var
  Path: string;
  I: Integer;
begin
  Path := FDualPanel.ActiveLocalPath;
  if Path = '' then
    Result := 'MTN2'
  else
    Result := 'MTN2 - ' + Path;
  // A control character in a folder name must not reach the terminal.
  for I := Length(Result) downto 1 do
    if Result[I] < ' ' then
      Delete(Result, I, 1);
end;

procedure TTuiShell.Resize(ACols, ARows: Integer);
begin
  ACols := Max(ACols, 20);
  ARows := Max(ARows, 6);
  if (ACols = FCols) and (ARows = FRows) then
    Exit;
  FCols := ACols;
  FRows := ARows;
  AllocTerminalGrid(FGrid, FCols, FRows);
  FDirty := True;
end;

function TTuiShell.Compose: TTerminalGrid;
begin
  FMdi.LayoutMaximized(FCols, FRows);
  SyncHiddenConsoleArea(FCols, FRows);
  FMdi.Paint(FGrid, FCols, FRows);
  FDualPanel.PaintConsoleWindowButtons(FGrid, FCols);
  PaintOverlayCells(FGrid);
  FDirty := False;
  Result := FGrid;
end;

{ ---- input --------------------------------------------------------------- }

procedure TTuiShell.SyncKeyModifiers(AShift: TShiftState);
var
  Changed: Boolean;
begin
  Changed := False;
  if Assigned(FDualPanel) and FDualPanel.Visible then
    Changed := FDualPanel.SetKeyModifiers(AShift) or Changed;
  if Assigned(FMdi.Active) and (FMdi.Active <> FDualPanel) then
    Changed := FMdi.Active.SetKeyModifiers(AShift) or Changed;
  if Changed then
    Recompose;
end;

function TTuiShell.IsConsoleScrollOrSelectionKey(AKey: Word; AKeyChar: Char;
  AShift: TShiftState): Boolean;
begin
  Result := (AKey = vkPrior) or (AKey = vkNext) or (AKey = vkHome) or (AKey = vkEnd) or
    (AKey = vkUp) or (AKey = vkDown) or (AKey = vkLeft) or (AKey = vkRight) or
    TKeyChord.Make(AKey, AKeyChar, AShift).MatchesLetter('C', [ssCtrl], [ssShift]) or
    TKeyChord.Make(AKey, AKeyChar, AShift).MatchesLetter('A', [ssCtrl], [ssShift]);
end;

function TTuiShell.DispatchTerminalKey(var AKey: Word; var AKeyChar: Char;
  AShift: TShiftState): Boolean;
var
  BareEscape: Boolean;
begin
  Result := False;
  SyncKeyModifiers(AShift);
  // A dialog of the dual panel wins over the active window.
  if FDualPanel.Visible and FDualPanel.DialogVisible and
     FDualPanel.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  // Esc in console mode always restores the panels; the console clears its own
  // selection first.
  BareEscape := TKeyChord.Make(AKey, #0, AShift).Matches(vkEscape);
  if BareEscape and FDualPanel.ConsoleMode and Assigned(FConsole) then
  begin
    FConsole.HandleInput(AKey, AShift, AKeyChar);
    Exit(True);
  end;
  if IsConsoleActiveInConsoleMode and IsConsoleScrollOrSelectionKey(AKey, AKeyChar, AShift) and
     FMdi.Active.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  if FDualPanel.Visible and FDualPanel.CmdFocused and not FDualPanel.ConsoleMode and
     FDualPanel.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  if Assigned(FMdi.Active) and FMdi.Active.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  if FDualPanel.Visible and FDualPanel.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
end;

procedure TTuiShell.HandleKey(const AEvent: TTermEvent);
var
  Key: Word;
  Ch: Char;
  Shift: TShiftState;
begin
  Key := AEvent.Key;
  Ch := AEvent.KeyChar;
  Shift := AEvent.Shift;
  // Typing takes the console over from a command started in the background.
  FPeekTimer.Enabled := False;
  NormalizeKeyInput(Key, Ch, Shift, False);
  if (Key = 0) and (Ch = #9) then
    Key := vkTab;
  if MatchActionIn(ActiveKeymap, [kcGlobal], KeymapLookupKey(Key, Ch), Shift) =
     kaReloadKeymap then
  begin
    ReloadKeymap('');
    Recompose;
    Exit;
  end;
  DispatchTerminalKey(Key, Ch, Shift);
  FHeldShift := Shift;
  FAltTimer.Enabled := False;
  if ssAlt in Shift then
    FAltTimer.Enabled := True;
  FDriveTimer.Enabled := False;
  if FDualPanel.DrivePreviewActive then
    FDriveTimer.Enabled := True;
  Recompose;
end;

procedure TTuiShell.HandlePaste(const AText: string);
var
  I: Integer;
  Key: Word;
  Ch: Char;
begin
  // The pasted text is typed key by key into whatever has the keyboard.
  for I := 1 to Length(AText) do
  begin
    Ch := AText[I];
    if Ch = #10 then
      Continue;
    Key := 0;
    if Ch = #13 then
      Key := vkReturn
    else if Ch = #9 then
      Key := vkTab;
    if Key <> 0 then
      Ch := #0;
    DispatchTerminalKey(Key, Ch, []);
  end;
  Recompose;
end;

procedure TTuiShell.HandleMouseDown(const AEvent: TTermEvent);
var
  Col, Row, LocalCol, LocalRow: Integer;
  Shift: TShiftState;
  Dbl: Boolean;
  Active: TTerminalWindow;
  Path: string;
  MenuClick: Boolean;
  Key: Word;
  KeyChar: Char;
  KeyShift: TShiftState;
  Tick: UInt64;
begin
  FPeekTimer.Enabled := False;
  Col := AEvent.Col;
  Row := AEvent.Row;
  Shift := AEvent.Shift;
  Tick := PlatformTickCount64;
  Dbl := (AEvent.Button = TMouseButton.mbLeft) and (Col = FLastClickCol) and
    (Row = FLastClickRow) and (Tick - FLastClickTick <= PlatformDoubleClickMs);
  if AEvent.Button = TMouseButton.mbLeft then
  begin
    FLastClickCol := Col;
    FLastClickRow := Row;
    FLastClickTick := Tick;
    if Dbl then
    begin
      FLastClickCol := -1;
      Include(Shift, ssDouble);
    end;
    FButtonsDown := FButtonsDown or 1;
  end;
  if AEvent.Button = TMouseButton.mbLeft then
    Include(Shift, ssLeft)
  else if AEvent.Button = TMouseButton.mbRight then
    Include(Shift, ssRight)
  else
    Include(Shift, ssMiddle);

  // The window buttons on the console frame sit above the console.
  if (AEvent.Button = TMouseButton.mbLeft) and
     FDualPanel.HandleConsoleFrameClick(Col - FDualPanel.Area.Left,
       Row - FDualPanel.Area.Top) then
    Exit;

  // The function bar below a console is the dual panel's.
  if (AEvent.Button = TMouseButton.mbLeft) and FDualPanel.Visible and
     FDualPanel.ConsoleMode and Assigned(FConsole) and FConsole.Visible and
     FDualPanel.HitTest(Col, Row) and
     FDualPanel.FunctionBarClickKey(Col - FDualPanel.Area.Left, Row - FDualPanel.Area.Top,
       Shift, Key, KeyChar, KeyShift) then
  begin
    DispatchTerminalKey(Key, KeyChar, KeyShift);
    Exit;
  end;

  FMdi.ActivateAt(Col, Row);
  Active := FMdi.Active;
  if (AEvent.Button = TMouseButton.mbLeft) and Assigned(Active) and Active.HitTest(Col, Row) then
  begin
    LocalCol := Col - Active.Area.Left;
    LocalRow := Row - Active.Area.Top;
    if (Active is TDualPanelWindow) and
       TDualPanelWindow(Active).HandleMouseDown(LocalCol, LocalRow, Shift) then
      Exit;
    if (Active is TEditorWindow) and
       TEditorWindow(Active).HandleMouseDown(LocalCol, LocalRow, Shift) then
      Exit;
    if (Active is TConsoleWindow) and
       TConsoleWindow(Active).HandleMouseDown(LocalCol, LocalRow, Shift) then
      Exit;
  end;
  if Assigned(FConsole) and FConsole.Visible and FConsole.HitTest(Col, Row) and
     (FMdi.Active <> FConsole) and
     FConsole.HandleMouseDown(Col - FConsole.Area.Left, Row - FConsole.Area.Top, Shift) then
    Exit;

  if FDualPanel.Visible and FDualPanel.HitTest(Col, Row) then
  begin
    LocalCol := Col - FDualPanel.Area.Left;
    LocalRow := Row - FDualPanel.Area.Top;
    if AEvent.Button = TMouseButton.mbRight then
    begin
      FDualPanel.HandleClick(LocalCol, LocalRow, False, Shift, False);
      Exit;
    end;
    MenuClick := FDualPanel.TopMenuOpen or (LocalRow = 0) or FDualPanel.HasOpenDialog;
    if MenuClick or not FDualPanel.HitTestListItemLocalPath(LocalCol, LocalRow, Path) then
      ;
    FDualPanel.HandleClick(LocalCol, LocalRow, Dbl, Shift);
  end;
end;

procedure TTuiShell.HandleMouseMove(const AEvent: TTermEvent);
var
  Col, Row, LocalCol, LocalRow: Integer;
  Active: TTerminalWindow;
begin
  Col := AEvent.Col;
  Row := AEvent.Row;
  if FDualPanel.Visible and FDualPanel.TopMenuOpen then
  begin
    LocalCol := Col - FDualPanel.Area.Left;
    LocalRow := Row - FDualPanel.Area.Top;
    FDualPanel.HandleMouseMove(LocalCol, LocalRow);
    Exit;
  end;
  Active := FMdi.Active;
  if Active = nil then
    Exit;
  LocalCol := Col - Active.Area.Left;
  LocalRow := Row - Active.Area.Top;
  if Active is TDualPanelWindow then
    TDualPanelWindow(Active).HandleMouseMove(LocalCol, LocalRow)
  else if Active is TEditorWindow then
    TEditorWindow(Active).HandleMouseMove(LocalCol, LocalRow)
  else if Active is TConsoleWindow then
    TConsoleWindow(Active).HandleMouseMove(LocalCol, LocalRow);
end;

procedure TTuiShell.HandleMouseUp(const AEvent: TTermEvent);
var
  Col, Row: Integer;
  Btn: TWindowButton;
  Acts: Boolean;
begin
  if AEvent.Button <> TMouseButton.mbLeft then
    Exit;
  FButtonsDown := FButtonsDown and not 1;
  Col := AEvent.Col - FDualPanel.Area.Left;
  Row := AEvent.Row - FDualPanel.Area.Top;
  if FDualPanel.HandleMenuMouseUp(Col, Row) then
    Exit;
  if FDualPanel.ReleaseChromeButton(Col, Row, Btn, Acts) then
    Exit;
  if FDualPanel.Visible then
    FDualPanel.HandleMouseUp
  else if FMdi.Active is TEditorWindow then
    TEditorWindow(FMdi.Active).HandleMouseUp
  else if FMdi.Active is TConsoleWindow then
    TConsoleWindow(FMdi.Active).HandleMouseUp;
end;

procedure TTuiShell.HandleWheel(const AEvent: TTermEvent);
var
  Delta: Integer;
  K: Word;
  C: Char;
begin
  if AEvent.MouseAction = tmaWheelUp then
    Delta := 120
  else if AEvent.MouseAction = tmaWheelDown then
    Delta := -120
  else
    Exit;
  if FDualPanel.Visible and FDualPanel.HitTest(AEvent.Col, AEvent.Row) and
     FDualPanel.HandleMouseWheelAt(AEvent.Col - FDualPanel.Area.Left,
       AEvent.Row - FDualPanel.Area.Top, Delta) then
    Exit;
  if Assigned(FMdi.Active) then
  begin
    if (FMdi.Active is TBaseConsoleWindow) and
       TBaseConsoleWindow(FMdi.Active).HandleMouseWheel(Delta) then
      Exit;
    if Delta > 0 then
      K := vkUp
    else
      K := vkDown;
    C := #0;
    FMdi.Active.HandleInput(K, [], C);
  end;
end;

procedure TTuiShell.HandleMouse(const AEvent: TTermEvent);
begin
  case AEvent.MouseAction of
    tmaPress: HandleMouseDown(AEvent);
    tmaRelease: HandleMouseUp(AEvent);
    tmaMove:
      if AEvent.Button = TMouseButton.mbLeft then
        HandleMouseMove(AEvent);
    tmaWheelUp, tmaWheelDown, tmaWheelLeft, tmaWheelRight: HandleWheel(AEvent);
  end;
end;

procedure TTuiShell.HandleEvent(const AEvent: TTermEvent);
begin
  case AEvent.Kind of
    tekKey: HandleKey(AEvent);
    tekMouse:
      begin
        HandleMouse(AEvent);
        Recompose;
      end;
    tekPaste: HandlePaste(AEvent.Text);
  end;
end;

end.
