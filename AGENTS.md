# AI Operating Instructions

## Purpose and integrity boundary

This repository archives one vendor's administrative-template distributions
across releases. It preserves original vendor downloads, records their
provenance and SHA-256 hashes, and verifies that registered downloads have not
changed.

- `versions/<release>/source/` contains the original vendor-supplied files.
  Treat every file in this directory as immutable: do not edit, rename, delete,
  generate, or extract files in place.
- `manifest.json` is the first registered integrity baseline for a release.
  Never overwrite, delete, modify, or recreate a manifest unless the user
  explicitly directs a corrective change.
- `extracted/` is optional inspection content. It is not part of the integrity
  baseline and is not verified by the scripts.

The archive does not establish vendor authenticity, acquire releases,
automatically extract packages, deploy templates, or validate package formats.

## Release operations

AI may, when asked, initialize a release layout, inspect user-supplied files,
generate a registration splat, verify a registered release, and run tests.

1. Create a requested release layout with:

   ```powershell
   .\scripts\Register-AdmxRelease.ps1 -InitializeRelease -ReleaseId '<release>'
   ```

   Use `./scripts/Register-AdmxRelease.ps1` when running PowerShell on Linux or
   macOS. Initialization creates `source/` and `extracted/` only; it does not
   acquire files or create a manifest.

2. Confirm that the user-supplied original files are present beneath `source/`
   and collect their provenance. `DownloadUrls` maps each source-relative path
   to its direct download URL. Do not provide SHA-256 values; registration
   calculates them from the preserved source files.

3. Use `-GenerateSplat` to prepare an editable registration hashtable when
   useful. The generated placeholder pairs must be replaced or removed before
   registration.

4. Obtain explicit user approval before downloading vendor artifacts or running
   registration, because registration creates the release's immutable first
   manifest. Do not invoke `Register-AdmxRelease.ps1` with registration
   parameters without that approval.

5. After approved registration, run:

   ```powershell
   .\scripts\Test-AdmxRelease.ps1 -ReleaseId '<release>'
   ```

   Report the registration result and verification outcome. Stage only the new
   release's `source/`, optional `extracted/`, and `manifest.json` after
   verification succeeds. Do not commit or push.

Copy-based extraction from `source/` to `extracted/` is allowed only when the
user directs it. Preserve the source file unchanged and do not add
format-specific extraction automation without an explicit request.

## Repository maintenance

- Preserve the scope and trust boundary in README and ADR 0001. Do not expand
  the repository into a downloader, deployment tool, or package validator
  without an explicit design decision.
- For a behavior or public-interface change, update applicable Pester tests,
  comment-based help, README guidance, and the ADR when the durable boundary
  changes.
- Do not change existing archived releases, their source files, or manifests
  unless explicitly directed by the user.
- Use PowerShell 7.4 or later and Pester 6.2.0. Run
  `./scripts/Invoke-Tests.ps1` after script or test changes.
- Before handoff, run `git diff --check`, report validation results, and list
  uncommitted changes.
