unit uPlatformFileAttr;

{ Reading and writing the attributes, owner and times of one local file
  (Windows build): the R/H/S/A bits via SetFileAttributes, the owner via the
  security API, the times via SetFileTime. Times are local, converted the same
  way the panel's date columns do, so a time typed in the dialog is the time
  the panel then shows. The POSIX build lives in Platform\Posix; each project
  puts exactly one of the two directories on its unit search path. }

interface

uses
  uFileAttrTypes;

/// <summary>True where files have permission bits and a group (the Set
/// attributes command then shows the permissions dialog).</summary>
function PlatformFileModeSupported: Boolean;

/// <summary>Reads the attributes, owner and times of APath.</summary>
function TryReadFileAttrSnapshot(const APath: string;
  out ASnap: TFileAttrSnapshot; out AError: string): Boolean;

/// <summary>Applies APlan to the single item APath (no recursion).</summary>
function ApplyFileAttrOne(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;

implementation

uses
  System.SysUtils, Winapi.Windows, Winapi.AccCtrl, Winapi.AclAPI, uVfsTypes;

function FileTimeToLocalDateTime(const AFT: TFileTime): TDateTime;
var
  LFT: TFileTime;
  ST: TSystemTime;
begin
  Result := 0;
  if (AFT.dwLowDateTime = 0) and (AFT.dwHighDateTime = 0) then
    Exit;
  if FileTimeToLocalFileTime(AFT, LFT) and FileTimeToSystemTime(LFT, ST) then
    Result := SystemTimeToDateTime(ST);
end;

function LocalDateTimeToFileTime(ATime: TDateTime; out AFT: TFileTime): Boolean;
var
  ST: TSystemTime;
  LFT: TFileTime;
begin
  DateTimeToSystemTime(ATime, ST);
  Result := SystemTimeToFileTime(ST, LFT) and LocalFileTimeToFileTime(LFT, AFT);
end;

function ReadFileAttrTimes(const APath: string; out ATimes: TFileAttrTimes): Boolean;
var
  Data: TWin32FileAttributeData;
begin
  ATimes := Default(TFileAttrTimes);
  Result := GetFileAttributesEx(PChar(WinApiPath(APath)), GetFileExInfoStandard, @Data);
  if not Result then
    Exit;
  ATimes.Created := FileTimeToLocalDateTime(Data.ftCreationTime);
  ATimes.Modified := FileTimeToLocalDateTime(Data.ftLastWriteTime);
  ATimes.Accessed := FileTimeToLocalDateTime(Data.ftLastAccessTime);
end;

function SysErrorText: string;
begin
  Result := SysErrorMessage(GetLastError);
  if Result = '' then
    Result := 'Access denied';
end;

function EnablePrivilege(const AName: string): Boolean;
var
  Token: THandle;
  TP: TTokenPrivileges;
  Dummy: DWORD;
begin
  Result := False;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY,
    Token) then
    Exit;
  try
    if not LookupPrivilegeValue(nil, PChar(AName), TP.Privileges[0].Luid) then
      Exit;
    TP.PrivilegeCount := 1;
    TP.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
    Dummy := 0;
    AdjustTokenPrivileges(Token, False, TP, 0, PTokenPrivileges(nil)^, Dummy);
    Result := GetLastError = ERROR_SUCCESS;
  finally
    CloseHandle(Token);
  end;
end;

function ReadFileOwner(const APath: string; out AOwner: string): Boolean;
var
  SD: PSECURITY_DESCRIPTOR;
  OwnerSid: PSID;
  NameBuf, DomBuf: array[0..255] of Char;
  NameLen, DomLen: DWORD;
  Use: SID_NAME_USE;
begin
  Result := False;
  AOwner := '';
  OwnerSid := nil;
  SD := nil;
  if GetNamedSecurityInfo(PChar(APath), SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION,
    @OwnerSid, nil, nil, nil, SD) <> ERROR_SUCCESS then
    Exit;
  try
    NameLen := Length(NameBuf);
    DomLen := Length(DomBuf);
    if not LookupAccountSid(nil, OwnerSid, NameBuf, NameLen, DomBuf, DomLen, Use) then
      Exit;
    if DomBuf[0] <> #0 then
      AOwner := string(DomBuf) + '\' + string(NameBuf)
    else
      AOwner := string(NameBuf);
    Result := AOwner <> '';
  finally
    if Assigned(SD) then
      LocalFree(HLOCAL(SD));
  end;
end;

function PlatformFileModeSupported: Boolean;
begin
  Result := False;
end;

function TryReadFileAttrSnapshot(const APath: string;
  out ASnap: TFileAttrSnapshot; out AError: string): Boolean;
var
  Attr: DWORD;
begin
  Result := False;
  ASnap := Default(TFileAttrSnapshot);
  ASnap.Mode := -1;
  AError := '';
  Attr := GetFileAttributes(PChar(WinApiPath(APath)));
  if Attr = INVALID_FILE_ATTRIBUTES then
  begin
    AError := SysErrorText;
    Exit;
  end;
  ASnap.ReadOnly := (Attr and FILE_ATTRIBUTE_READONLY) <> 0;
  ASnap.Hidden := (Attr and FILE_ATTRIBUTE_HIDDEN) <> 0;
  ASnap.System := (Attr and FILE_ATTRIBUTE_SYSTEM) <> 0;
  ASnap.Archive := (Attr and FILE_ATTRIBUTE_ARCHIVE) <> 0;
  if not ReadFileOwner(APath, ASnap.Owner) then
    ASnap.Owner := '(unknown)';
  ReadFileAttrTimes(APath, ASnap.Times);
  Result := True;
end;

