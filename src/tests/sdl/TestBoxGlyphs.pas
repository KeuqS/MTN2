unit TestBoxGlyphs;

{ Box-drawing and block characters are drawn as rectangles inside the cell,
  so lines join at cell edges whatever the font does. The expectations are
  the pixels of a 9 x 19 cell, where a light line is one pixel wide and
  crosses the cell at column 4 and row 9. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestBoxGlyphs = class
  public
    [Test] procedure LightHorizontalLineCrossesTheWholeCell;
    [Test] procedure LightVerticalLineCrossesTheWholeCell;
    [Test] procedure LightCornerJoinsItsArms;
    [Test] procedure DoubleHorizontalLineIsTwoBars;
    [Test] procedure DoubleCornerKeepsTheInnerLineApart;
    [Test] procedure DoubleTeeBreaksTheInnerBarOnTheBranchSide;
    [Test] procedure CrossOfDoubleLinesLeavesTheCenterOpen;
    [Test] procedure MixedCornerJoinsSingleLineToDoubleBars;
    [Test] procedure BlockElementsCoverTheirPartOfTheCell;
    [Test] procedure ShadesAreReportedAsCoverage;
    [Test] procedure OnlyDrawnCharactersAreShapes;
  end;

implementation

uses
  System.SysUtils, uBoxGlyphs;

const
  cW = 9;
  cH = 19;

type
  TBitmap = array[0..cH - 1, 0..cW - 1] of Boolean;

function Fill(ACodePoint: Integer): TBitmap;
var
  Shape: TCellShape;
  I, X, Y: Integer;
begin
  Result := Default(TBitmap);
  Shape := BuildCellShape(ACodePoint, cW, cH);
  for I := 0 to Shape.Count - 1 do
    for Y := Shape.Rects[I].Y0 to Shape.Rects[I].Y1 - 1 do
      for X := Shape.Rects[I].X0 to Shape.Rects[I].X1 - 1 do
        Result[Y, X] := True;
end;

function IfThen(AValue: Boolean; const ATrue, AFalse: string): string;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function RowText(const ABitmap: TBitmap; AY: Integer): string;
var
  X: Integer;
begin
  Result := '';
  for X := 0 to cW - 1 do
    Result := Result + IfThen(ABitmap[AY, X], '#', '.');
end;

function Count(const ABitmap: TBitmap): Integer;
var
  X, Y: Integer;
begin
  Result := 0;
  for Y := 0 to cH - 1 do
    for X := 0 to cW - 1 do
      if ABitmap[Y, X] then
        Inc(Result);
end;

procedure TTestBoxGlyphs.LightHorizontalLineCrossesTheWholeCell;
var
  B: TBitmap;
  Y: Integer;
begin
  B := Fill($2500);
  Assert.AreEqual('#########', RowText(B, 9));
  Assert.AreEqual(cW, Count(B), 'nothing but the one row');
  for Y := 0 to cH - 1 do
    if Y <> 9 then
      Assert.AreEqual('.........', RowText(B, Y));
end;

procedure TTestBoxGlyphs.LightVerticalLineCrossesTheWholeCell;
var
  B: TBitmap;
  Y: Integer;
begin
  B := Fill($2502);
  for Y := 0 to cH - 1 do
    Assert.AreEqual('....#....', RowText(B, Y));
end;

procedure TTestBoxGlyphs.LightCornerJoinsItsArms;
var
  B: TBitmap;
begin
  // The top left corner: the line goes right and down from the center.
  B := Fill($250C);
  Assert.AreEqual('.........', RowText(B, 8));
  Assert.AreEqual('....#####', RowText(B, 9));
  Assert.AreEqual('....#....', RowText(B, 10));
  Assert.AreEqual('....#....', RowText(B, 18));
end;

procedure TTestBoxGlyphs.DoubleHorizontalLineIsTwoBars;
var
  B: TBitmap;
begin
  B := Fill($2550);
  Assert.AreEqual('#########', RowText(B, 8));
  Assert.AreEqual('.........', RowText(B, 9));
  Assert.AreEqual('#########', RowText(B, 10));
  Assert.AreEqual(2 * cW, Count(B));
end;

procedure TTestBoxGlyphs.DoubleCornerKeepsTheInnerLineApart;
var
  B: TBitmap;
begin
  // The top left double corner: the outer line turns at column 3 and row 8,
  // the inner line at column 5 and row 10, with the gap between them open.
  B := Fill($2554);
  Assert.AreEqual('.........', RowText(B, 7));
  Assert.AreEqual('...######', RowText(B, 8));
  Assert.AreEqual('...#.....', RowText(B, 9));
  Assert.AreEqual('...#.####', RowText(B, 10));
  Assert.AreEqual('...#.#...', RowText(B, 11));
  Assert.AreEqual('...#.#...', RowText(B, 18));
end;

procedure TTestBoxGlyphs.DoubleTeeBreaksTheInnerBarOnTheBranchSide;
var
  B: TBitmap;
begin
  // Left, right and down: the upper bar runs through, the lower one stops
  // short of the branch on each side and the branch has its two lines.
  B := Fill($2566);
  Assert.AreEqual('#########', RowText(B, 8));
  Assert.AreEqual('.........', RowText(B, 9));
  Assert.AreEqual('####.####', RowText(B, 10));
  Assert.AreEqual('...#.#...', RowText(B, 11));
  Assert.AreEqual('...#.#...', RowText(B, 18));
  Assert.AreEqual('.........', RowText(B, 7));
end;

procedure TTestBoxGlyphs.CrossOfDoubleLinesLeavesTheCenterOpen;
var
  B: TBitmap;
begin
  B := Fill($256C);
  Assert.AreEqual('...#.#...', RowText(B, 0));
  Assert.AreEqual('####.####', RowText(B, 8));
  Assert.AreEqual('.........', RowText(B, 9));
  Assert.AreEqual('####.####', RowText(B, 10));
  Assert.AreEqual('...#.#...', RowText(B, 18));
end;

procedure TTestBoxGlyphs.MixedCornerJoinsSingleLineToDoubleBars;
var
  B: TBitmap;
begin
  // Double to the right, single down: the single line starts at the upper
  // bar and the bars start at the single line.
  B := Fill($2552);
  Assert.AreEqual('.........', RowText(B, 7));
  Assert.AreEqual('....#####', RowText(B, 8));
  Assert.AreEqual('....#....', RowText(B, 9));
  Assert.AreEqual('....#####', RowText(B, 10));
  Assert.AreEqual('....#....', RowText(B, 18));
end;

procedure TTestBoxGlyphs.BlockElementsCoverTheirPartOfTheCell;
var
  B: TBitmap;
begin
  B := Fill($2588);
  Assert.AreEqual(cW * cH, Count(B), 'full block');
  B := Fill($2580);
  Assert.AreEqual(cW * (cH div 2), Count(B), 'upper half');
  Assert.AreEqual('#########', RowText(B, 0));
  Assert.AreEqual('.........', RowText(B, cH div 2));
  B := Fill($2584);
  Assert.AreEqual('.........', RowText(B, 0));
  Assert.AreEqual('#########', RowText(B, cH - 1));
  B := Fill($258C);
  Assert.AreEqual('#####....', RowText(B, 5), 'left half');
  B := Fill($2597);
  Assert.AreEqual('.........', RowText(B, 0));
  Assert.AreEqual('....#####', RowText(B, cH - 1), 'lower right quadrant');
end;

procedure TTestBoxGlyphs.ShadesAreReportedAsCoverage;
begin
  Assert.AreEqual(25, BuildCellShape($2591, cW, cH).Shade);
  Assert.AreEqual(50, BuildCellShape($2592, cW, cH).Shade);
  Assert.AreEqual(75, BuildCellShape($2593, cW, cH).Shade);
  Assert.AreEqual(0, BuildCellShape($2588, cW, cH).Shade);
end;

procedure TTestBoxGlyphs.OnlyDrawnCharactersAreShapes;
begin
  Assert.IsTrue(IsShapeChar($2500));
  Assert.IsTrue(IsShapeChar($256C));
  Assert.IsTrue(IsShapeChar($2588));
  Assert.IsFalse(IsShapeChar(Ord('A')));
  Assert.IsFalse(IsShapeChar($2571), 'diagonals are left to the font');
  Assert.IsFalse(IsShapeChar($25B2), 'triangles are left to the font');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestBoxGlyphs);

end.
