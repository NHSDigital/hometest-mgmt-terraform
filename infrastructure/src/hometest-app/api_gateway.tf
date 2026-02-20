################################################################################
# API Gateways - Dynamic Creation from Lambda Map
# Each lambda with api_path_prefix gets its own API Gateway
################################################################################

locals {
  # Get unique API path prefixes from lambdas
  api_prefixes = toset([for k, v in local.api_lambdas : v.api_path_prefix])

  # Map of api_prefix to lambda name (for integration)
  api_to_lambda = { for k, v in local.api_lambdas : v.api_path_prefix => k }
}

################################################################################
# API Gateway REST APIs
################################################################################

resource "aws_api_gateway_rest_api" "apis" {
  for_each = local.api_prefixes

  name        = "${var.project_name}-${var.environment}-${each.key}"
  description = "API Gateway for ${each.key} - ${var.project_name} ${var.environment}"

  endpoint_configuration {
    types = [var.api_endpoint_type]
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project_name}-${var.environment}-${each.key}"
    ApiPrefix = each.key
  })
}

################################################################################
# API Gateway Resources and Methods (Proxy Integration)
################################################################################

# Proxy resource for catch-all routing
resource "aws_api_gateway_resource" "proxy" {
  for_each = local.api_prefixes

  rest_api_id = aws_api_gateway_rest_api.apis[each.key].id
  parent_id   = aws_api_gateway_rest_api.apis[each.key].root_resource_id
  path_part   = "{proxy+}"
}

