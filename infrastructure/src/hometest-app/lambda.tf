################################################################################
# Lambda Function - API 1 Handler
################################################################################

module "api1_lambda" {
  source = "../../modules/lambda"

  project_name    = var.project_name
  function_name   = "api1-handler"
  environment     = var.environment
  lambda_role_arn = module.lambda_iam.role_arn

  s3_bucket        = var.deployment_bucket_id
  s3_key           = "lambdas/${var.environment}/api1-handler.zip"
  source_code_hash = var.api1_lambda_hash

  description = "API 1 Handler Lambda"
  handler     = "index.handler"
  runtime     = var.lambda_runtime
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  tracing_mode       = "Active"
  log_retention_days = var.log_retention_days

  vpc_subnet_ids         = var.lambda_subnet_ids
  vpc_security_group_ids = var.lambda_security_group_ids

  lambda_kms_key_arn     = var.kms_key_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  environment_variables = merge(
    {
      NODE_OPTIONS = "--enable-source-maps"
      ENVIRONMENT  = var.environment
      API_NAME     = "api1"
    },
    var.api1_env_vars
  )

  tags = var.tags
}

################################################################################
# Lambda Function - API 2 Handler
################################################################################

module "api2_lambda" {
  source = "../../modules/lambda"

  project_name    = var.project_name
  function_name   = "api2-handler"
  environment     = var.environment
  lambda_role_arn = module.lambda_iam.role_arn

  s3_bucket        = var.deployment_bucket_id
  s3_key           = "lambdas/${var.environment}/api2-handler.zip"
  source_code_hash = var.api2_lambda_hash

  description = "API 2 Handler Lambda"
  handler     = "index.handler"
  runtime     = var.lambda_runtime
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  tracing_mode       = "Active"
  log_retention_days = var.log_retention_days

  vpc_subnet_ids         = var.lambda_subnet_ids
  vpc_security_group_ids = var.lambda_security_group_ids

  lambda_kms_key_arn     = var.kms_key_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  environment_variables = merge(
    {
      NODE_OPTIONS = "--enable-source-maps"
      ENVIRONMENT  = var.environment
      API_NAME     = "api2"
    },
    var.api2_env_vars
  )

  tags = var.tags
}

################################################################################
# Lambda Permissions for API Gateway
################################################################################

resource "aws_lambda_permission" "api1" {
  statement_id  = "AllowAPIGateway1Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.api1_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway_1.rest_api_execution_arn}/*/*"
}

resource "aws_lambda_permission" "api2" {
  statement_id  = "AllowAPIGateway2Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.api2_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway_2.rest_api_execution_arn}/*/*"
}
