<#
.SYNOPSIS
Verifies the registered source files for an archived release.

.DESCRIPTION
Reads a release manifest, validates its structure, and compares the current
SHA-256 hash of each registered source file with the recorded baseline. The
result reports discrepancies for registered files only; it does not validate
optional extracted content or vendor authenticity.

.PARAMETER ReleaseId
The name of the release directory under versions/ to verify.

.EXAMPLE
PS> .\scripts\Test-AdmxRelease.ps1 -ReleaseId '1.2.3'

Verifies the registered source files on Windows.

.EXAMPLE
PS> ./scripts/Test-AdmxRelease.ps1 -ReleaseId '1.2.3'

Verifies the release from PowerShell on Linux or macOS.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ReleaseId
)

. (Join-Path -Path $PSScriptRoot -ChildPath 'private/Test-AdmxManifest.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'private/Test-AdmxSourcePath.ps1')

if (
    $ReleaseId -in @('.', '..') -or
    $ReleaseId -match '[/\\]' -or
    [string]::IsNullOrWhiteSpace($ReleaseId)
) {
    throw "Invalid ReleaseId: '$ReleaseId'. Supply a single directory name."
}

$RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$ReleasePath = Join-Path -Path $RepositoryRoot -ChildPath 'versions' -AdditionalChildPath $ReleaseId
$ManifestPath = Join-Path -Path $ReleasePath -ChildPath 'manifest.json'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest not found for release '$ReleaseId': $ManifestPath"
}

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop
Test-AdmxManifest -Manifest $Manifest -ReleaseId $ReleaseId

$SourcePath = Join-Path -Path $ReleasePath -ChildPath 'source'
$SourceRootItem = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop

if (-not $SourceRootItem.PSIsContainer) {
    throw "Source root is not a directory: $SourcePath"
}

if ($SourceRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    throw "Source root is a reparse point: $SourcePath"
}

$Discrepancies = [System.Collections.Generic.List[object]]::new()

foreach ($File in $Manifest.SourceFiles) {
    try {
        Test-AdmxSourcePath -SourceRoot $SourcePath -RelativePath $File.Path
    }
    catch {
        $Issue = if (
            $_.Exception -is [System.Management.Automation.ItemNotFoundException] -or
            $_.Exception -is [System.IO.FileNotFoundException] -or
            $_.Exception -is [System.IO.DirectoryNotFoundException]
        ) { 'MissingFile' } else { 'InvalidSourcePath' }

        $Discrepancies.Add([PSCustomObject]@{
            Path   = $File.Path
            Issue  = $Issue
            Detail = $_.Exception.Message
        })
        continue
    }

    try {
        $ActualHash = Get-FileHash -LiteralPath (Join-Path -Path $SourcePath -ChildPath $File.Path) -Algorithm SHA256 -ErrorAction Stop
    }
    catch {
        $Discrepancies.Add([PSCustomObject]@{
            Path   = $File.Path
            Issue  = 'UnreadableFile'
            Detail = $_.Exception.Message
        })
        continue
    }

    if ($ActualHash.Hash -ine $File.SHA256) {
        $Discrepancies.Add([PSCustomObject]@{
            Path   = $File.Path
            Issue  = 'HashMismatch'
            Detail = 'SHA-256 differs from the registered value.'
        })
    }
}

[PSCustomObject]@{
    ReleaseId     = $ReleaseId
    Passed        = ($Discrepancies.Count -eq 0)
    Discrepancies = @($Discrepancies.ToArray())
}
