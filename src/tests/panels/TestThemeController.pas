unit TestThemeController;

{ The shared theme of a host (Core\uThemeController): loading by id with a
  fallback to the default theme, and live switching. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestThemeController = class
  public
    [Test] procedure TestEmptyIdSelectsTheDefaultTheme;
    [Test] procedure TestUnknownIdFallsBackAndIsReported;
    [Test] procedure TestSwitchToUnknownIdSelectsTheDefaultTheme;
    [Test] procedure TestSwitchKeepsTheSharedTheme;
  end;

implementation

uses
  System.SysUtils, uThemeTypes, uThemeController, uThemeRegistry;

const
  cNoSuchTheme = 'No such theme 8f3a';

procedure TTestThemeController.TestEmptyIdSelectsTheDefaultTheme;
var
  Themes: TThemeController;
begin
  Themes := TThemeController.Create('');
  try
    Assert.AreEqual(DefaultThemeId, Themes.ThemeId);
    Assert.AreEqual('', Themes.MissingId);
    Assert.IsNotNull(Themes.Theme);
  finally
    Themes.Free;
  end;
end;

procedure TTestThemeController.TestUnknownIdFallsBackAndIsReported;
var
  Themes: TThemeController;
begin
  Themes := TThemeController.Create(cNoSuchTheme);
  try
    Assert.AreEqual(DefaultThemeId, Themes.ThemeId);
    Assert.AreEqual(cNoSuchTheme, Themes.MissingId);
  finally
    Themes.Free;
  end;
end;

procedure TTestThemeController.TestSwitchToUnknownIdSelectsTheDefaultTheme;
var
  Themes: TThemeController;
begin
  Themes := TThemeController.Create('');
  try
    Assert.IsTrue(Themes.Switch(cNoSuchTheme));
    Assert.AreEqual(DefaultThemeId, Themes.ThemeId);
  finally
    Themes.Free;
  end;
end;

procedure TTestThemeController.TestSwitchKeepsTheSharedTheme;
var
  Themes: TThemeController;
  Before: IThemeRenderer;
begin
  Themes := TThemeController.Create('');
  try
    Before := Themes.Theme;
    Themes.Switch(DefaultThemeId);
    Assert.IsTrue(Before = Themes.Theme, 'windows keep the same theme object');
  finally
    Themes.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestThemeController);

end.
