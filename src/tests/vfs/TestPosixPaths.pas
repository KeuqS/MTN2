unit TestPosixPaths;

{ Local paths and file URIs on a POSIX system: one root, "/" separators,
  case-sensitive names. Windows runs these as no-ops; its paths are covered by
  the other fixtures of this folder. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestPosixPaths = class
  public
    [Test] procedure TestPathToUriAndBack;
    [Test] procedure TestRoot;
    [Test] procedure TestParentAndJoin;
    [Test] procedure TestCaseSensitiveComparison;
    [Test] procedure TestTitles;
    [Test] procedure TestArchiveUris;
    [Test] procedure TestPermissionText;
  end;

implementation

uses
  System.SysUtils, uPlatformPaths, uVfsTypes;

function Skip: Boolean;
begin
  Result := not PlatformPosixPaths;
  if Result then
    Assert.Pass('POSIX only');
end;

procedure TTestPosixPaths.TestPathToUriAndBack;
begin
  if Skip then
    Exit;
  Assert.AreEqual('file:///home/user/docs', PathToFileUri('/home/user/docs'));
  Assert.AreEqual('/home/user/docs', FileUriToPath('file:///home/user/docs'));
  Assert.AreEqual('/home/user/docs', FileUriToPath('file://localhost/home/user/docs'));
  Assert.AreEqual('/home/user/docs', FileUriToPath('file:/home/user/docs'));
  Assert.AreEqual('/home/user/docs', FileUriToPath('/home/user/docs/'), 'a plain path');
  Assert.AreEqual('', FileUriToPath('file://otherhost/share'), 'a remote host is not local');
  Assert.AreEqual('', FileUriToPath('sftp://host/dir'), 'another scheme is not a path');
  // Spaces, percent signs and non-ASCII letters survive the round trip.
  Assert.AreEqual('file:///tmp/a%20b/%D0%B6.txt', PathToFileUri('/tmp/a b/'#$0436'.txt'));
  Assert.AreEqual('/tmp/a b/'#$0436'.txt', FileUriToPath('file:///tmp/a%20b/%D0%B6.txt'));
  Assert.AreEqual('/tmp/50%', FileUriToPath(PathToFileUri('/tmp/50%')));
end;

procedure TTestPosixPaths.TestRoot;
begin
  if Skip then
    Exit;
  Assert.AreEqual('file:///', PathToFileUri('/'));
  Assert.AreEqual('/', FileUriToPath('file:///'));
  Assert.IsTrue(IsVfsUriNavigationRoot('file:///'), 'the root has no parent entry');
  Assert.IsFalse(IsVfsUriNavigationRoot('file:///usr'));
  Assert.AreEqual('file:///', ParentVfsUri('file:///'), 'the parent of the root is the root');
  Assert.AreEqual('file:///', ParentVfsUri('file:///usr'));
end;

procedure TTestPosixPaths.TestParentAndJoin;
begin
  if Skip then
    Exit;
  Assert.AreEqual('file:///usr/lib', ParentVfsUri('file:///usr/lib/x86_64'));
  Assert.AreEqual('file:///usr/lib/x', JoinVfsUri('file:///usr/lib', 'x'));
  Assert.AreEqual('file:///x', JoinVfsUri('file:///', 'x'));
  // A backslash is an ordinary character of a name here.
  Assert.AreEqual('/tmp/a\b', FileUriToPath(JoinVfsUri('file:///tmp', 'a\b')));
end;

procedure TTestPosixPaths.TestCaseSensitiveComparison;
begin
  if Skip then
    Exit;
  Assert.IsTrue(SameVfsUri('file:///tmp/a', 'file:///tmp/a/'));
  Assert.IsFalse(SameVfsUri('file:///tmp/a', 'file:///tmp/A'), 'names differ by case');
  Assert.IsTrue(VfsUriKey('file:///tmp/a') <> VfsUriKey('file:///tmp/A'), 'and so do their keys');
end;

procedure TTestPosixPaths.TestTitles;
begin
  if Skip then
    Exit;
  Assert.AreEqual('/', VfsUriTitle('file:///'));
  Assert.AreEqual('lib', VfsUriTitle('file:///usr/lib'));
  Assert.AreEqual('/', VfsUriDirTabTitle('file:///', 20));
  Assert.AreEqual('/usr/lib', VfsUriDirTabTitle('file:///usr/lib', 20));
  Assert.AreEqual('/.../x86_64', VfsUriDirTabTitle('file:///usr/lib/x86_64', 11));
end;

procedure TTestPosixPaths.TestArchiveUris;
var
  Base: string;
  Segs: TArray<string>;
begin
  if Skip then
    Exit;
  Assert.AreEqual('7z:///home/u/a.7z!/', PathToSevenZipRootUri('/home/u/a.7z'));
  Assert.AreEqual('/home/u/a.7z', ArchiveBaseLocalPath('7z:///home/u/a.7z'));
  Assert.IsTrue(SplitArchiveUri('file:///home/u/a.zip!/dir/f.txt', Base, Segs));
  Assert.AreEqual('file:///home/u/a.zip', Base);
  Assert.AreEqual('dir/f.txt', Segs[0]);
  Assert.AreEqual('/home/u/a.zip', ArchiveBasePath('file:///home/u/a.zip!/dir/f.txt'));
  Assert.AreEqual('file:///home/u', ParentVfsUri('file:///home/u/a.zip!/'),
    'above the archive root is the folder that holds it');
end;

procedure TTestPosixPaths.TestPermissionText;
var
  E: TVfsEntry;
begin
  if Skip then
    Exit;
  E := Default(TVfsEntry);
  E.UnixMode := $1ED; // 0755
  Assert.AreEqual('rwxr-xr-x', FormatVfsAttrText(E));
  E.UnixMode := $1A4; // 0644
  Assert.AreEqual('rw-r--r--', FormatVfsAttrText(E));
  E.UnixMode := $FFF; // 7777
  Assert.AreEqual('rwsrwsrwt', FormatVfsAttrText(E));
  E.UnixMode := $800 or $180; // setuid without execute
  Assert.AreEqual('rwS------', FormatVfsAttrText(E));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPosixPaths);

end.
