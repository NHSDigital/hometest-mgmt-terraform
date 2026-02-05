################################################################################
# HomeTest Service Application Infrastructure
# Main Terraform configuration for Lambda + CloudFront SPA deployment
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

################################################################################
# Deployment Artifacts S3 Bucket
################################################################################

module "deployment_artifacts" {
  source = "../../../modules/deployment-artifacts"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id

  kms_key_arn             = var.kms_key_arn
  artifact_retention_days = var.artifact_retention_days

  tags = var.tags
}

################################################################################
# Lambda Execution IAM Role
################################################################################

module "lambda_iam" {
  source = "../../../modules/lambda-iam"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.name

  enable_xray      = true
  enable_vpc_access = var.enable_vpc_access
  vpc_id           = var.vpc_id

  secrets_arns       = var.lambda_secrets_arns
  ssm_parameter_arns = var.lambda_ssm_parameter_arns
  kms_key_arns       = var.kms_key_arn != null ? [var.kms_key_arn] : []
  s3_bucket_arns     = var.lambda_s3_bucket_arns
  dynamodb_table_arns = var.lambda_dynamodb_table_arns
  sqs_queue_arns     = var.lambda_sqs_queue_arns

  tags = var.tags
}

################################################################################
# API Gateway
################################################################################

module "api_gateway" {
  source = "../../../modules/api-gateway"

  project_name = var.project_name
  environment  = var.environment

  stage_name           = var.api_stage_name
  endpoint_type        = var.api_endpoint_type
  xray_tracing_enabled = true
  log_retention_days   = var.log_retention_days

  throttling_burst_limit = var.api_throttling_burst_limit
  throttling_rate_limit  = var.api_throttling_rate_limit

  waf_web_acl_arn        = var.waf_web_acl_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  custom_domain_name  = var.api_custom_domain_name
  acm_certificate_arn = var.api_acm_certificate_arn

  tags = var.tags
}

################################################################################
# Lambda Functions
################################################################################

module "eligibility_test_info_lambda" {
  source = "../../../modules/lambda"

  project_name    = var.project_name
  function_name   = "eligibility-test-info"
  environment     = var.environment
  lambda_role_arn = module.lambda_iam.role_arn

  s3_bucket        = module.deployment_artifacts.bucket_id
  s3_key           = "lambdas/eligibility-test-info-lambda.zip"
  source_code_hash = var.eligibility_test_info_hash

  description  = "Eligibility test information Lambda"
  handler      = "index.handler"
  runtime      = var.lambda_runtime
  timeout      = var.lambda_timeout
  memory_size  = var.lambda_memory_size

  tracing_mode       = "Active"
  log_retention_days = var.log_retention_days

  vpc_subnet_ids         = var.lambda_vpc_subnet_ids
  vpc_security_group_ids = var.lambda_security_group_ids

  lambda_kms_key_arn     = var.kms_key_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  environment_variables = merge(
    {
      NODE_OPTIONS = "--enable-source-maps"
      ENVIRONMENT  = var.environment
    },
    var.eligibility_test_info_env_vars
  )

  tags = var.tags
}

module "order_router_lambda" {
  source = "../../../modules/lambda"

  project_name    = var.project_name
  function_name   = "order-router"
  environment     = var.environment
  lambda_role_arn = module.lambda_iam.role_arn

  s3_bucket        = module.deployment_artifacts.bucket_id
  s3_key           = "lambdas/order-router-lambda.zip"
  source_code_hash = var.order_router_hash

  description  = "Order router Lambda"
  handler      = "index.handler"
  runtime      = var.lambda_runtime
  timeout      = var.lambda_timeout
  memory_size  = var.lambda_memory_size

  tracing_mode       = "Active"
  log_retention_days = var.log_retention_days

  vpc_subnet_ids         = var.lambda_vpc_subnet_ids
  vpc_security_group_ids = var.lambda_security_group_ids

  lambda_kms_key_arn     = var.kms_key_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  environment_variables = merge(
    {
      NODE_OPTIONS = "--enable-source-maps"
      ENVIRONMENT  = var.environment
    },
    var.order_router_env_vars
  )

  tags = var.tags
}

module "hello_world_lambda" {
  source = "../../../modules/lambda"

  project_name    = var.project_name
  function_name   = "hello-world"
  environment     = var.environment
  lambda_role_arn = module.lambda_iam.role_arn

  s3_bucket        = module.deployment_artifacts.bucket_id
  s3_key           = "lambdas/hello-world-lambda.zip"
  source_code_hash = var.hello_world_hash

