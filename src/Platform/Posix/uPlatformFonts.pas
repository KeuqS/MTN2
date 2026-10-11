unit uPlatformFonts;

{ Installed font families (Posix build, fontconfig through the fc-list
  tool). The Windows build lives in Platform\Windows; each project puts
  exactly one of the two directories on its unit search path. }

interface

/// <summary>Monospace family used when nothing else is configured or
/// installed.</summary>
function PlatformDefaultMonoFont: string;

/// <summary>True when a font family with this exact name is installed.</summary>
function PlatformFontInstalled(const AName: string): Boolean;

/// <summary>Names of the installed monospace families.</summary>
function PlatformMonoFonts: TArray<string>;

implementation

uses
  System.SysUtils, System.Classes, Posix.Base;

function popen(ACommand, AMode: MarshaledAString): Pointer; cdecl;
  external libc name 'popen';
function pclose(AStream: Pointer): Integer; cdecl;
  external libc name 'pclose';
function fread(ABuf: Pointer; ASize, ACount: NativeUInt; AStream: Pointer): NativeUInt; cdecl;
  external libc name 'fread';

function RunCapture(const ACommand: string): string;
var
  Pipe: Pointer;
  Buf: array[0..4095] of Byte;
  Got: NativeUInt;
  Bytes: TBytes;
  Cmd: UTF8String;
begin
  Result := '';
  Cmd := UTF8String(ACommand);
  Pipe := popen(MarshaledAString(Cmd), 'r');
  if Pipe = nil then
    Exit;
  try
    repeat
      Got := fread(@Buf[0], 1, SizeOf(Buf), Pipe);
      if Got > 0 then
      begin
        SetLength(Bytes, Length(Bytes) + Got);
        Move(Buf[0], Bytes[Length(Bytes) - Got], Got);
      end;
    until Got = 0;
  finally
    pclose(Pipe);
  end;
  Result := TEncoding.UTF8.GetString(Bytes);
end;

function FamiliesOf(const AQuery: string): TArray<string>;
var
  Lines: TStringList;
  List: TStringList;
  Line, Family: string;
begin
  Lines := TStringList.Create;
  List := TStringList.Create;
  try
    List.CaseSensitive := False;
    Lines.Text := RunCapture('fc-list ' + AQuery + ' -f ''%{family}\n'' 2>/dev/null');
    for Line in Lines do
    begin
      // A font can carry several names ("Name,Alias"): the first is canonical.
      Family := Trim(Line);
      if Pos(',', Family) > 0 then
        Family := Trim(Copy(Family, 1, Pos(',', Family) - 1));
      if (Family <> '') and (List.IndexOf(Family) < 0) then
        List.Add(Family);
    end;
    Result := List.ToStringArray;
  finally
    List.Free;
    Lines.Free;
  end;
end;

function PlatformDefaultMonoFont: string;
begin
  Result := 'DejaVu Sans Mono';
end;

function PlatformFontInstalled(const AName: string): Boolean;
var
  Face: string;
  Name: string;
begin
  Face := Trim(AName);
  Result := False;
  if Face = '' then
    Exit;
  for Name in FamiliesOf('') do
    if SameText(Name, Face) then
      Exit(True);
end;

function PlatformMonoFonts: TArray<string>;
begin
  Result := FamiliesOf(':spacing=mono');
end;

end.
