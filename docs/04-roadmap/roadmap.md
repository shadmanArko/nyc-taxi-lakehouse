# Roadmap

Timeline assumes roughly 100 days of AWS access. Cloud-dependent work is scheduled after local-first foundations.

| Milestone | Goal | Exit criteria |
|---|---|---|
| **M0 Design** (now) | Product brief, requirements, architecture, ADRs, standards | Docs reviewed and merged; open questions logged |
| **M1 Foundations** | Repo tooling, CI skeleton, Databricks Free Edition spike, local Airflow runtime | CI green on empty project; spike confirms ingestion path (updates ADR-0003) |
| **M2 Ingestion** | Hardened downloader, checksum, idempotency, unit tests | Month downloaded to local/S3 landing repeatedly with identical result |
| **M3 AWS + Terraform** | S3, IAM, OIDC, budget alert, remote state | `terraform apply` and `destroy` both clean; CI uses OIDC |
| **M4 Lakehouse + dbt** | Bronze load, Silver/Gold models, tests, quarantine, reconciliation | `dbt build` passes; reconciliation invariant enforced |
| **M5 Orchestration** | Airflow DAG with Cosmos, retries, alerts, backfill | Backfill of Jan–Mar 2025 runs end-to-end unattended |
| **M6 Quality + Observability** | Elementary, run metadata, lineage docs, runbooks | Induced failure produces alert and documented recovery |
| **M7 Serving + Showcase** | Dashboard, architecture diagrams, demo script, polished README | Fresh-clone demo works from documented steps |

## Out of scope for now (candidate ADRs)

Streaming ingestion, additional TLC datasets, MWAA deployment, data contracts with a schema registry.
