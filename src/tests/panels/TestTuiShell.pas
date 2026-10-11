unit TestTuiShell;

{ The program behind the text-terminal host (Hosts\Ansi\uTuiShell): it takes
  decoded terminal events and returns the character grid to show. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestTuiShell = class
  public
    [Test] procedure TestComposeShowsThePanels;
    [Test] procedure TestKeysDriveTheWindows;
    [Test] procedure TestResizeReshapesTheScreen;
    [Test] procedure TestQuitKey;
    [Test] procedure TestBytesFromTheTerminal;
    [Test] procedure TestMouseClickOpensAMenu;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  uTerminalTypes, uTermInput, uTuiShell;

function ScreenText(const AGrid: TTerminalGrid): string;
var
  Y, X: Integer;
begin
  Result := '';
  for Y := 0 to High(AGrid) do
  begin
    for X := 0 to High(AGrid[Y]) do
      Result := Result + AGrid[Y][X].CharValue;
    Result := Result + #10;
  end;
end;

function KeyEvent(AKey: Word; AShift: TShiftState = []; AChar: Char = #0): TTermEvent;
begin
  Result := Default(TTermEvent);
  Result.Kind := tekKey;
  Result.Key := AKey;
  Result.KeyChar := AChar;
  Result.Shift := AShift;
end;

function MouseEvent(AAction: TTermMouseAction; ACol, ARow: Integer): TTermEvent;
begin
  Result := Default(TTermEvent);
  Result.Kind := tekMouse;
  Result.MouseAction := AAction;
  Result.Button := TMouseButton.mbLeft;
  Result.Col := ACol;
  Result.Row := ARow;
end;

procedure TTestTuiShell.TestComposeShowsThePanels;
var
  Shell: TTuiShell;
  Text: string;
begin
  Shell := TTuiShell.Create(100, 30);
  try
    Text := ScreenText(Shell.Compose);
    Assert.IsTrue(Text.Contains('Left'), 'the menu bar');
    Assert.IsTrue(Text.Contains('Name'), 'the column header of a panel');
    Assert.IsTrue(Text.Contains('1Help'), 'the key bar');
    Assert.AreEqual(30, Integer(Length(Shell.Compose)), 'one grid row per screen row');
    Assert.AreEqual(100, Integer(Length(Shell.Compose[0])), 'and one cell per column');
  finally
    Shell.Free;
  end;
end;

procedure TTestTuiShell.TestKeysDriveTheWindows;
var
  Shell: TTuiShell;
begin
  Shell := TTuiShell.Create(100, 30);
  try
    Shell.Compose;
    Shell.HandleEvent(KeyEvent(vkF7));
    Assert.IsTrue(Shell.Dirty, 'a key asks for a new frame');
    Assert.IsTrue(ScreenText(Shell.Compose).Contains('Make directory'), 'F7 opens the dialog');
    Assert.IsFalse(Shell.Dirty, 'composing clears the request');
    Shell.HandleEvent(KeyEvent(vkEscape));
    Assert.IsFalse(ScreenText(Shell.Compose).Contains('Make directory'), 'Esc closes it');
  finally
    Shell.Free;
  end;
end;

procedure TTestTuiShell.TestResizeReshapesTheScreen;
var
  Shell: TTuiShell;
  Grid: TTerminalGrid;
begin
  Shell := TTuiShell.Create(100, 30);
  try
    Shell.Resize(70, 20);
    Assert.IsTrue(Shell.Dirty, 'a new size asks for a new frame');
    Grid := Shell.Compose;
    Assert.AreEqual(20, Integer(Length(Grid)));
    Assert.AreEqual(70, Integer(Length(Grid[0])));
    Shell.Resize(5, 2);
    Assert.IsTrue(Shell.Cols >= 20, 'a tiny terminal is clamped to a usable size');
    Assert.IsTrue(Shell.Rows >= 6);
  finally
    Shell.Free;
  end;
end;

procedure TTestTuiShell.TestQuitKey;
var
  Shell: TTuiShell;
begin
  Shell := TTuiShell.Create(100, 30);
  try
    Assert.IsFalse(Shell.Quit);
    Shell.HandleEvent(KeyEvent(vkF10));
    Assert.IsTrue(Shell.Quit, 'F10 asks the loop to end');
  finally
    Shell.Free;
  end;
end;

procedure TTestTuiShell.TestBytesFromTheTerminal;
var
  Shell: TTuiShell;
  Parser: TTermInputParser;
  Events: TList<TTermEvent>;
  Bytes: TBytes;
  E: TTermEvent;
begin
  Shell := TTuiShell.Create(100, 30);
  Parser := TTermInputParser.Create;
  Events := TList<TTermEvent>.Create;
  try
    // F7 as a terminal sends it.
    Bytes := TEncoding.ASCII.GetBytes(#27'[18~');
    Parser.Feed(Bytes, Length(Bytes), Events);
    for E in Events do
      Shell.HandleEvent(E);
    Assert.IsTrue(ScreenText(Shell.Compose).Contains('Make directory'));
    // Text typed into the dialog lands in its input.
    Events.Clear;
    Bytes := TEncoding.UTF8.GetBytes('abc');
    Parser.Feed(Bytes, Length(Bytes), Events);
    for E in Events do
      Shell.HandleEvent(E);
    Assert.IsTrue(ScreenText(Shell.Compose).Contains('abc'), 'typed text is shown');
  finally
    Events.Free;
    Parser.Free;
    Shell.Free;
  end;
end;

procedure TTestTuiShell.TestMouseClickOpensAMenu;
var
  Shell: TTuiShell;
begin
  Shell := TTuiShell.Create(100, 30);
  try
    Shell.Compose;
    // The first menu item sits at the left end of the top row.
    Shell.HandleEvent(MouseEvent(tmaPress, 4, 0));
    Shell.HandleEvent(MouseEvent(tmaRelease, 4, 0));
    Assert.IsTrue(Shell.Dirty, 'a click asks for a new frame');
    Assert.IsTrue(ScreenText(Shell.Compose).Contains('Drive selection'), 'the Left menu opens');
  finally
    Shell.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTuiShell);

end.
