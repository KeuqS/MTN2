unit uBoxGlyphs;

{ Box-drawing and block characters drawn as rectangles, so that lines and
  fills meet exactly at cell edges whatever the font does. The shapes are
  returned as rectangles inside a cell; the renderer fills them with the
  foreground color. Shades (light, medium, dark) come back as a coverage
  percentage instead. }

interface

type
  TCellRect = record
    X0, Y0, X1, Y1: Integer;  // half-open: [X0, X1) x [Y0, Y1)
  end;

  TCellShape = record
    Count: Integer;
    Rects: array[0..11] of TCellRect;
    /// <summary>0 for solid rectangles; 25, 50 or 75 for a shade, in which
    /// case Rects holds the whole cell.</summary>
    Shade: Integer;
  end;

/// <summary>True when ACodePoint is a box-drawing or block character that
/// BuildCellShape draws.</summary>
function IsShapeChar(ACodePoint: Integer): Boolean;

/// <summary>The rectangles of the character in a cell of AW by AH pixels.</summary>
function BuildCellShape(ACodePoint, AW, AH: Integer): TCellShape;

implementation

uses
  System.SysUtils, System.Math;

const
  // Arms of U+2500..U+257F as four digits per character: left, right, up,
  // down. 0 none, 1 light, 2 heavy, 3 double. Dashed lines count as solid
  // ones; the diagonals (U+2571..U+2573) have no arms and are left to the font.
  cArms: array[0..127] of string = (
    '1100', '2200', '0011', '0022', '1100', '2200', '0011', '0022',
    '1100', '2200', '0011', '0022', '0101', '0201', '0102', '0202',
    '1001', '2001', '1002', '2002', '0110', '0210', '0120', '0220',
    '1010', '2010', '1020', '2020', '0111', '0211', '0121', '0112',
    '0122', '0221', '0212', '0222', '1011', '2011', '1021', '1012',
    '1022', '2021', '2012', '2022', '1101', '2101', '1201', '2201',
    '1102', '2102', '1202', '2202', '1110', '2110', '1210', '2210',
    '1120', '2120', '1220', '2220', '1111', '2111', '1211', '2211',
    '1121', '1112', '1122', '2121', '1221', '2112', '1212', '2221',
    '2212', '2122', '1222', '2222', '1100', '2200', '0011', '0022',
    '3300', '0033', '0301', '0103', '0303', '3001', '1003', '3003',
    '0310', '0130', '0330', '3010', '1030', '3030', '0311', '0133',
    '0333', '3011', '1033', '3033', '3301', '1103', '3303', '3310',
    '1130', '3330', '3311', '1133', '3333', '0101', '1001', '1010',
    '0110', '0000', '0000', '0000', '1000', '0010', '0100', '0001',
    '2000', '0020', '0200', '0002', '1200', '0012', '2100', '0021');

  // Quadrant masks of U+2596..U+259F: 1 upper left, 2 upper right, 4 lower
  // left, 8 lower right.
  cQuadrants: array[0..9] of Integer = (4, 8, 1, 13, 9, 7, 11, 2, 6, 14);

function IsShapeChar(ACodePoint: Integer): Boolean;
begin
  if (ACodePoint >= $2500) and (ACodePoint <= $257F) then
    Result := cArms[ACodePoint - $2500] <> '0000'
  else
    Result := (ACodePoint >= $2580) and (ACodePoint <= $259F);
end;

procedure AddRect(var AShape: TCellShape; AX0, AY0, AX1, AY1: Integer);
begin
  if (AX1 <= AX0) or (AY1 <= AY0) or (AShape.Count > High(AShape.Rects)) then
    Exit;
  AShape.Rects[AShape.Count].X0 := AX0;
  AShape.Rects[AShape.Count].Y0 := AY0;
  AShape.Rects[AShape.Count].X1 := AX1;
  AShape.Rects[AShape.Count].Y1 := AY1;
  Inc(AShape.Count);
end;

function BuildBlock(ACodePoint, AW, AH: Integer): TCellShape;
var
  N, HalfW, HalfH: Integer;
