unit uPlatformFolders;

{ The well-known folders of the current user and system (POSIX build), shown
  by the sys://folders view. User folders come from the XDG user-dirs file
  with the conventional names as fallback. The Windows build lives in
  Platform\Windows; each project puts exactly one of the two directories on
  its unit search path. }

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
  System.SysUtils, System.Classes, System.IOUtils;

function HomeDir: string;
begin
  Result := GetEnvironmentVariable('HOME');
end;

// Value of an XDG_*_DIR line of user-dirs.dirs, '' when absent.
function XdgUserDir(const AKey: string): string;
var
  Cfg, Line, Prefix, Val: string;
  Lines: TStringList;
begin
  Result := '';
  Cfg := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Cfg = '' then
    Cfg := TPath.Combine(HomeDir, '.config');
  Cfg := TPath.Combine(Cfg, 'user-dirs.dirs');
  if not TFile.Exists(Cfg) then
    Exit;
  Prefix := 'XDG_' + AKey + '_DIR=';
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Cfg, TEncoding.UTF8);
    for Line in Lines do
      if Line.StartsWith(Prefix) then
      begin
        Val := Line.Substring(Length(Prefix)).Trim;
        if (Length(Val) >= 2) and (Val[1] = '"') and (Val[Length(Val)] = '"') then
          Val := Copy(Val, 2, Length(Val) - 2);
        Result := StringReplace(Val, '$HOME', HomeDir, [rfReplaceAll]);
        Exit;
      end;
  finally
    Lines.Free;
  end;
end;

function PlatformDocumentsDir: string;
begin
  Result := XdgUserDir('DOCUMENTS');
  if Result = '' then
    Result := TPath.Combine(HomeDir, 'Documents');
  if not TDirectory.Exists(Result) then
    Result := HomeDir;
end;

function PlatformProjectsDir: string;
begin
  Result := HomeDir;
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

  procedure AddUser(const AName, AKey, ADefault: string);
  var
    P: string;
  begin
    P := XdgUserDir(AKey);
    if P = '' then
      P := TPath.Combine(HomeDir, ADefault);
    Add(AName, P);
  end;

begin
  SetLength(List, 0);
  Add('Home', HomeDir);
  AddUser('Desktop', 'DESKTOP', 'Desktop');
  AddUser('Documents', 'DOCUMENTS', 'Documents');
  AddUser('Downloads', 'DOWNLOAD', 'Downloads');
  AddUser('Pictures', 'PICTURES', 'Pictures');
  AddUser('Music', 'MUSIC', 'Music');
  AddUser('Videos', 'VIDEOS', 'Videos');
  Add('Config', TPath.Combine(HomeDir, '.config'));
  Add('Local data', TPath.Combine(HomeDir, '.local/share'));
  Add('Root', '/');
  Add('etc', '/etc');
  Add('usr', '/usr');
  Add('var', '/var');
  Add('opt', '/opt');
  Add('tmp', '/tmp');
  Add('media', '/media');
  Add('mnt', '/mnt');
  Result := List;
end;

end.
