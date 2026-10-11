unit uPixelGrid;

{ Draws a character grid into a memory bitmap of 32-bit pixels (blue, green,
  red, alpha in memory order). Only the cells that differ from the previous
  frame are painted, and the union of what changed is kept so a host can
  upload just that part. Glyphs come from an IGlyphSource; box-drawing and
  block characters are drawn as rectangles (uBoxGlyphs). The renderer knows
  nothing about windows: a graphical host copies Pixels to its window, a test
  reads them. }

interface

uses
  System.Types, System.UITypes, uTerminalTypes, uGlyphSource;

type
  TPixelGridRenderer = class
  strict private
    FGlyphs: IGlyphSource;
    FCellW, FCellH: Integer;
    FCols, FRows: Integer;
    FWidth, FHeight: Integer;
    FPixels: TArray<Cardinal>;
    FPrev: TTerminalGrid;
    FDirty: TRect;
    FBlinkOn: Boolean;
    FBlinkWas: Boolean;
    FForceAll: Boolean;
    procedure Reallocate(ACols, ARows: Integer);
    procedure MarkDirty(const ARect: TRect);
    procedure FillRect(const ARect: TRect; AColor: Cardinal);
    procedure BlendRect(const ARect: TRect; AColor: Cardinal; APercent: Integer);
    procedure DrawGlyph(const AGlyph: TGlyphBitmap; AOriginX, AOriginY: Integer;
      const AClip: TRect; AColor: Cardinal);
    procedure DrawShape(AX, AY, AW, AH: Integer; const AChar: Integer;
      AColor: Cardinal);
    procedure PaintCell(const AGrid: TTerminalGrid; AX, AY: Integer);
    function CellUnitDiffers(const AGrid: TTerminalGrid; AX, AY: Integer): Boolean;
    function GetPixels: PByte;
  public
    constructor Create(const AGlyphs: IGlyphSource);
    /// <summary>Swaps the font: the cell size follows it and the whole grid is
    /// painted again by the next Render.</summary>
    procedure SetGlyphSource(const AGlyphs: IGlyphSource);
    /// <summary>Paints the cells that changed; True when any pixel changed.</summary>
    function Render(const AGrid: TTerminalGrid; ABlinkOn: Boolean = True): Boolean;
    /// <summary>Paints everything again by the next Render.</summary>
    procedure Invalidate;
    /// <summary>The pixels changed since the last ClearDirty, empty when none.</summary>
    function DirtyRect: TRect;
    procedure ClearDirty;
    /// <summary>The cell under a pixel position, clamped to the grid.</summary>
    procedure CellAt(AX, AY: Integer; out ACol, ARow: Integer);
    /// <summary>Bitmap size that holds a grid of the given size.</summary>
    function PixelSizeOf(ACols, ARows: Integer): TSize;
    /// <summary>Grid size that fits in a bitmap of the given size, at least 1x1.</summary>
    function GridSizeOf(AWidth, AHeight: Integer): TSize;
    /// <summary>Color of the pixel (top left is 0, 0) as $AARRGGBB.</summary>
    function PixelAt(AX, AY: Integer): Cardinal;
    property Pixels: PByte read GetPixels;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    /// <summary>Bytes per row.</summary>
    function Stride: Integer;
    property CellWidth: Integer read FCellW;
    property CellHeight: Integer read FCellH;
    property Cols: Integer read FCols;
    property Rows: Integer read FRows;
  end;

implementation

uses
  System.SysUtils, System.Math, uBoxGlyphs;

function Opaque(AColor: TAlphaColor): Cardinal; inline;
begin
  Result := Cardinal(AColor) or $FF000000;
end;

constructor TPixelGridRenderer.Create(const AGlyphs: IGlyphSource);
begin
  inherited Create;
  FBlinkOn := True;
  SetGlyphSource(AGlyphs);
end;

procedure TPixelGridRenderer.SetGlyphSource(const AGlyphs: IGlyphSource);
begin
  FGlyphs := AGlyphs;
  FCellW := Max(1, AGlyphs.CellWidth);
  FCellH := Max(1, AGlyphs.CellHeight);
  FPrev := nil;
  FForceAll := True;
  Reallocate(0, 0);
end;

procedure TPixelGridRenderer.Reallocate(ACols, ARows: Integer);
begin
  FCols := ACols;
  FRows := ARows;
  FWidth := ACols * FCellW;
  FHeight := ARows * FCellH;
  SetLength(FPixels, FWidth * FHeight);
  FDirty := TRect.Create(0, 0, FWidth, FHeight);
end;

function TPixelGridRenderer.GetPixels: PByte;
begin
  if Length(FPixels) = 0 then
    Exit(nil);
  Result := PByte(@FPixels[0]);
end;

function TPixelGridRenderer.Stride: Integer;
begin
  Result := FWidth * 4;
end;

function TPixelGridRenderer.PixelAt(AX, AY: Integer): Cardinal;
begin
  Result := FPixels[AY * FWidth + AX];
end;

