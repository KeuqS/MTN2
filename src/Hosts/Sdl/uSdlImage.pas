unit uSdlImage;

{ Decodes a picture file into 32-bit pixels (blue, green, red, alpha in
  memory order) with SDL: BMP always, and PNG, JPEG, GIF and the other
  formats of SDL2_image when that library is installed. }

interface

uses
  System.SysUtils;

type
  TPictureStatus = (pdOk, pdNoDecoder, pdFailed);

/// <summary>Reads the file; AWidth, AHeight and APixels describe the result
/// when pdOk is returned. Safe to call from a worker thread once SDL is loaded.</summary>
function DecodePictureFile(const APath: string; out AWidth, AHeight: Integer;
  out APixels: TBytes): TPictureStatus;

implementation

uses
  uSdlApi;

function DecodePictureFile(const APath: string; out AWidth, AHeight: Integer;
  out APixels: TBytes): TPictureStatus;
var
  Path: UTF8String;
  Surface, Converted: PSDLSurface;
  Y: Integer;
begin
  AWidth := 0;
  AHeight := 0;
  APixels := nil;
  if not SdlLoaded then
    Exit(pdNoDecoder);
  Path := UTF8String(APath);
  Surface := nil;
  if SdlImageLoaded then
    Surface := IMG_Load(PAnsiChar(Path))
  else if LowerCase(ExtractFileExt(APath)) = '.bmp' then
    Surface := SDL_LoadBMP_RW(SDL_RWFromFile(PAnsiChar(Path), 'rb'), 1)
  else
    Exit(pdNoDecoder);
  if Surface = nil then
    Exit(pdFailed);
  try
    Converted := SDL_ConvertSurfaceFormat(Surface, SDL_PIXELFORMAT_ARGB8888, 0);
    if Converted = nil then
      Exit(pdFailed);
    try
      if (Converted.W <= 0) or (Converted.H <= 0) or (Converted.Pixels = nil) then
        Exit(pdFailed);
      AWidth := Converted.W;
      AHeight := Converted.H;
      SetLength(APixels, AWidth * AHeight * 4);
      for Y := 0 to AHeight - 1 do
        Move(PByte(Converted.Pixels)[Y * Converted.Pitch], APixels[Y * AWidth * 4],
          AWidth * 4);
    finally
      SDL_FreeSurface(Converted);
    end;
  finally
    SDL_FreeSurface(Surface);
  end;
  Result := pdOk;
end;

end.
