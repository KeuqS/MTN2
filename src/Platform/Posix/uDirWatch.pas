unit uDirWatch;

{ Watches a local directory via inotify and notifies the main thread
  (debounced) when contents change.

  The Windows build lives in Platform\Windows; each project puts exactly one
  of the two directories on its unit search path. }

interface

uses
  System.SysUtils, System.Classes;

type
  TDirWatchNotify = reference to procedure;

  TDirectoryWatcher = class;

  TWatchLife = class(TInterfacedObject)
  public
    Owner: TDirectoryWatcher;
  end;

  TDirectoryWatcher = class
  private
    FPath: string;
    FOnChanged: TDirWatchNotify;
    FOnArmed: TDirWatchNotify;
    FThread: TThread;
    /// <summary>Write end of the pipe that stops the watcher thread; -1 until
    /// the thread has armed its watch and published it.</summary>
    FStopFd: Integer;
    FGen: Integer;
    /// <summary>The closures a setup thread queues reach this instance only
    /// through this link, which Close/Destroy cuts: they must not touch it
    /// once it may be freed (its memory can already belong to a new watcher).</summary>
    FLife: TWatchLife;
    FLifeRef: IInterface;
    procedure StopWatcher;
    procedure StartWatcher(const APath: string);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Empty path stops the watcher. Same path is a no-op.</summary>
    procedure SetPath(const APath: string);
    procedure Close;
    property OnChanged: TDirWatchNotify read FOnChanged write FOnChanged;
    /// <summary>Main thread, once per SetPath, when the watch is armed (see
    /// Active). A change made between SetPath and this raises no OnChanged,
    /// so a caller that must not miss one re-checks here.</summary>
    property OnArmed: TDirWatchNotify read FOnArmed write FOnArmed;
    property Path: string read FPath;
    /// <summary>True once the background setup has armed the watch for Path.
    /// Changes made before this may be missed.</summary>
    function Active: Boolean;
  end;

implementation

uses
  Posix.Base, Posix.Unistd, uVfsTypes;

const
  IN_MODIFY = $00000002;
  IN_ATTRIB = $00000004;
  IN_MOVED_FROM = $00000040;
  IN_MOVED_TO = $00000080;
  IN_CREATE = $00000100;
  IN_DELETE = $00000200;
  IN_DELETE_SELF = $00000400;
  IN_MOVE_SELF = $00000800;
  IN_NONBLOCK = $00000800;
  IN_CLOEXEC = $00080000;
  POLLIN = $0001;
  cDebounceMs = 300;

type
  TPollFd = record
    fd: Integer;
    events: SmallInt;
    revents: SmallInt;
  end;

function inotify_init1(AFlags: Integer): Integer; cdecl;
  external libc name 'inotify_init1';
function inotify_add_watch(AFd: Integer; APath: MarshaledAString;
  AMask: Cardinal): Integer; cdecl; external libc name 'inotify_add_watch';
function poll(AFds: Pointer; ACount: NativeUInt; ATimeoutMs: Integer): Integer; cdecl;
  external libc name 'poll';

function WaitReadable(ANotifyFd, AStopFd, ATimeoutMs: Integer;
  out AStop, ANotify: Boolean): Boolean;
var
  Fds: array[0..1] of TPollFd;
  R: Integer;
begin
  Fds[0].fd := AStopFd;
  Fds[0].events := POLLIN;
  Fds[0].revents := 0;
  Fds[1].fd := ANotifyFd;
  Fds[1].events := POLLIN;
  Fds[1].revents := 0;
  R := poll(@Fds[0], 2, ATimeoutMs);
  AStop := (R > 0) and ((Fds[0].revents <> 0));
  ANotify := (R > 0) and ((Fds[1].revents and POLLIN) <> 0);
  Result := R >= 0;
end;

procedure DrainNotifyFd(AFd: Integer);
var
  Buf: array[0..4095] of Byte;
begin
  while __read(AFd, @Buf[0], SizeOf(Buf)) > 0 do
    ;
end;

constructor TDirectoryWatcher.Create;
begin
  inherited Create;
  FStopFd := -1;
  FThread := nil;
  FPath := '';
  FGen := 0;
  FLife := TWatchLife.Create;
  FLife.Owner := Self;
  FLifeRef := FLife;
end;

destructor TDirectoryWatcher.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TDirectoryWatcher.Close;
begin
  FLife.Owner := nil;
  StopWatcher;
  FPath := '';
end;

procedure TDirectoryWatcher.StopWatcher;
var
  B: Byte;
begin
  Inc(FGen);
  // The thread owns its descriptors and closes them when it leaves. A thread
  // still in setup (an unresponsive mount) is not waited for; it sees the
  // new generation once it publishes and stops itself.
  if FStopFd >= 0 then
  begin
    B := 1;
    __write(FStopFd, @B, 1);
    __close(FStopFd);
    FStopFd := -1;
  end;
  FThread := nil;
