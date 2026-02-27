# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION FOR dev ENVIRONMENT
# Deployment with: cd poc/hometest-app/dev && terragrunt apply
#
# All shared configuration (dependencies, lambda definitions, hooks) comes from ../app.hcl.
# Environment name ("dev") is derived automatically from this directory name.
# Only add overrides here for what's specific to this environment.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "app" {
  path           = find_in_parent_folders("app.hcl")
  expose         = true
  merge_strategy = "deep"
}

# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT-SPECIFIC OVERRIDES
# Only define inputs that differ from ../app.hcl
# The lambdas map below is deep-merged with the common lambdas.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  lambdas = {
    # Hello World Lambda - simple health check (dev environment only)
    # CloudFront: /hello-world/* → API Gateway → Lambda
    "hello-world-lambda" = {
      description     = "Hello World Lambda - Health Check"
      api_path_prefix = "hello-world"
      handler         = "index.handler"
      timeout         = 30
      memory_size     = 256
      environment = {
        NODE_OPTIONS = "--enable-source-maps"
        ENVIRONMENT  = basename(get_terragrunt_dir())
      }
    }
  }
}
