unit uElevation;

{ The rights this process runs with (POSIX build): administrator means the
  effective user is root; a plain user gets administrator rights for single
  operations through sudo (uElevatedVfs). The Windows build lives in
  Platform\Windows; each project puts exactly one of the two directories on
  its unit search path. }

interface

type
  TProcessRights = (prUser, prAdministrator);

/// <summary>True when the process runs as root.</summary>
function IsProcessElevated: Boolean;
function CurrentProcessRights: TProcessRights;
/// <summary>True where administrator rights can be asked for on request: the
/// process is not root and sudo is installed.</summary>
function ElevationAvailable: Boolean;
/// <summary>Short label for the window title: "Administrator", or '' for a user.</summary>
function ProcessRightsLabel(ARights: TProcessRights): string;

implementation

uses
  System.SysUtils, Posix.Base, uPlatformProcess;

var
  GSudoChecked: Boolean;
  GSudoFound: Boolean;

function c_geteuid: Cardinal; cdecl; external libc name 'geteuid';

function IsProcessElevated: Boolean;
begin
  Result := c_geteuid = 0;
end;

function CurrentProcessRights: TProcessRights;
begin
  if IsProcessElevated then
    Result := prAdministrator
  else
    Result := prUser;
end;

function ElevationAvailable: Boolean;
var
  Output: string;
  Code: Cardinal;
begin
  if IsProcessElevated then
    Exit(False);
  if not GSudoChecked then
  begin
    GSudoFound := (PlatformRunCaptured('sudo', ['-V'], '', 5000, nil, Output, Code) = srOk) and
      (Code = 0);
    GSudoChecked := True;
  end;
  Result := GSudoFound;
end;

function ProcessRightsLabel(ARights: TProcessRights): string;
begin
  if ARights = prAdministrator then
    Result := 'Administrator'
  else
    Result := '';
end;

end.