end;

procedure TDirectoryWatcher.StartWatcher(const APath: string);
var
  Path: string;
  Gen: Integer;
  Life: TWatchLife;
  LifeRef: IInterface;
begin
  Path := ExcludeTrailingPathDelimiter(APath);
  if Path = '' then
  begin
    FPath := '';
    Exit;
  end;

  FPath := Path; // optimistic: SetPath's same-path check relies on it
  Inc(FGen);
  Gen := FGen;
  Life := FLife;
  LifeRef := FLifeRef;

  FThread := TThread.CreateAnonymousThread(
    procedure
    var
      PipeFds: TPipeDescriptors;
      Nfd, Wd: Integer;
      StopRd, StopWr: Integer;
      LocalGen: Integer;
      PathUtf8: UTF8String;
      Stop, Changed: Boolean;

      procedure QueueGiveUp;
      begin
        TThread.Queue(nil,
          procedure
          begin
            if (Life.Owner <> nil) and (LocalGen = Life.Owner.FGen) then
            begin
              Life.Owner.FPath := '';
              Life.Owner.FThread := nil;
            end;
          end);
      end;

      // The thread closes what it reads from; the write end of the stop pipe
      // belongs to the main thread once published.
      procedure CloseOwn;
      begin
        if Nfd >= 0 then
          __close(Nfd);
        if StopRd >= 0 then
          __close(StopRd);
      end;

    begin
      LocalGen := Gen;
      Nfd := -1;
      StopRd := -1;
      StopWr := -1;

      // Setup touches the file system and can block on an unresponsive
      // network mount, so it runs here and is published to the main thread.
      if not DirectoryExists(Path) then
      begin
        QueueGiveUp;
        Exit;
      end;
      PathUtf8 := UTF8String(Path);
      Nfd := inotify_init1(IN_NONBLOCK or IN_CLOEXEC);
      if Nfd < 0 then
      begin
        QueueGiveUp;
        Exit;
      end;
      Wd := inotify_add_watch(Nfd, MarshaledAString(PathUtf8),
        IN_MODIFY or IN_ATTRIB or IN_MOVED_FROM or IN_MOVED_TO or IN_CREATE or
        IN_DELETE or IN_DELETE_SELF or IN_MOVE_SELF);
      if (Wd < 0) or (pipe(PipeFds) <> 0) then
      begin
        CloseOwn;
        QueueGiveUp;
        Exit;
      end;
      StopRd := PipeFds.ReadDes;
      StopWr := PipeFds.WriteDes;

      // Publish the stop end, or stop this attempt at once when a newer
      // SetPath/Close superseded it during setup.
      TThread.Queue(nil,
        procedure
        var
          Bye: Byte;
        begin
          if (Life.Owner <> nil) and (LocalGen = Life.Owner.FGen) then
          begin
            Life.Owner.FStopFd := StopWr;
            if Assigned(Life.Owner.FOnArmed) then
              Life.Owner.FOnArmed();
          end
          else
          begin
            Bye := 1;
            __write(StopWr, @Bye, 1);
            __close(StopWr);
          end;
        end);

      try
        // The loop ends when the owner writes to the stop pipe.
        while True do
        begin
          if not WaitReadable(Nfd, StopRd, -1, Stop, Changed) then
            Break;
          if Stop or not Changed then
            Break;
          // Drain and debounce bursty events (quiet window cDebounceMs).
          repeat
            DrainNotifyFd(Nfd);
            if not WaitReadable(Nfd, StopRd, cDebounceMs, Stop, Changed) then
              Exit;
            if Stop then
              Exit;
          until not Changed;

          TThread.Queue(nil,
            procedure
            var
              Notify: TDirWatchNotify;
            begin
              if (Life.Owner = nil) or (LocalGen <> Life.Owner.FGen) then
                Exit;
              Notify := Life.Owner.FOnChanged;
              if Assigned(Notify) then
                Notify();
            end);
        end;
      finally
        CloseOwn;
      end;
    end);
  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

function TDirectoryWatcher.Active: Boolean;
begin
  Result := FStopFd >= 0;
end;

procedure TDirectoryWatcher.SetPath(const APath: string);
var
  Path: string;
begin
  Path := NormalizeLocalPath(APath);
  if Path <> '' then
    Path := ExcludeTrailingPathDelimiter(Path);
  if (Path = FPath) and Assigned(FThread) then
    Exit;
  StopWatcher;
  if Path = '' then
  begin
    FPath := '';
    Exit;
  end;
  StartWatcher(Path);
end;

end.
