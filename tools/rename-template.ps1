param(
    [string]$Path = (Join-Path $PSScriptRoot "../"),

    [Parameter(Mandatory = $true)]
    [string]$NewName,

    [string]$Placeholder = "[MyMod]"
)

$Path = (Resolve-Path $Path).Path

Write-Host "Replacing '$Placeholder' with '$NewName' in:"
Write-Host "  $Path"
Write-Host ""

# Dateien umbenennen (tiefste zuerst)
Get-ChildItem $Path -Recurse -Force |
        Sort-Object FullName -Descending |
        Where-Object { $_.Name.Contains($Placeholder) } |
        ForEach-Object {
            $newFileName = $_.Name.Replace($Placeholder, $NewName)
            Rename-Item -LiteralPath $_.FullName -NewName $newFileName
        }

# Ordner umbenennen (tiefste zuerst)
Get-ChildItem $Path -Recurse -Directory -Force |
        Sort-Object FullName -Descending |
        Where-Object { $_.Name.Contains($Placeholder) } |
        ForEach-Object {
            $newFolderName = $_.Name.Replace($Placeholder, $NewName)
            Rename-Item -LiteralPath $_.FullName -NewName $newFolderName
        }

# Inhalte von Textdateien ersetzen
$textExtensions = @(
    ".txt", ".lua", ".json", ".xml", ".yml", ".yaml",
    ".ini", ".cfg", ".properties", ".md", ".ps1",
    ".js", ".ts", ".tsx", ".jsx", ".cs", ".java",
    ".c", ".cpp", ".h", ".hpp", ".html", ".css"
)

Get-ChildItem $Path -Recurse -File | ForEach-Object {
    if ($textExtensions -contains $_.Extension.ToLower()) {
        $content = [System.IO.File]::ReadAllText($_.FullName)
        if ($content.Contains($Placeholder)) {
            $content = $content.Replace($Placeholder, $NewName)
            [System.IO.File]::WriteAllText($_.FullName, $content)
            Write-Host "Updated $($_.FullName)"
        }
    }
}

Write-Host ""
Write-Host "Done."