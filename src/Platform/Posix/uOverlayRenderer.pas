unit uOverlayRenderer;

{ Picture preview laid over the character grid (POSIX build). A text terminal
  has no pixels to put a picture on, so no preview is ever shown: requests
  are accepted and ignored, and the cell metrics are fixed. The Windows build
  lives in Platform\Windows; each project puts exactly one of the two
  directories on its unit search path. }

interface

uses
  System.Classes, System.Types, uThemeTypes;

const
  cOverlayMaxBytes = 32 * 1024 * 1024;

procedure RequestOverlayPreview(const AURI: string; const ABounds: TRectI); overload;
procedure RequestOverlayPreview(const AURI: string; const ABounds, AClip: TRectI;
  AImageScale: Single = 0); overload;
procedure UpdateOverlayBounds(const ABounds: TRectI); overload;
procedure UpdateOverlayBounds(const ABounds, AClip: TRectI; AImageScale: Single = 0); overload;
procedure SetOverlayPixelArea(const ARect: TRectF);
procedure ClearOverlayPixelArea;
procedure SetOverlayPixels(const AURI: string; AWidth, AHeight: Integer; APixels: PByte;
  const ABounds, AClip: TRectI);
procedure ClearOverlayPreview;
function OverlayActive: Boolean;
/// <summary>URI of the current preview request; '' if none.</summary>
function OverlayCurrentURI: string;
procedure SetOverlayRepaintHandler(AHandler: TThreadProcedure);
function SetOverlayCellMetrics(ACellWidth, ACellHeight: Single;
  APixelScale: Single = 1): Boolean;
/// <summary>Cell height / cell width; 2.0.</summary>
function OverlayCellAspect: Single;
/// <summary>False: the cell size in pixels is not known.</summary>
function OverlayNativeCellSize(AImageW, AImageH: Integer; out ACols, ARows: Integer): Boolean;

implementation

procedure RequestOverlayPreview(const AURI: string; const ABounds: TRectI);
begin
end;

procedure RequestOverlayPreview(const AURI: string; const ABounds, AClip: TRectI;
  AImageScale: Single);
begin
end;

procedure UpdateOverlayBounds(const ABounds: TRectI);
begin
end;

procedure UpdateOverlayBounds(const ABounds, AClip: TRectI; AImageScale: Single);
begin
end;

procedure SetOverlayPixelArea(const ARect: TRectF);
begin
end;

procedure ClearOverlayPixelArea;
begin
end;

procedure SetOverlayPixels(const AURI: string; AWidth, AHeight: Integer; APixels: PByte;
  const ABounds, AClip: TRectI);
begin
end;

procedure ClearOverlayPreview;
begin
end;

function OverlayActive: Boolean;
begin
  Result := False;
end;

function OverlayCurrentURI: string;
begin
  Result := '';
end;

procedure SetOverlayRepaintHandler(AHandler: TThreadProcedure);
begin
end;

function SetOverlayCellMetrics(ACellWidth, ACellHeight: Single;
  APixelScale: Single): Boolean;
begin
  Result := False;
end;

function OverlayCellAspect: Single;
begin
  Result := 2.0;
end;

function OverlayNativeCellSize(AImageW, AImageH: Integer; out ACols, ARows: Integer): Boolean;
begin
  ACols := 0;
  ARows := 0;
  Result := False;
end;

end.
