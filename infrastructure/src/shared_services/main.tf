################################################################################
# Shared Services Infrastructure
# Contains resources shared across all environments:
# - WAF Web ACL (shared across API Gateways and CloudFront)
# - ACM Certificates (regional and global)
# - KMS Keys for encryption
# - Deployment Artifacts S3 Bucket
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  region          = data.aws_region.current.name
  resource_prefix = "${var.project_name}-${var.environment}"
}

################################################################################
# KMS Key for Encryption
################################################################################

resource "aws_kms_key" "main" {
  description             = "KMS key for ${local.resource_prefix} encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowLambdaService"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-kms-key"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.resource_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

################################################################################
# WAF Web ACL (Regional - for API Gateway)
################################################################################

resource "aws_wafv2_web_acl" "regional" {
  name        = "${local.resource_prefix}-regional-waf"
  description = "Regional WAF for API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting Rule
  rule {
    name     = "RateLimitRule"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.resource_prefix}-regional-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-regional-waf"
  })
}

################################################################################
# WAF Web ACL (CloudFront - must be in us-east-1)
################################################################################

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name        = "${local.resource_prefix}-cloudfront-waf"
  description = "CloudFront WAF for SPA distributions"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-cf-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting Rule for CloudFront
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-cf-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.resource_prefix}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-cloudfront-waf"
  })
}

################################################################################
# WAF Logging
################################################################################

resource "aws_cloudwatch_log_group" "waf_regional" {
  name              = "aws-waf-logs-${local.resource_prefix}-regional"
  retention_in_days = var.waf_log_retention_days
  kms_key_id        = aws_kms_key.main.arn

  tags = merge(var.tags, {
    Name = "aws-waf-logs-${local.resource_prefix}-regional"
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "regional" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_regional.arn]
  resource_arn            = aws_wafv2_web_acl.regional.arn
}

################################################################################
# ACM Certificate - Regional (for API Gateway)
################################################################################

resource "aws_acm_certificate" "regional" {
  count = var.create_acm_certificates ? 1 : 0

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-regional-cert"
  })
}

resource "aws_route53_record" "regional_cert_validation" {
  for_each = var.create_acm_certificates ? {
    for dvo in aws_acm_certificate.regional[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "regional" {
  count = var.create_acm_certificates ? 1 : 0

  certificate_arn         = aws_acm_certificate.regional[0].arn
  validation_record_fqdns = [for record in aws_route53_record.regional_cert_validation : record.fqdn]
}

################################################################################
# ACM Certificate - Global (for CloudFront - us-east-1)
################################################################################

resource "aws_acm_certificate" "cloudfront" {
  count    = var.create_acm_certificates ? 1 : 0
  provider = aws.us_east_1

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-cloudfront-cert"
  })
}

# Note: DNS validation records are the same as regional, so we don't need to create them again

resource "aws_acm_certificate_validation" "cloudfront" {
  count    = var.create_acm_certificates ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.regional_cert_validation : record.fqdn]
}

################################################################################
# Deployment Artifacts S3 Bucket (Shared across environments)
################################################################################

resource "aws_s3_bucket" "deployment_artifacts" {
  bucket = "${local.resource_prefix}-deployment-artifacts"

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-deployment-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "deployment_artifacts" {
  bucket = aws_s3_bucket.deployment_artifacts.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.artifact_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

################################################################################
# Developer IAM Role (Shared across environments)
################################################################################

resource "aws_iam_role" "developer" {
  name = "${local.resource_prefix}-developer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.developer_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = var.require_mfa ? {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        } : {}
      }
    ]
  })

  max_session_duration = 3600

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-developer-role"
  })
}

resource "aws_iam_role_policy" "developer_lambda" {
  name = "lambda-deployment"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaDeployment"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias"
        ]
        Resource = "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.project_name}-*"
      },
      {
        Sid    = "S3ArtifactAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.deployment_artifacts.arn,
          "${aws_s3_bucket.deployment_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}
