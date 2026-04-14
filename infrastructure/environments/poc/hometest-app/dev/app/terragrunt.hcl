# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev ENVIRONMENT
# Deployment with: cd poc/hometest-app/dev/app && terragrunt apply
#
# All shared configuration (dependencies, lambda definitions, hooks) comes from _envcommon/hometest-app.hcl.
# Domain overrides and env flags are in ../env.hcl.
# Environment name ("dev") is derived from the parent directory name.
# Only truly env-specific overrides (e.g., extra lambdas) belong here.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "app" {
  path           = find_in_parent_folders("_envcommon/hometest-app.hcl")
  expose         = true
  merge_strategy = "deep"
}

# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT-SPECIFIC OVERRIDES
# Deep-merged with _envcommon/hometest-app.hcl inputs.
# Domain, certs, hooks, and lambda env vars are handled by app.hcl + env.hcl.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # TEMPORARY FIX: staging uses devtest.hometest.service.nhs.uk zone (Z10312861T421RGJG6CVB)
  # instead of the default hometest.service.nhs.uk zone from the network module.
  # TODO: Remove once the network module outputs the correct zone for this subenv.
  route53_zone_id = "Z10312861T421RGJG6CVB"
}
