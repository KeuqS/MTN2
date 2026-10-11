unit TestSdlWindow;

{ SDL itself, with the video driver that draws nothing: the bindings load,
  a window, a renderer and a streaming texture are created, events keep the
  layout the input mapper reads, and the clipboard holds text. Without
  libSDL2 the fixture ends at once as passed. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestSdlWindow = class
  public
    [Test] procedure WindowRendererAndTextureWork;
    [Test] procedure WindowEventsCarryTheWindowId;
    [Test] procedure PushedKeyComesBackThroughTheMapper;
    [Test] procedure ClipboardKeepsText;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.UITypes,
  uTermInput, uSdlApi, uSdlInput, uSdlClipboard, uClipboardService;

var
  GInitialized: Boolean;

function StartSdl: Boolean;
var
  Err: string;
begin
  if not LoadSdl(Err) then
    Exit(False);
  if not GInitialized then
  begin
    SDL_SetHint('SDL_VIDEODRIVER', 'dummy');
    if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS) <> 0 then
      Exit(False);
    GInitialized := True;
  end;
  Result := True;
end;

procedure TTestSdlWindow.WindowRendererAndTextureWork;
var
  Win: PSDLWindow;
  Ren: PSDLRenderer;
  Tex: PSDLTexture;
  W, H: Integer;
  Pixels: array[0..63] of Cardinal;
  I: Integer;
begin
  if not StartSdl then
    Assert.Pass('SDL2 is not available');
  Win := SDL_CreateWindow('test', SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 320, 200,
    SDL_WINDOW_SHOWN);
  Assert.IsNotNull(Win, SdlErrorText);
  try
    Ren := SDL_CreateRenderer(Win, -1, SDL_RENDERER_SOFTWARE);
    Assert.IsNotNull(Ren, SdlErrorText);
    try
      Assert.AreEqual(0, SDL_GetRendererOutputSize(Ren, W, H));
      Assert.AreEqual(320, W);
      Assert.AreEqual(200, H);
      Tex := SDL_CreateTexture(Ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, 8, 8);
      Assert.IsNotNull(Tex, SdlErrorText);
      try
        for I := 0 to High(Pixels) do
          Pixels[I] := $FF336699;
        Assert.AreEqual(0, SDL_UpdateTexture(Tex, nil, @Pixels[0], 32));
        SDL_SetRenderDrawColor(Ren, 0, 0, 0, 255);
        SDL_RenderClear(Ren);
        Assert.AreEqual(0, SDL_RenderCopy(Ren, Tex, nil, nil));
        SDL_RenderPresent(Ren);
      finally
        SDL_DestroyTexture(Tex);
      end;
    finally
      SDL_DestroyRenderer(Ren);
    end;
  finally
    SDL_DestroyWindow(Win);
  end;
end;

procedure TTestSdlWindow.WindowEventsCarryTheWindowId;
var
  Win: PSDLWindow;
  E: TSDLEvent;
  Id: Cardinal;
  Seen: Boolean;
  Tries: Integer;
begin
  if not StartSdl then
    Assert.Pass('SDL2 is not available');
  Win := SDL_CreateWindow('events', SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 200, 100,
    SDL_WINDOW_SHOWN);
  Assert.IsNotNull(Win, SdlErrorText);
  try
    Id := SDL_GetWindowID(Win);
    Assert.IsTrue(Id > 0);
    Seen := False;
    Tries := 0;
    while (SDL_WaitEventTimeout(E, 200) <> 0) and (Tries < 50) do
    begin
      Inc(Tries);
      // windowID follows the type and the timestamp; the event code is a byte
      // at 12. Events of an earlier window may still be queued.
      if (SdlEventType(E) = SDL_WINDOWEVENT) and (SdlEventU32(E, 8) = Id) and
         (SdlEventU8(E, 12) > 0) then
        Seen := True;
    end;
    Assert.IsTrue(Seen, 'showing a window produces window events');
  finally
    SDL_DestroyWindow(Win);
  end;
end;

procedure TTestSdlWindow.PushedKeyComesBackThroughTheMapper;
var
  E, Back: TSDLEvent;
  Mapper: TSdlInputMapper;
  Events: TList<TTermEvent>;
begin
  if not StartSdl then
    Assert.Pass('SDL2 is not available');
  E := Default(TSDLEvent);
  SdlEventSetU32(E, 0, SDL_KEYDOWN);
  SdlEventSetU32(E, 20, 13);
  Assert.AreEqual(1, SDL_PushEvent(E));
  Back := Default(TSDLEvent);
  repeat
    Assert.AreNotEqual(0, SDL_WaitEventTimeout(Back, 500), 'the pushed event is delivered');
  until SdlEventType(Back) = SDL_KEYDOWN;
  Mapper := TSdlInputMapper.Create;
  Events := TList<TTermEvent>.Create;
  try
    Mapper.Translate(Back, Events);
    Assert.AreEqual(1, Integer(Events.Count));
    Assert.AreEqual(Integer(vkReturn), Integer(Events[0].Key));
  finally
    Events.Free;
    Mapper.Free;
  end;
end;

procedure TTestSdlWindow.ClipboardKeepsText;
var
  Clip: IClipboardService;
  Text: string;
begin
  if not StartSdl then
    Assert.Pass('SDL2 is not available');
  Clip := TSdlClipboard.Create;
  Assert.IsTrue(Clip.TrySetText('mtn2 clipboard ' + #$0416));
  Assert.IsTrue(Clip.TryGetText(Text));
  Assert.AreEqual('mtn2 clipboard ' + #$0416, Text);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSdlWindow);

end.
