# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev3 ENVIRONMENT
# Deployment with: cd dev3/hometest-app && terragrunt apply
# Dependencies: network (VPC/Route53), shared_services (WAF/ACM/KMS)
#
# This environment uses lambdas and UI from the hometest-service repository.
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
# TERRAFORM OVERRIDES - Use hometest-service repo for lambdas and SPA
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Override build hooks to use hometest-service repo
  before_hook "build_lambdas" {
    commands = ["apply", "plan"]
    execute  = [
      "bash", "-c",
      <<-EOF
        LAMBDAS_DIR="/home/mikee/git/kainos/code/nhs/code/hometest-service/lambdas"
        if [[ -d "$LAMBDAS_DIR" ]]; then
          echo "Building lambdas from hometest-service repo..."
          cd "$LAMBDAS_DIR"
          npm ci --silent 2>/dev/null || npm install --silent
          npm run build --silent 2>/dev/null || true
          
          # Package each lambda
          for lambda_dir in src/*/; do
            lambda_name=$(basename "$lambda_dir")
            if [[ -d "dist/$lambda_name" ]]; then
              echo "Packaging $lambda_name..."
              mkdir -p "$lambda_dir"
              cd "dist/$lambda_name"
              zip -rq "../../src/$lambda_name/$lambda_name.zip" . 2>/dev/null || true
              cd "$LAMBDAS_DIR"
            fi
          done
          echo "Lambda build complete!"
        else
          echo "hometest-service lambdas not found at $LAMBDAS_DIR"
          exit 1
        fi
      EOF
    ]
  }

  # Build Next.js SPA before apply
  before_hook "build_spa" {
    commands = ["apply"]
    execute  = [
      "bash", "-c",
      <<-EOF
        SPA_DIR="/home/mikee/git/kainos/code/nhs/code/hometest-service/ui"
        if [[ -d "$SPA_DIR" ]] && [[ -f "$SPA_DIR/package.json" ]]; then
          echo "Building Next.js SPA from hometest-service repo..."
          cd "$SPA_DIR"
          npm ci --silent 2>/dev/null || npm install --silent
          npm run build --silent 2>/dev/null || true
          echo "SPA build complete!"
        else
          echo "hometest-service UI not found at $SPA_DIR"
          exit 1
        fi
      EOF
    ]
  }

  # Upload Next.js static export to S3
  after_hook "upload_spa" {
    commands     = ["apply"]
    run_on_error = false
    execute      = [
      "bash", "-c",
      <<-EOF
        # Next.js static export goes to 'out' directory (or 'build' if using export)
        SPA_DIST="/home/mikee/git/kainos/code/nhs/code/hometest-service/ui/out"
        if [[ ! -d "$SPA_DIST" ]]; then
          SPA_DIST="/home/mikee/git/kainos/code/nhs/code/hometest-service/ui/build"
        fi
        
        if [[ -d "$SPA_DIST" ]]; then
          SPA_BUCKET=$(terraform output -raw spa_bucket_id 2>/dev/null || echo "")
          if [[ -n "$SPA_BUCKET" ]]; then
            echo "Uploading Next.js SPA to s3://$SPA_BUCKET..."
            aws s3 sync "$SPA_DIST" "s3://$SPA_BUCKET" \
              --delete \
              --cache-control "max-age=31536000" \
              --exclude "index.html" \
              --exclude "_next/data/*" \
              --region eu-west-2
            # Upload HTML files with no-cache
            aws s3 cp "$SPA_DIST" "s3://$SPA_BUCKET" \
              --recursive \
              --exclude "*" \
              --include "*.html" \
              --cache-control "no-cache, no-store, must-revalidate" \
              --region eu-west-2
            # Upload _next/data with short cache
            if [[ -d "$SPA_DIST/_next/data" ]]; then
              aws s3 sync "$SPA_DIST/_next/data" "s3://$SPA_BUCKET/_next/data" \
                --cache-control "max-age=60" \
                --region eu-west-2
            fi
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
            fi
          else
            echo "Could not determine SPA bucket, skipping upload..."
          fi
        else
          echo "No SPA dist found at expected locations, skipping upload..."
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
  enable_sqs_access  = true  # Required for order-router-lambda SQS trigger
  lambda_runtime     = include.envcommon.locals.lambda_runtime
  lambda_timeout     = include.envcommon.locals.lambda_timeout
  lambda_memory_size = include.envcommon.locals.lambda_memory_size
  log_retention_days = include.envcommon.locals.log_retention_days

  # Lambda code deployment
  use_placeholder_lambda = false

  # Base path for hometest-service lambdas
  lambdas_base_path = "/home/mikee/git/kainos/code/nhs/code/hometest-service/lambdas/src"

  # =============================================================================
  # LAMBDA DEFINITIONS - hometest-service lambdas
  # =============================================================================
  lambdas = {
    # Hello World Lambda - simple health check
    "hello-world-lambda" = {
      description     = "Hello World Lambda - Health Check"
      api_path_prefix = "hello"
      timeout         = 30
      memory_size     = 256
      environment = {
        ENVIRONMENT = include.envcommon.locals.environment
      }
    }

    # Eligibility Test Info Lambda
    "eligibility-test-info-lambda" = {
      description     = "Eligibility Test Info Service"
      api_path_prefix = "eligibility"
      timeout         = 30
      memory_size     = 256
      environment = {
        ENVIRONMENT = include.envcommon.locals.environment
      }
    }

    # Order Router Lambda - SQS triggered, no API endpoint
    "order-router-lambda" = {
      description = "Order Router Service - SQS Processor"
      sqs_trigger = true  # Triggered by SQS queue, no API Gateway integration
      timeout     = 60    # Longer timeout for queue processing
      memory_size = 512
      environment = {
        ENVIRONMENT = include.envcommon.locals.environment
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
