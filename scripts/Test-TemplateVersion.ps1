<#
.SYNOPSIS
Validates archive-tooling version metadata and, optionally, its release tag.

.DESCRIPTION
Checks that VERSION contains a Semantic Versioning X.Y.Z value and that
CHANGELOG.md has a matching dated release heading. With -CheckTag, also checks
that the corresponding vX.Y.Z tag is lightweight and resolves to the current
commit. Throws when validation fails and returns a structured result on
success.

.PARAMETER CheckTag
Checks the matching lightweight vX.Y.Z tag and confirms that it resolves to
the current commit.

.PARAMETER RepositoryRoot
The repository root that contains VERSION and CHANGELOG.md. Defaults to the
parent directory of this script.

.OUTPUTS
PSCustomObject with Version, MetadataValid, TagChecked, and TagValid.

.EXAMPLE
PS> .\scripts\Test-TemplateVersion.ps1

Validates the archive-tooling version metadata on Windows.

.EXAMPLE
PS> ./scripts/Test-TemplateVersion.ps1 -CheckTag

Validates metadata and the matching release tag from PowerShell on Linux or
macOS.
#>
[CmdletBinding()]
param(
    [switch]$CheckTag,

    [string]$RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent)
)

$VersionPath = Join-Path -Path $RepositoryRoot -ChildPath 'VERSION'
$ChangelogPath = Join-Path -Path $RepositoryRoot -ChildPath 'CHANGELOG.md'

if (-not (Test-Path -LiteralPath $VersionPath -PathType Leaf)) {
    throw "VERSION file not found: $VersionPath"
}

if (-not (Test-Path -LiteralPath $ChangelogPath -PathType Leaf)) {
    throw "CHANGELOG.md file not found: $ChangelogPath"
}

$Version = (Get-Content -LiteralPath $VersionPath -Raw -ErrorAction Stop).Trim()

if ($Version -cnotmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
    throw "VERSION must contain a Semantic Versioning X.Y.Z value: '$Version'"
}

$Changelog = Get-Content -LiteralPath $ChangelogPath -Raw -ErrorAction Stop
$ReleaseHeadingPattern = '(?m)^##\s+' + [regex]::Escape($Version) + '\s+-\s+\d{4}-\d{2}-\d{2}\s*$'

if ($Changelog -notmatch $ReleaseHeadingPattern) {
    throw "CHANGELOG.md does not contain a dated release heading for version $Version."
}

$TagValid = $null

if ($CheckTag) {
    $TagName = "v$Version"
    $TagObjectType = & git -C $RepositoryRoot cat-file -t "refs/tags/$TagName" 2>$null

    if ($LASTEXITCODE -ne 0) {
        throw "Release tag not found: $TagName"
    }

    if ($TagObjectType -ne 'commit') {
        throw "Release tag must be lightweight: $TagName"
    }

    $TagCommit = & git -C $RepositoryRoot rev-parse "refs/tags/$TagName" 2>$null
    $HeadCommit = & git -C $RepositoryRoot rev-parse HEAD 2>$null

    if ($LASTEXITCODE -ne 0 -or $TagCommit -ne $HeadCommit) {
        throw "Release tag $TagName does not point to the current commit."
    }

    $TagValid = $true
}

[PSCustomObject]@{
    Version       = $Version
    MetadataValid = $true
    TagChecked    = [bool]$CheckTag
    TagValid      = $TagValid
}
