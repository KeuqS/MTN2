unit uAnsiTerm;

{ The controlling terminal of the program: raw mode, size, writing and reading
  with a timeout, and the signals that must put the terminal back. Linux only. }

interface

uses
  System.SysUtils;

type
  TAnsiTerm = class
  private
    FSaved: array[0..255] of Byte;
    FRaw: Boolean;
  public
    destructor Destroy; override;
    /// <summary>True when standard input and output are a terminal.</summary>
    class function IsTerminal: Boolean;
    procedure EnterRaw;
    procedure LeaveRaw;
    /// <summary>Size in cells; False when it cannot be read.</summary>
    function QuerySize(out ACols, ARows: Integer): Boolean;
    procedure Write(const AData: TBytes);
    procedure WriteText(const AText: string);
    /// <summary>Reads what is available, waiting at most AMs milliseconds;
    /// returns the byte count (0 on timeout).</summary>
    function Read(var ABuf: TBytes; AMs: Integer): Integer;
  end;

/// <summary>True once SIGTERM, SIGHUP or SIGINT arrived.</summary>
function TerminationRequested: Boolean;
/// <summary>Installs the handlers that set TerminationRequested.</summary>
procedure InstallTerminationHandlers;

implementation

uses
  Posix.Base, Posix.Termios, Posix.Unistd, Posix.SysSelect, Posix.SysTime;

const
  TIOCGWINSZ = $5413;
  SIGINT = 2;
  SIGHUP = 1;
  SIGTERM = 15;
  SIGPIPE = 13;
  SIG_IGN = 1;

type
  TWinSize = record
    Rows: Word;
    Cols: Word;
    XPixel: Word;
    YPixel: Word;
  end;

var
  GTerminate: Boolean = False;

function c_ioctl(AFd: Integer; ARequest: NativeUInt; AArg: Pointer): Integer; cdecl;
  external libc name 'ioctl';
function c_signal(ASig: Integer; AHandler: Pointer): Pointer; cdecl;
  external libc name 'signal';
function c_isatty(AFd: Integer): Integer; cdecl; external libc name 'isatty';

procedure TermHandler(ASig: Integer); cdecl;
begin
  GTerminate := True;
end;

function TerminationRequested: Boolean;
begin
  Result := GTerminate;
end;

procedure InstallTerminationHandlers;
begin
  c_signal(SIGTERM, @TermHandler);
  c_signal(SIGHUP, @TermHandler);
  c_signal(SIGINT, @TermHandler);
  c_signal(SIGPIPE, Pointer(SIG_IGN));
end;

destructor TAnsiTerm.Destroy;
begin
  LeaveRaw;
  inherited Destroy;
end;

class function TAnsiTerm.IsTerminal: Boolean;
begin
  Result := (c_isatty(0) = 1) and (c_isatty(1) = 1);
end;

procedure TAnsiTerm.EnterRaw;
var
  Saved, Raw: termios;
begin
  if FRaw then
    Exit;
  tcgetattr(0, Saved);
  Move(Saved, FSaved[0], SizeOf(Saved));
  Raw := Saved;
  cfmakeraw(Raw);
  tcsetattr(0, TCSANOW, Raw);
  FRaw := True;
end;

procedure TAnsiTerm.LeaveRaw;
var
  Saved: termios;
begin
  if not FRaw then
    Exit;
  Move(FSaved[0], Saved, SizeOf(Saved));
  tcsetattr(0, TCSANOW, Saved);
  FRaw := False;
end;

function TAnsiTerm.QuerySize(out ACols, ARows: Integer): Boolean;
var
  WS: TWinSize;
begin
  ACols := 80;
  ARows := 24;
  FillChar(WS, SizeOf(WS), 0);
  Result := (c_ioctl(1, TIOCGWINSZ, @WS) = 0) and (WS.Cols > 0) and (WS.Rows > 0);
  if Result then
  begin
    ACols := WS.Cols;
    ARows := WS.Rows;
  end;
end;

procedure TAnsiTerm.Write(const AData: TBytes);
var
  Offset: Integer;
  N: NativeInt;
begin
  Offset := 0;
  while Offset < Length(AData) do
  begin
    N := __write(1, @AData[Offset], Length(AData) - Offset);
    if N < 0 then
    begin
      // A signal interrupted the write; anything else is a lost terminal.
      if GetLastError = 4 then
        Continue;
      Break;
    end;
    Inc(Offset, N);
  end;
end;

procedure TAnsiTerm.WriteText(const AText: string);
begin
  Write(TEncoding.UTF8.GetBytes(AText));
end;

function TAnsiTerm.Read(var ABuf: TBytes; AMs: Integer): Integer;
var
  FS: fd_set;
  TV: timeval;
  R: Integer;
begin
  Result := 0;
  if Length(ABuf) = 0 then
    SetLength(ABuf, 4096);
  __FD_ZERO(FS);
  _FD_SET(0, FS);
  TV.tv_sec := AMs div 1000;
  TV.tv_usec := (AMs mod 1000) * 1000;
  R := select(1, @FS, nil, nil, @TV);
  if R > 0 then
  begin
    R := __read(0, @ABuf[0], Length(ABuf));
    if R > 0 then
      Result := R;
  end;
end;

end.
