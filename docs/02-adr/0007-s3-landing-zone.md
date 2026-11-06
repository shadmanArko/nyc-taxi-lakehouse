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

## Amendment 2026-11-06
Implemented in `infra/terraform/main.tf` with **SSE-S3 (AES256)** instead of SSE-KMS. KMS keys cost money and add key-policy work for Databricks, while SSE-S3 gives the same encryption at rest for this project. Public access is fully blocked and versioning is on. Revisit KMS if the data becomes sensitive.

Also: the upload step skips a key that already exists, which enforces "never overwritten". The SHA-256 is currently printed by the download step but not stored; storing it is still to do.