function TPixelGridRenderer.PixelSizeOf(ACols, ARows: Integer): TSize;
begin
  Result.cx := ACols * FCellW;
  Result.cy := ARows * FCellH;
end;

function TPixelGridRenderer.GridSizeOf(AWidth, AHeight: Integer): TSize;
begin
  Result.cx := Max(1, AWidth div FCellW);
  Result.cy := Max(1, AHeight div FCellH);
end;

procedure TPixelGridRenderer.CellAt(AX, AY: Integer; out ACol, ARow: Integer);
begin
  ACol := EnsureRange(AX div FCellW, 0, Max(0, FCols - 1));
  ARow := EnsureRange(AY div FCellH, 0, Max(0, FRows - 1));
  if AX < 0 then
    ACol := 0;
  if AY < 0 then
    ARow := 0;
end;

procedure TPixelGridRenderer.Invalidate;
begin
  FForceAll := True;
end;

function TPixelGridRenderer.DirtyRect: TRect;
begin
  Result := FDirty;
end;

procedure TPixelGridRenderer.ClearDirty;
begin
  FDirty := TRect.Empty;
end;

procedure TPixelGridRenderer.MarkDirty(const ARect: TRect);
begin
  if FDirty.IsEmpty then
    FDirty := ARect
  else
    FDirty.Union(ARect);
end;

procedure TPixelGridRenderer.FillRect(const ARect: TRect; AColor: Cardinal);
var
  Y, X: Integer;
  R: TRect;
begin
  R := TRect.Intersect(ARect, TRect.Create(0, 0, FWidth, FHeight));
  for Y := R.Top to R.Bottom - 1 do
    for X := R.Left to R.Right - 1 do
      FPixels[Y * FWidth + X] := AColor;
end;

// Mixes the color over what is there: APercent of AColor, the rest of the pixel that is there.
procedure TPixelGridRenderer.BlendRect(const ARect: TRect; AColor: Cardinal;
  APercent: Integer);
var
  Y, X, Idx: Integer;
  R: TRect;
  Old: Cardinal;

  function Mix(AOld, ANew: Cardinal; AShift: Integer): Cardinal;
  begin
    Result := (((AOld shr AShift) and $FF) * Cardinal(100 - APercent) +
      ((ANew shr AShift) and $FF) * Cardinal(APercent)) div 100;
  end;

begin
  R := TRect.Intersect(ARect, TRect.Create(0, 0, FWidth, FHeight));
  for Y := R.Top to R.Bottom - 1 do
    for X := R.Left to R.Right - 1 do
    begin
      Idx := Y * FWidth + X;
      Old := FPixels[Idx];
      FPixels[Idx] := $FF000000 or (Mix(Old, AColor, 16) shl 16) or
        (Mix(Old, AColor, 8) shl 8) or Mix(Old, AColor, 0);
    end;
end;

procedure TPixelGridRenderer.DrawGlyph(const AGlyph: TGlyphBitmap; AOriginX,
  AOriginY: Integer; const AClip: TRect; AColor: Cardinal);
var
  GX, GY, PX, PY, Idx: Integer;
  A, Inv: Cardinal;
  Old: Cardinal;
  Fr, Fg, Fb: Cardinal;
begin
  Fr := (AColor shr 16) and $FF;
  Fg := (AColor shr 8) and $FF;
  Fb := AColor and $FF;
  for GY := 0 to AGlyph.Height - 1 do
  begin
    PY := AOriginY + GY;
    if (PY < AClip.Top) or (PY >= AClip.Bottom) then
      Continue;
    for GX := 0 to AGlyph.Width - 1 do
    begin
      PX := AOriginX + GX;
      if (PX < AClip.Left) or (PX >= AClip.Right) then
        Continue;
      A := AGlyph.Alpha[GY * AGlyph.Width + GX];
      if A = 0 then
        Continue;
      Idx := PY * FWidth + PX;
      if A = 255 then
      begin
        FPixels[Idx] := AColor;
        Continue;
      end;
      Inv := 255 - A;
      Old := FPixels[Idx];
      FPixels[Idx] := $FF000000 or
        ((((Old shr 16) and $FF) * Inv + Fr * A + 127) div 255) shl 16 or
        ((((Old shr 8) and $FF) * Inv + Fg * A + 127) div 255) shl 8 or
        (((Old and $FF) * Inv + Fb * A + 127) div 255);
    end;
  end;
end;

procedure TPixelGridRenderer.DrawShape(AX, AY, AW, AH: Integer; const AChar: Integer;
  AColor: Cardinal);
var
  Shape: TCellShape;
  I: Integer;
  R: TRect;
begin
  Shape := BuildCellShape(AChar, AW, AH);
  for I := 0 to Shape.Count - 1 do
  begin
    R := TRect.Create(AX + Shape.Rects[I].X0, AY + Shape.Rects[I].Y0,
      AX + Shape.Rects[I].X1, AY + Shape.Rects[I].Y1);
    if Shape.Shade > 0 then
      BlendRect(R, AColor, Shape.Shade)
    else
      FillRect(R, AColor);
  end;
