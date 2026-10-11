unit uPlatformFolders;

{ The well-known folders of the current user and system (Windows build), shown
  by the sys://folders view. The POSIX build lives in Platform\Posix; each
  project puts exactly one of the two directories on its unit search path. }

interface

type
  TPlatformFolder = record
    Name: string;
    Path: string;
  end;

/// <summary>The existing well-known folders in display order.</summary>
function PlatformSystemFolders: TArray<TPlatformFolder>;

/// <summary>The user's documents folder; the home folder where there is none.</summary>
function PlatformDocumentsDir: string;

/// <summary>The folder the panels start in on the second workspace; the home
/// folder where no projects folder is known.</summary>
function PlatformProjectsDir: string;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows, Winapi.ShLObj;

function SpecialFolderPath(ACSIDL: Integer): string;
var
  Path: array[0..MAX_PATH] of Char;
begin
  Result := '';
  if SHGetFolderPath(0, ACSIDL, 0, SHGFP_TYPE_CURRENT, Path) = S_OK then
    Result := string(Path);
end;

function PlatformDocumentsDir: string;
begin
  Result := TPath.GetDocumentsPath;
  if (Result = '') or not TDirectory.Exists(Result) then
    Result := TPath.GetHomePath;
end;

function PlatformProjectsDir: string;
begin
  if TDirectory.Exists('D:\Work') then
    Result := 'D:\Work'
  else
    Result := TPath.GetHomePath;
end;

function PlatformSystemFolders: TArray<TPlatformFolder>;
var
  List: TArray<TPlatformFolder>;

  procedure Add(const AName, APath: string);
  var
    N: Integer;
  begin
    if (APath = '') or not TDirectory.Exists(APath) then
      Exit;
    N := Length(List);
    SetLength(List, N + 1);
    List[N].Name := AName;
    List[N].Path := APath;
  end;

var
  Profile, Downloads: string;
begin
  SetLength(List, 0);
  Profile := SpecialFolderPath(CSIDL_PROFILE);
  Downloads := TPath.Combine(Profile, 'Downloads');
  if not TDirectory.Exists(Downloads) then
    Downloads := Profile;
  Add('Desktop', SpecialFolderPath(CSIDL_DESKTOPDIRECTORY));
  Add('Documents', SpecialFolderPath(CSIDL_PERSONAL));
  Add('Downloads', Downloads);
  Add('Pictures', SpecialFolderPath(CSIDL_MYPICTURES));
  Add('Music', SpecialFolderPath(CSIDL_MYMUSIC));
  Add('Videos', SpecialFolderPath(CSIDL_MYVIDEO));
  Add('Program Files', SpecialFolderPath(CSIDL_PROGRAM_FILES));
  Add('Program Files (x86)', SpecialFolderPath(CSIDL_PROGRAM_FILESX86));
  Add('Windows', SpecialFolderPath(CSIDL_WINDOWS));
  Add('System32', SpecialFolderPath(CSIDL_SYSTEM));
  Add('AppData (Roaming)', SpecialFolderPath(CSIDL_APPDATA));
  Add('AppData (Local)', SpecialFolderPath(CSIDL_LOCAL_APPDATA));
  Add('UserProfile', Profile);
  Add('Common AppData', SpecialFolderPath(CSIDL_COMMON_APPDATA));
  Result := List;
end;

end.
