unit uPlatformFileAttr;

{ Reading and writing the attributes, owner and times of one local file (POSIX
  build). The read-only flag is the absence of write permission, hidden means a
  name that starts with a dot, the system and archive flags do not exist; the
  owner is the user name, the times are the change, modification and access
  times (the creation time is the inode change time). The Windows build lives
  in Platform\Windows; each project puts exactly one of the two directories on
  its unit search path. }

interface

uses
  uFileAttrTypes;

/// <summary>Reads the attributes, owner and times of APath.</summary>
function TryReadFileAttrSnapshot(const APath: string;
  out ASnap: TFileAttrSnapshot; out AError: string): Boolean;

/// <summary>Applies APlan to the single item APath (no recursion).</summary>
function ApplyFileAttrOne(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;

implementation

uses
  System.SysUtils, System.DateUtils, Posix.Base, Posix.SysStat;

type
  TPasswd = record
    pw_name: MarshaledAString;
    pw_passwd: MarshaledAString;
    pw_uid: Cardinal;
    pw_gid: Cardinal;
  end;
  PPasswd = ^TPasswd;

  TTimeVal = record
    Sec: Int64;
    USec: Int64;
  end;

function c_getpwuid(AUid: Cardinal): PPasswd; cdecl; external libc name 'getpwuid';
function c_getpwnam(AName: MarshaledAString): PPasswd; cdecl; external libc name 'getpwnam';
function c_chown(APath: MarshaledAString; AUid, AGid: Cardinal): Integer; cdecl;
  external libc name 'chown';
function c_utimes(APath: MarshaledAString; ATimes: Pointer): Integer; cdecl;
  external libc name 'utimes';

function SysErrorText: string;
begin
  Result := SysErrorMessage(GetLastError);
  if Result = '' then
    Result := 'Access denied';
end;

function UnixToLocal(ASeconds: Int64): TDateTime;
begin
  Result := UnixToDateTime(ASeconds, False);
end;

function LocalToUnix(ATime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(ATime, False);
end;

function UserNameOf(AUid: Cardinal): string;
var
  P: PPasswd;
begin
  P := c_getpwuid(AUid);
  if (P <> nil) and (P^.pw_name <> nil) then
    Result := UTF8ToString(P^.pw_name)
  else
    Result := IntToStr(AUid);
end;

function TryReadFileAttrSnapshot(const APath: string;
  out ASnap: TFileAttrSnapshot; out AError: string): Boolean;
var
  St: _stat;
  P: UTF8String;
begin
  Result := False;
  ASnap := Default(TFileAttrSnapshot);
  AError := '';
  P := UTF8String(ExcludeTrailingPathDelimiter(APath));
  if stat(MarshaledAString(P), St) <> 0 then
  begin
    AError := SysErrorText;
    Exit;
  end;
  ASnap.ReadOnly := (St.st_mode and S_IWUSR) = 0;
  ASnap.Hidden := Copy(ExtractFileName(ExcludeTrailingPathDelimiter(APath)), 1, 1) = '.';
  ASnap.Owner := UserNameOf(St.st_uid);
  ASnap.Times.Created := UnixToLocal(St.st_ctime);
  ASnap.Times.Modified := UnixToLocal(St.st_mtime);
  ASnap.Times.Accessed := UnixToLocal(St.st_atime);
  Result := True;
end;

function ApplyMode(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;
var
  St: _stat;
  P: UTF8String;
  Mode: Cardinal;
const
  cWriteBits = S_IWUSR or S_IWGRP or S_IWOTH;
begin
  Result := False;
  AError := '';
  if APlan.ReadOnly = facKeep then
    Exit(True);
  P := UTF8String(ExcludeTrailingPathDelimiter(APath));
  if stat(MarshaledAString(P), St) <> 0 then
  begin
    AError := SysErrorText;
    Exit;
  end;
  Mode := St.st_mode and $FFF;
  if APlan.ReadOnly = facSet then
    Mode := Mode and not cWriteBits
  else
    Mode := Mode or S_IWUSR;
  if Mode = (St.st_mode and $FFF) then
    Exit(True);
  if chmod(MarshaledAString(P), Mode) <> 0 then
  begin
    AError := SysErrorText;
    Exit;
  end;
  Result := True;
end;

function ApplyTimes(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;
var
  St: _stat;
  P: UTF8String;
  T: array[0..1] of TTimeVal;
begin
  Result := False;
  AError := '';
  // The creation time cannot be set; only access and modification are.
  if not (APlan.SetModified or APlan.SetAccessed) then
    Exit(True);
  P := UTF8String(ExcludeTrailingPathDelimiter(APath));
  if stat(MarshaledAString(P), St) <> 0 then
  begin
    AError := SysErrorText;
    Exit;
  end;
  T[0].Sec := St.st_atime;
  T[0].USec := 0;
  T[1].Sec := St.st_mtime;
  T[1].USec := 0;
  if APlan.SetAccessed then
    T[0].Sec := LocalToUnix(APlan.Times.Accessed);
  if APlan.SetModified then
    T[1].Sec := LocalToUnix(APlan.Times.Modified);
  if c_utimes(MarshaledAString(P), @T[0]) <> 0 then
  begin
    AError := SysErrorText;
    Exit;
  end;
  Result := True;
end;

function ApplyOwner(const APath, AOwner: string; out AError: string): Boolean;
var
  Name, P: UTF8String;
  Pw: PPasswd;
begin
  Result := False;
  AError := '';
  if Trim(AOwner) = '' then
  begin
    AError := 'Owner name is empty';
    Exit;
  end;
  Name := UTF8String(Trim(AOwner));
  Pw := c_getpwnam(MarshaledAString(Name));
  if Pw = nil then
  begin
    AError := 'Unknown account: ' + AOwner;
    Exit;
  end;
  P := UTF8String(ExcludeTrailingPathDelimiter(APath));
  if c_chown(MarshaledAString(P), Pw^.pw_uid, Cardinal(-1)) <> 0 then
  begin
    AError := SysErrorText;
    Exit;
  end;
  Result := True;
end;

function ApplyFileAttrOne(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;
var
  Err: string;
  Snap: TFileAttrSnapshot;
begin
  Result := False;
  AError := '';
  if not ApplyMode(APath, APlan, Err) then
  begin
    AError := Err;
    Exit;
  end;
  if not ApplyTimes(APath, APlan, Err) then
  begin
    AError := Err;
    Exit;
  end;
  if APlan.ChangeOwner then
  begin
    if TryReadFileAttrSnapshot(APath, Snap, Err) and
       SameText(Snap.Owner, Trim(APlan.Owner)) then
      Exit(True);
    if not ApplyOwner(APath, APlan.Owner, Err) then
    begin
      AError := Err;
      Exit;
    end;
  end;
  Result := True;
end;

end.
