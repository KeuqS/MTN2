unit uShellIcons;

{ Shell icons for the panel icon column (POSIX build). A text terminal draws
  no bitmaps, so no icon is ever available and the file-kind glyph stays. The
  Windows build lives in Platform\Windows; each project puts exactly one of the
  two directories on its unit search path. }

interface

uses
  uDualPanelTypes;

const
  /// <summary>How many grid cells a shell icon occupies horizontally.</summary>
  cShellIconCells = 2;

type
  /// <summary>Fired on the main thread after icons land in the cache.</summary>
  TShellIconsReadyProc = reference to procedure;

/// <summary>0: there is no icon.</summary>
function ShellIconIdForRow(const ARow: TPanelRow): Integer;
function ShellIconIdForRowWait(const ARow: TPanelRow): Integer;
procedure ShellIconsSetOnReady(const AProc: TShellIconsReadyProc);

implementation

function ShellIconIdForRow(const ARow: TPanelRow): Integer;
begin
  Result := 0;
end;

function ShellIconIdForRowWait(const ARow: TPanelRow): Integer;
begin
  Result := 0;
end;

procedure ShellIconsSetOnReady(const AProc: TShellIconsReadyProc);
begin
end;

end.
