<#
.SYNOPSIS
Tests integrity verification for archived administrative-template releases.

.DESCRIPTION
Creates a temporary release under versions/ and verifies matching, changed,
missing, and malformed-manifest outcomes.
#>
Describe 'Test-AdmxRelease' {
    BeforeAll {
        $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
        $VerifierPath = Join-Path -Path $RepositoryRoot -ChildPath 'scripts/Test-AdmxRelease.ps1'
        $ReleaseId = "test-verification-$([guid]::NewGuid().ToString('N'))"
        $ReleasePath = Join-Path -Path $RepositoryRoot -ChildPath "versions/$ReleaseId"
        $SourcePath = Join-Path -Path $ReleasePath -ChildPath 'source'
        $SourceFilePath = Join-Path -Path $SourcePath -ChildPath 'sample.zip'
        $ManifestPath = Join-Path -Path $ReleasePath -ChildPath 'manifest.json'

        function Set-TestReleaseManifest {
            $Hash = (Get-FileHash -LiteralPath $SourceFilePath -Algorithm SHA256).Hash
            [PSCustomObject]@{
                ReleaseId = $ReleaseId; Vendor = 'Test Vendor'; Product = 'Test Product'; Version = '1.0'
                SourcePageUrl = 'https://example.invalid/test'; RegisteredAtUtc = '2026-01-01T00:00:00.0000000Z'
                SourceFiles = @([PSCustomObject]@{ Path = 'sample.zip'; SHA256 = $Hash })
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
        }

        New-Item -ItemType Directory -Path $SourcePath -Force | Out-Null
    }

    BeforeEach {
        Set-Content -LiteralPath $SourceFilePath -Value 'original vendor payload' -NoNewline
        Set-TestReleaseManifest
    }

    AfterAll { Remove-Item -LiteralPath $ReleasePath -Recurse -Force -ErrorAction SilentlyContinue }

    It 'passes when a registered source file matches its recorded hash' {
        $Result = & $VerifierPath -ReleaseId $ReleaseId
        $Result.Passed | Should -BeTrue
        $Result.Discrepancies | Should -BeNullOrEmpty
    }

    It 'reports a changed registered file as a hash mismatch' {
        Set-Content -LiteralPath $SourceFilePath -Value 'modified payload' -NoNewline
        $Result = & $VerifierPath -ReleaseId $ReleaseId
        $Result.Passed | Should -BeFalse
        $Result.Discrepancies | Should -HaveCount 1
        $Result.Discrepancies[0].Issue | Should -Be 'HashMismatch'
    }

    It 'reports a missing registered file' {
        Remove-Item -LiteralPath $SourceFilePath -Force
        $Result = & $VerifierPath -ReleaseId $ReleaseId
        $Result.Passed | Should -BeFalse
        $Result.Discrepancies | Should -HaveCount 1
        $Result.Discrepancies[0].Issue | Should -Be 'MissingFile'
    }

    It 'rejects an invalid manifest before verification' {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        $Manifest.SourceFiles[0].Path = '../sample.zip'
        $Manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
        { & $VerifierPath -ReleaseId $ReleaseId } | Should -Throw '*invalid source-relative path*'
    }
}
