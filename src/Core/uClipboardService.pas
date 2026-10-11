unit uClipboardService;

{ Text clipboard access for the core. The host registers the real clipboard
  (FMX window, SDL window, terminal OSC 52); until then, and in headless
  runs, a process-local buffer stands in so copy and paste still pair up. }

interface

type
  IClipboardService = interface
    ['{6E3B1C52-4F0A-4D8E-9B27-5A1D3C8E7F40}']
    /// <summary>False when the clipboard cannot be read.</summary>
    function TryGetText(out AText: string): Boolean;
    /// <summary>False when the clipboard cannot be written.</summary>
    function TrySetText(const AText: string): Boolean;
  end;

/// <summary>Installs the host's clipboard; nil restores the process-local
/// buffer.</summary>
procedure SetClipboardService(const AService: IClipboardService);

/// <summary>The clipboard text, or '' when it is empty or unreadable.</summary>
function GetClipboardText: string;
function TryGetClipboardText(out AText: string): Boolean;

/// <summary>Replaces the clipboard text; False when it cannot be written.</summary>
function TrySetClipboardText(const AText: string): Boolean;
procedure SetClipboardText(const AText: string);

implementation

var
  GService: IClipboardService;
  GLocalText: string;

procedure SetClipboardService(const AService: IClipboardService);
begin
  GService := AService;
end;

function TryGetClipboardText(out AText: string): Boolean;
begin
  if GService <> nil then
    Exit(GService.TryGetText(AText));
  AText := GLocalText;
  Result := True;
end;

function GetClipboardText: string;
begin
  if not TryGetClipboardText(Result) then
    Result := '';
end;

function TrySetClipboardText(const AText: string): Boolean;
begin
  if GService <> nil then
    Exit(GService.TrySetText(AText));
  GLocalText := AText;
  Result := True;
end;

procedure SetClipboardText(const AText: string);
begin
  TrySetClipboardText(AText);
end;

end.
