unit uPngWriter;

{ Writes 32-bit pixels (blue, green, red, alpha in memory order) as a PNG
  file: for screenshots of the rendered grid. }

interface

/// <summary>Saves the pixels, AStride bytes per row, as an opaque RGB image.</summary>
procedure SavePixelsAsPng(const AFileName: string; APixels: PByte; AStride, AWidth,
  AHeight: Integer);

implementation

uses
  System.SysUtils, System.Classes, System.ZLib;

var
  GCrcTable: array[0..255] of Cardinal;
  GCrcReady: Boolean;

procedure InitCrc;
var
  N, K: Integer;
  C: Cardinal;
begin
  for N := 0 to 255 do
  begin
    C := N;
    for K := 0 to 7 do
      if (C and 1) <> 0 then
        C := $EDB88320 xor (C shr 1)
      else
        C := C shr 1;
    GCrcTable[N] := C;
  end;
  GCrcReady := True;
end;

function Crc32Of(const AData: TBytes; AStart, ACount: Integer): Cardinal;
var
  I: Integer;
begin
  if not GCrcReady then
    InitCrc;
  Result := $FFFFFFFF;
  for I := AStart to AStart + ACount - 1 do
    Result := GCrcTable[(Result xor AData[I]) and $FF] xor (Result shr 8);
  Result := Result xor $FFFFFFFF;
end;

procedure PutBigEndian(var ABytes: TBytes; AOffset: Integer; AValue: Cardinal);
begin
  ABytes[AOffset] := Byte(AValue shr 24);
  ABytes[AOffset + 1] := Byte(AValue shr 16);
  ABytes[AOffset + 2] := Byte(AValue shr 8);
  ABytes[AOffset + 3] := Byte(AValue);
end;

procedure WriteChunk(AStream: TStream; const AType: AnsiString; const AData: TBytes);
var
  Block: TBytes;
  Len: Integer;
begin
  Len := Length(AData);
  SetLength(Block, 8 + Len + 4);
  PutBigEndian(Block, 0, Cardinal(Len));
  Move(AType[1], Block[4], 4);
  if Len > 0 then
    Move(AData[0], Block[8], Len);
  PutBigEndian(Block, 8 + Len, Crc32Of(Block, 4, 4 + Len));
  AStream.WriteBuffer(Block[0], Length(Block));
end;

procedure SavePixelsAsPng(const AFileName: string; APixels: PByte; AStride, AWidth,
  AHeight: Integer);
const
  cSignature: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
  Raw, Header, Deflated: TBytes;
  Y, X, Pos: Integer;
  Row: PByte;
  Out: Pointer;
  OutSize: Integer;
  Stream: TFileStream;
begin
  SetLength(Raw, (AWidth * 3 + 1) * AHeight);
  Pos := 0;
  for Y := 0 to AHeight - 1 do
  begin
    Raw[Pos] := 0;
    Inc(Pos);
    Row := APixels + Y * AStride;
    for X := 0 to AWidth - 1 do
    begin
      Raw[Pos] := Row[X * 4 + 2];
      Raw[Pos + 1] := Row[X * 4 + 1];
      Raw[Pos + 2] := Row[X * 4];
      Inc(Pos, 3);
    end;
  end;
  ZCompress(@Raw[0], Length(Raw), Out, OutSize, zcDefault);
  try
    SetLength(Deflated, OutSize);
    Move(Out^, Deflated[0], OutSize);
  finally
    FreeMem(Out);
  end;
  SetLength(Header, 13);
  PutBigEndian(Header, 0, Cardinal(AWidth));
  PutBigEndian(Header, 4, Cardinal(AHeight));
  Header[8] := 8;   // bits per channel
  Header[9] := 2;   // truecolor
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    Stream.WriteBuffer(cSignature[0], SizeOf(cSignature));
    WriteChunk(Stream, 'IHDR', Header);
    WriteChunk(Stream, 'IDAT', Deflated);
    WriteChunk(Stream, 'IEND', nil);
  finally
    Stream.Free;
  end;
end;

end.
