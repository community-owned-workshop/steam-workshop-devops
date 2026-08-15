param(
    [string] $MetadataPath = "metadata.json",
    [Parameter(Mandatory = $true)]
    [string] $ModInfoOutputPath
)

$ErrorActionPreference = "Stop"

$Root = if ($env:GITHUB_WORKSPACE) {
    $env:GITHUB_WORKSPACE
}
else {
    (Get-Location).Path
}

function Resolve-ProjectPath {
    param([string] $Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $Root $Path
}

function Assert-Value {
    param(
        [string] $Name,
        [object] $Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string] $Value)) {
        throw "metadata property '$Name' is required."
    }
}

$MetadataPath = Resolve-ProjectPath $MetadataPath
$ModInfoOutputPath = Resolve-ProjectPath $ModInfoOutputPath
$Metadata = Get-Content $MetadataPath -Raw | ConvertFrom-Json

# These fields are Project Zomboid-specific and therefore intentionally live
# outside the generic Steam Workshop metadata generator.
Assert-Value "name" $Metadata.name
Assert-Value "modId" $Metadata.modId
Assert-Value "version" $Metadata.version
Assert-Value "summary" $Metadata.summary
Assert-Value "gameVersionMin" $Metadata.gameVersionMin
Assert-Value "poster" $Metadata.poster

$Authors = @($Metadata.authors)
if ($Authors.Count -eq 0) {
    throw "metadata property 'authors' needs at least one entry."
}
$AuthorsText = $Authors -join ", "

$ModInfo = @(
    "name=$($Metadata.name)"
    "id=$($Metadata.modId)"
    "author=$AuthorsText"
    "description=$($Metadata.summary)"
    "poster=$($Metadata.poster)"
    "modversion=$($Metadata.version)"
    "versionMin=$($Metadata.gameVersionMin)"
)

foreach ($Dependency in @($Metadata.require)) {
    if (-not [string]::IsNullOrWhiteSpace($Dependency)) {
        $ModInfo += "require=$Dependency"
    }
}

$Parent = Split-Path $ModInfoOutputPath -Parent
if ($Parent) {
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
}

[System.IO.File]::WriteAllText(
    $ModInfoOutputPath,
    (($ModInfo -join "`n") + "`n"),
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Generated Project Zomboid mod.info."
