# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform and OpenTofu that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Include the root `terragrunt.hcl` configuration. The root configuration contains settings that are common across all
# components and environments, such as how to configure remote state.
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../..//src/network"
}

# poc is non-production - cost optimisations vs production HA:
#   single_nat_gateway        = true  : ~$65/month saving (1 NAT GW instead of per-AZ)
#   az_count                  = 2     : ~$284/month saving if network firewall enabled (2 endpoints not 3)
#                                       ~$36/month saving on VPC interface endpoint ENIs
#   enable_firewall_flow_logs = false : removes high-volume FLOW logs from CloudWatch (keep ALERT only)
#   firewall_logs_retention_days = 7  : reduces CloudWatch storage for POC logs
# For production, remove these overrides to restore per-AZ NAT gateways, 3-AZ redundancy, and full logging.
inputs = {
  single_nat_gateway           = true
  az_count                     = 2
  enable_firewall_flow_logs    = false
  firewall_logs_retention_days = 7
}
