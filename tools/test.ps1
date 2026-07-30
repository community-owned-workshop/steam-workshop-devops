$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$Tools = Join-Path $Root ".tools"
$Lua = Join-Path $Tools "lua"
$Rocks = Join-Path $Tools "rocks"
$RocksBin = Join-Path $Rocks "bin"
$TestRoot = Join-Path $Root "../tests"
$SourceRoot = Join-Path $Root "../source"
$Busted = Join-Path $Root ".tools/rocks/bin/busted.bat"
$CharacterBaseRoot = Join-Path $Root "../../project-zomboid-characters/source/CowCharactersBase"

if (-not (Test-Path $Lua)) {
    throw "Development tools are missing. Run .\tools\setup.ps1 first. (path $Lua was not found)"
}

if (-not (Test-Path $Busted)) {
    throw "Busted was not found. Run .\tools\setup.ps1 first. (path $Busted was not found)"
}

Push-Location $Root

try {
    $env:PATH = "$Lua;$RocksBin;$env:PATH"

    $env:LUA_PATH = @(
        "$SourceRoot\[MyMod]\42\media\lua\shared\?.lua"
        "$SourceRoot\[MyMod]\42\media\lua\client\?.lua"
        "$SourceRoot\[MyMod]\42\media\lua\shared\?.lua"
        "$SourceRoot\[MyMod]\42\media\lua\client\?.lua"
        "$CharacterBaseRoot\42\media\lua\shared\?.lua"
        "$CharacterBaseRoot\42\media\lua\client\?.lua"
        "$Rocks\share\lua\5.4\?.lua"
        "$Rocks\share\lua\5.4\?\init.lua"
        ";;"
    ) -join ";"

    $env:LUA_CPATH = @(
        "$Rocks\lib\lua\5.4\?.dll"
        ";;"
    ) -join ";"

    chcp 65001 > $null

    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding = [System.Text.UTF8Encoding]::new()

    & $Busted $TestRoot

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    Write-Host "All tests passed."
}
finally {
    Pop-Location
}