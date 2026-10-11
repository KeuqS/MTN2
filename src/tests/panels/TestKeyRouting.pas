unit TestKeyRouting;

{ The key predicates and the window routing shared by every host
  (Core\uKeyRouting). }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestKeyRouting = class
  public
    [Test] procedure TestBareEscapeNeedsNoModifier;
    [Test] procedure TestModifierOnlyKeys;
    [Test] procedure TestConsoleScrollAndSelectionKeys;
    [Test] procedure TestMissingWindowsTakeNoKey;
  end;

implementation

uses
  System.Classes, System.UITypes, uKeyRouting;

procedure TTestKeyRouting.TestBareEscapeNeedsNoModifier;
begin
  Assert.IsTrue(IsBareEscape(vkEscape, []));
  Assert.IsFalse(IsBareEscape(vkEscape, [ssCtrl]));
  Assert.IsFalse(IsBareEscape(vkReturn, []));
end;

procedure TTestKeyRouting.TestModifierOnlyKeys;
begin
  Assert.IsTrue(IsModifierOnlyKey(vkShift));
  Assert.IsTrue(IsModifierOnlyKey(vkControl));
  Assert.IsTrue(IsModifierOnlyKey(vkMenu));
  Assert.IsTrue(IsModifierOnlyKey(vkRMenu));
  Assert.IsFalse(IsModifierOnlyKey(Ord('A')));
  Assert.IsFalse(IsModifierOnlyKey(vkF1));
end;

procedure TTestKeyRouting.TestConsoleScrollAndSelectionKeys;
begin
  Assert.IsTrue(IsConsoleScrollOrSelectionKey(vkUp, #0, []));
  Assert.IsTrue(IsConsoleScrollOrSelectionKey(vkPrior, #0, [ssShift]));
  Assert.IsTrue(IsConsoleScrollOrSelectionKey(Ord('C'), 'c', [ssCtrl]));
  Assert.IsTrue(IsConsoleScrollOrSelectionKey(Ord('A'), 'a', [ssCtrl]));
  Assert.IsFalse(IsConsoleScrollOrSelectionKey(Ord('C'), 'c', []));
  Assert.IsFalse(IsConsoleScrollOrSelectionKey(Ord('C'), 'c', [ssCtrl, ssAlt]));
  Assert.IsFalse(IsConsoleScrollOrSelectionKey(vkReturn, #13, []));
end;

procedure TTestKeyRouting.TestMissingWindowsTakeNoKey;
var
  Key: Word;
  Ch: Char;
begin
  Key := vkReturn;
  Ch := #13;
  Assert.IsFalse(RouteTerminalKey(nil, nil, nil, Key, Ch, []));
  Assert.IsFalse(SyncKeyModifiers(nil, nil, [ssCtrl]));
  Assert.IsFalse(IsConsoleActiveInConsoleMode(nil, nil, nil));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestKeyRouting);

end.
