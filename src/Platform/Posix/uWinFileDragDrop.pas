unit uWinFileDragDrop;

{ Clipboard exchange of panel items and drag-out of files (POSIX build). The
  items travel as the MTN2 text form through the clipboard service (the
  terminal host offers it to the terminal emulator and keeps a copy of its
  own); dragging files out to other programs does not exist here. The Windows
  build lives in Platform\Windows; each project puts exactly one of the two
  directories on its unit search path. }

interface

const
  DROPEFFECT_NONE = 0;
  DROPEFFECT_COPY = 1;
  DROPEFFECT_MOVE = 2;

/// <summary>True while a drag-out is running; never here.</summary>
function OleFileDragActive: Boolean;

/// <summary>Drag of local files to another program; reports no effect.</summary>
function OleDragLocalFiles(const APaths: TArray<string>;
  AAllowedEffects: LongInt = DROPEFFECT_COPY or DROPEFFECT_MOVE): LongInt;

/// <summary>True when a drop effect returned by OleDragLocalFiles is a move.</summary>
function FileDragEffectIsMove(AEffect: LongInt): Boolean;

/// <summary>Puts the panel items on the clipboard.</summary>
function ClipboardSetPanelItems(const ALocalPaths, AUris: TArray<string>;
  ACut: Boolean): Boolean;
/// <summary>Reads panel items placed by ClipboardSetPanelItems.</summary>
function ClipboardGetPanelItems(out ALocalPaths, AUris: TArray<string>;
  out ACut: Boolean): Boolean;
function ClipboardHasPanelItems: Boolean;
procedure ClipboardClearPanelItems;

implementation

uses
  System.SysUtils, uClipboardService, uFileClip;

function OleFileDragActive: Boolean;
begin
  Result := False;
end;

function FileDragEffectIsMove(AEffect: LongInt): Boolean;
begin
  Result := (AEffect and DROPEFFECT_MOVE) <> 0;
end;

function OleDragLocalFiles(const APaths: TArray<string>;
  AAllowedEffects: LongInt): LongInt;
begin
  Result := DROPEFFECT_NONE;
end;

function ClipboardSetPanelItems(const ALocalPaths, AUris: TArray<string>;
  ACut: Boolean): Boolean;
begin
  Result := (Length(AUris) > 0) and
    TrySetClipboardText(EncodeMtnFileClip(AUris, ACut));
end;

function ClipboardGetPanelItems(out ALocalPaths, AUris: TArray<string>;
  out ACut: Boolean): Boolean;
var
  Text: string;
begin
  SetLength(ALocalPaths, 0);
  SetLength(AUris, 0);
  ACut := False;
  Result := TryGetClipboardText(Text) and DecodeMtnFileClip(Text, AUris, ACut);
  if Result then
    ALocalPaths := FileUrisToLocalPaths(AUris);
end;

function ClipboardHasPanelItems: Boolean;
var
  Paths, Uris: TArray<string>;
  Cut: Boolean;
begin
  Result := ClipboardGetPanelItems(Paths, Uris, Cut);
end;

procedure ClipboardClearPanelItems;
begin
  TrySetClipboardText('');
end;

end.
