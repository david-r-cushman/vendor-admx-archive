<#
.SYNOPSIS
Initializes or registers an administrative-template release.

.DESCRIPTION
Initializes a new release directory with source/ and extracted/ folders, or
creates a manifest.json file for an existing release directory. Registration
records release provenance and SHA-256 hashes for every original file under
versions/<release>/source/. It never overwrites an existing manifest or
modifies source files.

.PARAMETER ReleaseId
The name of a new release directory to initialize or an existing release
directory to register. It must be a single directory name, not a path.

.PARAMETER Vendor
The vendor that supplied the original download files.

.PARAMETER Product
The product represented by the release.

.PARAMETER Version
The vendor's version identifier for the release.

.PARAMETER SourcePageUrl
The vendor page from which the release was obtained.

.PARAMETER DownloadUrls
An optional hashtable that maps each source-relative file path to its direct
download URL. Each key becomes a manifest Path and its value becomes that
file's DownloadUrl.

.PARAMETER GenerateSplat
Writes an editable parameter hashtable instead of registering a release. Use it
to copy a starting splat, fill in the values, and invoke this script with the
completed hashtable.

.PARAMETER InitializeRelease
Creates a new versions/<release>/ directory with source/ and extracted/
subdirectories. This mode does not download files or create a manifest.

.OUTPUTS
PSCustomObject. Initialization returns ReleaseId, ReleasePath, SourcePath, and
ExtractedPath. Registration returns ReleaseId, ManifestPath, SourceFileCount,
and RegisteredAtUtc. Failures throw an error and do not return a result object.

.EXAMPLE
PS> .\scripts\Register-AdmxRelease.ps1 -InitializeRelease -ReleaseId '1.2.3'

Creates a new release layout with source/ and extracted/ folders.

.EXAMPLE
PS> .\scripts\Register-AdmxRelease.ps1 @registration

Registers the release using values prepared in the $Params hashtable.

.EXAMPLE
PS> .\scripts\Register-AdmxRelease.ps1 -GenerateSplat

Writes an editable splat to the pipeline.

.EXAMPLE
PS> .\scripts\Register-AdmxRelease.ps1 -GenerateSplat | Clip

On Windows, copies the generated splat to the clipboard. Run this form from the
repository root. The Clip command is not available on Linux or macOS.

.NOTES
On Linux and macOS, run the script from PowerShell with
./scripts/Register-AdmxRelease.ps1. Clipboard commands depend on the local
desktop environment and are intentionally not required by this script.
#>
[CmdletBinding(DefaultParameterSetName = 'Register')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Register')]
    [Parameter(Mandatory, ParameterSetName = 'InitializeRelease')]
    [string]$ReleaseId,

    [Parameter(Mandatory, ParameterSetName = 'Register')]
    [string]$Vendor,

    [Parameter(Mandatory, ParameterSetName = 'Register')]
    [string]$Product,

    [Parameter(Mandatory, ParameterSetName = 'Register')]
    [string]$Version,

    [Parameter(Mandatory, ParameterSetName = 'Register')]
    [string]$SourcePageUrl,

    [Parameter(ParameterSetName = 'Register')]
    [hashtable]$DownloadUrls,

    [Parameter(Mandatory, ParameterSetName = 'GenerateSplat')]
    [switch]$GenerateSplat,

    [Parameter(Mandatory, ParameterSetName = 'InitializeRelease')]
    [switch]$InitializeRelease
)

