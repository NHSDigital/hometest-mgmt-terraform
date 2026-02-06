# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev3 ENVIRONMENT
# Deployment with: cd dev3/hometest-app && terragrunt apply
# Dependencies: network (VPC/Route53), shared_services (WAF/ACM/KMS)
#
# This environment uses the default hometest-service repo (lambdas and Next.js UI).
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

dependency "rds_postgres" {
  config_path = "../../core/rds-postgres"

  mock_outputs = {
    db_instance_endpoint               = "mock-db.cluster-abc123.eu-west-2.rds.amazonaws.com:5432"
    db_instance_address                = "mock-db.cluster-abc123.eu-west-2.rds.amazonaws.com"
    db_instance_port                   = 5432
    db_instance_name                   = "hometest_poc"
    db_instance_username               = "postgres"
    db_instance_master_user_secret_arn = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:rds-mock-secret"
    connection_string                  = "postgresql://postgres@mock-db.cluster-abc123.eu-west-2.rds.amazonaws.com:5432/hometest_poc"
    security_group_id                  = "sg-mock-rds"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS - Configured for hometest-service lambdas
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

  # Lambda Configuration
  enable_vpc_access  = true
  enable_sqs_access  = true # Required for order-router-lambda SQS trigger
  lambda_runtime     = include.envcommon.locals.lambda_runtime
  lambda_timeout     = include.envcommon.locals.lambda_timeout
  lambda_memory_size = include.envcommon.locals.lambda_memory_size
  log_retention_days = include.envcommon.locals.log_retention_days

  # IAM Permissions - Grant Lambda access to RDS secrets
  lambda_secrets_arns = [
    dependency.rds_postgres.outputs.db_instance_master_user_secret_arn
  ]

  # Lambda code deployment
  use_placeholder_lambda = false

  # Base path for hometest-service lambdas (uses default from envcommon)
  lambdas_base_path = include.envcommon.locals.lambdas_base_path

  # =============================================================================
  # LAMBDA DEFINITIONS - hometest-service lambdas
  # Based on hometest-service/local-environment/infra/main.tf configuration
  # =============================================================================
  lambdas = {
    # Hello World Lambda - simple health check
    # API path: /hello-world
    "hello-world-lambda" = {
      description     = "Hello World Lambda - Health Check"
      api_path_prefix = "hello-world"
      handler         = "index.handler"
      timeout         = 30
      memory_size     = 256
      environment = {
        NODE_OPTIONS = "--enable-source-maps"
        ENVIRONMENT  = include.envcommon.locals.environment
      }
    }

    # Eligibility Test Info Lambda
    # API path: /test-order/info (GET)
    "eligibility-test-info-lambda" = {
      description     = "Eligibility Test Info Service - Returns test eligibility information"
      api_path_prefix = "test-order" # Will handle /test-order/* routes
      handler         = "index.handler"
      timeout         = 30
      memory_size     = 256
      environment = {
        NODE_OPTIONS  = "--enable-source-maps"
        ENVIRONMENT   = include.envcommon.locals.environment
        DATABASE_URL  = "${dependency.rds_postgres.outputs.connection_string}?currentSchema=hometest"
        DB_SECRET_ARN = dependency.rds_postgres.outputs.db_instance_master_user_secret_arn
      }
    }

    # Order Router Lambda - Handles order submissions to supplier
    # API path: /test-order/order (POST) - but configured as SQS processor for async processing
    "order-router-lambda" = {
      description = "Order Router Service - Routes orders to supplier via SQS processing"
      sqs_trigger = true # Triggered by SQS queue for async order processing
      handler     = "index.handler"
      timeout     = 60 # Longer timeout for external API calls
      memory_size = 512
      environment = {
        NODE_OPTIONS                = "--enable-source-maps"
        ENVIRONMENT                 = include.envcommon.locals.environment
        SUPPLIER_BASE_URL           = "https://supplier-api.example.com"
        SUPPLIER_OAUTH_TOKEN_PATH   = "/oauth/token"
        SUPPLIER_CLIENT_ID          = "supplier-client"
        SUPPLIER_CLIENT_SECRET_NAME = "${include.envcommon.locals.project_name}/${include.envcommon.locals.environment}/supplier-oauth-client-secret"
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
