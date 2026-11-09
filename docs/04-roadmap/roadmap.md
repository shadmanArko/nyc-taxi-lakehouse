# Roadmap

Timeline assumed roughly 100 days of AWS access, with cloud work scheduled after local-first foundations. Status below is as of 2026-11-09.

| Milestone | Goal | Exit criteria | Status |
|---|---|---|---|
| **M0 Design** | Product brief, requirements, architecture, ADRs, standards | Docs written; open questions logged | **Done.** Docs were updated after the build to match it. |
| **M1 Foundations** | Repo tooling, CI skeleton, Databricks Free Edition spike, local Airflow runtime | CI green; spike confirms ingestion path (updates ADR-0003) | **Done.** CI runs tests and the whole dbt build; ADR-0003 is accepted with the spike results. |
| **M2 Ingestion** | Hardened downloader, checksum, idempotency, unit tests | Month downloaded repeatedly with identical result | **Done, with a gap:** the checksum is printed, not stored. |
| **M3 AWS + Terraform** | S3, IAM, OIDC, budget alert, remote state | `apply` and `destroy` both clean; CI uses OIDC | **Partly done.** S3 bucket and the Databricks read role are in Terraform and `plan` shows no changes. OIDC, budget alert, remote state and `destroy` were not done. |
| **M4 Lakehouse + dbt** | Bronze load, Silver and Gold models, tests, quarantine, reconciliation | `dbt build` passes; reconciliation enforced | **Done** on DuckDB and on Databricks: 16 of 16 checks, identical row counts. |
| **M5 Orchestration** | Airflow DAG with Cosmos, retries, alerts, backfill | Backfill of Jan to Mar runs unattended | **Partly done.** A scheduled DAG with retries runs the DuckDB path. No Cosmos, no backfill, alerts only print. |
| **M6 Quality + Observability** | Elementary, run metadata, lineage docs, runbooks | Induced failure produces an alert and a documented recovery | **Not started.** One failure was induced on purpose and caught (the dropoff rule experiment), but there is no alert or runbook. |
| **M7 Serving + Showcase** | Dashboard, diagrams, demo script, polished README | Fresh-clone demo works from documented steps | **Partly done.** Story README with evidence, code tour and diagrams exist. No dashboard. |

## Next up

1. A dashboard on `gold_daily_revenue`.
2. Run the Databricks path from Airflow (token as a secret in the container).
3. Real failure alerts, a per-run reject report, and storing the file checksum.
4. A "complete day" flag in Gold for the partial edge days.
5. Backfill by date range.

## Out of scope for now (candidate ADRs)

Streaming ingestion, additional TLC datasets, MWAA deployment, data contracts with a schema registry.
