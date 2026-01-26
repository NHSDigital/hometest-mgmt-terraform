################################################################################
# API Gateway with mTLS - Main Configuration
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# Locals
################################################################################

locals {
  resource_prefix = "${var.project_name}-${var.aws_account_shortname}-${var.environment}"

  common_tags = merge(var.tags, {
    Component = "api-gateway"
  })

  # API Gateway name following NHS naming convention
  api_name = "${local.resource_prefix}-api"
}

################################################################################
# API Gateway Account Settings (CloudWatch Role for Logging)
################################################################################

# IAM role for API Gateway to write to CloudWatch Logs
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.resource_prefix}-api-cloudwatch-role"

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
    Name = "${local.resource_prefix}-api-cloudwatch-role"
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Configure API Gateway account to use this role for CloudWatch logging
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}

################################################################################
# API Gateway REST API (Regional for mTLS support)
################################################################################

resource "aws_api_gateway_rest_api" "main" {
  name        = local.api_name
  description = "API Gateway for ${local.resource_prefix} with mTLS"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Enable mTLS mutual authentication
  # Clients must present a valid certificate from the truststore
  minimum_compression_size = var.enable_compression ? var.minimum_compression_size : null

  tags = merge(local.common_tags, {
    Name = local.api_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# S3 Bucket for mTLS Truststore (Client Certificates)
################################################################################

resource "aws_s3_bucket" "truststore" {
  count  = var.enable_mtls ? 1 : 0
  bucket = "${local.resource_prefix}-api-truststore"

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-api-truststore"
  })
}

resource "aws_s3_bucket_versioning" "truststore" {
  count  = var.enable_mtls ? 1 : 0
  bucket = aws_s3_bucket.truststore[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "truststore" {
  count  = var.enable_mtls ? 1 : 0
  bucket = aws_s3_bucket.truststore[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.api_gateway.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "truststore" {
  count  = var.enable_mtls ? 1 : 0
  bucket = aws_s3_bucket.truststore[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "truststore" {
  count  = var.enable_mtls ? 1 : 0
  bucket = aws_s3_bucket.truststore[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAPIGatewayAccess"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.truststore[0].arn}/*"
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.truststore[0].arn,
          "${aws_s3_bucket.truststore[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Upload placeholder truststore (will be replaced with actual CA bundle)
resource "aws_s3_object" "truststore" {
  count   = var.enable_mtls && var.truststore_content != "" ? 1 : 0
  bucket  = aws_s3_bucket.truststore[0].id
  key     = "truststore.pem"
  content = var.truststore_content

  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.api_gateway.arn
}

################################################################################
# KMS Key for API Gateway
################################################################################

resource "aws_kms_key" "api_gateway" {
  description             = "KMS key for ${local.resource_prefix} API Gateway"
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
        Sid    = "Allow API Gateway and S3 access"
        Effect = "Allow"
        Principal = {
          Service = ["apigateway.amazonaws.com", "s3.amazonaws.com"]
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
    Name = "${local.resource_prefix}-api-kms"
  })
}

resource "aws_kms_alias" "api_gateway" {
  name          = "alias/${local.resource_prefix}-api"
  target_key_id = aws_kms_key.api_gateway.key_id
}

################################################################################
# Wait for ACM Certificate to be ISSUED
################################################################################

data "aws_acm_certificate" "validated" {
  count    = var.create_custom_domain ? 1 : 0
  domain   = var.domain_name
  statuses = ["ISSUED"]

  depends_on = [var.certificate_arn]
}

################################################################################
# Custom Domain Name with mTLS
################################################################################

resource "aws_api_gateway_domain_name" "main" {
  count = var.create_custom_domain ? 1 : 0

  domain_name              = var.domain_name
  regional_certificate_arn = data.aws_acm_certificate.validated[0].arn

  dynamic "mutual_tls_authentication" {
    for_each = var.enable_mtls ? [1] : []
    content {
      truststore_uri     = "s3://${aws_s3_bucket.truststore[0].bucket}/${aws_s3_object.truststore[0].key}"
      truststore_version = aws_s3_object.truststore[0].version_id
    }
  }

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  security_policy = "TLS_1_2"

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-api-domain"
  })

  depends_on = [aws_s3_object.truststore]
}

################################################################################
# Route53 A Record - Alias to API Gateway Custom Domain
################################################################################

resource "aws_route53_record" "api_gateway_alias" {
  count = var.create_custom_domain && var.create_dns_record && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.main[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.main[0].regional_zone_id
    evaluate_target_health = true
  }
}

################################################################################
# Base Path Mapping
################################################################################

resource "aws_api_gateway_base_path_mapping" "main" {
  count = var.create_custom_domain ? 1 : 0

  api_id      = aws_api_gateway_rest_api.main.id
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
  stage_name  = aws_api_gateway_stage.main.stage_name

  depends_on = [aws_api_gateway_stage.main]
}

################################################################################
# API Gateway Resource for Lambda Integration
################################################################################

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = var.authorization_type

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Root resource method
resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_rest_api.main.root_resource_id
  http_method   = "ANY"
  authorization = var.authorization_type
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_rest_api.main.root_resource_id
  http_method = aws_api_gateway_method.root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

################################################################################
# API Gateway Deployment
################################################################################

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy.id,
      aws_api_gateway_method.proxy.authorization,
      aws_api_gateway_integration.proxy.id,
      aws_api_gateway_method.root.id,
      aws_api_gateway_method.root.authorization,
      aws_api_gateway_integration.root.id,
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.proxy,
    aws_api_gateway_integration.root
  ]
}

################################################################################
# API Gateway Stage
################################################################################

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  xray_tracing_enabled = var.enable_xray_tracing

  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      integrationLatency      = "$context.integration.latency"
      responseLatency         = "$context.responseLatency"
      userAgent               = "$context.identity.userAgent"
      clientCertSerialNumber  = "$context.identity.clientCert.serialNumber"
      clientCertValidity      = "$context.identity.clientCert.validity.notAfter"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-api-stage-${var.stage_name}"
  })

  # Must wait for API Gateway account to have CloudWatch role configured
  depends_on = [aws_api_gateway_account.main]
}

################################################################################
# CloudWatch Log Group for API Gateway Access Logs
################################################################################

resource "aws_cloudwatch_log_group" "api_gateway_access" {
  name              = "/aws/api-gateway/${local.api_name}/access-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.api_gateway.arn

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-api-access-logs"
  })
}

################################################################################
# API Gateway Method Settings
################################################################################

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = var.logging_level
    data_trace_enabled     = var.data_trace_enabled
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
    caching_enabled        = true
    cache_ttl_in_seconds   = 300
    cache_data_encrypted   = true
  }
}

################################################################################
# Lambda Permission for API Gateway
################################################################################

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
