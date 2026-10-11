unit uKeyRouting;

{ How a host hands a key to its windows: the dual panel with its dialogs and
  command line, the background console and whichever window is active. The
  routing works on already normalized keys (Enter variants mapped to vkReturn,
  Tab recovered from its character) and leaves the host free to redraw. }

interface

uses
  System.Classes, System.UITypes, uMdiCompositor, uDualPanelWindow, uConsoleWindow;

/// <summary>True for a lone Esc.</summary>
function IsBareEscape(AKey: Word; AShift: TShiftState): Boolean;

/// <summary>True for a key that is only a modifier (Shift, Ctrl, Alt).</summary>
function IsModifierOnlyKey(AKey: Word): Boolean;

/// <summary>True for the keys the console takes while the panels are hidden:
/// navigation (arrows, Home, End, PgUp, PgDn) and Ctrl+C / Ctrl+A.</summary>
function IsConsoleScrollOrSelectionKey(AKey: Word; AKeyChar: Char;
  AShift: TShiftState): Boolean;

/// <summary>True when the console is shown instead of the panels and has the
/// keyboard.</summary>
function IsConsoleActiveInConsoleMode(ADualPanel: TDualPanelWindow;
  AMdi: TMdiCompositor; AConsole: TConsoleWindow): Boolean;

/// <summary>Tells the windows that draw a key bar or status which modifier
/// keys are held. True when any of them changed and the screen needs a new
/// composition.</summary>
function SyncKeyModifiers(ADualPanel: TDualPanelWindow; AMdi: TMdiCompositor;
  AShift: TShiftState): Boolean;

/// <summary>Offers a key to the windows in priority order: a dialog of the
/// dual panel, Esc in console mode, console scrolling, the panel command
/// line, the active window, the dual panel. True when one of them took it.</summary>
function RouteTerminalKey(ADualPanel: TDualPanelWindow; AMdi: TMdiCompositor;
  AConsole: TConsoleWindow; var AKey: Word; var AKeyChar: Char;
  AShift: TShiftState): Boolean;

implementation

uses
  uKeyChord;

function IsBareEscape(AKey: Word; AShift: TShiftState): Boolean;
begin
  Result := TKeyChord.Make(AKey, #0, AShift).Matches(vkEscape);
end;

function IsModifierOnlyKey(AKey: Word): Boolean;
begin
  Result := (AKey = vkMenu) or (AKey = vkControl) or (AKey = vkShift) or
    (AKey = vkLShift) or (AKey = vkRShift) or (AKey = vkLControl) or (AKey = vkRControl) or
    (AKey = vkLMenu) or (AKey = vkRMenu);
end;

function IsConsoleScrollOrSelectionKey(AKey: Word; AKeyChar: Char;
  AShift: TShiftState): Boolean;
begin
  Result := (AKey = vkPrior) or (AKey = vkNext) or (AKey = vkHome) or (AKey = vkEnd) or
    (AKey = vkUp) or (AKey = vkDown) or (AKey = vkLeft) or (AKey = vkRight) or
    TKeyChord.Make(AKey, AKeyChar, AShift).MatchesLetter('C', [ssCtrl], [ssShift]) or
    TKeyChord.Make(AKey, AKeyChar, AShift).MatchesLetter('A', [ssCtrl], [ssShift]);
end;

function IsConsoleActiveInConsoleMode(ADualPanel: TDualPanelWindow;
  AMdi: TMdiCompositor; AConsole: TConsoleWindow): Boolean;
begin
  Result := Assigned(ADualPanel) and ADualPanel.ConsoleMode and Assigned(AMdi) and
    Assigned(AMdi.Active) and (AMdi.Active = AConsole);
end;

function SyncKeyModifiers(ADualPanel: TDualPanelWindow; AMdi: TMdiCompositor;
  AShift: TShiftState): Boolean;
begin
  Result := False;
  // The dual panel owns the shared chrome in console mode and when it is active.
  if Assigned(ADualPanel) and ADualPanel.Visible then
    Result := ADualPanel.SetKeyModifiers(AShift) or Result;
  // A focused viewer or editor draws its own key bar and status.
  if Assigned(AMdi) and Assigned(AMdi.Active) and (AMdi.Active <> ADualPanel) then
    Result := AMdi.Active.SetKeyModifiers(AShift) or Result;
end;

function RouteTerminalKey(ADualPanel: TDualPanelWindow; AMdi: TMdiCompositor;
  AConsole: TConsoleWindow; var AKey: Word; var AKeyChar: Char;
  AShift: TShiftState): Boolean;
begin
  // A dialog of the dual panel wins over the active window, so Enter reaches
  // its default button.
  if Assigned(ADualPanel) and ADualPanel.Visible and ADualPanel.DialogVisible and
     ADualPanel.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  // Esc in console mode always restores the panels (Ctrl+C stops a running
  // command). The console sees it first so a scrollback selection is cleared.
  // It is routed here because the dual panel ignores input in console mode.
  if IsBareEscape(AKey, AShift) and Assigned(ADualPanel) and ADualPanel.ConsoleMode and
     Assigned(AConsole) then
  begin
    AConsole.HandleInput(AKey, AShift, AKeyChar);
    Exit(True);
  end;
  // Scrolling and selection in console mode: the command line is hidden and the
  // input belongs to the console.
  if IsConsoleActiveInConsoleMode(ADualPanel, AMdi, AConsole) and
     IsConsoleScrollOrSelectionKey(AKey, AKeyChar, AShift) and
     AMdi.Active.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  // The panel command line owns typing while it has focus (panel mode only).
  if Assigned(ADualPanel) and ADualPanel.Visible and ADualPanel.CmdFocused and
     not ADualPanel.ConsoleMode and ADualPanel.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  if Assigned(AMdi) and Assigned(AMdi.Active) and
     AMdi.Active.HandleInput(AKey, AShift, AKeyChar) then
    Exit(True);
  Result := Assigned(ADualPanel) and ADualPanel.Visible and
    ADualPanel.HandleInput(AKey, AShift, AKeyChar);
end;

end.
