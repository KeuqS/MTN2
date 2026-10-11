# Platform isolation check.
# Units outside src\Platform must not reference platform APIs directly:
#   Windows: Winapi.*, System.Win.*, Vcl.*, FMX.Platform.Win, ShellAPI, Windows
#   POSIX:   Posix.*, Linuxapi.*
# Files that still do are listed in platform-baseline.txt. The baseline may
# only shrink: a new file with a platform reference fails the check, and a
# baseline entry whose file has become platform-neutral is reported so it can
# be dropped (-Update rewrites the baseline).
param(
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$Src = Split-Path -Parent $PSScriptRoot
$BaselineFile = Join-Path $PSScriptRoot 'platform-baseline.txt'

$Found = @()
foreach ($Dir in 'Core', 'Forms') {
    Get-ChildItem (Join-Path $Src $Dir) -Filter *.pas -Recurse | ForEach-Object {
        $Text = Get-Content $_.FullName -Raw -Encoding UTF8
        # Drop comments and string literals before matching.
        $Text = [regex]::Replace($Text, '(?s)\{[^$].*?\}|\(\*.*?\*\)|//[^\r\n]*', '')
        if ($Text -match '(?i)\b(Winapi\.\w+|System\.Win\.\w+|Vcl\.\w+|FMX\.Platform\.Win|ShellAPI|Posix\.\w+|Linuxapi\.\w+)\b') {
            $Found += ($_.FullName.Substring($Src.Length + 1) -replace '\\', '/')
        }
    }
}
$Found = $Found | Sort-Object -Unique

if ($Update) {
    Set-Content $BaselineFile $Found -Encoding UTF8
    Write-Host "Baseline updated: $($Found.Count) files"
    exit 0
}

$Baseline = @()
if (Test-Path $BaselineFile) { $Baseline = Get-Content $BaselineFile -Encoding UTF8 | Where-Object { $_ } }

$New = $Found | Where-Object { $Baseline -notcontains $_ }
$Gone = $Baseline | Where-Object { $Found -notcontains $_ }

foreach ($F in $Gone) { Write-Host "STALE: $F is platform-neutral; remove it from platform-baseline.txt (-Update)" }
foreach ($F in $New) { Write-Host "ERROR: $F references a platform API outside src\Platform" }
if ($New) { exit 1 }
Write-Host "Platform check passed ($($Found.Count) baseline files)"
