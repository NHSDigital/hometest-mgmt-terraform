# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform and OpenTofu
# that helps keep your code DRY and maintainable.
# ---------------------------------------------------------------------------------------------------------------------

# Include the root `terragrunt.hcl` configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include the envcommon configuration for the component
include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/main.hcl"
  expose = true
}

# Configure the version of the module to use in this environment
terraform {
  source = "../../../..//src/main"
}

# ---------------------------------------------------------------------------------------------------------------------
# Environment-specific overrides
# Override any common parameters for this specific environment here
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Dev-specific overrides
  lambda_memory_size = 512
  lambda_timeout     = 30
  
  # Dev throttling limits (lower for cost control)
  throttling_burst_limit = 50
  throttling_rate_limit  = 25

  # Dev log retention (shorter for cost savings)
  log_retention_days = 14

  # Environment variables
  environment_variables = {
    DEBUG = "true"
  }

  # Tags
  tags = {
    Environment = "dev"
    Owner       = "platform-team"
  }
}
