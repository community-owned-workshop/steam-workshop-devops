$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$Tools = Join-Path $Root ".tools"
$Lua = Join-Path $Tools "lua"
$LuaRocks = Join-Path $Tools "luarocks"
$Rocks = Join-Path $Tools "rocks"
$Downloads = Join-Path $Tools "downloads"

$LuaVersion = "5.4.8"
$LuaRocksVersion = "3.13.0"

New-Item $Downloads -ItemType Directory -Force | Out-Null

function Install-Zip($Url, $Archive, $Destination) {
    if (Test-Path $Destination) {
        return
    }

    Write-Host "Downloading $Url"

    Invoke-WebRequest `
        -Uri $Url `
        -OutFile $Archive

    New-Item $Destination -ItemType Directory -Force | Out-Null
    Expand-Archive $Archive $Destination
}

Install-Zip `
    "https://joedf.github.io/LuaBuilds/hdata/lua-$($LuaVersion)_Win64_bin.zip" `
    (Join-Path $Downloads "lua.zip") `
    $Lua

$LuaInclude = Join-Path $Lua "include\lua\5.4"

if (-not (Test-Path (Join-Path $LuaInclude "lua.h"))) {
    Write-Host "Installing Lua development headers..."

    $SourceArchive = Join-Path $Downloads "lua-source.tar.gz"
    $SourceDirectory = Join-Path $Downloads "lua-source"

    Invoke-WebRequest `
        -Uri "https://www.lua.org/ftp/lua-$LuaVersion.tar.gz" `
        -OutFile $SourceArchive

    New-Item $SourceDirectory -ItemType Directory -Force | Out-Null
    tar -xzf $SourceArchive -C $SourceDirectory

    New-Item $LuaInclude -ItemType Directory -Force | Out-Null

    Copy-Item `
        (Join-Path $SourceDirectory "lua-$LuaVersion\src\*.h") `
        $LuaInclude
}

Install-Zip `
    "https://luarocks.github.io/luarocks/releases/luarocks-$($LuaRocksVersion)-windows-64.zip" `
    (Join-Path $Downloads "luarocks.zip") `
    $LuaRocks
$CompilerVersion = "2.8.0"
$Compiler = Join-Path $Tools "w64devkit"
$CompilerArchive = Join-Path $Downloads "w64devkit.exe"

if (-not (Test-Path $Compiler)) {
    Write-Host "Installing portable C compiler..."

    $CompilerUrl = "https://github.com/skeeto/w64devkit/releases/download/v$CompilerVersion/w64devkit-x64-$CompilerVersion.7z.exe"

    Remove-Item $CompilerArchive -Force -ErrorAction SilentlyContinue

    & curl.exe `
        --location `
        --fail `
        --retry 3 `
        --retry-delay 2 `
        --output $CompilerArchive `
        $CompilerUrl

    if ($LASTEXITCODE -ne 0) {
        throw "Could not download the C compiler."
    }

    New-Item $Compiler -ItemType Directory -Force | Out-Null

    $process = Start-Process `
        -FilePath $CompilerArchive `
        -ArgumentList "-o$Compiler", "-y" `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        exit $process.ExitCode
    }
}

$CompilerExecutable = Get-ChildItem `
    $Compiler `
    -Filter "x86_64-w64-mingw32-gcc.exe" `
    -Recurse |
        Select-Object -First 1

if (-not $CompilerExecutable) {
    throw "C compiler was not found."
}

$env:PATH = "$($CompilerExecutable.Directory.FullName);$env:PATH"

$LuaRocksExe = Get-ChildItem $LuaRocks -Filter "luarocks.exe" -Recurse |
        Select-Object -First 1 -ExpandProperty FullName

if (-not $LuaRocksExe) {
    throw "LuaRocks executable was not found."
}

Write-Host "Installing Busted..."

& $LuaRocksExe `
    --lua-dir $Lua `
    --lua-version 5.4 `
    --tree $Rocks `
    install busted

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Setup completed."
Write-Host "Run tests with: .\tools\test.ps1"