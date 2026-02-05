################################################################################
# Lambda Module
# Deploys Lambda functions with best security practices
################################################################################

locals {
  function_name = "${var.project_name}-${var.environment}-${var.function_name}"

  common_tags = merge(
    var.tags,
    {
      Name         = local.function_name
      Service      = "lambda"
      Runtime      = var.runtime
      ManagedBy    = "terraform"
      Module       = "lambda"
      ResourceType = "lambda-function"
    }
  )
}

################################################################################
# CloudWatch Log Group
# Create log group before Lambda to ensure proper log encryption
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.cloudwatch_kms_key_arn

  tags = merge(local.common_tags, {
    ResourceType = "cloudwatch-log-group"
  })
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = var.description
  role          = var.lambda_role_arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  # Deployment package
  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version
  source_code_hash  = var.source_code_hash

  # VPC Configuration (optional)
  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null ? [1] : []
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

  # Dead letter queue for failed invocations
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  # Tracing configuration for X-Ray
  tracing_config {
    mode = var.tracing_mode
  }

  # Reserved concurrency (set to -1 to disable)
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Encryption for environment variables at rest
  kms_key_arn = var.lambda_kms_key_arn

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = local.common_tags
}

################################################################################
# Lambda Function URL (optional, for direct HTTPS access)
################################################################################

resource "aws_lambda_function_url" "this" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age           = cors.value.max_age
    }
  }
}

################################################################################
# Lambda Alias (for traffic shifting and blue/green deployments)
################################################################################

resource "aws_lambda_alias" "this" {
  count = var.create_alias ? 1 : 0

  name             = var.alias_name
  description      = "Alias for ${local.function_name}"
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version

  dynamic "routing_config" {
    for_each = var.alias_routing_additional_version_weights != null ? [1] : []
    content {
      additional_version_weights = var.alias_routing_additional_version_weights
    }
  }
}
