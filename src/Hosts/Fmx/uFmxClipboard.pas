unit uFmxClipboard;

{ Registers the FMX platform clipboard as the core's clipboard service. }

interface

implementation

uses
  System.Rtti, FMX.Platform, uClipboardService;

type
  TFmxClipboardService = class(TInterfacedObject, IClipboardService)
    function TryGetText(out AText: string): Boolean;
    function TrySetText(const AText: string): Boolean;
  end;

function TFmxClipboardService.TryGetText(out AText: string): Boolean;
var
  Svc: IFMXClipboardService;
  V: TValue;
begin
  AText := '';
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
    Exit(False);
  V := Svc.GetClipboard;
  if not V.IsEmpty and V.IsType<string> then
    AText := V.AsString;
  Result := True;
end;

function TFmxClipboardService.TrySetText(const AText: string): Boolean;
var
  Svc: IFMXClipboardService;
begin
  Result := TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc);
  if Result then
    Svc.SetClipboard(AText);
end;

initialization
  SetClipboardService(TFmxClipboardService.Create);

end.
