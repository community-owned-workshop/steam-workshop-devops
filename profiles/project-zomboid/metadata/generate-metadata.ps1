param(
    [string] $MetadataPath = "metadata.json",
    [string] $DescriptionPath = "description.md",
    [string] $ReadmeTemplatePath = "tools/templates/README.md",
    [string] $ReadmeOutputPath = "README.md",
    [string] $WorkshopOutputPath = "workshop/workshop.txt",
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

$MetadataPath = Resolve-ProjectPath $MetadataPath
$DescriptionPath = Resolve-ProjectPath $DescriptionPath
$ReadmeTemplatePath = Resolve-ProjectPath $ReadmeTemplatePath
$ReadmeOutputPath = Resolve-ProjectPath $ReadmeOutputPath
$WorkshopOutputPath = Resolve-ProjectPath $WorkshopOutputPath
$ModInfoOutputPath = Resolve-ProjectPath $ModInfoOutputPath
$ToolManifestPath = Join-Path $PSScriptRoot ".config/dotnet-tools.json"

$Metadata = Get-Content $MetadataPath -Raw | ConvertFrom-Json
$Description = (Get-Content $DescriptionPath -Raw).Trim()
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

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
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function ConvertTo-SteamBBCode {
    param([string] $InputPath)

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

        return (Get-Content $OutputPath -Raw).Trim()
    }
    finally {
        Remove-Item $OutputPath -ErrorAction SilentlyContinue
    }
}

Assert-Value "name" $Metadata.name
Assert-Value "modId" $Metadata.modId
Assert-Value "version" $Metadata.version
Assert-Value "summary" $Metadata.summary
Assert-Value "repositoryUrl" $Metadata.repositoryUrl
Assert-Value "gameVersionMin" $Metadata.gameVersionMin
Assert-Value "poster" $Metadata.poster
Assert-Value "workshop.id" $Metadata.workshop.id
Assert-Value "workshop.version" $Metadata.workshop.version

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

$ModInfo = @(
    "name=$($Metadata.name)"
    "id=$($Metadata.modId)"
    "author=$AuthorsText"
    "description=$($Metadata.summary)"
    "poster=$($Metadata.poster)"
    "modversion=$($Metadata.version)"
    "versionMin=$($Metadata.gameVersionMin)"
)

$WorkshopInfo = @(
    "version=$($Metadata.workshop.version)"
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
    "description=[*][b]Mod ID:[/b] $($Metadata.modId)"
    "description=[*][b]Version:[/b] $($Metadata.version)"
    "description=[*][b]Authors:[/b] $AuthorsText"
    "description=[*][b]Minimum game version:[/b] $($Metadata.gameVersionMin)"
    "description=[*][b]Source:[/b] [url=$($Metadata.repositoryUrl)]GitHub[/url]"
    "description=[/list]"
    "tags=$(@($Metadata.workshop.tags) -join ';')"
    "visibility=$($Metadata.workshop.visibility)"
)

$Readme = @"
<!-- Generated file. Edit metadata.json, description.md, or the README template instead. -->

$(Get-Content $ReadmeTemplatePath -Raw)
"@

$Tokens = @{
    "{{NAME}}"             = $Metadata.name
    "{{MOD_ID}}"           = $Metadata.modId
    "{{VERSION}}"          = $Metadata.version
    "{{AUTHORS}}"          = $AuthorsText
    "{{SUMMARY}}"          = $Metadata.summary
    "{{DESCRIPTION}}"      = $Description
    "{{GAME_VERSION_MIN}}" = $Metadata.gameVersionMin
    "{{REPOSITORY_URL}}"   = $Metadata.repositoryUrl
    "{{WORKSHOP_ID}}"      = $Metadata.workshop.id
    "{{WORKSHOP_URL}}"     = "https://steamcommunity.com/sharedfiles/filedetails/?id=$($Metadata.workshop.id)"
}

foreach ($Token in $Tokens.GetEnumerator()) {
    $Readme = $Readme.Replace($Token.Key, [string] $Token.Value)
}

Write-GeneratedFile $ModInfoOutputPath $ModInfo
Write-GeneratedFile $WorkshopOutputPath $WorkshopInfo
Write-GeneratedFile $ReadmeOutputPath @($Readme.TrimEnd())

Write-Host "Generated Project Zomboid metadata."
