unit TestLocalPathLayer;

{ Local path rules that differ between Windows and Posix systems: roots,
  absolute paths, case sensitivity of keys. The
  expectations follow PlatformPosixPaths, so the same fixture runs on both. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestLocalPathLayer = class
  public
    [Test] procedure RootOfAbsolutePath;
    [Test] procedure RelativePathHasNoRoot;
    [Test] procedure AbsolutePathDetection;
    [Test] procedure PathKeyFollowsFileSystemCase;
    [Test] procedure SamePathFollowsFileSystemCase;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  uPlatformPaths, uVfsTypes;

procedure TTestLocalPathLayer.RootOfAbsolutePath;
begin
  if PlatformPosixPaths then
  begin
    Assert.AreEqual('/', LocalPathRootOf('/home/user/doc'));
    Assert.AreEqual('/', LocalPathRootOf('/'));
  end
  else
  begin
    Assert.AreEqual('C:', LocalPathRootOf('C:\Work\doc'));
    Assert.AreEqual('\\host\share', LocalPathRootOf('\\host\share\dir'));
  end;
end;

procedure TTestLocalPathLayer.RelativePathHasNoRoot;
begin
  Assert.AreEqual('', LocalPathRootOf('sub' + PathDelim + 'file.txt'));
  Assert.AreEqual('', LocalPathRootOf(''));
end;

procedure TTestLocalPathLayer.AbsolutePathDetection;
begin
  Assert.IsFalse(IsLocalAbsolutePath(''));
  Assert.IsFalse(IsLocalAbsolutePath('sub' + PathDelim + 'file.txt'));
  if PlatformPosixPaths then
  begin
    Assert.IsTrue(IsLocalAbsolutePath('/usr/bin'));
    Assert.IsFalse(IsLocalAbsolutePath('C:\Work'));
  end
  else
  begin
    Assert.IsTrue(IsLocalAbsolutePath('C:\Work'));
    Assert.IsTrue(IsLocalAbsolutePath('\\host\share\dir'));
    Assert.IsFalse(IsLocalAbsolutePath('/usr/bin'));
  end;
end;

procedure TTestLocalPathLayer.PathKeyFollowsFileSystemCase;
begin
  if PlatformPosixPaths then
    Assert.IsFalse(LocalPathKey('/tmp/A.zip') = LocalPathKey('/tmp/a.zip'))
  else
    Assert.AreEqual(LocalPathKey('C:\Tmp\A.zip'), LocalPathKey('c:\tmp\a.zip'));
end;

procedure TTestLocalPathLayer.SamePathFollowsFileSystemCase;
begin
  if PlatformPosixPaths then
  begin
    Assert.IsFalse(SameLocalPath('/tmp/Dir', '/tmp/dir'));
    Assert.IsTrue(SameLocalPath('/tmp/dir', '/tmp/dir'));
  end
  else
  begin
    Assert.IsTrue(SameLocalPath('C:\Tmp\Dir', 'c:\tmp\dir'));
    Assert.IsFalse(SameLocalPath('C:\Tmp\Dir', 'C:\Tmp\Other'));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLocalPathLayer);

end.
