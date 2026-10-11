unit uImageInfo;

{ Cheap facts about image files, read without decoding the picture. }

interface

/// <summary>Whitelist for Quick View - matches what FMX's default bitmap
/// codecs (WIC on Windows) reliably decode via LoadFromStream.</summary>
function IsOverlayImageExtension(const AExt: string): Boolean;

/// <summary>Request (or replace) the active preview. ABounds is in grid
/// cells (inclusive Left/Top/Right/Bottom, TRectI convention).</summary>

/// <summary>Pixel size from the file header only (PNG, JPEG, GIF, BMP,
/// WebP) - no decode, reads at most 64 KB. False for other formats or a
/// broken header.</summary>
function ReadImagePixelSize(const APath: string; out AWidth, AHeight: Integer): Boolean;

implementation

uses
  System.SysUtils, System.Classes, System.Math, uVfsTypes;

function IsOverlayImageExtension(const AExt: string): Boolean;
var
  E: string;
begin
  E := LowerCase(AExt);
  Result := (E = '.png') or (E = '.jpg') or (E = '.jpeg') or (E = '.jfif') or
    (E = '.bmp') or (E = '.gif') or (E = '.ico') or (E = '.tif') or
    (E = '.tiff') or (E = '.webp');
end;

function ReadImagePixelSize(const APath: string; out AWidth, AHeight: Integer): Boolean;
const
  cMaxHeader = 64 * 1024;
var
  FS: TFileStream;
  B: TBytes;
  N, P, SegLen: Integer;
  M: Byte;

  function BE16(I: Integer): Integer;
  begin
    Result := (B[I] shl 8) or B[I + 1];
  end;

  function LE16(I: Integer): Integer;
  begin
    Result := B[I] or (B[I + 1] shl 8);
  end;

  function LE24(I: Integer): Integer;
  begin
    Result := B[I] or (B[I + 1] shl 8) or (B[I + 2] shl 16);
  end;

  function BE32(I: Integer): Int64;
  begin
    Result := (Int64(B[I]) shl 24) or (B[I + 1] shl 16) or (B[I + 2] shl 8) or B[I + 3];
  end;

  function LE32(I: Integer): Integer;
  begin
    Result := Integer(Cardinal(B[I]) or (Cardinal(B[I + 1]) shl 8) or
      (Cardinal(B[I + 2]) shl 16) or (Cardinal(B[I + 3]) shl 24));
  end;

  function Tag(I: Integer; const S: AnsiString): Boolean;
  var
    K: Integer;
  begin
    Result := I + Length(S) <= N;
    if Result then
      for K := 1 to Length(S) do
        if B[I + K - 1] <> Ord(S[K]) then
          Exit(False);
  end;

begin
  Result := False;
  AWidth := 0;
  AHeight := 0;
  try
    FS := TFileStream.Create(WinApiPath(APath), fmOpenRead or fmShareDenyNone);
    try
      N := Integer(Min(FS.Size, cMaxHeader));
      SetLength(B, N);
      if N > 0 then
        FS.ReadBuffer(B[0], N);
    finally
      FS.Free;
    end;
  except
    Exit;
  end;

  if Tag(0, #$89'PNG'#13#10#26#10) and Tag(12, 'IHDR') and (N >= 24) then
  begin
    AWidth := BE32(16);
    AHeight := BE32(20);
  end
  else if (Tag(0, 'GIF87a') or Tag(0, 'GIF89a')) and (N >= 10) then
  begin
    AWidth := LE16(6);
    AHeight := LE16(8);
  end
  else if Tag(0, 'BM') and (N >= 26) then
  begin
    AWidth := LE32(18);
    AHeight := Abs(LE32(22)); // negative = top-down rows
  end
  else if Tag(0, 'RIFF') and Tag(8, 'WEBP') and (N >= 30) then
  begin
    if Tag(12, 'VP8 ') then
    begin
      AWidth := LE16(26) and $3FFF;
      AHeight := LE16(28) and $3FFF;
    end
    else if Tag(12, 'VP8L') and (N >= 25) then
    begin
      AWidth := (LE16(21) and $3FFF) + 1;
      AHeight := ((LE32(21) shr 14) and $3FFF) + 1;
    end
    else if Tag(12, 'VP8X') then
    begin
      AWidth := LE24(24) + 1;
      AHeight := LE24(27) + 1;
    end;
  end
  else if (N >= 4) and (B[0] = $FF) and (B[1] = $D8) then
  begin
    // JPEG: walk segments to the first SOFn (not DHT C4 / JPG C8 / DAC CC).
    P := 2;
    while P + 9 < N do
    begin
      if B[P] <> $FF then
        Break;
      M := B[P + 1];
      if M = $FF then
      begin
        Inc(P); // fill byte
        Continue;
      end;
      if (M = $D8) or ((M >= $D0) and (M <= $D7)) or (M = $01) then
      begin
        Inc(P, 2); // standalone markers
        Continue;
      end;
      SegLen := BE16(P + 2);
      if (M >= $C0) and (M <= $CF) and (M <> $C4) and (M <> $C8) and (M <> $CC) then
      begin
        AHeight := BE16(P + 5);
        AWidth := BE16(P + 7);
        Break;
      end;
      if SegLen < 2 then
        Break;
      Inc(P, 2 + SegLen);
    end;
  end;
  Result := (AWidth > 0) and (AHeight > 0);
end;

end.
