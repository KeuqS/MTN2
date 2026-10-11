unit uTestPaths;

{ Path literals of the fixtures are written with "/" or "\" and made native
  here, so a fixture builds the same folder tree on every platform. }

interface

/// <summary>APath with every "/" and "\" turned into the platform's separator.</summary>
function NativePath(const APath: string): string;

implementation

uses
  System.SysUtils;

function NativePath(const APath: string): string;
begin
  Result := StringReplace(StringReplace(APath, '\', PathDelim, [rfReplaceAll]),
    '/', PathDelim, [rfReplaceAll]);
end;

end.
