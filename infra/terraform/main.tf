# Landing zone: one private S3 bucket that holds the raw files, unchanged.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# Bucket names are unique across ALL of AWS, so we add our own prefix.
variable "bucket_name" {
  type    = string
  default = "arko-nyc-taxi-lakehouse-landing"
}

# 1. The bucket itself.
resource "aws_s3_bucket" "landing" {
  bucket = var.bucket_name
}

# 2. Nobody can ever make this bucket public, even by mistake.
resource "aws_s3_bucket_public_access_block" "landing" {
  bucket = aws_s3_bucket.landing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Keep old versions of a file when it is overwritten (raw data is never lost).
resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 4. Encrypt everything stored (free, AWS-managed key).
resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "landing_bucket" {
  value = aws_s3_bucket.landing.bucket
}
