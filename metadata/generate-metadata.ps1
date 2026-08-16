param(
    [string] $MetadataPath = "metadata.json",
    [string] $DescriptionPath = "description.md",
    [string] $ReadmeTemplatePath = "tools/templates/README.md",
    [string] $ReadmeOutputPath = "README.md",
    [string] $WorkshopOutputPath = "workshop/workshop.txt"
)

$ErrorActionPreference = "Stop"

# All paths are resolved relative to the caller repository. This keeps the
# metadata action reusable from game-specific profiles and directly from mods.
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

function Write-GeneratedFile {
    param(
        [string] $Path,
        [string[]] $Lines
    )

    $Parent = Split-Path $Path -Parent
    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Content = ($Lines -join "`n") + "`n"

    # Write a UTF-8 BOM so Windows/Steam-side consumers reliably detect Unicode
    # instead of interpreting UTF-8 bytes as the active ANSI code page.
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($true)
    )
}

function ConvertTo-SteamBBCode {
    param([string] $InputPath)

    # The converter is intentionally kept in this generic layer: Markdown is
    # the source of truth for both README.md and Steam Workshop descriptions.
    $ToolManifestPath = Join-Path $PSScriptRoot ".config/dotnet-tools.json"
    $OutputPath = [System.IO.Path]::GetTempFileName()

    try {
        $RestoreOutput = & dotnet tool restore --tool-manifest $ToolManifestPath
        $RestoreExitCode = $LASTEXITCODE
        $RestoreOutput | Write-Host

        if ($RestoreExitCode -ne 0) {
            throw "Could not restore the Markdown-to-Steam-BBCode converter."
        }

        Push-Location $PSScriptRoot
        try {
            $ConverterOutput = & dotnet tool run markdown_to_bbcodesteam `
                -- `
                --input $InputPath `
                --output $OutputPath
            $ConverterExitCode = $LASTEXITCODE
            $ConverterOutput | Write-Host

            if ($ConverterExitCode -ne 0) {
                throw "Could not convert the description to Steam BBCode."
            }
        }
        finally {
            Pop-Location
        }

        # The converter writes UTF-8 without a BOM. Windows PowerShell 5.1 would
        # otherwise read that using the active ANSI code page and corrupt Unicode.
        return (Get-Content $OutputPath -Raw -Encoding UTF8).Trim()
    }
    finally {
        Remove-Item $OutputPath -ErrorAction SilentlyContinue
    }
}

$MetadataPath = Resolve-ProjectPath $MetadataPath
$DescriptionPath = Resolve-ProjectPath $DescriptionPath
$ReadmeTemplatePath = Resolve-ProjectPath $ReadmeTemplatePath
$ReadmeOutputPath = Resolve-ProjectPath $ReadmeOutputPath
$WorkshopOutputPath = Resolve-ProjectPath $WorkshopOutputPath

# Explicit UTF-8 is important for local generation under Windows PowerShell 5.1,
# whose default Get-Content encoding is the current ANSI code page for BOM-less files.
$Metadata = Get-Content $MetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$Description = (Get-Content $DescriptionPath -Raw -Encoding UTF8).Trim()

# These fields are intentionally game agnostic. Game profiles may validate and
# consume additional properties from the same metadata.json.
Assert-Value "name" $Metadata.name
Assert-Value "version" $Metadata.version
Assert-Value "summary" $Metadata.summary
Assert-Value "repositoryUrl" $Metadata.repositoryUrl
Assert-Value "workshop.id" $Metadata.workshop.id

$Authors = @($Metadata.authors)
if ($Authors.Count -eq 0) {
    throw "metadata property 'authors' needs at least one entry."
}
foreach ($Author in $Authors) {
    Assert-Value "authors" $Author
}
$AuthorsText = $Authors -join ", "

if ([string]::IsNullOrWhiteSpace($Description)) {
    throw "Description must not be empty."
}

if ($Metadata.workshop.visibility -notin 0, 1, 2, 3) {
    throw "workshop.visibility must be 0, 1, 2, or 3."
}

$WorkshopDescription = ConvertTo-SteamBBCode $DescriptionPath

# workshop.txt is consumed by the generic SteamCMD publisher. The description
# may span multiple lines, therefore every line gets its own description= entry.
$WorkshopInfo = @(
    "id=$($Metadata.workshop.id)"
    "title=$($Metadata.name)"
    "description=[h1]$($Metadata.name)[/h1]"
)
foreach ($DescriptionLine in ($WorkshopDescription -split "\r?\n")) {
    $WorkshopInfo += "description=$DescriptionLine"
}
$WorkshopInfo += @(
    "description="
    "description=[hr][/hr]"
    "description=[h2]Technical information[/h2]"
    "description=[list]"
    "description=[*][b]Version:[/b] $($Metadata.version)"
    "description=[*][b]Authors:[/b] $AuthorsText"
    "description=[*][b]Source:[/b] [url=$($Metadata.repositoryUrl)]GitHub[/url]"
    "description=[/list]"
    "tags=$(@($Metadata.workshop.tags) -join ';')"
    "visibility=$($Metadata.workshop.visibility)"
)

# README templates can provide repository specific framing while description.md
# remains the shared human-readable description used by Steam as well.
$Readme = @"
<!-- Generated file. Edit metadata.json, description.md, or the README template instead. -->

$(Get-Content $ReadmeTemplatePath -Raw -Encoding UTF8)
"@

$Tokens = @{
    "{{NAME}}"           = $Metadata.name
    "{{VERSION}}"        = $Metadata.version
    "{{AUTHORS}}"        = $AuthorsText
    "{{SUMMARY}}"        = $Metadata.summary
    "{{DESCRIPTION}}"    = $Description
    "{{REPOSITORY_URL}}" = $Metadata.repositoryUrl
    "{{WORKSHOP_ID}}"    = $Metadata.workshop.id
    "{{WORKSHOP_URL}}"   = "https://steamcommunity.com/sharedfiles/filedetails/?id=$($Metadata.workshop.id)"
}

foreach ($Token in $Tokens.GetEnumerator()) {
    $Readme = $Readme.Replace($Token.Key, [string] $Token.Value)
}

Write-GeneratedFile $WorkshopOutputPath $WorkshopInfo
Write-GeneratedFile $ReadmeOutputPath @($Readme.TrimEnd())

Write-Host "Generated generic Steam Workshop metadata."
