# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION FOR HOMETEST-APP
# This file contains the common configuration for all environments
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Default values that can be overridden per environment
  default_lambda_runtime     = "nodejs20.x"
  default_lambda_timeout     = 30
  default_lambda_memory_size = 256
  default_log_retention_days = 30

  # API Gateway defaults
  default_api_throttling_burst_limit = 5000
  default_api_throttling_rate_limit  = 10000

  # CloudFront defaults
  default_cloudfront_price_class = "PriceClass_100"

  # Security headers
  default_content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';"
  default_permissions_policy      = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
}

terraform {
  source = "${get_repo_root()}/infrastructure/src/hometest-app"
}

# Default inputs that can be overridden
inputs = {
  lambda_runtime     = local.default_lambda_runtime
  lambda_timeout     = local.default_lambda_timeout
  lambda_memory_size = local.default_lambda_memory_size
  log_retention_days = local.default_log_retention_days

  api_throttling_burst_limit = local.default_api_throttling_burst_limit
  api_throttling_rate_limit  = local.default_api_throttling_rate_limit

  cloudfront_price_class = local.default_cloudfront_price_class

  content_security_policy = local.default_content_security_policy
  permissions_policy      = local.default_permissions_policy
}
