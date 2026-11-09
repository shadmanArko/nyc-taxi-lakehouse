# ADR-0005: Airflow for orchestration

- Status: Accepted
- Date: 2026-11-05
- Deciders: Shadman Arko

## Context
The pipeline needs scheduling, retries, backfills, alerting, and dependency management across ingestion, load and dbt.

## Options considered
1. Prefect (used in the original reference solution): modern, light setup.
2. Databricks Workflows: native, but only orchestrates Databricks and is limited on Free Edition.
3. **Apache Airflow**: most widely deployed in industry; Cosmos renders dbt models as tasks; strong backfill semantics.
4. Managed Airflow (MWAA): production-grade but around $350+/month, too costly for this project.

## Decision
Airflow, run locally in Docker (Astro CLI or docker-compose). MWAA is documented as the production deployment option, not provisioned.

## Consequences
- Industry-standard skill demonstrated; clean backfill story.
- Local runtime means no always-on scheduler; demos run on demand.

## Amendment 2026-11-09
Built with docker-compose (Airflow `standalone`, an image that installs the project from `uv.lock` into its own environment). Differences from the plan:
- **Plain `BashOperator` tasks, no Cosmos.** Three tasks (`download`, `load_bronze`, `dbt_build`) run the same commands used by hand. Cosmos was not needed for four models.
- **`max_active_runs=1`** was added after a manual and a scheduled run overlapped and locked the DuckDB file. Retries (2, one minute apart) recovered that run.
- **Not done:** backfill by date range (the months are fixed in the download step); real failure alerts (the callback only prints a message).
- **Scope:** the DAG runs the local DuckDB pipeline only. Running the Databricks path from Airflow is still open (ADR-0003, "Still unverified").
