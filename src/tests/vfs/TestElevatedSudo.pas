unit TestElevatedSudo;

{ Administrator operations through sudo (POSIX build): the password goes to
  "sudo -S -v" once, later commands rely on the credential cache, and a
  session that is not open yet asks through OnAuthenticate first. A stand-in
  sudo script on the search path plays the system's; on Windows, where the
  helper process does this work, the fixture is a no-op. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestElevatedSudo = class
  private
    FDir: string;
    FOldPath: string;
    procedure InstallFakeSudo;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure PasswordOpensTheSession;
    [Test] procedure OperationsAskForThePasswordFirst;
    [Test] procedure RefusedPasswordFailsTheOperation;
    [Test] procedure CopyKeepsAnExistingTargetUnlessOverwriting;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils,
  uPlatformPaths, uPlatformProcess, uPlatformFileAttr, uFileAttrTypes, uVfsTypes,
  uTextEncoding, uElevatedVfs;

const
  cFakeSudo =
    '#!/bin/sh'#10 +
    'state="$FAKE_SUDO_STATE"'#10 +
    'if [ "$1" = "-V" ]; then echo "Sudo version 1.9"; exit 0; fi'#10 +
    'if [ "$1" = "-S" ]; then'#10 +
    '  read pw'#10 +
    '  if [ "$pw" = "secret" ]; then touch "$state"; exit 0; fi'#10 +
    '  echo "Sorry, try again."; exit 1'#10 +
    'fi'#10 +
    'shift'#10 +
    'if [ ! -e "$state" ]; then echo "sudo: a password is required"; exit 1; fi'#10 +
    'if [ "$1" = "-v" ]; then exit 0; fi'#10 +
    'exec "$@"'#10;

function Pump(const AIsDone: TFunc<Boolean>): Boolean;
var
  Stop: UInt64;
begin
  Stop := TThread.GetTickCount64 + 15000;
  while (TThread.GetTickCount64 < Stop) and not AIsDone() do
    CheckSynchronize(10);
  Result := AIsDone();
end;

procedure TTestElevatedSudo.InstallFakeSudo;
var
  Script: string;
  Plan: TFileAttrPlan;
  Err: string;
begin
  Script := TPath.Combine(FDir, 'sudo');
  TFile.WriteAllText(Script, cFakeSudo, TEncoding.ASCII);
  Plan := Default(TFileAttrPlan);
  Plan.ChangeMode := True;
  Plan.Mode := $1ED;
  Assert.IsTrue(ApplyFileAttrOne(Script, Plan, Err), Err);
  FOldPath := GetEnvironmentVariable('PATH');
  PlatformSetEnvironment('PATH', FDir + ':' + FOldPath);
  PlatformSetEnvironment('FAKE_SUDO_STATE', TPath.Combine(FDir, 'session'));
end;

procedure TTestElevatedSudo.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'mtn2-sudo-' + TPath.GetGUIDFileName(False));
  TDirectory.CreateDirectory(FDir);
  FOldPath := '';
  if PlatformPosixPaths then
    InstallFakeSudo;
end;

procedure TTestElevatedSudo.TearDown;
begin
  if FOldPath <> '' then
    PlatformSetEnvironment('PATH', FOldPath);
  TDirectory.Delete(FDir, True);
end;

procedure TTestElevatedSudo.PasswordOpensTheSession;
var
  Err: string;
begin
  if not PlatformPosixPaths then
    Exit;
  Assert.IsFalse(ElevatedSessionOpen, 'no session at first');
  Assert.IsFalse(ElevatedAuthenticate('wrong', Err), 'wrong password refused');
  Assert.AreNotEqual('', Err, 'the refusal says why');
  Assert.IsFalse(ElevatedSessionOpen, 'still closed');
  Assert.IsTrue(ElevatedAuthenticate('secret', Err), Err);
  Assert.IsTrue(ElevatedSessionOpen, 'open after the right password');
end;

procedure TTestElevatedSudo.OperationsAskForThePasswordFirst;
var
  Vfs: TElevatedFileVfs;
  Keep: IVirtualFileSystem;
  Dir, Src, Dst, Text: string;
  Asked, Finished, Ok, ActiveSeen: Boolean;
