unit uPlatformFonts;

{ Installed font families (Windows build, GDI). The Posix build lives in
  Platform\Posix; each project puts exactly one of the two directories on its
  unit search path. }

interface

/// <summary>Monospace family used when nothing else is configured or
/// installed.</summary>
function PlatformDefaultMonoFont: string;

/// <summary>True when a font family with this exact face name is installed.</summary>
function PlatformFontInstalled(const AName: string): Boolean;

/// <summary>Face names of the installed fixed-pitch families.</summary>
function PlatformMonoFonts: TArray<string>;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, Winapi.Windows;

function PlatformDefaultMonoFont: string;
{$IFDEF SKIA}
var
  WinDir, CascadiaPath: string;
{$ENDIF}
begin
  Result := 'Consolas';
  {$IFDEF SKIA}
  WinDir := GetEnvironmentVariable('WINDIR');
  if WinDir = '' then
    WinDir := 'C:\Windows';
  CascadiaPath := TPath.Combine(TPath.Combine(WinDir, 'Fonts'), 'CascadiaMono.ttf');
  if TFile.Exists(CascadiaPath) then
    Exit('Cascadia Mono');
  CascadiaPath := TPath.Combine(TPath.Combine(WinDir, 'Fonts'), 'cascadiamono.ttf');
  if TFile.Exists(CascadiaPath) then
    Exit('Cascadia Mono');
  {$ENDIF}
end;

function FamilyPresentProc(var LogFont: TLogFont; var TextMetric: TTextMetric;
  FontType: Integer; Data: LPARAM): Integer; stdcall;
begin
  PBoolean(Data)^ := True;
  Result := 0;
end;

function PlatformFontInstalled(const AName: string): Boolean;
var
  DC: HDC;
  LF: TLogFont;
  Found: Boolean;
  Face: string;
begin
  Result := False;
  Face := Trim(AName);
  if Face = '' then
    Exit;
  Found := False;
  FillChar(LF, SizeOf(LF), 0);
  LF.lfCharSet := DEFAULT_CHARSET;
  StrLCopy(@LF.lfFaceName[0], PChar(Face), LF_FACESIZE - 1);
  DC := GetDC(0);
  if DC = 0 then
    Exit;
  try
    EnumFontFamiliesEx(DC, LF, @FamilyPresentProc, LPARAM(@Found), 0);
  finally
    ReleaseDC(0, DC);
  end;
  Result := Found;
end;

function MonoEnumProc(var LogFont: TLogFont; var TextMetric: TTextMetric;
  FontType: Integer; Data: LPARAM): Integer; stdcall;
var
  Face: string;
  List: TStringList;
begin
  Result := 1;
  List := TStringList(Data);
  if (TextMetric.tmPitchAndFamily and TMPF_FIXED_PITCH) <> 0 then
    Exit;
  Face := Trim(string(LogFont.lfFaceName));
  if (Face = '') or Face.StartsWith('@') then
    Exit;
  if List.IndexOf(Face) < 0 then
    List.Add(Face);
end;

function PlatformMonoFonts: TArray<string>;
var
  DC: HDC;
  LF: TLogFont;
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.CaseSensitive := False;
    FillChar(LF, SizeOf(LF), 0);
    LF.lfCharSet := DEFAULT_CHARSET;
    LF.lfPitchAndFamily := FIXED_PITCH or FF_DONTCARE;
    DC := GetDC(0);
    if DC <> 0 then
    try
      EnumFontFamiliesEx(DC, LF, @MonoEnumProc, LPARAM(List), 0);
    finally
      ReleaseDC(0, DC);
    end;
    Result := List.ToStringArray;
  finally
    List.Free;
  end;
end;

end.
