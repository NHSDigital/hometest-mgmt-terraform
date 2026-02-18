# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev-mikmio ENVIRONMENT
# Deployment with: cd poc/hometest-app/dev-mikmio && terragrunt apply
#
# All shared configuration (dependencies, lambda definitions, hooks) comes from _envcommon/hometest-app.hcl.
# Environment name ("dev-mikmio") is derived automatically from this directory name — no env.hcl needed.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/hometest-app.hcl"
  expose         = true
  merge_strategy = "deep"
}

# Uses all defaults from _envcommon/hometest-app.hcl — no overrides needed.
# To add environment-specific overrides, uncomment and extend:
# inputs = {
#   lambdas = {
#     "my-custom-lambda" = { ... }
#   }
# }
