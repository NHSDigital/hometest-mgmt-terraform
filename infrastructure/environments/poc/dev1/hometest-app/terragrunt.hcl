# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev1 ENVIRONMENT
# Deployment with: cd dev1/hometest-app && terragrunt apply
# Dependencies: network (VPC/Route53), shared_services (WAF/ACM/KMS)
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infrastructure//src/hometest-app"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES
# ---------------------------------------------------------------------------------------------------------------------

dependency "network" {
  config_path = "../../core/network"

  # Mock outputs for plan when network hasn't been deployed yet
  mock_outputs = {
    route53_zone_id          = "Z0123456789ABCDEFGHIJ"
    vpc_id                   = "vpc-mock12345"
    private_subnet_ids       = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
    lambda_security_group_id = "sg-mock12345"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "shared_services" {
  config_path = "../../core/shared_services"

  # Mock outputs for plan when shared_services hasn't been deployed yet
  mock_outputs = {
    kms_key_arn                     = "arn:aws:kms:eu-west-2:123456789012:key/mock-key-id"
    waf_regional_arn                = "arn:aws:wafv2:eu-west-2:123456789012:regional/webacl/mock/mock-id"
    waf_cloudfront_arn              = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/mock/mock-id"
    acm_regional_certificate_arn    = "arn:aws:acm:eu-west-2:123456789012:certificate/mock-cert"
    acm_cloudfront_certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/mock-cert"
    deployment_artifacts_bucket_id  = "mock-deployment-bucket"
    deployment_artifacts_bucket_arn = "arn:aws:s3:::mock-deployment-bucket"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# LOCALS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  global_vars  = read_terragrunt_config(find_in_parent_folders("_envcommon/all.hcl"))

  project_name = local.global_vars.locals.project_name
  account_id   = local.account_vars.locals.aws_account_id
  environment  = "dev1"

  # Domain configuration
  base_domain = "hometest.service.nhs.uk"
  env_domain  = "${local.environment}.${local.base_domain}"
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  project_name = local.project_name
  environment  = local.environment

  # Dependencies from network
  vpc_id                    = dependency.network.outputs.vpc_id
  lambda_subnet_ids         = dependency.network.outputs.private_subnet_ids
  lambda_security_group_ids = [dependency.network.outputs.lambda_security_group_id]
  route53_zone_id           = dependency.network.outputs.route53_zone_id

  # Dependencies from shared_services
  kms_key_arn           = dependency.shared_services.outputs.kms_key_arn
  waf_cloudfront_arn    = dependency.shared_services.outputs.waf_cloudfront_arn
  deployment_bucket_id  = dependency.shared_services.outputs.deployment_artifacts_bucket_id
  deployment_bucket_arn = dependency.shared_services.outputs.deployment_artifacts_bucket_arn

  # Lambda Configuration
  enable_vpc_access  = true
  lambda_runtime     = "nodejs20.x"
  lambda_timeout     = 30
  lambda_memory_size = 256
  log_retention_days = 14

  # Use placeholder Lambda code for initial deployment
  use_placeholder_lambda = true

  # API Gateway Configuration
  api_stage_name             = "v1"
  api_endpoint_type          = "REGIONAL"
  api_throttling_burst_limit = 1000
  api_throttling_rate_limit  = 2000

  # Single custom domain for everything
  # - dev1.hometest.service.nhs.uk -> SPA
  # - dev1.hometest.service.nhs.uk/api1/* -> API 1
  # - dev1.hometest.service.nhs.uk/api2/* -> API 2
  custom_domain_name  = local.env_domain
  acm_certificate_arn = dependency.shared_services.outputs.acm_cloudfront_certificate_arn

  # CloudFront Configuration
  cloudfront_price_class = "PriceClass_100"

  # Lambda environment variables
  api1_env_vars = {
    API_NAME    = "api1-users"
    ENVIRONMENT = local.environment
  }

  api2_env_vars = {
    API_NAME    = "api2-orders"
    ENVIRONMENT = local.environment
  }
}
