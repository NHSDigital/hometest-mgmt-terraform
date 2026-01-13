################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  resource_prefix = "${var.project_name}-${var.environment}"
  account_id      = data.aws_caller_identity.current.account_id

  common_tags = merge(var.tags, {
    Component = "bootstrap"
  })
}

################################################################################
# KMS Key for State Encryption (Security Best Practice)
################################################################################

resource "aws_kms_key" "tfstate" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = var.kms_key_deletion_window_days
  enable_key_rotation     = true # Security best practice

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "tfstate-key-policy"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow GitHub Actions Role"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.gha_oidc_role.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-tfstate-key"
  })
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${local.resource_prefix}-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

################################################################################
# S3 Bucket for Terraform State
################################################################################

resource "aws_s3_bucket" "tfstate" {
  bucket = "${local.resource_prefix}-tfstate-${local.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-tfstate"
  })
}

# Enable versioning for state history and recovery
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true # Reduces KMS costs
  }
}

# Block all public access (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL/TLS connections only
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "EnforceTLSVersion"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = "1.2"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# Lifecycle rules for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "noncurrent-version-expiration"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.state_bucket_retention_days
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# Access logging for audit trail (Conditional)
resource "aws_s3_bucket" "tfstate_logs" {
  count  = var.enable_state_bucket_logging ? 1 : 0
  bucket = "${local.resource_prefix}-tfstate-logs-${local.account_id}"

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-tfstate-logs"
  })
}

resource "aws_s3_bucket_versioning" "tfstate_logs" {
  count  = var.enable_state_bucket_logging ? 1 : 0
  bucket = aws_s3_bucket.tfstate_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_logs" {
  count  = var.enable_state_bucket_logging ? 1 : 0
  bucket = aws_s3_bucket.tfstate_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_logs" {
  count  = var.enable_state_bucket_logging ? 1 : 0
  bucket = aws_s3_bucket.tfstate_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate_logs" {
  count  = var.enable_state_bucket_logging ? 1 : 0
  bucket = aws_s3_bucket.tfstate_logs[0].id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 365
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_logging" "tfstate" {
  count  = var.enable_state_bucket_logging ? 1 : 0
  bucket = aws_s3_bucket.tfstate.id

  target_bucket = aws_s3_bucket.tfstate_logs[0].id
  target_prefix = "access-logs/"
}

################################################################################
# DynamoDB Table for State Locking
################################################################################

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${local.resource_prefix}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST" # Cost-effective for variable workloads
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Point-in-time recovery for disaster recovery
  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  # Server-side encryption with KMS
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate.arn
  }

  # Deletion protection
  deletion_protection_enabled = true

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-tfstate-lock"
  })
}
