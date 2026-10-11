unit TestSafePath;

{ Name helpers that accept the control characters a Linux file name may
  carry (SafeFileName, SafeExtension, SafeDirectoryName in uVfsTypes). }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestSafePath = class
  public
    [Test] procedure TestPlainPathsFollowTPath;
    [Test] procedure TestControlCharsInTheName;
    [Test] procedure TestControlCharsWithoutExtensionOrFolder;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, uVfsTypes;

const
  cOdd = 'a' + #11 + 'b' + #31 + 'c';

procedure TTestSafePath.TestPlainPathsFollowTPath;
const
  Paths: array[0..3] of string = ('/home/user/doc.txt', 'name.tar.gz', '/etc', 'dir/.hidden');
var
  P: string;
begin
  for P in Paths do
  begin
    Assert.AreEqual(TPath.GetFileName(P), SafeFileName(P), P);
    Assert.AreEqual(TPath.GetExtension(P), SafeExtension(P), P);
    Assert.AreEqual(TPath.GetDirectoryName(P), SafeDirectoryName(P), P);
  end;
end;

procedure TTestSafePath.TestControlCharsInTheName;
var
  Path: string;
begin
  Path := '/data/work/' + cOdd + '.txt';
  Assert.AreEqual(cOdd + '.txt', SafeFileName(Path));
  Assert.AreEqual('.txt', SafeExtension(Path));
  Assert.AreEqual('/data/work', SafeDirectoryName(Path));
end;

procedure TTestSafePath.TestControlCharsWithoutExtensionOrFolder;
begin
  Assert.AreEqual(cOdd, SafeFileName('/' + cOdd));
  Assert.AreEqual('', SafeExtension('/dir/' + cOdd));
  Assert.AreEqual('/', SafeDirectoryName('/' + cOdd));
  Assert.AreEqual('', SafeDirectoryName(cOdd));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSafePath);

end.