. (Join-Path -Path $PSScriptRoot -ChildPath 'private/Test-AdmxManifest.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'private/Test-AdmxSourcePath.ps1')

if ($GenerateSplat) {
    @'
$Params = @{
    ReleaseId     = ''
    Vendor        = ''
    Product       = ''
    Version       = ''
    SourcePageUrl = ''
    DownloadUrls  = @{
        '<source-relative-file-1>' = '<download-url-1>'
        '<source-relative-file-2>' = '<download-url-2>'
    }
}
'@
    return
}

if (
    $ReleaseId -in @('.', '..') -or
    $ReleaseId -match '[/\\]' -or
    [string]::IsNullOrWhiteSpace($ReleaseId)
) {
    throw "Invalid ReleaseId: '$ReleaseId'. Supply a single directory name."
}

$RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$ReleasePath = Join-Path -Path $RepositoryRoot -ChildPath 'versions' -AdditionalChildPath $ReleaseId
$SourcePath = Join-Path -Path $ReleasePath -ChildPath 'source'
$ExtractedPath = Join-Path -Path $ReleasePath -ChildPath 'extracted'

if ($InitializeRelease) {
    if (Test-Path -LiteralPath $ReleasePath) {
        throw "Release path already exists: $ReleasePath"
    }

    $CreatedPaths = [System.Collections.Generic.List[string]]::new()

    try {
        foreach ($DirectoryPath in @($ReleasePath, $SourcePath, $ExtractedPath)) {
            $Directory = New-Item -ItemType Directory -Path $DirectoryPath -ErrorAction Stop
            $CreatedPaths.Add($Directory.FullName)
        }
    }
    catch {
        for ($Index = $CreatedPaths.Count - 1; $Index -ge 0; $Index--) {
            Remove-Item -LiteralPath $CreatedPaths[$Index] -Force -ErrorAction SilentlyContinue
        }

        throw
    }

    [PSCustomObject]@{
        ReleaseId     = $ReleaseId
        ReleasePath   = $ReleasePath
        SourcePath    = $SourcePath
        ExtractedPath = $ExtractedPath
    }

    return
}

if (-not (Test-Path -LiteralPath $ReleasePath -PathType Container)) {
    throw "Release directory does not exist: $ReleasePath"
}

$ManifestPath = Join-Path -Path $ReleasePath -ChildPath 'manifest.json'

if (Test-Path -LiteralPath $ManifestPath) {
    throw "Release '$ReleaseId' is already registered or contains a manifest.json. Registration aborted."
}

if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
    throw "Source directory does not exist: $SourcePath"
}

$SourceRootItem = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop

if ($SourceRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    throw "Source directory is a reparse point: $SourcePath"
}

$SourceItems = @(Get-ChildItem -LiteralPath $SourcePath -Recurse -Force -ErrorAction Stop)

foreach ($Item in $SourceItems) {
    if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Source directory contains a reparse point: $($Item.FullName)"
    }
}

$SourceFiles = @($SourceItems | Where-Object {
    -not $_.PSIsContainer -and $_.Name -ne '.gitkeep'
})

if ($SourceFiles.Count -eq 0) {
    throw "No source files found in: $SourcePath"
}

$SourceInventory = @(
    foreach ($File in $SourceFiles) {
        $RelativePath = [System.IO.Path]::GetRelativePath(
            $SourcePath,
            $File.FullName
        ).Replace('\', '/')

        Test-AdmxSourcePath -SourceRoot $SourcePath -RelativePath $RelativePath
        $FileHash = Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256 -ErrorAction Stop

        $FileRecord = [ordered]@{
            Path   = $RelativePath
            SHA256 = $FileHash.Hash
        }

        if ($DownloadUrls -and $DownloadUrls.ContainsKey($RelativePath)) {
            $FileRecord['DownloadUrl'] = $DownloadUrls[$RelativePath]
        }

        [PSCustomObject]$FileRecord
    }
)

$Manifest = [PSCustomObject]@{
    ReleaseId       = $ReleaseId
    Vendor          = $Vendor
    Product         = $Product
    Version         = $Version
    SourcePageUrl   = $SourcePageUrl
    RegisteredAtUtc = [DateTime]::UtcNow.ToString('o')
    SourceFiles     = $SourceInventory
}

Test-AdmxManifest -Manifest $Manifest -ReleaseId $ReleaseId
$ManifestJson = $Manifest | ConvertTo-Json -Depth 5
$TemporaryPath = Join-Path -Path $ReleasePath -ChildPath (
    "manifest-$([guid]::NewGuid()).tmp"
)

try {
    $ManifestJson | Set-Content -LiteralPath $TemporaryPath -Encoding utf8 -ErrorAction Stop
    [System.IO.File]::Move($TemporaryPath, $ManifestPath)
}
finally {
    if (Test-Path -LiteralPath $TemporaryPath) {
        Remove-Item -LiteralPath $TemporaryPath -Force
    }
}

[PSCustomObject]@{
    ReleaseId       = $ReleaseId
    ManifestPath    = $ManifestPath
    SourceFileCount = $SourceInventory.Count
    RegisteredAtUtc = $Manifest.RegisteredAtUtc
}
