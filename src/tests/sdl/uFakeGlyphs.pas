unit uFakeGlyphs;

{ A glyph source for tests: cells of 8 x 16 pixels with the baseline at row
  12. 'A' is a solid 6 x 10 box, 'B' the same box at half coverage, 'I' a
  box that is wider than the cell. The bold style of a character is one pixel
  wider. Every other character has no glyph. }

interface

uses
  uGlyphSource;

type
  TFakeGlyphs = class(TInterfacedObject, IGlyphSource)
  strict private
    FRequests: Integer;
  public
    function CellWidth: Integer;
    function CellHeight: Integer;
    function Baseline: Integer;
    function TryGetGlyph(ACodePoint: Integer; ABold, AItalic: Boolean;
      out AGlyph: TGlyphBitmap): Boolean;
    property Requests: Integer read FRequests;
  end;

const
  cFakeCellW = 8;
  cFakeCellH = 16;
  cFakeBaseline = 12;

implementation

function TFakeGlyphs.CellWidth: Integer;
begin
  Result := cFakeCellW;
end;

function TFakeGlyphs.CellHeight: Integer;
begin
  Result := cFakeCellH;
end;

function TFakeGlyphs.Baseline: Integer;
begin
  Result := cFakeBaseline;
end;

function TFakeGlyphs.TryGetGlyph(ACodePoint: Integer; ABold, AItalic: Boolean;
  out AGlyph: TGlyphBitmap): Boolean;
var
  W, I: Integer;
  Alpha: Byte;
begin
  Inc(FRequests);
  AGlyph := Default(TGlyphBitmap);
  Result := True;
  case ACodePoint of
    Ord('A'): begin W := 6; Alpha := 255; end;
    Ord('B'): begin W := 6; Alpha := 128; end;
    Ord('I'): begin W := 12; Alpha := 255; end;
  else
    Exit(False);
  end;
  if ABold then
    Inc(W);
  AGlyph.Width := W;
  AGlyph.Height := 10;
  AGlyph.Left := 1;
  AGlyph.Top := 10;
  SetLength(AGlyph.Alpha, AGlyph.Width * AGlyph.Height);
  for I := 0 to High(AGlyph.Alpha) do
    AGlyph.Alpha[I] := Alpha;
end;

end.
