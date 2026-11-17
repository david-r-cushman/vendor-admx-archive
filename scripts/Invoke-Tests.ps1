<#
.SYNOPSIS
Runs the repository's Pester test suite.

.DESCRIPTION
Imports Pester 6.2.0, requires PowerShell 7.4 or later, and runs all tests in
the tests directory. The Pester TestRegistry fixture is disabled because this
repository does not use it and its registry write requirement is unnecessary.

.EXAMPLE
PS> .\scripts\Invoke-Tests.ps1

Runs the test suite from the repository root on Windows.

.EXAMPLE
PS> ./scripts/Invoke-Tests.ps1

Runs the test suite from PowerShell on Linux or macOS.
#>
[CmdletBinding()]
param()

$RequiredPesterVersion = [version]'6.2.0'
$RepositoryRoot = Split-Path -Path $PSScriptRoot -Parent
$TestPath = Join-Path -Path $RepositoryRoot -ChildPath 'tests'

if ($PSVersionTable.PSVersion -lt [version]'7.4.0') {
    throw 'PowerShell 7.4 or later is required to run this test suite.'
}

try {
    Import-Module Pester -RequiredVersion $RequiredPesterVersion -ErrorAction Stop
}
catch {
    throw "Pester $RequiredPesterVersion is required. Install it with: Install-Module Pester -RequiredVersion $RequiredPesterVersion -Scope CurrentUser"
}

$PesterConfiguration = New-PesterConfiguration -Hashtable @{
    Run = @{ Exit = $true; Path = $TestPath }
    Output = @{ CIFormat = 'Auto'; Verbosity = 'Detailed' }
    TestRegistry = @{ Enabled = $false }
}

Invoke-Pester -Configuration $PesterConfiguration
