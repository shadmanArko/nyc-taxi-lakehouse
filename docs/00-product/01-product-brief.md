# Product Brief

| | |
|---|---|
| Owner | Shadman Arko |
| Status | v0.2: definitions confirmed after profiling the data; see the delivered-vs-planned scorecard in the [README](../../README.md) |
| Last updated | 2026-11-09 |

## 1. Problem

Analysts at a taxi-fleet operator need a daily, trusted view of revenue and trip volume. Raw TLC files arrive monthly as Parquet, with inconsistent columns, bad timestamps, duplicates and occasional late corrections. Today, answers come from ad-hoc scripts: slow, unreproducible, and with no way to tell whether a number is right.

## 2. Users and jobs to be done

| Persona | Job | Needs |
|---|---|---|
| Finance analyst | "What was revenue yesterday and this month?" | Correct, reconciled daily revenue; clear definitions |
| Operations manager | "How is demand trending by day and borough?" | Trip counts, trends, drill-down |
| Data engineer (maintainer) | "Is the pipeline healthy? Can I backfill safely?" | Alerts, lineage, idempotent reruns, runbooks |

## 3. Goals

1. Produce a **daily revenue** dataset (revenue, trip count, average fare) for Green Taxi trips that analysts can trust.
2. Make every number **traceable** (lineage from dashboard to source file) and **verifiable** (reconciliation to source).
3. Make the pipeline **reproducible and safe to rerun** (idempotent, backfillable).
4. Run the platform the way a production team would: IaC, CI/CD, tests as gates, documented decisions.

## 4. Non-goals

- Real-time or streaming ingestion (batch only; revisit as a later ADR).
- Yellow, FHV and HVFHV datasets in v1 (the design must allow adding them).
- Machine learning or forecasting.
- Multi-tenant access control beyond role separation.

## 5. Scope (v1)

- Source: NYC TLC Green Taxi trip records, Jan–Mar 2025, extensible to any month.
- Output: the daily revenue table `gold_daily_revenue` (built); a dashboard is still to do.
- Environments: `dev` only so far. `prod` is future work.

## 6. Success metrics

| Metric | Target |
|---|---|
| Gold revenue reconciles to source total (after documented exclusions) | 100%, enforced by test |
| Pipeline rerun produces identical output (idempotency) | Yes, verified in CI |
| Time from file availability to dashboard refresh | < 30 min |
| Failed run triggers alert | < 5 min |
| Test coverage: every Silver/Gold model has schema and uniqueness tests | 100% |
| Fresh environment from zero via Terraform + CI | One documented command path |

## 7. Key business definitions (confirmed 2026-11-09; the first draft is replaced)

The first draft defined revenue as the sum of `total_amount` and a valid trip as one with non-negative amounts and a pickup date inside the file's month. Profiling the three real files changed that:

- **Service date:** calendar date of `lpep_pickup_datetime`.
- **Revenue:** `total_amount` minus `tip_amount`. Card tips are recorded and cash tips are not, so including tips would make card and cash trips incomparable.
- **Gross revenue / adjustments / net revenue:** revenue of trips that are not adjustments; revenue of trips with a negative total; their sum. Negative amounts are kept and reported, not dropped. *(Assumption: they are refunds or disputes. A real finance team must confirm.)*
- **Valid trip:** pickup, dropoff and amount are present, the trip does not end before it starts, and it is not a duplicate. Trips outside their file's month are kept and grouped by their own pickup date, which leaves a few partial edge days.
- **Missing descriptive fields:** trips with an empty rate code, passenger count, payment type and store-and-forward flag are kept and flagged (`fields_missing`), because they carry real revenue.

Full column-level detail: [data-model.md](../01-architecture/data-model.md).

## 8. Risks and assumptions

| Risk | Mitigation |
|---|---|
| Databricks Free Edition limits (compute, external storage) | ADR-0003: design for Free Edition first, keep an upgrade path |
| AWS free access expires (~100 days) | Everything in Terraform, destroyable and rebuildable |
| Source schema drift across months | Bronze keeps raw; Silver enforces explicit schema; contract tests |
| Scope creep into too many tools | Each tool must have an ADR justifying it |
