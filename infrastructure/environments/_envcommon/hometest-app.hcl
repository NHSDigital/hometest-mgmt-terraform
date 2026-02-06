# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION FOR HOMETEST-APP
# This file contains the shared configuration for all dev environments (dev1, dev2, etc.)
# Environment-specific terragrunt.hcl files include this and override only what's needed.
#
# Usage in environment terragrunt.hcl:
#   include "envcommon" {
#     path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/hometest-app.hcl"
#     expose = true
#     merge_strategy = "deep"
#   }
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# LOCALS - Common configuration values
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Load configuration from parent folders
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  global_vars  = read_terragrunt_config(find_in_parent_folders("_envcommon/all.hcl"))

  # Extract commonly used values
  project_name = local.global_vars.locals.project_name
  account_id   = local.account_vars.locals.aws_account_id
  environment  = local.env_vars.locals.environment

  # Domain configuration
  base_domain = "hometest.service.nhs.uk"
  env_domain  = "${local.environment}.${local.base_domain}"

  # Lambda Configuration Defaults
  # https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
  lambda_runtime     = "nodejs24.x"
  lambda_timeout     = 30
  lambda_memory_size = 256
  log_retention_days = 14

  # API Gateway Defaults
  api_stage_name             = "v1"
  api_endpoint_type          = "REGIONAL"
  api_throttling_burst_limit = 1000
  api_throttling_rate_limit  = 2000

  # CloudFront Defaults
  cloudfront_price_class = "PriceClass_100"

  # Security headers
  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';"
  permissions_policy      = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
}

# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM SOURCE
# ---------------------------------------------------------------------------------------------------------------------

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
    execute  = [
      "${get_repo_root()}/scripts/build-lambdas.sh",
      "--environment", local.environment,
      "--source-dir", "${get_repo_root()}/examples/lambdas",
      "--no-upload"
    ]
  }

  # Build SPA before apply (if examples/spa exists)
  before_hook "build_spa" {
    commands = ["apply"]
    execute  = [
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
    execute      = [
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
