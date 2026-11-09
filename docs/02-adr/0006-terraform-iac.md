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

## Amendment 2026-11-09
Implemented for the S3 landing bucket (`main.tf`) and the read-only IAM role Databricks assumes (`iam.tf`). Differences from the plan:
- **Local state.** `terraform.tfstate` stays on the laptop and is ignored by git. A remote state bucket with locking was planned and is not built; for one person on a time-limited account the risk was accepted.
- **Not done:** the GitHub OIDC trust, a budget alert, and `terraform plan` in CI.
- **Two-phase apply for the IAM role.** Databricks reveals its External ID only after the credential exists, so the role is applied first with a placeholder and updated afterwards. The real values live in `terraform.tfvars`, which git ignores.
- **The Databricks credential and external location were created in the UI**, not in Terraform.
- Encryption is SSE-S3, not SSE-KMS (see ADR-0007).
