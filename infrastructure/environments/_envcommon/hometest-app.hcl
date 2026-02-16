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

  # ---------------------------------------------------------------------------
  # SOURCE PATHS - Can be overridden via env.hcl in each environment
  # ---------------------------------------------------------------------------
  # Check if env.hcl has path overrides, otherwise use defaults
  # Default: hometest-service repo (production code)
  lambdas_source_dir = try(local.env_vars.locals.lambdas_source_dir, "${get_repo_root()}/../hometest-service/lambdas")
  lambdas_base_path  = try(local.env_vars.locals.lambdas_base_path, "${local.lambdas_source_dir}/src")
  spa_source_dir     = try(local.env_vars.locals.spa_source_dir, "${get_repo_root()}/../hometest-service/ui")
  spa_dist_dir       = try(local.env_vars.locals.spa_dist_dir, "${local.spa_source_dir}/out")
  spa_type           = try(local.env_vars.locals.spa_type, "nextjs") # "nextjs" or "vite"

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
  # Paths are configurable via locals: lambdas_source_dir, spa_source_dir, spa_type
  # ---------------------------------------------------------------------------

  # Build and package Lambda code locally (Terraform uploads and deploys)
  # Uses scripts/build-lambdas.sh which only rebuilds when source changes are detected
  before_hook "build_lambdas" {
    commands = ["plan",
    "apply"]
    execute = [
      "bash", "-c",
      "\"$(cd '${get_repo_root()}' && pwd)/scripts/build-lambdas.sh\" \"$(cd '${local.lambdas_source_dir}' && pwd)\" \"$(cd '${get_repo_root()}' && pwd)/.lambda-build-cache\""
    ]
  }

  # Build SPA before apply
  before_hook "build_spa" {
    commands = ["apply"]
    execute = [
      "bash", "-c",
      <<-EOF
        SPA_DIR="${local.spa_source_dir}"
        SPA_TYPE="${local.spa_type}"
        if [[ -d "$SPA_DIR" ]] && [[ -f "$SPA_DIR/package.json" ]]; then
          echo "Building $SPA_TYPE SPA from $SPA_DIR..."
          cd "$SPA_DIR"
          npm ci --silent 2>/dev/null || npm install --silent

          # Set Next.js public environment variables for build
          export NEXT_PUBLIC_LOGIN_LAMBDA_ENDPOINT="https://${local.env_domain}/login"
          echo "Setting NEXT_PUBLIC_LOGIN_LAMBDA_ENDPOINT=$NEXT_PUBLIC_LOGIN_LAMBDA_ENDPOINT"

          npm run build --silent 2>/dev/null || true
          echo "SPA build complete!"
        else
          echo "SPA not found at $SPA_DIR, skipping..."
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
        SPA_TYPE="${local.spa_type}"
        SPA_DIST="${local.spa_dist_dir}"

        # Fallback paths based on SPA type
        if [[ ! -d "$SPA_DIST" ]]; then
          if [[ "$SPA_TYPE" == "nextjs" ]]; then
            SPA_DIST="${local.spa_source_dir}/build"
          else
            SPA_DIST="${local.spa_source_dir}/dist"
          fi
        fi

        if [[ -d "$SPA_DIST" ]]; then
          SPA_BUCKET=$(terraform output -raw spa_bucket_id 2>/dev/null || echo "")
          if [[ -n "$SPA_BUCKET" ]]; then
            echo "Uploading $SPA_TYPE SPA from $SPA_DIST to s3://$SPA_BUCKET..."

            if [[ "$SPA_TYPE" == "nextjs" ]]; then
              # Next.js specific upload with proper caching
              aws s3 sync "$SPA_DIST" "s3://$SPA_BUCKET" \
                --delete \
                --cache-control "max-age=31536000" \
                --exclude "*.html" \
                --exclude "_next/data/*" \
                --region eu-west-2
              # HTML files with no-cache
              aws s3 cp "$SPA_DIST" "s3://$SPA_BUCKET" \
                --recursive \
                --exclude "*" \
                --include "*.html" \
                --cache-control "no-cache, no-store, must-revalidate" \
                --region eu-west-2
              # _next/data with short cache
              if [[ -d "$SPA_DIST/_next/data" ]]; then
                aws s3 sync "$SPA_DIST/_next/data" "s3://$SPA_BUCKET/_next/data" \
                  --cache-control "max-age=60" \
                  --region eu-west-2
              fi
            else
              # Vite/standard SPA upload
              aws s3 sync "$SPA_DIST" "s3://$SPA_BUCKET" \
                --delete \
                --cache-control "max-age=31536000" \
                --exclude "index.html" \
                --region eu-west-2
              aws s3 cp "$SPA_DIST/index.html" "s3://$SPA_BUCKET/index.html" \
                --cache-control "no-cache, no-store, must-revalidate" \
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
          echo "No SPA dist found at $SPA_DIST, skipping upload..."
        fi
      EOF
    ]
  }

  # Empty SPA bucket before a destroy so deletion of an environment will proceed without errors due to non-empty bucket (including versioned objects)
  before_hook "empty_spa_bucket_on_destroy" {
    commands     = ["destroy"]
    run_on_error = true
    execute = [
      "bash", "-c",
      <<-EOF
        SPA_BUCKET="${local.project_name}-${local.environment}-spa"
        if [[ -n "$SPA_BUCKET" ]]; then
          echo "Cleaning versioned objects in s3://$SPA_BUCKET..."
          OBJECTS_JSON=$(aws s3api list-object-versions \
            --bucket "$SPA_BUCKET" \
            --query '{Objects: ([Versions[], DeleteMarkers[]][] | [].{Key: Key, VersionId: VersionId})}' \
            --output json \
            --region eu-west-2)

          if [[ -n "$OBJECTS_JSON" && "$OBJECTS_JSON" != "{\"Objects\": []}" && "$OBJECTS_JSON" != "{\"Objects\":[]}" ]]; then
            aws s3api delete-objects \
              --bucket "$SPA_BUCKET" \
              --delete "$OBJECTS_JSON" \
              --region eu-west-2 || true
          else
            echo "No versioned objects found in $SPA_BUCKET."
          fi
        else
          echo "Could not determine SPA bucket, skipping cleanup..."
        fi
      EOF
    ]
  }
}