end;

procedure TPixelGridRenderer.PaintCell(const AGrid: TTerminalGrid; AX, AY: Integer);
var
  Cell: TCharCell;
  Fg, Bg: Cardinal;
  Cells, PX, PY, W, Code, Bar: Integer;
  Cl: TRect;
  Glyph: TGlyphBitmap;
begin
  Cell := AGrid[AY][AX];
  Cells := 1;
  if (ccaWide in Cell.Attributes) and (AX + 1 < FCols) then
    Cells := 2;
  PX := AX * FCellW;
  PY := AY * FCellH;
  W := Cells * FCellW;
  Cl := TRect.Create(PX, PY, PX + W, PY + FCellH);
  Fg := Opaque(Cell.FgColor);
  Bg := Opaque(Cell.BgColor);
  if ccaReverse in Cell.Attributes then
  begin
    Fg := Opaque(Cell.BgColor);
    Bg := Opaque(Cell.FgColor);
  end;
  if (ccaBlink in Cell.Attributes) and not FBlinkOn then
    Fg := Bg;
  FillRect(Cl, Bg);
  Code := Ord(Cell.CharValue);
  if (Code > 32) and (Fg <> Bg) and not ((Code >= $D800) and (Code <= $DFFF)) then
  begin
    if IsShapeChar(Code) then
      DrawShape(PX, PY, W, FCellH, Code, Fg)
    else if FGlyphs.TryGetGlyph(Code, ccaBold in Cell.Attributes,
         ccaItalic in Cell.Attributes, Glyph) then
      DrawGlyph(Glyph, PX + Glyph.Left, PY + FGlyphs.Baseline - Glyph.Top, Cl, Fg);
  end;
  Bar := Max(1, FCellH div 16);
  if ccaUnderline in Cell.Attributes then
    FillRect(TRect.Create(PX, Min(PY + FGlyphs.Baseline + 1, PY + FCellH - Bar),
      PX + W, Min(PY + FGlyphs.Baseline + 1, PY + FCellH - Bar) + Bar), Fg);
  if ccaStrike in Cell.Attributes then
    FillRect(TRect.Create(PX, PY + (FGlyphs.Baseline * 2) div 3,
      PX + W, PY + (FGlyphs.Baseline * 2) div 3 + Bar), Fg);
  if ccaInsertCaret in Cell.Attributes then
    FillRect(TRect.Create(PX, PY, PX + Min(2, FCellW), PY + FCellH),
      Opaque(InsertCaretColor(Cell.BgColor)));
  MarkDirty(Cl);
end;

// A wide character and its filler cell are repainted together.
function TPixelGridRenderer.CellUnitDiffers(const AGrid: TTerminalGrid;
  AX, AY: Integer): Boolean;
var
  Cell: TCharCell;
begin
  Cell := AGrid[AY][AX];
  Result := not SameCharCell(Cell, FPrev[AY][AX]);
  if Result then
    Exit;
  if (ccaBlink in Cell.Attributes) and (FBlinkOn <> FBlinkWas) then
    Exit(True);
  if (ccaWide in Cell.Attributes) and (AX + 1 < FCols) then
    Result := not SameCharCell(AGrid[AY][AX + 1], FPrev[AY][AX + 1])
  else if (ccaWideTail in Cell.Attributes) and (AX > 0) then
    Result := not SameCharCell(AGrid[AY][AX - 1], FPrev[AY][AX - 1]);
end;

function TPixelGridRenderer.Render(const AGrid: TTerminalGrid; ABlinkOn: Boolean): Boolean;
var
  Rows, Cols, X, Y: Integer;
  Full: Boolean;
begin
  Rows := Length(AGrid);
  if Rows = 0 then
    Exit(False);
  Cols := Length(AGrid[0]);
  Full := FForceAll or (Cols <> FCols) or (Rows <> FRows) or (Length(FPrev) <> Rows);
  FBlinkWas := FBlinkOn;
  FBlinkOn := ABlinkOn;
  if Full then
  begin
    if (Cols <> FCols) or (Rows <> FRows) then
      Reallocate(Cols, Rows);
    SetLength(FPrev, Rows);
    for Y := 0 to Rows - 1 do
      SetLength(FPrev[Y], Cols);
    FillRect(TRect.Create(0, 0, FWidth, FHeight), $FF000000);
    MarkDirty(TRect.Create(0, 0, FWidth, FHeight));
  end;
  Result := Full;
  for Y := 0 to Rows - 1 do
    for X := 0 to Cols - 1 do
    begin
      if not Full and not CellUnitDiffers(AGrid, X, Y) then
        Continue;
      Result := True;
      // The filler cell of a wide character is painted with its first cell.
      if not (ccaWideTail in AGrid[Y][X].Attributes) or (X = 0) then
        PaintCell(AGrid, X, Y);
    end;
  for Y := 0 to Rows - 1 do
    Move(AGrid[Y][0], FPrev[Y][0], Cols * SizeOf(TCharCell));
  FForceAll := False;
end;

end.
