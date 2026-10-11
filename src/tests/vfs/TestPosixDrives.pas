unit TestPosixDrives;

{ Volumes on POSIX systems: the quick list names only the mount, the details
  (file system, mount point, sizes) come with PlatformFillDriveDetails, so the
  drive cache knows it still has to query them. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestPosixDrives = class
  public
    [Test] procedure QuickListLeavesDetailsOpen;
    [Test] procedure DetailsNameFileSystemAndMountPoint;
  end;

implementation

uses
  uPlatformPaths, uPlatformDrives, uDriveTypes;

procedure TTestPosixDrives.QuickListLeavesDetailsOpen;
var
  Drives: TDriveInfoArray;
begin
  if not PlatformPosixPaths then
    Exit;
  Drives := PlatformListDrives;
  Assert.IsTrue(Length(Drives) > 0, 'the root file system is listed');
  Assert.AreEqual('', Drives[0].FsName, 'file system comes with the details');
  Assert.AreEqual(Int64(0), Drives[0].TotalBytes, 'sizes come with the details');
end;

procedure TTestPosixDrives.DetailsNameFileSystemAndMountPoint;
var
  Info: TDriveInfo;
begin
  if not PlatformPosixPaths then
    Exit;
  Assert.IsTrue(PlatformDriveByLetter(PlatformDriveLetterOfPath('/'), Info), 'volume of /');
  PlatformFillDriveDetails(Info);
  Assert.AreNotEqual('', Info.FsName, 'file system');
  Assert.AreEqual(Info.RootPath, Info.LabelOrPath, 'the mount point is shown');
  Assert.IsTrue(Info.TotalBytes > 0, 'total size');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPosixDrives);

end.
