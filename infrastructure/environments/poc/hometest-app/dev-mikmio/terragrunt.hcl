# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev-mikmio ENVIRONMENT
# Deployment with: cd poc/hometest-app/dev-mikmio && terragrunt apply
#
# All shared configuration (dependencies, lambda definitions, hooks) comes from ../app.hcl.
# Environment name ("dev-mikmio") is derived automatically from this directory name.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "app" {
  path           = find_in_parent_folders("app.hcl")
  expose         = true
  merge_strategy = "deep"
}

# Uses all defaults from ../app.hcl — no overrides needed.
# To add environment-specific overrides, uncomment and extend:
# inputs = {
#   lambdas = {
#     "my-custom-lambda" = { ... }
#   }
# }
