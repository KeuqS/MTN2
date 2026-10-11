# Builds the terminal program for Linux (mtn2-tui) with the Delphi Linux64 compiler.
# The Linux SDK files (sysroot) come from the IDE's SDK manager: Tools > Options >
# Deployment > SDK Manager, "Ubuntu 22.04/24.04", or an already-fetched copy under
# Documents\Embarcadero\Studio\<version>\PlatformSDKs. No PAServer is needed to build.
#
#   ./src/build-linux.ps1                build bin\linux64\mtn2-tui
#   ./src/build-linux.ps1 -Rebuild       compile everything
#   ./src/build-linux.ps1 -Dump          build, then draw one screen as text in WSL
param(
    [switch]$Rebuild,
    [switch]$Dump,
    [string]$Distro = 'Ubuntu-24.04',
    [string]$Sdk = ''
)

$ErrorActionPreference = 'Stop'
$Studio = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$Src = $PSScriptRoot
$Root = Split-Path -Parent $Src
if (-not $Sdk) { $Sdk = Join-Path $env:USERPROFILE 'Documents\Embarcadero\Studio\37.0\PlatformSDKs\Linux64.sdk' }
if (-not (Test-Path $Sdk)) { throw "Linux SDK not found: $Sdk" }

$OutDir = Join-Path $Root 'bin\linux64'
$DcuDir = Join-Path $Root 'dcu\linux64'
New-Item -ItemType Directory -Force $OutDir, $DcuDir | Out-Null

& (Join-Path $Src 'tools\make-linux-resources.ps1')
Push-Location $Src
try {
    $Rtl = Join-Path $Studio 'lib\linux64\release'
    $Libs = "$Rtl;$Sdk\usr\lib\x86_64-linux-gnu;$Sdk\lib\x86_64-linux-gnu;$Sdk\usr\lib\gcc\x86_64-linux-gnu\13"
    $Units = "$Src\Core;$Src\Platform\Posix;$Src\Hosts\Ansi"
    $Args = @("--syslibroot:$Sdk", "--libpath:$Libs", '--linker-option:-lstdc++',
        "-U$Units", "-I$Units", "-N0$DcuDir", "-E$OutDir", '-V', '-$D-', '-$O+')
    if ($Rebuild) { $Args += '-B' }
    $Output = & (Join-Path $Studio 'bin\dcclinux64.exe') @Args (Join-Path $Src 'MTN2Tui.dpr') 2>&1
    $Output | Where-Object { $_ -match 'Error|Fatal|Warning: W1' } | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "dcclinux64 failed with $LASTEXITCODE" }
    Move-Item -Force (Join-Path $OutDir 'MTN2Tui') (Join-Path $OutDir 'mtn2-tui')
    Write-Host "OK: $OutDir\mtn2-tui"
} finally {
    Pop-Location
}

if ($Dump) {
    $Wsl = '/mnt/' + $OutDir.Substring(0, 1).ToLower() + $OutDir.Substring(2).Replace('\', '/')
    wsl -d $Distro -- bash -c "cd '$Wsl' && ./mtn2-tui --dump 100 30"
}
