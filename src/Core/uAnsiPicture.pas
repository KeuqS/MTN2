unit uAnsiPicture;

{ Turns the output of a picture-to-text converter (chafa and the like) into
  character cells. Only what such a converter writes is understood: text,
  line breaks and SGR colors (16 colors, the 256-color palette and TrueColor);
  every other escape sequence is skipped. }

interface

uses
  System.UITypes, uTerminalTypes;

/// <summary>Cells of the picture, one row per output line, all rows equally
/// wide. Colors that the text resets take ADefaultFg and ADefaultBg. Trailing
/// empty lines are dropped.</summary>
function ParseAnsiPicture(const AText: string; ADefaultFg, ADefaultBg: TAlphaColor): TTerminalGrid;

/// <summary>Width in cells of the widest row, 0 for no rows.</summary>
function AnsiPictureWidth(const APicture: TTerminalGrid): Integer;

implementation

uses
  System.SysUtils, System.Math, System.Character;

const
  cBasicColors: array[0..15] of Cardinal = (
    $FF000000, $FFCD0000, $FF00CD00, $FFCDCD00, $FF0000EE, $FFCD00CD, $FF00CDCD, $FFE5E5E5,
    $FF7F7F7F, $FFFF0000, $FF00FF00, $FFFFFF00, $FF5C5CFF, $FFFF00FF, $FF00FFFF, $FFFFFFFF);

function PaletteColor(AIndex: Integer): TAlphaColor;
const
  cLevels: array[0..5] of Integer = (0, 95, 135, 175, 215, 255);
var
  N: Integer;
begin
  AIndex := EnsureRange(AIndex, 0, 255);
  if AIndex < 16 then
    Exit(TAlphaColor(cBasicColors[AIndex]));
  if AIndex >= 232 then
  begin
    N := 8 + (AIndex - 232) * 10;
    Exit(TAlphaColor($FF000000 or (Cardinal(N) shl 16) or (Cardinal(N) shl 8) or Cardinal(N)));
  end;
  Dec(AIndex, 16);
  Result := TAlphaColor($FF000000 or (Cardinal(cLevels[AIndex div 36]) shl 16) or
    (Cardinal(cLevels[(AIndex div 6) mod 6]) shl 8) or Cardinal(cLevels[AIndex mod 6]));
end;

function RgbColor(AR, AG, AB: Integer): TAlphaColor;
begin
  Result := TAlphaColor($FF000000 or (Cardinal(EnsureRange(AR, 0, 255)) shl 16) or
    (Cardinal(EnsureRange(AG, 0, 255)) shl 8) or Cardinal(EnsureRange(AB, 0, 255)));
end;

procedure SplitParams(const AText: string; out AParams: TArray<Integer>);
var
  Parts: TArray<string>;
  I: Integer;
begin
  if AText = '' then
  begin
    AParams := TArray<Integer>.Create(0);
    Exit;
  end;
  Parts := AText.Replace(':', ';').Split([';']);
  SetLength(AParams, Length(Parts));
  for I := 0 to High(Parts) do
    AParams[I] := StrToIntDef(Parts[I], 0);
end;

procedure ApplySgr(const AParams: TArray<Integer>; ADefaultFg, ADefaultBg: TAlphaColor;
  var AFg, ABg: TAlphaColor);
var
  I, P: Integer;
