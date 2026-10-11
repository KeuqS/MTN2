unit TestFreeTypeGlyphs;

{ Glyphs rendered by FreeType from the system fonts. The fixture needs
  libfreetype and a monospace font; where either is missing it ends at once
  as passed, as there is nothing to check. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestFreeTypeGlyphs = class
  public
    [Test] procedure CellSizeFollowsThePixelSize;
    [Test] procedure LetterHasCoverageAboveTheBaseline;
    [Test] procedure SpaceHasNoCoverage;
    [Test] procedure FallbackFontServesWideCharacters;
    [Test] procedure MissingFontReportsAnError;
    [Test] procedure RenderedGridShowsText;
  end;

implementation

uses
  System.SysUtils, System.Types, System.UITypes, uGlyphSource, uFreeTypeGlyphs,
  uPlatformFonts, uTerminalTypes, uPixelGrid;

function OpenSource(APixelSize: Integer): IGlyphSource;
var
  Err: string;
begin
  Result := CreateFreeTypeGlyphSource(PlatformDefaultMonoFont, APixelSize, Err);
end;

function Covered(const AGlyph: TGlyphBitmap): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AGlyph.Alpha) do
    if AGlyph.Alpha[I] > 0 then
      Inc(Result);
end;

procedure TTestFreeTypeGlyphs.CellSizeFollowsThePixelSize;
var
  Small, Large: IGlyphSource;
begin
  Small := OpenSource(12);
  if Small = nil then
    Assert.Pass('FreeType or the font is not available');
  Large := OpenSource(24);
  Assert.IsTrue(Small.CellWidth >= 5, 'a readable cell width');
  Assert.IsTrue(Small.CellHeight > Small.CellWidth, 'cells are taller than wide');
  Assert.IsTrue(Small.Baseline > 0);
  Assert.IsTrue(Small.Baseline < Small.CellHeight);
  Assert.IsTrue(Large.CellWidth > Small.CellWidth);
  Assert.IsTrue(Large.CellHeight > Small.CellHeight);
end;

procedure TTestFreeTypeGlyphs.LetterHasCoverageAboveTheBaseline;
var
  Src: IGlyphSource;
  G, Bold: TGlyphBitmap;
begin
  Src := OpenSource(20);
  if Src = nil then
    Assert.Pass('FreeType or the font is not available');
  Assert.IsTrue(Src.TryGetGlyph(Ord('H'), False, False, G));
  Assert.IsTrue(G.Width > 0);
  Assert.IsTrue(G.Height > 0);
  Assert.AreEqual(G.Width * G.Height, Integer(Length(G.Alpha)));
  Assert.IsTrue(G.Top >= G.Height, 'a capital letter stands on the baseline');
  Assert.IsTrue(Covered(G) > G.Width, 'its strokes are drawn');
  Assert.IsTrue(G.Width <= Src.CellWidth + 2, 'it fits its cell');
  Assert.IsTrue(Src.TryGetGlyph(Ord('H'), True, False, Bold));
  Assert.IsTrue(Covered(Bold) >= Covered(G), 'bold has at least as much ink');
end;

procedure TTestFreeTypeGlyphs.SpaceHasNoCoverage;
var
  Src: IGlyphSource;
  G: TGlyphBitmap;
begin
  Src := OpenSource(16);
  if Src = nil then
    Assert.Pass('FreeType or the font is not available');
  if Src.TryGetGlyph(Ord(' '), False, False, G) then
    Assert.AreEqual(0, Covered(G));
end;

procedure TTestFreeTypeGlyphs.FallbackFontServesWideCharacters;
var
  Src: IGlyphSource;
  G: TGlyphBitmap;
begin
  Src := OpenSource(16);
  if Src = nil then
    Assert.Pass('FreeType or the font is not available');
  // A character that the monospace font lacks may come from another font;
  // when none has it the answer is simply no glyph.
  if Src.TryGetGlyph($4E2D, False, False, G) then
  begin
    Assert.IsTrue(Covered(G) > 0);
    Assert.IsTrue(G.Width > Src.CellWidth, 'a wide character is wider than one cell');
  end;
  Assert.IsFalse(Src.TryGetGlyph($0378, False, False, G), 'an unassigned code point has no glyph');
end;

procedure TTestFreeTypeGlyphs.MissingFontReportsAnError;
var
  Err: string;
  Src: IGlyphSource;
begin
  Src := CreateFreeTypeGlyphSourceFromFile('/no/such/font.ttf', 16, Err);
  Assert.IsNull(Src);
  Assert.IsTrue(Err <> '');
end;

procedure TTestFreeTypeGlyphs.RenderedGridShowsText;
var
  Src: IGlyphSource;
  R: TPixelGridRenderer;
  Grid: TTerminalGrid;
  X, Y, Ink: Integer;
begin
  Src := OpenSource(16);
  if Src = nil then
    Assert.Pass('FreeType or the font is not available');
  R := TPixelGridRenderer.Create(Src);
  try
    AllocTerminalGrid(Grid, 4, 1);
    ClearTerminalGrid(Grid, TAlphaColor($FFFFFFFF), TAlphaColor($FF000000));
    PutTerminalText(Grid, 0, 0, 'MTN2', TAlphaColor($FFFFFFFF), TAlphaColor($FF000000));
    R.Render(Grid);
    Ink := 0;
    for Y := 0 to R.Height - 1 do
      for X := 0 to R.Width - 1 do
        if R.PixelAt(X, Y) <> Cardinal($FF000000) then
          Inc(Ink);
    Assert.IsTrue(Ink > 40, 'the four letters leave marks on the background');
    Assert.AreEqual(Cardinal($FF000000), R.PixelAt(0, 0), 'the corner of the cell stays empty');
  finally
    R.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFreeTypeGlyphs);

end.
