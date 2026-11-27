# Contributing

This repository is a reusable template for archiving one vendor's
administrative-template distributions. Contributions should keep the archive
workflow small, format-neutral, safe by default, and broadly reusable.

## Scope

- Preserve original vendor distributions as the integrity baseline.
- Avoid vendor-specific acquisition, extraction, deployment, or package-format
  behavior unless a durable design decision explicitly adds it.
- Keep changes focused. Do not make unrelated refactors or alter archived
  release content without maintainer direction.

## Development and validation

For script or test changes, use PowerShell 7.6 LTS and run:

```powershell
./scripts/Test-TemplateVersion.ps1
./scripts/Invoke-Tests.ps1
git diff --check
```

Update Pester tests and comment-based help when behavior changes. Keep the
README and ADR 0001 aligned with any change to the archive's public interface
or trust boundary.

## Pull requests

- Describe the change and its rationale.
- Call out compatibility, integrity-boundary, or migration impacts.
- Keep documentation and changelog entries in sync where applicable.
- Do not include vendor artifacts, credentials, or unreviewed downloaded files.

For release-preparation work, follow the versioning and release guidance in
`AGENTS.md` and `CHANGELOG.md`.
