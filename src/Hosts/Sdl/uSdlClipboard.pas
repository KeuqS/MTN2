unit uSdlClipboard;

{ The system clipboard through SDL, as the clipboard service of the core. }

interface

uses
  uClipboardService;

type
  TSdlClipboard = class(TInterfacedObject, IClipboardService)
  public
    function TryGetText(out AText: string): Boolean;
    function TrySetText(const AText: string): Boolean;
  end;

implementation

uses
  System.SysUtils, uSdlApi;

function TSdlClipboard.TryGetText(out AText: string): Boolean;
var
  P: PAnsiChar;
begin
  AText := '';
  if not Assigned(SDL_GetClipboardText) then
    Exit(False);
  P := SDL_GetClipboardText;
  if P = nil then
    Exit(False);
  try
    AText := UTF8ToString(P);
  finally
    SDL_free(P);
  end;
  Result := True;
end;

function TSdlClipboard.TrySetText(const AText: string): Boolean;
var
  S: UTF8String;
begin
  if not Assigned(SDL_SetClipboardText) then
    Exit(False);
  S := UTF8String(AText);
  Result := SDL_SetClipboardText(PAnsiChar(S)) = 0;
end;

end.
