################################################################################
# Deployment Artifacts S3 Bucket Module
# S3 bucket for Lambda deployment packages with security best practices
################################################################################

locals {
  bucket_name = "${var.project_name}-${var.environment}-artifacts-${var.aws_account_id}"

  common_tags = merge(
    var.tags,
    {
      Name         = local.bucket_name
      Service      = "s3"
      ManagedBy    = "terraform"
      Module       = "deployment-artifacts"
      ResourceType = "s3-bucket"
      Purpose      = "deployment-artifacts"
    }
  )
}

################################################################################
# S3 Bucket
################################################################################

resource "aws_s3_bucket" "artifacts" {
  bucket = local.bucket_name

  tags = local.common_tags
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# Lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "cleanup-old-artifacts"
    status = "Enabled"

    filter {
      prefix = "lambdas/"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.artifact_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-to-infrequent-access"
    status = var.enable_intelligent_tiering ? "Enabled" : "Disabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }
}

# Bucket policy
resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowLambdaServiceRead"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# Enable logging (optional)
resource "aws_s3_bucket_logging" "artifacts" {
  count = var.logging_bucket_id != null ? 1 : 0

  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = var.logging_bucket_id
  target_prefix = "s3-access-logs/${local.bucket_name}/"
}
