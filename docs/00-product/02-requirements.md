# Requirements

## Functional requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-1 | Download TLC Green Taxi files for a given month and store them unmodified in S3 landing, with checksum and source URL recorded | Must |
| FR-2 | Ingestion is idempotent: re-running a month does not duplicate data | Must |
| FR-3 | Bronze preserves raw records plus load metadata (source file, load timestamp, batch id) | Must |
| FR-4 | Silver enforces types, removes duplicates, and quarantines invalid rows with a reason code | Must |
| FR-5 | Gold exposes `daily_revenue` (service_date, trip_count, total_revenue, avg_fare) | Must |
| FR-6 | Rejected rows are counted and reported per run | Must |
| FR-7 | Any month can be backfilled by passing a date range | Must |
| FR-8 | A dashboard shows daily revenue and trips | Should |
| FR-9 | New datasets (Yellow, FHV) can be added by configuration plus models, without changing orchestration | Could |

## Non-functional requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-1 | Reliability | Failed tasks retry with backoff; failures alert within 5 minutes |
| NFR-2 | Data quality | Tests gate promotion: failed tests block Gold publication |
| NFR-3 | Reproducibility | Same inputs produce same outputs; pinned dependencies |
| NFR-4 | Security | No long-lived credentials in the repo or CI; least-privilege IAM; secrets in a secrets manager |
| NFR-5 | Observability | Per-run metrics: rows in/out/rejected, duration; lineage visible |
| NFR-6 | Maintainability | All infrastructure as code; every non-trivial decision has an ADR |
| NFR-7 | Cost | Idle cost near zero; monthly budget alert configured |
| NFR-8 | Portability | Transformations are SQL in dbt, not tied to notebook code |

## Service level objectives (illustrative, v1)

| SLO | Target |
|---|---|
| Freshness | Gold updated within 30 min of scheduled run |
| Success rate | ≥ 95% of scheduled runs succeed without manual intervention |
| Correctness | 0 reconciliation test failures reaching Gold |
