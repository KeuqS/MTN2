# Pack the terminal program (after src\build-linux.ps1) into
#   dist\MTN2-<Version>-linux-x64.tar.gz
# The archive holds a folder mtn2\ with the program, the F1 help, the plugins
# built by build-linux.ps1 (native .so libraries, manifests, WASM modules) and
# libwasmtime.so, a version file, the license texts and the Linux notes. tar runs in WSL so that the program keeps its execute bit.
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [string]$Distro = 'Ubuntu-24.04'
)
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Bin = Join-Path $Root 'bin'
$Program = Join-Path $Bin 'linux64\mtn2-tui'
if (-not (Test-Path $Program)) { throw 'bin\linux64\mtn2-tui not found; run src\build-linux.ps1 first' }

$Dist = Join-Path $Root 'dist'
$Stage = Join-Path $Dist 'linux-stage\mtn2'
if (Test-Path (Join-Path $Dist 'linux-stage')) { Remove-Item (Join-Path $Dist 'linux-stage') -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'plugins') | Out-Null

Copy-Item $Program $Stage
$PluginsBuilt = Join-Path $Bin 'linux64\plugins'
if (Test-Path $PluginsBuilt) { Copy-Item (Join-Path $PluginsBuilt '*') (Join-Path $Stage 'plugins') -Recurse -Force }
$Wasmtime = Join-Path $Bin 'linux64\libwasmtime.so'
if (Test-Path $Wasmtime) { Copy-Item $Wasmtime $Stage }
$Help = Join-Path $Bin 'linux64\help'
if (Test-Path $Help) { Copy-Item $Help (Join-Path $Stage 'help') -Recurse }
Copy-Item (Join-Path $Root 'LICENSE') $Stage
Copy-Item (Join-Path $Root 'THIRD-PARTY.md') $Stage
Copy-Item (Join-Path $Root 'CHANGELOG.md') $Stage
Copy-Item (Join-Path $Root 'docs\LINUX.md') $Stage
# The program has no version resource on Linux; it reads this file (uPlatformUpdate).
[IO.File]::WriteAllText((Join-Path $Stage 'version'), ($Version -replace '^v', '') + "`n", (New-Object Text.UTF8Encoding $false))

$Safe = $Version -replace '[^\w.\-]', '_'
$Archive = Join-Path $Dist "MTN2-$Safe-linux-x64.tar.gz"
if (Test-Path $Archive) { Remove-Item $Archive -Force }

function ConvertTo-WslPath([string]$Path) {
    '/mnt/' + $Path.Substring(0, 1).ToLower() + $Path.Substring(2).Replace('\', '/')
}
$WslStage = ConvertTo-WslPath (Split-Path $Stage -Parent)
$WslArchive = ConvertTo-WslPath $Archive
wsl -d $Distro -- bash -c "cd '$WslStage' && chmod 755 mtn2/mtn2-tui && tar czf '$WslArchive' --owner=0 --group=0 mtn2"
if ($LASTEXITCODE -ne 0) { throw "tar failed with $LASTEXITCODE" }
Remove-Item (Join-Path $Dist 'linux-stage') -Recurse -Force
Write-Host "OK: $Archive"
