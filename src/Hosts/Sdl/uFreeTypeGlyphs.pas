unit uFreeTypeGlyphs;

{ Glyph source backed by FreeType: one font file per style of the configured
  family, plus fallback files looked up by code point for characters the main
  font lacks (CJK, symbols). Rendered glyphs are cached per character and
  style. The cell is sized from the regular face: its widest ASCII advance and
  its ascent and descent. }

interface

uses
  uGlyphSource;

/// <summary>A glyph source for a font family at a pixel size; nil with
/// AError set when FreeType or the font file is missing.</summary>
function CreateFreeTypeGlyphSource(const AFamily: string; APixelSize: Integer;
  out AError: string): IGlyphSource;

/// <summary>The same for a font file chosen by path; bold and italic text
/// uses the same file.</summary>
function CreateFreeTypeGlyphSourceFromFile(const AFontFile: string; APixelSize: Integer;
  out AError: string): IGlyphSource;

implementation

uses
  System.SysUtils, System.Generics.Collections, uFreeTypeApi, uPlatformFonts;

type
  TFaceSet = class
  strict private
    FLib: TFtLibrary;
    FPixelSize: Integer;
    FFaces: TDictionary<string, TFtFace>;
    FMissing: TDictionary<string, Boolean>;
  public
    constructor Create(ALib: TFtLibrary; APixelSize: Integer);
    destructor Destroy; override;
    /// <summary>The face of a font file, opened once; nil when it cannot be
    /// opened.</summary>
    function Open(const AFile: string): TFtFace;
  end;

  TFreeTypeGlyphSource = class(TInterfacedObject, IGlyphSource)
  strict private
    FLib: TFtLibrary;
    FFaces: TFaceSet;
    FFamily: string;
    FStyleFiles: array[Boolean, Boolean] of string;
    FCellW, FCellH, FBaseline: Integer;
    FCache: TDictionary<Int64, TGlyphBitmap>;
    FEmpty: TDictionary<Int64, Boolean>;
    FFallbackFiles: TDictionary<Integer, string>;
    function StyleFile(ABold, AItalic: Boolean): string;
    function FallbackFile(ACodePoint: Integer): string;
    function Render(AFace: TFtFace; ACodePoint: Integer; out AGlyph: TGlyphBitmap): Boolean;
    procedure Measure(AFace: TFtFace);
  public
    constructor Create(ALib: TFtLibrary; const AFamily, ARegularFile: string;
      APixelSize: Integer);
    destructor Destroy; override;
    function CellWidth: Integer;
    function CellHeight: Integer;
    function Baseline: Integer;
    function TryGetGlyph(ACodePoint: Integer; ABold, AItalic: Boolean;
      out AGlyph: TGlyphBitmap): Boolean;
  end;

{ TFaceSet }

constructor TFaceSet.Create(ALib: TFtLibrary; APixelSize: Integer);
begin
  inherited Create;
  FLib := ALib;
  FPixelSize := APixelSize;
  FFaces := TDictionary<string, TFtFace>.Create;
  FMissing := TDictionary<string, Boolean>.Create;
end;

destructor TFaceSet.Destroy;
var
  Face: TFtFace;
begin
  for Face in FFaces.Values do
    FT_Done_Face(Face);
  FFaces.Free;
  FMissing.Free;
  inherited;
end;

function TFaceSet.Open(const AFile: string): TFtFace;
var
  Path: UTF8String;
begin
  if AFile = '' then
    Exit(nil);
  if FFaces.TryGetValue(AFile, Result) then
    Exit;
  if FMissing.ContainsKey(AFile) then
    Exit(nil);
  Path := UTF8String(AFile);
  Result := nil;
  if (FT_New_Face(FLib, PAnsiChar(Path), 0, Result) <> 0) or (Result = nil) or
     (FT_Set_Pixel_Sizes(Result, 0, FPixelSize) <> 0) then
  begin
    if Result <> nil then
      FT_Done_Face(Result);
    FMissing.Add(AFile, True);
    Exit(nil);
  end;
  FFaces.Add(AFile, Result);
end;

{ TFreeTypeGlyphSource }

constructor TFreeTypeGlyphSource.Create(ALib: TFtLibrary; const AFamily,
  ARegularFile: string; APixelSize: Integer);
var
  Face: TFtFace;
begin
  inherited Create;
  FLib := ALib;
  FFamily := AFamily;
  FFaces := TFaceSet.Create(ALib, APixelSize);
  FCache := TDictionary<Int64, TGlyphBitmap>.Create;
  FEmpty := TDictionary<Int64, Boolean>.Create;
  FFallbackFiles := TDictionary<Integer, string>.Create;
  FStyleFiles[False, False] := ARegularFile;
  Face := FFaces.Open(ARegularFile);
  Measure(Face);
end;

destructor TFreeTypeGlyphSource.Destroy;
begin
  FFallbackFiles.Free;
  FEmpty.Free;
  FCache.Free;
  FFaces.Free;
  FT_Done_FreeType(FLib);
  inherited;
end;

procedure TFreeTypeGlyphSource.Measure(AFace: TFtFace);
var
  Info: TFtSizeInfo;
  Ch: Integer;
  Glyph: TFtBitmapInfo;
  Adv, W: Integer;
begin
  Info := FtSizeInfo(AFace);
  FBaseline := Info.Ascender;
  FCellH := Info.Ascender - Info.Descender;
  W := 0;
  for Ch := 32 to 126 do
    if FT_Load_Glyph(AFace, FT_Get_Char_Index(AFace, Ch), FT_LOAD_DEFAULT) = 0 then
    begin
      Glyph := FtGlyphBitmap(AFace);
      Adv := (Glyph.Advance + 32) div 64;
      if Adv > W then
        W := Adv;
    end;
  FCellW := W;
  if FCellW < 1 then
    FCellW := (FCellH + 1) div 2;
  if FCellH < 1 then
    FCellH := 1;
