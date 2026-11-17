function Test-AdmxSourcePath {
    <#
    .SYNOPSIS
    Validates a source-relative file path before it is read.

    .DESCRIPTION
    Confirms that a relative path remains within the source root, resolves to a
    file, and does not traverse a reparse point. Throws when the source root or
    any component of the path is unsafe or invalid.

    .PARAMETER SourceRoot
    The source directory that contains registered original vendor files.

    .PARAMETER RelativePath
    A forward-slash-delimited path relative to SourceRoot.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Source-relative path cannot be empty.'
    }

    $PathComponents = $RelativePath -split '/'

    if (
        [System.IO.Path]::IsPathFullyQualified($RelativePath) -or
        $RelativePath.Contains('\') -or
        $RelativePath.Contains(':') -or
        $PathComponents -contains '..' -or
        $PathComponents -contains '.' -or
        $PathComponents -contains ''
    ) {
        throw "Invalid source-relative path: '$RelativePath'."
    }

    $RootItem = Get-Item -LiteralPath $SourceRoot -Force -ErrorAction Stop

    if (-not $RootItem.PSIsContainer) {
        throw "Source root is not a directory: $SourceRoot"
    }

    if ($RootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Source root is a reparse point: $SourceRoot"
    }

    $CurrentPath = $RootItem.FullName

    foreach ($Component in $PathComponents) {
        $CurrentPath = Join-Path -Path $CurrentPath -ChildPath $Component
        $Item = Get-Item -LiteralPath $CurrentPath -Force -ErrorAction Stop

        if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "Source path contains a reparse point: $CurrentPath"
        }
    }

    if ($Item.PSIsContainer) {
        throw "Source path does not identify a file: $RelativePath"
    }
}
