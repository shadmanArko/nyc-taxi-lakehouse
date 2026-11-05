# Engineering Standards

## Workflow

- Trunk-based: short-lived branches off `main`, merged by pull request; `main` is always deployable.
- Branch names: `feat/…`, `fix/…`, `docs/…`, `chore/…`.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat: add bronze loader`).
- Every PR: description, linked issue, passing CI, and an ADR if it changes architecture.
- Squash merge; `main` branch protection requires CI to pass.

## Definition of Done

- Code and tests merged; CI green.
- Docs updated (data model, ADRs, runbook as relevant).
- dbt models have descriptions and tests.
- No secrets in the repo; infrastructure changes via Terraform.

## Testing strategy

| Level | Tool | Scope |
|---|---|---|
| Unit | pytest | Ingestion package logic |
| Data tests | dbt tests, dbt-expectations | Uniqueness, not null, ranges, reconciliation |
| Contract | dbt model contracts | Gold schema stability |
| Integration | CI run of `dbt build` on a small fixture dataset | End-to-end model graph |
| Infra | `terraform validate`, `plan`, tflint, checkov | IaC correctness and security |

## Tooling

- Python 3.13 managed with `uv`; dependencies locked.
- Ruff (lint + format), mypy or ty (types), SQLFluff for SQL.
- pre-commit hooks mirror CI checks.

## CI/CD (GitHub Actions)

| Trigger | Jobs |
|---|---|
| Pull request | lint, unit tests, dbt build (CI schema), terraform plan |
| Merge to `main` | deploy dbt to `prod`, terraform apply (manual approval) |
| Schedule | Airflow runs ingestion; CI is not the scheduler |

AWS access via GitHub OIDC role assumption; no static access keys.

## Security

- Least-privilege IAM per component (ingestion writes landing; Databricks reads landing).
- Secrets in AWS Secrets Manager or GitHub encrypted secrets; never in code.
- S3 buckets: block public access, versioning, SSE-KMS.
- Dependency and secret scanning enabled on the repository.

## Operations

- Runbook per pipeline failure mode (in `docs/03-engineering/runbooks/`, added in M4).
- Alerts on task failure and test failure.
- Monthly cost review and AWS Budget alert.
