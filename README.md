# Vendor Administrative Template Archive

This repository is a reusable template for archiving one vendor's
administrative-template distributions across multiple releases. A repository
created from this template preserves original vendor downloads, records their
provenance and SHA-256 hashes, and verifies that registered downloads have not
changed.

The archive does not establish vendor authenticity, download releases, extract
packages, deploy templates, or diagnose every file in the repository. Git and
GitHub provide history, review, access control, and governance after a release
is registered.

## Release layout

Each release has this layout:

```text
versions/<release>/
  source/       Original vendor download file or files, unchanged and required
  manifest.json Registered provenance and SHA-256 hashes
  extracted/    Optional inspection copies; not integrity-baseline content
```

Place each original vendor download in `source/` without transforming it. The
registration and verification workflow treats files as opaque, so it supports
standalone templates, ZIP archives, EXEs, MSIs, and multiple downloads without
format-specific logic. A directory created by extracting a download belongs in
`extracted/`, not in the registered source baseline. The initializer creates
both folders for convenience, but Git does not track an empty `extracted/`
folder.

## Quick start

### 1. Initialize a release

On Windows:

```powershell
.\scripts\Register-AdmxRelease.ps1 -InitializeRelease -ReleaseId '1.2.3'
```

On Linux or macOS, from PowerShell:

```powershell
./scripts/Register-AdmxRelease.ps1 -InitializeRelease -ReleaseId '1.2.3'
```

Initialization creates `versions/1.2.3/source/` and
`versions/1.2.3/extracted/`, returns their paths, and does not download files
or create a manifest. It fails without changes if the release directory already
exists.

### 2. Preserve original downloads

Acquire files from a source you trust and place the unmodified originals in
`versions/<release>/source/`. Optionally place extracted or inspection-only
content under `extracted/`.

### 3. Generate and edit a registration splat

`-GenerateSplat` writes a ready-to-edit parameter hashtable. Within
`DownloadUrls`, each hashtable key is a source-relative file path and each value
is that file's direct download URL. Replace the two generated placeholder pairs,
add more pairs as needed, or clear the hashtable when direct download URLs are
unavailable. Do not add SHA-256 values: registration computes them from the
preserved source files.

On Windows, generate and copy it to the clipboard:

```powershell
.\scripts\Register-AdmxRelease.ps1 -GenerateSplat | Clip
```

On Linux or macOS, run PowerShell (`pwsh`) and write it to the terminal:

```powershell
./scripts/Register-AdmxRelease.ps1 -GenerateSplat
```

The `Clip` command is Windows-specific. Clipboard support on Linux and macOS
depends on the local desktop environment and is not required by this project.

### 4. Register the release

Fill in the generated splat, or prepare one directly:

```powershell
$registration = @{
    ReleaseId     = '1.2.3'
    Vendor        = 'Example Vendor'
    Product       = 'Example Product'
    Version       = '1.2.3'
    SourcePageUrl = 'https://vendor.example/releases'
    DownloadUrls  = @{
        'ExampleProduct-1.2.3.zip' = 'https://vendor.example/downloads/ExampleProduct-1.2.3.zip'
    }
}

./scripts/Register-AdmxRelease.ps1 @registration
```

Registration creates `manifest.json` once and refuses to overwrite it. On
success, it returns a PowerShell object with `ReleaseId`, the absolute
`ManifestPath`, `SourceFileCount`, and `RegisteredAtUtc`. Failures throw an
error and do not return a success object.

### 5. Verify and commit

On Windows:

```powershell
.\scripts\Test-AdmxRelease.ps1 -ReleaseId '1.2.3'
```

On Linux or macOS, from PowerShell:

```powershell
./scripts/Test-AdmxRelease.ps1 -ReleaseId '1.2.3'
```

Verification compares only the files registered in `manifest.json` with their
recorded SHA-256 hashes. It does not verify `extracted/` contents or prove that
the original download came from the stated vendor. Review and commit the
original source file(s) and manifest together.

## Run tests

The test suite requires PowerShell 7.4 or later and Pester 6.2.0. Install the
required Pester version once when it is not already available:

```powershell
Install-Module Pester -RequiredVersion 6.2.0 -Scope CurrentUser

# Windows
.\scripts\Invoke-Tests.ps1

# Linux or macOS, from PowerShell
./scripts/Invoke-Tests.ps1
```

The test runner disables Pester's unused Windows registry fixture, so tests do
not require registry write access.

## Governance

After the GitHub Actions test workflow is passing, enable GitHub's **Template
repository** setting if this repository will be used as a template. Configure
protection for `main` through GitHub: require pull requests and the passing test
check, and restrict direct and force pushes as appropriate for the repository.
These are repository-governance controls, not verifier behavior.

## License and vendor artifacts

[MIT](LICENSE) applies only to the scripts, tests, workflow, and documentation
authored for this template. Vendor-supplied artifacts archived in repositories
created from it remain subject to their original vendors' terms and licenses.

## Architecture decision

- [ADR 0001: Original Vendor Distributions as Integrity Baseline](docs/decisions/0001-original-vendor-distributions-as-integrity-baseline.md)
