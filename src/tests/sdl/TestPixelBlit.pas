unit TestPixelBlit;

{ Fitting a picture into a block of cells and scaling it into a bitmap of
  32-bit pixels, and the PNG file written from such a bitmap. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestPixelBlit = class
  public
    [Test] procedure PictureIsFittedAndCentered;
    [Test] procedure NativeScaleStartsAtTheTopLeft;
    [Test] procedure NativeScaleShrinksWhenTooLarge;
    [Test] procedure UpscaleKeepsPixelColors;
    [Test] procedure DownscaleAveragesCoveredPixels;
    [Test] procedure ClipLimitsTheBlit;
    [Test] procedure TransparentPixelsShowWhatIsBelow;
    [Test] procedure PngHoldsTheRgbPixels;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Types, System.IOUtils, System.ZLib, uPixelBlit, uPngWriter;

type
  TPixels = array of Cardinal;

function Solid(AW, AH: Integer; AColor: Cardinal): TBytes;
var
  I: Integer;
begin
  SetLength(Result, AW * AH * 4);
  for I := 0 to AW * AH - 1 do
    PCardinal(@Result[I * 4])^ := AColor;
end;

function Canvas(AW, AH: Integer; AColor: Cardinal): TPixels;
var
  I: Integer;
begin
  SetLength(Result, AW * AH);
  for I := 0 to High(Result) do
    Result[I] := AColor;
end;

procedure TTestPixelBlit.PictureIsFittedAndCentered;
var
  R: TRect;
begin
  // A 200 x 100 picture in an 80 x 80 block keeps its proportions.
  R := FitPicture(200, 100, TRect.Create(10, 20, 90, 100), 0);
  Assert.AreEqual(80, R.Width);
  Assert.AreEqual(40, R.Height);
  Assert.AreEqual(10, R.Left);
  Assert.AreEqual(40, R.Top, 'centered vertically');
  // A small picture is enlarged to the block.
  R := FitPicture(10, 10, TRect.Create(0, 0, 50, 100), 0);
  Assert.AreEqual(50, R.Width);
  Assert.AreEqual(50, R.Height);
  Assert.AreEqual(25, R.Top);
  Assert.IsTrue(FitPicture(0, 10, TRect.Create(0, 0, 5, 5), 0).IsEmpty, 'no picture, no area');
end;

procedure TTestPixelBlit.NativeScaleStartsAtTheTopLeft;
var
  R: TRect;
begin
  R := FitPicture(40, 20, TRect.Create(8, 16, 208, 116), 2);
  Assert.AreEqual(8, R.Left);
  Assert.AreEqual(16, R.Top);
  Assert.AreEqual(80, R.Width);
  Assert.AreEqual(40, R.Height);
end;

procedure TTestPixelBlit.NativeScaleShrinksWhenTooLarge;
var
  R: TRect;
begin
  R := FitPicture(400, 200, TRect.Create(0, 0, 100, 100), 1);
  Assert.AreEqual(100, R.Width);
  Assert.AreEqual(50, R.Height);
  Assert.AreEqual(0, R.Left);
end;

procedure TTestPixelBlit.UpscaleKeepsPixelColors;
var
  Pic: TBytes;
  Dst: TPixels;
begin
  Pic := Solid(2, 2, $FF112233);
  PCardinal(@Pic[4])^ := $FF445566;
  Dst := Canvas(8, 8, $FF000000);
  BlitScaled(Pic, 2, 2, PByte(@Dst[0]), 32, 8, 8, TRect.Create(0, 0, 4, 4), TRect.Create(0, 0, 8, 8));
  Assert.AreEqual(Cardinal($FF112233), Dst[0]);
  Assert.AreEqual(Cardinal($FF112233), Dst[1 + 8], 'a 2 x 2 block per source pixel');
  Assert.AreEqual(Cardinal($FF445566), Dst[2], 'the second source pixel');
  Assert.AreEqual(Cardinal($FF000000), Dst[4], 'outside the picture');
  Assert.AreEqual(Cardinal($FF000000), Dst[4 * 8]);
end;

procedure TTestPixelBlit.DownscaleAveragesCoveredPixels;
var
  Pic: TBytes;
  Dst: TPixels;
  I: Integer;
begin
  Pic := Solid(4, 2, $FF000000);
  // Left half white, right half black: two columns of each.
  for I := 0 to 1 do
  begin
    PCardinal(@Pic[(0 + I * 4) * 4])^ := $FFFFFFFF;
    PCardinal(@Pic[(1 + I * 4) * 4])^ := $FFFFFFFF;
  end;
  Dst := Canvas(2, 1, $FF000000);
  BlitScaled(Pic, 4, 2, PByte(@Dst[0]), 8, 2, 1, TRect.Create(0, 0, 2, 1), TRect.Create(0, 0, 2, 1));
  Assert.AreEqual(Cardinal($FFFFFFFF), Dst[0]);
  Assert.AreEqual(Cardinal($FF000000), Dst[1]);
  Pic := Solid(2, 1, $FF000000);
  PCardinal(@Pic[0])^ := $FFFFFFFF;
  BlitScaled(Pic, 2, 1, PByte(@Dst[0]), 8, 2, 1, TRect.Create(0, 0, 1, 1), TRect.Create(0, 0, 1, 1));
  Assert.AreEqual(Cardinal($FF7F7F7F), Dst[0], 'two source pixels share one');
end;

procedure TTestPixelBlit.ClipLimitsTheBlit;
var
  Pic: TBytes;
  Dst: TPixels;
begin
  Pic := Solid(2, 2, $FFFFFFFF);
  Dst := Canvas(4, 4, $FF000000);
  BlitScaled(Pic, 2, 2, PByte(@Dst[0]), 16, 4, 4, TRect.Create(0, 0, 4, 4), TRect.Create(1, 1, 3, 2));
  Assert.AreEqual(Cardinal($FF000000), Dst[0]);
  Assert.AreEqual(Cardinal($FFFFFFFF), Dst[1 + 4]);
  Assert.AreEqual(Cardinal($FFFFFFFF), Dst[2 + 4]);
  Assert.AreEqual(Cardinal($FF000000), Dst[3 + 4], 'right of the clip');
  Assert.AreEqual(Cardinal($FF000000), Dst[1 + 8], 'below the clip');
end;

procedure TTestPixelBlit.TransparentPixelsShowWhatIsBelow;
var
  Pic: TBytes;
  Dst: TPixels;
begin
  Pic := Solid(2, 1, $00FFFFFF);
  PCardinal(@Pic[4])^ := $80FFFFFF;
  Dst := Canvas(2, 1, $FF000000);
  BlitScaled(Pic, 2, 1, PByte(@Dst[0]), 8, 2, 1, TRect.Create(0, 0, 2, 1), TRect.Create(0, 0, 2, 1));
  Assert.AreEqual(Cardinal($FF000000), Dst[0], 'fully transparent');
  Assert.AreEqual(Cardinal($FF808080), Dst[1], 'half transparent white over black');
end;

procedure TTestPixelBlit.PngHoldsTheRgbPixels;
var
  Pixels: TPixels;
  FileName: string;
  Bytes, Raw: TBytes;
  Signature: array[0..7] of Byte;
  Pos, Len: Integer;
  Kind: string;
  Out: Pointer;
  OutSize: Integer;
  Width, Height: Cardinal;

  function BE(AOffset: Integer): Cardinal;
  begin
    Result := (Cardinal(Bytes[AOffset]) shl 24) or (Cardinal(Bytes[AOffset + 1]) shl 16) or
      (Cardinal(Bytes[AOffset + 2]) shl 8) or Bytes[AOffset + 3];
  end;

begin
  SetLength(Pixels, 2 * 2);
  Pixels[0] := $FF112233;
  Pixels[1] := $FF445566;
  Pixels[2] := $FF778899;
  Pixels[3] := $FFAABBCC;
  FileName := TPath.Combine(TPath.GetTempPath, 'mtn2_png_' + IntToStr(Random(MaxInt)) + '.png');
  try
    SavePixelsAsPng(FileName, PByte(@Pixels[0]), 8, 2, 2);
    Bytes := TFile.ReadAllBytes(FileName);
  finally
    TFile.Delete(FileName);
  end;
  Move(Bytes[0], Signature[0], 8);
  Assert.AreEqual(137, Integer(Signature[0]));
  Assert.AreEqual(Integer(Ord('P')), Integer(Signature[1]));
  Pos := 8;
  Width := 0;
  Height := 0;
  Raw := nil;
  while Pos < Length(Bytes) do
  begin
    Len := Integer(BE(Pos));
    Kind := string(AnsiString(Chr(Bytes[Pos + 4]) + Chr(Bytes[Pos + 5]) + Chr(Bytes[Pos + 6]) +
      Chr(Bytes[Pos + 7])));
    if Kind = 'IHDR' then
    begin
      Width := BE(Pos + 8);
      Height := BE(Pos + 12);
    end
    else if Kind = 'IDAT' then
    begin
      ZDecompress(@Bytes[Pos + 8], Len, Out, OutSize);
      try
        SetLength(Raw, OutSize);
        Move(Out^, Raw[0], OutSize);
      finally
        FreeMem(Out);
      end;
    end;
    Inc(Pos, 12 + Len);
  end;
  Assert.AreEqual(Cardinal(2), Width);
  Assert.AreEqual(Cardinal(2), Height);
  Assert.AreEqual(14, Integer(Length(Raw)), 'two rows of a filter byte and three bytes per pixel');
  Assert.AreEqual(0, Integer(Raw[0]), 'no filter');
  Assert.AreEqual($11, Integer(Raw[1]), 'red first');
  Assert.AreEqual($22, Integer(Raw[2]));
  Assert.AreEqual($33, Integer(Raw[3]));
  Assert.AreEqual($CC, Integer(Raw[13]), 'blue of the last pixel');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPixelBlit);

end.
