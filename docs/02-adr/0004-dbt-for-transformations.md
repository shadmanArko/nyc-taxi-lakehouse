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
