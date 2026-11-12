# ADR-0008: Local-first with DuckDB, Docker and uv

- Status: Accepted (written down after the fact, 2026-11-12; the decision was made at the start of the build)
- Date: 2026-11-12
- Deciders: Shadman Arko

## Context
The target platform (S3, Databricks, Airflow) costs money and time to set up, and Databricks Free Edition had unknown limits (ADR-0003). Building straight in the cloud would mix two kinds of failure: "the design is wrong" and "the platform is configured wrong". We wanted to prove the data model, the rules and the tests first, for free, and then move one piece at a time.

## Options considered
1. **Build directly on AWS and Databricks**: closest to the target, but every mistake costs cloud time, and failures are hard to locate.
2. **Local-first with a stand-in engine**: prove the design on a laptop, then move each layer to the cloud and compare results.

## Decision
Local-first, with three tools:
- **DuckDB** as a stand-in for Databricks. It runs SQL on Parquet files on a laptop, needs no server, and has a dbt adapter. Moving dbt to Databricks changes only `profiles.yml`.
- **Docker (docker-compose)** to run Airflow locally, so the scheduler runs the same way on any machine, without installing Airflow on the laptop.
- **uv** with a lock file (`uv.lock`), so the laptop, the Airflow image and CI install exactly the same library versions.

Order of work: laptop pipeline, then Airflow in Docker, then CI, then S3 with Terraform, then the Databricks spike, then dbt on Databricks.

## Consequences
- The design was proven before any cloud money was spent; cloud steps only had to match known numbers (146,486 / 145,968 / 518).
- Each move changed one thing, so each failure pointed to one cause (for example the `timestampNtz` error appeared only in the Databricks step).
- DuckDB allows one writer at a time, which caused the Airflow lock incident and the `max_active_runs=1` fix (ADR-0005).
- Two engines must stay compatible; this cost two small SQL changes (ADR-0003).
