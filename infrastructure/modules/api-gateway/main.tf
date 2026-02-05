################################################################################
# API Gateway Module
# REST API Gateway with Lambda integration and security best practices
################################################################################

locals {
  api_name = var.api_name_suffix != null ? "${var.project_name}-${var.environment}-${var.api_name_suffix}" : "${var.project_name}-${var.environment}-api"

  common_tags = merge(
    var.tags,
    {
      Name         = local.api_name
      Service      = "api-gateway"
      ManagedBy    = "terraform"
      Module       = "api-gateway"
      ResourceType = "rest-api"
    }
  )
}

################################################################################
# REST API
################################################################################

resource "aws_api_gateway_rest_api" "this" {
  name        = local.api_name
  description = var.description

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  # Minimum TLS version
  minimum_compression_size = var.minimum_compression_size

  tags = local.common_tags
}

################################################################################
# CloudWatch Log Group for API Gateway Access Logs
################################################################################

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${local.api_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.cloudwatch_kms_key_arn

  tags = merge(local.common_tags, {
    ResourceType = "cloudwatch-log-group"
  })
}

################################################################################
# API Gateway Stage
################################################################################

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name

  # Enable caching (optional)
  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_size

  # X-Ray tracing
  xray_tracing_enabled = var.xray_tracing_enabled

  # Access logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      sourceIp          = "$context.identity.sourceIp"
      requestTime       = "$context.requestTime"
      protocol          = "$context.protocol"
      httpMethod        = "$context.httpMethod"
      resourcePath      = "$context.resourcePath"
      routeKey          = "$context.routeKey"
      status            = "$context.status"
      responseLength    = "$context.responseLength"
      integrationError  = "$context.integrationErrorMessage"
      errorMessage      = "$context.error.message"
      errorResponseType = "$context.error.responseType"
      userAgent         = "$context.identity.userAgent"
      requestTimeEpoch  = "$context.requestTimeEpoch"
    })
  }

  tags = merge(local.common_tags, {
    Stage = var.stage_name
  })

  depends_on = [aws_api_gateway_account.this]
}

################################################################################
# API Gateway Method Settings (for throttling and logging)
################################################################################

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    # Logging
    metrics_enabled    = true
    logging_level      = var.logging_level
    data_trace_enabled = var.data_trace_enabled

    # Throttling
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit

    # Caching
    caching_enabled      = var.caching_enabled
    cache_ttl_in_seconds = var.cache_ttl_seconds
  }
}

################################################################################
# API Gateway Deployment
################################################################################

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.this.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# API Gateway Account (for CloudWatch logging)
################################################################################

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

################################################################################
# IAM Role for API Gateway CloudWatch Logging
################################################################################

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.api_name}-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    ResourceType = "iam-role"
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name = "${local.api_name}-cloudwatch-policy"
  role = aws_iam_role.api_gateway_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# WAF Web ACL Association (optional)
################################################################################

resource "aws_wafv2_web_acl_association" "this" {
  count = var.waf_web_acl_arn != null ? 1 : 0

  resource_arn = aws_api_gateway_stage.this.arn
  web_acl_arn  = var.waf_web_acl_arn
}

################################################################################
# Custom Domain (optional)
################################################################################

resource "aws_api_gateway_domain_name" "this" {
  count = var.custom_domain_name != null ? 1 : 0

  domain_name              = var.custom_domain_name
  regional_certificate_arn = var.acm_certificate_arn
  security_policy          = "TLS_1_2"

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = merge(local.common_tags, {
    ResourceType = "custom-domain"
  })
}

resource "aws_api_gateway_base_path_mapping" "this" {
  count = var.custom_domain_name != null ? 1 : 0

  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  domain_name = aws_api_gateway_domain_name.this[0].domain_name
  base_path   = var.base_path_mapping
}
