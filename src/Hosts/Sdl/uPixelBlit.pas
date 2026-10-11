unit uPixelBlit;

{ Scaling of a picture of 32-bit pixels (blue, green, red, alpha in memory
  order) into a bitmap of the same format, and the geometry that fits a
  picture into a block of character cells. }

interface

uses
  System.Types, System.SysUtils;

/// <summary>Where the picture lands inside ATarget (pixels): fitted without
/// stretching and centered, or, when AScale > 0, drawn at AScale device
/// pixels per picture pixel from the top left and shrunk only when it is
/// larger than ATarget.</summary>
function FitPicture(APicW, APicH: Integer; const ATarget: TRect; AScale: Single): TRect;

/// <summary>Draws the picture scaled into ADest (a rectangle in the bitmap),
/// only inside AClip; transparent parts show what is already there. Reductions
/// average the covered picture pixels.</summary>
procedure BlitScaled(const APicture: TBytes; APicW, APicH: Integer; APixels: PByte;
  AStride, AWidth, AHeight: Integer; const ADest, AClip: TRect);

implementation

uses
  System.Math;

function FitPicture(APicW, APicH: Integer; const ATarget: TRect; AScale: Single): TRect;
var
  TW, TH, W, H: Integer;
  Ratio: Double;
begin
  TW := ATarget.Width;
  TH := ATarget.Height;
  if (APicW <= 0) or (APicH <= 0) or (TW <= 0) or (TH <= 0) then
    Exit(TRect.Create(ATarget.Left, ATarget.Top, ATarget.Left, ATarget.Top));
  if AScale > 0 then
  begin
    W := Max(1, Round(APicW * AScale));
    H := Max(1, Round(APicH * AScale));
    if (W > TW) or (H > TH) then
    begin
      Ratio := Min(TW / W, TH / H);
      W := Max(1, Round(W * Ratio));
      H := Max(1, Round(H * Ratio));
    end;
    Exit(TRect.Create(ATarget.Left, ATarget.Top, ATarget.Left + W, ATarget.Top + H));
  end;
  Ratio := Min(TW / APicW, TH / APicH);
  W := Max(1, Round(APicW * Ratio));
  H := Max(1, Round(APicH * Ratio));
  Result.Left := ATarget.Left + (TW - W) div 2;
  Result.Top := ATarget.Top + (TH - H) div 2;
  Result.Right := Result.Left + W;
  Result.Bottom := Result.Top + H;
end;

procedure BlitScaled(const APicture: TBytes; APicW, APicH: Integer; APixels: PByte;
  AStride, AWidth, AHeight: Integer; const ADest, AClip: TRect);
const
  cMaxSamples = 8;
var
  Area: TRect;
  DX, DY, SX, SY, SX0, SX1, SY0, SY1, StepX, StepY, N: Integer;
  RatioX, RatioY: Double;
  SumB, SumG, SumR, SumA: Cardinal;
  Src: PByte;
  Dst: PCardinal;
  A, Inv, OldPix: Cardinal;
  B, G, R: Cardinal;
begin
  if (APicW <= 0) or (APicH <= 0) or (ADest.Width <= 0) or (ADest.Height <= 0) then
    Exit;
  Area := TRect.Intersect(TRect.Intersect(ADest, AClip), TRect.Create(0, 0, AWidth, AHeight));
  if Area.IsEmpty then
    Exit;
  RatioX := APicW / ADest.Width;
  RatioY := APicH / ADest.Height;
  for DY := Area.Top to Area.Bottom - 1 do
  begin
    SY0 := Min(APicH - 1, Trunc((DY - ADest.Top) * RatioY));
    SY1 := Max(SY0 + 1, Min(APicH, Ceil((DY - ADest.Top + 1) * RatioY)));
    StepY := Max(1, (SY1 - SY0) div cMaxSamples);
    Dst := PCardinal(APixels + DY * AStride + Area.Left * 4);
    for DX := Area.Left to Area.Right - 1 do
    begin
      SX0 := Min(APicW - 1, Trunc((DX - ADest.Left) * RatioX));
      SX1 := Max(SX0 + 1, Min(APicW, Ceil((DX - ADest.Left + 1) * RatioX)));
      StepX := Max(1, (SX1 - SX0) div cMaxSamples);
      SumB := 0;
      SumG := 0;
      SumR := 0;
      SumA := 0;
      N := 0;
      SY := SY0;
      while SY < SY1 do
      begin
        SX := SX0;
        while SX < SX1 do
        begin
          Src := @APicture[(SY * APicW + SX) * 4];
          // Weigh the color by its alpha so transparent pixels add no color.
          SumB := SumB + Src[0] * Src[3];
          SumG := SumG + Src[1] * Src[3];
          SumR := SumR + Src[2] * Src[3];
          SumA := SumA + Src[3];
          Inc(N);
          Inc(SX, StepX);
        end;
        Inc(SY, StepY);
      end;
      if SumA > 0 then
      begin
        B := SumB div SumA;
        G := SumG div SumA;
        R := SumR div SumA;
        A := SumA div Cardinal(N);
        if A >= 255 then
          Dst^ := $FF000000 or (R shl 16) or (G shl 8) or B
        else
        begin
          Inv := 255 - A;
          OldPix := Dst^;
          Dst^ := $FF000000 or
            ((((OldPix shr 16) and $FF) * Inv + R * A + 127) div 255) shl 16 or
            ((((OldPix shr 8) and $FF) * Inv + G * A + 127) div 255) shl 8 or
            (((OldPix and $FF) * Inv + B * A + 127) div 255);
        end;
      end;
      Inc(Dst);
    end;
  end;
end;

end.
