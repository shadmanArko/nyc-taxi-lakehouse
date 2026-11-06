# ADR-0003: Databricks Free Edition first, upgrade path kept

- Status: Accepted (spike completed 2026-11-06; three points still unverified, listed below)
- Date: 2026-11-05, updated 2026-11-06
- Deciders: Shadman Arko

## Context
We want a real lakehouse engine (Delta Lake, SQL warehouse, catalog). The owner has Databricks Free Edition, which is serverless-only and restricts outbound internet to "a limited set of trusted domains" ([Free Edition limitations](https://docs.databricks.com/aws/getting-started/free-edition-limitations)). That page does not say whether a customer's own S3 bucket can be used, and community answers contradicted each other, so we ran a spike instead of guessing.

## Options considered
1. **Free Edition**: no cost; possible limits on S3 access, Terraform workspace management, and compute.
2. **Trial or paid workspace on AWS**: full feature set, but time-limited or costly.
3. **Open-source alternative** (Spark + Delta/Iceberg on S3, or DuckDB): free and portable, but drops the Databricks showcase.

## Spike results (2026-11-06, workspace on AWS)
| Question | Result |
|---|---|
| Outbound HTTPS from a serverless notebook to our S3 bucket | Works (presigned URL, 200, whole file downloaded) |
| Load a file into a Delta table (`saveAsTable`) | Works (48,326 rows, matches the local Bronze) |
| Storage credential from an AWS IAM role | Works. Assume Role, Self Assume Role and External ID checks pass. |
| External location on `s3://<bucket>/landing` | Works with "Force create". Read, List and Path Exists pass. |
| Read all landing files by `s3://` path with Spark | Works: 146,486 rows, identical to the local Bronze table |
| File events (queues created in our AWS account) | Not set up. Optional, and it would widen access, so we skipped it. |

Observed facts to keep in mind:
- The Databricks workspace is in **US East (Ohio)**; our bucket is in **eu-central-1 (Frankfurt)**. Reads work across regions. For real European data this would need a data-residency decision and would add transfer cost.
- The IAM role is **read-only** and trusts only Databricks's published Unity Catalog role plus a per-credential External ID. During the short window before the real External ID is known, the trust policy uses the placeholder `0000`.
- Databricks requires the role to trust itself. Terraform therefore applies in two phases (see `infra/terraform/iam.tf`).

## Decision
Build against Free Edition and read the S3 landing zone natively through a Unity Catalog storage credential and external location. The S3-to-Bronze load stays behind one interface, so it can be swapped for a Databricks Volume upload or Auto Loader file notifications if needed. dbt models are engine-agnostic SQL and do not change.

## Consequences
- Zero licence cost. The proper IAM-role pattern is demonstrated and defined in Terraform; no AWS keys are stored in Databricks.
- Without file events, Databricks does not react to new files by itself. The Airflow schedule decides when to load, which is enough for a daily batch.
- Free Edition has one 2X-Small SQL warehouse and a daily quota; compute stops for the day when the quota is exceeded.

## Still unverified
- Whether dbt (running on a laptop or in Airflow) can connect to the Free Edition SQL warehouse with a personal access token.
- Whether Auto Loader works in directory-listing mode without file events.
- Whether the Databricks Terraform provider can manage Free Edition resources. The AWS side is already in Terraform; the Databricks credential and location were created in the UI.
