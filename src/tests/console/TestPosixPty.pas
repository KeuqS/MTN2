unit TestPosixPty;

{ The shell session on a POSIX pseudo-terminal (uConPty in Platform\Posix).
  Windows runs these as no-ops: its sessions are tested by the other
  fixtures of this folder. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestPosixPty = class
  public
    [Test] procedure TestShellRunsACommandAndExits;
    [Test] procedure TestResizeReachesTheShell;
    [Test] procedure TestTerminateEndsARunningCommand;
    [Test] procedure TestUtf8SplitAcrossChunks;
    [Test] procedure TestQueuedCallbacksSurviveASessionFreedAfterExit;
  end;

implementation

uses
  System.SysUtils, System.Classes, uPlatformPaths, uConPty;

function WaitUntil(const APredicate: TFunc<Boolean>; ATimeoutMs: Integer): Boolean;
var
  Waited: Integer;
begin
  Waited := 0;
  while not APredicate() and (Waited < ATimeoutMs) do
  begin
    CheckSynchronize(20);
    Inc(Waited, 20);
  end;
  Result := APredicate();
end;

procedure TTestPosixPty.TestShellRunsACommandAndExits;
var
  S: TConPtySession;
  Output: string;
  Exited: Boolean;
  Code: Cardinal;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  Output := '';
  Exited := False;
  Code := 99;
  S := TConPtySession.Create;
  try
    S.OnOutput :=
      procedure(const AText: string)
      begin
        Output := Output + AText;
      end;
    S.OnExit :=
      procedure(AExitCode: Cardinal)
      begin
        Exited := True;
        Code := AExitCode;
      end;
    Assert.IsTrue(S.StartShell('', '/tmp', 80, 24), 'the shell starts: ' + S.LastError);
    Assert.IsTrue(S.IsRunning, 'it runs');
    Assert.IsTrue(WaitUntil(function: Boolean begin Result := Output <> ''; end, 5000),
      'the shell prints its prompt');
    S.WriteInput('echo mtn2-pty-' + 'ok'#13);
    Assert.IsTrue(WaitUntil(function: Boolean begin Result := Pos('mtn2-pty-ok', Output) > 0; end, 5000),
      'the command output arrives');
    S.WriteInput('exit 7'#13);
    Assert.IsTrue(WaitUntil(function: Boolean begin Result := Exited; end, 5000), 'the exit is reported');
    Assert.AreEqual(7, Integer(Code), 'with the exit code of the shell');
    Assert.IsFalse(S.IsRunning, 'and the session is over');
  finally
    S.Free;
  end;
end;

procedure TTestPosixPty.TestResizeReachesTheShell;
var
  S: TConPtySession;
  Output: string;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  Output := '';
  S := TConPtySession.Create;
  try
    S.OnOutput :=
      procedure(const AText: string)
      begin
        Output := Output + AText;
      end;
    Assert.IsTrue(S.StartShell('', '/tmp', 80, 24), 'the shell starts: ' + S.LastError);
    Assert.IsTrue(WaitUntil(function: Boolean begin Result := Output <> ''; end, 5000));
    S.Resize(100, 30);
    S.WriteInput('stty size'#13);
    Assert.IsTrue(WaitUntil(function: Boolean begin Result := Pos('30 100', Output) > 0; end, 5000),
      'the shell sees 30 rows and 100 columns: ' + Output);
  finally
    S.Free;
  end;
end;

procedure TTestPosixPty.TestTerminateEndsARunningCommand;
var
  S: TConPtySession;
  Output: string;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  Output := '';
  S := TConPtySession.Create;
  try
    S.OnOutput :=
      procedure(const AText: string)
      begin
        Output := Output + AText;
      end;
    Assert.IsTrue(S.StartShell('', '/tmp', 80, 24), 'the shell starts: ' + S.LastError);
    Assert.IsTrue(WaitUntil(function: Boolean begin Result := Output <> ''; end, 5000));
    S.WriteInput('sleep 60'#13);
    Assert.IsTrue(WaitUntil(function: Boolean begin Result := S.HasChildProcess; end, 5000),
      'a command in the foreground is seen');
    S.Terminate;
    Assert.IsFalse(S.IsRunning, 'Terminate ends the session at once');
  finally
    S.Free;
  end;
end;

procedure TTestPosixPty.TestUtf8SplitAcrossChunks;
var
  S: TConPtySession;
  Bytes: TBytes;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  S := TConPtySession.Create;
  try
    // "ж" is D0 B6; a chunk may end between the two bytes.
    Bytes := TBytes.Create($D0);
    Assert.AreEqual('', S.DecodeOutputChunk(Bytes), 'the first byte waits');
    Bytes := TBytes.Create($B6, Ord('a'));
    Assert.AreEqual(#$0436'a', S.DecodeOutputChunk(Bytes), 'the character completes');
  finally
    S.Free;
  end;
end;

procedure TTestPosixPty.TestQueuedCallbacksSurviveASessionFreedAfterExit;
var
  S: TConPtySession;
  Round, I: Integer;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  for Round := 1 to 6 do
  begin
    S := TConPtySession.Create;
    try
      Assert.IsTrue(S.StartShell('', '/tmp', 80, 24), 'the shell starts: ' + S.LastError);
      S.WriteInput('exit'#13);
      // The reader thread queues its last calls while nothing pumps the queue;
      // the session is gone before the main thread runs them.
      Sleep(300);
    finally
      S.Free;
    end;
    for I := 1 to 5 do
      CheckSynchronize(10);
  end;
  Assert.Pass('queued calls ran against released sessions');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPosixPty);

end.
