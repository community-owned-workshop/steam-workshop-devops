param(
    [Parameter(Mandatory = $true)]
    [string]$MetadataPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$metadata = Get-Content -LiteralPath $MetadataPath -Raw | ConvertFrom-Json
$sm = $metadata.scrapMechanic

if (-not $sm) { throw "metadata.json is missing scrapMechanic metadata." }
if (-not $sm.localId) { throw "metadata.json is missing scrapMechanic.localId." }
if (-not $metadata.workshop.id) { throw "metadata.json is missing workshop.id." }

# `version` is the Scrap Mechanic description.json format version, not the mod's
# semantic version. Current files produced by the Scrap Mechanic Mod Tool use 2.
$description = [ordered]@{
    allow_add_mods = if ($null -ne $sm.allowAddMods) { [bool]$sm.allowAddMods } else { $true }
    custom_icons   = if ($null -ne $sm.customIcons) { [bool]$sm.customIcons } else { $false }
    description    = if ($sm.description) { [string]$sm.description } else { [string]$metadata.summary }
    fileId         = [long]$metadata.workshop.id
    localId        = [string]$sm.localId
    name           = [string]$metadata.name
    type           = if ($sm.type) { [string]$sm.type } else { "Blocks and Parts" }
    version        = 2
}

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

$json = $description | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText(
    $OutputPath,
    $json + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Generated Scrap Mechanic metadata: $OutputPath"
