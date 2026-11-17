# 0001 - Original Vendor Distributions as Integrity Baseline

## Status

Accepted

## Context

This repository is a reusable template for an archive of one vendor's
administrative-template distributions across multiple releases. Each
repository created from the template preserves original vendor downloads,
enables historical comparison and traceability, and detects unintended changes
to registered downloads.

An archive must accommodate vendor distributions delivered as multiple
downloads, standalone ADMX/ADML files, ZIP archives, or other package formats.
Requiring a single ZIP, mandatory extraction, or duplicate copies of
standalone files would introduce unnecessary vendor-specific constraints.

The template requires a repeatable, governable archiving process without
becoming a general-purpose package management or deployment system.

## Decision

Preserve original vendor-supplied files, unchanged, as the authoritative
archived artifacts.

Support one or more original files per release, without requiring a particular
file format.

Record release metadata and SHA-256 hashes of the original files in
`manifest.json`.

Treat extracted files as optional inspection artifacts for viewing and
comparing changes through Git, rather than as the authoritative integrity
baseline.

Require users to acquire and organize vendor files before registration. The
repository does not independently establish vendor authenticity.

Use format-neutral PowerShell registration and verification scripts that treat
original downloads as opaque files.

Prevent registration from overwriting an existing manifest.

Keep automated acquisition, vendor-specific extraction, deployment, and
comprehensive package-format validation outside the initial scope.

Registration uses mandatory named parameters, with an optional `-GenerateSplat`
switch that outputs an editable parameter hashtable. The script does not create
configuration files or manage the clipboard.

Verification establishes whether registered original files still match their
recorded hashes. It does not establish vendor authenticity or guarantee the
correctness of optional extracted contents.

## Alternatives Considered

Require exactly one ZIP per release: Rejected because vendors may distribute
releases through multiple downloads or other file formats.

Require original and extracted files for every release: Rejected because
standalone administrative templates would be duplicated unnecessarily, and
some packages may not support straightforward extraction.

Hash every extracted file independently: Rejected for the initial design
because it introduces a second recorded integrity baseline without being
necessary to verify the preserved original distributions.

Implement format-specific extraction and comparison for all vendors: Deferred
because it introduces substantial complexity beyond the repository's primary
preservation and integrity objectives.

Automate acquisition and release preparation: Deferred to retain a clear
responsibility boundary between vendor acquisition and archive registration.

## Consequences

The core registration and verification process can accommodate different
vendors and distribution formats without vendor-specific code.

Original distributions remain available for future inspection or re-extraction,
while optional extracted contents support readable Git comparisons.

Integrity verification is limited to registered original files. Extracted-file
completeness and equivalence to original packages are not guaranteed.

Users remain responsible for establishing confidence in the acquisition source
and preparing release directories.

The initial implementation remains deliberately limited. Additional
capabilities may be introduced when actual vendor requirements justify them,
rather than through speculative generalization.
