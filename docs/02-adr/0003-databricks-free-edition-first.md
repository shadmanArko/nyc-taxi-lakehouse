# ADR-0003: Databricks Free Edition first, upgrade path kept

- Status: Proposed (needs verification of Free Edition capabilities)
- Date: 2026-11-05
- Deciders: Shadman Arko

## Context
We want a real lakehouse engine (Delta Lake, SQL warehouse, catalog). The owner has Databricks Free Edition, which is serverless-only and, to our understanding, restricts external cloud connectivity and workspace automation. Capabilities change over time and must be verified against current Databricks documentation before implementation.

## Options considered
1. **Free Edition**: no cost; possible limits on S3 access, Terraform workspace management, and compute.
2. **Trial or paid workspace on AWS**: full feature set (external locations, Auto Loader from S3, Terraform), but time-limited or costly.
3. **Open-source alternative** (Spark + Delta/Iceberg on S3, or DuckDB): free and portable, but drops the Databricks showcase.

## Decision
Build against Free Edition first. Isolate the S3-to-Bronze load behind a single interface so it can be implemented either as (a) upload to a Databricks Volume, or (b) Auto Loader from an S3 external location if a full workspace becomes available. dbt models are engine-agnostic SQL and do not change.

## Consequences
- Zero licence cost; Terraform for Databricks may be limited to what Free Edition supports.
- The load step may initially be less "enterprise" than the target design; this is documented honestly.
- Follow-up: spike to confirm supported ingestion path (milestone M1).
