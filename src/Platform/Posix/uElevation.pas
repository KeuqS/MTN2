unit uElevation;

{ The rights this process runs with (POSIX build): administrator means the
  effective user is root. The Windows build lives in Platform\Windows; each
  project puts exactly one of the two directories on its unit search path. }

interface

type
  TProcessRights = (prUser, prAdministrator);

/// <summary>True when the process runs as root.</summary>
function IsProcessElevated: Boolean;
function CurrentProcessRights: TProcessRights;
/// <summary>True where a helper process with administrator rights can be
/// started on request.</summary>
function ElevationAvailable: Boolean;
/// <summary>Short label for the window title: "Administrator", or '' for a user.</summary>
function ProcessRightsLabel(ARights: TProcessRights): string;

implementation

uses
  Posix.Base;

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
begin
  Result := False;
end;

function ProcessRightsLabel(ARights: TProcessRights): string;
begin
  if ARights = prAdministrator then
    Result := 'Administrator'
  else
    Result := '';
end;

end.
