unit uPlatformDrives;

{ Volumes of the machine (Windows build: drive letters). The Posix build lives
  in Platform\Posix; each project puts exactly one of the two directories on
  its unit search path. }

interface

uses
  uDriveTypes;

/// <summary>Letter, root and kind of every volume. Never touches the volume
/// itself, so an unresponsive network share cannot block it.</summary>
function PlatformListDrives: TDriveInfoArray;

/// <summary>Letter, root and kind of the volume with this letter; False when
/// there is none. Same blocking guarantee as PlatformListDrives.</summary>
function PlatformDriveByLetter(ALetter: Char; out AInfo: TDriveInfo): Boolean;

/// <summary>Letter of the volume that holds APath; #0 for a path outside any
/// volume (UNC, relative, empty).</summary>
function PlatformDriveLetterOfPath(const APath: string): Char;

/// <summary>Fills file system, label, serial number and sizes. Queries the
/// volume, so it can block for a long time on an unresponsive network share.</summary>
procedure PlatformFillDriveDetails(var AInfo: TDriveInfo);

/// <summary>Ends the calling thread at once, without any RTL cleanup. For a
/// worker that wakes up after the heap has been finalized.</summary>
procedure PlatformAbandonThread;

implementation

uses
  System.SysUtils, Winapi.Windows;

function DriveKindLabel(ADriveType: Cardinal): string;
begin
  case ADriveType of
    DRIVE_REMOVABLE: Result := 'Removable';
    DRIVE_FIXED:     Result := 'Hard disk';
    DRIVE_REMOTE:    Result := 'Network';
    DRIVE_CDROM:     Result := 'CD-ROM';
    DRIVE_RAMDISK:   Result := 'RAM';
  else
    Result := '';
  end;
end;

function RemoteConnectionName(const ARoot: string): string;
var
  Buf: array[0..512] of Char;
  Len: DWORD;
begin
  Result := '';
  Len := Length(Buf);
  FillChar(Buf, SizeOf(Buf), 0);
  if WNetGetConnection(PChar(Copy(ARoot, 1, 2)), Buf, Len) = NO_ERROR then
    Result := string(Buf);
end;

procedure ClearInfo(out AInfo: TDriveInfo);
begin
  AInfo.Letter := #0;
  AInfo.RootPath := '';
  AInfo.KindLabel := '';
  AInfo.FsName := '';
  AInfo.LabelOrPath := '';
  AInfo.TotalBytes := 0;
  AInfo.FreeBytes := 0;
  AInfo.SerialNumber := 0;
  AInfo.VolumeFlags := 0;
end;

function PlatformDriveByLetter(ALetter: Char; out AInfo: TDriveInfo): Boolean;
var
  Dt: Cardinal;
begin
  ClearInfo(AInfo);
  AInfo.Letter := UpCase(ALetter);
  AInfo.RootPath := AInfo.Letter + ':' + PathDelim;
  Dt := GetDriveType(PChar(AInfo.RootPath));
  Result := Dt <> DRIVE_NO_ROOT_DIR;
  if Result then
    AInfo.KindLabel := DriveKindLabel(Dt);
end;

function PlatformListDrives: TDriveInfoArray;
var
  Buf: array[0..512] of Char;
  P: PChar;
  Root: string;
  Info: TDriveInfo;
  N: Integer;
begin
  SetLength(Result, 0);
  FillChar(Buf, SizeOf(Buf), 0);
  if GetLogicalDriveStrings(Length(Buf) - 1, Buf) = 0 then
    Exit;
  P := Buf;
  while P^ <> #0 do
  begin
    Root := string(P);
    if (Length(Root) >= 2) and (Root[2] = ':') and
       PlatformDriveByLetter(Root[1], Info) then
    begin
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N] := Info;
    end;
    Inc(P, StrLen(P) + 1);
  end;
end;

function PlatformDriveLetterOfPath(const APath: string): Char;
begin
  if (Length(APath) >= 2) and (APath[2] = ':') then
    Result := UpCase(APath[1])
  else
    Result := #0;
end;

procedure PlatformFillDriveDetails(var AInfo: TDriveInfo);
var
  VolName, FsName: array[0..255] of Char;
  Serial, MaxComp, Flags: DWORD;
  FreeAvail, TotalBytes, TotalFree: Int64;
begin
  FillChar(VolName, SizeOf(VolName), 0);
  FillChar(FsName, SizeOf(FsName), 0);
  Serial := 0;
  MaxComp := 0;
  Flags := 0;
  AInfo.SerialNumber := 0;
  try
    if GetVolumeInformation(PChar(AInfo.RootPath), VolName, Length(VolName),
      @Serial, MaxComp, Flags, FsName, Length(FsName)) then
    begin
      AInfo.FsName := string(FsName);
      AInfo.LabelOrPath := string(VolName);
      AInfo.SerialNumber := Serial;
      AInfo.VolumeFlags := Flags;
    end
    else
    begin
      AInfo.FsName := '';
      AInfo.LabelOrPath := '';
      AInfo.VolumeFlags := 0;
    end;
  except
    AInfo.FsName := '';
    AInfo.LabelOrPath := '';
  end;

  if AInfo.KindLabel = 'Network' then
  begin
    AInfo.LabelOrPath := RemoteConnectionName(AInfo.RootPath);
    if AInfo.LabelOrPath = '' then
      AInfo.LabelOrPath := AInfo.RootPath;
  end;

  AInfo.TotalBytes := 0;
  AInfo.FreeBytes := 0;
  try
    FreeAvail := 0;
    TotalBytes := 0;
    TotalFree := 0;
    if GetDiskFreeSpaceEx(PChar(AInfo.RootPath), FreeAvail, TotalBytes, @TotalFree) then
    begin
      AInfo.TotalBytes := TotalBytes;
      AInfo.FreeBytes := FreeAvail;
    end;
  except
    AInfo.TotalBytes := 0;
    AInfo.FreeBytes := 0;
  end;
end;

procedure PlatformAbandonThread;
begin
  ExitThread(0);
end;

end.
