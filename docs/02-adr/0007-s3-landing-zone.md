# ADR-0007: S3 as immutable landing zone

- Status: Accepted
- Date: 2026-11-05
- Deciders: Shadman Arko

## Context
We need a durable system of record for raw files, decoupled from compute, so any downstream layer can be rebuilt.

## Options considered
1. Load straight into the lakehouse: fewer hops, but no independent raw copy.
2. **S3 landing zone, then load**: durable, cheap, auditable, standard pattern.

## Decision
Store original files unmodified at `s3://<bucket>/landing/green_taxi/year=YYYY/month=MM/` with versioning, SSE-KMS, and recorded SHA-256 checksum. Files are never overwritten; corrections arrive as new object versions.

## Consequences
- Full replay and audit capability.
- Small storage cost (pennies at this volume).
- Adds an extra hop to the load path.
