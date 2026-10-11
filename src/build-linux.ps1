# Builds the terminal program for Linux (mtn2-tui) with the Delphi Linux64 compiler.
# The Linux SDK files (sysroot) come from the IDE's SDK manager: Tools > Options >
# Deployment > SDK Manager, "Ubuntu 22.04/24.04", or an already-fetched copy under
# Documents\Embarcadero\Studio\<version>\PlatformSDKs. No PAServer is needed to build.
#
#   ./src/build-linux.ps1                build bin\linux64\mtn2-tui
#   ./src/build-linux.ps1 -Rebuild       compile everything
#   ./src/build-linux.ps1 -Dump          build, then draw one screen as text in WSL
#   ./src/build-linux.ps1 -NoPlugins     only the program
#
# Native plugins become lib<Name>.so in bin\linux64\plugins\<id> with their manifests;
# libwasmtime.so (WASM plugins) is fetched next to the program.
param(
    [switch]$Rebuild,
    [switch]$Dump,
    [switch]$NoPlugins,
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

$Help = Join-Path $Root 'bin\win64\help'
if (Test-Path $Help) { Copy-Item $Help $OutDir -Recurse -Force }

if (-not $NoPlugins) {
    $PluginsOut = Join-Path $OutDir 'plugins'
    $PluginDcu = Join-Path $Root 'dcu\linux64-plugins'
    New-Item -ItemType Directory -Force $PluginsOut, $PluginDcu | Out-Null
    foreach ($Plugin in Get-ChildItem (Join-Path $Src 'plugins') -Directory) {
        $Dest = Join-Path $PluginsOut $Plugin.Name
        New-Item -ItemType Directory -Force $Dest | Out-Null
        foreach ($Dpr in Get-ChildItem $Plugin.FullName -Filter '*.dpr' -File) {
            $Units = "$Src\Core;$Src\Platform\Posix;$($Plugin.FullName);$($Plugin.FullName)\Posix"
            $Output = & (Join-Path $Studio 'bin\dcclinux64.exe') "--syslibroot:$Sdk" "--libpath:$Libs" '--linker-option:-lstdc++' `
                "-U$Units" "-N0$PluginDcu" "-E$Dest" '-$D-' '-$O+' $Dpr.FullName 2>&1
            if ($LASTEXITCODE -ne 0) {
                $Output | Where-Object { $_ -match 'Error|Fatal' } | ForEach-Object { Write-Host $_ }
                throw "$($Plugin.Name): dcclinux64 failed with $LASTEXITCODE"
            }
            Write-Host "OK: $($Plugin.Name)\lib$($Dpr.BaseName).so"
        }
        Get-ChildItem $Plugin.FullName -File | Where-Object { $_.Extension -in '.json', '.wat', '.wasm', '.md', '.txt' } |
            ForEach-Object { Copy-Item $_.FullName (Join-Path $Dest $_.Name) -Force }
    }
    & (Join-Path $Src 'tools\fetch-wasmtime.ps1') -Linux | Out-Null
    $Wasmtime = Join-Path $Src 'tools\wasmtime\linux64\libwasmtime.so'
    if (Test-Path $Wasmtime) { Copy-Item $Wasmtime $OutDir -Force }
}

if ($Dump) {
    $Wsl = '/mnt/' + $OutDir.Substring(0, 1).ToLower() + $OutDir.Substring(2).Replace('\', '/')
    wsl -d $Distro -- bash -c "cd '$Wsl' && ./mtn2-tui --dump 100 30"
}
