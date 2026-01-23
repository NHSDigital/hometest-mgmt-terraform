# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION - WAF for DEV Environment
# This provisions WAF Web ACL attached to API Gateway for dev environment
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//src/waf"
}

# Dependencies
dependency "api_gateway" {
  config_path = "../api-gateway"

  mock_outputs = {
    stage_arn = "arn:aws:apigateway:eu-west-2::/restapis/mock-api-id/stages/v1"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "apply", "destroy"]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEV Environment WAF Configuration
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # API Gateway Association
  api_gateway_stage_arn = dependency.api_gateway.outputs.stage_arn

  # Rule Configuration
  common_rules_excluded = [] # No exclusions initially
  enable_linux_rules    = true

  # Rate Limiting - more permissive for dev
  enable_rate_limiting = true
  rate_limit           = 5000 # Requests per 5 minutes per IP

  # IP Filtering - disabled for dev
  enable_ip_allowlist  = false
  allowed_ip_addresses = []
  enable_ip_blocklist  = false
  blocked_ip_addresses = []

  # Geo Restriction - disabled for dev
  enable_geo_restriction = false
  allowed_countries      = ["GB"]

  # Logging - log all requests for dev debugging
  log_retention_days = 30
  log_all_requests   = true
  redacted_fields = [
    {
      type = "single_header"
      name = "authorization"
    },
    {
      type = "single_header"
      name = "cookie"
    }
  ]
}