function ApplyAttrBits(Attr: DWORD; AChoice: TFileAttrChoice; ABit: DWORD): DWORD;
begin
  Result := Attr;
  case AChoice of
    facSet: Result := Result or ABit;
    facClear: Result := Result and not ABit;
  else
    ;
  end;
end;

function ApplyFileAttributesOnly(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;
var
  Attr, Next: DWORD;
begin
  Result := False;
  AError := '';
  Attr := GetFileAttributes(PChar(WinApiPath(APath)));
  if Attr = INVALID_FILE_ATTRIBUTES then
  begin
    AError := SysErrorText;
    Exit;
  end;
  Next := Attr;
  Next := ApplyAttrBits(Next, APlan.ReadOnly, FILE_ATTRIBUTE_READONLY);
  Next := ApplyAttrBits(Next, APlan.Hidden, FILE_ATTRIBUTE_HIDDEN);
  Next := ApplyAttrBits(Next, APlan.System, FILE_ATTRIBUTE_SYSTEM);
  Next := ApplyAttrBits(Next, APlan.Archive, FILE_ATTRIBUTE_ARCHIVE);
  if Next = Attr then
    Exit(True);
  if not SetFileAttributes(PChar(WinApiPath(APath)), Next) then
  begin
    AError := SysErrorText;
    Exit;
  end;
  Result := True;
end;

function ApplyFileTimes(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;
var
  H: THandle;
  C, A, M: TFileTime;
  PC, PA, PM: PFileTime;

  function Prepare(AUse: Boolean; ATime: TDateTime; var AFT: TFileTime;
    out AP: PFileTime): Boolean;
  begin
    AP := nil;
    Result := True;
    if not AUse then
      Exit;
    Result := LocalDateTimeToFileTime(ATime, AFT);
    if Result then
      AP := @AFT;
  end;

begin
  Result := False;
  AError := '';
  if not (APlan.SetCreated or APlan.SetModified or APlan.SetAccessed) then
    Exit(True);
  if not (Prepare(APlan.SetCreated, APlan.Times.Created, C, PC) and
          Prepare(APlan.SetModified, APlan.Times.Modified, M, PM) and
          Prepare(APlan.SetAccessed, APlan.Times.Accessed, A, PA)) then
  begin
    AError := 'Invalid date';
    Exit;
  end;
  // FILE_WRITE_ATTRIBUTES is allowed on read-only files; BACKUP_SEMANTICS
  // is what lets CreateFile open a directory.
  H := CreateFile(PChar(WinApiPath(APath)), FILE_WRITE_ATTRIBUTES,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS, 0);
  if H = INVALID_HANDLE_VALUE then
  begin
    AError := SysErrorText;
    Exit;
  end;
  try
    if not SetFileTime(H, PC, PA, PM) then
    begin
      AError := SysErrorText;
      Exit;
    end;
  finally
    CloseHandle(H);
  end;
  Result := True;
end;

function ApplyFileOwner(const APath, AOwner: string; out AError: string): Boolean;
var
  SidLen, DomLen: DWORD;
  Use: SID_NAME_USE;
  Sid: PSID;
  Domain: string;
  Code: DWORD;
begin
  Result := False;
  AError := '';
  if Trim(AOwner) = '' then
  begin
    AError := 'Owner name is empty';
    Exit;
  end;
  SidLen := 0;
  DomLen := 0;
  LookupAccountName(nil, PChar(AOwner), nil, SidLen, nil, DomLen, Use);
  if (SidLen = 0) then
  begin
    AError := 'Unknown account: ' + AOwner;
    Exit;
  end;
  GetMem(Sid, SidLen);
  try
    SetLength(Domain, DomLen);
    if DomLen > 0 then
    begin
      if not LookupAccountName(nil, PChar(AOwner), Sid, SidLen, PChar(Domain),
        DomLen, Use) then
      begin
        AError := SysErrorText;
        Exit;
      end;
    end
    else if not LookupAccountName(nil, PChar(AOwner), Sid, SidLen, nil, DomLen, Use) then
    begin
      AError := SysErrorText;
      Exit;
    end;
    Code := SetNamedSecurityInfo(PChar(APath), SE_FILE_OBJECT,
      OWNER_SECURITY_INFORMATION, Sid, nil, nil, nil);
    if Code = ERROR_ACCESS_DENIED then
    begin
      EnablePrivilege('SeTakeOwnershipPrivilege');
      EnablePrivilege('SeRestorePrivilege');
      Code := SetNamedSecurityInfo(PChar(APath), SE_FILE_OBJECT,
        OWNER_SECURITY_INFORMATION, Sid, nil, nil, nil);
    end;
    if Code <> ERROR_SUCCESS then
    begin
      AError := SysErrorMessage(Code);
      if AError = '' then
        AError := Format('Set owner failed (%d)', [Code]);
      Exit;
    end;
    Result := True;
  finally
    FreeMem(Sid);
  end;
end;

function ApplyFileAttrOne(const APath: string; const APlan: TFileAttrPlan;
  out AError: string): Boolean;
var
  Err, CurOwner: string;
begin
  Result := False;
  AError := '';
  if not ApplyFileAttributesOnly(APath, APlan, Err) then
  begin
    AError := Err;
    Exit;
  end;
  if not ApplyFileTimes(APath, APlan, Err) then
  begin
    AError := Err;
    Exit;
  end;
  if APlan.ChangeOwner then
  begin
    CurOwner := '';
    if ReadFileOwner(APath, CurOwner) and SameText(CurOwner, Trim(APlan.Owner)) then
    begin
      Result := True;
      Exit;
    end;
    if not ApplyFileOwner(APath, APlan.Owner, Err) then
    begin
      AError := Err;
      Exit;
    end;
  end;
  Result := True;
end;

end.
