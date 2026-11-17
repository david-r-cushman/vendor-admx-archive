function Test-AdmxManifest {
    <#
    .SYNOPSIS
    Validates the structure and required values of a release manifest.

    .DESCRIPTION
    Ensures that a manifest identifies the requested release, contains required
    provenance fields, and has unique source-file records with safe relative
    paths and valid SHA-256 values. Throws when validation fails.

    .PARAMETER Manifest
    The deserialized manifest object to validate.

    .PARAMETER ReleaseId
    The release identifier that the manifest must match.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Manifest,

        [Parameter(Mandatory)]
        [string]$ReleaseId
    )

    if ($Manifest.ReleaseId -cne $ReleaseId) {
        throw "Manifest ReleaseId '$($Manifest.ReleaseId)' does not match requested release '$ReleaseId'."
    }

    $RequiredProperties = @(
        'ReleaseId', 'Vendor', 'Product', 'Version', 'SourcePageUrl', 'RegisteredAtUtc'
    )

    foreach ($Property in $RequiredProperties) {
        if ([string]::IsNullOrWhiteSpace($Manifest.$Property)) {
            throw "Manifest is missing or has an empty required property: $Property"
        }
    }

    if (-not $Manifest.SourceFiles -or $Manifest.SourceFiles.Count -eq 0) {
        throw 'Manifest contains no source file records.'
    }

    $RegisteredPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($File in $Manifest.SourceFiles) {
        if ([string]::IsNullOrWhiteSpace($File.Path)) {
            throw 'Manifest contains a source file record without a valid Path.'
        }

        $PathComponents = $File.Path -split '/'

        if (
            [System.IO.Path]::IsPathFullyQualified($File.Path) -or
            $File.Path.Contains('\') -or
            $File.Path.Contains(':') -or
            $PathComponents -contains '..' -or
            $PathComponents -contains '.' -or
            $PathComponents -contains ''
        ) {
            throw "Manifest contains an invalid source-relative path: '$($File.Path)'."
        }

        if (-not $RegisteredPaths.Add($File.Path)) {
            throw "Manifest contains a duplicate source-relative path: '$($File.Path)'."
        }

        if ($File.SHA256 -cnotmatch '^[0-9A-Fa-f]{64}$') {
            throw "Manifest contains an invalid SHA-256 hash for '$($File.Path)'."
        }
    }
}
