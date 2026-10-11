# Optional Wasmtime C API runtime for WASM plugins (not committed; Apache-2.0).
# Downloads wasmtime.dll into this folder so TestWasmHost / MTN2 can LoadLibrary it;
# with -Linux, libwasmtime.so for the Linux64 build (into wasmtime\linux64).
param(
    [string]$Version = 'v26.0.1',
    [switch]$Linux
)
$ErrorActionPreference = 'Stop'
$LibName = if ($Linux) { 'libwasmtime.so' } else { 'wasmtime.dll' }
$OutDir = $PSScriptRoot + '\wasmtime' + $(if ($Linux) { '\linux64' } else { '' })
$Dll = Join-Path $OutDir $LibName
if (Test-Path $Dll) {
    Write-Host "OK: $Dll"
    exit 0
}
# A copy kept outside the source tree (see cache-dir.ps1) saves the download
# after a clean checkout; the version is part of its path.
$Cache = & (Join-Path $PSScriptRoot 'cache-dir.ps1')
$CachedDll = if ($Cache) { Join-Path $Cache "wasmtime-$Version\$LibName" }
if ($CachedDll -and (Test-Path $CachedDll)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    Copy-Item $CachedDll $Dll -Force
    Write-Host "OK: $Dll (from $CachedDll)"
    exit 0
}
$ZipName = if ($Linux) { "wasmtime-$Version-x86_64-linux-c-api.tar.xz" } else { "wasmtime-$Version-x86_64-windows-c-api.zip" }
$Url = "https://github.com/bytecodealliance/wasmtime/releases/download/$Version/$ZipName"
$Tmp = Join-Path $env:TEMP $ZipName
# The download is retried: a dropped connection must not leave a package
# without the runtime.
for ($Attempt = 1; $Attempt -le 4; $Attempt++) {
    Write-Host "Downloading $Url (attempt $Attempt)"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Tmp -UseBasicParsing
        break
    } catch {
        if ($Attempt -eq 4) { throw }
        Write-Host "WARN: download failed: $_"
        Start-Sleep -Seconds (5 * $Attempt)
    }
}
$Extract = Join-Path $env:TEMP ("wasmtime-" + $Version + "-c-api")
if (Test-Path $Extract) { Remove-Item $Extract -Recurse -Force }
if ($Linux) {
    New-Item -ItemType Directory -Force -Path $Extract | Out-Null
    tar -xf $Tmp -C $Extract '*/lib/libwasmtime.so'
    if ($LASTEXITCODE -ne 0) { throw "cannot unpack $ZipName" }
} else {
    Expand-Archive -Path $Tmp -DestinationPath $Extract -Force
}
$Found = Get-ChildItem -Path $Extract -Filter $LibName -Recurse | Select-Object -First 1
if (-not $Found) { throw "$LibName missing from $ZipName" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Copy-Item $Found.FullName $Dll -Force
if ($CachedDll) {
    New-Item -ItemType Directory -Force -Path (Split-Path $CachedDll) | Out-Null
    Copy-Item $Found.FullName $CachedDll -Force
}
Write-Host "OK: $Dll"
