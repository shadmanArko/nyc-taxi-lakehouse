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
