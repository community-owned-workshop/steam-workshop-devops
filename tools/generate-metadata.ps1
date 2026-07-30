$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent
$DevOpsRepository = "https://github.com/community-owned-workshop/steam-workshop-devops.git"
$DevOpsVersion = "v1"
$TemporaryDirectory = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("cow-steam-workshop-devops-" + [guid]::NewGuid())

$PreviousRollForward = $env:DOTNET_ROLL_FORWARD
$LocationPushed = $false

try {
    $env:DOTNET_ROLL_FORWARD = "Major"

    git -c advice.detachedHead=false clone `
        --quiet `
        --depth 1 `
        --branch $DevOpsVersion `
        $DevOpsRepository `
        $TemporaryDirectory

    if ($LASTEXITCODE -ne 0) {
        throw "Could not download steam-workshop-devops@$DevOpsVersion."
    }

    Push-Location $Root
    $LocationPushed = $true

    & "$TemporaryDirectory/profiles/project-zomboid/metadata/generate-metadata.ps1" `
        -ModInfoOutputPath "source/[MyMod]/42/mod.info"
}
finally {
    if ($LocationPushed) {
        Pop-Location
    }

    if ($null -eq $PreviousRollForward) {
        Remove-Item Env:DOTNET_ROLL_FORWARD -ErrorAction SilentlyContinue
    }
    else {
        $env:DOTNET_ROLL_FORWARD = $PreviousRollForward
    }

    Remove-Item $TemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}