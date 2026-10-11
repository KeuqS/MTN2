unit uShellAssoc;

{ Platform shell file associations (open handler probe + open), Posix build:
  the freedesktop tools xdg-open and xdg-mime. Host/UI code uses only this
  unit. The Windows build lives in Platform\Windows; each project puts
  exactly one of the two directories on its unit search path. }

interface

type
  /// <summary>Result of asking the OS for an "open" handler for an extension.</summary>
  TShellOpenQuery = record
    Available: Boolean;
    AppName: string;
    Command: string;
    class function None: TShellOpenQuery; static;
  end;

/// <summary>Normalize to lowercase ".ext" (accepts "pdf", ".PDF", or a file name).</summary>
function NormalizeFileExtension(const AExtOrName: string): string;

/// <summary>Ask the OS whether an open action is registered for the extension.</summary>
function QueryShellOpen(const AExtension: string): TShellOpenQuery;

function HasShellOpen(const AExtension: string): Boolean;

/// <summary>Open a local file via the platform shell. Returns False on failure.</summary>
function ShellOpenFile(const AFilePath: string): Boolean;

/// <summary>Open a local file for editing: $VISUAL or $EDITOR in the desktop's
/// default handler, otherwise the plain open. Returns False on failure.</summary>
function ShellEditFile(const AFilePath: string): Boolean;

/// <summary>Open a URL (https://..., mailto:...) with the OS default handler,
/// e.g. the default browser. Returns False on failure.</summary>
function ShellOpenUrl(const AUrl: string): Boolean;

/// <summary>The OS file context menu is not available: always False.</summary>
function ShellShowContextMenu(const AFilePath: string; AScreenX, AScreenY: Integer;
  AOwnerHwnd: NativeUInt): Boolean;
function ShellShowContextMenuFor(const APaths: TArray<string>; AScreenX, AScreenY: Integer;
  AOwnerHwnd: NativeUInt): Boolean;

/// <summary>The OS "Properties" window is not available: always False.</summary>
function ShellShowProperties(const APaths: TArray<string>; AOwnerHwnd: NativeUInt): Boolean;

/// <summary>Run a command or file as a separate OS process that outlives this one.</summary>
function ShellRunDetached(const ACommand, AWorkingDir: string): Boolean;

implementation

uses
  System.SysUtils, System.IOUtils, Posix.Base;

function system(ACommand: MarshaledAString): Integer; cdecl;
  external libc name 'system';

class function TShellOpenQuery.None: TShellOpenQuery;
begin
  Result.Available := False;
  Result.AppName := '';
  Result.Command := '';
end;

function NormalizeFileExtension(const AExtOrName: string): string;
var
  S: string;
begin
  S := Trim(AExtOrName);
  if S = '' then
    Exit('');
  // File name -> extension; bare "pdf" -> ".pdf".
  if (Pos(PathDelim, S) > 0) or (Pos('/', S) > 0) or (Pos('.', S) > 1) then
    S := TPath.GetExtension(S)
  else if (Length(S) > 0) and (S[1] <> '.') then
    S := '.' + S;
  Result := LowerCase(S);
end;

function ShellQuote(const AText: string): string;
begin
  Result := '''' + StringReplace(AText, '''', '''\''''', [rfReplaceAll]) + '''';
end;

// A graphical desktop is available to take the file.
function HasDisplay: Boolean;
begin
  Result := GetEnvironmentVariable('DISPLAY') + GetEnvironmentVariable('WAYLAND_DISPLAY') <> '';
end;

function ToolInPath(const ATool: string): Boolean;
begin
  Result := FileSearch(ATool, GetEnvironmentVariable('PATH')) <> '';
end;

function RunShell(const ACommandLine: string): Boolean;
var
  Cmd: UTF8String;
begin
  Cmd := UTF8String(ACommandLine);
  Result := system(MarshaledAString(Cmd)) = 0;
end;

function QueryShellOpen(const AExtension: string): TShellOpenQuery;
var
  Ext: string;
begin
  Result := TShellOpenQuery.None;
  Ext := NormalizeFileExtension(AExtension);
  if Ext = '' then
    Exit;
  // xdg-open picks the handler itself; the probe only says it can be asked.
  Result.Available := HasDisplay and ToolInPath('xdg-open');
  if Result.Available then
    Result.Command := 'xdg-open';
end;

function HasShellOpen(const AExtension: string): Boolean;
begin
  Result := QueryShellOpen(AExtension).Available;
end;

function ShellOpenFile(const AFilePath: string): Boolean;
begin
  Result := False;
  if (AFilePath = '') or not HasDisplay or not ToolInPath('xdg-open') then
    Exit;
  Result := RunShell('xdg-open ' + ShellQuote(AFilePath) + ' >/dev/null 2>&1 &');
end;

function ShellEditFile(const AFilePath: string): Boolean;
var
  Editor: string;
begin
  Result := False;
  if AFilePath = '' then
    Exit;
  Editor := GetEnvironmentVariable('VISUAL');
  if Editor = '' then
    Editor := GetEnvironmentVariable('EDITOR');
  if (Editor <> '') and ToolInPath(Editor) and
     HasDisplay then
    Exit(RunShell(Editor + ' ' + ShellQuote(AFilePath) + ' >/dev/null 2>&1 &'));
  Result := ShellOpenFile(AFilePath);
end;

function ShellOpenUrl(const AUrl: string): Boolean;
begin
  Result := False;
  if (AUrl = '') or not ToolInPath('xdg-open') then
    Exit;
  Result := RunShell('xdg-open ' + ShellQuote(AUrl) + ' >/dev/null 2>&1 &');
end;

function ShellShowContextMenu(const AFilePath: string; AScreenX, AScreenY: Integer;
  AOwnerHwnd: NativeUInt): Boolean;
begin
  Result := False;
end;

function ShellShowContextMenuFor(const APaths: TArray<string>; AScreenX, AScreenY: Integer;
  AOwnerHwnd: NativeUInt): Boolean;
begin
  Result := False;
end;

function ShellShowProperties(const APaths: TArray<string>; AOwnerHwnd: NativeUInt): Boolean;
begin
  Result := False;
end;

function ShellRunDetached(const ACommand, AWorkingDir: string): Boolean;
var
  Line: string;
begin
  Result := False;
  if ACommand = '' then
    Exit;
  Line := ACommand + ' >/dev/null 2>&1 &';
  if AWorkingDir <> '' then
    Line := 'cd ' + ShellQuote(AWorkingDir) + ' && ' + Line;
  Result := RunShell(Line);
end;

end.
