<#
.SYNOPSIS
Tests archive-tooling version metadata validation.

.DESCRIPTION
Validates Semantic Versioning metadata, matching changelog entries, and the
lightweight release-tag requirement in isolated temporary repositories.
#>
Describe 'Test-TemplateVersion' {
    BeforeAll {
        $RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
        $ValidatorPath = Join-Path -Path $RepositoryRoot -ChildPath 'scripts/Test-TemplateVersion.ps1'
    }

    BeforeEach {
        $TestRepository = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $TestRepository | Out-Null
        $VersionPath = Join-Path -Path $TestRepository -ChildPath 'VERSION'
        $ChangelogPath = Join-Path -Path $TestRepository -ChildPath 'CHANGELOG.md'
        Set-Content -LiteralPath $VersionPath -Value '1.2.3' -NoNewline
        Set-Content -LiteralPath $ChangelogPath -Value @'
# Changelog

## Unreleased

## 1.2.3 - 2026-11-17

### Added

- Test release.
'@
    }

    It 'validates the template metadata in the repository' {
        $Result = & $ValidatorPath

        $Result.Version | Should -Be '0.1.0'
        $Result.MetadataValid | Should -BeTrue
        $Result.TagChecked | Should -BeFalse
        $Result.TagValid | Should -BeNullOrEmpty
    }

    It 'validates matching Semantic Versioning metadata' {
        $Result = & $ValidatorPath -RepositoryRoot $TestRepository

        $Result.Version | Should -Be '1.2.3'
        $Result.MetadataValid | Should -BeTrue
    }

    It 'rejects a non-SemVer VERSION value' {
        Set-Content -LiteralPath $VersionPath -Value 'v1.2.3' -NoNewline

        { & $ValidatorPath -RepositoryRoot $TestRepository } |
            Should -Throw '*Semantic Versioning X.Y.Z*'
    }

    It 'rejects a missing matching changelog entry' {
        Set-Content -LiteralPath $ChangelogPath -Value "# Changelog`n`n## 1.2.2 - 2026-11-17" -NoNewline

        { & $ValidatorPath -RepositoryRoot $TestRepository } |
            Should -Throw '*does not contain a dated release heading*'
    }

    It 'validates a lightweight release tag on the current commit' {
        & git -C $TestRepository init --quiet
        & git -C $TestRepository config user.email 'test@example.invalid'
        & git -C $TestRepository config user.name 'Test User'
        & git -C $TestRepository add VERSION CHANGELOG.md
        & git -C $TestRepository commit --quiet -m 'test version'
        & git -C $TestRepository tag v1.2.3

        $Result = & $ValidatorPath -RepositoryRoot $TestRepository -CheckTag

        $Result.TagChecked | Should -BeTrue
        $Result.TagValid | Should -BeTrue
    }

    It 'rejects an annotated release tag' {
        & git -C $TestRepository init --quiet
        & git -C $TestRepository config user.email 'test@example.invalid'
        & git -C $TestRepository config user.name 'Test User'
        & git -C $TestRepository add VERSION CHANGELOG.md
        & git -C $TestRepository commit --quiet -m 'test version'
        & git -C $TestRepository tag -a v1.2.3 -m 'annotated tag'

        { & $ValidatorPath -RepositoryRoot $TestRepository -CheckTag } |
            Should -Throw '*must be lightweight*'
    }
}
