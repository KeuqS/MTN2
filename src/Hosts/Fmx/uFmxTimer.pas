unit uFmxTimer;

{ Registers the FMX timer as the backend of the core's timers. }

interface

implementation

uses
  System.SysUtils, System.Classes, FMX.Types, uCoreTimer;

type
  TFmxTimerBackend = class(TInterfacedObject, ICoreTimerBackend)
  private
    FTimer: TTimer;
    FTick: TProc;
    procedure Fired(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Apply(AEnabled: Boolean; AIntervalMs: Cardinal; const ATick: TProc);
  end;

constructor TFmxTimerBackend.Create;
begin
  inherited Create;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.OnTimer := Fired;
end;

destructor TFmxTimerBackend.Destroy;
begin
  FTick := nil;
  FreeAndNil(FTimer);
  inherited Destroy;
end;

procedure TFmxTimerBackend.Apply(AEnabled: Boolean; AIntervalMs: Cardinal;
  const ATick: TProc);
begin
  FTick := ATick;
  FTimer.Enabled := False;
  FTimer.Interval := AIntervalMs;
  FTimer.Enabled := AEnabled;
end;

procedure TFmxTimerBackend.Fired(Sender: TObject);
var
  Tick: TProc;
begin
  Tick := FTick;
  if Assigned(Tick) then
    Tick();
end;

initialization
  SetCoreTimerBackendFactory(
    function: ICoreTimerBackend
    begin
      Result := TFmxTimerBackend.Create;
    end);

end.
