unit uResourceAccess;

{ Access to the RCDATA resources embedded in the running program (Windows).
  The Posix build of this unit lives in Platform\Posix; each project puts
  exactly one of the two directories on its unit search path. }

interface

uses
  System.Classes;

/// <summary>Opens the RCDATA resource AName, looking in this module first and
/// then in the main module. Returns nil when it is absent; the caller frees
/// the stream.</summary>
function OpenRcData(const AName: string): TStream;

/// <summary>Adds the names (upper case) of the RCDATA resources that start
/// with APrefix to AList, without duplicates.</summary>
procedure ListRcDataNames(const APrefix: string; AList: TStrings);

implementation

uses
  System.SysUtils, Winapi.Windows;

function OpenRcData(const AName: string): TStream;
var
  Module: HMODULE;
begin
  Module := HInstance;
  if FindResource(Module, PChar(AName), RT_RCDATA) = 0 then
  begin
    Module := MainInstance;
    if FindResource(Module, PChar(AName), RT_RCDATA) = 0 then
      Exit(nil);
  end;
  try
    Result := TResourceStream.Create(Module, AName, RT_RCDATA);
  except
    Result := nil;
  end;
end;

type
  PNameQuery = ^TNameQuery;
  TNameQuery = record
    Prefix: string;
    Names: TStrings;
  end;

function EnumNamesProc(AModule: HMODULE; AType, AName: PChar;
  AParam: NativeInt): BOOL; stdcall;
var
  Query: PNameQuery;
  NameStr: string;
begin
  // Named resources only: an integer id arrives as a small value in the
  // pointer, which has no high word.
  if (NativeUInt(AName) shr 16) <> 0 then
  begin
    Query := PNameQuery(AParam);
    NameStr := UpperCase(AName);
    if NameStr.StartsWith(Query.Prefix) and (Query.Names.IndexOf(NameStr) < 0) then
      Query.Names.Add(NameStr);
  end;
  Result := True;
end;

procedure ListRcDataNames(const APrefix: string; AList: TStrings);
var
  Query: TNameQuery;
begin
  Query.Prefix := UpperCase(APrefix);
  Query.Names := AList;
  EnumResourceNames(HInstance, RT_RCDATA, @EnumNamesProc, NativeInt(@Query));
end;

end.