begin
  I := 0;
  while I <= High(AParams) do
  begin
    P := AParams[I];
    case P of
      0:
        begin
          AFg := ADefaultFg;
          ABg := ADefaultBg;
        end;
      30..37: AFg := PaletteColor(P - 30);
      90..97: AFg := PaletteColor(P - 90 + 8);
      39: AFg := ADefaultFg;
      40..47: ABg := PaletteColor(P - 40);
      100..107: ABg := PaletteColor(P - 100 + 8);
      49: ABg := ADefaultBg;
      38, 48:
        begin
          if (I + 2 <= High(AParams)) and (AParams[I + 1] = 5) then
          begin
            if P = 38 then
              AFg := PaletteColor(AParams[I + 2])
            else
              ABg := PaletteColor(AParams[I + 2]);
            Inc(I, 2);
          end
          else if (I + 4 <= High(AParams)) and (AParams[I + 1] = 2) then
          begin
            if P = 38 then
              AFg := RgbColor(AParams[I + 2], AParams[I + 3], AParams[I + 4])
            else
              ABg := RgbColor(AParams[I + 2], AParams[I + 3], AParams[I + 4]);
            Inc(I, 4);
          end;
        end;
    end;
    Inc(I);
  end;
end;

function ParseAnsiPicture(const AText: string; ADefaultFg, ADefaultBg: TAlphaColor): TTerminalGrid;
var
  Fg, Bg: TAlphaColor;
  Row: TTerminalRow;
  RowLen, RowCount, Width, I, J, N: Integer;
  Params: TArray<Integer>;
  Ch: Char;

  procedure EndRow;
  begin
    SetLength(Row, RowLen);
    if RowCount > High(Result) then
      SetLength(Result, Max(8, RowCount * 2));
    Result[RowCount] := Row;
    Inc(RowCount);
    Width := Max(Width, RowLen);
    Row := nil;
    RowLen := 0;
  end;

  procedure AddCell(AChar: Char);
  begin
    if RowLen >= Length(Row) then
      SetLength(Row, Max(16, RowLen * 2));
    Row[RowLen] := TCharCell.Make(AChar, Fg, Bg);
    Inc(RowLen);
  end;

begin
  Result := nil;
  Fg := ADefaultFg;
  Bg := ADefaultBg;
  RowLen := 0;
  RowCount := 0;
  Width := 0;
  N := Length(AText);
  I := 1;
  while I <= N do
  begin
    Ch := AText[I];
    if Ch = #27 then
    begin
      if (I < N) and (AText[I + 1] = '[') then
      begin
        J := I + 2;
        while (J <= N) and not CharInSet(AText[J], [#$40..#$7E]) do
          Inc(J);
        if (J <= N) and (AText[J] = 'm') then
        begin
          SplitParams(Copy(AText, I + 2, J - I - 2), Params);
          ApplySgr(Params, ADefaultFg, ADefaultBg, Fg, Bg);
        end;
        I := J + 1;
      end
      else if (I < N) and (AText[I + 1] = ']') then
      begin
        // Operating system command: ends with BEL or ESC \.
        J := I + 2;
        while (J <= N) and (AText[J] <> #7) and
              not ((AText[J] = #27) and (J < N) and (AText[J + 1] = '\')) do
          Inc(J);
        if (J <= N) and (AText[J] = #27) then
          Inc(J);
        I := J + 1;
      end
      else
        Inc(I, 2);
      Continue;
    end;
    Inc(I);
    if Ch = #10 then
      EndRow
    else if Ch < ' ' then
      Continue
    else if Ch.IsHighSurrogate then
    begin
      AddCell(' ');
      Inc(I);
    end
    else
      AddCell(Ch);
  end;
  if RowLen > 0 then
    EndRow;
  SetLength(Result, RowCount);
  while (RowCount > 0) and (Length(Result[RowCount - 1]) = 0) do
  begin
    Dec(RowCount);
    SetLength(Result, RowCount);
  end;
  for I := 0 to High(Result) do
  begin
    J := Length(Result[I]);
    SetLength(Result[I], Width);
    while J < Width do
    begin
      Result[I][J] := TCharCell.Make(' ', ADefaultFg, ADefaultBg);
      Inc(J);
    end;
  end;
end;

function AnsiPictureWidth(const APicture: TTerminalGrid): Integer;
begin
  if Length(APicture) = 0 then
    Result := 0
  else
    Result := Length(APicture[0]);
end;

end.
