# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR SHARED SERVICES
# Deploys resources shared across all environments (WAF, ACM, KMS, etc.)
# Must be deployed after network and before any hometest-app environments
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infrastructure/src/shared_services"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES
# ---------------------------------------------------------------------------------------------------------------------

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    route53_zone_id = "Z0123456789ABCDEFGHIJ"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  global_vars  = read_terragrunt_config(find_in_parent_folders("_envcommon/all.hcl"))

  project_name = local.global_vars.locals.project_name
  account_id   = local.account_vars.locals.aws_account_id
}

# Generate provider configuration for us-east-1 (required for CloudFront WAF and ACM)
generate "provider_us_east_1" {
  path      = "provider_us_east_1.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
EOF
}

inputs = {
  project_name = local.project_name
  environment  = "core"

  # Domain for wildcard certificates
  domain_name     = "hometest.service.nhs.uk"
  route53_zone_id = dependency.network.outputs.route53_zone_id

  # ACM Certificates
  create_acm_certificates = true

  # WAF Configuration
  waf_rate_limit         = 2000
  waf_log_retention_days = 30

  # KMS
  kms_deletion_window_days = 30

  # Deployment Artifacts
  artifact_retention_days = 30

  # Developer IAM
  developer_account_arns = [
    "arn:aws:iam::${local.account_id}:root"
  ]
  require_mfa = false  # Set to true for production
}