  description  = "Hello World Lambda"
  handler      = "index.handler"
  runtime      = var.lambda_runtime
  timeout      = 10
  memory_size  = 128

  tracing_mode       = "Active"
  log_retention_days = var.log_retention_days

  lambda_kms_key_arn     = var.kms_key_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  environment_variables = {
    NODE_OPTIONS = "--enable-source-maps"
    ENVIRONMENT  = var.environment
  }

  tags = var.tags
}

################################################################################
# API Gateway Lambda Integrations
################################################################################

# Create API resources and methods for each Lambda
resource "aws_api_gateway_resource" "test_order" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = module.api_gateway.rest_api_root_resource_id
  path_part   = "test-order"
}

resource "aws_api_gateway_resource" "test_order_info" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = aws_api_gateway_resource.test_order.id
  path_part   = "info"
}

resource "aws_api_gateway_resource" "test_order_order" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = aws_api_gateway_resource.test_order.id
  path_part   = "order"
}

resource "aws_api_gateway_resource" "hello_world" {
  rest_api_id = module.api_gateway.rest_api_id
  parent_id   = module.api_gateway.rest_api_root_resource_id
  path_part   = "hello-world"
}

# Methods and integrations
resource "aws_api_gateway_method" "eligibility_test_info" {
  rest_api_id   = module.api_gateway.rest_api_id
  resource_id   = aws_api_gateway_resource.test_order_info.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "eligibility_test_info" {
  rest_api_id             = module.api_gateway.rest_api_id
  resource_id             = aws_api_gateway_resource.test_order_info.id
  http_method             = aws_api_gateway_method.eligibility_test_info.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.eligibility_test_info_lambda.function_invoke_arn
}

resource "aws_lambda_permission" "eligibility_test_info" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.eligibility_test_info_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.rest_api_execution_arn}/*/*"
}

resource "aws_api_gateway_method" "order_router" {
  rest_api_id   = module.api_gateway.rest_api_id
  resource_id   = aws_api_gateway_resource.test_order_order.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "order_router" {
  rest_api_id             = module.api_gateway.rest_api_id
  resource_id             = aws_api_gateway_resource.test_order_order.id
  http_method             = aws_api_gateway_method.order_router.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.order_router_lambda.function_invoke_arn
}

resource "aws_lambda_permission" "order_router" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.order_router_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.rest_api_execution_arn}/*/*"
}

resource "aws_api_gateway_method" "hello_world" {
  rest_api_id   = module.api_gateway.rest_api_id
  resource_id   = aws_api_gateway_resource.hello_world.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello_world" {
  rest_api_id             = module.api_gateway.rest_api_id
  resource_id             = aws_api_gateway_resource.hello_world.id
  http_method             = aws_api_gateway_method.hello_world.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.hello_world_lambda.function_invoke_arn
}

resource "aws_lambda_permission" "hello_world" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.hello_world_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.rest_api_execution_arn}/*/*"
}

################################################################################
# CloudFront SPA Distribution
################################################################################

module "cloudfront_spa" {
  source = "../../../modules/cloudfront-spa"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id

  enable_spa_routing = true
  price_class        = var.cloudfront_price_class

  s3_kms_key_arn                        = var.kms_key_arn
  s3_noncurrent_version_expiration_days = 30

  # API Gateway integration
  api_gateway_domain_name = replace(module.api_gateway.invoke_url, "https://", "")
  api_gateway_origin_path = "/${var.api_stage_name}"

  # Custom domain (optional)
  custom_domain_names = var.spa_custom_domain_names
  acm_certificate_arn = var.spa_acm_certificate_arn
  route53_zone_id     = var.route53_zone_id

  # Security
  waf_web_acl_arn         = var.waf_web_acl_arn
  content_security_policy = var.content_security_policy
  permissions_policy      = var.permissions_policy

  # Geo restriction
  geo_restriction_type      = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations

  # Logging
  enable_access_logging      = var.enable_cloudfront_logging
  logging_bucket_domain_name = var.cloudfront_logging_bucket_domain_name

  tags = var.tags
}

################################################################################
# Developer IAM Role
################################################################################

module "developer_iam" {
  source = "../../../modules/developer-iam"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.name

  developer_account_arns = var.developer_account_arns

  require_mfa         = var.developer_require_mfa
  require_external_id = var.developer_require_external_id
  external_id         = var.developer_external_id
  allowed_ip_ranges   = var.developer_allowed_ip_ranges

  cloudfront_distribution_arn = module.cloudfront_spa.distribution_arn
  kms_key_arns                = var.kms_key_arn != null ? [var.kms_key_arn] : []

  tags = var.tags
}
