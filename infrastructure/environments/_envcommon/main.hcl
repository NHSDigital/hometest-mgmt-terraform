# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for the main web application Lambda.
# These common variables for each environment are defined here and merged into
# the environment configuration via an include block.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract out common variables for reuse
  env            = local.environment_vars.locals.environment
  account_name   = local.account_vars.locals.account_name
  aws_account_id = local.account_vars.locals.aws_account_id

  # Expose the base source URL so different versions of the module can be deployed
  # in different environments
  base_source_url = "../../../..//src/main"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the
# parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # AWS Configuration
  aws_account_id = local.aws_account_id
  account_name   = local.account_name
  environment    = local.env

  # Application Configuration
  app_name = "webapp"
  app_port = 8080

  # Lambda Configuration
  lambda_memory_size   = 512
  lambda_timeout       = 30
  lambda_architecture  = "arm64"

  # API Gateway Configuration
  enable_api_gateway             = true
  enable_api_gateway_access_logs = true

  # Observability
  enable_xray_tracing      = true
  log_retention_days       = 30
  enable_cloudwatch_alarms = true
}
