# NYC Taxi Lakehouse

A production-style data platform that ingests NYC TLC trip records, models them in a medallion lakehouse, and serves trusted revenue analytics.

> **Status:** Design phase. No implementation code yet; see the [roadmap](docs/04-roadmap/roadmap.md).

## Why this exists

Show how a modern data team builds, tests, deploys and operates a pipeline: contract-driven ingestion, layered modelling, automated quality gates, infrastructure as code, and CI/CD. The dataset is small by design. The engineering practices are the point.

## Stack (target)

| Concern | Tool |
|---|---|
| Landing storage | AWS S3 |
| Lakehouse / compute | Databricks (Free Edition first, see ADR-0003) |
| Transformation | dbt Core (`dbt-databricks`) |
| Orchestration | Apache Airflow (+ Cosmos) |
| Infrastructure as code | Terraform |
| CI/CD | GitHub Actions (AWS OIDC) |
| Data quality | dbt tests, dbt-expectations, Elementary |
| Serving | Databricks AI/BI dashboard |

## Documentation map

| Area | Where |
|---|---|
| Product brief and requirements | [docs/00-product](docs/00-product/) |
| Architecture and data model | [docs/01-architecture](docs/01-architecture/) |
| Architecture Decision Records | [docs/02-adr](docs/02-adr/) |
| Engineering standards | [docs/03-engineering](docs/03-engineering/) |
| Roadmap and milestones | [docs/04-roadmap](docs/04-roadmap/) |

## Repository layout (planned)

```
ingestion/   Python ingestion package
dbt/         dbt project (silver, gold, tests, docs)
airflow/     DAGs and local Airflow runtime
terraform/   AWS and Databricks infrastructure
docs/        Design and decision records
.github/     CI/CD workflows, PR template
```
