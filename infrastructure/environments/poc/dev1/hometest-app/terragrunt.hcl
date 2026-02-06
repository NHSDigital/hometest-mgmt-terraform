# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev1 ENVIRONMENT
# Deployment with: cd dev1/hometest-app && terragrunt apply
# Dependencies: network (VPC/Route53), shared_services (WAF/ACM/KMS)
#
# This configuration inherits terraform source and hooks from _envcommon/hometest-app.hcl
# Dependencies and inputs are defined here as they reference dependency outputs.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/hometest-app.hcl"
  expose         = true
  merge_strategy = "deep"
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
    api_config_secret_arn           = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:mock-secret"
    api_config_secret_name          = "mock/secret/name"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS - Uses locals from envcommon and dependencies defined above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  project_name = include.envcommon.locals.project_name
  environment  = include.envcommon.locals.environment

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

  # Lambda Configuration - Use defaults from envcommon
  enable_vpc_access  = true
  lambda_runtime     = include.envcommon.locals.lambda_runtime
  lambda_timeout     = include.envcommon.locals.lambda_timeout
  lambda_memory_size = include.envcommon.locals.lambda_memory_size
  log_retention_days = include.envcommon.locals.log_retention_days

  # Lambda code deployment - hooks build and upload automatically
  use_placeholder_lambda = false

  # Base path where lambda zip files are located after build
  lambdas_base_path = "${get_repo_root()}/examples/lambdas"

  # =============================================================================
  # LAMBDA DEFINITIONS MAP
  # =============================================================================
  lambdas = {
    # User Service API - accessible at /api1/*
    "api1-handler" = {
      description     = "User Service API Handler with Secrets Manager"
      api_path_prefix = "api1"
      timeout         = 30
      memory_size     = 256
      secrets_arn     = dependency.shared_services.outputs.api_config_secret_arn
      environment = {
        API_NAME    = "users"
        API_VERSION = "v1"
        SECRET_NAME = dependency.shared_services.outputs.api_config_secret_name
      }
    }

    # Order Service API - accessible at /api2/*
    "api2-handler" = {
      description     = "Order Service API Handler with SQS integration"
      api_path_prefix = "api2"
      timeout         = 30
      memory_size     = 256
      environment = {
        API_NAME      = "orders"
        API_VERSION   = "v1"
        SQS_QUEUE_URL = "https://sqs.eu-west-2.amazonaws.com/${include.envcommon.locals.account_id}/${include.envcommon.locals.project_name}-${include.envcommon.locals.environment}-events"
      }
    }

    # SQS Message Processor - triggered by SQS events (no API Gateway)
    "sqs-processor" = {
      description = "SQS Event Processor - processes messages from queue"
      sqs_trigger = true
      timeout     = 60
      memory_size = 256
      environment = {
        PROCESSOR_NAME = "event-processor"
      }
    }
  }

  # API Gateway Configuration
  api_stage_name             = include.envcommon.locals.api_stage_name
  api_endpoint_type          = include.envcommon.locals.api_endpoint_type
  api_throttling_burst_limit = include.envcommon.locals.api_throttling_burst_limit
  api_throttling_rate_limit  = include.envcommon.locals.api_throttling_rate_limit

  # Domain configuration
  custom_domain_name  = include.envcommon.locals.env_domain
  acm_certificate_arn = dependency.shared_services.outputs.acm_cloudfront_certificate_arn

  # CloudFront Configuration
  cloudfront_price_class = include.envcommon.locals.cloudfront_price_class
}
