################################################################################
# Data Sources and Locals
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  resource_prefix = "${var.project_name}-${var.environment}"
  function_name   = "${local.resource_prefix}-${var.app_name}"
  account_id      = data.aws_caller_identity.current.account_id

  common_tags = merge(var.tags, {
    Component   = "webapp"
    Application = var.app_name
  })

  # Use provided image or a placeholder (AWS public ECR for testing)
  container_image_uri = var.container_image_uri != "" ? var.container_image_uri : "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.resource_prefix}-${var.app_name}:latest"

  # Default environment variables
  default_environment_variables = {
    ENVIRONMENT     = var.environment
    APP_NAME        = var.app_name
    AWS_REGION_NAME = var.aws_region
    LOG_LEVEL       = var.environment == "prod" ? "INFO" : "DEBUG"
  }

  # Merge default and custom environment variables
  lambda_environment_variables = merge(
    local.default_environment_variables,
    var.environment_variables
  )
}

################################################################################
# ECR Repository
################################################################################

resource "aws_ecr_repository" "app" {
  name                 = "${local.resource_prefix}-${var.app_name}"
  image_tag_mutability = "MUTABLE" # Use IMMUTABLE for production

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # Or use KMS for stricter requirements
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-${var.app_name}"
  })
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

################################################################################
# IAM Role for Lambda
################################################################################

resource "aws_iam_role" "lambda" {
  name        = "${local.function_name}-role"
  description = "IAM role for ${local.function_name} Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-role"
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy (if VPC enabled)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.vpc_enabled ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing policy
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count      = var.enable_xray_tracing ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Custom policy for Secrets Manager access
resource "aws_iam_role_policy" "lambda_secrets" {
  count = length(var.secrets_arns) > 0 ? 1 : 0
  name  = "secrets-access"
  role  = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.secrets_arns
      }
    ]
  })
}

# ECR pull policy
resource "aws_iam_role_policy" "lambda_ecr" {
  name = "ecr-pull"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = [aws_ecr_repository.app.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      }
    ]
  })
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-logs"
  })
}

################################################################################
# Lambda Function (Container Image)
################################################################################

resource "aws_lambda_function" "app" {
  function_name = local.function_name
  description   = "${var.app_name} web application running as Lambda container"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = local.container_image_uri

  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
  architectures = [var.lambda_architecture]

  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions

  # Container image overrides
  dynamic "image_config" {
    for_each = length(var.container_command) > 0 || length(var.container_entry_point) > 0 || var.container_working_directory != "" ? [1] : []
    content {
      command           = length(var.container_command) > 0 ? var.container_command : null
      entry_point       = length(var.container_entry_point) > 0 ? var.container_entry_point : null
      working_directory = var.container_working_directory != "" ? var.container_working_directory : null
    }
  }

  environment {
    variables = local.lambda_environment_variables
  }

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_enabled ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  # X-Ray tracing
  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic
  ]

  tags = merge(local.common_tags, {
    Name = local.function_name
  })

  lifecycle {
    # Ignore image_uri changes to allow external CI/CD to update
    ignore_changes = [image_uri]
  }
}

################################################################################
# Lambda Function URL (Alternative to API Gateway)
################################################################################

resource "aws_lambda_function_url" "app" {
  count              = var.enable_function_url ? 1 : 0
  function_name      = aws_lambda_function.app.function_name
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.function_url_auth_type == "NONE" ? [1] : []
    content {
      allow_credentials = var.function_url_cors.allow_credentials
      allow_headers     = var.function_url_cors.allow_headers
      allow_methods     = var.function_url_cors.allow_methods
      allow_origins     = var.function_url_cors.allow_origins
      expose_headers    = var.function_url_cors.expose_headers
      max_age           = var.function_url_cors.max_age
    }
  }
}

################################################################################
# API Gateway HTTP API
################################################################################

resource "aws_apigatewayv2_api" "app" {
  count         = var.enable_api_gateway ? 1 : 0
  name          = "${local.function_name}-api"
  description   = "HTTP API for ${var.app_name}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["*"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"]
    allow_origins     = ["*"]
    expose_headers    = ["*"]
    max_age           = 86400
  }

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-api"
  })
}

resource "aws_apigatewayv2_integration" "app" {
  count                  = var.enable_api_gateway ? 1 : 0
  api_id                 = aws_apigatewayv2_api.app[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.app.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "app" {
  count     = var.enable_api_gateway ? 1 : 0
  api_id    = aws_apigatewayv2_api.app[0].id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.app[0].id}"
}

resource "aws_apigatewayv2_route" "app_proxy" {
  count     = var.enable_api_gateway ? 1 : 0
  api_id    = aws_apigatewayv2_api.app[0].id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.app[0].id}"
}

# API Gateway Stage with Access Logging
resource "aws_cloudwatch_log_group" "api_gateway" {
  count             = var.enable_api_gateway && var.enable_api_gateway_access_logs ? 1 : 0
  name              = "/aws/apigateway/${local.function_name}-api"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-api-logs"
  })
}

resource "aws_apigatewayv2_stage" "app" {
  count       = var.enable_api_gateway ? 1 : 0
  api_id      = aws_apigatewayv2_api.app[0].id
  name        = var.api_gateway_stage_name
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

  dynamic "access_log_settings" {
    for_each = var.enable_api_gateway_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gateway[0].arn
      format = jsonencode({
        requestId          = "$context.requestId"
        ip                 = "$context.identity.sourceIp"
        requestTime        = "$context.requestTime"
        httpMethod         = "$context.httpMethod"
        routeKey           = "$context.routeKey"
        status             = "$context.status"
        protocol           = "$context.protocol"
        responseLength     = "$context.responseLength"
        integrationError   = "$context.integrationErrorMessage"
        integrationLatency = "$context.integrationLatency"
      })
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-api-stage"
  })
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  count         = var.enable_api_gateway ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.app[0].execution_arn}/*/*"
}

################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alarm_error_threshold
  alarm_description   = "Lambda function error count exceeds threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-errors-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_duration_threshold
  alarm_description   = "Lambda function duration exceeds threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-duration-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${local.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.function_name}-throttles-alarm"
  })
}
