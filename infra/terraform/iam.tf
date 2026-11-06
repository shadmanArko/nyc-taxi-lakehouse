# An IAM role that Databricks (Unity Catalog) may assume to READ the landing bucket.
# No AWS keys are stored in Databricks: it receives short-lived access through this role.
#
# Two phases, because Databricks only tells us its External ID AFTER we create the credential:
#   Phase 1: apply with the defaults (external id "0000", trust_self = false).
#   Phase 2: create the storage credential in Databricks, copy its External ID, then apply with
#            -var="databricks_external_id=<id>" -var="trust_self=true".

variable "databricks_external_id" {
  type    = string
  default = "0000" # placeholder for phase 1
}

variable "trust_self" {
  type    = bool
  default = false # Unity Catalog requires the role to trust itself (phase 2)
}

data "aws_caller_identity" "current" {}

locals {
  role_name = "databricks-landing-read"
  role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.role_name}"

  # Databricks' own role, published in the Databricks documentation.
  unity_catalog_master_role = "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
}

# WHO may assume this role: Databricks' role, and only with the right external id.
resource "aws_iam_role" "databricks_landing_read" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        AWS = concat([local.unity_catalog_master_role], var.trust_self ? [local.role_arn] : [])
      }
      Condition = {
        StringEquals = { "sts:ExternalId" = var.databricks_external_id }
      }
    }]
  })
}

# WHAT the role may do: read this one bucket, and assume itself (a Databricks requirement).
resource "aws_iam_role_policy" "databricks_landing_read" {
  name = "read-landing-bucket"
  role = aws_iam_role.databricks_landing_read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          aws_s3_bucket.landing.arn,
          "${aws_s3_bucket.landing.arn}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.role_arn
      },
    ]
  })
}

output "databricks_role_arn" {
  value = aws_iam_role.databricks_landing_read.arn
}
