################################################################################
# Application Module - Lambda Functions with Supporting Resources
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Locals
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  common_tags = merge(var.tags, {
    Component = "application"
  })

  lambda_name = "${local.resource_prefix}-${var.lambda_name}"
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "main" {
  function_name = local.lambda_name
  description   = var.lambda_description
  role          = aws_iam_role.lambda_execution.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  # Package configuration - supports both S3 and local zip
  s3_bucket         = var.lambda_s3_bucket != "" ? var.lambda_s3_bucket : null
  s3_key            = var.lambda_s3_key != "" ? var.lambda_s3_key : null
  s3_object_version = var.lambda_s3_object_version != "" ? var.lambda_s3_object_version : null
  filename          = var.lambda_filename != "" ? var.lambda_filename : null
  source_code_hash  = var.lambda_source_code_hash

  # VPC Configuration (optional)
  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  # Environment variables
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  # Tracing configuration
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # Reserved concurrency (optional)
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Dead letter queue (optional)
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != "" ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }

  # KMS encryption for environment variables
  kms_key_arn = aws_kms_key.lambda.arn

  # Code signing configuration (optional)
  # checkov:skip=CKV_AWS_272: Code signing requires AWS Signer profile - configurable via code_signing_config_arn variable
  code_signing_config_arn = var.code_signing_config_arn != "" ? var.code_signing_config_arn : null

  tags = merge(local.common_tags, {
    Name = local.lambda_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda
  ]
}

################################################################################
# Lambda Alias (optional - for stable endpoint)
################################################################################

resource "aws_lambda_alias" "live" {
  count = var.create_alias ? 1 : 0

  name             = var.alias_name
  description      = "Live alias for ${local.lambda_name}"
  function_name    = aws_lambda_function.main.function_name
  function_version = var.alias_function_version != "" ? var.alias_function_version : aws_lambda_function.main.version
}

################################################################################
# Lambda IAM Role
################################################################################

resource "aws_iam_role" "lambda_execution" {
  name = "${local.lambda_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.lambda_name}-execution-role"
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy (if VPC enabled)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.enable_vpc ? 1 : 0

  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing policy
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count = var.enable_xray_tracing ? 1 : 0

  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Custom policy for additional permissions
resource "aws_iam_role_policy" "lambda_custom" {
  count = length(var.additional_iam_statements) > 0 ? 1 : 0

  name = "${local.lambda_name}-custom-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.additional_iam_statements
  })
}

# KMS access for Lambda
resource "aws_iam_role_policy" "lambda_kms" {
  name = "${local.lambda_name}-kms-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.lambda.arn
      }
    ]
  })
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.lambda.arn

  tags = merge(local.common_tags, {
    Name = "${local.lambda_name}-logs"
  })
}

################################################################################
# KMS Key for Lambda
################################################################################

resource "aws_kms_key" "lambda" {
  description             = "KMS key for ${local.lambda_name} Lambda"
  deletion_window_in_days = var.kms_key_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda service to use the key"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs access"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.lambda_name}-kms"
  })
}

# KMS Alias - commented out for now
# resource "aws_kms_alias" "lambda" {
#   name          = "alias/${local.lambda_name}"
#   target_key_id = aws_kms_key.lambda.key_id
# }

################################################################################
# S3 Bucket for Lambda Artifacts (optional)
################################################################################

resource "aws_s3_bucket" "artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = "${local.resource_prefix}-lambda-artifacts"

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-lambda-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.lambda.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  count  = var.create_artifacts_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.artifacts_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

################################################################################
# CloudWatch Alarms (optional)
################################################################################

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.create_alarms ? 1 : 0

  alarm_name          = "${local.lambda_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Lambda function ${local.lambda_name} error rate exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(local.common_tags, {
    Name = "${local.lambda_name}-errors-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.create_alarms ? 1 : 0

  alarm_name          = "${local.lambda_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.lambda_timeout * 1000 * 0.9 # 90% of timeout
  alarm_description   = "Lambda function ${local.lambda_name} duration approaching timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(local.common_tags, {
    Name = "${local.lambda_name}-duration-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count = var.create_alarms ? 1 : 0

  alarm_name          = "${local.lambda_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda function ${local.lambda_name} is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(local.common_tags, {
    Name = "${local.lambda_name}-throttles-alarm"
  })
}
