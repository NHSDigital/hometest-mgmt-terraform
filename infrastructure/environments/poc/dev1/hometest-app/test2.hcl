# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev1 ENVIRONMENT
# Deployment with: cd dev1/hometest-app && terragrunt apply
# Dependencies: network (VPC/Route53), shared_services (WAF/ACM/KMS)
#
# This configuration automatically:
# 1. Builds and packages all Lambda functions
# 2. Uploads them to S3
# 3. Deploys the infrastructure with Terraform
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infrastructure//src/hometest-app"

  # ---------------------------------------------------------------------------
  # BUILD HOOKS
  # These hooks build and package artifacts locally BEFORE terraform runs.
  # Terraform then uploads and deploys the Lambda functions.
  # ---------------------------------------------------------------------------

  # Build and package Lambda code locally (Terraform uploads and deploys)
  before_hook "build_lambdas" {
    commands = ["apply", "plan"]
    execute = [
      "${get_repo_root()}/scripts/build-lambdas.sh",
      "--environment", "dev1",
      "--source-dir", "${get_repo_root()}/examples/lambdas",
      "--no-upload"
    ]
  }

  # Build SPA before apply (if examples/spa exists)
  before_hook "build_spa" {
    commands = ["apply"]
    execute = [
      "bash", "-c",
      <<-EOF
        SPA_DIR="${get_repo_root()}/examples/spa"
        if [[ -d "$SPA_DIR" ]] && [[ -f "$SPA_DIR/package.json" ]]; then
          echo "Building SPA..."
          cd "$SPA_DIR"
          npm ci --silent 2>/dev/null || npm install --silent
          npm run build --silent 2>/dev/null || true
        else
          echo "No SPA found at $SPA_DIR, skipping..."
        fi
      EOF
    ]
  }

  # Upload SPA to S3 after terraform creates the bucket
  after_hook "upload_spa" {
    commands     = ["apply"]
    run_on_error = false
    execute = [
      "bash", "-c",
      <<-EOF
        SPA_DIST="${get_repo_root()}/examples/spa/dist"
        if [[ -d "$SPA_DIST" ]]; then
          # Get the SPA bucket from terraform output (hook runs in .terragrunt-cache)
          SPA_BUCKET=$(terraform output -raw spa_bucket_id 2>/dev/null || echo "")
          if [[ -n "$SPA_BUCKET" ]]; then
            echo "Uploading SPA to s3://$SPA_BUCKET..."
            aws s3 sync "$SPA_DIST" "s3://$SPA_BUCKET" \
              --delete \
              --cache-control "max-age=31536000" \
              --exclude "index.html" \
              --region eu-west-2
            # Upload index.html with no-cache
            aws s3 cp "$SPA_DIST/index.html" "s3://$SPA_BUCKET/index.html" \
              --cache-control "no-cache, no-store, must-revalidate" \
              --region eu-west-2
            echo "SPA uploaded successfully!"

            # Invalidate CloudFront cache
            CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
            if [[ -n "$CLOUDFRONT_ID" ]]; then
              echo "Invalidating CloudFront cache for distribution $CLOUDFRONT_ID..."
              aws cloudfront create-invalidation \
                --distribution-id "$CLOUDFRONT_ID" \
                --paths "/*" \
                --output text
              echo "CloudFront cache invalidation initiated!"
            else
              echo "Could not determine CloudFront distribution ID, skipping invalidation..."
            fi
          else
            echo "Could not determine SPA bucket, skipping upload..."
          fi
        else
          echo "No SPA dist found, skipping upload..."
        fi
      EOF
    ]
  }
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

  # Lambda Configuration - Global defaults
  enable_vpc_access = true
  # https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
  lambda_runtime     = "nodejs24.x"
  lambda_timeout     = 30
  lambda_memory_size = 256
  log_retention_days = 14

  # Lambda code deployment - hooks build and upload automatically
  # Set to true for initial infrastructure deployment without code
  use_placeholder_lambda = false

  # Base path where lambda zip files are located after build
  # Build script creates: <base_path>/<lambda-name>/<lambda-name>.zip
  lambdas_base_path = "${get_repo_root()}/examples/lambdas"

  # =============================================================================
  # LAMBDA DEFINITIONS MAP
  # Define all lambdas here - each gets an API Gateway if api_path_prefix is set
  # =============================================================================
  lambdas = {
    # User Service API - accessible at /api1/*
    # Demonstrates Secrets Manager integration
    "api1-handler" = {
      description     = "User Service API Handler with Secrets Manager"
      api_path_prefix = "api1" # Creates API Gateway at /api1/*
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
      description     = "Order Service API Handler"
      api_path_prefix = "api2" # Creates API Gateway at /api2/*
      timeout         = 30
      memory_size     = 256
      environment = {
        API_NAME    = "orders"
        API_VERSION = "v1"
      }
    }

    # SQS Message Processor - triggered by SQS events (no API Gateway)
    # Demonstrates event-driven architecture with SQS
    "sqs-processor" = {
      description = "SQS Event Processor - processes messages from queue"
      sqs_trigger = true # Enables SQS event source mapping
      timeout     = 60   # Longer timeout for batch processing
      memory_size = 256
      environment = {
        PROCESSOR_NAME = "event-processor"
      }
    }
  }

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
}
