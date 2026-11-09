# ADR-0004: dbt for transformations

- Status: Accepted
- Date: 2026-11-05
- Deciders: Shadman Arko

## Context
Silver and Gold logic must be versioned, tested, documented, and reviewable.

## Options considered
1. Databricks notebooks / jobs with PySpark: flexible, but harder to test, review and document.
2. Delta Live Tables: powerful, but ties logic to Databricks and is less portable.
3. **dbt Core with `dbt-databricks`**: SQL models, built-in tests, docs, lineage, incremental strategies, industry standard.

## Decision
Use dbt Core for Silver and Gold. Use `incremental` models with `merge` keyed on `trip_id` / `service_date`.

## Consequences
- Tests and docs come with the models; lineage graph for free.
- Bronze loading stays outside dbt.
- Team must learn dbt conventions (staging/marts, YAML contracts).

## Amendment 2026-11-09
Built as planned with two differences.
- **Models are plain `table` materializations, rebuilt in full on every run, not incremental merges.** The data is small (146,486 Bronze rows): a full build takes about 1 second on DuckDB and about 80 seconds on Databricks including the tests. A full rebuild is idempotent by construction and has no merge keys to maintain. Revisit when volume makes a rebuild slow.
- **Two engines.** `profiles.yml` has a `dev` target (DuckDB, the default) and a `databricks` target (credentials from environment variables). Only two small changes were needed to run the same models on both (see ADR-0003).

A staging model (`stg_green_trips_classified`) holds every validity rule, so Silver and the quarantine table are two opposite filters over the same labelled rows.