begin
  Result := Default(TCellShape);
  HalfW := AW div 2;
  HalfH := AH div 2;
  case ACodePoint of
    $2580:
      AddRect(Result, 0, 0, AW, HalfH);
    $2581..$2588:
      begin
        N := ACodePoint - $2580;
        AddRect(Result, 0, AH - (AH * N + 4) div 8, AW, AH);
      end;
    $2589..$258F:
      begin
        N := 8 - (ACodePoint - $2588);
        AddRect(Result, 0, 0, Max(1, (AW * N + 4) div 8), AH);
      end;
    $2590:
      AddRect(Result, AW - HalfW, 0, AW, AH);
    $2591..$2593:
      begin
        Result.Shade := (ACodePoint - $2590) * 25;
        AddRect(Result, 0, 0, AW, AH);
      end;
    $2594:
      AddRect(Result, 0, 0, AW, Max(1, (AH + 4) div 8));
    $2595:
      AddRect(Result, AW - Max(1, (AW + 4) div 8), 0, AW, AH);
    $2596..$259F:
      begin
        N := cQuadrants[ACodePoint - $2596];
        if (N and 1) <> 0 then
          AddRect(Result, 0, 0, HalfW, HalfH);
        if (N and 2) <> 0 then
          AddRect(Result, HalfW, 0, AW, HalfH);
        if (N and 4) <> 0 then
          AddRect(Result, 0, HalfH, HalfW, AH);
        if (N and 8) <> 0 then
          AddRect(Result, HalfW, HalfH, AW, AH);
      end;
  end;
end;

type
  // One band of a line across the center: [Lo, Hi) relative to the center.
  TBand = record
    Lo, Hi: Integer;
  end;

function BandsOf(AStyle, AThick: Integer): TArray<TBand>;
begin
  case AStyle of
    1:
      begin
        SetLength(Result, 1);
        Result[0].Lo := -(AThick div 2);
        Result[0].Hi := Result[0].Lo + AThick;
      end;
    2:
      begin
        SetLength(Result, 1);
        Result[0].Lo := -AThick;
        Result[0].Hi := AThick;
      end;
    3:
      begin
        SetLength(Result, 2);
        Result[0].Lo := -AThick;
        Result[0].Hi := 0;
        Result[1].Lo := AThick;
        Result[1].Hi := 2 * AThick;
      end;
  else
    Result := nil;
  end;
end;

function HiOf(AStyle, AThick: Integer): Integer;
begin
  case AStyle of
    1: Result := -(AThick div 2) + AThick;
    2: Result := AThick;
  else
    Result := 2 * AThick;
  end;
end;

function LoOf(AStyle, AThick: Integer): Integer;
begin
  case AStyle of
    1: Result := -(AThick div 2);
    2, 3: Result := -AThick;
  else
    Result := 0;
  end;
end;

// Where a bar of an arm that comes from the left or top stops, relative to
// the center. ANear and AFar are the styles of the crossing lines on the
// side of the bar (left/top) and on the other side.
function ArmEnd(AStyle, ANear, AFar, AThick, ABar: Integer): Integer;
begin
  Result := 0;
  if AStyle <> 3 then
  begin
    if (ANear = 3) and (AFar = 3) then
      Result := 0
    else if (ANear = 3) or (AFar = 3) then
      Result := 2 * AThick
    else if (ANear <> 0) or (AFar <> 0) then
      Result := Max(IfThen(ANear <> 0, HiOf(ANear, AThick), -MaxInt),
        IfThen(AFar <> 0, HiOf(AFar, AThick), -MaxInt))
    else
      Result := HiOf(AStyle, AThick);
    Exit;
  end;
  if (ANear = 3) or (AFar = 3) then
  begin
    if ABar = 0 then
    begin
      if ANear <> 0 then
        Result := 0
      else if AFar <> 0 then
        Result := 2 * AThick;
    end
    else
    begin
      if AFar <> 0 then
        Result := 0
      else if ANear <> 0 then
        Result := 2 * AThick;
    end;
  end
  else if (ANear <> 0) or (AFar <> 0) then
    Result := Max(IfThen(ANear <> 0, HiOf(ANear, AThick), -MaxInt),
      IfThen(AFar <> 0, HiOf(AFar, AThick), -MaxInt));
