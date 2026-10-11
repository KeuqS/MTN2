unit uResourceAccess;

{ Access to the RCDATA resources embedded in the running program (Posix).
  Resources are read through TResourceStream; the RTL has no way to list
  them, so the build embeds an RCDATA resource named RESOURCE_INDEX with one
  resource name per line. The Windows build of this unit lives in
  Platform\Windows; each project puts exactly one of the two directories on
  its unit search path. }

interface

uses
  System.Classes;

/// <summary>Opens the RCDATA resource AName, or returns nil when it is
/// absent; the caller frees the stream.</summary>
function OpenRcData(const AName: string): TStream;

/// <summary>Adds the names (upper case) of the RCDATA resources that start
/// with APrefix to AList, without duplicates.</summary>
procedure ListRcDataNames(const APrefix: string; AList: TStrings);

implementation

uses
  System.SysUtils;

const
  cResIndex = 'RESOURCE_INDEX';
  cRcData = PChar(10);

function OpenRcData(const AName: string): TStream;
begin
  try
    Result := TResourceStream.Create(HInstance, AName, cRcData);
  except
    Result := nil;
  end;
end;

procedure ListRcDataNames(const APrefix: string; AList: TStrings);
var
  Stream: TStream;
  Lines: TStringList;
  Prefix, NameStr: string;
begin
  Stream := OpenRcData(cResIndex);
  if Stream = nil then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromStream(Stream, TEncoding.UTF8);
    Prefix := UpperCase(APrefix);
    for NameStr in Lines do
      if UpperCase(Trim(NameStr)).StartsWith(Prefix) and
         (AList.IndexOf(UpperCase(Trim(NameStr))) < 0) then
        AList.Add(UpperCase(Trim(NameStr)));
  finally
    Lines.Free;
    Stream.Free;
  end;
end;

end.
