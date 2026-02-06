# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION - IAM Developer Role for DEV Environment
# This provisions the IAM role for developers with scoped permissions
# Ready for AWS AFT integration
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//src/iam-developer-role"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEV Environment IAM Developer Role Configuration
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Trust Relationship Configuration
  # Enable AFT trust for future AWS Account Factory for Terraform integration
  enable_aft_trust          = true
  aft_management_account_id = "" # Set to AFT management account ID when available
  aft_external_id           = "" # Set to external ID when available

  # Enable SSO trust for developers
  enable_sso_trust = false
  allowed_teams    = ["developers", "platform"]

  # Enable GitHub OIDC for CI/CD
  enable_github_oidc_trust = true
  github_repo              = "NHSDigital/hometest-mgmt-terraform"

  # Enable account trust for initial testing (disable in production)
  enable_account_trust = true

  # Session Configuration
  max_session_duration = 3600 # 1 hour for dev

  # Additional custom permissions can be added here
  additional_iam_statements = []
}
