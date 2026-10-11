unit TestPosixShellProfiles;

{ The shell catalog of the POSIX build (uShellProfiles in Platform\Posix): the
  login shells of /etc/shells and $SHELL. Windows runs these as no-ops; its
  catalog is covered by TestShellProfiles. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestPosixShellProfiles = class
  public
    [Test] procedure TestCatalogHasALoginShell;
    [Test] procedure TestResolveStartsAnInteractiveShell;
    [Test] procedure TestCopyIdsKeepTheirShell;
    [Test] procedure TestCdLineQuotesThePath;
  end;

implementation

uses
  System.SysUtils, uPlatformPaths, uShellProfiles;

procedure TTestPosixShellProfiles.TestCatalogHasALoginShell;
var
  Profiles: TShellProfileArray;
  P: TShellProfileInfo;
  Found: Boolean;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  Profiles := EnumerateShellProfiles;
  Assert.IsTrue(Length(Profiles) > 0, 'there is at least one shell');
  Found := False;
  for P in Profiles do
    if P.Available then
      Found := True;
  Assert.IsTrue(Found, 'one of them can be started');
  Assert.IsTrue(ShellProfileAvailable(''), 'the empty id is the login shell');
  Assert.AreEqual(NormalizeShellProfileId(''), Profiles[0].Id, 'the login shell comes first');
end;

procedure TTestPosixShellProfiles.TestResolveStartsAnInteractiveShell;
var
  CmdLine, WorkDir: string;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  Assert.IsTrue(ResolveShellCmdLine('', '/tmp', CmdLine, WorkDir), 'the login shell resolves');
  Assert.IsTrue(CmdLine.EndsWith(' -i'), 'it is interactive: ' + CmdLine);
  Assert.AreEqual('/tmp', WorkDir, 'in the requested folder');
  Assert.IsFalse(ResolveShellCmdLine('no-such-shell-mtn2', '/tmp', CmdLine, WorkDir),
    'an unknown shell does not');
  Assert.AreEqual(#13, ProfileReturnSeq(''), 'Enter is a carriage return');
end;

procedure TTestPosixShellProfiles.TestCopyIdsKeepTheirShell;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  Assert.AreEqual('bash', NormalizeShellProfileId('bash#2'));
  Assert.AreEqual('bash#2', CanonicalShellProfileId('bash#2'));
  Assert.AreEqual('#2', ShellProfileCopySuffix('bash#2'));
  Assert.AreEqual('', ShellProfileCopySuffix('bash'));
end;

procedure TTestPosixShellProfiles.TestCdLineQuotesThePath;
begin
  if not PlatformPosixPaths then
  begin
    Assert.Pass('POSIX only');
    Exit;
  end;
  Assert.AreEqual('cd ''/tmp/a b''' + #13, BuildCdLineForProfile('', '/tmp/a b'));
  Assert.AreEqual('cd ''/tmp/it' + '''\''''' + 's''' + #13, BuildCdLineForProfile('', '/tmp/it''s'),
    'a quote in the path is closed, escaped and reopened');
  Assert.AreEqual('', BuildCdLineForProfile('', ''), 'no folder, no line');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPosixShellProfiles);

end.
