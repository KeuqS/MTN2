unit TestOverlayModel;

{ The picture preview of the SDL host: a request is decoded once, shown while
  a window keeps asking for it, dropped when the window goes away, and laid
  over the grid as scaled pixels. The decoder is a stand-in that returns a
  fixed picture without a worker thread. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestOverlayModel = class
  strict private
    FFile: string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure RequestIsDecodedOnTheNextFrame;
    [Test] procedure PictureIsDecodedOnlyOnce;
    [Test] procedure PreviewStaysUntilCleared;
    [Test] procedure MissingFileShowsAHint;
    [Test] procedure UndecodableFileShowsAHint;
    [Test] procedure PixelsFromAWindowAreShownAtOnce;
    [Test] procedure CellMetricsGiveTheNativeSize;
    [Test] procedure FramePicturesAreFittedIntoTheirCells;
    [Test] procedure BlitDrawsOnlyInsideTheDirtyArea;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Types, System.IOUtils, System.UITypes,
  uTerminalTypes, uThemeTypes, uOverlayModel;

const
  cWhite = TAlphaColor($FFFFFFFF);
  cBlack = TAlphaColor($FF000000);

var
  GDecodeCalls: Integer;

function SolidDecoder(const APath: string; out AWidth, AHeight: Integer;
  out APixels: TBytes): TPictureState;
var
  I: Integer;
begin
  Inc(GDecodeCalls);
  if APath.EndsWith('.bad') then
  begin
    AWidth := 0;
    AHeight := 0;
    APixels := nil;
    Exit(psFailed);
  end;
  AWidth := 4;
  AHeight := 2;
  SetLength(APixels, 4 * 2 * 4);
  for I := 0 to 7 do
    PCardinal(@APixels[I * 4])^ := $FF2040C0;
  Result := psReady;
end;

function NewGrid(ACols, ARows: Integer): TTerminalGrid;
begin
  AllocTerminalGrid(Result, ACols, ARows);
  ClearTerminalGrid(Result, cWhite, cBlack);
end;

function Area(ALeft, ATop, ARight, ABottom: Integer): TRectI;
begin
  Result := TRectI.Make(ALeft, ATop, ARight, ABottom);
end;

function GridText(const AGrid: TTerminalGrid): string;
var
  Y, X: Integer;
begin
  Result := '';
  for Y := 0 to High(AGrid) do
    for X := 0 to High(AGrid[Y]) do
      Result := Result + AGrid[Y][X].CharValue;
end;

procedure TTestOverlayModel.Setup;
begin
  GDecodeCalls := 0;
  FFile := TPath.Combine(TPath.GetTempPath, 'mtn2_overlay_' + IntToStr(Random(MaxInt)) + '.png');
  TFile.WriteAllText(FFile, 'x');
end;

procedure TTestOverlayModel.TearDown;
begin
  if TFile.Exists(FFile) then
    TFile.Delete(FFile);
end;

procedure TTestOverlayModel.RequestIsDecodedOnTheNextFrame;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Grid := NewGrid(20, 10);
    M.Request(FFile, Area(2, 2, 9, 5), Area(2, 2, 9, 5), 0);
    Assert.IsTrue(M.Active);
    Assert.AreEqual(FFile, M.CurrentUri);
    M.PaintCells(Grid);
    Assert.IsFalse(M.Frame.Visible, 'the picture is being decoded');
    M.PaintCells(Grid);
    Assert.IsTrue(M.Frame.Visible, 'the picture is ready for the host window');
    Assert.AreEqual(4, M.Frame.Width);
    Assert.AreEqual(2, M.Frame.Height);
    Assert.AreEqual(2, M.Frame.Bounds.Left);
    Assert.AreEqual(32, Integer(Length(M.Frame.Pixels)));
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.PictureIsDecodedOnlyOnce;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
  Serial: Cardinal;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Grid := NewGrid(20, 10);
    M.Request(FFile, Area(0, 0, 9, 5), Area(0, 0, 9, 5), 0);
    M.PaintCells(Grid);
    M.PaintCells(Grid);
    Serial := M.Frame.Serial;
    M.UpdateBounds(Area(1, 1, 9, 5), Area(1, 1, 9, 5), 0);
    M.PaintCells(Grid);
    Assert.AreEqual(1, GDecodeCalls, 'a moved preview keeps its picture');
    Assert.AreEqual(Integer(Serial), Integer(M.Frame.Serial), 'and the pixels are the same');
    Assert.AreEqual(1, M.Frame.Bounds.Left);
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.PreviewStaysUntilCleared;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Grid := NewGrid(20, 10);
    M.Request(FFile, Area(0, 0, 9, 5), Area(0, 0, 9, 5), 0);
    M.PaintCells(Grid);
    M.PaintCells(Grid);
    Assert.IsTrue(M.Frame.Visible);
    M.PaintCells(Grid);
    Assert.IsTrue(M.Frame.Visible, 'frames in which the window does not draw keep the picture');
    M.Clear;
    Assert.IsFalse(M.Active);
    M.PaintCells(Grid);
    Assert.IsFalse(M.Frame.Visible, 'a cleared preview is gone');
    Assert.AreEqual('', M.CurrentUri);
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.MissingFileShowsAHint;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Grid := NewGrid(30, 10);
    M.Request(TPath.Combine(TPath.GetTempPath, 'mtn2_no_such_picture.png'), Area(0, 0, 29, 5),
      Area(0, 0, 29, 5), 0);
    M.PaintCells(Grid);
    M.PaintCells(Grid);
    Assert.IsTrue(GridText(Grid).Contains('(no preview)'));
    Assert.IsFalse(M.Frame.Visible);
    Assert.AreEqual(0, GDecodeCalls, 'a file that is not there is not decoded');
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.UndecodableFileShowsAHint;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
  Bad: string;
begin
  Bad := FFile + '.bad';
  TFile.WriteAllText(Bad, 'x');
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Grid := NewGrid(30, 10);
    try
      M.Request(Bad, Area(0, 0, 29, 5), Area(0, 0, 29, 5), 0);
      M.PaintCells(Grid);
      M.PaintCells(Grid);
      Assert.IsTrue(GridText(Grid).Contains('(no preview)'));
    finally
      TFile.Delete(Bad);
    end;
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.PixelsFromAWindowAreShownAtOnce;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
  Pixels: array[0..3] of Cardinal;
  I: Integer;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    for I := 0 to 3 do
      Pixels[I] := $FFFF0000;
    Grid := NewGrid(20, 10);
    M.SetPixels('video://frame', 2, 2, PByte(@Pixels[0]), Area(0, 0, 9, 4), Area(0, 0, 9, 4));
    M.PaintCells(Grid);
    Assert.IsTrue(M.Frame.Visible);
    Assert.AreEqual(2, M.Frame.Width);
    Assert.AreEqual(Cardinal($FFFF0000), PCardinal(@M.Frame.Pixels[0])^);
    Assert.AreEqual(0, GDecodeCalls, 'nothing to decode');
    Pixels[0] := $FF00FF00;
    M.SetPixels('video://frame', 2, 2, PByte(@Pixels[0]), Area(0, 0, 9, 4), Area(0, 0, 9, 4));
    M.PaintCells(Grid);
    Assert.AreEqual(Cardinal($FF00FF00), PCardinal(@M.Frame.Pixels[0])^, 'the next frame replaces the pixels');
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.CellMetricsGiveTheNativeSize;
var
  M: TOverlayModel;
  Cols, Rows: Integer;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Assert.IsFalse(M.NativeCellSize(100, 100, Cols, Rows), 'unknown before the host reports');
    Assert.AreEqual(Single(2.0), M.CellAspect);
    Assert.IsTrue(M.SetCellMetrics(8, 16, 1));
    Assert.IsFalse(M.SetCellMetrics(8, 16, 1), 'no change');
    Assert.IsTrue(M.NativeCellSize(100, 100, Cols, Rows));
    Assert.AreEqual(13, Cols);
    Assert.AreEqual(7, Rows);
    Assert.AreEqual(Single(2.0), M.CellAspect);
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.FramePicturesAreFittedIntoTheirCells;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
  Fitted, Clip: TRect;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Grid := NewGrid(30, 12);
    // A 4 x 2 picture in a block of 10 x 4 cells of 8 x 16 pixels: 80 x 64.
    M.Request(FFile, Area(5, 2, 14, 5), Area(5, 2, 14, 5), 0);
    M.PaintCells(Grid);
    M.PaintCells(Grid);
    Assert.IsTrue(OverlayFrameRects(M.Frame, 8, 16, 240, 192, Fitted, Clip));
    Assert.AreEqual(40, Fitted.Left);
    Assert.AreEqual(44, Fitted.Top, 'centered in the block that starts at pixel row 32');
    Assert.AreEqual(80, Fitted.Width, 'as wide as the block');
    Assert.AreEqual(40, Fitted.Height, 'in proportion 2 : 1');
    Assert.AreEqual(40, Clip.Left);
    Assert.AreEqual(120, Clip.Right);
  finally
    M.Free;
  end;
end;

procedure TTestOverlayModel.BlitDrawsOnlyInsideTheDirtyArea;
var
  M: TOverlayModel;
  Grid: TTerminalGrid;
  Bitmap: TArray<Cardinal>;
  I: Integer;
begin
  M := TOverlayModel.Create(SolidDecoder, False);
  try
    Grid := NewGrid(10, 4);
    M.Request(FFile, Area(0, 0, 9, 3), Area(0, 0, 9, 3), 0);
    M.PaintCells(Grid);
    M.PaintCells(Grid);
    SetLength(Bitmap, 80 * 64);
    for I := 0 to High(Bitmap) do
      Bitmap[I] := $FF000000;
    BlitOverlayFrame(M.Frame, 8, 16, PByte(@Bitmap[0]), 80 * 4, 80, 64, TRect.Create(0, 0, 40, 64));
    Assert.AreEqual(Cardinal($FF2040C0), Bitmap[20 * 80 + 10], 'inside the dirty area and the picture');
    Assert.AreEqual(Cardinal($FF000000), Bitmap[20 * 80 + 50], 'outside the dirty area');
  finally
    M.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestOverlayModel);

end.
