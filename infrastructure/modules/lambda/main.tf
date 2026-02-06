################################################################################
# Lambda Module
# Deploys Lambda functions with best security practices
################################################################################

locals {
  function_name = "${var.project_name}-${var.environment}-${var.function_name}"

  # Placeholder code for initial deployment
  placeholder_code = <<EOF
exports.handler = async (event) => {
  return ${var.placeholder_response};
};
EOF

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
# Placeholder ZIP Archive (when use_placeholder is true)
################################################################################

data "archive_file" "placeholder" {
  count = var.use_placeholder ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/.placeholder/${local.function_name}.zip"

  source {
    content  = local.placeholder_code
    filename = "index.js"
  }
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

  # Deployment package priority:
  # 1. Placeholder (for initial deployment)
  # 2. Local filename (Terraform uploads directly)
  # 3. S3 bucket/key (pre-uploaded package)
  filename          = var.use_placeholder ? data.archive_file.placeholder[0].output_path : var.filename
  s3_bucket         = var.use_placeholder || var.filename != null ? null : var.s3_bucket
  s3_key            = var.use_placeholder || var.filename != null ? null : var.s3_key
  s3_object_version = var.use_placeholder || var.filename != null ? null : var.s3_object_version
  source_code_hash  = var.use_placeholder ? data.archive_file.placeholder[0].output_base64sha256 : var.source_code_hash

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

  timeouts {
    create = "2m"  # Custom create timeout (e.g., 10 minutes)
    update = "2m"   # Custom update timeout
    delete = "2m"   # Custom delete timeout for durable executions
  }
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

# * Failed to execute "terraform apply -auto-approve" in ./.terragrunt-cache/Omq22eG3YTbbRpQQRiuSifYiqLI/R-jNQY0q8KEUNT6OtV-g2bdzJkU/src/hometest-app
#   ╷
#   │ Error: creating Lambda Function (nhs-hometest-dev1-api2-handler): operation error Lambda: CreateFunction, https response error StatusCode: 400, RequestID: 1d444545-512a-490c-b759-3af233f5e51f, InvalidParameterValueException: The provided execution role does not have permissions to call CreateNetworkInterface on EC2
#   │
#   │   with module.api2_lambda.aws_lambda_function.this,
#   │   on ../../modules/lambda/main.tf line 64, in resource "aws_lambda_function" "this":
#   │   64: resource "aws_lambda_function" "this" {
#   │
#   ╵
#   ╷
#   │ Error: creating Lambda Function (nhs-hometest-dev1-api1-handler): operation error Lambda: CreateFunction, https response error StatusCode: 400, RequestID: bd03209b-d3fa-4704-9b7a-cbd929bc9934, InvalidParameterValueException: The provided execution role does not have permissions to call CreateNetworkInterface on EC2
#   │
#   │   with module.api1_lambda.aws_lambda_function.this,
#   │   on ../../modules/lambda/main.tf line 64, in resource "aws_lambda_function" "this":
#   │   64: resource "aws_lambda_function" "this" {
#   │
