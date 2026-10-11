unit TestCmdLinePlatformPaths;

{ Path tokens of the command line: detection and Tab completion follow the
  path rules of the platform, so the same fixture runs on Windows and Posix
  systems. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestCmdLinePlatformPaths = class
  public
    [Test] procedure PathTokenDetection;
    [Test] procedure CompletionKeepsTypedSeparators;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  uPlatformPaths, uDualPanelCmd;

procedure TTestCmdLinePlatformPaths.PathTokenDetection;
begin
  Assert.IsTrue(CmdLineTokenIsPath('sub/file'));
  Assert.IsFalse(CmdLineTokenIsPath('plainname'));
  if PlatformPosixPaths then
  begin
    Assert.IsFalse(CmdLineTokenIsPath('C:'));
    Assert.IsFalse(CmdLineTokenIsPath('a\b'));
  end
  else
  begin
    Assert.IsTrue(CmdLineTokenIsPath('C:'));
    Assert.IsTrue(CmdLineTokenIsPath('a\b'));
  end;
end;

procedure TTestCmdLinePlatformPaths.CompletionKeepsTypedSeparators;
var
  Dir, Sub: string;
  Items: TArray<string>;
begin
  Dir := TPath.Combine(TPath.GetTempPath, 'mtn2_layer_' + IntToStr(Random(MaxInt)));
  Sub := TPath.Combine(Dir, 'alpha');
  TDirectory.CreateDirectory(Sub);
  try
    TFile.WriteAllText(TPath.Combine(Dir, 'alpine.txt'), 'x');
    // An absolute folder part is read as typed: it is not rewritten to the
    // other platform's separator and joined to the base folder.
    Items := CmdLinePathCompletions(IncludeTrailingPathDelimiter(Dir) + 'al', '');
    Assert.AreEqual(2, Integer(Length(Items)));
    Assert.AreEqual('alpha', ExtractFileName(ExcludeTrailingPathDelimiter(Items[0])));
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCmdLinePlatformPaths);

end.
