# ADR-0006: Terraform for infrastructure

- Status: Accepted
- Date: 2026-11-05
- Deciders: Shadman Arko

## Context
AWS access is time-limited (about 100 days). The environment must be rebuildable and destroyable, and changes must be reviewable.

## Options considered
1. Console clicks: fast, not reproducible.
2. CloudFormation/CDK: AWS-only.
3. **Terraform**: declarative, multi-provider (AWS, Databricks), widely used.

## Decision
All AWS resources (S3, IAM, OIDC trust, budgets) are defined in Terraform with remote state in S3 and locking. CI runs `plan` on pull requests.

## Consequences
- One-command rebuild and teardown.
- Bootstrap step needed for the state bucket.
- Databricks resources managed in Terraform only where Free Edition allows (ADR-0003).
