$ErrorActionPreference = "Stop"

& "$PSScriptRoot\test.ps1"

if ($LASTEXITCODE -gt 0) {
    Write-Host "Mod(s) are faulty and will not be copied into PZ!"
    exit $LASTEXITCODE
}


& "$PSScriptRoot\generate-metadata.ps1"

if ($LASTEXITCODE -gt 0) {
    Write-Host "Could not generate metadata (mod.info, workshop.txt and / or README.md)"
    exit $LASTEXITCODE
}


robocopy `
    ".\source\[MyMod]" `
    "$env:USERPROFILE\Zomboid\mods\[MyMod]" `
    /MIR /NFL /NDL /NJH /NJS

Write-Host "Mod(s) installed at $env:USERPROFILE\Zomboid\mods\[MyMod]"