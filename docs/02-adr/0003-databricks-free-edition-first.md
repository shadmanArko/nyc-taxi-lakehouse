# ADR-0003: Databricks Free Edition first, upgrade path kept

- Status: Accepted (spike completed 2026-11-06; dbt verified 2026-11-08; two points still unverified, listed below)
- Date: 2026-11-05, updated 2026-11-08
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
| File events (queues created in our AWS account) | Not working, by choice. The external location page shows "Enable file events: Enabled, Automatic: Yes" (set when we used "Force create"), but the two validation checks that create the notification queues failed, because we did not give the role the extra AWS permissions. Granting them would widen access, so we skipped it and do not rely on file events. Whether the setting does anything is untested. |
| Bronze load with `COPY INTO` (`databricks/load_bronze.sql`) | Works after enabling the `timestampNtz` table feature. 48,326 / 46,621 / 51,539 rows; a second run loads 0 rows (idempotent). |
| dbt from a laptop to the Free Edition SQL warehouse (personal access token) | Works. `dbt debug` passes and `dbt build --target databricks` gives PASS=16 (4 models, 12 tests). |

Observed facts to keep in mind:
- The Databricks workspace is in **US East (Ohio)**; our bucket is in **eu-central-1 (Frankfurt)**. Reads work across regions. For real European data this would need a data-residency decision and would add transfer cost.
- The IAM role is **read-only** and trusts only Databricks's published Unity Catalog role plus a per-credential External ID. During the short window before the real External ID is known, the trust policy uses the placeholder `0000`.
- Databricks requires the role to trust itself. Terraform therefore applies in two phases (see `infra/terraform/iam.tf`).

## Decision
Build against Free Edition and read the S3 landing zone natively through a Unity Catalog storage credential and external location. The S3-to-Bronze load stays behind one interface, so it can be swapped for a Databricks Volume upload or Auto Loader file notifications if needed. dbt models are almost engine-agnostic SQL: moving from DuckDB to Databricks needed only two small changes (`cast(... as string)` instead of `varchar`, and the `timestampNtz` table property). `profiles.yml` holds both targets; credentials come from environment variables.

## Consequences
- Zero licence cost. The proper IAM-role pattern is demonstrated and defined in Terraform; no AWS keys are stored in Databricks.
- We do not rely on file events, so Databricks does not react to new files by itself. The Airflow schedule decides when to load, which is enough for a daily batch.
- Free Edition has one 2X-Small SQL warehouse and a daily quota; compute stops for the day when the quota is exceeded.

## Still unverified
- Whether dbt can connect from inside the Airflow container (verified from a laptop only). Personal access tokens are short-lived and must be supplied to the container as a secret.
- Whether Auto Loader works in directory-listing mode without file events.
- Whether the Databricks Terraform provider can manage Free Edition resources. The AWS side is already in Terraform; the Databricks credential and location were created in the UI.
