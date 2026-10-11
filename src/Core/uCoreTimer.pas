unit uCoreTimer;

{ A timer for code that must not depend on a window toolkit: Enabled, Interval
  and OnTimer like a component timer, with the ticks delivered on the main
  thread. A host may install its own backend (the FireMonkey host uses the
  toolkit's timer); without one the timers are polled by ProcessCoreTimers,
  which the main loop of a console host calls on every pass. }

interface

uses
  System.SysUtils, System.Classes;

type
  /// <summary>Implementation of one timer supplied by a host.</summary>
  ICoreTimerBackend = interface
    ['{5B1C6D0E-2F4A-4E7B-9C38-6A0D1E7F52B4}']
    /// <summary>Sets the state of the timer; ATick runs on the main thread
    /// once per interval while AEnabled.</summary>
    procedure Apply(AEnabled: Boolean; AIntervalMs: Cardinal; const ATick: TProc);
  end;

  TCoreTimerBackendFactory = reference to function: ICoreTimerBackend;

  TCoreTimer = class
  private
    FBackend: ICoreTimerBackend;
    FEnabled: Boolean;
    FInterval: Cardinal;
    FOnTimer: TNotifyEvent;
    procedure Tick;
    procedure Update;
    procedure SetEnabled(AValue: Boolean);
    procedure SetInterval(AValue: Cardinal);
    procedure SetOnTimer(const AValue: TNotifyEvent);
  public
    /// <summary>AOwner is accepted for source compatibility with component
    /// timers and is not used.</summary>
    constructor Create(AOwner: TComponent = nil);
    destructor Destroy; override;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Interval: Cardinal read FInterval write SetInterval;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
  end;

/// <summary>Installs the backend factory used by timers created afterwards;
/// nil restores the polled default.</summary>
procedure SetCoreTimerBackendFactory(const AFactory: TCoreTimerBackendFactory);

/// <summary>Runs the polled timers that are due. Main thread only.</summary>
procedure ProcessCoreTimers;

/// <summary>Milliseconds until the next polled timer is due; -1 when none is
/// enabled.</summary>
function CoreTimersNextDueMs: Integer;

implementation

uses
  System.Generics.Collections, uPlatformInfo;

type
  TPolledBackend = class(TInterfacedObject, ICoreTimerBackend)
  private
    FEnabled: Boolean;
    FInterval: Cardinal;
    FDue: UInt64;
    FTick: TProc;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Apply(AEnabled: Boolean; AIntervalMs: Cardinal; const ATick: TProc);
    procedure Poll(ANow: UInt64);
    property Enabled: Boolean read FEnabled;
    property Due: UInt64 read FDue;
  end;

var
  GFactory: TCoreTimerBackendFactory;
  GPolled: TList<TPolledBackend>;

constructor TPolledBackend.Create;
begin
  inherited Create;
  GPolled.Add(Self);
end;

destructor TPolledBackend.Destroy;
begin
  if Assigned(GPolled) then
    GPolled.Remove(Self);
  inherited Destroy;
end;

procedure TPolledBackend.Apply(AEnabled: Boolean; AIntervalMs: Cardinal;
  const ATick: TProc);
begin
  FTick := ATick;
  FInterval := AIntervalMs;
  if AEnabled then
    FDue := PlatformTickCount64 + AIntervalMs;
  FEnabled := AEnabled;
end;

procedure TPolledBackend.Poll(ANow: UInt64);
var
  Tick: TProc;
begin
  if not FEnabled or (ANow < FDue) then
    Exit;
  FDue := ANow + FInterval;
  Tick := FTick;
  if Assigned(Tick) then
    Tick();
end;

procedure SetCoreTimerBackendFactory(const AFactory: TCoreTimerBackendFactory);
begin
  GFactory := AFactory;
end;

procedure ProcessCoreTimers;
var
  Snapshot: TArray<TPolledBackend>;
  Now64: UInt64;
  B: TPolledBackend;
  Keep: ICoreTimerBackend;
begin
  if (GPolled = nil) or (GPolled.Count = 0) then
    Exit;
  Snapshot := GPolled.ToArray;
  Now64 := PlatformTickCount64;
  for B in Snapshot do
  begin
    // A tick may free timers; only a backend still registered is polled, and
    // the interface reference keeps it alive while it runs.
    if GPolled.IndexOf(B) < 0 then
      Continue;
    Keep := B;
    B.Poll(Now64);
  end;
end;

function CoreTimersNextDueMs: Integer;
var
  B: TPolledBackend;
  Now64: UInt64;
  Ms: Int64;
begin
  Result := -1;
  if GPolled = nil then
    Exit;
  Now64 := PlatformTickCount64;
  for B in GPolled do
    if B.Enabled then
    begin
      if B.Due <= Now64 then
        Ms := 0
      else
        Ms := Int64(B.Due - Now64);
      if (Result < 0) or (Ms < Result) then
        Result := Integer(Ms);
    end;
end;

constructor TCoreTimer.Create(AOwner: TComponent);
begin
  inherited Create;
  FInterval := 1000;
  if Assigned(GFactory) then
    FBackend := GFactory()
  else
    FBackend := TPolledBackend.Create;
end;

destructor TCoreTimer.Destroy;
begin
  FOnTimer := nil;
  if Assigned(FBackend) then
    FBackend.Apply(False, 0, nil);
  FBackend := nil;
  inherited Destroy;
end;

procedure TCoreTimer.Tick;
begin
  if Assigned(FOnTimer) then
    FOnTimer(Self);
end;

procedure TCoreTimer.Update;
begin
  FBackend.Apply(FEnabled and Assigned(FOnTimer), FInterval,
    procedure
    begin
      Tick;
    end);
end;

procedure TCoreTimer.SetEnabled(AValue: Boolean);
begin
  FEnabled := AValue;
  Update;
end;

procedure TCoreTimer.SetInterval(AValue: Cardinal);
begin
  FInterval := AValue;
  Update;
end;

procedure TCoreTimer.SetOnTimer(const AValue: TNotifyEvent);
begin
  FOnTimer := AValue;
  Update;
end;

initialization
  GPolled := TList<TPolledBackend>.Create;

finalization
  FreeAndNil(GPolled);

end.
