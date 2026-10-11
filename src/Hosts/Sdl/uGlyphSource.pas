unit uGlyphSource;

{ Glyph bitmaps for the pixel renderer. The renderer asks for the cell size
  and for one glyph at a time; where the outlines come from (FreeType font
  files, a fixed test pattern) is the business of the implementation. }

interface

uses
  System.SysUtils;

type
  /// <summary>An 8-bit coverage mask of one glyph. Left is the distance from
  /// the pen position to the mask, Top the distance from the baseline up to
  /// its first row.</summary>
  TGlyphBitmap = record
    Width: Integer;
    Height: Integer;
    Left: Integer;
    Top: Integer;
    Alpha: TBytes;
  end;

  IGlyphSource = interface
    ['{3D6A8E21-7B94-4C0F-A1D5-9E2F40C7B318}']
    /// <summary>Width of one character cell in pixels.</summary>
    function CellWidth: Integer;
    function CellHeight: Integer;
    /// <summary>Distance from the top of the cell to the baseline.</summary>
    function Baseline: Integer;
    /// <summary>False when no font has the character; the renderer then
    /// leaves the cell empty.</summary>
    function TryGetGlyph(ACodePoint: Integer; ABold, AItalic: Boolean;
      out AGlyph: TGlyphBitmap): Boolean;
  end;

implementation

end.
