################################################################################
# API Gateway 1 - First API
################################################################################

module "api_gateway_1" {
  source = "../../modules/api-gateway"

  project_name    = var.project_name
  environment     = var.environment
  api_name_suffix = "api1"

  stage_name           = var.api_stage_name
  endpoint_type        = var.api_endpoint_type
  xray_tracing_enabled = true
  log_retention_days   = var.log_retention_days

  throttling_burst_limit = var.api_throttling_burst_limit
  throttling_rate_limit  = var.api_throttling_rate_limit

  waf_web_acl_arn        = var.waf_regional_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  custom_domain_name  = var.api1_custom_domain_name
  acm_certificate_arn = var.api_acm_certificate_arn

  tags = var.tags
}

################################################################################
# API Gateway 2 - Second API
################################################################################

module "api_gateway_2" {
  source = "../../modules/api-gateway"

  project_name    = var.project_name
  environment     = var.environment
  api_name_suffix = "api2"

  stage_name           = var.api_stage_name
  endpoint_type        = var.api_endpoint_type
  xray_tracing_enabled = true
  log_retention_days   = var.log_retention_days

  throttling_burst_limit = var.api_throttling_burst_limit
  throttling_rate_limit  = var.api_throttling_rate_limit

  waf_web_acl_arn        = var.waf_regional_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  custom_domain_name  = var.api2_custom_domain_name
  acm_certificate_arn = var.api_acm_certificate_arn

  tags = var.tags
}

################################################################################
# API Gateway 1 - Lambda Integration
################################################################################

resource "aws_api_gateway_resource" "api1_proxy" {
  rest_api_id = module.api_gateway_1.rest_api_id
  parent_id   = module.api_gateway_1.rest_api_root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "api1_proxy_any" {
  rest_api_id   = module.api_gateway_1.rest_api_id
  resource_id   = aws_api_gateway_resource.api1_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api1_proxy" {
  rest_api_id             = module.api_gateway_1.rest_api_id
  resource_id             = aws_api_gateway_resource.api1_proxy.id
  http_method             = aws_api_gateway_method.api1_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.api1_lambda.function_invoke_arn
}

resource "aws_api_gateway_method" "api1_root" {
  rest_api_id   = module.api_gateway_1.rest_api_id
  resource_id   = module.api_gateway_1.rest_api_root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api1_root" {
  rest_api_id             = module.api_gateway_1.rest_api_id
  resource_id             = module.api_gateway_1.rest_api_root_resource_id
  http_method             = aws_api_gateway_method.api1_root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.api1_lambda.function_invoke_arn
}

# CORS OPTIONS for API 1
resource "aws_api_gateway_method" "api1_options" {
  rest_api_id   = module.api_gateway_1.rest_api_id
  resource_id   = aws_api_gateway_resource.api1_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api1_options" {
  rest_api_id = module.api_gateway_1.rest_api_id
  resource_id = aws_api_gateway_resource.api1_proxy.id
  http_method = aws_api_gateway_method.api1_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "api1_options" {
  rest_api_id = module.api_gateway_1.rest_api_id
  resource_id = aws_api_gateway_resource.api1_proxy.id
  http_method = aws_api_gateway_method.api1_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "api1_options" {
  rest_api_id = module.api_gateway_1.rest_api_id
  resource_id = aws_api_gateway_resource.api1_proxy.id
  http_method = aws_api_gateway_method.api1_options.http_method
  status_code = aws_api_gateway_method_response.api1_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

################################################################################
# API Gateway 2 - Lambda Integration
################################################################################

resource "aws_api_gateway_resource" "api2_proxy" {
  rest_api_id = module.api_gateway_2.rest_api_id
  parent_id   = module.api_gateway_2.rest_api_root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "api2_proxy_any" {
  rest_api_id   = module.api_gateway_2.rest_api_id
  resource_id   = aws_api_gateway_resource.api2_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api2_proxy" {
  rest_api_id             = module.api_gateway_2.rest_api_id
  resource_id             = aws_api_gateway_resource.api2_proxy.id
  http_method             = aws_api_gateway_method.api2_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.api2_lambda.function_invoke_arn
}

resource "aws_api_gateway_method" "api2_root" {
  rest_api_id   = module.api_gateway_2.rest_api_id
  resource_id   = module.api_gateway_2.rest_api_root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api2_root" {
  rest_api_id             = module.api_gateway_2.rest_api_id
  resource_id             = module.api_gateway_2.rest_api_root_resource_id
  http_method             = aws_api_gateway_method.api2_root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.api2_lambda.function_invoke_arn
}

# CORS OPTIONS for API 2
resource "aws_api_gateway_method" "api2_options" {
  rest_api_id   = module.api_gateway_2.rest_api_id
  resource_id   = aws_api_gateway_resource.api2_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api2_options" {
  rest_api_id = module.api_gateway_2.rest_api_id
  resource_id = aws_api_gateway_resource.api2_proxy.id
  http_method = aws_api_gateway_method.api2_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "api2_options" {
  rest_api_id = module.api_gateway_2.rest_api_id
  resource_id = aws_api_gateway_resource.api2_proxy.id
  http_method = aws_api_gateway_method.api2_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "api2_options" {
  rest_api_id = module.api_gateway_2.rest_api_id
  resource_id = aws_api_gateway_resource.api2_proxy.id
  http_method = aws_api_gateway_method.api2_options.http_method
  status_code = aws_api_gateway_method_response.api2_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

################################################################################
# API Gateway Deployments
################################################################################

resource "aws_api_gateway_deployment" "api1" {
  rest_api_id = module.api_gateway_1.rest_api_id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api1_proxy.id,
      aws_api_gateway_method.api1_proxy_any.id,
      aws_api_gateway_method.api1_root.id,
      aws_api_gateway_integration.api1_proxy.id,
      aws_api_gateway_integration.api1_root.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.api1_proxy,
    aws_api_gateway_integration.api1_root,
    aws_api_gateway_integration.api1_options,
  ]
}

resource "aws_api_gateway_deployment" "api2" {
  rest_api_id = module.api_gateway_2.rest_api_id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api2_proxy.id,
      aws_api_gateway_method.api2_proxy_any.id,
      aws_api_gateway_method.api2_root.id,
      aws_api_gateway_integration.api2_proxy.id,
      aws_api_gateway_integration.api2_root.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.api2_proxy,
    aws_api_gateway_integration.api2_root,
    aws_api_gateway_integration.api2_options,
  ]
}
