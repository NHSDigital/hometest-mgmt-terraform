# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR uat ENVIRONMENT
# Deployment with: cd poc/hometest-app/uat && terragrunt apply
#
# All shared configuration (dependencies, lambda definitions, hooks) comes from ../app.hcl.
# Environment name ("uat") is derived automatically from this directory name.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "app" {
  path           = find_in_parent_folders("app.hcl")
  expose         = true
  merge_strategy = "deep"
}