# ANY method on proxy resource
resource "aws_api_gateway_method" "proxy_any" {
  for_each = local.api_prefixes

  rest_api_id   = aws_api_gateway_rest_api.apis[each.key].id
  resource_id   = aws_api_gateway_resource.proxy[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

# Lambda integration for proxy
resource "aws_api_gateway_integration" "proxy" {
  for_each = local.api_prefixes

  rest_api_id             = aws_api_gateway_rest_api.apis[each.key].id
  resource_id             = aws_api_gateway_resource.proxy[each.key].id
  http_method             = aws_api_gateway_method.proxy_any[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambdas[local.api_to_lambda[each.key]].function_invoke_arn
}

# ANY method on root
resource "aws_api_gateway_method" "root" {
  for_each = local.api_prefixes

  rest_api_id   = aws_api_gateway_rest_api.apis[each.key].id
  resource_id   = aws_api_gateway_rest_api.apis[each.key].root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# Lambda integration for root
resource "aws_api_gateway_integration" "root" {
  for_each = local.api_prefixes

  rest_api_id             = aws_api_gateway_rest_api.apis[each.key].id
  resource_id             = aws_api_gateway_rest_api.apis[each.key].root_resource_id
  http_method             = aws_api_gateway_method.root[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambdas[local.api_to_lambda[each.key]].function_invoke_arn
}

################################################################################
# CORS OPTIONS Methods
################################################################################

resource "aws_api_gateway_method" "options" {
  for_each = local.api_prefixes

  rest_api_id   = aws_api_gateway_rest_api.apis[each.key].id
  resource_id   = aws_api_gateway_resource.proxy[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each = local.api_prefixes

  rest_api_id = aws_api_gateway_rest_api.apis[each.key].id
  resource_id = aws_api_gateway_resource.proxy[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = local.api_prefixes

  rest_api_id = aws_api_gateway_rest_api.apis[each.key].id
  resource_id = aws_api_gateway_resource.proxy[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = local.api_prefixes

  rest_api_id = aws_api_gateway_rest_api.apis[each.key].id
  resource_id = aws_api_gateway_resource.proxy[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = aws_api_gateway_method_response.options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

################################################################################
# API Gateway Account Settings (for CloudWatch logging)
# This is a regional setting - only one needed per AWS account/region
################################################################################

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [aws_iam_role_policy.api_gateway_cloudwatch]
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-${var.environment}-apigw-cloudwatch"

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
    Name = "${var.project_name}-${var.environment}-apigw-cloudwatch-role"
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name = "${var.project_name}-${var.environment}-apigw-cloudwatch-policy"
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
# API Gateway Stages
################################################################################

resource "aws_api_gateway_stage" "apis" {
  for_each = local.api_prefixes

  deployment_id = aws_api_gateway_deployment.apis[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.apis[each.key].id
  stage_name    = var.api_stage_name

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway[each.key].arn
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
      errorMessage       = "$context.error.message"
      integrationLatency = "$context.integrationLatency"
    })
  }

  tags = merge(local.common_tags, {
    Name      = "${var.project_name}-${var.environment}-${each.key}-${var.api_stage_name}"
    ApiPrefix = each.key
  })

  depends_on = [aws_api_gateway_account.this]
}

################################################################################
# API Gateway CloudWatch Log Groups
################################################################################

resource "aws_cloudwatch_log_group" "api_gateway" {
  for_each = local.api_prefixes

  name              = "/aws/apigateway/${var.project_name}-${var.environment}-${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name      = "${var.project_name}-${var.environment}-${each.key}-logs"
    ApiPrefix = each.key
  })
}

################################################################################
# API Gateway Deployments
################################################################################

resource "aws_api_gateway_deployment" "apis" {
  for_each = local.api_prefixes

  rest_api_id = aws_api_gateway_rest_api.apis[each.key].id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy[each.key].id,
      aws_api_gateway_method.proxy_any[each.key].id,
      aws_api_gateway_method.root[each.key].id,
      aws_api_gateway_integration.proxy[each.key].id,
      aws_api_gateway_integration.root[each.key].id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.proxy,
    aws_api_gateway_integration.root,
    aws_api_gateway_integration.options,
  ]
}

################################################################################
# WAF Web ACL Association (one per stage)
################################################################################

resource "aws_wafv2_web_acl_association" "apis" {
  for_each = var.waf_regional_arn != null ? local.api_prefixes : toset([])

  # Stage ARN format for REST API: arn:aws:apigateway:{region}::/restapis/{id}/stages/{stage}
  resource_arn = "arn:aws:apigateway:${var.aws_region}::/restapis/${aws_api_gateway_rest_api.apis[each.key].id}/stages/${aws_api_gateway_stage.apis[each.key].stage_name}"
  web_acl_arn  = var.waf_regional_arn

  depends_on = [aws_api_gateway_stage.apis]
}

################################################################################
# API Gateway Method Settings (Throttling)
################################################################################

resource "aws_api_gateway_method_settings" "apis" {
  for_each = local.api_prefixes

  rest_api_id = aws_api_gateway_rest_api.apis[each.key].id
  stage_name  = aws_api_gateway_stage.apis[each.key].stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = var.api_throttling_burst_limit
    throttling_rate_limit  = var.api_throttling_rate_limit
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false # Don't log request/response data
  }
}

################################################################################
# API Gateway Custom Domain (api.{env}.hometest.service.nhs.uk)
# Note: *.hometest.service.nhs.uk does NOT cover api.dev.hometest.service.nhs.uk
# (AWS wildcards are single-level), so a dedicated cert is created here.
################################################################################

resource "aws_acm_certificate" "api_domain" {
  count = var.api_custom_domain_name != null ? 1 : 0

  domain_name       = var.api_custom_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-domain-cert"
  })
}

resource "aws_route53_record" "api_domain_cert_validation" {
  for_each = var.api_custom_domain_name != null ? {
    for dvo in aws_acm_certificate.api_domain[0].domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "api_domain" {
  count = var.api_custom_domain_name != null ? 1 : 0

  certificate_arn         = aws_acm_certificate.api_domain[0].arn
  validation_record_fqdns = [for record in aws_route53_record.api_domain_cert_validation : record.fqdn]
}

# Regional custom domain — one domain, multiple base path mappings (one per API prefix)
resource "aws_api_gateway_domain_name" "api" {
  count = var.api_custom_domain_name != null ? 1 : 0

  domain_name              = var.api_custom_domain_name
  regional_certificate_arn = aws_acm_certificate_validation.api_domain[0].certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-custom-domain"
  })

  depends_on = [aws_acm_certificate_validation.api_domain]
}

# Base path mapping: https://api.dev.hometest.service.nhs.uk/{prefix}/... → REST API {prefix} stage v1
resource "aws_api_gateway_base_path_mapping" "api" {
  for_each = var.api_custom_domain_name != null ? local.api_prefixes : toset([])

  api_id      = aws_api_gateway_rest_api.apis[each.key].id
  stage_name  = aws_api_gateway_stage.apis[each.key].stage_name
  domain_name = aws_api_gateway_domain_name.api[0].domain_name
  base_path   = each.key

  depends_on = [aws_api_gateway_domain_name.api]
}

# Route53 alias record: api.dev.hometest.service.nhs.uk → API Gateway regional endpoint
resource "aws_route53_record" "api_domain" {
  count = var.api_custom_domain_name != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.api_custom_domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.api[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.api[0].regional_zone_id
    evaluate_target_health = false
  }
}