begin
  if not PlatformPosixPaths then
    Exit;
  Vfs := TElevatedFileVfs.Create(nil);
  Keep := Vfs;
  try
    Asked := False;
    ActiveSeen := False;
    Vfs.OnAuthenticate :=
      procedure(const ADone: TProc<Boolean>)
      var
        Err: string;
      begin
        Asked := True;
        ADone(ElevatedAuthenticate('secret', Err));
      end;
    Vfs.OnActiveChanged := procedure(AActive: Boolean) begin ActiveSeen := AActive; end;

    Dir := TPath.Combine(FDir, 'made');
    Finished := False;
    Ok := False;
    Vfs.CreateDirectoryAsync(PathToFileUri(Dir), nil,
      procedure(const ASuccess: Boolean; const AError: TVfsError)
      begin
        Ok := ASuccess;
        Finished := True;
      end);
    Assert.IsTrue(Pump(function: Boolean begin Result := Finished; end), 'mkdir finishes');
    Assert.IsTrue(Asked, 'the password was asked for');
    Assert.IsTrue(Ok and TDirectory.Exists(Dir), 'folder created');
    Assert.IsTrue(ActiveSeen and Vfs.IsActive, 'rights reported active');

    Asked := False;
    Src := TPath.Combine(Dir, 'a.txt');
    Dst := TPath.Combine(Dir, 'b.txt');
    Finished := False;
    Vfs.WriteTextAsync(PathToFileUri(Src), 'hello', tfeUtf8, nil,
      procedure(const ASuccess: Boolean; const AError: TVfsError)
      begin
        Ok := ASuccess;
        Finished := True;
      end);
    Assert.IsTrue(Pump(function: Boolean begin Result := Finished; end), 'write finishes');
    Assert.IsFalse(Asked, 'an open session does not ask again');
    Assert.IsTrue(Ok, 'text written');
    Text := TFile.ReadAllText(Src, TEncoding.UTF8);
    Assert.AreEqual('hello', Text, 'text content');

    Finished := False;
    Vfs.MoveAsync(PathToFileUri(Src), PathToFileUri(Dst), nil, nil,
      procedure(const ASuccess: Boolean; const AError: TVfsError)
      begin
        Ok := ASuccess;
        Finished := True;
      end);
    Assert.IsTrue(Pump(function: Boolean begin Result := Finished; end), 'move finishes');
    Assert.IsTrue(Ok and TFile.Exists(Dst) and not TFile.Exists(Src), 'file moved');

    Finished := False;
    Vfs.DeleteAsync(PathToFileUri(Dir), vdmPermanent, nil, nil,
      procedure(const ASuccess: Boolean; const AError: TVfsError)
      begin
        Ok := ASuccess;
        Finished := True;
      end);
    Assert.IsTrue(Pump(function: Boolean begin Result := Finished; end), 'delete finishes');
    Assert.IsTrue(Ok and not TDirectory.Exists(Dir), 'folder removed with its content');
  finally
    Vfs.Shutdown;
    Keep := nil;
  end;
end;

procedure TTestElevatedSudo.RefusedPasswordFailsTheOperation;
var
  Vfs: TElevatedFileVfs;
  Keep: IVirtualFileSystem;
  Dir: string;
  Finished, Ok: Boolean;
  Code: TVfsErrorCode;
begin
  if not PlatformPosixPaths then
    Exit;
  Vfs := TElevatedFileVfs.Create(nil);
  Keep := Vfs;
  try
    Vfs.OnAuthenticate :=
      procedure(const ADone: TProc<Boolean>)
      begin
        ADone(False);
      end;
    Dir := TPath.Combine(FDir, 'never');
    Finished := False;
    Ok := True;
    Code := vecOk;
    Vfs.CreateDirectoryAsync(PathToFileUri(Dir), nil,
      procedure(const ASuccess: Boolean; const AError: TVfsError)
      begin
        Ok := ASuccess;
        Code := AError.Code;
        Finished := True;
      end);
    Assert.IsTrue(Pump(function: Boolean begin Result := Finished; end), 'mkdir finishes');
    Assert.IsFalse(Ok, 'the operation fails');
    Assert.AreEqual(Ord(vecAccessDenied), Ord(Code), 'access denied');
    Assert.IsFalse(TDirectory.Exists(Dir), 'nothing created');
    Assert.IsFalse(Vfs.IsActive, 'not active');
  finally
    Vfs.Shutdown;
    Keep := nil;
  end;
end;

procedure TTestElevatedSudo.CopyKeepsAnExistingTargetUnlessOverwriting;
var
  Vfs: TElevatedFileVfs;
  Keep: IVirtualFileSystem;
  Src, Dst, Err: string;
  Finished, Ok: Boolean;
  Code: TVfsErrorCode;
begin
  if not PlatformPosixPaths then
    Exit;
  Assert.IsTrue(ElevatedAuthenticate('secret', Err), Err);
  Src := TPath.Combine(FDir, 'src.txt');
  Dst := TPath.Combine(FDir, 'dst.txt');
  TFile.WriteAllText(Src, 'new', TEncoding.UTF8);
  TFile.WriteAllText(Dst, 'old', TEncoding.UTF8);
  Vfs := TElevatedFileVfs.Create(nil);
  Keep := Vfs;
  try
    Finished := False;
    Vfs.CopyAsync(PathToFileUri(Src), PathToFileUri(Dst), nil, nil,
      procedure(const ASuccess: Boolean; const AError: TVfsError)
      begin
        Ok := ASuccess;
        Code := AError.Code;
        Finished := True;
      end);
    Assert.IsTrue(Pump(function: Boolean begin Result := Finished; end), 'copy finishes');
    Assert.IsFalse(Ok, 'no silent overwrite');
    Assert.AreEqual(Ord(vecAlreadyExists), Ord(Code), 'reported as existing');
    Assert.AreEqual('old', TFile.ReadAllText(Dst, TEncoding.UTF8), 'target untouched');

    Finished := False;
    Vfs.CopyAsync(PathToFileUri(Src), PathToFileUri(Dst), nil, nil,
      procedure(const ASuccess: Boolean; const AError: TVfsError)
      begin
        Ok := ASuccess;
        Finished := True;
      end, True);
    Assert.IsTrue(Pump(function: Boolean begin Result := Finished; end), 'overwrite finishes');
    Assert.IsTrue(Ok, 'overwrite allowed');
    Assert.AreEqual('new', TFile.ReadAllText(Dst, TEncoding.UTF8), 'target replaced');
  finally
    Vfs.Shutdown;
    Keep := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestElevatedSudo);

end.