end;

function TFreeTypeGlyphSource.CellWidth: Integer;
begin
  Result := FCellW;
end;

function TFreeTypeGlyphSource.CellHeight: Integer;
begin
  Result := FCellH;
end;

function TFreeTypeGlyphSource.Baseline: Integer;
begin
  Result := FBaseline;
end;

function TFreeTypeGlyphSource.StyleFile(ABold, AItalic: Boolean): string;
begin
  Result := FStyleFiles[ABold, AItalic];
  if Result <> '' then
    Exit;
  if FFamily <> '' then
    Result := PlatformFontFile(FFamily, ABold, AItalic);
  if Result = '' then
    Result := FStyleFiles[False, False];
  FStyleFiles[ABold, AItalic] := Result;
end;

function TFreeTypeGlyphSource.FallbackFile(ACodePoint: Integer): string;
begin
  if not FFallbackFiles.TryGetValue(ACodePoint, Result) then
  begin
    Result := PlatformFontFileForChar(ACodePoint);
    FFallbackFiles.Add(ACodePoint, Result);
  end;
end;

function TFreeTypeGlyphSource.Render(AFace: TFtFace; ACodePoint: Integer;
  out AGlyph: TGlyphBitmap): Boolean;
var
  Index: Cardinal;
  Bmp: TFtBitmapInfo;
  Y, X: Integer;
  Row: PByte;
begin
  AGlyph := Default(TGlyphBitmap);
  Result := False;
  if AFace = nil then
    Exit;
  Index := FT_Get_Char_Index(AFace, ACodePoint);
  if Index = 0 then
    Exit;
  if FT_Load_Glyph(AFace, Index, FT_LOAD_RENDER or FT_LOAD_NO_BITMAP) <> 0 then
    Exit;
  Bmp := FtGlyphBitmap(AFace);
  AGlyph.Width := Bmp.Width;
  AGlyph.Height := Bmp.Rows;
  AGlyph.Left := Bmp.Left;
  AGlyph.Top := Bmp.Top;
  SetLength(AGlyph.Alpha, Bmp.Width * Bmp.Rows);
  if (Bmp.Buffer <> nil) and (Bmp.Width > 0) then
    for Y := 0 to Bmp.Rows - 1 do
    begin
      Row := Bmp.Buffer;
      if Bmp.Pitch >= 0 then
        Inc(Row, Y * Bmp.Pitch)
      else
        Inc(Row, (Bmp.Rows - 1 - Y) * -Bmp.Pitch);
      for X := 0 to Bmp.Width - 1 do
        if Bmp.PixelMode = FT_PIXEL_MODE_MONO then
          AGlyph.Alpha[Y * Bmp.Width + X] :=
            Ord(((Row[X shr 3] shr (7 - (X and 7))) and 1) <> 0) * 255
        else
          AGlyph.Alpha[Y * Bmp.Width + X] := Row[X];
    end;
  Result := True;
end;

function TFreeTypeGlyphSource.TryGetGlyph(ACodePoint: Integer; ABold, AItalic: Boolean;
  out AGlyph: TGlyphBitmap): Boolean;
var
  Key: Int64;
begin
  Key := (Int64(ACodePoint) shl 2) or (Ord(ABold) shl 1) or Ord(AItalic);
  if FCache.TryGetValue(Key, AGlyph) then
    Exit(True);
  if FEmpty.ContainsKey(Key) then
    Exit(False);
  Result := Render(FFaces.Open(StyleFile(ABold, AItalic)), ACodePoint, AGlyph);
  if (not Result) and (ABold or AItalic) then
    Result := Render(FFaces.Open(StyleFile(False, False)), ACodePoint, AGlyph);
  if not Result then
    Result := Render(FFaces.Open(FallbackFile(ACodePoint)), ACodePoint, AGlyph);
  if Result then
    FCache.Add(Key, AGlyph)
  else
    FEmpty.Add(Key, True);
end;

function OpenLibrary(out ALib: TFtLibrary; out AError: string): Boolean;
begin
  Result := False;
  if not LoadFreeType(AError) then
    Exit;
  ALib := nil;
  if (FT_Init_FreeType(ALib) <> 0) or (ALib = nil) then
  begin
    AError := 'FreeType could not start';
    Exit;
  end;
  Result := True;
end;

function CreateFreeTypeGlyphSource(const AFamily: string; APixelSize: Integer;
  out AError: string): IGlyphSource;
var
  Lib: TFtLibrary;
  FontFile: string;
begin
  Result := nil;
  FontFile := PlatformFontFile(AFamily, False, False);
  if FontFile = '' then
  begin
    AError := 'No font file for "' + AFamily + '"';
    Exit;
  end;
  if not OpenLibrary(Lib, AError) then
    Exit;
  Result := TFreeTypeGlyphSource.Create(Lib, AFamily, FontFile, APixelSize);
end;

function CreateFreeTypeGlyphSourceFromFile(const AFontFile: string; APixelSize: Integer;
  out AError: string): IGlyphSource;
var
  Lib: TFtLibrary;
begin
  Result := nil;
  if not FileExists(AFontFile) then
  begin
    AError := 'Font file not found: ' + AFontFile;
    Exit;
  end;
  if not OpenLibrary(Lib, AError) then
    Exit;
  Result := TFreeTypeGlyphSource.Create(Lib, '', AFontFile, APixelSize);
end;

end.
