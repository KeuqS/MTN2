# Compiles the resources of the Linux programs and the Linux tests into
# src\MTN2Tui.dres: everything MTN2Resource.rc embeds, plus RESOURCE_INDEX, a
# list of the resource names, because the Linux runtime cannot enumerate them.
$ErrorActionPreference = 'Stop'
$Src = Split-Path -Parent $PSScriptRoot
$Studio = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$Names = Get-Content (Join-Path $Src 'MTN2Resource.rc') |
    Where-Object { $_ -match '^\s*([A-Z0-9_]+)\s+RCDATA\s' } |
    ForEach-Object { $Matches[1] }
[IO.File]::WriteAllText((Join-Path $Src 'MTN2Tui.index.txt'), ($Names -join "`n") + "`n",
    (New-Object Text.UTF8Encoding $false))
$RcText = (Get-Content (Join-Path $Src 'MTN2Resource.rc') -Raw) +
    "`r`nRESOURCE_INDEX RCDATA `"MTN2Tui.index.txt`"`r`n"
$Rc = Join-Path $Src 'MTN2Tui.rc'
[IO.File]::WriteAllText($Rc, $RcText, (New-Object Text.UTF8Encoding $false))
Push-Location $Src
try {
    & (Join-Path $Studio 'bin\brcc32.exe') -fo(Join-Path $Src 'MTN2Tui.dres') $Rc | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "brcc32 failed with $LASTEXITCODE" }
} finally {
    Pop-Location
}
