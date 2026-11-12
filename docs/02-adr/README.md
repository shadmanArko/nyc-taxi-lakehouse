# Architecture Decision Records

We record significant decisions as ADRs (format: [Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)). An accepted ADR is not rewritten. New facts are added as dated "Amendment" sections at the bottom, and a decision that is reversed gets a new ADR that supersedes it.

| # | Title | Status |
|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-elt-medallion-lakehouse.md) | ELT with a medallion lakehouse | Accepted |
| [0003](0003-databricks-free-edition-first.md) | Databricks Free Edition first, upgrade path kept | Accepted (spike done 2026-11-06, updated 2026-11-08) |
| [0004](0004-dbt-for-transformations.md) | dbt for transformations | Accepted |
| [0005](0005-airflow-orchestration.md) | Airflow for orchestration | Accepted |
| [0006](0006-terraform-iac.md) | Terraform for infrastructure | Accepted |
| [0007](0007-s3-landing-zone.md) | S3 as immutable landing zone | Accepted |
| [0008](0008-local-first-duckdb-docker-uv.md) | Local-first with DuckDB, Docker and uv | Accepted |

Template: [0000-template.md](0000-template.md)
