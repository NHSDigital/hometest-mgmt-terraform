################################################################################
# Lambda Functions - Dynamic Creation from Map
################################################################################

locals {
  # Merge legacy lambda definitions with new map-based approach
  # This supports both old (api1_env_vars) and new (lambdas map) configurations
  legacy_lambdas = length(var.lambdas) == 0 ? {
    "api1-handler" = {
      description                    = "API 1 Handler Lambda"
      handler                        = "index.handler"
      runtime                        = null
      timeout                        = null
      memory_size                    = null
      zip_path                       = null
      s3_key                         = "lambdas/${var.environment}/api1-handler.zip"
      source_hash                    = var.api1_lambda_hash
      environment                    = var.api1_env_vars
      api_path_prefix                = "api1"
      reserved_concurrent_executions = -1
      sqs_trigger                    = false
      secrets_arn                    = null
    }
    "api2-handler" = {
      description                    = "API 2 Handler Lambda"
      handler                        = "index.handler"
      runtime                        = null
      timeout                        = null
      memory_size                    = null
      zip_path                       = null
      s3_key                         = "lambdas/${var.environment}/api2-handler.zip"
      source_hash                    = var.api2_lambda_hash
      environment                    = var.api2_env_vars
      api_path_prefix                = "api2"
      reserved_concurrent_executions = -1
      sqs_trigger                    = false
      secrets_arn                    = null
    }
  } : {}

  # Final lambda configurations - prefer new map over legacy
  all_lambdas = length(var.lambdas) > 0 ? var.lambdas : local.legacy_lambdas

  # Extract lambdas that have API Gateway integration
  api_lambdas = { for k, v in local.all_lambdas : k => v if v.api_path_prefix != null }

  # Compute zip paths for each lambda
  lambda_zip_paths = {
    for k, v in local.all_lambdas : k => coalesce(
      v.zip_path,
      "${var.lambdas_base_path}/${k}/${k}.zip"
    )
  }
}

################################################################################
# Lambda Functions
################################################################################

module "lambdas" {
  source   = "../../modules/lambda"
  for_each = local.all_lambdas

  project_name          = var.project_name
  aws_account_shortname = var.aws_account_shortname
  function_name         = each.key
  environment           = var.environment
  lambda_role_arn       = module.lambda_iam.role_arn

  # Deployment: local zip file (Terraform uploads) or placeholder
  use_placeholder = var.use_placeholder_lambda

  # When not using placeholder, use local zip file - Terraform uploads it directly
  filename = var.use_placeholder_lambda ? null : local.lambda_zip_paths[each.key]
  source_code_hash = var.use_placeholder_lambda ? null : (
    each.value.source_hash != null ? each.value.source_hash : (
      fileexists(local.lambda_zip_paths[each.key]) ? filebase64sha256(local.lambda_zip_paths[each.key]) : null
    )
  )

  description = each.value.description
  handler     = each.value.handler
  runtime     = coalesce(each.value.runtime, var.lambda_runtime)
  timeout     = coalesce(each.value.timeout, var.lambda_timeout)
  memory_size = coalesce(each.value.memory_size, var.lambda_memory_size)

  tracing_mode       = "Active"
  log_retention_days = var.log_retention_days

  vpc_subnet_ids         = var.lambda_subnet_ids
  vpc_security_group_ids = var.lambda_security_group_ids

  lambda_kms_key_arn     = var.kms_key_arn
  cloudwatch_kms_key_arn = var.kms_key_arn

  alarm_actions = var.sns_alerts_topic_arn != null ? [var.sns_alerts_topic_arn] : []

  reserved_concurrent_executions = each.value.reserved_concurrent_executions

  environment_variables = merge(
    {
      NODE_OPTIONS = "--enable-source-maps"
      ENVIRONMENT  = var.environment
      LAMBDA_NAME  = each.key
    },
    each.value.environment
  )

  tags = local.common_tags
}

################################################################################
# Lambda Permissions for API Gateway
################################################################################

resource "aws_lambda_permission" "api_gateway" {
  for_each = local.api_lambdas

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = module.lambdas[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.apis[each.value.api_path_prefix].execution_arn}/*/*"
}

################################################################################
# Outputs for Lambda Functions
################################################################################

output "lambda_functions_detail" {
  description = "Map of Lambda function details"
  value = {
    for k, v in module.lambdas : k => {
      function_name = v.function_name
      function_arn  = v.function_arn
      invoke_arn    = v.function_invoke_arn
    }
  }
}
