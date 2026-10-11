unit uPlatformHostInfo;

{ Facts about the machine and the user session, shown by the panel info view
  (Windows build). The POSIX build lives in Platform\Posix; each project puts
  exactly one of the two directories on its unit search path. }

interface

type
  TPlatformHostInfo = record
    ComputerName: string;
    UserName: string;
    /// <summary>Logon domain; '' when there is none.</summary>
    Domain: string;
    /// <summary>The user's profile (home) directory.</summary>
    ProfileDir: string;
    IsElevated: Boolean;
    ProcessId: Cardinal;
    /// <summary>Milliseconds since the system started.</summary>
    UptimeMs: UInt64;
    HasMemory: Boolean;
    MemoryLoadPercent: Integer;
    TotalPhysical: Int64;
    AvailPhysical: Int64;
    TotalPageFile: Int64;
    AvailPageFile: Int64;
    TotalVirtual: Int64;
    AvailVirtual: Int64;
  end;

function PlatformHostInfo: TPlatformHostInfo;

implementation

uses
  System.SysUtils, Winapi.Windows;

function PlatformHostInfo: TPlatformHostInfo;
var
  CompBuf, UserBuf: array[0..255] of Char;
  CompLen, UserLen, ElevSz: DWORD;
  Token: THandle;
  Elev: TOKEN_ELEVATION;
  Mem: TMemoryStatusEx;
begin
  Result := Default(TPlatformHostInfo);
  CompLen := Length(CompBuf);
  UserLen := Length(UserBuf);
  FillChar(CompBuf, SizeOf(CompBuf), 0);
  FillChar(UserBuf, SizeOf(UserBuf), 0);
  if GetComputerName(CompBuf, CompLen) then
    Result.ComputerName := string(CompBuf);
  if GetUserName(UserBuf, UserLen) then
    Result.UserName := string(UserBuf);
  Result.Domain := GetEnvironmentVariable('USERDOMAIN');
  Result.ProfileDir := GetEnvironmentVariable('USERPROFILE');
  if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, Token) then
  try
    ElevSz := SizeOf(Elev);
    if GetTokenInformation(Token, TokenElevation, @Elev, SizeOf(Elev), ElevSz) then
      Result.IsElevated := Elev.TokenIsElevated <> 0;
  finally
    CloseHandle(Token);
  end;
  Result.ProcessId := GetCurrentProcessId;
  Result.UptimeMs := GetTickCount64;
  FillChar(Mem, SizeOf(Mem), 0);
  Mem.dwLength := SizeOf(Mem);
  if GlobalMemoryStatusEx(Mem) then
  begin
    Result.HasMemory := True;
    Result.MemoryLoadPercent := Integer(Mem.dwMemoryLoad);
    Result.TotalPhysical := Int64(Mem.ullTotalPhys);
    Result.AvailPhysical := Int64(Mem.ullAvailPhys);
    Result.TotalPageFile := Int64(Mem.ullTotalPageFile);
    Result.AvailPageFile := Int64(Mem.ullAvailPageFile);
    Result.TotalVirtual := Int64(Mem.ullTotalVirtual);
    Result.AvailVirtual := Int64(Mem.ullAvailVirtual);
  end;
end;

end.
