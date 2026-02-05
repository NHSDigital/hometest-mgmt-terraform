# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Terragrunt configuration for HomeTest App deployment
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infrastructure/src/hometest-app"
}

locals {
  # Load common variables
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  global_vars      = read_terragrunt_config(find_in_parent_folders("_envcommon/all.hcl"))

  project_name = local.global_vars.locals.project_name
  environment  = local.environment_vars.locals.environment
  account_id   = local.account_vars.locals.aws_account_id
}

inputs = {
  project_name = local.project_name
  environment  = local.environment

  # Lambda Configuration
  lambda_runtime     = "nodejs20.x"
  lambda_timeout     = 30
  lambda_memory_size = 256
  log_retention_days = 30

  # API Gateway Configuration
  api_stage_name             = "v1"
  api_endpoint_type          = "REGIONAL"
  api_throttling_burst_limit = 5000
  api_throttling_rate_limit  = 10000

  # CloudFront Configuration
  cloudfront_price_class = "PriceClass_100"

  # Security - restrict to UK only (optional)
  # geo_restriction_type      = "whitelist"
  # geo_restriction_locations = ["GB"]

  # Developer Deployment Role
  # Add developer AWS account ARNs here for cross-account deployment
  developer_account_arns = [
    # "arn:aws:iam::123456789012:user/developer1",
    # "arn:aws:iam::123456789012:role/DeveloperRole",
    "arn:aws:iam::${local.account_id}:root"  # Allow same account for dev environment
  ]
  developer_require_mfa = true

  # Environment-specific Lambda variables
  eligibility_test_info_env_vars = {
    DATABASE_URL = "postgresql://app_user:PLACEHOLDER@rds-endpoint:5432/hometest"
  }

  order_router_env_vars = {
    SUPPLIER_BASE_URL           = "https://supplier-api.example.com"
    SUPPLIER_OAUTH_TOKEN_PATH   = "/oauth/token"
    SUPPLIER_CLIENT_ID          = "supplier-client"
    SUPPLIER_CLIENT_SECRET_NAME = "supplier-oauth-client-secret"
  }
}
