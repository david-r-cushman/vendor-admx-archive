<#
.SYNOPSIS
Tests registration behavior for archived administrative-template releases.

.DESCRIPTION
Creates temporary releases under versions/ and verifies manifest creation,
source-file preservation, generated splats, initialization, and failure
conditions.
#>
Describe 'Register-AdmxRelease' {
    BeforeAll {
        $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
        $RegistrarPath = Join-Path -Path $RepositoryRoot -ChildPath 'scripts/Register-AdmxRelease.ps1'
    }

    BeforeEach {
        $ReleaseId = "test-registration-$([guid]::NewGuid().ToString('N'))"
        $ReleasePath = Join-Path -Path $RepositoryRoot -ChildPath "versions/$ReleaseId"
        $SourcePath = Join-Path -Path $ReleasePath -ChildPath 'source'
        $ManifestPath = Join-Path -Path $ReleasePath -ChildPath 'manifest.json'
        New-Item -ItemType Directory -Path $ReleasePath -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $ReleasePath -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'creates a manifest with provenance and source hash without altering the source file' {
        New-Item -ItemType Directory -Path $SourcePath -Force | Out-Null
        $SourceFile = Join-Path -Path $SourcePath -ChildPath 'installer.msi'
        Set-Content -LiteralPath $SourceFile -Value 'vendor MSI payload' -NoNewline
        $ExpectedHash = (Get-FileHash -LiteralPath $SourceFile -Algorithm SHA256).Hash

        $Result = & $RegistrarPath -ReleaseId $ReleaseId -Vendor 'Test Vendor' -Product 'Test Product' -Version '1.0' -SourcePageUrl 'https://example.invalid/releases'
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json

        $Manifest.ReleaseId | Should -Be $ReleaseId
        $Manifest.Vendor | Should -Be 'Test Vendor'
        $Manifest.SourceFiles | Should -HaveCount 1
        $Manifest.SourceFiles[0].Path | Should -Be 'installer.msi'
        $Manifest.SourceFiles[0].SHA256 | Should -Be $ExpectedHash
        (Get-FileHash -LiteralPath $SourceFile -Algorithm SHA256).Hash | Should -Be $ExpectedHash
        $Result.ReleaseId | Should -Be $ReleaseId
        $Result.ManifestPath | Should -Be $ManifestPath
        $Result.SourceFileCount | Should -Be 1
        ([DateTime]$Result.RegisteredAtUtc).ToUniversalTime() | Should -Be $Manifest.RegisteredAtUtc.ToUniversalTime()
    }

    It 'registers multiple opaque source files and their optional download URLs' {
        New-Item -ItemType Directory -Path $SourcePath -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $SourcePath 'template.admx') -Value 'ADMX payload' -NoNewline
        Set-Content -LiteralPath (Join-Path $SourcePath 'template.adml') -Value 'ADML payload' -NoNewline
        Set-Content -LiteralPath (Join-Path $SourcePath 'setup.exe') -Value 'EXE payload' -NoNewline

        & $RegistrarPath -ReleaseId $ReleaseId -Vendor 'Test Vendor' -Product 'Test Product' -Version '1.0' -SourcePageUrl 'https://example.invalid/releases' -DownloadUrls @{
            'template.admx' = 'https://example.invalid/template.admx'
            'setup.exe' = 'https://example.invalid/setup.exe'
        }

        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        $Manifest.SourceFiles | Should -HaveCount 3
        ($Manifest.SourceFiles.Path | Sort-Object) | Should -Be @('setup.exe', 'template.adml', 'template.admx')
        ($Manifest.SourceFiles | Where-Object Path -eq 'template.admx').DownloadUrl | Should -Be 'https://example.invalid/template.admx'
        ($Manifest.SourceFiles | Where-Object Path -eq 'setup.exe').DownloadUrl | Should -Be 'https://example.invalid/setup.exe'
        ($Manifest.SourceFiles | Where-Object Path -eq 'template.adml').PSObject.Properties.Name | Should -Not -Contain 'DownloadUrl'
    }

    It 'generates an editable multi-file splat without SHA-256 values' {
        $Splat = & $RegistrarPath -GenerateSplat | Out-String
        $Splat | Should -Match '\$Params = @\{'
        $Splat | Should -Match "'<source-relative-file-1>' = '<download-url-1>'"
        $Splat | Should -Match "'<source-relative-file-2>' = '<download-url-2>'"
        $Splat | Should -Not -Match 'SHA256'
    }

    It 'initializes a new release layout without creating a manifest' {
        $InitializedReleaseId = "test-initialize-$([guid]::NewGuid().ToString('N'))"
        $InitializedReleasePath = Join-Path -Path $RepositoryRoot -ChildPath "versions/$InitializedReleaseId"
        $InitializedSourcePath = Join-Path -Path $InitializedReleasePath -ChildPath 'source'
        $InitializedExtractedPath = Join-Path -Path $InitializedReleasePath -ChildPath 'extracted'

        try {
            $Result = & $RegistrarPath -InitializeRelease -ReleaseId $InitializedReleaseId
            $Result.ReleaseId | Should -Be $InitializedReleaseId
            $Result.ReleasePath | Should -Be $InitializedReleasePath
            $Result.SourcePath | Should -Be $InitializedSourcePath
            $Result.ExtractedPath | Should -Be $InitializedExtractedPath
            $InitializedSourcePath | Should -Exist
            $InitializedExtractedPath | Should -Exist
            (Join-Path $InitializedReleasePath 'manifest.json') | Should -Not -Exist
        }
        finally {
            Remove-Item -LiteralPath $InitializedReleasePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects an invalid release ID during initialization' {
        { & $RegistrarPath -InitializeRelease -ReleaseId '../invalid' } | Should -Throw '*Invalid ReleaseId*'
    }

    It 'does not initialize an existing release directory' {
        { & $RegistrarPath -InitializeRelease -ReleaseId $ReleaseId } | Should -Throw '*Release path already exists*'
        $SourcePath | Should -Not -Exist
        $ManifestPath | Should -Not -Exist
    }

    It 'refuses to overwrite an existing manifest' {
        Set-Content -LiteralPath $ManifestPath -Value '{}' -NoNewline
        { & $RegistrarPath -ReleaseId $ReleaseId -Vendor 'Test Vendor' -Product 'Test Product' -Version '1.0' -SourcePageUrl 'https://example.invalid/releases' } | Should -Throw '*already registered*'
    }

    It 'fails when the source directory is missing' {
        { & $RegistrarPath -ReleaseId $ReleaseId -Vendor 'Test Vendor' -Product 'Test Product' -Version '1.0' -SourcePageUrl 'https://example.invalid/releases' } | Should -Throw '*Source directory does not exist*'
    }

    It 'fails when the source directory contains no source files' {
        New-Item -ItemType Directory -Path $SourcePath -Force | Out-Null
        { & $RegistrarPath -ReleaseId $ReleaseId -Vendor 'Test Vendor' -Product 'Test Product' -Version '1.0' -SourcePageUrl 'https://example.invalid/releases' } | Should -Throw '*No source files found*'
    }
}
