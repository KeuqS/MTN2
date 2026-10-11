unit uLinkUtils;

{ Symlink and hardlink creation (POSIX build): symlink() and link(). Junctions
  exist only on Windows. The Windows build lives in Platform\Windows; each
  project puts exactly one of the two directories on its unit search path. }

interface

uses
  System.SysUtils, uVfsTypes;

type
  TLinkKind = (lkSymlinkFile, lkSymlinkDir, lkHardlink, lkJunction);

/// <summary>Creates a link at ALinkPath pointing at ATargetPath. Junctions are
/// reported as not supported.</summary>
function CreateFileLink(const ALinkPath, ATargetPath: string; AKind: TLinkKind;
  out AError: TVfsError): Boolean;

/// <summary>True when this process can create symbolic links (always).</summary>
function CanCreateSymlinks: Boolean;

/// <summary>Index of the "Create link" dropdown entry that fits the target: a
/// symlink to a file or to a folder.</summary>
function SuggestLinkTypeIndex(const ATargetPath, ALinkFolder: string): Integer;

implementation

uses
  System.IOUtils, Posix.Base;

function c_symlink(ATarget, ALink: MarshaledAString): Integer; cdecl;
  external libc name 'symlink';
function c_link(AExisting, ANew: MarshaledAString): Integer; cdecl;
  external libc name 'link';

function CanCreateSymlinks: Boolean;
begin
  Result := True;
end;

function SuggestLinkTypeIndex(const ATargetPath, ALinkFolder: string): Integer;
begin
  Result := Ord(TDirectory.Exists(ATargetPath));
end;

function CreateFileLink(const ALinkPath, ATargetPath: string; AKind: TLinkKind;
  out AError: TVfsError): Boolean;
var
  Target, Link: UTF8String;
begin
  AError := TVfsError.Ok;
  Target := UTF8String(ATargetPath);
  Link := UTF8String(ALinkPath);
  case AKind of
    lkSymlinkFile, lkSymlinkDir:
      begin
        Result := c_symlink(MarshaledAString(Target), MarshaledAString(Link)) = 0;
        if not Result then
          AError := TVfsError.Make(vecIOError,
            'Cannot create symbolic link: ' + SysErrorMessage(GetLastError),
            PathToFileUri(ALinkPath));
      end;
    lkHardlink:
      begin
        Result := c_link(MarshaledAString(Target), MarshaledAString(Link)) = 0;
        if not Result then
          AError := TVfsError.Make(vecIOError,
            'Cannot create hard link: ' + SysErrorMessage(GetLastError),
            PathToFileUri(ALinkPath));
      end;
  else
    Result := False;
    AError := TVfsError.Make(vecNotSupported, 'Junctions are not supported on this system',
      PathToFileUri(ALinkPath));
  end;
end;

end.
