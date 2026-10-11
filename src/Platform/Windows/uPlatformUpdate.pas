unit uPlatformUpdate;

{ OS services the self-updater needs (Windows build). The Posix build lives
  in Platform\Posix; each project puts exactly one of the two directories on
  its unit search path. }

interface

/// <summary>Major.Minor.Release[.Build] of the program file; '' when it has no
/// version information. The build number is left out when it is 0.</summary>
function PlatformFileVersion(const AExeFile: string): string;

/// <summary>Renames or moves a file, also across volumes. With AReplace an
/// existing destination is overwritten; without it the move fails instead.</summary>
function PlatformMoveFile(const ASource, ADest: string; AReplace: Boolean;
  out AError: string): Boolean;

/// <summary>True when a file can be created in ADir.</summary>
function PlatformCanWriteToDir(const ADir: string): Boolean;

function PlatformCurrentProcessId: Cardinal;

/// <summary>Starts AExeFile with AArguments as a separate process in its own
/// folder; it outlives the caller.</summary>
function PlatformStartProcess(const AExeFile, AArguments: string;
  out AError: string): Boolean;

/// <summary>Waits until the process has exited or ATimeoutMs passed.</summary>
procedure PlatformWaitForProcess(APid: Cardinal; ATimeoutMs: Cardinal);

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows;

function PlatformFileVersion(const AExeFile: string): string;
var
  Handle, Size, Len: DWORD;
  Buf: TBytes;
  Info: PVSFixedFileInfo;
begin
  Result := '';
  Size := GetFileVersionInfoSize(PChar(AExeFile), Handle);
  if Size = 0 then
    Exit;
  SetLength(Buf, Size);
  if not GetFileVersionInfo(PChar(AExeFile), 0, Size, @Buf[0]) then
    Exit;
  if not VerQueryValue(@Buf[0], '\', Pointer(Info), Len) or (Len < SizeOf(TVSFixedFileInfo)) then
    Exit;
  Result := Format('%d.%d.%d', [HiWord(Info.dwFileVersionMS), LoWord(Info.dwFileVersionMS),
    HiWord(Info.dwFileVersionLS)]);
  if LoWord(Info.dwFileVersionLS) <> 0 then
    Result := Result + '.' + IntToStr(LoWord(Info.dwFileVersionLS));
end;

function PlatformMoveFile(const ASource, ADest: string; AReplace: Boolean;
  out AError: string): Boolean;
var
  Flags: DWORD;
begin
  AError := '';
  if AReplace then
    Flags := MOVEFILE_REPLACE_EXISTING or MOVEFILE_COPY_ALLOWED
  else
    Flags := 0;
  Result := MoveFileEx(PChar(ASource), PChar(ADest), Flags);
  if not Result then
    AError := SysErrorMessage(GetLastError);
end;

function PlatformCanWriteToDir(const ADir: string): Boolean;
var
  Probe: string;
  H: THandle;
begin
  Probe := TPath.Combine(ADir, '.mtn2-write-probe-' + IntToStr(GetCurrentProcessId));
  H := CreateFile(PChar(Probe), GENERIC_WRITE, 0, nil, CREATE_ALWAYS,
    FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
  Result := H <> INVALID_HANDLE_VALUE;
  if Result then
    CloseHandle(H);
end;

function PlatformCurrentProcessId: Cardinal;
begin
  Result := GetCurrentProcessId;
end;

function PlatformStartProcess(const AExeFile, AArguments: string;
  out AError: string): Boolean;
var
  Cmd: string;
  Si: TStartupInfo;
  Pi: TProcessInformation;
begin
  AError := '';
  Cmd := Format('"%s" %s', [AExeFile, AArguments]);
  UniqueString(Cmd);
  ZeroMemory(@Si, SizeOf(Si));
  Si.cb := SizeOf(Si);
  Result := CreateProcess(nil, PChar(Cmd), nil, nil, False, 0, nil,
    PChar(ExtractFileDir(AExeFile)), Si, Pi);
  if Result then
  begin
    CloseHandle(Pi.hThread);
    CloseHandle(Pi.hProcess);
  end
  else
    AError := SysErrorMessage(GetLastError);
end;

procedure PlatformWaitForProcess(APid: Cardinal; ATimeoutMs: Cardinal);
var
  H: THandle;
begin
  H := OpenProcess(SYNCHRONIZE, False, APid);
  if H <> 0 then
  begin
    WaitForSingleObject(H, ATimeoutMs);
    CloseHandle(H);
  end;
end;

end.