end;

// Where a bar of an arm that comes from the right or bottom starts.
function ArmStart(AStyle, ANear, AFar, AThick, ABar: Integer): Integer;
begin
  Result := 0;
  if AStyle <> 3 then
  begin
    if (ANear = 3) and (AFar = 3) then
      Result := AThick
    else if (ANear = 3) or (AFar = 3) then
      Result := -AThick
    else if (ANear <> 0) or (AFar <> 0) then
      Result := Min(IfThen(ANear <> 0, LoOf(ANear, AThick), MaxInt),
        IfThen(AFar <> 0, LoOf(AFar, AThick), MaxInt))
    else
      Result := LoOf(AStyle, AThick);
    Exit;
  end;
  if (ANear = 3) or (AFar = 3) then
  begin
    if ABar = 0 then
    begin
      if ANear <> 0 then
        Result := AThick
      else if AFar <> 0 then
        Result := -AThick;
    end
    else
    begin
      if AFar <> 0 then
        Result := AThick
      else if ANear <> 0 then
        Result := -AThick;
    end;
  end
  else if (ANear <> 0) or (AFar <> 0) then
    Result := Min(IfThen(ANear <> 0, LoOf(ANear, AThick), MaxInt),
      IfThen(AFar <> 0, LoOf(AFar, AThick), MaxInt));
end;

// Adds the bars of one arm. AHoriz selects the axis: a horizontal arm runs
// along x and its bars are offset in y; a vertical arm is the same shape with
// the axes exchanged.
procedure AddArm(var AShape: TCellShape; AHoriz, AFromStart: Boolean; AStyle, ANear,
  AFar, AThick, AAlongCenter, AAcrossCenter, AAlongSize: Integer);
var
  Bands: TArray<TBand>;
  I, A0, A1: Integer;
begin
  Bands := BandsOf(AStyle, AThick);
  for I := 0 to High(Bands) do
  begin
    if AFromStart then
    begin
      A0 := 0;
      A1 := AAlongCenter + ArmEnd(AStyle, ANear, AFar, AThick, I);
    end
    else
    begin
      A0 := AAlongCenter + ArmStart(AStyle, ANear, AFar, AThick, I);
      A1 := AAlongSize;
    end;
    if AHoriz then
      AddRect(AShape, A0, AAcrossCenter + Bands[I].Lo, A1, AAcrossCenter + Bands[I].Hi)
    else
      AddRect(AShape, AAcrossCenter + Bands[I].Lo, A0, AAcrossCenter + Bands[I].Hi, A1);
  end;
end;

function BuildBox(ACodePoint, AW, AH: Integer): TCellShape;
var
  Spec: string;
  L, R, U, D, T, Cx, Cy: Integer;
begin
  Result := Default(TCellShape);
  Spec := cArms[ACodePoint - $2500];
  L := Ord(Spec[1]) - 48;
  R := Ord(Spec[2]) - 48;
  U := Ord(Spec[3]) - 48;
  D := Ord(Spec[4]) - 48;
  T := Max(1, (AW * 2 + 9) div 18);
  Cx := AW div 2;
  Cy := AH div 2;
  if L <> 0 then
    AddArm(Result, True, True, L, U, D, T, Cx, Cy, AW);
  if R <> 0 then
    AddArm(Result, True, False, R, U, D, T, Cx, Cy, AW);
  if U <> 0 then
    AddArm(Result, False, True, U, L, R, T, Cy, Cx, AH);
  if D <> 0 then
    AddArm(Result, False, False, D, L, R, T, Cy, Cx, AH);
end;

function BuildCellShape(ACodePoint, AW, AH: Integer): TCellShape;
begin
  if (ACodePoint >= $2500) and (ACodePoint <= $257F) then
    Result := BuildBox(ACodePoint, AW, AH)
  else
    Result := BuildBlock(ACodePoint, AW, AH);
end;

end.
