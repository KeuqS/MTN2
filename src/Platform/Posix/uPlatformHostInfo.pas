unit uPlatformHostInfo;

{ Facts about the machine and the user session, shown by the panel info view
  (POSIX build). The Windows build lives in Platform\Windows; each project puts
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
  System.SysUtils, System.Classes, Posix.Base, Posix.Unistd, uPlatformInfo;

function c_geteuid: Cardinal; cdecl; external libc name 'geteuid';

function ReadFirstLine(const APath: string): string;
var
  Text: string;
  P: Integer;
begin
  Text := PlatformReadTextFile(APath);
  P := Pos(#10, Text);
  if P > 0 then
    Text := Copy(Text, 1, P - 1);
  Result := Trim(Text);
end;

// Value of a "/proc/meminfo" key in bytes, -1 when missing.
function MemInfoBytes(AList: TStrings; const AKey: string): Int64;
var
  Line, V: string;
  P: Integer;
begin
  Result := -1;
  for Line in AList do
    if Line.StartsWith(AKey + ':') then
    begin
      V := Trim(Copy(Line, Length(AKey) + 2, MaxInt));
      P := Pos(' ', V);
      if P > 0 then
        V := Copy(V, 1, P - 1);
      Result := StrToInt64Def(V, 0) * 1024;
      Exit;
    end;
end;

function PlatformHostInfo: TPlatformHostInfo;
var
  Mem: TStringList;
  Up, Text: string;
  P: Integer;
  F: Double;
  Total, Avail, SwapTotal, SwapFree: Int64;
begin
  Result := Default(TPlatformHostInfo);
  Result.ComputerName := ReadFirstLine('/etc/hostname');
  if Result.ComputerName = '' then
    Result.ComputerName := GetEnvironmentVariable('HOSTNAME');
  Result.UserName := GetEnvironmentVariable('USER');
  if Result.UserName = '' then
    Result.UserName := GetEnvironmentVariable('LOGNAME');
  Result.ProfileDir := GetEnvironmentVariable('HOME');
  Result.IsElevated := c_geteuid = 0;
  Result.ProcessId := Cardinal(getpid);
  Up := ReadFirstLine('/proc/uptime');
  P := Pos(' ', Up);
  if P > 0 then
    Up := Copy(Up, 1, P - 1);
  if TryStrToFloat(StringReplace(Up, '.', FormatSettings.DecimalSeparator, []), F) then
    Result.UptimeMs := Round(F * 1000);
  Text := PlatformReadTextFile('/proc/meminfo');
  if Text <> '' then
  begin
    Mem := TStringList.Create;
    try
      Mem.Text := Text;
      Total := MemInfoBytes(Mem, 'MemTotal');
      Avail := MemInfoBytes(Mem, 'MemAvailable');
      SwapTotal := MemInfoBytes(Mem, 'SwapTotal');
      SwapFree := MemInfoBytes(Mem, 'SwapFree');
      if (Total > 0) and (Avail >= 0) then
      begin
        Result.HasMemory := True;
        Result.TotalPhysical := Total;
        Result.AvailPhysical := Avail;
        Result.MemoryLoadPercent := Integer((Total - Avail) * 100 div Total);
        if SwapTotal < 0 then
          SwapTotal := 0;
        if SwapFree < 0 then
          SwapFree := 0;
        Result.TotalPageFile := SwapTotal;
        Result.AvailPageFile := SwapFree;
        Result.TotalVirtual := Total + SwapTotal;
        Result.AvailVirtual := Avail + SwapFree;
      end;
    finally
      Mem.Free;
    end;
  end;
end;

end.
