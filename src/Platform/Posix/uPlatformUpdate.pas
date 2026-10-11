unit uPlatformUpdate;

{ OS services the self-updater needs (Posix build). The Windows build lives
  in Platform\Windows; each project puts exactly one of the two directories on
  its unit search path. }

interface

/// <summary>Version of the program: the first line of the file "version" next
/// to it ("1.2.3" or "1.2.3.45"); '' when there is none.</summary>
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
  System.SysUtils, System.Classes, System.IOUtils, Posix.Base, Posix.Unistd,
  Posix.Signal, Posix.Errno;

function system(ACommand: MarshaledAString): Integer; cdecl;
  external libc name 'system';

function ShellQuote(const AText: string): string;
begin
  Result := '''' + StringReplace(AText, '''', '''\''''', [rfReplaceAll]) + '''';
end;

function PlatformFileVersion(const AExeFile: string): string;
var
  FileName: string;
  Lines: TStringList;
begin
  Result := '';
  FileName := TPath.Combine(ExtractFileDir(AExeFile), 'version');
  if not TFile.Exists(FileName) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    if Lines.Count > 0 then
      Result := Trim(Lines[0]);
  finally
    Lines.Free;
  end;
end;

function PlatformMoveFile(const ASource, ADest: string; AReplace: Boolean;
  out AError: string): Boolean;
begin
  AError := '';
  if (not AReplace) and TFile.Exists(ADest) then
  begin
    AError := SysErrorMessage(EEXIST);
    Exit(False);
  end;
  try
    TFile.Move(ASource, ADest);
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function PlatformCanWriteToDir(const ADir: string): Boolean;
var
  Probe: string;
begin
  Probe := TPath.Combine(ADir, '.mtn2-write-probe-' + IntToStr(getpid));
  try
    TFile.WriteAllText(Probe, '');
    TFile.Delete(Probe);
    Result := True;
  except
    Result := False;
  end;
end;

function PlatformCurrentProcessId: Cardinal;
begin
  Result := getpid;
end;

function PlatformStartProcess(const AExeFile, AArguments: string;
  out AError: string): Boolean;
var
  Cmd: UTF8String;
begin
  AError := '';
  Cmd := UTF8String(Format('cd %s && %s %s >/dev/null 2>&1 &',
    [ShellQuote(ExtractFileDir(AExeFile)), ShellQuote(AExeFile), AArguments]));
  Result := system(MarshaledAString(Cmd)) = 0;
  if not Result then
    AError := SysErrorMessage(GetLastError);
end;

procedure PlatformWaitForProcess(APid: Cardinal; ATimeoutMs: Cardinal);
var
  Waited: Cardinal;
begin
  Waited := 0;
  // Signal 0 only checks that the process exists.
  while (kill(APid, 0) = 0) and (Waited < ATimeoutMs) do
  begin
    Sleep(50);
    Inc(Waited, 50);
  end;
end;

end.
