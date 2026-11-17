# Architecture Decision Records

This directory records the small number of durable decisions that define this
template's purpose and trust boundary. It is not a log of routine
implementation work or speculative failure modes.

The current governing decision is [ADR 0001: Original Vendor Distributions as
Integrity Baseline](0001-original-vendor-distributions-as-integrity-baseline.md).

Create a new ADR only when a decision changes the archive's durable purpose,
baseline, or responsibility boundary.

## Format

Use a short, numbered Markdown file with this structure:

```markdown
# 0001 - Decision Title

## Status

Accepted

## Context

## Decision

## Alternatives Considered

## Consequences
```

Keep ADRs brief and outcome-focused. They should explain durable reasoning, not replay every implementation step.
