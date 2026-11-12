# Decision journey: from requirements to technology

One page that answers "why did you choose that, and why in that order?". Details live in the linked ADRs.

## 1. Requirement → what meets it

| What the brief needs | Pattern or tool that meets it | Why this one | Record |
|---|---|---|---|
| A trusted daily revenue number | Medallion layers (Bronze, Silver, Gold) with ELT | Raw data stays queryable; every rule is SQL that can be tested | [ADR-0002](../02-adr/0002-elt-medallion-lakehouse.md) |
| Every number traceable to its source | Immutable S3 landing zone, plus `_source_file` on every Bronze row | An untouched copy of each file to audit and replay from | [ADR-0007](../02-adr/0007-s3-landing-zone.md) |
| Safe reruns (FR-2) | Skip-if-exists download and upload; delete-then-insert per file; Databricks `COPY INTO` | Running twice must give the same result | [ADR-0007](../02-adr/0007-s3-landing-zone.md), [ADR-0003](../02-adr/0003-databricks-free-edition-first.md) |
| Rules that are versioned, tested and reviewable | dbt | Tests, lineage and docs come with the models | [ADR-0004](../02-adr/0004-dbt-for-transformations.md) |
| Proof that nothing is lost | dbt reconciliation tests | The build fails if rows vanish or totals drift | [data-model.md](data-model.md) |
| Daily schedule, retries, history | Airflow | Industry standard; the managed version was too costly | [ADR-0005](../02-adr/0005-airflow-orchestration.md) |
| Rebuildable infrastructure on a time-limited AWS account | Terraform | Reviewable, repeatable, destroyable | [ADR-0006](../02-adr/0006-terraform-iac.md) |
| No AWS keys in other systems; least privilege | IAM role that Databricks assumes, read-only, with an external ID | Short-lived access to one bucket only | [ADR-0003](../02-adr/0003-databricks-free-edition-first.md) |
| A real lakehouse engine at low cost | Databricks Free Edition | No licence cost; limits tested in a spike, not assumed | [ADR-0003](../02-adr/0003-databricks-free-edition-first.md) |
| Reproducible results everywhere | uv lock file; CI installs it frozen | Same versions on laptop, Docker and CI | [ADR-0008](../02-adr/0008-local-first-duckdb-docker-uv.md) |
| Prove the design before spending money | DuckDB locally, Airflow in Docker | Free, fast, and moving to Databricks changes one file | [ADR-0008](../02-adr/0008-local-first-duckdb-docker-uv.md) |
| A quality gate on every change | GitHub Actions running tests and the full dbt build | A clean machine catches what a laptop hides | [README](../../README.md) Chapter 6 |

## 2. The build order, and why each step came before the next

| Step | What I built | What it proved | Why at this point |
|---|---|---|---|
| 1 | Download and Bronze load on the laptop (DuckDB) | The raw data loads, reruns don't duplicate | Cheapest place to learn the data |
| 2 | dbt staging, Silver, quarantine, Gold, tests | The business rules and definitions hold; nothing is lost | Rules had to be right before anything was automated |
| 3 | Airflow in Docker | The same commands run on a schedule with retries | Automate only what already works by hand |
| 4 | GitHub Actions CI | The whole chain passes on a clean machine | Lock in quality before the cloud adds complexity |
| 5 | S3 bucket and upload with Terraform | Raw files have a durable, auditable home | First cloud step; small and cheap |
| 6 | Databricks spike (credential, external location) | Free Edition can read our S3 bucket securely | The biggest unknown, tested before building on it |
| 7 | Bronze on Databricks with `COPY INTO` | Same row counts as DuckDB; second run loads 0 rows | Move one layer, compare to known numbers |
| 8 | dbt on Databricks | Same 16 checks pass; same results as DuckDB | Only `profiles.yml` and two SQL details changed |

The rule behind the order: **change one thing at a time, and compare every new step with numbers already proven.** When something broke (the DuckDB lock, the `timestampNtz` error), there was only one new thing to suspect.

## 3. What is still open

See the "Design versus delivered" table in the [README](../../README.md) and the [roadmap](../04-roadmap/roadmap.md).
